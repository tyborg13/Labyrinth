"""Offline report statistics and completeness of the checked-in measurements."""
import gzip
import hashlib
import json
from collections import Counter
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import encounter_bot
import encounter_sweep
import enc03_measurement
import enc03_proof

ARTIFACTS = encounter_sweep.DEFAULT_OUTPUT
CURRENT_ARTIFACTS = encounter_sweep.output_for_revision(6)
BIOMES = ("fire", "earth", "ice", "air", "lightning", "shadow")
# Frozen evidence for the policy-v2 revision-5 report, before CLI integration.
REVISION5_POLICY_SHA256 = "1ba458bdc63f50f99ad598d0d1542691ddd937d79d54584f53e28b5330a6cac6"
# Revision-7 evidence predates additive measurement-only CLI options. Validate
# its recorded tooling against its integration snapshot, not later tool edits.
REVISION7_TOOL_SNAPSHOT = "24cc38b7791444dcbd3f8ecd9c59dc1247a284ba"


class EncounterReportTests(unittest.TestCase):
    def test_slag_action_mix_and_outcomes(self):
        mix = dict(lob=2, lob_mark=1, lob_land=1, brace=3, scatter=4, retreat=5)
        rows = [dict(won=True, hp_lost=2, turns=3, turn_cap_reached=False, slag_action_mix=mix),
                dict(won=False, hp_lost=24, turns=7, turn_cap_reached=True, slag_action_mix=mix)]
        summary = enc03_measurement.summarize(rows)
        self.assertEqual(summary['win_rate'], .5)
        self.assertEqual(summary['hp_lost']['median'], 13)
        self.assertEqual(summary['turns']['median'], 5)
        self.assertEqual(summary['action_mix'], {key: value * 2 for key, value in mix.items()})
        self.assertEqual(summary['turn_caps'], 1)

    def test_slag_report_distinguishes_historical_drift_from_paired_measurement(self):
        row = dict(won=True, hp_lost=3, turns=4, decisions=5, intent_previews=6)
        row['revision7_baseline'] = row.copy()
        self.assertEqual(enc03_measurement.historical_drift([row]), 0)
        row['hp_lost'] = 4
        self.assertEqual(enc03_measurement.historical_drift([row]), 1)

    def test_slag_report_reads_archived_gzip_without_changing_records(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'before-t1-warband.json'
            value = {'results': [{'won': True, 'slag_action_mix': {'retreat': 2}}]}
            encoded = json.dumps(value).encode()
            path.write_bytes(encoded)
            self.assertEqual(enc03_measurement.read_report(path), value)
            path.unlink()
            path.with_suffix('.json.gz').write_bytes(gzip.compress(encoded, mtime=0))
            self.assertEqual(enc03_measurement.read_report(path), value)

    def test_before_proof_restores_only_its_owned_enemy_after_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in enc03_proof.OWNED:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('after ' + relative)
            (root / 'data').mkdir()
            original = {'slag_mortar': {'name': 'after'}, 'other_unit': {'hp': 10}}
            (root / 'data/enemies.json').write_text(json.dumps(original, indent=2) + '\n')
            fixture = root / 'tests/fixtures/enc03_slag_before.json'
            fixture.parent.mkdir(parents=True)
            fixture.write_text('{"name": "before"}')
            def fail_capture(*args, **kwargs):
                data = json.loads((root / 'data/enemies.json').read_text())
                self.assertEqual(data['slag_mortar']['name'], 'before')
                data['other_unit']['hp'] = 11  # A different engineer's concurrent entry.
                (root / 'data/enemies.json').write_text(json.dumps(data, indent=2) + '\n')
                raise RuntimeError('renderer unavailable')
            with patch.object(enc03_proof, 'ROOT', root), \
                    patch.object(sys, 'argv', ['enc03_proof.py', '--phase', 'before']), \
                    patch.object(enc03_proof.subprocess, 'check_output', return_value=b'before source'), \
                    patch.object(enc03_proof.subprocess, 'run', side_effect=fail_capture):
                with self.assertRaisesRegex(RuntimeError, 'renderer unavailable'):
                    enc03_proof.main()
            self.assertEqual(json.loads((root / 'data/enemies.json').read_text()),
                             {'slag_mortar': {'name': 'after'}, 'other_unit': {'hp': 11}})
            for relative in enc03_proof.OWNED:
                self.assertEqual((root / relative).read_text(), 'after ' + relative)

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

    def test_impossible_revision_cohorts_fail_without_scanning_seeds(self):
        cases = [(["--revision", "6", "--objective", "reach_exit"], "revision 6 objectives follow --cohort"),
                 (["--revision", "5", "--cohort", "warband"], "revision 5 has no Warband cohort")]
        for arguments, message in cases:
            with self.subTest(arguments=arguments):
                result = subprocess.run([sys.executable, "-B", str(ROOT / "tools/encounter_bot.py"), *arguments],
                                        text=True, capture_output=True, check=False)
                self.assertEqual(result.returncode, 2)
                self.assertIn(message, result.stderr)
                self.assertEqual(result.stdout, "")

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

    def test_preserved_revision5_v2_baseline_is_complete_and_recomputes(self):
        report, presets, identities = self.assert_baseline_complete("baseline.json", 2)
        _, previous_presets, previous_identities = self.assert_baseline_complete("baseline_policy_v1.json", 1)
        self.assertEqual(presets, previous_presets)
        self.assertEqual(identities, previous_identities)
        self.assertEqual(report["policy_sha256"], REVISION5_POLICY_SHA256)
        tier1 = next(g for g in report["groups"] if g["tier"] == 1 and g["objective"] == "kill_all")
        self.assertEqual(report["tier1_target"]["met"], tier1["win_rate"] >= .70 and tier1["hp_lost"]["median"] <= 8)
        self.assertFalse(list(ARTIFACTS.rglob("*.log")))
        self.assertFalse(list(ARTIFACTS.rglob("*.log.gz")))

    def test_revision6_sweep_is_complete_and_recomputes(self):
        report = json.loads((CURRENT_ARTIFACTS / "composition.json").read_text())
        self.assertEqual(report["revision"], 6)
        raw = CURRENT_ARTIFACTS / report["raw_file"]
        self.assertEqual(hashlib.sha256(raw.read_bytes()).hexdigest(), report["raw_sha256"])
        with gzip.open(raw, "rt") as stream:
            rows = [json.loads(line) for line in stream]
        self.assertEqual(len(rows), 72000)
        identities = {(r["cohort"], r["seed"], r["tier"], r["biome"]) for r in rows}
        self.assertEqual(len(identities), len(rows))
        bins = Counter((r["cohort"], r["tier"], r["biome"]) for r in rows)
        self.assertEqual(set(bins), {(c, t, b) for c in encounter_sweep.COHORTS for t in (1, 2, 3) for b in BIOMES})
        self.assertEqual(set(bins.values()), {2000})
        for row in rows:
            self.assertEqual(row["revision"], 6)
            if row["cohort"] == "warband":
                self.assertEqual(row["objective"], "kill_leader")
                self.assertEqual(row["special_type"], "warband")
                self.assertEqual(row["special_variant"], row["biome"])
                self.assertTrue(row["leader_type"])
                self.assertGreaterEqual(row["leader_distance"], 0)
            else:
                self.assertEqual(row["objective"], "kill_all")
                self.assertEqual(row["special_type"], "")
        self.assertEqual(encounter_sweep.summarize(rows), report["groups"])
        self.assertEqual(encounter_sweep.markdown(report["groups"]), (CURRENT_ARTIFACTS / "composition.md").read_text())

    def test_revision6_baseline_is_complete_and_recomputes(self):
        report = json.loads((CURRENT_ARTIFACTS / "baseline.json").read_text())
        self.assertEqual(report["revision"], 6)
        self.assertEqual(report["policy_version"], 2)
        self.assertEqual(report["runs_per_group"], 200)
        self.assertEqual({(g["tier"], g["cohort"]) for g in report["groups"]},
                         {(t, c) for t in (1, 2, 3) for c in encounter_sweep.COHORTS})
        self.assertEqual(len(report["groups"]), 6)
        historical = encounter_bot.read_report(ARTIFACTS / "bot-t1-kill_all.json.gz")
        for group in report["groups"]:
            path = CURRENT_ARTIFACTS / group["file"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), group["sha256"])
            data = encounter_bot.read_report(path)
            self.assertEqual(data["revision"], 6)
            self.assertEqual(data["cohort"], group["cohort"])
            self.assertEqual(data["decks"], historical["decks"])
            self.assertEqual(data["defaults"], historical["defaults"])
            records = data["results"]
            self.assertEqual(len(records), 200)
            self.assertEqual(len({(r["seed"], r["coord"]["x"], r["coord"]["y"]) for r in records}), 200)
            self.assertEqual(set(group["biomes"]), set(BIOMES))
            for key, value in encounter_bot.summarize(records).items():
                self.assertEqual(group[key], value)
            for row in records:
                self.assertEqual(row["revision"], 6)
                self.assertEqual(row["policy_version"], 2)
                self.assertEqual(row["tier"], group["tier"])
                self.assertEqual(row["cohort"], group["cohort"])
                self.assertEqual(row["won"], row["outcome"] == "victory")
                self.assertEqual(row["first_enemy_death_turn"] is None, row["kills"] == 0)
                self.assertEqual(row["objective"], "kill_leader" if row["cohort"] == "warband" else "kill_all")
                self.assertEqual(row["special_type"], "warband" if row["cohort"] == "warband" else "")
                self.assertEqual(row["special_variant"], row["biome"] if row["cohort"] == "warband" else "")
        tier1 = next(g for g in report["groups"] if g["tier"] == 1 and g["cohort"] == "standard")
        self.assertEqual(report["tier1_target"]["met"], tier1["win_rate"] >= .70 and tier1["hp_lost"]["median"] <= 8)

    def test_revision7_measurement_groups_and_legacy_availability(self):
        for revision in (5, 6, 7):
            groups = encounter_bot.measurement_groups(revision, 200, 50)
            guardians = [g for g in groups if g["cohort"] == "guardian"]
            bosses = [g for g in groups if g["cohort"] == "boss"]
            self.assertEqual({g["tier"] for g in guardians}, {1, 2, 3})
            self.assertEqual({g["boss_id"] for g in bosses}, set(encounter_bot.BOSS_IDS))
            self.assertTrue(all(g["tier"] == 3 and g["runs"] == 50 and not g["objective"] for g in bosses))
            self.assertTrue(all(g["runs"] == 200 and not g["objective"] for g in guardians))
            self.assertEqual(len({encounter_bot.group_stem(g, revision) for g in groups}), len(groups))
        groups = encounter_bot.measurement_groups(7, 200, 50)
        self.assertEqual(len(groups), 15)
        self.assertEqual(sum(g["runs"] for g in groups), 2100)
        self.assertEqual(len(encounter_sweep.expected_bins(7)), 60)
        self.assertEqual(len(encounter_sweep.expected_bins(5)), 42)
        self.assertEqual(encounter_sweep.TASK_ID, "meas-02")

    def test_new_cohorts_reject_overridden_objectives_and_wrong_boss_decks(self):
        cases = [(["--cohort", "guardian", "--objective", "kill_all"], "retain their own objective"),
                 (["--cohort", "boss", "--tier", "1"], "tier-3 deck preset"),
                 (["--cohort", "guardian", "--boss-id", "vyraketh"], "requires a single boss cohort")]
        for arguments, message in cases:
            with self.subTest(arguments=arguments):
                result = subprocess.run([sys.executable, "-B", str(ROOT / "tools/encounter_bot.py"), *arguments],
                                        text=True, capture_output=True, check=False)
                self.assertEqual(result.returncode, 2)
                self.assertIn(message, result.stderr)
                self.assertEqual(result.stdout, "")

    def test_revision7_sweep_is_complete_and_recomputes(self):
        output = encounter_sweep.output_for_revision(7)
        report = json.loads((output / "composition.json").read_text())
        self.assertEqual(report["revision"], 7)
        self.assertEqual(report["first_seed"], 1)
        self.assertEqual(report["seeds_per_cohort_tier_biome"], 200)
        raw = output / report["raw_file"]
        self.assertEqual(hashlib.sha256(raw.read_bytes()).hexdigest(), report["raw_sha256"])
        with gzip.open(raw, "rt") as stream:
            rows = [json.loads(line) for line in stream]
        self.assertEqual(len(rows), 12000)
        bins = Counter((r["cohort"], r["tier"], r["biome"]) for r in rows)
        self.assertEqual(set(bins), encounter_sweep.expected_bins(7))
        self.assertEqual(set(bins.values()), {200})
        self.assertEqual(len({(r["cohort"], r["tier"], r["biome"], r["seed"]) for r in rows}), len(rows))
        for row in rows:
            self.assertEqual(row["revision"], 7)
            if row["cohort"] in ("guardian", "boss"):
                self.assertEqual(row["room_type"], row["cohort"])
                self.assertEqual(row["objective"], "kill_leader")
                self.assertIn(row["boss_id"], encounter_bot.BOSS_IDS)
                self.assertTrue(row["leader_type"])
                self.assertIsNotNone(row["leader_distance"])
                if row["cohort"] == "boss":
                    self.assertEqual(row["room_tier"], 4)
                    self.assertEqual(row["tier"], 3)
                    self.assertEqual(row["leader_type"], row["boss_id"])
                else:
                    self.assertEqual(row["room_tier"], row["tier"])
                    self.assertEqual(row["leader_type"], row["guardian_id"])
        self.assertEqual(encounter_sweep.summarize(rows), report["groups"])
        self.assertEqual(encounter_sweep.markdown(report["groups"]), (output / "composition.md").read_text())

    def test_revision7_baseline_is_complete_and_recomputes(self):
        output = encounter_sweep.output_for_revision(7)
        report = json.loads((output / "baseline.json").read_text())
        previous = json.loads((CURRENT_ARTIFACTS / "baseline.json").read_text())
        historical = encounter_bot.read_report(CURRENT_ARTIFACTS / previous["groups"][0]["file"])
        self.assertEqual(report["policy_sha256"], previous["policy_sha256"])
        self.assertEqual(report["policy_version"], 2)
        self.assertEqual(report["first_seed"], 1)
        self.assertEqual(report["workers"], 6)
        self.assertEqual(report["runs_per_group"], 200)
        self.assertEqual(report["runs_per_dragon"], 50)
        expected = encounter_bot.measurement_groups(7, 200, 50)
        self.assertEqual({g["file"] for g in report["groups"]},
                         {encounter_bot.group_stem(g, 7) + ".json.gz" for g in expected})
        self.assertEqual(sum(g["n"] for g in report["groups"]), 2100)
        for group in report["groups"]:
            path = output / group["file"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), group["sha256"])
            data = encounter_bot.read_report(path)
            self.assertEqual(data["defaults"], historical["defaults"])
            self.assertEqual(data["decks"], historical["decks"])
            count = 50 if group["cohort"] == "boss" else 200
            records = data["results"]
            self.assertEqual(len(records), count)
            self.assertEqual(len({(r["seed"], r["coord"]["x"], r["coord"]["y"]) for r in records}), count)
            self.assertEqual([(r["seed"], r["section_index"]) for r in records],
                             sorted((r["seed"], r["section_index"]) for r in records))
            for key, value in encounter_bot.summarize(records).items():
                self.assertEqual(group[key], value)
            for row in records:
                self.assertEqual(row["revision"], 7)
                self.assertEqual(row["policy_version"], 2)
                self.assertEqual(row["cohort"], group["cohort"])
                self.assertEqual(row["tier"], group["tier"])
                self.assertEqual(row["objective"], group["objective"])
                self.assertEqual(row["won"], row["outcome"] == "victory")
                self.assertEqual(row["first_enemy_death_turn"] is None, row["kills"] == 0)
                if row["cohort"] in ("guardian", "boss"):
                    self.assertEqual(row["deck_tier"], 3 if row["cohort"] == "boss" else row["tier"])
                    self.assertEqual(row["room_type"], row["cohort"])
                    self.assertEqual(row["objective"], "kill_leader")
                    if row["cohort"] == "boss":
                        self.assertEqual(row["boss_id"], group["boss_id"])
                        self.assertEqual(row["room_tier"], 4)
            if group["cohort"] == "boss":
                self.assertEqual([r["seed"] for r in records], list(range(1, 51)))
        report_path = ROOT / "spec/peer_benchmark/encounter_redesign/baseline_revision7.md"
        with tempfile.TemporaryDirectory() as temporary:
            regenerated = Path(temporary) / "baseline.md"
            encounter_bot.write_baseline(report, output, regenerated)
            self.assertEqual(regenerated.read_text(), report_path.read_text())


if __name__ == "__main__":
    unittest.main()
