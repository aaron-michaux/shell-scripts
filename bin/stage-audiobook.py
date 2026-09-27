#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET


DEFAULT_LIBRARY_BASE = "/home/amichaux/Media/AudioBookshelf/AudioBooks"

DC = "{http://purl.org/dc/elements/1.1/}"

SUBTITLE_SEPARATOR = re.compile(r"\s*[:–—]\s*|\s+-\s+")

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_ISBN_TO_OPF = os.path.join(_SCRIPT_DIR, "isbn-to-opf.py")

_cache = {}


def library_base() -> str:
    return os.environ.get("AUDIO_LIBRARY_BASE", DEFAULT_LIBRARY_BASE)


def safe_name(name: str) -> str:
    name = name.strip().replace("\0", "").replace("/", "-")
    name = re.sub(r"\s+", " ", name)
    name = re.sub(r"[\x00-\x1f\x7f]", "", name)
    name = name.replace("'", "").replace('"', "")
    name = name.lstrip(" .")
    return name.strip()


def short_title(title: str) -> str:
    return safe_name(SUBTITLE_SEPARATOR.split(title, maxsplit=1)[0].strip())


def lookup_isbn(isbn: str) -> bytes:
    if isbn in _cache:
        return _cache[isbn]

    proc = subprocess.run(
        [sys.executable, _ISBN_TO_OPF, isbn],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    if proc.returncode != 0:
        detail = proc.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(
            detail or f"isbn-to-opf.py exited with status {proc.returncode}"
        )

    opf = proc.stdout
    _cache[isbn] = opf
    return opf


def parse_opf(opf: bytes) -> tuple[str, str]:
    try:
        root = ET.fromstring(opf)
    except ET.ParseError as exc:
        raise RuntimeError(f"could not parse OPF from isbn-to-opf.py: {exc}")

    title_el = root.find(f".//{DC}title")
    title = title_el.text if title_el is not None else None
    if not title or not title.strip():
        raise RuntimeError("OPF is missing a title")

    creators = [
        el.text.strip()
        for el in root.findall(f".//{DC}creator")
        if el.text and el.text.strip()
    ]
    if not creators:
        raise RuntimeError("OPF is missing an author")

    author = safe_name(" & ".join(creators))
    if not author:
        raise RuntimeError("could not derive a valid author from OPF")

    short = short_title(title)
    if not short:
        raise RuntimeError("could not derive a valid short title from OPF")

    return author, short


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Stage an audiobook directory under the audiobook library."
    )
    parser.add_argument("isbn", help="ISBN-13 of the book")
    parser.add_argument("directory", help="directory containing the audiobook")
    args = parser.parse_args()

    src = args.directory
    if not os.path.isdir(src):
        print(f"error: not a directory: {src}", file=sys.stderr)
        return 1

    try:
        opf = lookup_isbn(args.isbn)
        author, short = parse_opf(opf)
        target = os.path.join(library_base(), author, short)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if os.path.exists(target):
        print(
            f"error: refusing to overwrite existing title: {target}",
            file=sys.stderr,
        )
        return 1

    try:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.move(src, target)
    except Exception as exc:
        print(f"error: could not move {src} to {target}: {exc}", file=sys.stderr)
        return 1

    metadata = os.path.join(target, "metadata.opf")
    try:
        with open(metadata, "wb") as handle:
            handle.write(opf)
    except Exception as exc:
        print(f"error: could not write metadata.opf: {exc}", file=sys.stderr)
        return 1

    print(target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
