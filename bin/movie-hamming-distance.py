#!/usr/bin/env python3
"""
Compare two video files using VideoHash values stored in xattrs.

Behavior:
  1. Reads xattr user.videohash from each file.
  2. If missing, calls ./set-videohash-xattr.py on that file, suppressing stdout.
  3. Computes Hamming distance between the two hashes.
  4. Prints exactly: "hamming distance: X"

Usage:
    ./compare-videohash-xattr.py video1.mp4 video2.mp4
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import shutil
import tempfile
from pathlib import Path
from PIL import Image

# Must appear before importing videohash
if not hasattr(Image, "ANTIALIAS"):
    Image.ANTIALIAS = Image.Resampling.LANCZOS

from videohash import VideoHash

XATTR_NAME = "user.videohash"

# Stop ffmpeg from reading from stdin
sys.stdin = open('/dev/null')

def get_xattr(path: Path, attr_name: str) -> str | None:
    try:
        value = os.getxattr(path, attr_name)
    except OSError:
        return None
    return value.decode("utf-8").strip()


def set_xattr(video_path: Path, attr_name: str, value: str) -> None:
    os.setxattr(video_path, attr_name, value.encode("utf-8"))


def compute_videohash(video_path: Path) -> str:
    vh = VideoHash(path=str(video_path))
    h = vh.hash
    # Be defensive about library return type
    if isinstance(h, bytes):
        return h.decode("utf-8")
    return str(h)


def ensure_videohash(path: Path, attr_name: str) -> str:
    value = get_xattr(path, attr_name)
    if value:
        return value
    set_xattr(path, attr_name, compute_videohash(path))
    value = get_xattr(path, attr_name)
    if not value:
        raise RuntimeError(f"{attr_name} still missing after running {script_path} on {path}")
    return value


def parse_hash(hash_str: str) -> int:
    """
    Parse a VideoHash string into an integer for Hamming distance.

    Expected common case:
      - hex string like 'ff0a12...'
    Tolerates:
      - optional 0x prefix
      - surrounding whitespace
    """
    s = hash_str.strip().lower()
    if s.startswith("0x"):
        return int(s[2:], 16)
    elif s.startswith("0b"):
        return int(s[2:], 2)
    return int(s, 16)


def hamming_distance(a: str, b: str) -> int:
    a_int = parse_hash(a)
    b_int = parse_hash(b)
    return (a_int ^ b_int).bit_count()


def validate_file(path_str: str) -> Path:
    path = Path(path_str).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"file does not exist: {path}")
    if not path.is_file():
        raise ValueError(f"not a regular file: {path}")
    return path

DISTANCE_THRESHOLDS = [
    (5,  "Almost certainly same video"),
    (10, "Very likely same content"),
    (20, "Possibly same, altered"),
    (30, "Weak similarity"),
    (float("inf"), "Different"),
]

def normalized_distance(d: int) -> int:
    if d < 0:
        raise ValueError("distance cannot be negative")

    counter = 0
    for threshold, label in DISTANCE_THRESHOLDS:
        if d <= threshold:
            return counter
        counter += 1

def interpret_distance(d: int) -> str:
    """
    Convert Hamming distance into a human-readable interpretation.
    """
    return DISTANCE_THRESHOLDS[normalized_distance(d)][1]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare two videos using VideoHash values stored in xattrs."
    )
    parser.add_argument("video1", help="First video file")
    parser.add_argument("video2", help="Second video file")
    parser.add_argument(
        "--xattr-name",
        default=XATTR_NAME,
        help=f"xattr name to read/write (default: {XATTR_NAME})",
    )
    parser.add_argument("--with-exit-code", default=False, help="Will exit [0-5] depending on similarity, with exit 0 the most similar.")
    args = parser.parse_args()

    tempdir = tempfile.mkdtemp()
    tempfile.tempdir = tempdir

    try:
        video1 = validate_file(args.video1)
        video2 = validate_file(args.video2)

        hash1 = ensure_videohash(video1, args.xattr_name)
        hash2 = ensure_videohash(video2, args.xattr_name)

        distance = hamming_distance(hash1, hash2)

        print(f"hamming distance: {distance} / 64 => {interpret_distance(distance)}")
        if args.with_exit_code:
            return normalized_distance(distance)
        return 0

    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 99

    finally:
        shutil.rmtree(tempdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
