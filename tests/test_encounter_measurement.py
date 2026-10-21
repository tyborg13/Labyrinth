"""Offline report statistics and completeness of the checked-in measurements."""
import gzip
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import encounter_bot
import encounter_sweep

ARTIFACTS = encounter_sweep.DEFAULT_OUTPUT


class EncounterReportTests(unittest.TestCase):
    def test_quantiles_and_even_median(self):
        self.assertEqual(encounter_sweep.distribution(list(range(1, 201))),
                         {"n": 200, "median": 100.5, "p10": 20, "p90": 180})
        self.assertEqual(encounter_sweep.distribution([]),
                         {"n": 0, "median": None, "p10": None, "p90": None})

    def test_escape_rate_includes_losses(self):
        records = [{"objective": "reach_exit", "won": win, "turns": turns,
                    "hp_lost": 4, "turn_cap_reached": False, "biome": "ice"}
                   for win, turns in [(True, 1), (True, 3), (False, 1), (False, 5)]]
        summary = encounter_bot.summarize(records)
        self.assertEqual(summary["win_rate"], .5)
        self.assertEqual(summary["one_turn_escape_share"], .25)
        self.assertEqual(summary["turns"], {"n": 4, "median": 2, "p10": 1, "p90": 5})

    def test_committed_sweep_is_complete_and_recomputes(self):
        report = json.loads((ARTIFACTS / "composition.json").read_text())
        raw = ARTIFACTS / report["raw_file"]
        self.assertEqual(hashlib.sha256(raw.read_bytes()).hexdigest(), report["raw_sha256"])
        with gzip.open(raw, "rt") as stream:
            rows = [json.loads(line) for line in stream]
        self.assertEqual(len(rows), 36000)
        identities = {(r["seed"], r["tier"], r["biome"]) for r in rows}
        self.assertEqual(len(identities), 36000)
        for tier in (1, 2, 3):
            for biome in ("fire", "earth", "ice", "air", "lightning", "shadow"):
                self.assertEqual(sum(r["tier"] == tier and r["biome"] == biome for r in rows), 2000)
        self.assertEqual(encounter_sweep.summarize(rows), report["groups"])
        self.assertEqual(encounter_sweep.markdown(report["groups"]), (ARTIFACTS / "composition.md").read_text())

    def test_committed_baseline_is_complete_and_recomputes(self):
        report = json.loads((ARTIFACTS / "baseline.json").read_text())
        self.assertEqual(len(report["groups"]), 9)
        self.assertEqual({(g["tier"], g["objective"]) for g in report["groups"]},
                         {(t, o) for t in (1, 2, 3) for o in encounter_bot.OBJECTIVES})
        for group in report["groups"]:
            path = ARTIFACTS / group["file"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), group["sha256"])
            data = json.loads(path.read_text())
            self.assertEqual(len(data["results"]), 200)
            self.assertEqual(len({(r["seed"], r["coord"]["x"], r["coord"]["y"]) for r in data["results"]}), 200)
            for key, value in encounter_bot.summarize(data["results"]).items():
                self.assertEqual(group[key], value)
            for result in data["results"]:
                self.assertEqual(result["tier"], group["tier"])
                self.assertEqual(result["objective"], group["objective"])
                self.assertEqual(result["won"], result["outcome"] == "victory")
                self.assertEqual(result["first_enemy_death_turn"] is None, result["kills"] == 0)


if __name__ == "__main__":
    unittest.main()
