#!/usr/bin/env python3

#!/usr/bin/env python3
"""
Compute VideoHash for a single video file and store it in an xattr.

Requirements:
    pip install videohash

Linux/macOS:
    Uses os.setxattr / os.getxattr

Usage:
    ./store_videohash_xattr.py /path/to/video.mp4
"""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
import shutil
from pathlib import Path
from PIL import Image

# Must appear before importing videohash
if not hasattr(Image, "ANTIALIAS"):
    Image.ANTIALIAS = Image.Resampling.LANCZOS

from videohash import VideoHash

XATTR_NAME = "user.videohash"


def compute_videohash(video_path: Path) -> str:
    """
    Compute the perceptual hash for a video file and return it as a string.
    """
    vh = VideoHash(path=str(video_path))
    h = vh.hash

    # Be defensive about library return type
    if isinstance(h, bytes):
        return h.decode("utf-8")
    return str(h)


def set_xattr(video_path: Path, attr_name: str, value: str) -> None:
    """
    Store a UTF-8 string value in the file's extended attribute.
    """
    os.setxattr(video_path, attr_name, value.encode("utf-8"))


def get_xattr(video_path: Path, attr_name: str) -> str | None:
    """
    Read a UTF-8 string xattr if present, otherwise return None.
    """
    try:
        raw = os.getxattr(video_path, attr_name)
    except OSError:
        return None
    return raw.decode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compute VideoHash for a video file and store it in an xattr."
    )
    parser.add_argument("video", help="Path to the video file")
    parser.add_argument(
        "--xattr-name",
        default=XATTR_NAME,
        help=f"Extended attribute name to use (default: {XATTR_NAME})",
    )
    parser.add_argument("--force", default=False, help="Update hash even if xattr already exists.")

    args = parser.parse_args()
    video_path = Path(args.video).expanduser().resolve()

    if not video_path.exists():
        print(f"error: file does not exist: {video_path}", file=sys.stderr)
        return 1

    if not video_path.is_file():
        print(f"error: not a regular file: {video_path}", file=sys.stderr)
        return 1

    if get_xattr(video_path, args.xattr_name) is not None and not args.force:
        print(f"exiting early because xattr already exists: {args.xattr_name}")
        return 0

    tempdir = tempfile.mkdtemp()
    tempfile.tempdir = tempdir

    try:
        hash_value = compute_videohash(video_path)
        set_xattr(video_path, args.xattr_name, hash_value)
    except PermissionError as e:
        print(f"permission error: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"os error while setting xattr: {e}", file=sys.stderr)
        return 3
    except Exception as e:
        print(f"failed to compute/store VideoHash: {e}", file=sys.stderr)
        return 4
    finally:
        shutil.rmtree(tempdir, ignore_errors=True)

    print("")
    print(f"   stored {args.xattr_name}={hash_value}")
    print(f"   getfattr -n user.videohash --only-values {video_path}")
    print("")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
