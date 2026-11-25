"""Ratchet for the rules-text checks in spec/card_text_style.md."""
from __future__ import annotations

import argparse
from collections import Counter
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import re
import sys
import tempfile
from typing import NamedTuple
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASELINE = Path("tests/fixtures/rules_text_lint_baseline.json")
NAME_CATALOGS = ("cards", "relics", "enemies")
RULE_TEXT_FIELDS = {"description", "definition", "sentence", "text", "tooltip"}
RULE_TEXT_SUFFIXES = ("_description", "_text", "_tooltip", "_tooltip_line")
EXTRA_FIELDS = {
    "card_panel_text": {"legacy", "title"},
    "glossary": {"name"},
    "grimoire": {"body", "summary", "title"},
    "special_encounters": {
        "objective_title", "objective_hud_title", "tooltip_line", "rule_line", "reward_line", "break_line",
    },
}
ENEMY_COPY_CONTEXTS = {"intent", "intents", "trait", "traits", "enemy_intents", "enemy_traits"}
ENEMY_COPY_FIELDS = {"body", "summary", "detail", "details", "rules", "tooltip_line", "rule_line"}
NEVER_WORDS = (
    "every", "all", "next to", "around", "beside", "nearby", "surrounding",
    "battle", "fight", "foe", "square", "explode", "blast", "unleash",
    "dispel", "that much", "the shown",
)
ICON_TITLE = re.compile(r'"label"\s*:\s*("(?:[^"\\]|\\.)*")')
INLINE_TOKEN = re.compile(r"@(icon|term|kw|pattern)\(([^()|]+)(?:\|([^()]+))?\)")
DIAGRAM = "\ufffc"
SENTENCE = re.compile(r'''.+?(?:[.!?]+["”’)\]]*(?=\s|$)|$)''', re.MULTILINE)
SHATTER_CARD_REFERENCE = re.compile(r'\b(?:play|draw|discard|copy|exhaust|upgrade|of)\s+["“]?\s*$', re.IGNORECASE)
SHATTER_CARD_PREDICATE = re.compile(r"^\s+(?:deals|hits|costs|gives|adds|applies|targets|is|can|has)\b", re.IGNORECASE)


def words(*values: str) -> re.Pattern:
    alternatives = [r"\s+".join(map(re.escape, value.split())) for value in values]
    return re.compile(r"\b(?:" + "|".join(alternatives) + r")\b", re.IGNORECASE)


VOCABULARY = words(*NEVER_WORDS, "shatter", "shatters")
CUT_VOCABULARY = re.compile(
    r"\b(?:expend(?:s|ed|ing)?|quicken(?:s|ed|ing)?|(?-i:Next\s+Attack)|"
    r"detonate|shatter\s+illusion|truesight|chilled|sunder|frost\s+armor)\b",
    re.IGNORECASE,
)
CHECKS = {
    "sentence_start": re.compile(r"""^[\s"'“‘(\[\ufffc]*(?:it|its|they|them|their|there|here)\b""", re.IGNORECASE),
    "pronoun": words("it", "them", "they"),
    "hedge": words("sometimes", "possibly", "mostly", "simply"),
    "semicolon": re.compile(";"),
    "spaced_dash": re.compile(r" [—-] "),
    # "a unit" and "a one-use card" are correct English: the sound decides, not the letter.
    "article": re.compile(r"\ba\s+(?!one\b|one-|uni|us[aeiou]|eu)[aeiou][^\W\d_]*\b", re.IGNORECASE),
}
RULES = (*CHECKS, "vocabulary", "cut_vocabulary")


class Hit(NamedTuple):
    file: str
    key: str
    rule: str
    sentence: str


def json_pointer(path: tuple[str, ...]) -> str:
    return "".join("/" + part.replace("~", "~0").replace("/", "~1") for part in path)


def string_leaves(value, path=()):
    if isinstance(value, dict):
        for key, child in value.items():
            if not key.startswith("_"):
                yield from string_leaves(child, (*path, key))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from string_leaves(child, (*path, str(index)))
    elif isinstance(value, str):
        yield path, value


