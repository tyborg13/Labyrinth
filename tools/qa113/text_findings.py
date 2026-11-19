#!/usr/bin/env python3
"""Distill QA-112's inventory into the four QA-113 wording checks."""

import argparse
from collections import Counter
import csv
from functools import cache
import json
from pathlib import Path
import re
import subprocess
import sys

QA112 = Path(__file__).resolve().parents[1] / "qa112"
sys.path.insert(0, str(QA112))
from audit import glossary_data

MASTER = "047c5848f"
PATTERNS = {
    "HP": re.compile(r"\bHP\b"),
    "foe": re.compile(r"\bfoes?\b", re.IGNORECASE),
    "curly quote": re.compile("[‘’“”]"),
    "double space": re.compile(r"(?<=\S) {2,}(?=\S)"),
}
# General nouns can be legitimate outside the vocabulary's rules sense.
RESOURCE_TERMS = {"Health", "Embers", "Card Plays", "Movement", "Defiance"}


@cache
def baseline(path):
    result = subprocess.run(("git", "show", f"{MASTER}:{path}"), capture_output=True, check=False)
    return result.stdout.decode("utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inventory", type=Path)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    _, keywords = glossary_data()
    alternates = sorted(keywords | RESOURCE_TERMS, key=lambda term: (-len(term), term))
    lower_terms = re.compile(r"(?<![\w])(?:" + "|".join(re.escape(term.lower()) for term in alternates) + r")(?![\w])")
    counts = Counter()
    with (args.inventory.open(encoding="utf-8", newline="") as source,
          args.ledger.open("w", encoding="utf-8", newline="") as output):
        columns = ("check", "evidence", "surface", "location", "matched", "copy", "master_same_literal")
        writer = csv.DictWriter(output, columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in csv.DictReader(source, delimiter="\t"):
            plain = json.loads(row["plain text"])
            raw = json.loads(row["raw text"])
            matches = [(check, match[0]) for check, pattern in PATTERNS.items() for match in pattern.finditer(plain)]
            matches.extend(("lowercase game term candidate", match[0]) for match in lower_terms.finditer(plain))
            if not matches:
                continue
            path = row["location"].split(":", 1)[0]
            comparable = path.startswith(("scripts/", "scenes/", "data/"))
            old = baseline(path) if comparable else ""
            same = ("yes" if raw in old or json.dumps(raw, ensure_ascii=False)[1:-1] in old else "no exact literal") if comparable else "runtime witness needed"
            for check, text in matches:
                counts[check, row["evidence"]] += 1
                writer.writerow({"check": check, "evidence": row["evidence"], "surface": row["surface"],
                                 "location": row["location"], "matched": text, "copy": row["plain text"],
                                 "master_same_literal": same})
    for check, evidence in sorted(counts):
        print(f"QA113 TEXT {check} / {evidence}: {counts[check, evidence]}")
    print(f"QA113 TEXT LEDGER: {sum(counts.values())} matches in {args.ledger}")


if __name__ == "__main__":
    main()
