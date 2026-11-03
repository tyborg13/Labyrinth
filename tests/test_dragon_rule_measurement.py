"""Matched director ladders reject sample drift and continuing past a valid rung."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dragon_rule_measurement as measurement


class DragonRuleMeasurementTests(unittest.TestCase):
    def setUp(self):
        self.raw = measurement.read_report(ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bos-02/after/tharokh.json.gz")

    def test_same_samples_allow_changed_outcomes_and_order(self):
        candidate = copy.deepcopy(self.raw)
        candidate["results"].reverse()
        candidate["results"][0]["won"] = not candidate["results"][0]["won"]
        measurement.validate_matched(self.raw, candidate)

    def test_sample_or_setup_drift_is_rejected(self):
        for field in ("coord", "travel_dir", "deck_tier", "policy_version", "seed"):
            with self.subTest(field=field):
                candidate = copy.deepcopy(self.raw)
                candidate["results"][0][field] = "changed"
                with self.assertRaisesRegex(ValueError, "Unmatched tuning samples"):
                    measurement.validate_matched(self.raw, candidate)
        for field in ("decks", "defaults", "revision", "cohort"):
            with self.subTest(field=field):
                candidate = copy.deepcopy(self.raw)
                candidate[field] = "changed"
                with self.assertRaisesRegex(ValueError, "Unmatched measurement setup"):
                    measurement.validate_matched(self.raw, candidate)

    def test_duplicates_or_short_cohorts_are_rejected(self):
        candidate = copy.deepcopy(self.raw)
        candidate["results"][-1] = copy.deepcopy(candidate["results"][0])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            measurement.validate_matched(self.raw, candidate)
        candidate["results"].pop()
        with self.assertRaisesRegex(ValueError, "50 runs"):
            measurement.validate_matched(self.raw, candidate)

    def _manifest(self, folder, wins, extra=False, maximum=4):
        (folder / "before.json").write_text(json.dumps(self.raw))
        candidate = copy.deepcopy(self.raw)
        for index, row in enumerate(candidate["results"]): row["won"] = index < wins
        (folder / "after.json").write_text(json.dumps(candidate))
        rungs = [{"rung":0, "change":"Round 0", "report":"before.json"},
                 {"rung":1, "change":"director rung 1", "report":"after.json"}]
        if extra: rungs.append({"rung":2, "change":"director rung 2", "report":"after.json"})
        manifest = {"dragons":{"tharokh":{"before":"before.json", "band":[.30,.60],
                    "maximum_rung":maximum, "selected_rung":len(rungs)-1, "rungs":rungs}}}
        path = folder / "manifest.json"
        path.write_text(json.dumps(manifest))
        return path

    def test_inclusive_band_edges_stop_on_first_rung(self):
        for wins in (15, 30):
            with self.subTest(wins=wins), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                measurement.ladder_report(self._manifest(folder, wins), folder / "report.md")
                self.assertIn("Retained rung 1: inside band.", (folder / "report.md").read_text())

    def test_ladder_cannot_continue_after_first_in_band_rung(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with self.assertRaisesRegex(ValueError, "continued past"):
                measurement.ladder_report(self._manifest(folder, 20, extra=True), folder / "report.md")

    def test_out_of_band_ladder_must_exhaust_authorized_rungs(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with self.assertRaisesRegex(ValueError, "stopped early"):
                measurement.ladder_report(self._manifest(folder, 5), folder / "report.md")
            measurement.ladder_report(self._manifest(folder, 5, maximum=1), folder / "report.md")
            self.assertIn("OUTSIDE band after the last authorized rung.", (folder / "report.md").read_text())
