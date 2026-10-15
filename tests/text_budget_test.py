"""Approved UX-04 copy, hard word budgets, and explicit concept coverage."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r"@(icon|term|kw)\(([A-Za-z0-9_-]*)(?:\|[^)]*)?\)")
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
        aliases = {alias.lower(): e["id"] for e in self.glossary.values() for alias in e["aliases"]}
        paths = [ROOT / "data" / f"{name}.json" for name in ("cards", "relics", "skills", "enemies", "grimoire", "glossary")]
        paths += list((ROOT / "scripts").rglob("*.gd"))
        checked = 0
        for path in paths:
            values = strings(json.loads(path.read_text())) if path.suffix == ".json" else [path.read_text()]
            for value in values:
                for match in TOKEN.finditer(value):
                    checked += 1
                    key = match[2]
                    self.assertTrue(aliases.get(key, key) in self.glossary, f"{path.relative_to(ROOT)}: unresolved {match[0]}")
        self.assertGreater(checked, 400)

    def test_token_word_count_includes_inflections_as_one_word(self):
        self.assertEqual(words("Store 3 @kw(surface_consume|Expended) ground tiles."), 5)
        self.assertEqual(words("[b]Gain[/b] @term(card_play|Card Plays)."), 2)
        self.assertNotIn("missing_key", self.glossary)
        self.assertEqual(TOKEN.search("@kw(missing_key|Missing Words)")[2], "missing_key")


if __name__ == "__main__":
    unittest.main(verbosity=2)
