"""rr-03 pipeline failures and exact-registration contracts (no renderer)."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
import shutil
import subprocess
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
Ownership = module("rr03_ownership", CASE / "repair_ownership.py")
Fills = module("rr03_fills", CASE / "repair_fills.py")
Compiler = module("rr03_compile_motion", CASE / "compile_motion.py")


class ShrikeCutoutTests(unittest.TestCase):
    def _director_mutation_fails_cpu_gate(self, mutation):
        # Recompile a disposable case and run the actual Godot sampler, as the
        # reviewer did. Protected inputs and production scripts stay untouched.
        with tempfile.TemporaryDirectory(prefix='rr03_mutation_', dir=CASE.parent) as temporary:
            root = Path(temporary)
            shutil.copytree(CASE, root, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('native_keyframes', 'round*.log', '*_result*.json'))
            original_semantic, original_projection = Compiler.semantic_tracks, Compiler.projection
            def semantic(*args):
                tracks, todos = original_semantic(*args)
                if mutation == 'missing_hold':
                    tracks['idle']['tail.lift_deg'] = [k for k in tracks['idle']['tail.lift_deg'] if k['at'] != .4]
                return tracks, todos
            def projection(*args):
                result = original_projection(*args)
                if mutation == 'reversed_tail': result['tail_sign'] *= -1
                return result
            with patch.object(Compiler, 'semantic_tracks', semantic), patch.object(Compiler, 'projection', projection):
                Compiler.compile_data(root, root / 'motion_data.gd', Pipeline.read_json(root / 'recipes/motion_interpretation.json'),
                    Pipeline.read_json(CASE / 'proof/motion_compilation.json')['proof_pixel_scale'])
            process = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-03', '--stream', '--',
                'godot', '--headless', '--path', '.', '--script', str(CASE / 'probes/motion_samples.gd'), '--',
                '--case', str(root / 'cutout.json'), '--output', str(root / 'proof/motion_samples.json')],
                cwd=PROJECT, capture_output=True, text=True, timeout=300)
            self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
            report = Gates.cpu_gates(root, root / 'proof/mutation_gate.json')
            self.assertFalse(report['ok'])
            self.assertTrue(any('idle/tail_angle: authored keys/sign differ' in e for e in report['errors']), report['errors'])

    def test_cpu_gate_rejects_missing_authored_tail_hold_after_resampling(self):
        self._director_mutation_fails_cpu_gate('missing_hold')

    def test_cpu_gate_rejects_reversed_projected_tail_after_resampling(self):
        self._director_mutation_fails_cpu_gate('reversed_tail')

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

    def test_director_round2_snap_starts_at_key_then_holds(self):
        data = Pipeline.read_json(Compiler.source_path(CASE))
        interpretation = Pipeline.read_json(CASE / "recipes/motion_interpretation.json")
        self.assertEqual(interpretation["head_snap_fps"], 30)
        self.assertEqual(interpretation["head_snap_placement"], "start")
        tracks, todos = Compiler.semantic_tracks(data, interpretation)
        self.assertFalse(todos)
        head = tracks["idle"]["head.tilt_deg"]
        poses = data["idle"]["keys"]["head"]["keys"]
        for previous, current in zip(poses, poses[1:-1]):
            start = next(k for k in head if k["at"] == current["t"])
            end = next(k for k in head if abs(k["at"] - current["t"] - 2 / 30 / 2.4) < 1e-10)
            self.assertEqual(start["value"], previous["tilt_deg"])
            self.assertEqual(start["interpolation"], "hold")
            self.assertEqual(end["value"], current["tilt_deg"])
            self.assertEqual(end["interpolation"], "linear")
        self.assertEqual(head[0]["value"], head[-1]["value"])

    def test_island_rest_bridge_does_not_keep_wrong_moving_owner(self):
        owners = np.full((8, 8), -1, dtype=np.int16)
        owners[1:4, 1:4] = 0
        owners[2:4, 4:7] = 1
        owners[4, 6] = 0  # Connected to whole rest only through part 1.
        paint = np.zeros((8, 8, 4), dtype=np.uint8)
        paint[owners >= 0] = [70, 60, 50, 255]
        before = paint.copy()
        names = ["head", "body"]
        solos = {n: owners == i for i, n in enumerate(names)}
        repaired, hidden, report = Ownership.cleanup(owners, paint, names, solos, "front", None,
            {"speck_max_exclusive_px": 12, "traced_moves": []})
        self.assertEqual(repaired[4, 6], 1)
        self.assertTrue(np.array_equal(paint, before))
        self.assertEqual(report["specks"]["head"]["move_pixels"], 1)

    def test_sparse_reference_stays_in_view_and_material_and_uses_nearest(self):
        owners = np.full((10, 15), -1, dtype=np.int16)
        owners[1, 1] = 0
        owners[2:10, 0:5] = 1
        owners[2:10, 10:15] = 2
        names = ["sparse", "near", "far"]
        reference, rule = Fills.value_reference(np.zeros((10, 15, 4), dtype=np.uint8), owners,
            names, "sparse", {n: "one material" for n in names}, {}, "rear")
        self.assertEqual(rule["part"], "near")
        self.assertTrue(np.array_equal(reference, owners == 1))
        with self.assertRaises(Pipeline.CutoutError):
            Fills.value_reference(np.zeros((10, 15, 4), dtype=np.uint8), owners,
                names, "sparse", {n: n for n in names}, {}, "rear")

    def test_thin_hidden_fill_keeps_midtones_without_changing_visible_pixels(self):
        # Reproduce the wing's 15 outline pixels out of a 16-pixel hidden region.
        pixels = np.full((5, 5, 4), [20, 16, 21, 255], dtype=np.uint8)
        pixels[4] = [90, 80, 70, 255]
        before = pixels.copy()
        hidden = np.zeros((5, 5), dtype=bool); hidden[:4, :4] = True
        reference = np.repeat(np.array([[40, 35, 30], [70, 60, 50], [100, 90, 80]], dtype=np.uint8), [10, 30, 10], axis=0)
        after = Fills.match_values(pixels, hidden, reference)
        self.assertTrue(np.array_equal(after[~hidden], before[~hidden]))
        self.assertTrue(np.array_equal(after[..., 3], before[..., 3]))
        source_l = Pipeline.maquette.to_lab(reference)[:, 0]
        actual_l = Pipeline.maquette.to_lab(after[hidden, :3])[:, 0]
        self.assertLessEqual(abs(np.median(actual_l) - np.median(source_l)), 8)
        low, high = np.percentile(source_l, [25, 75])
        self.assertTrue(((actual_l >= low) & (actual_l <= high)).any())

    def test_redundant_underlay_requires_identical_rigid_bone_and_complete_cover(self):
        owners = np.zeros((5, 5), dtype=np.int16)
        names = ["head", "beak"]
        hidden = [np.zeros((5, 5), dtype=bool), np.zeros((5, 5), dtype=bool)]
        hidden[1][1:4, 1:4] = True
        initial = [h.copy() for h in hidden]
        records = Ownership.remove_redundant_hidden(owners, hidden, names,
            {"head": "head", "beak": "head"}, names)
        self.assertEqual(records[0]["pixels"], 9)
        self.assertFalse(hidden[1].any())
        hidden = [h.copy() for h in initial]
        self.assertEqual(Ownership.remove_redundant_hidden(owners, hidden, names,
            {"head": "head", "beak": "different_bone"}, names), [])
        self.assertTrue(np.array_equal(hidden[1], initial[1]))
        owners[2, 2] = -1
        hidden = [h.copy() for h in initial]
        self.assertEqual(Ownership.remove_redundant_hidden(owners, hidden, names,
            {"head": "head", "beak": "head"}, names), [])


if __name__ == "__main__":
    unittest.main()
