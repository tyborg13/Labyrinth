#!/usr/bin/env python3
"""Native measurement provenance checks; fixtures never claim renderer proof."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools/record_combat_feel_measurements.py"
SPEC = importlib.util.spec_from_file_location("measurements", MODULE_PATH)
measurements = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(measurements)


class CombatFeelMeasurementTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.paths = []
        for index in range(3):
            directory = self.root / str(index)
            directory.mkdir()
            images = []
            for filename in measurements.CAPTURES:
                image = directory / filename
                image.write_bytes(b"fixture")
                images.append({"path": str(image), "width": 1920, "height": 1080})
            (directory / "heavy_hit_trace.json").write_text(json.dumps({"headless_scheduling": False, "captured_offsets": [0, 1, 4, 8]}))
            for speed_index, speed in enumerate(measurements.SPEEDS):
                (directory / f"timeline_{speed}.json").write_text(json.dumps({"renderer": True, "speed": speed, "pass_to_hero_banner_seconds": 5 - speed_index + index / 10}))
            path = directory / "manifest.json"
            path.write_text(json.dumps({"ok": True, "namespace": str(index), "script": "tests/combat_feel_probe.gd",
                                        "command": ["godot"], "attempts": [{"accepted": True, "returncode": 0}], "images": images}))
            self.paths.append(path)

    def test_three_native_runs_update_only_owned_measurement_block(self):
        spec = self.root / "spec.md"
        spec.write_text("before\n" + measurements.START + "\npending\n" + measurements.END + "\nafter\n")
        measurements.update_spec(spec, measurements.collect_runs(self.paths))
        result = spec.read_text()
        self.assertIn("| Normal | 5.000 s | 5.100 s | 5.200 s | 5.100 s |", result)
        self.assertTrue(result.startswith("before\n"))
        self.assertTrue(result.endswith("\nafter\n"))

    def test_failed_retried_or_duplicate_runs_are_rejected(self):
        for mutation in ("failed", "retry", "duplicate"):
            with self.subTest(mutation=mutation):
                data = json.loads(self.paths[2].read_text())
                original = self.paths[2].read_text()
                if mutation == "failed": data["ok"] = False
                if mutation == "retry": data["attempts"].append(data["attempts"][0])
                if mutation == "duplicate": data["namespace"] = "0"
                self.paths[2].write_text(json.dumps(data))
                with self.assertRaises(ValueError): measurements.collect_runs(self.paths)
                self.paths[2].write_text(original)

    def test_headless_timeline_or_missing_offset_cannot_be_recorded_as_native(self):
        timeline = self.root / "0" / "timeline_normal.json"
        data = json.loads(timeline.read_text())
        data["renderer"] = False
        timeline.write_text(json.dumps(data))
        with self.assertRaises(ValueError): measurements.collect_runs(self.paths)
        data["renderer"] = True
        timeline.write_text(json.dumps(data))
        (self.root / "0" / "heavy_hit_trace.json").write_text(json.dumps({"headless_scheduling": False, "captured_offsets": [0, 1, 4]}))
        with self.assertRaises(ValueError): measurements.collect_runs(self.paths)


if __name__ == "__main__":
    unittest.main()
