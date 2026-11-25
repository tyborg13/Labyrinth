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
            "petrify", "keg_detonate", "meteorfall", "raise_outcrop",
            "raise_keg", "crystal_mantle", "ice_to_electrified", "only_light", "only_fire",
            "only_chilled", "only_electrified", "shatter",
            "terrain_burst_any", "if_half_health", "if_frozen",
            "if_in_light", "swap_illusion", "swap", "shatter_illusion", "illusion_block",
            "skate", "empower", "follow_up", "expose", "fireproof", "move_scaling",
            "next_attack_move", "stoneskin_scaling", "quicken", "shock_all_hits",
            "range_ice", "range_light", "range_illusion", "range_outcrop", "light_trail",
            "light_target", "light_land", "title_sentence_pull_area", "title_sentence_push_any",
            "title_sentence_range_terrain", "title_sentence_range_illusion",
        )
        rows = {row["id"]: row for row in director["rows"]}
        updated = read("tests/fixtures/txt20_rules_copy.json")["panel_rows"]
        next_attack_rows = ("next_attack_move", "next_attack_pierce", "next_attack_chain", "next_attack_damage")
        vrb01_text = dict.fromkeys(next_attack_rows, "{sentence}")
        vrb01_text.update(quicken="Your next card this turn costs {n} less Time.",
                          expend_beneath_you="Remove the {ground} from your tile.")
        vrb01_titles = {"keg_detonate": "Burst", "shatter_illusion": "Burst", "next_attack_move": "", "quicken": ""}
        exception_strip = read("tests/fixtures/pla01_exception_strip.json")["card_panel_text"]
        for key, sentence in exception_strip.items():
            self.assertEqual(templates[key]["text"], sentence)
        for key, row in updated.items():
            if key in vrb01_text or key == "expend_after_hit":
                continue
            if key in vrb01_titles:
                row = dict(row, title=vrb01_titles[key])
                if key == "shatter_illusion":
                    row["legacy"] = row["legacy"].replace("Shatter Illusion\n", "Burst\n", 1)
            self.assertEqual(templates[key], row)
        # pla-04 (Burst merge): no player-facing "Terrain Burst"; these titles read "Burst".
        pla04 = read("tests/fixtures/pla04_burst_copy.json")["panel_titles"]
        outcrop_rows = {"raise_outcrop", "terrain_burst_any", "terrain_burst_own", "range_outcrop"}
        # pla-06 (Ice merge): Petrify, Frozen and Chilled rows are retired; the
        # Chilled selector row is the Ice selector row.
        pla06 = read("tests/fixtures/pla06_ice_copy.json")
        for key in pla06["retired_panel_rows"]:
            self.assertNotIn(key, templates)
        for key, row in pla06["panel_rows"].items():
            self.assertEqual(templates[key], updated.get(key, row))
        for key in straightforward:
            if key in pla06["retired_panel_rows"]:
                continue
            with self.subTest(row=key):
                expected = rows[key]["text"]
                if key in outcrop_rows:
                    expected = expected.replace("outcrop", "Outcrop")
                if key in {"light_trail", "light_target", "light_land"}:
                    expected = read("tests/fixtures/pla08_light_vision_copy.json")["definitions"]["illuminate"]
                self.assertEqual(templates[key]["text"], vrb01_text.get(key, updated.get(key, {}).get("text", expected)))
                title = vrb01_titles.get(key, pla04.get(key, rows[key]["title"]))
                self.assertEqual(templates[key]["title"], title)
        self.assertNotIn("worldspine_burst", templates)
        self.assertNotIn("expend_after_hit", templates)
        self.assertEqual(templates["remove_ground"], {
            "title": "", "text": "Remove the {ground} {where}.",
            "legacy": "Remove the {ground} {where}.", "term": "surface_consume",
        })
        self.assertEqual(templates["expend_beneath_you"], {
            "title": "", "text": vrb01_text["expend_beneath_you"],
            "legacy": vrb01_text["expend_beneath_you"], "term": "surface_consume",
        })
        for key in next_attack_rows:
            self.assertEqual(templates[key], {
                "title": "", "text": "{sentence}", "legacy": "{legacy}", "term": "next_attack",
            })
        self.assertEqual(templates["terrain_burst_own"]["text"], "Destroy an adjacent Outcrop you raised.")
        self.assertEqual(templates["raise_outcrop_around_target"]["text"],
                         "Raise an Outcrop with X Health on each empty tile adjacent to the target.")
        self.assertEqual(templates["retaliate_illusion"]["text"],
                         "Enemies that damage this Illusion take {n} damage{suffix2}.")
        for key, expected in (
            ("title_sentence_light", "Placed Light lasts the battle. Enemies starting a turn in Light are Exposed 2."),
            ("title_sentence_light_self", "Placed Light lasts the battle. Enemies starting a turn in Light are Exposed 2."),
            ("title_sentence_push_area", "Pushes each enemy within {r} of you {n} tiles away."),
            ("title_sentence_push_area_target", "Pushes each enemy within {r} of the chosen tile {n} tiles away from it."),
            ("retaliate_illusion_reflect", "Enemies that damage this illusion take that much damage too."),
            ("cleanse", "Remove {statuses} from yourself."),
        ):
            self.assertEqual(templates[key]["text"], updated.get(key, {}).get("text", expected))

    def test_every_director_row_and_fact_has_independent_fixture(self):
        director = read("spec/peer_benchmark/staged/tt-02/card_panels.json")
        examples = read("tests/fixtures/card_panel_examples.json")
        self.assertEqual(set(examples), {row["id"] for row in director["rows"]})
        facts = read("tests/fixtures/card_panel_grimoire_facts.json")
        self.assertEqual(set(facts), {r["id"] for r in director["rows"] if r["grimoire"]})
        self.assertEqual(sum(f["appended"] for f in facts.values()), 10)
        for row in director["rows"]:
            if row["id"] == "worldspine_burst":
                self.assertEqual(facts[row["id"]]["owner"], "keyword:rite")
                self.assertEqual(facts[row["id"]]["paragraphs"],
                                 ["Worldspine: at the start of your turn, each enemy next to an Outcrop you raised takes 3."])
            elif row["id"] in facts and facts[row["id"]]["appended"]:
                expected = row["grimoire"].split(": ", 1)[1]
                if row["id"] == "raise_outcrop":
                    expected = expected.replace(" outcrop", " Outcrop")
                if row["id"] == "title_sentence_push_area":
                    expected = expected.replace("in an area push", "In an area Push")
                if row["id"] == "crystal_mantle":
                    expected = expected.replace(", Bleed", "").replace("bypass it.", "bypass Crystal Mantle.")
                self.assertEqual(facts[row["id"]]["paragraphs"], [expected])

    def test_new_gdscript_uses_windows_safe_typed_arrays(self):
        pattern = re.compile(r"\b(?:var|const)\s+\w+\s*:\s*Array\[[^]]+\]\s*=\s*\[")
        for path in ("scripts/card_panel_text.gd", "tests/card_panel_text_test.gd",
                     "tests/helpers/card_panel_proof.gd"):
            self.assertIsNone(pattern.search((ROOT / path).read_text()), path)

    def test_feedback_one_copy(self):
        templates = read("data/card_panel_text.json")
        template = templates["item_once_per_combat"]
        self.assertEqual(template["text"], "This item can be used once per combat and returns next combat.")
        self.assertEqual(template["legacy"], "This item can be used once per combat and returns next combat.")
        self.assertEqual(templates["empower_health"]["text"],
                         "Lose {n} Health after the card resolves.")
        self.assertEqual(templates["unchanged_leaves_an_illusion_with_this_much_health_where_you_stood"]["text"],
                         "Leave an Illusion with X Health on the tile you left.")


if __name__ == "__main__":
    unittest.main()
