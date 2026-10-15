"""Approved UX-04 copy, hard word budgets, and explicit concept coverage."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Read the renderer's grammar rather than maintaining a narrower Python copy.
SYNTAX = (ROOT / "scripts/inline_token_syntax.gd").read_text()


def syntax_pattern(name):
    literal = re.search(rf"^const {name}: String = (.+)$", SYNTAX, re.MULTILINE)[1]
    return re.compile(json.loads(literal))


TOKEN = syntax_pattern("TOKEN_PATTERN")
TOKEN_START = syntax_pattern("TOKEN_START_PATTERN")
TEXT_ONLY = {"wait", "turns", "ice_pillar", "movement", "item", "outcrop"}


def read(path):
    return json.loads((ROOT / path).read_text())


def words(text):
    return len(re.sub(r"\[[^]]*\]", "", TOKEN.sub("TOKEN", text)).split())


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


def malformed_tokens(text):
    complete = {match.start() for match in TOKEN.finditer(text)}
    return [text[match.start():] for match in TOKEN_START.finditer(text) if match.start() not in complete]


def glossary_keys(glossary):
    aliases = {alias.lower(): e["id"] for e in glossary.values() for alias in e["aliases"]}
    candidates = {}
    for entry in glossary.values():
        for term in [entry["name"], *entry["aliases"]]:
            candidates[term] = entry["id"] if term not in candidates or candidates[term] == entry["id"] else ""
    aliases.update({term.lower(): key for term, key in candidates.items() if key})
    return set(glossary) | set(aliases)


def token_errors(text, keys):
    errors = [f"malformed {token}" for token in malformed_tokens(text)]
    errors += [f"unresolved {match[0]}" for match in TOKEN.finditer(text) if match[2].lower() not in keys]
    return errors


class TextBudgetTest(unittest.TestCase):
    def setUp(self):
        self.glossary = {e["id"]: e for e in read("data/glossary.json")}

    def test_glossary_matches_approved_copy_and_budget(self):
        approved = read("spec/peer_benchmark/staged/text/glossary_rewrite.json")
        self.assertTrue(approved["final"])
        live = {e["id"]: e for e in approved["entries"] if not e.get("deleted")}
        self.assertEqual(set(self.glossary), set(live))
        self.assertEqual(len(live), 145)
        for key, source in live.items():
            with self.subTest(entry=key):
                actual = self.glossary[key]
                self.assertEqual(actual["name"], source["name"])
                self.assertEqual(actual["definition"], source["definition"])
                self.assertTrue(set(source["aliases"]).issubset(actual["aliases"]))
                if source.get("current_name") and source["current_name"] != source["name"]:
                    self.assertIn(source["current_name"], actual["aliases"])
                self.assertLessEqual(words(actual["definition"]), 20)
                self.assertEqual(actual["icon"] is None, key in TEXT_ONLY)
        self.assertIn("chain_discharge", self.glossary["charge"]["aliases"])
        self.assertNotIn("chain_discharge", self.glossary["chain"]["aliases"])
        self.assertNotIn("outcrop", self.glossary["raise_terrain"]["aliases"])

    def test_relics_match_approved_copy_and_budget(self):
        relics = read("data/relics.json")
        active = retired = 0
        for source in read("spec/peer_benchmark/staged/text/relic_rewrite.json"):
            with self.subTest(relic=source["id"]):
                actual = relics[source["id"]]
                self.assertEqual(actual["name"], source["name"])
                self.assertEqual(actual["description"], source["description"])
                if source.get("retired_redirect_to"):
                    retired += 1
                    self.assertTrue(actual["retired"])
                    self.assertEqual(actual["description"], source["current_description"])
                else:
                    active += 1
                    self.assertLessEqual(words(actual["description"]), 25)
        self.assertEqual((active, retired), (100, 12))

    def test_every_explicit_concept_resolves(self):
        keys = glossary_keys(self.glossary)
        paths = [ROOT / "data" / f"{name}.json" for name in ("cards", "relics", "skills", "enemies", "grimoire", "glossary")]
        paths += list((ROOT / "scripts").rglob("*.gd"))
        checked = 0
        for path in paths:
            values = strings(json.loads(path.read_text())) if path.suffix == ".json" else [path.read_text()]
            for value in values:
                checked += len(TOKEN.findall(value))
                self.assertEqual(token_errors(value, keys), [], f"{path.relative_to(ROOT)}: invalid token")
        self.assertGreater(checked, 400)

    def test_token_validation_rejects_punctuation_whitespace_and_malformed_cases(self):
        cases = read("tests/fixtures/inline_token_cases.json")
        keys = glossary_keys(self.glossary)
        card_text = read("data/cards.json")["quick_stab"]["description"]
        for category, examples in cases.items():
            for markup in examples:
                with self.subTest(category=category, markup=markup):
                    errors = token_errors(card_text + " " + markup, keys)
                    self.assertEqual(bool(errors), category != "valid", errors)
                    self.assertEqual(bool(malformed_tokens(markup)), category.startswith("malformed"))
                    if category == "unknown":
                        self.assertEqual(len(TOKEN.findall(markup)), 1)

    def test_duration_skills_match_the_approved_glossary(self):
        skills = read("data/skills.json")
        for key in ("long_dawn", "sunpath", "afterglow"):
            with self.subTest(skill=key):
                self.assertEqual(skills[key]["description"], self.glossary[f"skill_{key}"]["definition"])
                self.assertNotIn("time", [match[2] for match in TOKEN.finditer(skills[key]["description"])])

    def test_token_word_count_includes_inflections_as_one_word(self):
        self.assertEqual(words("Store 3 @kw(surface_consume|Expended) ground tiles."), 5)
        self.assertEqual(words("[b]Gain[/b] @term(card_play|Card Plays)."), 2)
        self.assertNotIn("missing_key", self.glossary)
        self.assertEqual(TOKEN.search("@kw(missing_key|Missing Words)")[2], "missing_key")


if __name__ == "__main__":
    unittest.main(verbosity=2)