def face_sentence(segments: list[dict]) -> str:
    parts = []
    for segment in segments:
        if "text" in segment:
            parts.append(segment["text"])
        elif "term" in segment:
            number = segment.get("number")
            parts.append(segment["word"] + (f" {segment.get('display', number)}" if number is not None else ""))
        elif "pattern" in segment:
            parts.append(DIAGRAM)
        elif "number" in segment and "damage" not in segment:
            parts.append(str(segment.get("display", segment["number"])))
        elif "damage" in segment or "duration" in segment:
            prefix = "+" if segment.get("bonus") else ""
            parts.append(prefix + str(segment.get("display", segment.get("number", segment.get("duration")))))
    return "".join(parts)


def rules_strings(file: Path, data):
    if file == Path("card_faces.json"):
        for card, face in data.items():
            if "sentence" in face:
                yield (card, "sentence"), face_sentence(face["sentence"])
        return
    if file == Path("pattern_rule_text.json"):
        # The keys match source lines. Only the replacement values are copy here.
        for source, text in data["copy"].items():
            yield ("copy", source), text
        return

    extra_fields = EXTRA_FIELDS.get(file.stem, set())
    for path, text in string_leaves(data):
        field = next((part for part in reversed(path) if not part.isdecimal()), "")
        in_enemy_copy = (
            file.stem in ENEMY_COPY_CONTEXTS or ENEMY_COPY_CONTEXTS.intersection(path)
        )
        is_enemy_copy = in_enemy_copy and (
            field in ENEMY_COPY_FIELDS or (field in ENEMY_COPY_CONTEXTS and not text.isidentifier())
        )
        if field in RULE_TEXT_FIELDS or field.endswith(RULE_TEXT_SUFFIXES) or field in extra_fields or is_enemy_copy:
            if file.stem == "card_panel_text" and field == "legacy":
                title, _, body = text.partition("\n")
                if title == data[path[0]].get("title"):
                    text = body
            yield path, text


def visible_text(text: str, terms: dict[str, str]) -> str:
    def replace(match: re.Match) -> str:
        kind, key, word = match.groups()
        if kind in ("pattern", "icon"):
            return DIAGRAM
        return word or terms.get(key.lower(), key)

    return INLINE_TOKEN.sub(replace, text)


def name_pattern(names: set[str]) -> re.Pattern:
    # Only names containing a banned word can affect the vocabulary check.
    # "Shatter" is both a card and a verb; its use needs context.
    relevant = [name for name in names if name.casefold() != "shatter"
                and (VOCABULARY.search(name) or CUT_VOCABULARY.search(name))]
    return words(*sorted(relevant, key=lambda name: (-len(name), name))) if relevant else re.compile(r"(?!)")


# "after every second Slagmaster turn" is a timing idiom, not a substitute for "each".
TIMING_EVERY = re.compile(r"\bevery (?:second|third|other)\b", re.IGNORECASE)


def has_banned_vocabulary(sentence: str, names: re.Pattern, has_shatter_card: bool,
                          pattern: re.Pattern = VOCABULARY) -> bool:
    name_spans = [match.span() for match in names.finditer(sentence)]
    sentence = TIMING_EVERY.sub(lambda found: " " * len(found[0]), sentence)
    for match in pattern.finditer(sentence):
        if any(start <= match.start() and end >= match.end() for start, end in name_spans):
            continue
        if has_shatter_card and match[0] == "Shatter":
            before = sentence[:match.start()]
            after = sentence[match.end():]
            if (not after.strip(" .!?’'”\"),;") or SHATTER_CARD_REFERENCE.search(before)
                    or SHATTER_CARD_PREDICATE.match(after)):
                continue
        return True
    return False


