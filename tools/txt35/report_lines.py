"""Compare the two move_lines.gd dumps and print the complete Markdown inventory."""

import argparse
import json
from pathlib import Path
import re
import sys

DUMP_PREFIX = "TXT35 MOVES "
INVALID_SEPARATOR = re.compile(r"^\s*·|·\s*$|·\s*·|:\s*·|\bSummon\s*·")


def read_dump(path):
    return json.loads(next(line.removeprefix(DUMP_PREFIX) for line in path.read_text().splitlines()
                           if line.startswith(DUMP_PREFIX)))


def cell(text):
    return "`" + text.replace("|", "\\|").replace("\n", " ") + "`"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    args = parser.parse_args()
    catalog = json.loads(Path(__file__).resolve().parents[2].joinpath("data/enemies.json").read_text())
    before, after = read_dump(args.before), read_dump(args.after)
    assert before.keys() == after.keys() == catalog.keys(), "Enemy inventory changed"

    changed, total = 0, 0
    print("| Enemy / intent | Before | After | Changed |")
    print("| --- | --- | --- | --- |")
    for enemy_id, new_lines in after.items():
        old_lines = before[enemy_id]
        intents = catalog[enemy_id].get("intents", [])
        assert len(old_lines) == len(new_lines) == len(intents), enemy_id
        if not new_lines:
            print(f"| {enemy_id} | No intents | No intents | |")
        for old, new, intent in zip(old_lines, new_lines, intents):
            assert old["id"] == new["id"] == intent["id"], enemy_id
            assert old["name"] == new["name"] == intent["name"], enemy_id
            text = new["text"]
            assert text.strip() and not INVALID_SEPARATOR.search(text), (enemy_id, intent["id"], text)
            if "known_summary" in intent:
                assert text == intent["known_summary"], (enemy_id, intent["id"], text)
            differs = old["text"] != text
            changed += differs
            total += 1
            name = f'{enemy_id} / {intent["name"]} (`{intent["id"]}`)'
            print(f"| {name} | {cell(old['text'])} | {cell(text)} | {'Yes' if differs else ''} |")
    print(f"TXT35 MOVE LINES: PASS ({len(after)} enemies, {total} moves, {changed} changed)", file=sys.stderr)


if __name__ == "__main__":
    main()
