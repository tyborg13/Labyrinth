#!/usr/bin/env python3
"""Generate the QA-112 text inventory and complete per-location findings."""
import argparse
from collections import Counter, defaultdict
import csv
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
from inventory import ROOT, clean_text, formatted_rows, observation_rows, sources

# Ordered by exposure. Physical node paths and data pointers stay in the ledgers.
VISIBILITY = (
    ("In combat", ("combat objectives", "HUD labels", "combat log", "card panel", "card rules",
                   "card name", "room rules", "room rules and pattern tooltips", "status/condition tooltip",
                   "enemy intents and traits", "intent label/tooltip", "card tooltip", "keyword tooltip",
                   "glossary and shared tooltips", "enemy name/tooltip")),
    ("Combat entry and rewards", ("pre-battle", "reward screen", "relics and items", "relic tooltip",
                                  "relic name", "relic description", "map node")),
    ("Run setup and occasional rooms", ("event body", "event choice", "event title", "shop",
                                        "opening boons", "campfire", "special encounters",
                                        "onboarding/tutorial", "dialogue", "equipment", "skills")),
    ("Menus and reference screens", ("menus/settings", "confirmation dialogs", "error/empty states",
                                     "Grimoire", "grimoire", "card flavour")),
    ("Run end and archive", ("run-end recap", "chronicle")),
)
RANK = {surface: index for index, (_, names) in enumerate(VISIBILITY) for surface in names}
KINDS = ("data", "source", "formatted", "observed")
CONCEPTS = {
    "Health": r"health|hp|hit points?",
    "Embers": r"embers?",
    "Block": r"block",
    "Stoneskin": r"stone[ -]?skin",
    "Card Plays": r"card plays?|plays? per turn|play slots?|play points?",
    "Movement": r"movement|move points?|movement points?|move allowance",
    "Time": r"time cost|time units?|time",
    "Enemy": r"enem(?:y|ies)|foes?",
    "Outcrop": r"outcrops?",
    "Electrified": r"electrified|electrification",
    "Magick": r"magicks?|magic",
}
CHECKS = (
    ("Numbers and units", "damage", r"(?:\b\d+|%d|\{\w+\})\s+([Dd][Aa][Mm][Aa][Gg][Ee])\b", 1),
    ("Numbers and units", "multiplier", r"(?<![A-Za-z_])([xX×])(?=\s*(?:\d|%d|\{\w+\}))", 1),
    ("Numbers and units", "signed numeral", r"(?<![\w+])([+−-][ \u00a0\u202f]*)(?=(?:\d+\b|%d|\{\w+\}))", 1),
    ("Numbers and units", "range delimiter", r"(?:\b\d+|%d)\s*([-–—]|to)\s*(?:\d+\b|%d)", 1),
    ("Numbers and units", "numeric Health unit", r"(?:\b\d+|%d|\{\w+\})(?:\s*/\s*(?:\d+|%d))?\s+((?i:health|hp|hit points?))\b", 1),
    ("Numbers and units", "Health unit prefix", r"\b((?i:health|hp|hit points?))\s+(?=(?:\d+|%d)\s*/)", 1),
    ("Numbers and units", "fraction spacing", r"(?:\b\d+|%d)([ \u00a0]*/[ \u00a0]*)(?:\d+\b|%d)", 1),
    ("Typography", "repeated interior space", r"(?<=\S) {2,}(?=\S)", 0),
    ("Typography", "trailing spaces", r"[ \t]+(?=\n|\Z)", 0),
    ("Typography", "trailing line break", r"\n\Z", 0),
    ("Typography", "apostrophe", r"(?<=\w)['’](?=\w)", 0),
    ("Typography", "quotation marks", r"""["“”‘]|(?<!\w)'(?=\w)|(?<=\w)'(?!\w)""", 0),
    ("Typography", "ellipsis", r"(?<!\.)\.{3}(?!\.)|…", 0),
    ("Typography", "prose dash", r"(?<= )[-–—](?= )|(?<=\w)[–—](?=\w)", 0),
    ("Leak candidates", "parameter", r"(?<!%)%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdifxXocve](?![A-Za-z])|\{(?:[\w.]+)?\}", 0),
    ("Leak candidates", "angle-bracket placeholder", r"<(?:n|card|damage|Count|Relic effect|Element|Item|starter piece|Relic)>", 0),
    ("Leak candidates", "bracket tag", r"\[/?[A-Za-z][\w-]*(?:=[^\]]*)?\]", 0),
    ("Leak candidates", "unresolved inline token", r"@(?:kw|term|icon|pattern)\([^()]*\)", 0),
    ("Leak candidates", "internal identifier", r"\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b", 0),
    ("Leak candidates", "debug or TODO", r"\b(?:TODO(?:_[A-Z0-9_]+)?|FIXME|DEBUG|ERROR_[A-Z0-9_]+|dev only|test fixture|intentionally blank)\b", 0),
)
REGIONAL = {
    "armor / armour": r"armou?rs?",
    "color / colour": r"colou?rs?|colou?red|colou?ring",
    "defense / defence": r"defen[sc]es?|defen[sc]ive",
    "center / centre": r"cent(?:er|re)s?|cent(?:er|re)d|cent(?:er|re)ing",
    "neighbor / neighbour": r"neighbou?r(?:s|ing|hood)?",
    "behavior / behaviour": r"behaviou?rs?",
    "gray / grey": r"gr[ae]ys?",
    "traveled / travelled": r"travell?(?:ed|ing|ers?)",
    "canceled / cancelled": r"cancell?(?:ed|ing)",
    "labeled / labelled": r"labell?(?:ed|ing)",
    "favorite / favourite": r"favou?rites?",
    "honor / honour": r"honou?r(?:s|ed|ing)?",
    "toward / towards": r"towards?",
    "catalog / catalogue": r"catalog(?:ue)?s?",
    "flavor / flavour": r"flavou?rs?",
    "meter / metre": r"met(?:er|re)s?",
    "recognize / recognise": r"recogni[sz](?:e[sd]?|ing)",
    "summarize / summarise": r"summari[sz](?:e[sd]?|ing)",
    "learned / learnt": r"learned|learnt",
    "practice / practise": r"practi[sc](?:e[sd]?|ing)",
    "realize / realise": r"reali[sz](?:e[sd]?|ing)",
}
WORD = re.compile(r"\b[A-Za-z]+(?:['’][A-Za-z]+)?\b")
ALLOWLIST = Path(__file__).with_name("spelling_allowlist.txt")


