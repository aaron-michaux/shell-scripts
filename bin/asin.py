#!/usr/bin/env python3

import json
import sys
import urllib.parse
import urllib.request


def lookup_asin(asin):
    groups = ",".join([
        "contributors",
        "product_attrs",
        "product_extended_attrs",
    ])

    url = (
        f"https://api.audible.com/1.0/catalog/products/{asin}"
        f"?response_groups={urllib.parse.quote(groups)}"
    )

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "asin-lookup/1.0"}
    )

    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)["product"]


def names(items):
    return ", ".join(
        x["name"]
        for x in items or []
        if x.get("name")
    )


asin = sys.argv[1]
p = lookup_asin(asin)

print(f"ASIN:     {p.get('asin')}")
print(f"Title:    {p.get('title')}")
print(f"Subtitle: {p.get('subtitle')}")
print(f"Author:   {names(p.get('authors'))}")
print(f"Narrator: {names(p.get('narrators'))}")
print(f"Publisher:{p.get('publisher_name')}")
print(f"Released: {p.get('release_date')}")
print(f"Language: {p.get('language')}")
print(f"Runtime:  {p.get('runtime_length_min')} minutes")
