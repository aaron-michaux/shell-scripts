#!/usr/bin/env python3

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET


API_KEY = os.environ.get("ISBNDB_API") or "74291_53d7da8110da34281f8baa1d78e5577c"

ISBNDB_URL = "https://api2.isbndb.com/book/{isbn13}"
OPENLIBRARY_ISBN_URL = "https://openlibrary.org/isbn/{isbn13}.json"

RATE_INTERVAL = 1.5

USER_AGENT = "isbn-to-opf/2.0"


class NotFound(LookupError):
    pass


class RateLimited(LookupError):
    pass


class RateLimiter:
    def __init__(self, interval: float):
        self.interval = interval
        self.last = 0.0

    def wait(self):
        elapsed = time.monotonic() - self.last
        if elapsed < self.interval:
            time.sleep(self.interval - elapsed)
        self.last = time.monotonic()


limiter = RateLimiter(RATE_INTERVAL)


def open_json(url, headers):
    req = urllib.request.Request(url, headers=headers)
    limiter.wait()
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.load(response)


def fetch_isbndb(isbn13: str) -> dict:
    url = ISBNDB_URL.format(isbn13=isbn13)
    headers = {
        "Authorization": API_KEY,
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    }

    try:
        data = open_json(url, headers)
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise RateLimited("ISBNDB rate limited requests; retry later") from exc
        if exc.code in (400, 404):
            raise NotFound(f"ISBNDB has no record for ISBN {isbn13}") from exc
        raise

    book = data.get("book")
    if not book:
        raise NotFound(f"ISBNDB returned no book for ISBN {isbn13}")

    return {
        "title": book.get("title_long") or book.get("title"),
        "author_names": list(book.get("authors") or []),
        "publishers": [book["publisher"]] if book.get("publisher") else [],
        "publish_date": book.get("date_published"),
        "languages": [{"key": "/languages/" + book["language"]}]
        if book.get("language") else [],
        "subjects": list(book.get("subjects") or []),
        "number_of_pages": book.get("pages"),
        "isbn_10": [book["isbn10"]] if book.get("isbn10") else [],
    }


def fetch_openlibrary_author(key: str):
    url = f"https://openlibrary.org{key}.json"
    headers = {"User-Agent": USER_AGENT}
    try:
        return open_json(url, headers).get("name")
    except (urllib.error.URLError, ValueError):
        return None


def fetch_openlibrary(isbn13: str) -> dict:
    url = OPENLIBRARY_ISBN_URL.format(isbn13=isbn13)
    headers = {"User-Agent": USER_AGENT}

    try:
        edition = open_json(url, headers)
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise RateLimited("Open Library rate limited requests; retry later") from exc
        if exc.code == 404:
            raise NotFound(f"Open Library has no record for ISBN {isbn13}") from exc
        raise

    authors = []
    for author in edition.get("authors", []) or []:
        name = author.get("name") if isinstance(author, dict) else None
        key = author.get("key") if isinstance(author, dict) else None
        if key and not name:
            name = fetch_openlibrary_author(key)
        if name:
            authors.append(name)

    return {
        "title": edition.get("title"),
        "author_names": authors,
        "publishers": list(edition.get("publishers") or []),
        "publish_date": edition.get("publish_date"),
        "languages": [
            {"key": language.get("key", "")}
            for language in (edition.get("languages") or [])
            if isinstance(language, dict)
        ],
        "subjects": list(edition.get("subjects") or []),
        "number_of_pages": edition.get("number_of_pages"),
        "isbn_10": list(edition.get("isbn_10") or []),
    }


def fetch_isbn(isbn13: str) -> dict:
    try:
        return fetch_isbndb(isbn13)
    except RateLimited as exc:
        raise LookupError(f"ISBNDB rate limited; retry later: {exc}") from exc
    except (urllib.error.URLError, NotFound) as exc:
        isbndb_error = exc

    try:
        return fetch_openlibrary(isbn13)
    except RateLimited as exc:
        raise LookupError(
            f"ISBNDB ({isbndb_error}); Open Library rate limited; retry later"
        ) from exc
    except (urllib.error.URLError, NotFound) as exc:
        raise LookupError(
            f"ISBNDB ({isbndb_error}); Open Library ({exc})"
        ) from exc


def normalize_isbn(raw: str) -> str:
    return re.sub(r"[\s-]", "", raw)


def isbn13_checksum_ok(digits: str) -> bool:
    if len(digits) != 13 or not digits.isdigit():
        return False
    total = sum(
        (1 if index % 2 == 0 else 3) * int(digit)
        for index, digit in enumerate(digits[:12])
    )
    check = (10 - total % 10) % 10
    return check == int(digits[12])


LANGUAGE_CODES = {
    "english": "en", "french": "fr", "german": "de", "spanish": "es",
    "italian": "it", "portuguese": "pt", "dutch": "nl", "russian": "ru",
    "japanese": "ja", "chinese": "zh", "korean": "ko", "arabic": "ar",
    "greek": "el", "latin": "la", "hebrew": "he", "turkish": "tr",
    "swedish": "sv", "norwegian": "no", "danish": "da", "finnish": "fi",
    "polish": "pl", "czech": "cs", "hungarian": "hu", "romanian": "ro",
    "indonesian": "id", "thai": "th", "vietnamese": "vi", "hindi": "hi",
    "eng": "en", "fre": "fr", "fra": "fr", "ger": "de", "deu": "de",
    "spa": "es", "ita": "it", "por": "pt", "dut": "nl", "nld": "nl",
    "rus": "ru", "jpn": "ja", "chi": "zh", "zho": "zh", "kor": "ko",
    "ara": "ar", "gre": "el", "ell": "el", "lat": "la", "heb": "he",
    "tur": "tr", "swe": "sv", "nor": "no", "dan": "da", "fin": "fi",
    "pol": "pl", "cze": "cs", "ces": "cs", "hun": "hu", "rum": "ro",
    "ron": "ro", "ind": "id", "tha": "th", "vie": "vi", "hin": "hi",
}


