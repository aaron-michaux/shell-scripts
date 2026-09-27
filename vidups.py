#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path

VIDEO_EXTENSIONS = {
    ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm",
    ".m4v", ".mpeg", ".mpg", ".ts", ".3gp", ".ogv",
}

VALID_RUN_TO = {"files", "hashes", "compare", "output"}
PHASE_ORDER = ["files", "hashes", "compare", "output"]


def tmpd() -> Path:
    return Path(os.environ["HOME"]) / "TMP" / "vidups"


def phase_number(name: str) -> int:
    return PHASE_ORDER.index(name)


def ensure_tmpd() -> None:
    d = tmpd()
    d.mkdir(parents=True, exist_ok=True)


def phase_1_discover(directory: Path, lazy: bool) -> list[Path]:
    movie_out = tmpd() / "1.movie-files.text"
    other_out = tmpd() / "1.other-files.text"

    if lazy and movie_out.exists() and other_out.exists():
        movies = [Path(line.strip()) for line in movie_out.read_text().splitlines() if line.strip()]
        return movies

    movies: list[Path] = []
    others: list[Path] = []
    seen_inodes: set[tuple[int, int]] = set()

    for dirpath, dirnames, filenames in os.walk(directory):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fname in filenames:
            if fname.startswith("."):
                continue
            full = Path(dirpath) / fname
            try:
                if full.is_symlink():
                    continue
                st = full.stat()
                key = (st.st_dev, st.st_ino)
                if key in seen_inodes:
                    continue
                seen_inodes.add(key)
            except OSError:
                continue

            suffix = full.suffix.lower()
            if suffix in VIDEO_EXTENSIONS:
                movies.append(full)
            else:
                others.append(full)

    movies.sort(key=lambda p: str(p))
    others.sort(key=lambda p: str(p))

    movie_out.write_text("\n".join(str(m) for m in movies) + "\n")
    other_out.write_text("\n".join(str(o) for o in others) + "\n")

    return movies


def hash_path_for(movie: Path, directory: Path) -> Path:
    rel = movie.resolve().relative_to(directory.resolve())
    return tmpd() / (str(rel).replace("\\", "/") + ".hashes-bin")


def _frame_to_hash(frame_bytes: bytes) -> bytes:
    pixels = list(frame_bytes)
    mean = sum(pixels) // len(pixels)
    bits: list[int] = []
    for p in pixels:
        bits.append(1 if p > mean else 0)
    packed = bytearray()
    for i in range(0, 256, 8):
        b = 0
        for j in range(8):
            b = (b << 1) | bits[i + j]
        packed.append(b)
    return bytes(packed)


def compute_hashes(movie: Path) -> bytes | None:
    cmd = [
        "ffmpeg", "-v", "quiet", "-nostdin",
        "-i", str(movie),
        "-vf", "fps=1/5,scale=16:16,format=gray",
        "-f", "rawvideo", "-",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=600)
        if result.returncode != 0:
            return None
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None

    raw = result.stdout
    if len(raw) < 256:
        return None

    frame_count = len(raw) // 256
    hashes = bytearray()
    for i in range(frame_count):
        frame = raw[i * 256 : (i + 1) * 256]
        hashes.extend(_frame_to_hash(frame))

    return bytes(hashes)


def phase_2_hashes(directory: Path, movies: list[Path], lazy: bool) -> dict[Path, Path]:
    hash_map: dict[Path, Path] = {}
    total = len(movies)
    failed = 0
    for idx, movie in enumerate(movies):
        hp = hash_path_for(movie, directory)
        hash_map[movie] = hp

        if lazy and hp.exists():
            mtime_movie = movie.stat().st_mtime
            mtime_hash = hp.stat().st_mtime
            if mtime_hash >= mtime_movie:
                continue

        hp.parent.mkdir(parents=True, exist_ok=True)
        hashes = compute_hashes(movie)
        if hashes is not None:
            hp.write_bytes(hashes)
        else:
            failed += 1

        print(f"\rPhase 2 (perceptual hashing): {idx + 1}/{total}", end="", file=sys.stderr)
    if total > 0:
        print(file=sys.stderr)
    if failed > 0:
        print(f"Phase 2 warning: {failed} file(s) could not be hashed (corrupt or unsupported)", file=sys.stderr)
    return hash_map


