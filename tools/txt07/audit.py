#!/usr/bin/env python3
"""Inventory and verify the txt-07 copy audit against the production sources."""

import argparse
from collections import Counter
from dataclasses import dataclass
from functools import lru_cache
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORD_LIMIT = 22
TOKEN = re.compile(r'@[a-z_]+\(([^()]*)\)')
FORMAT = re.compile(r"%(?:\.\d+)?[dsf]|\{[\w.]+\}")
PLURAL = re.compile(r"(?<=[A-Za-z])%s\b")
CODE_LINK = re.compile(r"\]\(\.\./\.\./([^#)]+)#L(\d+)\)")
WORD = re.compile(r"[+-]?\d+(?:\.\d+)?[%+]?|[^\W\d_]+(?:['’\-][^\W\d_]+)*", re.UNICODE)
CAVEAT = re.compile(r"\b(?:but|unless|except|not when|only if|instead|however)\b|[()]", re.I)
LITERAL = re.compile(r'"(?:[^"\\]|\\.)*"')


@lru_cache(maxsize=None)
def read_json(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


@lru_cache(maxsize=None)
def source_lines(path):
    return (ROOT / path).read_text(encoding="utf-8").splitlines()


@lru_cache(maxsize=1)
def glossary_names():
    return {entry["id"]: entry["name"] for entry in read_json("data/glossary.json")}


def concept_text(match):
    key, separator, label = match[1].partition("|")
    return label if separator else glossary_names().get(key, key.replace("_", " "))


@dataclass(frozen=True)
class Line:
    source: str
    surface: str
    text: str

    @property
    def visible(self):
        return TOKEN.sub(concept_text, self.text)

    @property
    def word_count(self):
        return len(WORD.findall(FORMAT.sub("0", PLURAL.sub("", self.visible))))

    @property
    def flags(self):
        text = re.sub(r"\.(?=\d)", "", self.visible)
        sentences = [part for part in re.split(r"[.!?]+(?:\s+|$)", text) if WORD.search(part)]
        reasons = []
        if len(sentences) > 1:
            reasons.append("multiple sentences")
        matches = dict.fromkeys(
            "parentheses" if match[0] in "()" else match[0].lower()
            for match in CAVEAT.finditer(text)
        )
        if matches:
            reasons.append("caveat (" + ", ".join(matches) + ")")
        if self.word_count > WORD_LIMIT:
            reasons.append(">22 words")
        return reasons


def data_lines():
    def walk(value, path=()):
        if isinstance(value, dict):
            for key, child in value.items():
                yield from walk(child, (*path, key))
        elif isinstance(value, list):
            for index, child in enumerate(value):
                key = child.get("id", index) if isinstance(child, dict) else index
                yield from walk(child, (*path, str(key)))
        elif isinstance(value, str):
            yield path, value

    selectors = {
        "battlefield_rules": {"sentence": "Battlefield rule HUD and turn rail"},
        "special_encounters": {
            "tooltip_line": "Section map room tooltip", "text": "Special encounter rule/order",
            "objective_description": "Objective tooltip", "rule_line": "Battlefield rule HUD",
            "reward_line": "Special room bonus preview", "tooltip": "Brazier tile tooltip",
            "break_line": "Special encounter rule feedback",
        },
        "glossary": {"definition": "Glossary, keyword and status tooltips"},
        "grimoire": {"summary": "Grimoire navigation tooltip"},
        "enemies": {"description": "Enemy move description", "tooltip": "Enemy intent tooltip"},
        "events": {"description": "Omen badge and Grimoire"},
        "skills": {"description": "Skill inspection and HUD skill popover"},
        "relics": {"description": "Run HUD relic tooltip and relic inspection"},
    }
    for file, fields in selectors.items():
        data = read_json(f"data/{file}.json")
        if file == "relics":
            data = {key: entry for key, entry in data.items() if not entry.get("retired", False)}
        for path, value in walk(data):
            if file == "events" and path[0] != "omens":
                continue
            if path[-1] in fields:
                yield Line(f"data/{file}.json#{'.'.join(path)}", fields[path[-1]], value)


def script_lines():
    # Each selector identifies a template, one alternative, or adjacent
    # literals that form a single body. Indices refer to quoted strings.
    for row in read_json("tools/txt07/sources.json"):
        file, key, surface, *locations = row

        def literal(location):
            line, index, *override = location
            path = override[0] if override else file
            return json.loads(LITERAL.findall(source_lines(path)[line - 1])[index])

        text = ""
        for location in locations:
            if isinstance(location, str):
                text += location
            elif isinstance(location, dict):
                before, marker, after = text.rpartition("%s")
                assert marker, (file, key)
                text = before + literal(location["replace_last"]) + after
            else:
                text += literal(location)
        yield Line(f"{file}:{locations[0][0]}#{key}", surface, text)


def inventory():
    lines = list(data_lines()) + list(script_lines())
    assert len(lines) == len({line.source for line in lines}), "Duplicate inventory source"
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", action="store_true", help="Print all inventoried source lines")
    parser.add_argument("--flagged", action="store_true", help="Print flagged source lines and counts")
    args = parser.parse_args()
    lines = inventory()
    flagged = [line for line in lines if line.flags]
    if args.inventory or args.flagged:
        for line in flagged if args.flagged else lines:
            print(f"{line.source}\t{line.word_count}\t{'; '.join(line.flags)}\t{json.dumps(line.text, ensure_ascii=False)}")
        return
    check_report(lines, flagged)


def check_report(lines, flagged):
    expected = {line.source: line for line in flagged}
    seen = set()
    verdicts = ("false", "incomplete", "true")
    counts = Counter()
    previous = -1
    rechecked = set()
    in_recheck = False
    by_source = {line.source: line for line in lines}
    for row in source_lines("tools/txt07/REPORT.md"):
        if row == "## Rechecked txt-07 contradictions":
            in_recheck = True
        if not row.startswith("| `"):
            continue
        source, surface, exact, words, flags, verdict, exceptions = row[2:-2].split(" | ")
        source = source.strip("`")
        line = by_source[source]
        assert surface == line.surface, source
        assert exact == quote(line.text), source
        assert words == str(line.word_count), source
        assert flags == ("; ".join(line.flags) or "—"), source
        label = verdict.split(" — ", 1)[0]
        references = CODE_LINK.findall(verdict)
        assert references and exceptions, source
        for path, number in references:
            assert 1 <= int(number) <= len(source_lines(path)), (source, path, number)
        if in_recheck:
            assert source not in rechecked and label == "true", source
            rechecked.add(source)
            continue
        assert source in expected and source not in seen, source
        assert verdicts.index(label) >= previous, source
        previous = verdicts.index(label)
        counts[label] += 1
        seen.add(source)
    assert seen == expected.keys(), f"Missing verdicts: {sorted(expected.keys() - seen)}"
    assert len(rechecked) == 7, "Expected six rechecked lines plus the second Lob variant"
    print(f"Inventory: {len(lines)} lines. Flagged report rows verified: {len(seen)} "
          f"({', '.join(f'{counts[v]} {v}' for v in verdicts)}).")
    print("Verified revised copy for six txt-07 rows and the second Lob variant.")


def quote(text):
    return "`" + text.replace("|", r"\|").replace("\n", r"\n") + "`"


if __name__ == "__main__":
    main()
