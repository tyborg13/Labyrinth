"""Behavioral checks for the sync audit and the timing-only audio rebuild."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import numpy as np
from tools.sfx_lab.common import LabError, decode
from tools.sfx_lab.sync import leading_ms, trim_onset, variant_from_provenance
from tools.sfx_lab.sync_align import trim_samples, constraints
from tools.sfx_lab.sync_metrics import envelope_times, short_loudness, onset_cap
from tools.sfx_sync_audit import analyze, digest, source_sites, site_identity, coverage_regressions


class TimingTrimTests(unittest.TestCase):
    RATE = 48000

    def test_trim_and_fade_preserve_the_tail_and_level(self):
        samples = np.zeros((2400, 2))
        samples[720:, 0] = 0.2
        samples[720:, 1] = -0.1
        trimmed, provenance = trim_onset(samples, self.RATE)
        removed = provenance["removed_samples"]
        self.assertEqual(provenance["fade_in_ms"], 2)
        self.assertLessEqual(leading_ms(trimmed, self.RATE), 5)
        np.testing.assert_array_equal(trimmed[96:], samples[removed + 96:])
        self.assertEqual(float(np.max(np.abs(trimmed))), 0.2)

    def test_threshold_is_strict_and_checks_both_channels(self):
        threshold = 10 ** (-45 / 20)
        samples = np.full((480, 2), threshold)
        samples[240, 1] = threshold * 1.001
        self.assertEqual(leading_ms(samples, self.RATE), 5)

    def test_silent_audio_cannot_be_reported_as_zero_lead(self):
        with self.assertRaises(LabError):
            leading_ms(np.zeros((480, 1)), self.RATE)

    def test_rebuilt_assets_keep_the_original_non_timing_parameters(self):
        original = json.loads((ROOT / "spec/assets/sfx/manifest.json").read_text())
        overlay = json.loads((ROOT / "assets/audio/sfx/sfx-04-provenance.json").read_text())
        by_path = {entry["path"]: entry for entry in original["outputs"]}
        self.assertEqual(sum("sfx_04" in entry["processing"] for entry in overlay["outputs"]), 4)
        self.assertEqual(overlay["parent_manifest_sha256"], digest(ROOT / overlay["parent_manifest"]))
        measured_fields = {"output_duration", "output_lufs", "output_loudness_method", "output_peak_dbfs", "sfx_04", "sfx_04_alignment"}
        for rebuilt in overlay["outputs"]:
            parent = by_path[rebuilt["path"]]
            with self.subTest(sample=rebuilt["path"]):
                self.assertEqual(rebuilt["parent_output_sha256"], parent["output_sha256"])
                self.assertEqual(variant_from_provenance(rebuilt), variant_from_provenance(parent))
                self.assertEqual({key: value for key, value in rebuilt["processing"].items() if key not in measured_fields},
                                 {key: value for key, value in parent["processing"].items() if key not in measured_fields})
                path = ROOT / "assets/audio/sfx/cues" / rebuilt["path"]
                self.assertEqual(digest(path), rebuilt["output_sha256"])
                samples, rate = decode(path)
                removed = int(rebuilt["processing"].get("sfx_04", {}).get("removed_samples", 0))
                removed += int(rebuilt["processing"].get("sfx_04_alignment", {}).get("removed_samples", 0))
                recipe = parent["processing"]
                source_seconds = (recipe["excerpt_end_seconds"] - recipe["excerpt_start_seconds"]) / recipe["pitch"]
                expected_frames = round(source_seconds * rate) - removed
                # Vorbis remux granules can retain trailing codec padding (the
                # parent relic.trigger already has 928 such frames). Compare
                # against the approved source excerpt, not that old padding.
                self.assertGreaterEqual(len(samples), expected_frames - 1,
                                        "The encoded output must retain the complete source tail")
                self.assertLessEqual(leading_ms(samples, rate), 5 if "sfx_04" in rebuilt["processing"] else 10)
                if "sfx_04" in rebuilt["processing"]:
                    self.assertEqual(rebuilt["processing"]["sfx_04"]["task"], "sfx-04")
                alignment = rebuilt["processing"].get("sfx_04_alignment")
                if alignment:
                    self.assertFalse(rebuilt["loop"])
                    self.assertEqual(alignment["fade_in_ms"], 3)
                    self.assertGreaterEqual(alignment["retained_pre_peak_ms"], 15)
                    self.assertTrue(alignment["tail_preserved"])
                    metrics = envelope_times(samples, rate)
                    self.assertLessEqual(metrics["perceived_onset_ms"], alignment["constraints"]["max_onset_ms"])
                    if alignment["constraints"]["max_peak_ms"] is not None:
                        self.assertLessEqual(metrics["peak_ms"], alignment["constraints"]["max_peak_ms"])
                        self.assertGreaterEqual(metrics["peak_ms"], alignment["constraints"]["min_peak_ms"])
                    measured = short_loudness(path)
                    self.assertLessEqual(abs(measured - alignment["before"]["short_loudness_lufs"]), 0.5)

    def test_envelope_searches_the_whole_sample_not_an_early_window(self):
        samples = np.zeros((self.RATE, 2))
        samples[4800:5280] = 0.1
        samples[38400:38880] = 0.8
        metrics = envelope_times(samples, self.RATE)
        self.assertGreater(metrics["perceived_onset_ms"], 790)
        self.assertGreater(metrics["peak_ms"], 800)
        self.assertLess(metrics["peak_ms"], 810)

    def test_envelope_uses_channel_power_without_stereo_cancellation(self):
        samples = np.zeros((4800, 2))
        samples[2400:2880, 0] = 0.5
        samples[:, 1] = -samples[:, 0]
        self.assertEqual(envelope_times(samples, self.RATE), envelope_times(samples[:, :1], self.RATE))

    def test_alignment_preserves_tail_and_rejects_clipped_pre_peak(self):
        samples = np.zeros((4800, 2))
        samples[2400:2880] = 0.5
        samples[2880:] = 0.1
        removed = 1000
        trimmed = trim_samples(samples, self.RATE, removed)
        np.testing.assert_array_equal(trimmed[144:], samples[removed + 144:])
        self.assertTrue(np.all(trimmed[0] == 0))
        with self.assertRaisesRegex(LabError, "less than 15 ms"):
            trim_samples(samples, self.RATE, 2400)


class AuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = json.loads((ROOT / "spec/peer_benchmark/staged/sfx/sync_audit.json").read_text())
        cls.cues = json.loads((ROOT / "data/sfx_cues.json").read_text())["cues"]

    @staticmethod
    def event(observation: dict) -> dict:
        sites = {site_identity(site): site for site in source_sites(ROOT)}
        # Reconstruct the synthetic test stack from stable statement identities,
        # never from the saved report's line positions.
        current = [sites[site_identity(site)] for site in observation["call_sites"]]
        return {"scenario": "regression", **{key: observation[key] for key in
                ("cue", "result", "delay_ms", "pitch", "climax_applicable", "climax_kind", "climax_after_trigger_ms")},
                "alignment": copy.deepcopy(observation.get("alignment") or {}),
                "stack": [{"source": "res://" + frame["file"], "line": frame["line"], "function": frame["function"]} for frame in current],
                "anchor_stack": [{"source": "res://" + frame["file"], "line": frame["line"], "function": frame["function"]} for frame in observation["visual_anchor"]],
                "climax_stack": [{"source": "res://" + frame["file"], "line": frame["line"], "function": frame["function"]} for frame in observation["visual_climax"]]}

    def test_after_covers_every_cue_and_live_call_site(self):
        after = self.report["after"]
        self.assertFalse(after["uncovered_cues"])
        self.assertFalse(after["uncovered_call_sites"])
        self.assertFalse(after["uncovered_cue_call_site_pairs"])
        self.assertFalse(after["harness_failures"])
        self.assertEqual(after["summary"]["cues"], len(self.cues))
        self.assertEqual(after["summary"]["violations"], 0)
        self.assertEqual(after["summary"]["unmeasured"], 0)
        self.assertEqual({site_identity(site) for site in after["call_site_inventory"]},
                         {site_identity(site) for site in source_sites(ROOT)})

    def test_per_call_alignment_uses_actual_pitch_and_preserves_verified_assets(self):
        after = self.report["after"]
        aligned = [event for event in after["observations"] if event.get("alignment")]
        self.assertEqual({event["scenario"] for event in aligned}, {
            "player/swap", "enemy/eclipse", "dragon/area/false", "dragon/area/true", "dragon/breath"})
        for observation in aligned:
            alignment = observation["alignment"]
            self.assertTrue(alignment["fade_and_tail_verified"])
            self.assertTrue(alignment["pcm_sha256"])
            relative = observation["delay_ms"] + alignment["metrics"]["peak_ms"] / observation["pitch"] - observation["climax_after_trigger_ms"]
            self.assertAlmostEqual(relative, 15, delta=0.1)
            event = self.event(observation)
            for mutation in ("peak_ms", "fade_and_tail_verified"):
                broken = copy.deepcopy(event)
                if mutation == "peak_ms": broken["alignment"]["metrics"][mutation] += 50
                else: broken["alignment"][mutation] = False
                result = analyze(ROOT, {"rows": [broken], "failures": [], "frame_usec": 16667}, self.cues, after["samples"])
                self.assertGreater(result["summary"]["violations"], 0)
        for path, sample in after["samples"].items():
            self.assertEqual(sample["sha256"], self.report["feedback_2_before"]["samples"][path]["sha256"])

    def test_same_frame_three_target_area_matches_single_hit_loudness(self):
        proof = self.report["after"]["area_loudness"]
        self.assertTrue(proof["pass"])
        self.assertEqual(proof["area/same_frame"]["voices"], 1)
        self.assertEqual(proof["area/single"]["voices"], 1)
        self.assertLessEqual(abs(proof["delta_lu"]), 0.5)

    def test_coverage_identity_ignores_unrelated_lines_but_detects_statement_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "data").mkdir()
            (root / "data/sfx_cues.json").write_text(json.dumps({"cues": self.cues}))
            names = {"sfx_cue_router.gd", "run_scene.gd", "sfx_bank.gd"}
            expected = {site_identity(site) for site in source_sites(ROOT) if Path(site["file"]).name in names}
            for name in names:
                source = (ROOT / "scripts" / name).read_text()
                source = "# Unrelated developer note\n\n" + source.replace("\nfunc ", "\n\n# Another unrelated note\nfunc ")
                (root / "scripts" / name).write_text(source)
            self.assertEqual(expected, {site_identity(site) for site in source_sites(root)})
            changed = root / "scripts/sfx_cue_router.gd"
            changed.write_text(changed.read_text().replace('request("move.blink",', 'request("move.blink" + "",'))
            self.assertNotEqual(expected, {site_identity(site) for site in source_sites(root)})

    def test_observation_and_cue_site_coverage_cannot_shrink(self):
        after = self.report["after"]
        fewer = copy.deepcopy(after)
        fewer["observations"].pop()
        self.assertTrue(coverage_regressions(fewer, after))
        fewer = copy.deepcopy(after)
        fewer["rows"].pop()
        self.assertTrue(coverage_regressions(fewer, after))
        shifted = copy.deepcopy(after)
        for row in shifted["rows"]:
            row["call_site"]["line"] += 100
        self.assertFalse(coverage_regressions(shifted, after))

    def test_every_cue_call_site_meets_perceived_caps_peak_alignment_and_loudness(self):
        after = self.report["after"]
        for row in after["rows"]:
            with self.subTest(cue=row["cue"], site=row["call_site"]):
                if row["verdict"] == "dropped" or row["loop"]:
                    continue
                self.assertLessEqual(row["perceived_onset_max_ms"], onset_cap(row["cue"], self.cues[row["cue"]]))
                if row["climax_min_ms"] is not None:
                    self.assertLessEqual(row["peak_relative_climax_max_ms"], 30)
                for path in row["leading_silence_ms"]:
                    sample = after["samples"][path]
                    self.assertEqual(digest(ROOT / path.removeprefix("res://")), sample["sha256"])
                    if sample.get("peak_aligned") and row["climax_min_ms"] is not None:
                        self.assertGreaterEqual(row["peak_relative_climax_min_ms"], 0)
                    self.assertLessEqual(abs(sample["short_loudness_lufs"] - self.report["feedback_1_before"]["samples"][path]["short_loudness_lufs"]), 0.5)

    def test_late_body_or_peak_fails_even_with_zero_leading_silence(self):
        observation = next(event for event in self.report["after"]["observations"] if event["cue"] == "hit.blade.light" and event["result"] == "played")
        event = self.event(observation)
        for changed in ("perceived_onset_ms", "peak_ms"):
            samples = copy.deepcopy(self.report["after"]["samples"])
            for path in self.cues[event["cue"]]["variants"]:
                samples[path]["leading_ms"] = 0
                samples[path][changed] = 100
            result = analyze(ROOT, {"rows": [event], "failures": [], "frame_usec": 16667}, self.cues, samples)
            self.assertGreater(result["summary"]["violations"], 0)

    def test_missing_climax_cannot_inherit_a_passing_trigger(self):
        observation = next(event for event in self.report["after"]["observations"] if event["cue"] == "move.blink" and event["result"] == "played")
        event = self.event(observation)
        event["climax_after_trigger_ms"] = None
        result = analyze(ROOT, {"rows": [event], "failures": [], "frame_usec": 16667}, self.cues, self.report["after"]["samples"])
        self.assertGreater(result["summary"]["unmeasured"], 0)

    def test_cooldown_requests_do_not_move_the_required_sample_peak(self):
        phase = copy.deepcopy(self.report["feedback_1_before"])
        phase["observations"] = [row for row in phase["observations"] if row["cue"] == "fatigue"]
        played_only = {**phase, "observations": [row for row in phase["observations"] if row["result"] == "played"]}
        self.assertTrue(any(row["result"] == "cooldown" and row["delay_ms"] > 40 for row in phase["observations"]))
        self.assertEqual(constraints(phase, self.cues), constraints(played_only, self.cues))

    def test_incompatible_climaxes_fail_instead_of_clipping_the_transient(self):
        phase = copy.deepcopy(self.report["feedback_1_before"])
        phase["observations"] = [row for row in phase["observations"] if row["cue"] == "move.blink" and row["result"] == "played"]
        self.assertGreaterEqual(len(phase["observations"]), 2)
        phase["observations"][0]["climax_after_trigger_ms"] = 0.0
        with self.assertRaisesRegex(LabError, "incompatible_peak_windows"):
            constraints(phase, self.cues)

    def test_new_unmeasured_site_is_not_covered_by_an_existing_cue(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "data").mkdir()
            (root / "data/sfx_cues.json").write_text(json.dumps({"cues": self.cues}))
            for name in ("sfx_cue_router.gd", "run_scene.gd", "sfx_bank.gd"):
                (root / "scripts" / name).write_text((ROOT / "scripts" / name).read_text())
            (root / "scripts/new_delayed_cue.gd").write_text('extends Node\nfunc later():\n\tbank.play("move.blink")\n')
            result = analyze(root, {"rows": [], "failures": [], "frame_usec": 16667}, self.cues, self.report["after"]["samples"])
            self.assertTrue(any(site["file"] == "scripts/new_delayed_cue.gd" for site in result["uncovered_call_sites"]))

    def test_early_and_delayed_cues_fail_the_measured_window(self):
        observation = next(event for event in self.report["after"]["observations"] if event["cue"] == "hit.blade.light" and event["result"] == "played")
        for delay in (-100.0, 21.0):
            event = self.event(observation)
            event["delay_ms"] = delay
            result = analyze(ROOT, {"rows": [event], "failures": [], "frame_usec": 16667}, self.cues, self.report["after"]["samples"])
            self.assertGreater(result["summary"]["violations"], 0)

    def test_sample_onset_and_pitch_are_part_of_the_bound(self):
        observation = next(event for event in self.report["after"]["observations"] if event["cue"] == "hit.blade.light" and event["result"] == "played")
        event = self.event(observation)
        samples = copy.deepcopy(self.report["after"]["samples"])
        for path in self.cues[event["cue"]]["variants"]:
            samples[path]["leading_ms"] = 25
        result = analyze(ROOT, {"rows": [event], "failures": [], "frame_usec": 16667}, self.cues, samples)
        self.assertGreater(result["summary"]["violations"], 0)


if __name__ == "__main__":
    unittest.main()