def scan(root: Path) -> Counter[Hit]:
    data_root = root / "data"
    catalogs = {
        file.relative_to(data_root): json.loads(file.read_text(encoding="utf-8"))
        for file in sorted(data_root.rglob("*.json"))
    }
    names = {
        entry["name"] for catalog in NAME_CATALOGS
        for entry in catalogs.get(Path(catalog + ".json"), {}).values() if "name" in entry
    }
    terms = {}
    for entry in catalogs.get(Path("glossary.json"), []):
        for key in (entry["id"], entry["name"], *entry.get("aliases", [])):
            terms[key.lower()] = entry["name"]
    proper_names = name_pattern(names)
    has_shatter_card = "Shatter" in names
    hits = Counter()
    icon_file = Path("scripts/action_icon_library.gd")
    if (root / icon_file).is_file():
        icon_code = (root / icon_file).read_text(encoding="utf-8")
        for match in ICON_TITLE.finditer(icon_code):
            title = json.loads(match[1])
            if has_banned_vocabulary(title, proper_names, has_shatter_card, CUT_VOCABULARY):
                line = icon_code.count("\n", 0, match.start()) + 1
                hits[Hit(icon_file.as_posix(), str(line), "cut_vocabulary", title)] += 1
    for file, data in catalogs.items():
        source = (Path("data") / file).as_posix()
        for path, text in rules_strings(file, data):
            key = json_pointer(path)
            title_only = (file.stem in {"card_panel_text", "grimoire"} and path[-1] == "title"
                          or file.stem == "glossary" and path[-1] == "name")
            for match in SENTENCE.finditer(visible_text(text, terms)):
                sentence = match[0].strip()
                if not title_only:
                    for rule, pattern in CHECKS.items():
                        if pattern.search(sentence):
                            hits[Hit(source, key, rule, sentence)] += 1
                    if has_banned_vocabulary(sentence, proper_names, has_shatter_card):
                        hits[Hit(source, key, "vocabulary", sentence)] += 1
                if has_banned_vocabulary(sentence, proper_names, has_shatter_card, CUT_VOCABULARY):
                    hits[Hit(source, key, "cut_vocabulary", sentence)] += 1
    return hits


def read_baseline(path: Path) -> Counter[Hit]:
    return Counter(Hit(**entry) for entry in json.loads(path.read_text(encoding="utf-8")))


def write_baseline(path: Path, hits: Counter[Hit]) -> None:
    rows = [json.dumps(hit._asdict(), ensure_ascii=False) for hit in sorted(hits.elements())]
    with tempfile.NamedTemporaryFile(dir=path.parent, mode="w", encoding="utf-8", newline="\n", delete=False) as temp:
        pending = Path(temp.name)
        try:
            temp.write("[\n" + ",\n".join("  " + row for row in rows) + "\n]\n" if rows else "[]\n")
            temp.close()
            pending.replace(path)
        finally:
            pending.unlink(missing_ok=True)


def loose(hits: Counter[Hit]) -> Counter:
    """Hits ignoring the JSON path: data entries move when catalogs are reordered."""
    return Counter((hit.file, hit.rule, hit.sentence) for hit in hits.elements())


def check(root: Path, *, update: bool = False) -> int:
    path = root / BASELINE
    baseline = Counter({hit: count for hit, count in read_baseline(path).items()
                        if hit.rule != "cut_vocabulary"})
    hits = scan(root)
    added_ids = loose(hits) - loose(baseline)
    added = Counter(hit for hit in hits.elements() if (hit.file, hit.rule, hit.sentence) in added_ids)
    if added:
        print(f"FAIL: Rules text lint ({sum(added.values())} new hits)")
        for hit in sorted(added.elements()):
            print(f"{hit.file} {hit.key}: {hit.rule}: {hit.sentence}")
        if update:
            print("Refusing to add hits to the baseline.")
        return 1
    removed = sum((loose(baseline) - loose(hits)).values())
    if update:
        write_baseline(path, hits)
        print(f"Updated rules text baseline ({removed} removed)")
    elif removed:
        print(f"{removed} baseline hits are gone. Run python3 tests/test_rules_text_lint.py --update.")
    counts = Counter(hit.rule for hit in hits.elements())
    print(f"PASS: Rules text lint ({sum(hits.values())} existing hits)")
    print("Hits by rule: " + ", ".join(f"{rule}={counts[rule]}" for rule in RULES))
    return 0


