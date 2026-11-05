"""Protect director copy, glossary identities and the full Grimoire rules."""
import hashlib
import json
from pathlib import Path
import re
import unittest

from marked_glossary_contract import (
    MARKED_DEFINITION, MARKED_METADATA, MARKED_RETIRED,
    marked_metadata_supersession,
)

ROOT = Path(__file__).resolve().parents[1]
COPY = ROOT / "spec/peer_benchmark/staged/tt-01/tooltips.json"
EXPECTATIONS = ROOT / "tests/fixtures/short_card_tooltips_expectations.json"
UNCHANGED_SHA256 = "17be644b843ba6c56d6fed1fef19d4c98b339b70edf0a8fae91f3f72b2051cd0"
RETIRED_TERMS = {"dive", "veil", "flurry", "aoe"}  # sta-01/flu-01: keep protected historical copy untouched.
METADATA_SHA256 = "452541bfabda9d9a177a13e383c14c147a78746c0492e0eace190b58caf3bab2"

UMBRA_AREA_BODY = "Darkness that limits your sight. Hidden enemies show no intent and can't be targeted. Attacks that hit an area hit hidden enemies on those tiles too."

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


class ShortCardTooltipsTest(unittest.TestCase):
    def setUp(self):
        self.copy = json.loads(COPY.read_text())
        self.expectations = json.loads(EXPECTATIONS.read_text())
        # mim-01 retires Mirror; keep the director's historical inputs intact.
        self.copy["entries"] = [e for e in self.copy["entries"] if e["id"] != "mirror"]
        self.expectations["owners"].pop("mirror")
        self.expectations["new_terms"].remove("mirror")
        self.superseding = {e["id"]: e["text"] for e in json.loads(
            (ROOT / "spec/peer_benchmark/staged/tt-02/card_panels.json").read_text())["glossary_edits"]}
        self.superseding["retaliate"] = "Until its next turn, whoever hits this unit up close takes that much damage."
        self.glossary = json.loads((ROOT / "data/glossary.json").read_text())
        self.grimoire = json.loads((ROOT / "data/grimoire.json").read_text())

    def test_protected_copy_and_term_matching(self):
        by_id = {entry["id"]: entry for entry in self.glossary}
        self.assertEqual(len(self.copy["entries"]), 107)
        for change in self.copy["entries"]:
            with self.subTest(term=change["id"]):
                if change["id"] in RETIRED_TERMS:
                    self.assertNotIn(change["id"], by_id)
                elif change["id"] in MARKED_RETIRED:
                    self.assertNotIn(change["id"], by_id)
                    self.assertIn(change["id"], by_id["marked"]["aliases"])
                else:
                    self.assertEqual(by_id[change["id"]]["definition"], self.superseding.get(change["id"], change["tooltip"]))
        self.assertEqual(by_id["marked"]["definition"], MARKED_DEFINITION)
        expected = json.loads((ROOT / 'tests/goldens/glossary_metadata.json').read_text())
        expected['metadata'] = [e for e in expected['metadata'] if e['id'] not in {'mirror', 'flurry', 'aoe'}]
        metadata = [{key: value for key, value in entry.items() if key != "definition"}
                    for entry in self.glossary]
        self.assertEqual(metadata, marked_metadata_supersession(expected['metadata']))
        unchanged = [entry for entry in self.glossary if entry['id'] in self.copy['unchanged_ids']]
        self.assertEqual(unchanged, expected['unchanged'])

    def test_full_rules_retained_in_expected_topics(self):
        entries = {entry["id"]: entry for entry in self.grimoire["entries"]}
        self.assertEqual(set(self.expectations["owners"]),
                         {change["id"] for change in self.copy["entries"]})
        for change in self.copy["entries"]:
            with self.subTest(term=change["id"]):
                owner = self.expectations["owners"][change["id"]]
                if change["id"] in RETIRED_TERMS | MARKED_RETIRED:
                    self.assertNotIn(owner, entries)
                    if change["id"] in MARKED_RETIRED:
                        self.assertEqual(entries["keyword:marked"]["body"], [MARKED_DEFINITION])
                    continue
                self.assertIn(owner, entries)
                # bos-02 supersedes two former dragon rules with director-approved
                # Grimoire bodies. Keep the retention assertion for every other term.
                if change["id"] in ("gale_force", "worldspines"):
                    approved = json.loads((ROOT / "tests/fixtures/bos02_feedback1_grimoire.json").read_text())
                    self.assertEqual(entries[owner]["body"], approved["entries"][owner]["body"])
                else:
                    self.assertIn(UMBRA_AREA_BODY if change["id"] == "umbra" else change["old"], entries[owner]["body"],
                                  "Former full definition must remain in its owning topic")

    def test_every_new_entry_schema(self):
        by_id = {entry["id"]: entry for entry in self.glossary}
        entries = {entry["id"]: entry for entry in self.grimoire["entries"]}
        changes = {change["id"]: change for change in self.copy["entries"]}
        self.assertEqual(len(self.expectations["new_terms"]), 38)
        self.assertEqual(entries["keyword:marked"], {
            "id": "keyword:marked", "section": "keywords", "title": "Marked",
            "icon": "marked",
            "body": [MARKED_DEFINITION], "aliases": MARKED_METADATA["aliases"],
        })
        for term in self.expectations["new_terms"]:
            with self.subTest(term=term):
                entry_id = "keyword:" + term
                if term in RETIRED_TERMS | MARKED_RETIRED:
                    self.assertNotIn(entry_id, entries)
                    self.assertNotIn(term, by_id)
                    continue
                self.assertIn(entry_id, entries)
                entry = entries[entry_id]
                self.assertEqual(entry["section"], "keywords")
                self.assertEqual(entry["title"], by_id[term]["name"])
                icon = term if term in ("skill_point", "moltshard") else by_id[term]["icon"]
                self.assertEqual(entry["icon"], icon)
                expected_body = [changes[term]["old"]]
                facts = json.loads((ROOT / "tests/fixtures/card_panel_grimoire_facts.json").read_text())
                for fact in facts.values():
                    if fact["owner"] == entry_id and fact["appended"]:
                        expected_body.extend(fact["paragraphs"])
                self.assertEqual(entry["body"], expected_body)
                if "default" in entry:
                    self.assertIs(type(entry["default"]), bool)

    def test_proof_typed_arrays_have_no_literal_initializers(self):
        pattern = re.compile(r"\b(?:var|const)\s+\w+\s*:\s*Array\[[^]]+\]\s*=\s*\[")
        for relative in ("tests/helpers/short_card_tooltips_proof.gd",
                         "tests/short_card_tooltips_test.gd"):
            with self.subTest(path=relative):
                self.assertIsNone(pattern.search((ROOT / relative).read_text()),
                                  "Use append() or a typed helper for Windows compatibility")

    def test_no_automatic_time_panel_on_card_surfaces(self):
        run_scene = (ROOT / "scripts/run_scene.gd").read_text()
        body = run_scene.split("func _show_card_focus_tooltips(", 1)[1].split("\nfunc ", 1)[0]
        self.assertNotIn('leading_icons.append("time")', body)
        self.assertIn('leading_icons.append("rite")', body)
        boon = (ROOT / "scripts/opening_boon_inspection.gd").read_text()
        self.assertNotIn('["time"]', boon)
        # card-02: boon inspection uses the retained face's effective rows.
        self.assertIn('Icons.tooltip_entries_for_rows(widget.display_summary_rows())', boon)


if __name__ == "__main__":
    unittest.main()
