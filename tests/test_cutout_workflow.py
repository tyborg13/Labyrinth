#!/usr/bin/env python3
"""Observable contracts for portable cutout authoring and its retained evidence."""
import copy
import json
import sys
import shutil
from unittest.mock import patch
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from cutout_pipeline.assets import apply_skin, replace_part, segment, skin_mesh
from cutout_pipeline.cases import CutoutError, PROJECT, baseline, case_hashes, fork_case, init_case, local_path, read_json, seed_protagonist, write_json
from cutout_pipeline.proof import pack, verify_render
from cutout_pipeline.cases import digest
from cutout_pipeline.validation import validate, validate_layout


class CutoutWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cutout-workflow-test-")
        self.root = Path(self.temporary.name).resolve()

    def tearDown(self):
        self.temporary.cleanup()

    def creature(self):
        case = init_case(self.root / "crawler", "crawler", ["side"])
        image = Image.new("RGBA", (8, 8), (93, 56, 114, 255))
        image.save(case.parent / "body.png")
        layout = read_json(case.parent / "layouts/side.json")
        layout["joints"]["tail"] = {"parent": "root", "position": [136, 210]}
        layout["parts"] = [{"name": "body", "bone": "root", "offset": [124, 204], "file": "body.png"}]
        write_json(case.parent / "layouts/side.json", layout)
        baseline(case)
        return case

    def test_new_anatomy_is_unbuilt_until_painted_and_does_not_assume_humanoid(self):
        case = init_case(self.root / "empty", "wisp", ["side"])
        result = validate(case)
        self.assertFalse(result["ok"])
        self.assertIn("No painted parts", result["errors"][0])
        result = validate(self.creature())
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["layouts"]["side"]["joints"], 2)

    def test_paths_cannot_escape_even_through_symlinks(self):
        outside = self.root / "outside"
        outside.mkdir()
        root = self.root / "case"
        root.mkdir()
        (root / "link").symlink_to(outside, target_is_directory=True)
        for path in ["../outside/file", "link/file", "/absolute/file", "res://paint.png"]:
            with self.subTest(path=path), self.assertRaises(CutoutError):
                local_path(root, path)
        self.assertEqual(local_path(root, "assets/piece.png"), root / "assets/piece.png")

    def test_seed_matches_production_and_copies_portable_sources(self):
        production_before = {str(p): p.read_bytes() for folder in ["assets/units/protagonist_cutout", "scripts/protagonist_cutout"] for p in (PROJECT / folder).rglob("*") if p.is_file()}
        case = seed_protagonist(self.root / "seed", "protagonist_guard")
        self.assertTrue(validate(case, "all")["ok"])
        config = read_json(case)
        self.assertAlmostEqual(config["clips"]["idle"]["duration"], 0.84)
        self.assertAlmostEqual(config["clips"]["walk"]["duration"], 0.30)
        self.assertAlmostEqual(config["clips"]["attack"]["duration"], 0.50)
        self.assertEqual((case.parent / "motion.gd").read_bytes(), (PROJECT / "scripts/protagonist_cutout/motion.gd").read_bytes())
        for facing, relative in config["layouts"].items():
            layout = read_json(case.parent / relative)
            original = read_json(PROJECT / f"assets/units/protagonist_cutout/{facing}.json")
            for part, reference in zip(layout["parts"], original["parts"]):
                self.assertEqual((case.parent / part["file"]).read_bytes(), (PROJECT / reference["file"].removeprefix("res://")).read_bytes())
        self.assertTrue(all(Path(p).read_bytes() == data for p, data in production_before.items()))

    def test_art_protection_allows_motion_but_rejects_paint_and_layout_changes(self):
        case = self.creature()
        with (case.parent / "motion.gd").open("a") as stream:
            stream.write("\n# Another action can be authored independently.\n")
        self.assertTrue(validate(case, "art")["ok"])
        self.assertFalse(validate(case, "all")["ok"])
        image = Image.open(case.parent / "body.png")
        image.putpixel((0, 0), (0, 0, 0, 255))
        image.save(case.parent / "body.png")
        self.assertFalse(validate(case, "art")["ok"])
        baseline(case)
        layout = read_json(case.parent / "layouts/side.json")
        layout["parts"][0]["offset"][0] += 1
        write_json(case.parent / "layouts/side.json", layout)
        self.assertFalse(validate(case, "art")["ok"])

    def test_fork_has_no_dependency_on_source_or_old_proofs(self):
        source = self.creature()
        (source.parent / "old_preview.mp4").write_bytes(b"not a runtime input")
        fork = fork_case(source, self.root / "variant", "crawler_wave")
        self.assertFalse((fork.parent / "old_preview.mp4").exists())
        source.parent.rename(self.root / "unavailable-source")
        self.assertTrue(validate(fork, "all")["ok"])
        with self.assertRaises(CutoutError):
            init_case(fork.parent, "overwrite", ["front"])

    def test_manual_segmentation_preserves_partial_alpha_and_reports_unassigned_pixels(self):
        source = Image.new("RGBA", (255, 255))
        source.putpixel((10, 20), (90, 40, 20, 128))
        source.putpixel((11, 20), (50, 120, 90, 255))
        source.save(self.root / "source.png")
        recipe = self.root / "ownership.json"
        write_json(recipe, {"priority_polygons": [["body", [[9, 19], [10, 19], [10, 21], [9, 21]]]]})
        report = segment(self.root / "source.png", recipe, self.root / "missing")
        self.assertFalse(report["ok"])
        self.assertEqual(report["unassigned_coordinates"], [(11, 20)])
        write_json(recipe, {"priority_polygons": [["body", [[9, 19], [12, 19], [12, 21], [9, 21]]]]})
        report = segment(self.root / "source.png", recipe, self.root / "complete")
        self.assertTrue(report["ok"])
        self.assertEqual(Image.open(self.root / "complete/reconstructed.png").tobytes(), source.tobytes())
        self.assertEqual(Image.open(self.root / "complete/body.png").getpixel((0, 0)), (90, 40, 20, 128))

    def test_shared_skin_reproduces_all_six_approved_rear_leg_meshes(self):
        layout = read_json(PROJECT / "assets/units/protagonist_cutout/rear.json")
        for original in layout["joint_meshes"]:
            if not original.get("family", "").startswith("rear_leg_"):
                continue
            part = next(p for p in layout["parts"] if p["name"] == original["replaces_part"])
            side = part["name"][-1]
            knee = layout["joints"]["shin_" + side]["position"][1]
            ankle = layout["joints"]["foot_" + side]["position"][1]
            field = {"name": "rear_leg_" + side, "bones": ["thigh_" + side, "shin_" + side, "foot_" + side], "bands": [{"center": [0, knee], "axis": [0, 1], "width": 16}, {"center": [0, ankle - 5], "axis": [0, 1], "width": 12}]}
            with Image.open(PROJECT / part["file"].removeprefix("res://")) as image:
                size = image.size
            self.assertEqual(skin_mesh(part, size, field), original)

    def test_structural_failures_reject_cycles_bad_uvs_and_nonshared_weights(self):
        case = self.creature()
        layout = read_json(case.parent / "layouts/side.json")
        field = {"name": "tail", "bones": ["root", "tail"], "bands": [{"center": [128, 208], "axis": [1, 0], "width": 4}]}
        mesh = skin_mesh(layout["parts"][0], (8, 8), field)
        layout["joint_meshes"] = [mesh]
        validate_layout(case.parent, layout, "side", [], [])
        broken = copy.deepcopy(layout)
        broken["joints"]["root"]["parent"] = "tail"
        with self.assertRaisesRegex(CutoutError, "cyclic"):
            validate_layout(case.parent, broken, "side", [], [])
        broken = copy.deepcopy(layout)
        broken["joint_meshes"][0]["uvs"][0][0] = 100
        with self.assertRaisesRegex(CutoutError, "UV outside"):
            validate_layout(case.parent, broken, "side", [], [])
        broken = copy.deepcopy(layout)
        extra = copy.deepcopy(mesh)
        extra.update({"name": "other"})
        extra.pop("replaces_part")
        extra["weights"]["root"][0] = 0.25
        extra["weights"]["tail"][0] = 0.75
        broken["joint_meshes"].append(extra)
        with self.assertRaisesRegex(CutoutError, "different weights"):
            validate_layout(case.parent, broken, "side", [], [])
        mesh["weights"]["root"][0] = -1
        with self.assertRaisesRegex(CutoutError, "negative weights"):
            validate_layout(case.parent, layout, "side", [], [])

    def test_skin_collision_does_not_leave_a_half_written_layout(self):
        case = self.creature()
        recipe = {"facing": "side", "input_layout": "layouts/side.json", "output_layout": "layouts/skinned.json", "fields": [{"name": "tail", "parts": ["body"], "bones": ["root", "tail"], "bands": [{"center": [128, 208], "axis": [1, 0], "width": 4}]}]}
        write_json(self.root / "recipe.json", recipe)
        write_json(case.parent / "recipes/skinned.skin.json", {"retained": True})
        before = case_hashes(case)
        with self.assertRaises(CutoutError):
            apply_skin(case, self.root / "recipe.json")
        self.assertFalse((case.parent / "layouts/skinned.json").exists())
        self.assertEqual(case_hashes(case), before)

    def test_rigid_replacement_preserves_pixels_and_invalidates_rest(self):
        case = self.creature()
        image = Image.new("RGBA", (3, 5), (255, 0, 100, 255))
        image.save(self.root / "replacement.png")
        result = replace_part(case, "side", "body", self.root / "replacement.png", (125, 207))
        self.assertEqual(result.read_bytes(), (self.root / "replacement.png").read_bytes())
        self.assertTrue(validate(case)["ok"])
        self.assertFalse(validate(case, "art")["ok"])
        self.assertEqual(read_json(case.parent / "layouts/side.json")["parts"][0]["offset"], [125, 207])


    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "video tools unavailable")
    def test_pack_retains_full_non_60fps_cycles_and_recovery(self):
        output = self.root / "proof"
        folder = output / "side_hover"
        folder.mkdir(parents=True)
        for index in range(12):
            Image.new("RGB", (32, 32), (index * 20, 50, 80)).save(folder / f"board_{index:04d}.jpg")
        write_json(output / "render_manifest.json", {"errors": [], "clips": [{"folder": "side_hover", "frames": 12, "frame_seconds": 1 / 20}]})
        report = pack(output)
        self.assertEqual(report["full_decode"], "PASS")
        self.assertAlmostEqual(report["source_seconds"], 0.6)
        self.assertAlmostEqual(report["encoded_seconds"], 0.6)
        self.assertEqual(report["clips"][0]["encoded_frames"], 36)

    def test_verification_rejects_changed_inputs_or_tampered_proof(self):
        output = self.root / "proof"
        output.mkdir()
        native = output / "render_manifest.json"
        write_json(native, {"errors": [], "roundtrip": [{"pixel_identical": True}]})
        write_json(output / "proof_sha256.json", {"render_manifest.json": digest(native)})
        write_json(output / "capture_input_sha256.json", {"case:motion.gd": "accepted"})
        with patch("cutout_pipeline.proof.input_hashes", return_value={"case:motion.gd": "accepted"}):
            self.assertTrue(verify_render(self.root, output)["ok"])
            native.write_text(native.read_text() + " ")
            result = verify_render(self.root, output)
            self.assertFalse(result["ok"])
            self.assertIn("Changed/missing proof", result["errors"][0])
        with patch("cutout_pipeline.proof.input_hashes", return_value={"case:motion.gd": "changed"}):
            self.assertIn("Changed capture input", verify_render(self.root, output)["errors"][0])

    def test_skin_records_sources_replaces_mesh_once_and_refuses_rigid_swap(self):
        case = self.creature()
        recipe = {"facing": "side", "input_layout": "layouts/side.json", "output_layout": "layouts/skinned.json", "fields": [{"name": "tail", "parts": ["body"], "bones": ["root", "tail"], "bands": [{"center": [128, 208], "axis": [1, 0], "width": 4}]}]}
        write_json(self.root / "recipe.json", recipe)
        apply_skin(case, self.root / "recipe.json")
        self.assertTrue(validate(case)["ok"])
        self.assertEqual(len(read_json(case.parent / "layouts/skinned.json")["joint_meshes"]), 1)
        self.assertIn("recipes/skinned.skin.json", read_json(case)["sources"])
        recipe.update({"input_layout": "layouts/skinned.json", "output_layout": "layouts/skinned_v2.json"})
        write_json(self.root / "recipe-v2.json", recipe)
        apply_skin(case, self.root / "recipe-v2.json")
        self.assertEqual(len(read_json(case.parent / "layouts/skinned_v2.json")["joint_meshes"]), 1)
        with self.assertRaisesRegex(CutoutError, "skinned"):
            replace_part(case, "side", "body", case.parent / "body.png", (0, 0))

    def test_missing_fork_input_fails_before_creating_output(self):
        case = self.creature()
        (case.parent / "body.png").unlink()
        with self.assertRaisesRegex(CutoutError, "Missing case input"):
            fork_case(case, self.root / "failed-fork", "crawler_variant")
        self.assertFalse((self.root / "failed-fork").exists())


if __name__ == "__main__":
    unittest.main()