def get_duration(movie: Path) -> float | None:
    cmd = [
        "ffprobe", "-v", "quiet",
        "-print_format", "json",
        "-show_format", str(movie),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=60)
        if result.returncode != 0:
            return None
        info = json.loads(result.stdout)
        return float(info["format"]["duration"])
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError,
            KeyError, ValueError, json.JSONDecodeError):
        return None


def load_hashes(hash_path: Path) -> list[bytes] | None:
    try:
        raw = Path(hash_path).read_bytes()
    except OSError:
        return None
    if len(raw) < 32 or len(raw) % 32 != 0:
        return None
    return [raw[i * 32 : (i + 1) * 32] for i in range(len(raw) // 32)]


def hamming_32(a: bytes, b: bytes) -> int:
    return (int.from_bytes(a, "big") ^ int.from_bytes(b, "big")).bit_count()


def median_hamming(frames_a: list[bytes], frames_b: list[bytes]) -> float:
    n = min(len(frames_a), len(frames_b))
    if n == 0:
        return float("inf")
    dists = [hamming_32(frames_a[i], frames_b[i]) for i in range(n)]
    return statistics.median(dists)


def run_vmaf(movie_a: Path, movie_b: Path) -> float | None:
    vf = (
        "[0:v]scale=1280:720,fps=24,setpts=PTS-STARTPTS[a];"
        "[1:v]scale=1280:720,fps=24,setpts=PTS-STARTPTS[b];"
        "[a][b]libvmaf=log_fmt=json:log_path="
    )
    log_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
            log_path = tf.name
        cmd = [
            "ffmpeg", "-nostdin",
            "-i", str(movie_a),
            "-i", str(movie_b),
            "-lavfi", vf + log_path,
            "-f", "null", "-",
        ]
        result = subprocess.run(cmd, capture_output=True, timeout=1200)
        with open(log_path) as f:
            data = json.load(f)
        return float(data["pooled_metrics"]["vmaf"]["mean"])
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError,
            KeyError, ValueError, json.JSONDecodeError):
        return None
    finally:
        if log_path:
            try:
                os.unlink(log_path)
            except OSError:
                pass


def phase_3_compare(movies: list[Path], hash_map: dict[Path, Path], lazy: bool) -> list[dict]:
    output_json = tmpd() / "output.json"
    expected_pairs = len(movies) * (len(movies) - 1) // 2

    if lazy and output_json.exists():
        try:
            data = json.loads(output_json.read_text())
            if isinstance(data, list) and len(data) == expected_pairs:
                return data
        except (json.JSONDecodeError, OSError):
            pass

    results: list[dict] = []

    durations: dict[Path, float | None] = {}
    missing_dur = 0
    for movie in movies:
        d = get_duration(movie)
        durations[movie] = d
        if d is None:
            missing_dur += 1
    if missing_dur > 0:
        print(f"Phase 3 warning: {missing_dur} file(s) have unknown duration", file=sys.stderr)

    frame_hashes: dict[Path, list[bytes] | None] = {}
    missing_hash = 0
    for movie, hp in hash_map.items():
        fh = load_hashes(hp)
        frame_hashes[movie] = fh
        if fh is None:
            missing_hash += 1
    if missing_hash > 0:
        print(f"Phase 3 warning: {missing_hash} file(s) have missing hashes", file=sys.stderr)

    total_pairs = len(movies) * (len(movies) - 1) // 2
    compared = 0
    for i in range(len(movies)):
        for j in range(i + 1, len(movies)):
            compared += 1
            if compared % 10 == 0 or compared == total_pairs:
                print(f"\rPhase 3 (comparing): {compared}/{total_pairs}", end="", file=sys.stderr)

            a = movies[i]
            b = movies[j]

            dur_a = durations.get(a)
            dur_b = durations.get(b)

            if dur_a is None or dur_b is None or dur_a <= 0 or dur_b <= 0:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "duration", "score": 0.0,
                })
                continue

            dur_diff = abs(dur_a - dur_b) / max(dur_a, dur_b)
            duration_pct = (1.0 - dur_diff) * 100
            if dur_diff > 0.01:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "duration", "score": round(duration_pct, 1),
                })
                continue

            fh_a = frame_hashes.get(a)
            fh_b = frame_hashes.get(b)
            if fh_a is None or fh_b is None:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "hamming", "score": 0.0,
                })
                continue

            mh = median_hamming(fh_a, fh_b)
            hamming_pct = (1.0 - mh / 256) * 100
            if mh > 10:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "hamming", "score": round(hamming_pct, 1),
                })
                continue

            vmaf_score = run_vmaf(a, b)
            if vmaf_score is None:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "vmaf", "score": None,
                })
                continue

            if vmaf_score >= 95.0:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "match", "score": round(vmaf_score, 1),
                })
            else:
                results.append({
                    "file1": str(a), "file2": str(b),
                    "strategy": "vmaf", "score": round(vmaf_score, 1),
                })

    if total_pairs > 0:
        print(file=sys.stderr)

    output_json = tmpd() / "output.json"
    with open(output_json, "w") as f:
        json.dump(results, f, indent=2)

    return results


