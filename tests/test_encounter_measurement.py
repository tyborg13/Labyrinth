"""Offline report statistics and completeness of the checked-in measurements."""
import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
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

    def test_gzip_reports_are_deterministic_and_lossless(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            source = folder / "raw.json"
            source.write_text('{"results": [{"won": true}]}\n')
            first, second = folder / "first.gz", folder / "second.gz"
            encounter_bot.compress_report(source, first)
            encounter_bot.compress_report(source, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(gzip.decompress(first.read_bytes()), source.read_bytes())
            self.assertEqual(encounter_bot.read_report(first), encounter_bot.read_report(source))

    def assert_baseline_complete(self, summary_file, version):
        report = json.loads((ARTIFACTS / summary_file).read_text())
        self.assertEqual(report["policy_version"], version)
        self.assertEqual(len(report["groups"]), 9)
        self.assertEqual({(g["tier"], g["objective"]) for g in report["groups"]},
                         {(t, o) for t in (1, 2, 3) for o in encounter_bot.OBJECTIVES})
        presets, defaults, identities = None, None, {}
        for group in report["groups"]:
            path = ARTIFACTS / group["file"]
            self.assertEqual(path.suffix, ".gz")
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), group["sha256"])
            if version == 1:
                self.assertEqual(hashlib.sha256(gzip.decompress(path.read_bytes())).hexdigest(), group["original_sha256"])
            data = encounter_bot.read_report(path)
            self.assertEqual(len(data["results"]), 200)
            keys = [(r["seed"], r["coord"]["x"], r["coord"]["y"]) for r in data["results"]]
            self.assertEqual(len(set(keys)), 200)
            identities[group["tier"], group["objective"]] = keys
            if presets is None:
                presets, defaults = data["decks"], data["defaults"]
            self.assertEqual(data["decks"], presets)
            self.assertEqual(data["defaults"], defaults)
            self.assertEqual(defaults["hp"], 24)
            self.assertEqual(defaults["relics"], [])
            self.assertEqual(len(presets["1"]), 16)
            self.assertEqual(presets["2"], presets["1"] + presets["common_rewards"])
            self.assertEqual(presets["3"], presets["2"] + presets["rare_rewards"])
            for key, value in encounter_bot.summarize(data["results"]).items():
                self.assertEqual(group[key], value)
            for result in data["results"]:
                if version == 2:
                    self.assertEqual(result["policy_version"], 2)
                self.assertEqual(result["tier"], group["tier"])
                self.assertEqual(result["objective"], group["objective"])
                self.assertEqual(result["won"], result["outcome"] == "victory")
                self.assertEqual(result["first_enemy_death_turn"] is None, result["kills"] == 0)
        return report, presets, identities

    def test_preserved_v1_baseline_is_complete_and_lossless(self):
        self.assert_baseline_complete("baseline_policy_v1.json", 1)

    def test_calibration_preserves_both_configurations(self):
        report = json.loads((ARTIFACTS / "calibration_policy_v2.json").read_text())
        self.assertFalse(report["search_limits_changed"])
        for configuration in report["configurations"]:
            path = ARTIFACTS / configuration["raw_file"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), configuration["sha256"])
            records = encounter_bot.read_report(path)["results"]
            self.assertEqual(len(records), 30)
            for key, value in encounter_bot.summarize(records).items():
                self.assertEqual(configuration[key], value)
        best = max(report["configurations"], key=lambda row: (row["win_rate"], -row["hp_lost"]["median"]))
        self.assertEqual(report["selected_configuration"], best["name"])

    def test_committed_baseline_is_complete_and_recomputes(self):
        report, presets, identities = self.assert_baseline_complete("baseline.json", 2)
        _, previous_presets, previous_identities = self.assert_baseline_complete("baseline_policy_v1.json", 1)
        self.assertEqual(presets, previous_presets)
        self.assertEqual(identities, previous_identities)
        self.assertEqual(report["policy_sha256"], hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest())
        tier1 = next(g for g in report["groups"] if g["tier"] == 1 and g["objective"] == "kill_all")
        self.assertEqual(report["tier1_target"]["met"], tier1["win_rate"] >= .70 and tier1["hp_lost"]["median"] <= 8)
        self.assertFalse(list(ARTIFACTS.rglob("*.log")))
        self.assertFalse(list(ARTIFACTS.rglob("*.log.gz")))


if __name__ == "__main__":
    unittest.main()