def normalize_language(value: str):
    if not value:
        return None
    code = value.strip().lower()
    if not code:
        return None
    return LANGUAGE_CODES.get(code, code)


def add_text(parent, tag, value):
    if value is None:
        return

    if isinstance(value, str):
        value = value.strip()
        if not value:
            return

    el = ET.SubElement(parent, tag)
    el.text = str(value)


def build_opf(isbn13: str, book: dict) -> bytes:
    ET.register_namespace("", "http://www.idpf.org/2007/opf")
    ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

    package = ET.Element(
        "{http://www.idpf.org/2007/opf}package",
        {
            "version": "2.0",
            "unique-identifier": "BookId",
        },
    )

    metadata = ET.SubElement(
        package,
        "{http://www.idpf.org/2007/opf}metadata",
    )

    DC = "http://purl.org/dc/elements/1.1/"

    add_text(metadata, f"{{{DC}}}identifier", isbn13)

    identifier = metadata.findall(f"{{{DC}}}identifier")[-1]
    identifier.set("id", "BookId")

    add_text(metadata, f"{{{DC}}}title", book.get("title"))

    for name in book.get("author_names", []):
        add_text(metadata, f"{{{DC}}}creator", name)

    for publisher in book.get("publishers", []):
        add_text(metadata, f"{{{DC}}}publisher", publisher)

    add_text(metadata, f"{{{DC}}}date", book.get("publish_date"))

    for language in book.get("languages", []):
        key = language.get("key", "") if isinstance(language, dict) else str(language)
        code = normalize_language(key.rsplit("/", 1)[-1])
        add_text(metadata, f"{{{DC}}}language", code)

    for subject in book.get("subjects", []):
        add_text(metadata, f"{{{DC}}}subject", subject)

    if book.get("number_of_pages"):
        ET.SubElement(
            metadata,
            "{http://www.idpf.org/2007/opf}meta",
            {
                "name": "calibre:pages",
                "content": str(book["number_of_pages"]),
            },
        )

    for isbn10 in book.get("isbn_10", []):
        add_text(metadata, f"{{{DC}}}identifier", isbn10)

    ET.indent(package, space="  ")

    return ET.tostring(
        package,
        encoding="utf-8",
        xml_declaration=True,
    )


def self_test() -> int:
    checksum_cases = [
        ("9780679751342", True),
        ("9780306406157", True),
        ("9780679751343", False),
        ("978067975134", False),
        ("97806797513x4", False),
    ]

    failures = []

    for value, expected in checksum_cases:
        digits = normalize_isbn(value)
        result = isbn13_checksum_ok(digits)
        if result != expected:
            failures.append(f"checksum({value!r}) = {result}, expected {expected}")

    language_cases = [
        ("English", "en"),
        ("english", "en"),
        ("EN", "en"),
        ("eng", "en"),
        ("spa", "es"),
        ("deu", "de"),
        ("fr", "fr"),
        ("", None),
        (None, None),
    ]

    for value, expected in language_cases:
        result = normalize_language(value)
        if result != expected:
            failures.append(
                f"language({value!r}) = {result!r}, expected {expected!r}"
            )

    fixture = {
        "title": "Angels & Insects",
        "author_names": ["A. S. Byatt"],
        "publishers": ["Knopf Doubleday"],
        "publish_date": "1994-03-29",
        "languages": [{"key": "/languages/English"}],
        "subjects": ["Fiction", "Literary"],
        "number_of_pages": 352,
        "isbn_10": ["0679751343"],
    }

    opf = build_opf("9780679751342", fixture).decode("utf-8")
    for fragment in (
        'id="BookId"',
        "<dc:title>Angels &amp; Insects</dc:title>",
        "<dc:creator>A. S. Byatt</dc:creator>",
        "<dc:language>en</dc:language>",
        'name="calibre:pages"',
        "<dc:identifier>0679751343</dc:identifier>",
    ):
        if fragment not in opf:
            failures.append(f"OPF missing {fragment!r}")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print(
        f"self-test: {len(checksum_cases)} checksum cases, "
        f"{len(language_cases)} language cases, and OPF build passed"
    )
    return 0


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sys.exit(self_test())

    if len(sys.argv) != 2:
        print(
            f"usage: {sys.argv[0]} ISBN13",
            file=sys.stderr,
        )
        sys.exit(2)

    isbn = normalize_isbn(sys.argv[1])

    if len(isbn) != 13 or not isbn.isdigit():
        print(f"Invalid ISBN-13: {isbn}", file=sys.stderr)
        sys.exit(2)

    if not isbn13_checksum_ok(isbn):
        print(f"Invalid ISBN-13 checksum: {isbn}", file=sys.stderr)
        sys.exit(2)

    try:
        book = fetch_isbn(isbn)
    except (urllib.error.URLError, LookupError, ValueError) as exc:
        print(f"Could not look up ISBN {isbn}: {exc}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.buffer.write(build_opf(isbn, book))
    sys.stdout.buffer.write(b"\n")


if __name__ == "__main__":
    main()