def phase_4_output(results: list[dict], output_file: str | None) -> None:
    output_json = tmpd() / "output.json"
    output_text = tmpd() / "output.text"

    with open(output_json, "w") as f:
        json.dump(results, f, indent=2)

    if output_file:
        with open(output_file, "w") as f:
            json.dump(results, f, indent=2)

    lines: list[str] = []
    rows: list[tuple[str, str, str, str]] = []

    for r in results:
        f1 = r["file1"]
        f2 = r["file2"]
        strategy = r["strategy"]
        score_val = r["score"]
        if score_val is None:
            score_str = "n/a"
        elif strategy in ("match", "vmaf"):
            score_str = str(score_val)
        else:
            score_str = f"{score_val}%"
        rows.append((f1, f2, strategy, score_str))

    if not rows:
        lines.append("| file1 | file2 | strategy | score |")
        lines.append("No duplicate candidates found.")
    else:
        col1_w = max(len(r[0]) for r in rows)
        col2_w = max(len(r[1]) for r in rows)
        col3_w = max(max(len(r[2]) for r in rows), len("strategy"))
        col4_w = max(max(len(r[3]) for r in rows), len("score"))

        header = f"| {'file1':<{col1_w}} | {'file2':<{col2_w}} | {'strategy':<{col3_w}} | {'score':>{col4_w}} |"
        sep = f"|-{'-' * col1_w}-|-{'-' * col2_w}-|-{'-' * col3_w}-|-{'-' * col4_w}-|"

        lines.append(header)
        lines.append(sep)
        for f1, f2, strategy, score_str in rows:
            lines.append(
                f"| {f1:<{col1_w}} | {f2:<{col2_w}} "
                f"| {strategy:<{col3_w}} | {score_str:>{col4_w}} |"
            )

    table = "\n".join(lines)
    output_text.write_text(table + "\n")
    print(table)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="vidups — find duplicate video files in a directory tree"
    )
    parser.add_argument(
        "directory",
        help="Root directory to scan for video files",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="Optional path to write JSON output (also written to TMPD always)",
    )
    parser.add_argument(
        "--run-to",
        choices=VALID_RUN_TO,
        default="output",
        help="Stop after the named phase (default: output)",
    )
    lazy_group = parser.add_mutually_exclusive_group()
    lazy_group.add_argument(
        "--lazy",
        action="store_true",
        default=True,
        help="Skip phases where output files already exist (default)",
    )
    lazy_group.add_argument(
        "--no-lazy",
        action="store_false",
        dest="lazy",
        help="Recompute all phases from scratch",
    )
    lazy_group.add_argument(
        "--force",
        action="store_false",
        dest="lazy",
        help="Same as --no-lazy",
    )

    args = parser.parse_args()

    directory = Path(args.directory).expanduser().resolve()
    if not directory.is_dir():
        print(f"error: not a directory: {directory}", file=sys.stderr)
        return 1

    if not args.lazy and tmpd().exists():
        shutil.rmtree(tmpd())

    ensure_tmpd()

    max_phase = phase_number(args.run_to)

    movies = phase_1_discover(directory, args.lazy)
    print(f"Phase 1 (file discovery): found {len(movies)} video files", file=sys.stderr)
    if not movies:
        print("No video files found. Exiting.", file=sys.stderr)
        return 0

    if max_phase < 1:
        return 0

    hash_map = phase_2_hashes(directory, movies, args.lazy)

    if max_phase < 2:
        return 0

    results = phase_3_compare(movies, hash_map, args.lazy)

    if max_phase < 3:
        return 0

    phase_4_output(results, args.output)
    return 0


if __name__ == "__main__":
    sys.stdin = open("/dev/null")
    raise SystemExit(main())
