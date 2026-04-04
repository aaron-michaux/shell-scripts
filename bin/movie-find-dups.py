#!/usr/bin/env python3

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


def load_hash(path: Path, attr_name: str):
    try:
        return parse_hash(ensure_videohash(path, attr_name))
    except Exception as e:
        return None

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

def compare(xattr_name: str, video1_: str, video2_: str) -> int:

    try:
        video1 = validate_file(video1_)
        video2 = validate_file(video2_)

        hash1 = ensure_videohash(video1, xattr_name)
        hash2 = ensure_videohash(video2, xattr_name)

        distance = hamming_distance(hash1, hash2)

        return normalized_distance(distance)

    except Exception as e:
        return 99

def find_files(root, excluded):
    return [
        path for path in Path(root).rglob("*")
        if path.is_file() and path.suffix.lower() not in excluded
    ]

def main():
    tempdir = tempfile.mkdtemp()
    tempfile.tempdir = tempdir
    try:
        excluded = {".jpg", ".jpeg", ".png", ".nfo"}
        files = find_files(".", excluded)
        print(f"Loaded {len(files)} files; loading hashes")
        with_hash = [(f, load_hash(f, XATTR_NAME)) for f in files]
        filtered = [(f, h) for f, h in with_hash if h is not None]
        print(f"Loaded hashes")
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())