def regex_terms(values):
    return {name: re.compile(rf"(?<!\w)(?:{pattern})(?!\w)", re.IGNORECASE)
            for name, pattern in values.items()}


def glossary_data():
    entries = json.loads((ROOT / "data/glossary.json").read_text(encoding="utf-8"))
    names = {}
    for entry in entries:
        names[entry["id"]] = entry["name"]
        for alias in entry.get("aliases", []):
            names[alias] = entry["name"]
    return names, {entry["name"] for entry in entries}


def casing(value):
    words = WORD.findall(re.sub(r"(?<=\w)-(?=\w)", "", value))
    if len(words) < 2 or len(words) > 12 or re.search(r"[.!?\n]", value):
        return ""
    if value.isupper():
        return "ALL CAPS"
    if value.islower():
        return "lowercase"
    minor = {"a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"}
    if all(word[0].isupper() or word in minor for word in words):
        return "Title Case"
    if words[0][0].isupper() and all(word.islower() for word in words[1:]):
        return "Sentence case"
    return "Mixed case"


def end_form(line):
    if len(WORD.findall(line)) < 5:
        return ""
    closing = {")", chr(34), chr(39), "’", "”"}
    while line and line[-1] in closing:
        line = line[:-1]
    if line.endswith(("…", "...")):
        return "ellipsis"
    if line.endswith("."):
        return "period"
    if line.endswith(("?", "!", ":", ";")):
        return line[-1]
    return "no terminal punctuation" if line and line[-1].isalnum() else ""


def accepted_word(word, dictionary):
    if word in dictionary:
        return True
    if "'" in word:
        base, suffix = word.split("'", 1)
        return base in dictionary and suffix in {"s", "d", "ll", "m", "re", "t", "ve"}
    for ending in ("ies", "es", "s", "ied", "ed", "ing", "ly", "er", "ers", "est"):
        if word.endswith(ending):
            base = word[:-len(ending)]
            if len(base) < 3:
                continue
            if any(form in dictionary for form in (base, base + "e", base + "y", base[:-1] if base[-1:] == base[-2:-1] else base)):
                return True
    return False


