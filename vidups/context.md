# Vidups — Domain Model & Design Decisions

A duplicate video finder that uses a 3-phase coarse→fine pipeline (duration → perceptual hash Hamming distance → VMAF) to identify re-encoded duplicates, regardless of codec, resolution, or bitrate differences.

## Language

**Phase**:
A discrete, ordered step in the pipeline. Each phase produces output files on disk; the next phase reads those files as input. Phases are named by number: 1 (file discovery), 2 (perceptual hashing), 3 (comparison & output).

**Candidate**:
A pair of videos that passes the duration gate and the Hamming-distance gate, but has not yet been verified by VMAF. A candidate is *not* guaranteed to be a match.

**Match**:
A pair of videos that passes all three gates and is confirmed by VMAF to be perceptually equivalent.

**Gate / Fail gate**:
A decision point in the pipeline that rejects a pair before reaching the next, more expensive phase. The strategy column in output names the gate that rejected the pair (e.g. `duration`, `hamming`, `match`).

**Perceptual hash (phash)**:
A 256-bit fingerprint computed per sampled frame. Each 16×16 grayscale frame is thresholded against its mean pixel value to produce 256 bits (32 bytes). Stored in `.hashes-bin` files.

**Hamming distance**:
Bitwise XOR + popcount between two perceptual hashes. Measures how different two frames are at the bit level. Used as a cheap similarity proxy before VMAF.

**VMAF (Video Multi-Method Assessment Fusion)**:
A perceptual video quality metric produced by Netflix's libvmaf. Runs via FFmpeg's `libvmaf` filter. The final, authoritative gate for determining if two videos are duplicates.

**TMPD**:
`$HOME/TMP/vidups` — the temporary working directory where all phase outputs and hash files live.

---

## Design Decisions

### 1. File discovery: extension-based filtering

**Decision**: Classify files as video/movie using a whitelist of file extensions. The list is: `.mp4`, `.mkv`, `.avi`, `.mov`, `.wmv`, `.flv`, `.webm`, `.m4v`, `.mpeg`, `.mpg`, `.ts`, `.3gp`, `.ogv`.

**Why**: Extension checking is free (no I/O beyond `os.walk`). `ffprobe` would require opening every file. The false-positive rate (non-video files with these extensions) is negligible for a duplicate-detection tool — they'll simply fail later in the pipeline with a clear error.

**Consequences**: Files with unconventional extensions (e.g. `.vid`) are ignored. Symlinks and hardlinks are skipped by `os.walk` + `os.path.islink` / `os.stat` inode tracking.

---

### 2. Perceptual hash: 16×16 grayscale, sampled every 5 seconds

**Decision**: Each video is sampled at 5-second intervals. Each frame is resized to 16×16, converted to grayscale. Each pixel is thresholded against the frame mean: `pixel > mean → 1`, else `0`. The result is a 256-bit hash per frame, stored as 32 raw bytes per frame in `.hashes-bin`.

**Why 5s**: The strategy doc recommends 5–10s. Five seconds gives more samples for short videos while keeping file sizes manageable. A 2-hour video produces (7200 / 5) = 1440 frames × 32 bytes = ~46 KB — trivial.

**Why 16×16**: 256 bits gives better discrimination than 64-bit (8×8) with negligible overhead. The FFmpeg command for 8×8 vs 16×16 costs roughly the same.

**Binary format**: Raw concatenation of 32-byte frames. Frame count = filesize / 32. No header needed.

**FFmpeg command**:
```
ffmpeg -i INPUT -vf "fps=1/5,scale=16:16,format=gray" -f rawvideo -
```
Post-processing in Python: read 256 bytes per frame, compute mean, threshold.

---

### 3. Duration gate: ±1% tolerance

**Decision**: Extract duration with `ffprobe`. Reject a pair if `abs(d1 - d2) / max(d1, d2) > 0.01`.

**Why 1%**: Specified in the spec. Tight enough to eliminate obviously different videos (a trailer vs a feature film), loose enough to tolerate minor timing differences from re-encoding (e.g. a few frames of black padding added by an encoder).

**Edge case**: What if both durations are 0 (broken files)? Reject the pair immediately — can't compare.

---

### 4. Hamming gate: median Hamming ≤ 10

**Decision**: Compute the per-frame Hamming distance for each corresponding frame pair (frames 0..N-1 where N = min(len(h1), len(h2))). Take the median. If median Hamming distance > 10 (out of 256), reject the pair. Otherwise, the pair is a candidate for VMAF.

**Why median**: The strategy doc specifically recommends median. It's robust to a few outlier frames (scene changes, encoding glitches) while catching videos that are genuinely different across most frames.

**Why threshold 10**: 10 / 256 ≈ 3.9% bit difference. This is lenient enough to pass re-encodes (same source, different codec/resolution) while rejecting unrelated videos. A typical re-encode of the same source should have median Hamming ≤ 5.

**Temporal alignment**: We compare frame N to frame N. If videos have matching durations (within 1%), we assume temporal alignment is close enough. The extra min(len) accounts for ±1 frame of difference.

---

### 5. VMAF gate: score ≥ 95.0 → match

**Decision**: Run `libvmaf` on each candidate pair. Normalize both videos to 1280×720 at 24fps before comparison. If VMAF score ≥ 95.0, the pair is a match. Otherwise, output the VMAF score as the fail reason.

