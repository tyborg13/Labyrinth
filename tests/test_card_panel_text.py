"""Pin the director's data-only copy, variants, and protected glossary scope."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads((ROOT / path).read_text())


class CardPanelTextTest(unittest.TestCase):
    def test_director_sentences_are_data_templates(self):
        director = read("spec/peer_benchmark/staged/tt-02/card_panels.json")
        templates = read("data/card_panel_text.json")
        straightforward = (
            "petrify", "keg_detonate", "meteorfall", "raise_worldspine", "raise_outcrop",
            "raise_keg", "crystal_mantle", "ice_to_electrified", "only_light", "only_fire",
            "only_chilled", "only_electrified", "shatter", "worldspine_burst",
            "terrain_burst_any", "terrain_burst_own", "if_half_health", "if_frozen",
            "if_in_light", "swap_illusion", "swap", "shatter_illusion", "illusion_block",
            "skate", "empower", "follow_up", "expose", "fireproof", "move_scaling",
            "next_attack_move", "stoneskin_scaling", "quicken", "shock_all_hits",
            "range_ice", "range_light", "range_illusion", "range_outcrop", "light_trail",
            "light_target", "light_land", "title_sentence_pull_area", "title_sentence_push_any",
            "title_sentence_range_terrain", "title_sentence_range_illusion",
        )
        rows = {row["id"]: row for row in director["rows"]}
        for key in straightforward:
            with self.subTest(row=key):
                self.assertEqual(templates[key]["text"], rows[key]["text"])
                self.assertEqual(templates[key]["title"], rows[key]["title"])
        self.assertEqual(templates["retaliate_illusion"]["text"],
                         "Enemies that damage this illusion take {n}{suffix} damage{suffix2}.")
        for key, expected in (
            ("title_sentence_light", "Creates Light of this radius."),
            ("title_sentence_light_self", "Creates Light of this radius around you."),
            ("title_sentence_push_area", "Pushes each enemy within {r} of you {n} tiles away."),
            ("title_sentence_push_area_target", "Pushes each enemy within {r} of the chosen tile {n} tiles away from it."),
            ("retaliate_illusion_reflect", "Enemies that damage this illusion take that much damage too."),
            ("cleanse", "Remove {statuses} from yourself."),
        ):
            self.assertEqual(templates[key]["text"], expected)

    def test_every_director_row_and_fact_has_independent_fixture(self):
        director = read("spec/peer_benchmark/staged/tt-02/card_panels.json")
        examples = read("tests/fixtures/card_panel_examples.json")
        self.assertEqual(set(examples), {row["id"] for row in director["rows"]})
        facts = read("tests/fixtures/card_panel_grimoire_facts.json")
        self.assertEqual(set(facts), {r["id"] for r in director["rows"] if r["grimoire"]})
        self.assertEqual(sum(f["appended"] for f in facts.values()), 11)
        for row in director["rows"]:
            if row["id"] in facts and facts[row["id"]]["appended"]:
                self.assertEqual(facts[row["id"]]["paragraphs"], [row["grimoire"].split(": ", 1)[1]])

    def test_new_gdscript_uses_windows_safe_typed_arrays(self):
        pattern = re.compile(r"\b(?:var|const)\s+\w+\s*:\s*Array\[[^]]+\]\s*=\s*\[")
        for path in ("scripts/card_panel_text.gd", "tests/card_panel_text_test.gd",
                     "tests/helpers/card_panel_proof.gd"):
            self.assertIsNone(pattern.search((ROOT / path).read_text()), path)

    def test_feedback_one_copy(self):
        templates = read("data/card_panel_text.json")
        template = templates["item_once_per_combat"]
        self.assertEqual(template["text"], "Usable once per combat; it returns next combat.")
        self.assertEqual(template["legacy"], "Once per combat. This item returns at the next combat.")
        self.assertEqual(templates["empower_health"]["text"],
                         "Empower cost: lose {n} Health after the card resolves.")
        self.assertEqual(templates["unchanged_leaves_an_illusion_with_this_much_health_where_you_stood"]["text"],
                         "Leaves an illusion with this much Health where you stood.")


if __name__ == "__main__":
    unittest.main()