def scan(records, glossary, keywords, dictionary):
    terms = regex_terms(CONCEPTS)
    glossary_forms = regex_terms({name: re.escape(name) for name in sorted(keywords)})
    regional = regex_terms(REGIONAL)
    checks = [(category, concept, re.compile(pattern, re.I if concept == "debug or TODO" else 0), group)
              for category, concept, pattern, group in CHECKS]
    for record in records:
        original = record["text"]
        display = clean_text(original, glossary)
        no_tags = re.sub(r"@\w+\([^()]*\)", "", display)
        prose = record["role"] == "prose" or (len(WORD.findall(no_tags)) >= 5 and bool(re.search(r"[.!?]", no_tags)))
        for category, concept, pattern, group in checks:
            subject = display
            for match in pattern.finditer(subject):
                yield category, concept, match[group], record
        for concept, pattern in terms.items():
            for match in pattern.finditer(no_tags):
                yield "Terminology", concept, match[0], record
        if prose:
            for concept, pattern in glossary_forms.items():
                for match in pattern.finditer(no_tags):
                    yield "Keyword case", concept, match[0], record
        if record["role"] in {"button", "heading", "label"}:
            style = casing(no_tags.strip())
            if style:
                yield "UI case", f'{record["surface"]} / {record["role"]}', style, record
        if record["family"]:
            for line in no_tags.splitlines():
                style = end_form(line.strip())
                if style:
                    yield "Sibling punctuation", record["family"], style, record
        spell_text = re.sub(r"\{[^}]*\}|%[sdif]|\b\w*[_/]\w*\b", " ", no_tags)
        for concept, pattern in regional.items():
            for match in pattern.finditer(spell_text):
                yield "Regional spelling", concept, match[0].lower(), record
        for match in WORD.finditer(spell_text):
            word = match[0].lower().replace("’", "'")
            if len(word) > 2 and not accepted_word(word, dictionary):
                yield "Dictionary candidates", word, word, record


def write_tsv(path, columns, items):
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, delimiter="\t", lineterminator="\n")
        writer.writerow(columns)
        writer.writerows(items)


def shown(value):
    return json.dumps(value, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-log", type=Path, required=True)
    parser.add_argument("--observations", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--dictionary", type=Path, default=Path("/usr/share/dict/web2"))
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    glossary, keywords = glossary_data()
    dictionary = {word.lower() for word in args.dictionary.read_text(encoding="utf-8").splitlines()}
    dictionary.update(word.strip() for word in ALLOWLIST.read_text(encoding="utf-8").splitlines()
                      if word.strip() and not word.startswith("#"))
    records = list(sources()) + list(formatted_rows(args.runtime_log)) + list(observation_rows(args.observations))
    records.sort(key=lambda item: (RANK.get(item["surface"], len(VISIBILITY)), KINDS.index(item["kind"]), item["location"]))
    matches = defaultdict(Counter)
    families = defaultdict(Counter)
    evidence = defaultdict(Counter)
    visibility = {}
    for category, concept, form, record in scan(records, glossary, keywords, dictionary):
        kind = record["kind"]
        matches[(category, concept, form)][kind] += 1
        family = category, concept, "runtime" if kind in ("formatted", "observed") else "source"
        families[family][form] += 1
        rank = RANK.get(record["surface"], len(VISIBILITY)) + 1
        key = category, concept, form
        visibility[key] = min(rank, visibility.get(key, rank))
        evidence[(rank, *key, kind, record["surface"])][record["location"]] += 1
    counts = Counter(r["kind"] for r in records)
    write_tsv(args.output_dir / "inventory.tsv", ("rank", "evidence", "surface", "location", "role", "raw text", "plain text"),
              ((RANK.get(r["surface"], len(VISIBILITY)) + 1, r["kind"], r["surface"], r["location"], r["role"],
                shown(r["text"]), shown(clean_text(r["text"], glossary))) for r in records))
    def dominant(category, concept, scope):
        return ", ".join(f"{shown(form)} ({count})"
                         for form, count in families[(category, concept, scope)].most_common(3))

    write_tsv(args.output_dir / "variants.tsv", ("earliest exposure rank", "class", "check", "variant", *KINDS, "source forms", "runtime forms"),
              ((visibility[(category, concept, form)], category, concept, shown(form),
                *(matches[(category, concept, form)][k] for k in KINDS),
                dominant(category, concept, "source"), dominant(category, concept, "runtime"))
               for category, concept, form in sorted(matches, key=lambda key: (visibility[key], *key))))
    write_tsv(args.output_dir / "locations.tsv", ("rank", "class", "check", "variant", "evidence", "surface", "locations"),
              ((rank, category, concept, shown(form), kind, surface,
                " | ".join(f"{location} [{count}]" if count > 1 else location
                           for location, count in locations.items()))
               for (rank, category, concept, form, kind, surface), locations in sorted(evidence.items())))
    print("QA112 INVENTORY:", ", ".join(f"{counts[k]} {k}" for k in KINDS))
    print(f"QA112 SCAN: {sum(sum(c.values()) for c in matches.values())} matches across {len(matches)} class/check/variant rows")
    print(f"QA112 OUTPUT: {args.output_dir}")


if __name__ == "__main__":
    main()