**Why 95.0**: VMAF 93+ is "imperceptible" for most viewers. 95 gives a conservative margin. Since the Hamming gate already filtered to likely matches, a 95 threshold balances false positives and false negatives.

**Normalization**: 1280×720 at 24fps is a reasonable middle ground. Higher resolution = slower VMAF. Lower = less accurate. 720p24 is a good trade-off for a CLI tool that needs to be practical.

**FFmpeg command**:
```
ffmpeg -i A -i B -lavfi "[0:v]scale=1280:720,fps=24,setpts=PTS-STARTPTS[a];[1:v]scale=1280:720,fps=24,setpts=PTS-STARTPTS[b];[a][b]libvmaf" -f null -
```

---

### 6. Architecture: single Python script, stdlib only

**Decision**: One file: `vidups.py`. No dependencies beyond Python 3 stdlib and `ffmpeg`/`ffprobe` on PATH. Uses `argparse`, `subprocess`, `os`, `json`, `sys`, `glob`, `struct`.

**Why**: The spec explicitly forbids installing pip packages. A single script is easy to distribute, review, and run. No setup required beyond `chmod +x vidups.py` and having ffmpeg installed.

---

### 7. CLI interface

**Arguments**:
- `directory` (positional, required): root directory to scan
- `-o / --output FILE` (optional): write JSON output here as well
- `--run-to PHASE` (optional): stop after phase. Valid: `files`, `hashes`, `compare`, `output`
- `--lazy` (default): skip phases where output files already exist
- `--no-lazy` / `--force`: recompute everything from scratch
- `-h / --help`: show usage

**Phase mapping to --run-to**:
- `files`: Phase 1 only (produce `1.movie-files.text`, `1.other-files.text`)
- `hashes`: Phase 1 + 2 (produce `.hashes-bin` files)
- `compare`: Phase 1 + 2 + 3 (produce `output.json`, `output.text`)
- `output`: All phases (same as compare, since output writes at the end of phase 3/4). Actually, per spec phases are 1-4 and output writes in phase 4.

**Re-reading spec**: The spec says phases 1-4 and "Output is written to TMPD/output.json, and TMPD/output.text". So phase 4 IS the output phase. The phases map as:
- `files` (phase 1): discover files
- `hashes` (phase 2): compute perceptual hashes
- `compare` (phase 3): run the decision tree (duration → hamming → VMAF)
- `output` (phase 4): format and write output
- `--run-to files` runs phase 1 and stops
- `--run-to hashes` runs phases 1-2 and stops
- `--run-to compare` runs phases 1-3 and stops
- `--run-to output` runs all phases (default)

---

### 8. Lazy mode

**Decision**: `--lazy` (default) skips work when output files already exist:
- Phase 1: Skip if `TMPD/1.movie-files.text` exists
- Phase 2: Skip individual `.hashes-bin` files that exist and are newer than the source video
- Phase 3: Skip individual pair comparisons if already in loaded JSON (requires loading existing output)
- Phase 4: Skip if `TMPD/output.json` exists

**--force** deletes TMPD before starting.

---

### 9. Output formats

**JSON** (`output.json`):
```json
[
  {
    "file1": "/absolute/path/to/video1.mp4",
    "file2": "/absolute/path/to/video2.mp4",
    "strategy": "match",
    "score": 97.3
  },
  {
    "file1": "/absolute/path/to/video3.mp4",
    "file2": "/absolute/path/to/video4.mp4",
    "strategy": "duration",
    "score": 45.2
  }
]
```

**Text table** (terminal + `output.text`):
```
| file1                                   | file2                                   | strategy   | score   |
| /path/to/video1.mp4                     | /path/to/video2.mp4                     | match      | 97.3%   |
| /path/to/video3.mp4                     | /path/to/video4.mp4                     | duration   | 45.2%   |
```

Strategy values: `duration`, `hamming`, `vmaf`, `match`. Every pair of videos is reported exactly once. The strategy names the gate that resolved the pair, and `score` is the metric value at that gate:

- `duration` — rejected at the duration gate. Score is duration similarity % (0.0 when a duration is unknown or zero).
- `hamming` — rejected at the Hamming gate. Score is Hamming similarity % (0.0 when hashes are missing).
- `vmaf` — passed the coarse gates but VMAF < 95.0. Score is the VMAF score, or `null` if VMAF could not run.
- `match` — VMAF ≥ 95.0. Score is the VMAF score.

---

### 10. Hardlink detection

**Decision**: Track `(device, inode)` tuples during file discovery. If two files share the same inode on the same device, they are hardlinks — skip the second one (don't add to either movie-files or other-files).

**Why**: The spec says "we ignore hardlinks — if possible." Python's `os.stat()` exposes `st_dev` and `st_ino`, making this possible without external tools.

---

### Open questions

- How should the tool handle videos shorter than 5 seconds (no frames sampled)? → Skip hashing, these won't match anything meaningful. Log a warning.
- Should the tool be parallelized (multiple ffmpeg/ffprobe processes)? → Phase 2 is embarrassingly parallel. Use `concurrent.futures.ThreadPoolExecutor` for subprocess calls. Phase 3 comparisons can also be parallelized but O(N²) comparisons mean N is likely small after candidate filtering.

