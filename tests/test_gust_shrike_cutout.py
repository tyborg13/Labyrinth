"""rr-03 pipeline failures and exact-registration contracts (no renderer)."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
CASE = PROJECT / "experiments/cutouts/gust_shrike/mq2"


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


Pipeline = module("rr03_pipeline", CASE / "pipeline.py")
Gates = module("rr03_motion_gates", CASE / "probes/motion_gates.py")
Compiler = module("rr03_compile_motion", CASE / "compile_motion.py")


class ShrikeCutoutTests(unittest.TestCase):
    def test_non_1024_raw_registration_scales_all_render_coordinates_once(self):
        original = Pipeline.maquette.Registration([0.25, 0.3], [-12, 9], {"raw_size": [1254, 1254]})
        with patch.object(Pipeline, "ORIGINAL_REGISTRATION", return_value=original):
            actual = Pipeline.render_registration(Path("fixture.png"), {})
        self.assertEqual(actual.point([1024, 1024]), original.point([1254, 1254]))
        self.assertEqual(actual.offset, original.offset)
        self.assertEqual(actual.trace["render_to_raw_scale"], 1254 / 1024)

    def test_missing_inputs_fail_before_creating_or_mutating_a_case(self):
        with tempfile.TemporaryDirectory(dir=PROJECT / "experiments/cutouts/gust_shrike") as temporary:
            root = Path(temporary)
            report = Pipeline.input_report(root, root / "front.png", root / "rear.png")
            self.assertFalse(report["ok"])
            self.assertEqual(len(list(root.iterdir())), 0)
            self.assertTrue(any("TODO_DESIGN_approved_raw_front" in e for e in report["errors"]))
            self.assertTrue(any("rear_solo_wing_far" in e for e in report["errors"]))

    def test_bird_recipe_keeps_six_groups_and_head_materials_together(self):
        recipe = Pipeline.read_json(CASE / "recipes/rig.json")
        self.assertEqual(set(recipe["parts"]), set(Pipeline.PARTS))
        self.assertEqual(len(set(recipe["parts"].values())), 6)
        self.assertEqual(recipe["parts"]["mask"], "head")
        self.assertEqual(recipe["parts"]["beak"], "head")
        self.assertFalse(recipe.get("cloth"))
        self.assertEqual(set(recipe["clips"]), {"idle", "move", "dive", "talon_rake", "hover", "hit", "death"})
        self.assertEqual(recipe["clips"]["idle"]["duration"], 2.4)
        self.assertEqual(recipe["clips"]["move"]["duration"], 8 * .045)

    def test_pixel_gates_reject_empty_magenta_specks_and_clipping(self):
        # Small synthetic masks exercise the gate; these are never game assets.
        pixels = np.zeros((512, 512, 4), dtype=np.uint8)
        self.assertTrue(Gates.frame_counts(pixels)["empty_frame"])
        pixels[200:240, 200:240] = [90, 70, 60, 255]
        self.assertFalse(any(Gates.frame_counts(pixels).values()))
        pixels[100, 100] = [255, 0, 255, 255]
        result = Gates.frame_counts(pixels)
        self.assertEqual(result["magenta_pixels"], 1)
        self.assertEqual(result["detached_specks"], 1)
        pixels[0, 200] = [90, 70, 60, 255]
        self.assertEqual(Gates.frame_counts(pixels)["clipped_pixels"], 1)

    def test_missing_or_changed_hashes_cannot_pass_proof(self):
        with self.assertRaises(Pipeline.CutoutError): Gates.bound_inputs(CASE, {})
        with self.assertRaises(Pipeline.CutoutError): Gates.bound_inputs(CASE, {"motion.gd": "invalid"})

    def test_native_and_cpu_gates_reject_failed_or_incomplete_samples(self):
        config = {"layouts": {"front": "unused"}, "clips": {"idle": {"frames": 2}}}
        samples = {"ok": True, "design_complete": True, "samples": [
            {"view": "front", "clip": "idle", "frame": i} for i in range(2)]}
        self.assertEqual(Gates.sample_errors(config, samples), [])
        samples["ok"] = False
        self.assertIn("Sampler/design incomplete", Gates.sample_errors(config, samples))
        samples["ok"] = True
        samples["samples"][1] = samples["samples"][0]
        self.assertIn("Incomplete/duplicated motion sampling", Gates.sample_errors(config, samples))

    def test_approved_processed_paint_still_matches_protected_record(self):
        from PIL import Image
        from art_identity_gate import pixel_digest
        for view in ["front", "rear"]:
            job = Pipeline.JOBS / ("mq2_" + view)
            self.assertEqual(pixel_digest(Image.open(job / "processed.png")), Pipeline.read_json(job / "processed.json")["pixel_sha256"])

    def test_semantic_directions_come_from_each_exported_view(self):
        spec = Pipeline.read_json(CASE.parent / "maquette/spec.json")
        views = {v: Compiler.projection(spec, v) for v in ["front", "rear"]}
        self.assertLess(views["front"]["forward"][0], 0)
        self.assertGreater(views["rear"]["forward"][0], 0)
        self.assertEqual(views["front"]["pitch_sign"], -1)
        self.assertEqual(views["rear"]["pitch_sign"], 1)
        for view in views.values():
            self.assertAlmostEqual(float(np.linalg.norm(view["forward"])), 1)
            self.assertEqual(view["legs_sign"], -view["pitch_sign"])

    def test_director_dive_recovery_keys_keep_the_six_frame_clock(self):
        data = Pipeline.read_json(Compiler.source_path(CASE))
        tracks, _ = Compiler.semantic_tracks(data, {})
        pitch = tracks["dive"]["body.pitch_deg"]
        duration = Compiler.FLIGHT_SECONDS + 6 / 30
        for frame, angle in [(1, -10), (3, -3), (6, 0)]:
            at = (Compiler.FLIGHT_SECONDS + (frame - 1) / 30) / duration
            self.assertTrue(any(abs(k["at"] - at) < 1e-9 and k["value"] == angle for k in pitch))
        self.assertEqual(pitch[-1]["value"], 0)

    def test_step2_interpolation_uses_two_frames_without_changing_director_data(self):
        source = Compiler.source_path(CASE)
        before = source.read_bytes()
        data = Pipeline.read_json(source)
        # Explicit synthetic clock/placement, not an authored gameplay choice.
        tracks, todos = Compiler.semantic_tracks(data, {"head_snap_fps": 60, "head_snap_placement": "finish"})
        self.assertFalse(todos)
        head = tracks["idle"]["head.tilt_deg"]
        self.assertAlmostEqual((head[2]["at"] - head[1]["at"]) * data["idle"]["seconds"], 2 / 60)
        self.assertEqual(head[1]["interpolation"], "hold")
        self.assertEqual(head[2]["interpolation"], "linear")
        self.assertEqual(source.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
