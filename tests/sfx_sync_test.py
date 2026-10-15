"""Timing, first-transient preservation, and reproducible sync-build contracts."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import numpy as np

from tools.sfx_lab.common import decode, encode, sha256
from tools.sfx_lab.sync_align import quiet_cut, rebuild_aligned
from tools.sfx_lab.sync_metrics import RULES, envelope_times
from tools.sfx_sync_audit import analyze, source_sites, site_identity, coverage_regressions, compact_baseline, playback_failures

BASELINE = ROOT / "spec/peer_benchmark/staged/sfx/sync_baseline.json"
PROVENANCE = ROOT / "assets/audio/sfx/sfx-04-provenance.json"


class TransientTests(unittest.TestCase):
    def test_first_nearly_equal_transient_wins(self):
        rate = 48000
        times = np.arange(9600) / rate
        for first_gain, expected in [(0.9, 50), (0.6, 100)]:
            mono = first_gain * np.exp(-((times - .05) / .003) ** 2) + np.exp(-((times - .1) / .003) ** 2)
            result = envelope_times(mono[:, None], rate)
            self.assertAlmostEqual(result["peak_ms"], expected, delta=.1)
            self.assertAlmostEqual(result["strongest_peak_ms"], 100, delta=.1)

    def test_quiet_cut_checks_both_channels_before_fading(self):
        data = np.zeros((4800, 2))
        data[1000:2000] = [.01, .8]
        data[2000:2400] = .9
        data[2400:2700] = 1
        peak = round(envelope_times(data, 48000)["peak_ms"] * 48)
        cut, relative = quiet_cut(data, 48000, 1800, peak)
        self.assertEqual(cut, 999)
        self.assertLessEqual(relative, -RULES["cut_below_peak_db"])

    def test_short_ogg_preserves_eos_and_is_deterministic(self):
        rate = 48000
        data = (.1 * np.sin(np.arange(3840) * 2 * np.pi * 120 / rate))[:, None]
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / name for name in ["a.ogg", "b.ogg"]]
            for path in paths: encode(path, data, rate, "ogg")
            self.assertEqual(sha256(paths[0]), sha256(paths[1]))
            decoded, actual_rate = decode(paths[0])
            self.assertEqual(actual_rate, rate)
            self.assertEqual(len(decoded), len(data))
            raw = paths[0].read_bytes()
            offset = 0
            granule = -1
            while offset < len(raw):
                self.assertEqual(raw[offset:offset + 4], b"OggS")
                segments = raw[offset + 26]
                size = 27 + segments + sum(raw[offset + 27:offset + 27 + segments])
                if raw[offset + 5] & 4:
                    granule = int.from_bytes(raw[offset + 6:offset + 14], "little")
                offset += size
            self.assertEqual(granule, len(data))


class EvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = json.loads(BASELINE.read_text())
        cls.provenance = json.loads(PROVENANCE.read_text())
        cls.cues = json.loads((ROOT / "data/sfx_cues.json").read_text())["cues"]

    def test_measurements_bind_every_audio_file(self):
        for path, sample in self.baseline["samples"].items():
            with self.subTest(path=path):
                self.assertEqual(sha256(ROOT / path.removeprefix("res://")), sample["sha256"])
                self.assertGreater(sample["duration_seconds"], 0)
        self.assertEqual(self.baseline["speeds"], [1, 1.5, 2])
        self.assertEqual(len(self.baseline["runs"]), 15)
        self.assertEqual({run[0] for run in self.baseline["runs"]}, {"fixed_60", "spikes", "fixed_30", "fixed_144", "jitter"})
        scenarios = [{key.rsplit("|", 1)[0] for key, counts in self.baseline["request_counts"].items() if counts[index] > 0} for index in range(15)]
        self.assertTrue(all(scenarios[0] == value for value in scenarios))

    def test_primary_priority_drop_cannot_pass_as_request_coverage(self):
        event = {"scenario": "weapon/spear/3", "cue": "hit.pierce", "result": "played", "speed": 1,
                 "frame_profile": "spikes", "request": {"role": "primary"}}
        result = {"observations": [event], "silences": [], "samples": {}, "rows": [], "summary": {}}
        baseline = compact_baseline(result)
        self.assertEqual(coverage_regressions(result, baseline), [])
        event["result"] = "priority"
        errors = coverage_regressions(result, baseline)
        self.assertTrue(any("Required primary did not play" in error for error in errors))
        self.assertTrue(any("primary_play_counts shrank" in error for error in errors))
        self.assertFalse(any("request_counts shrank" in error for error in errors))

    def test_only_explicit_optional_and_valid_cooldown_drops_are_allowed(self):
        event = {"scenario": "fixture", "cue": "hit.pierce", "result": "priority", "request": {"role": "optional_layer"}}
        self.assertEqual(playback_failures([event]), [])
        event.update(result="cooldown", request={"role": "primary", "since_success_ms": 12, "cooldown_ms": 30})
        self.assertEqual(playback_failures([event]), [])
        for elapsed in [-1, 30, 100]:
            event["request"]["since_success_ms"] = elapsed
            self.assertTrue(playback_failures([event]))

    def test_call_identity_ignores_neighbors_and_tracks_statement(self):
        path = "scripts/sfx_cue_router.gd"
        source = (ROOT / path).read_text()
        original = {site_identity(site) for site in source_sites(ROOT)}
        edited = source.replace('func blink(', '# Harmless adjacent comment\n\nfunc blink(')
        edited = edited.replace('\trequest("move.blink",', '\t# A harmless neighboring statement\n\tvar observation_only: int = 0\n\trequest("move.blink",')
        self.assertEqual(original, {site_identity(site) for site in source_sites(ROOT, {path: edited})})
        edited = source.replace('request("move.blink",', 'request("move.blink", {"gain_db": -1},')
        self.assertNotEqual(original, {site_identity(site) for site in source_sites(ROOT, {path: edited})})

    def test_actual_aligned_pcm_must_hit_plus_15(self):
        site = next(site for site in source_sites(ROOT) if site["file"] == "scripts/sfx_cue_router.gd" and site["function"] == "blink")
        frame = {"source": "res://" + site["file"], "function": site["function"], "line": site["line"]}
        event = {"scenario": "fixture", "speed": 2, "cue": "move.blink", "result": "played", "delay_ms": 0,
                 "pitch": 1, "stack": [frame], "anchor_stack": [frame], "climax_stack": [frame],
                 "climax_applicable": True, "climax_kind": "observed", "climax_after_trigger_ms": 0,
                 "alignment": {"metrics": {"peak_ms": 15.01, "perceived_onset_ms": 1}, "rate": 48000, "fade_and_tail_verified": True}}
        for peak, verdict in [(15.01, "pass"), (17.01, "violation"), (14.0, "violation")]:
            event["alignment"]["metrics"]["peak_ms"] = peak
            result = analyze(ROOT, {"rows": [event], "failures": [], "frame_usec": 16667}, self.cues, self.baseline["samples"])
            self.assertEqual(result["rows"][0]["verdict"], verdict)

    def test_compact_provenance_keeps_sources_cuts_and_caps(self):
        p = self.provenance
        self.assertEqual(p["schema_version"], 3)
        self.assertEqual(p["parent_manifest_sha256"], sha256(ROOT / p["parent_manifest"]))
        for row in p["outputs"]:
            with self.subTest(path=row["path"]):
                self.assertNotIn("processing", row)
                self.assertEqual(row["output_sha256"], sha256(ROOT / "assets/audio/sfx/cues" / row["path"]))
                self.assertLessEqual(row["after"]["peak_dbfs"], row["constraints"]["peak_cap_dbfs"])
                self.assertLessEqual(row["after"]["true_peak_dbtp"], RULES["true_peak_ceiling_dbtp"])
                if row["removed_samples"]:
                    self.assertLessEqual(row["cut_relative_db"], -RULES["cut_below_peak_db"])
                    self.assertGreaterEqual(row["source_peak_ms"] - row["removed_samples"] * 1000 / row["sample_rate"], RULES["minimum_pre_peak_ms"] - .0001)
                self.assertEqual(row["fade_ms"], RULES["fade_ms"])
                self.assertIn(row["build"], p["builds"])

    def test_plain_rebuild_is_a_no_write_no_source_scan(self):
        before = PROVENANCE.read_bytes()
        with patch("tools.sfx_lab.sync_align.TakeLibrary", side_effect=AssertionError("Idempotent build must not scan sources")):
            rebuild_aligned(ROOT, ROOT / self.provenance["parent_manifest"], ROOT / ".godot/sfx_lab/features.jsonl", PROVENANCE)
        self.assertEqual(before, PROVENANCE.read_bytes())

    def test_portable_compact_evidence(self):
        for path in [BASELINE, PROVENANCE, BASELINE.with_name("sync_audit.md")]:
            text = path.read_text()
            self.assertNotIn("/Users/", text)
            self.assertNotIn("/private/tmp/", text)
            self.assertNotIn("/var/folders/", text)
        self.assertNotIn("feedback_1_before", PROVENANCE.read_text())
        self.assertFalse(BASELINE.with_name("sync_audit.json").exists())

    def test_full_report_cannot_overwrite_tracked_evidence(self):
        before = BASELINE.read_bytes()
        for destination in [str(BASELINE), "output/unignored-sync-report.json"]:
            result = subprocess.run([sys.executable, "tools/sfx_sync_audit.py", "--report", destination], cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("gitignored output/sfx/", result.stderr)
        self.assertEqual(BASELINE.read_bytes(), before)
        self.assertFalse((ROOT / "output/unignored-sync-report.json").exists())

    def test_every_capped_loudness_exception_is_disclosed(self):
        report = BASELINE.with_name("sync_audit.md").read_text()
        for row in self.provenance["outputs"]:
            delta = row["after"]["loudness_delta_lu"]
            if not RULES["loudness_delta_lu"][0] <= delta <= RULES["loudness_delta_lu"][1]:
                self.assertIn(row["path"] + f": capped loudness outside window ({delta:+.3f} LU)", report)


if __name__ == "__main__":
    unittest.main()
