"""The owner-approved Dial row stays aligned across runtime and authored records."""
import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
TEXT = "Each ground tile you Expend gives your next attack +3 damage (up to +9)."
INLINE_TEXT = TEXT.replace("Expend", "@kw(surface_consume|Expend)")
EFFECTS = [{"type": "expend_next_attack_damage", "damage": 3, "max": 9}]
RATIONALE = (
    "one-sentence rework after owner playtest 13; the riders were cut and the bonus rose to +3 per tile"
)


class BlackSunDialRecordTests(unittest.TestCase):
    def test_shipped_row(self):
        relic = json.loads((ROOT / "data/relics.json").read_text())["black_sun_dial"]
        self.assertEqual(relic["description"], INLINE_TEXT)
        self.assertEqual(relic["effects"], EFFECTS)
        self.assertEqual(relic["rarity"], "legendary")
        for field in ("design_version", "condition_tier", "upside_tier"):
            self.assertEqual(relic[field], 4)
        self.assertEqual(relic["build_tags"], [
            "mixed_elements", "rubble", "surface_consumption", "shared_damage",
        ])

    def test_authored_row_and_snapshot(self):
        path = ROOT / "spec/relic_pool_overhaul/relic_data.py"
        spec = importlib.util.spec_from_file_location("pt13_01_relic_record", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        authored = next(row for row in module.RELICS if row["id"] == "black_sun_dial")
        snapshot = json.loads((ROOT / "spec/relic_pool_overhaul/proposal.json").read_text())
        recorded = next(row for row in snapshot["relics"] if row["id"] == "black_sun_dial")
        self.assertEqual(authored, recorded)
        self.assertEqual(authored["text"], TEXT)
        self.assertEqual(authored["effects"], EFFECTS)
        self.assertEqual(authored["note"], RATIONALE)


if __name__ == "__main__":
    unittest.main()
