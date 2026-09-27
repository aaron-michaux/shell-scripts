#!/usr/bin/env python3

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request
from difflib import SequenceMatcher


SEARCH_URL = "https://openlibrary.org/search.json"


def normalize(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^\w\s]", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, normalize(a), normalize(b)).ratio()


def get_json(url: str):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "isbn-finder/2.0",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def search_work(author: str, title: str, limit=10):
    params = {
        "author": author,
        "title": title,
        "limit": limit,
        "fields": "key,title,author_name,first_publish_year",
    }

    url = SEARCH_URL + "?" + urllib.parse.urlencode(params)

    data = get_json(url)

    return data.get("docs", [])


def score_work(author: str, title: str, doc: dict) -> float:
    title_score = similarity(
        title,
        doc.get("title", ""),
    )

    authors = doc.get("author_name", []) or []

    author_score = (
        max(similarity(author, x) for x in authors)
        if authors
        else 0.0
    )

    return title_score * 0.65 + author_score * 0.35


def fetch_editions(work_key: str):
    url = (
        f"https://openlibrary.org{work_key}"
        "/editions.json?limit=1000"
    )

    return get_json(url).get("entries", [])


def isbn13s(ed: dict) -> list[str]:
    result = []

    for isbn in ed.get("isbn_13", []) or []:
        isbn = re.sub(r"\D", "", isbn)

        if len(isbn) == 13:
            result.append(isbn)

    return sorted(set(result))


def is_audiobook(ed: dict) -> bool:
    bits = [
        ed.get("physical_format", ""),
        ed.get("edition_name", ""),
        ed.get("subtitle", ""),
        ed.get("title", ""),
    ]

    text = " ".join(str(x) for x in bits).lower()

    indicators = (
        "audio",
        "audiobook",
        "audible",
        "mp3",
        "compact disc",
        "audio cd",
        "cassette",
        "unabridged",
    )

    return any(x in text for x in indicators)


def publisher(ed: dict) -> str:
    publishers = ed.get("publishers", []) or []

    if not publishers:
        return "?"

    return ", ".join(publishers)


def publish_date(ed: dict) -> str:
    return ed.get("publish_date") or "?"


def pages(ed: dict) -> str:
    value = (
        ed.get("number_of_pages")
        or ed.get("pagination")
    )

    if value is None:
        return "?"

    return str(value)


def edition_description(ed: dict) -> str:
    values = []

    physical_format = ed.get("physical_format")
    edition_name = ed.get("edition_name")

    if physical_format:
        values.append(str(physical_format))

    if edition_name:
        values.append(str(edition_name))

    # Preserve order while removing duplicates.
    values = list(dict.fromkeys(values))

    return "; ".join(values) or "?"


def clean_field(value, width=None):
    value = str(value).replace("\n", " ").replace("\r", " ")
    value = re.sub(r"\s+", " ", value).strip()

    if width is not None and len(value) > width:
        value = value[:width]

    return value


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Find Open Library editions and ISBN-13 values "
            "for an author/title."
        )
    )

    parser.add_argument("author")
    parser.add_argument("title")

    parser.add_argument(
        "--threshold",
        type=float,
        default=0.78,
        help="Minimum fuzzy work-match score (default: 0.78)",
    )

    args = parser.parse_args()

    try:
        docs = search_work(args.author, args.title)

    except Exception as exc:
        sys.exit(f"Search failed: {exc}")

    ranked = [
        (
            score_work(args.author, args.title, doc),
            doc,
        )
        for doc in docs
    ]

    ranked.sort(
        key=lambda x: x[0],
        reverse=True,
    )

    if not ranked:
        sys.exit("No matching work found.")

    score, work = ranked[0]

    if score < args.threshold:
        sys.exit(
            f"No confident work match: "
            f"score={score:.3f}"
        )

    try:
        editions = fetch_editions(work["key"])

    except Exception as exc:
        sys.exit(f"Could not fetch editions: {exc}")

    rows = []

    for ed in editions:
        isbns = isbn13s(ed)

        if not isbns:
            continue

        for isbn in isbns:
            rows.append(
                {
                    "isbn": isbn,
                    "audio": is_audiobook(ed),
                    "publisher": publisher(ed),
                    "date": publish_date(ed),
                    "edition": edition_description(ed),
                    "pages": pages(ed),
                    "title": (
                        ed.get("title")
                        or work.get("title")
                        or "?"
                    ),
                }
            )

    if not rows:
        sys.exit("No ISBN-13 editions found.")

    #
    # Audiobooks first, then publication date, then ISBN.
    #
    rows.sort(
        key=lambda x: (
            not x["audio"],
            str(x["date"]),
            x["isbn"],
        )
    )

    seen = set()

    for row in rows:
        key = (
            row["isbn"],
            row["publisher"],
            row["date"],
            row["edition"],
        )

        if key in seen:
            continue

        seen.add(key)

        audio = "AUDIO" if row["audio"] else ""

        isbn = clean_field(row["isbn"])
        date = clean_field(row["date"], 18)
        pub = clean_field(row["publisher"], 32)
        edition = clean_field(row["edition"], 28)
        pages_value = clean_field(row["pages"], 8)
        title = clean_field(row["title"])

        print(
            f"{audio:<6} "
            f"{isbn:<13} "
            f"{date:<18} "
            f"{pub:<32} "
            f"{edition:<28} "
            f"{pages_value:>8} "
            f"{title}"
        )


if __name__ == "__main__":
    main()