class RulesTextLintTests(unittest.TestCase):
    def test_project_data_against_baseline(self) -> None:
        self.assertEqual(check(ROOT), 0)

    def test_rules_and_visible_tokens(self) -> None:
        catalogs = {
            "cards.json": {"shatter": {"name": "Shatter"}, "shatter_swing": {"name": "Shatter Swing"}},
            "glossary.json": [{"id": "stone", "name": "Outcrop"}],
            "card_faces.json": {"test_face": {"sentence": [
                {"text": "Push next "}, {"term": "fixture", "word": "to", "number": None},
                {"text": " a "}, {"term": "stone", "word": "Outcrop", "number": None}, {"text": "."},
            ]}},
            "card_panel_text.json": {"test_panel": {"title": "Next Attack"}},
            "variants/enemy_traits.json": {"test_enemy": {
                "_doc": "It is internal.",
                "traits": [
                    {"detail": "It simply hits them; then it hits a @term(stone) — twice."},
                    "They hit - twice.",
                ],
                "description": "Play Shatter. Shatter Swing deals damage. Shatter the Outcrop. Refit a battlefield tile.",
            }},
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, catalog in catalogs.items():
                path = root / "data" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(catalog), encoding="utf-8")
            icon_table = root / "scripts/action_icon_library.gd"
            icon_table.parent.mkdir()
            icon_table.write_text('{"label": "Expended"}\n{"label": "next attack"}\n', encoding="utf-8")
            hits = scan(root)

        face = "data/card_faces.json", "/test_face/sentence"
        enemy = "data/variants/enemy_traits.json"
        trait = enemy, "/test_enemy/traits/0/detail"
        trait_sentence = "It simply hits them; then it hits a Outcrop — twice."
        expected = [
            Hit(*face, rule, "Push next to a Outcrop.") for rule in ("vocabulary", "article")
        ] + [
            Hit(*trait, rule, trait_sentence)
            for rule in ("sentence_start", "pronoun", "hedge", "semicolon", "spaced_dash", "article")
        ] + [
            Hit(enemy, "/test_enemy/traits/1", rule, "They hit - twice.")
            for rule in ("sentence_start", "pronoun", "spaced_dash")
        ] + [
            Hit(enemy, "/test_enemy/description", "vocabulary", "Shatter the Outcrop."),
            Hit("data/card_panel_text.json", "/test_panel/title", "cut_vocabulary", "Next Attack"),
            Hit("scripts/action_icon_library.gd", "1", "cut_vocabulary", "Expended"),
        ]
        self.assertEqual(hits, Counter(expected))

    def test_update_prunes_only_after_a_clean_check(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "data/cards.json"
            path.parent.mkdir()
            baseline = root / BASELINE
            baseline.parent.mkdir(parents=True)
            hit = Hit("data/cards.json", "/example/description", "vocabulary", "Hit every enemy.")
            write_baseline(baseline, Counter({hit: 1}))
            original = baseline.read_bytes()
            path.write_text(json.dumps({"example": {"description": "Hit all enemies."}}), encoding="utf-8")
            output = io.StringIO()
            with redirect_stdout(output):
                self.assertEqual(check(root, update=True), 1)
            self.assertIn("data/cards.json /example/description: vocabulary: Hit all enemies.", output.getvalue())
            self.assertEqual(baseline.read_bytes(), original)
            path.write_text(json.dumps({"example": {"description": "Hit each enemy."}}), encoding="utf-8")
            with redirect_stdout(output):
                self.assertEqual(check(root, update=True), 0)
            self.assertEqual(read_baseline(baseline), Counter())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update", action="store_true", help="remove baseline hits that no longer occur")
    options, remaining = parser.parse_known_args()
    if options.update:
        if remaining:
            parser.error("--update takes no other arguments")
        sys.exit(check(ROOT, update=True))
    unittest.main(argv=[sys.argv[0], *remaining])
