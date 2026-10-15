#!/usr/bin/env python3
"""Observable registration, ownership, hidden-material and approved-rest contracts."""
import argparse
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from art_identity_gate import process_raw, silhouette_edge, to_lab
from cutout_pipeline.cases import CutoutError, PROJECT, case_hashes, digest, read_json, write_json
from cutout_pipeline.validation import validate
from maquette_cutout import (FILL_DEFAULTS, MAGENTA, Registration, build, camera_depths, decode_labels, depth_order,
                            fill_donors, fill_hidden, fill_pixels, part_palette, same_material_donors,
                            hidden_region, material_neighbours, nearest_labels, projected,
                            registration, request_image, label_core, clean_ownership, components8, material_reference, array_digest,
                            occlusion_shadow_ownership, build_view)

CASE = PROJECT / "experiments/cutouts/chainbound_gaoler/mq3"


class HiddenFillTests(unittest.TestCase):
    def test_new_shadow_floor_preserves_rest_and_discloses_unusable_midtones(self):
        paint = np.zeros((12, 12, 4), dtype=np.uint8)
        visible = np.zeros((12, 12), dtype=bool)
        visible[:3, :4] = True
        paint[visible] = [30, 30, 30, 255]
        paint[2, 1:4] = [42, 42, 42, 255]
        hidden = np.zeros_like(visible)
        hidden[3:9, :4] = True
        result, metrics = fill_pixels(paint, visible, hidden, paint[..., :3], visible, "diffusion",
            value_pixels=paint[visible, :3], minimum_hidden_l=15)
        np.testing.assert_array_equal(result[visible], paint[visible])
        self.assertGreaterEqual(float(to_lab(result[hidden, :3])[:, 0].min()), 15)
        values = metrics["diffusion"]["value_distribution"]
        self.assertLess(values["visible_midtones_l"][1], 15)
        self.assertEqual(values["hidden_original_midtones_pixels"], 0)
        self.assertGreater(values["hidden_midtones_pixels"], 0)
        self.assertGreaterEqual(values["effective_midtones_l"][0], 15)
        self.assertLessEqual(values["median_difference_l"], 8)

    def test_diffusion_is_repeatable_palette_limited_and_preserves_visible_rgba(self):
        paint = np.zeros((16, 16, 4), dtype=np.uint8)
        visible = np.zeros((16, 16), dtype=bool)
        visible[2:12, 2:7] = True
        yy, xx = np.indices(visible.shape)
        paint[visible, :3] = np.stack([40 + 3 * yy, 22 + xx, 29 + yy], axis=-1)[visible]
        paint[visible, 3] = 255
        hidden = np.zeros_like(visible)
        hidden[2:12, 7:12] = True
        donor = np.zeros_like(visible)
        a, report = fill_pixels(paint, visible, hidden, paint[..., :3], donor, "diffusion")
        b, again = fill_pixels(paint, visible, hidden, paint[..., :3], donor, "diffusion")
        np.testing.assert_array_equal(a, b)
        self.assertEqual(report, again)
        self.assertEqual(report["palette_source"], "own_visible")
        self.assertEqual(len(report["palette"]), 6)
        np.testing.assert_array_equal(a[visible], paint[visible])
        np.testing.assert_array_equal(a[..., 3] > 0, visible | hidden)
        edge = hidden & silhouette_edge(visible | hidden, clipped_border=True)
        self.assertTrue(np.all(a[edge, :3] == FILL_DEFAULTS["outline_tone"]))
        allowed = {tuple(color) for color in report["palette"]}
        self.assertTrue({tuple(color) for color in a[hidden & ~edge, :3]} <= allowed)
        self.assertFalse(edge[5, 7], "A seam with visible paint is not an alpha edge")
        self.assertFalse(np.any(np.all(a == MAGENTA, axis=-1)))

    def test_value_matching_contains_visible_midtones_and_preserves_outline(self):
        paint = np.zeros((32, 32, 4), dtype=np.uint8)
        visible = np.zeros((32, 32), dtype=bool)
        visible[2:30, :4] = True
        paint[visible] = [80, 65, 58, 255]
        paint[2:7, :4] = [8, 6, 7, 255]
        paint[25:30, :4] = [120, 100, 90, 255]
        hidden = np.zeros_like(visible)
        hidden[4:28, 4:28] = True
        result, info = fill_pixels(paint, visible, hidden, paint[..., :3], visible, "diffusion",
                                   value_pixels=paint[visible, :3])
        np.testing.assert_array_equal(result[visible], paint[visible])
        source_l = to_lab(paint[visible, :3])[:, 0]
        actual_l = to_lab(result[hidden, :3])[:, 0]
        self.assertLessEqual(abs(np.median(actual_l) - np.median(source_l)), 8)
        self.assertGreater(np.count_nonzero(np.all(result[hidden, :3] == [80, 65, 58], axis=-1)), 100)
        self.assertGreater(info["outline_pixels"], 0)
        self.assertFalse(np.any(np.all(result[hidden] == MAGENTA, axis=-1)))

    def test_small_part_palette_uses_only_same_material_neighbours(self):
        owners = np.array([[0, 1, 2, 3, 4], [1, 1, 2, 3, 4]])
        request = {"part": "self", "material": "coat", "occluding_parts": [
            {"part": "coat", "material": "coat"}, {"part": "helm", "material": "metal"},
            {"part": "belt", "material": "leather"}], "bordering_parts": [
            {"part": "coat", "material": "coat"}, {"part": "tabard", "material": "red cloth"}]}
        names, donors = same_material_donors(request, ["self", "coat", "helm", "belt", "tabard"], owners)
        self.assertEqual(names, ["coat"])
        np.testing.assert_array_equal(donors, owners == 1)
        paint = np.zeros((2, 5, 4), dtype=np.uint8)
        paint[owners == 0] = [200, 10, 10, 255]
        paint[donors] = [35, 31, 37, 255]
        paint[owners >= 2] = [255, 245, 0, 255]
        hidden = owners == 2
        _, record = fill_pixels(paint, owners == 0, hidden, paint[..., :3], donors, "diffusion")
        self.assertEqual(record["palette"], [[35, 31, 37]])
        self.assertEqual(record["palette_source"], "same_material_neighbours")
        with self.assertRaisesRegex(CutoutError, "No same-material palette fallback"):
            fill_pixels(paint, owners == 0, hidden, paint[..., :3], np.zeros_like(donors), "diffusion")

    def test_palette_preserves_frequency_and_is_independent_of_input_order(self):
        pixels = np.array([[12, 15, 18]] * 60 + [[44, 43, 42]] * 30 + [[99, 88, 77]] * 10, dtype=np.uint8)
        a, _ = part_palette(pixels)
        b, _ = part_palette(pixels[::-1])
        np.testing.assert_array_equal(a, b)
        self.assertEqual(a.tolist(), [[12, 15, 18], [44, 43, 42], [99, 88, 77]])

    def test_cross_view_fallback_uses_only_same_part_visible_paint(self):
        owners = np.full((8, 8), -1, dtype=np.int16)
        other_owners = np.ones_like(owners)
        other_owners[:, :4] = 0
        paint = np.zeros((8, 8, 4), dtype=np.uint8)
        other_paint = np.full_like(paint, [255, 0, 255, 255])
        other_paint[other_owners == 0] = [70, 40, 20, 255]
        views = {"rear": (paint, owners, {}), "front": (other_paint, other_owners, {})}
        request = {"view": "rear", "part": "glove", "material": "leather",
                   "occluding_parts": [], "bordering_parts": []}
        names = ["glove", "unrelated"]
        _, _, mask, view = fill_donors(request, names, views, False)
        self.assertIsNone(view)
        self.assertFalse(mask.any(), "Unrequested cross-view borrowing stays disabled")
        donors, rgb, mask, view = fill_donors(request, names, views, True)
        self.assertEqual(donors, [])
        self.assertEqual(view, "front")
        np.testing.assert_array_equal(mask, other_owners == 0)
        hidden = np.zeros_like(mask)
        hidden[2:6, 2:6] = True
        result, record = fill_pixels(paint, owners == 0, hidden, rgb, mask, "diffusion")
        self.assertEqual(record["palette"], [[70, 40, 20]])
        self.assertTrue(np.all(result[3:5, 3:5, :3] == [70, 40, 20]))
        self.assertFalse(np.any(np.all(result == MAGENTA, axis=-1)))
        np.testing.assert_array_equal(result[..., 3] > 0, hidden)

    def test_cross_view_fallback_preserves_local_donor_precedence_and_threshold(self):
        owners = np.full((8, 8), -1, dtype=np.int16)
        paint = np.full((8, 8, 4), [35, 31, 37, 255], dtype=np.uint8)
        views = {"rear": (paint, owners, {}), "front": (paint, np.zeros_like(owners), {})}
        request = {"view": "rear", "part": "self", "material": "coat",
                   "occluding_parts": [], "bordering_parts": []}
        owners[:5] = 0  # Exactly 40 own pixels: no cross-view fallback.
        _, _, mask, view = fill_donors(request, ["self", "coat"], views, True)
        self.assertIsNone(view)
        self.assertFalse(mask.any())
        owners[:] = -1
        owners[0, 0] = 1
        request["occluding_parts"] = [{"part": "coat", "material": "coat"}]
        donors, _, mask, view = fill_donors(request, ["self", "coat"], views, True)
        self.assertEqual(donors, ["coat"])
        self.assertIsNone(view)
        np.testing.assert_array_equal(mask, owners == 1)

    def test_case_fill_is_idempotent_and_refuses_to_erase_artist_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "case"
            shutil.copytree(CASE, root)
            # This exercises the real case, including completely hidden parts.
            args = argparse.Namespace(case=root, task_id="rr-02", cross_view_fallback=True)
            before = {p.relative_to(root): digest(p) for p in (root / "hidden").rglob("*.png")}
            protected = {p.relative_to(root): digest(p) for d in ["source", "segmented", "hidden_requests"]
                         for p in (root / d).rglob("*.png")}
            with patch("maquette_cutout.sample_exposure"):
                first = fill_hidden(args)
                hashes = case_hashes(root)
                args.cross_view_fallback = False  # Recorded authorization survives reruns.
                again = fill_hidden(args)
            self.assertTrue(first["ok"], first)
            self.assertTrue(first["complete"], first)
            self.assertEqual(first["pending_design"], [])
            self.assertEqual(first["remaining_magenta_pixels"], 0)
            self.assertEqual(first, again)
            self.assertEqual(hashes, case_hashes(root))
            self.assertTrue(all(digest(root / p) == value for p, value in protected.items()))
            manifest = read_json(root / "hidden_fills/index.json")
            self.assertEqual(len(manifest["requests"]), 42)
            cross_view = [r for r in manifest["requests"] if "cross_view_donor" in r]
            expected_parts = {"fore_near", "hand_near", "tabard"}
            self.assertEqual({r["part"] for r in cross_view}, expected_parts)
            for r in cross_view:
                self.assertEqual(r["view"], "rear")
                self.assertEqual(r["cross_view_donor"]["view"], "front")
                self.assertEqual(r["cross_view_donor"]["part"], r["part"])
                self.assertEqual(r["palette_source"], "same_part_other_view")
                self.assertEqual(r["cross_view_donor"]["source_sha256"], digest(root / "source/front/processed.png"))
            for path, expected in before.items():
                if str(path) not in {f"hidden/rear/{part}.png" for part in expected_parts}:
                    self.assertEqual(digest(root / path), expected)
            for path in (root / "hidden").rglob("*.png"):
                self.assertFalse(np.any(np.all(np.array(Image.open(path).convert("RGBA")) == MAGENTA, axis=-1)))
            record = next(r for r in manifest["requests"] if r["status"] == "filled")
            path = root / record["output"]
            pixels = np.array(Image.open(path).convert("RGBA"))
            y, x = np.argwhere(pixels[..., 3] > 0)[0]
            pixels[y, x, :3] = [77, 55, 33]
            Image.fromarray(pixels).save(path)
            edited = digest(path)
            with patch("maquette_cutout.sample_exposure"), self.assertRaisesRegex(CutoutError, "manually changed"):
                fill_hidden(args)
            self.assertEqual(digest(path), edited)
            self.assertEqual(digest(root / "hidden_fills/index.json"), hashes["hidden_fills/index.json"])


class OwnershipCleanupTests(unittest.TestCase):
    def test_occlusion_shadow_uses_six_pixel_geometry_and_preserves_paint(self):
        names = ["thigh_far", "thigh_near", "shin_near", "foot_near", "pelvis", "tabard"]
        owners = np.full((16, 16), -1, dtype=np.int16)
        for x, y in [(4, 8), (3, 8), (0, 8), (4, 9)]:
            owners[y, x] = 0
        paint = np.zeros((16, 16, 4), dtype=np.uint8)
        paint[owners == 0] = [10, 10, 10, 255]
        paint[9, 4] = [90, 80, 70, 255]
        original = paint.copy()
        labels = np.full_like(owners, -1)
        labels[8, 10] = labels[8, 1] = 1
        solos = {name: np.zeros_like(owners, dtype=bool) for name in names}
        solos["thigh_near"][8, 10] = True
        result, hidden, report = occlusion_shadow_ownership(owners, [np.zeros_like(owners, dtype=bool) for _ in names],
            paint, labels, names, solos, {"parts": ["thigh_far"], "max_l_exclusive": 15, "boundary_distance_px": 6})
        self.assertEqual(result[8, 4], len(names))
        self.assertEqual(result[8, 3], 0)  # Seven pixels from the real label.
        self.assertEqual(result[8, 0], 0)  # Invalid colour fringe is not a boundary.
        self.assertEqual(result[9, 4], 0)  # Bright source paint is never transferred.
        self.assertEqual(int(hidden[0].sum()), 1)
        self.assertTrue(hidden[0][8, 4])
        self.assertEqual(report["discarded_label_fringe_pixels"]["thigh_near"], 1)
        np.testing.assert_array_equal(paint, original)

    def test_core_uses_euclidean_distance_and_excludes_border(self):
        mask = np.ones((13, 13), dtype=bool)
        core = label_core(mask, 4)
        self.assertEqual(int(core.sum()), 49)
        self.assertTrue(core[3:10, 3:10].all())
        mask[6, 6] = False
        core = label_core(mask, 4)
        self.assertFalse(core[6, 9])
        self.assertTrue(core[3, 3], "Diagonal sqrt(18) exceeds 4px")

    def test_specks_use_eight_connectivity_largest_exemption_and_shared_edges(self):
        names = ["self", "left", "right"]
        owners = np.full((14, 18), -1, dtype=np.int16)
        owners[1:5, 1:5] = 0
        owners[10, 9:11] = 0
        owners[9, 9:11] = 2
        owners[10, 8] = 1
        owners[12, 15] = 0  # No neighbour: visible pixels must remain.
        paint = np.zeros((*owners.shape, 4), dtype=np.uint8)
        paint[owners >= 0] = [50, 35, 29, 255]
        solos = {name: owners == i for i, name in enumerate(names)}
        policy = {"speck_max_exclusive_px": 12}
        cleaned, hidden, report = clean_ownership(owners, paint, names, solos, "front", {}, policy)
        self.assertTrue(np.all(cleaned[10, 9:11] == 2))
        self.assertEqual(cleaned[12, 15], 0)
        self.assertEqual(report["specks"]["self"]["move_pixels"], 2)
        self.assertEqual(report["specks"]["self"]["keep_pixels"], 1)
        np.testing.assert_array_equal(cleaned >= 0, owners >= 0)
        self.assertEqual(len(components8(np.eye(3, dtype=bool))), 1)

    def test_unattached_hidden_only_speck_is_deleted_without_changing_visible_partition(self):
        names = ["self", "cover"]
        owners = np.full((12, 12), -1, dtype=np.int16)
        owners[1:5, 1:5] = 0
        owners[10, 10] = 1
        paint = np.zeros((*owners.shape, 4), dtype=np.uint8)
        paint[owners >= 0] = [40, 30, 25, 255]
        solo = owners >= 0
        cleaned, hidden, report = clean_ownership(owners, paint, names,
            {"self": solo, "cover": owners == 1}, "front", {}, {"speck_max_exclusive_px": 12})
        np.testing.assert_array_equal(cleaned, owners)
        self.assertFalse(hidden[0].any())
        self.assertEqual(report["specks"]["self"]["delete_pixels"], 1)

    def test_material_constrained_fill_uses_sampled_colors_and_preserves_visible(self):
        paint = np.zeros((16, 16, 4), dtype=np.uint8)
        visible = np.zeros((16, 16), dtype=bool)
        visible[:4] = True
        paint[visible] = [0, 0, 0, 255]
        hidden = np.zeros_like(visible)
        hidden[4:14, 2:14] = True
        donors = np.zeros_like(visible)
        donors[15] = True
        paint[donors] = [60, 45, 40, 255]
        reference = {"median_lab": to_lab(np.array([60, 45, 40])).tolist(), "max_delta_e": 12}
        result, report = fill_pixels(paint, visible, hidden, paint[..., :3], donors, "diffusion",
                                    np.concatenate([paint[visible, :3], paint[donors, :3]]), reference)
        self.assertEqual(report["quantization_palette"], [[60, 45, 40]])
        np.testing.assert_array_equal(result[visible], paint[visible])
        self.assertLessEqual(np.linalg.norm(to_lab(np.median(result[hidden, :3], axis=0)) - reference["median_lab"]), 12)


class SyntheticMaquetteTests(unittest.TestCase):
    def test_complete_wing_tail_case_uses_explicit_views_and_keeps_all_source_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            spec = {"target": [0, 0, 0], "ortho_scale": 4,
                    "joints": {"root": [0, 0, 0], "head": [0.6, 0, 0.4], "wing": [0, 1, 0.2], "tail": [-0.7, -0.2, 0.1]},
                    "labels": {"body": [1, 0, 0], "head": [0, 0, 1], "wing": [1, 1, 0], "tail": [0, 1, 1]},
                    "shapes": [{"type": "ellipsoid", "part": "body", "at": "root"},
                               {"type": "ellipsoid", "part": "head", "at": "head"},
                               {"type": "ellipsoid", "part": "wing", "at": "wing"},
                               {"type": "ellipsoid", "part": "tail", "at": "tail"}]}
            write_json(root / "spec.json", spec)
            recipe = {"character_id": "synthetic", "joints": {"root": {"joint": "root", "parent": None},
                       "head": {"joint": "head", "parent": "root"}, "wing": {"joint": "wing", "parent": "root"},
                       "tail": {"joint": "tail", "parent": "root"}}, "parts": {"body": "root", "head": "head", "wing": "wing", "tail": "tail"},
                      "motion": "motion.gd", "clips": {"idle": {"frames": 2, "duration": 1, "loop": True}},
                      "rigid_bones": [], "contact_feet": []}
            write_json(root / "rig.json", recipe)
            colors = {"body": [255, 0, 0], "head": [0, 0, 255], "wing": [255, 255, 0], "tail": [0, 255, 255]}
            write_json(root / "palette.json", colors)
            cache = root / "renders"
            cache.mkdir()
            joints, transforms = {}, {}
            for view, degrees in [("front", 135), ("rear", 315)]:
                # Independent Blender-equivalent exporter: rotate the object,
                # then dot camera right/up/forward. Do not use projected().
                yaw = math.radians(degrees)
                c, s = math.cos(yaw), math.sin(yaw)
                transforms[view] = {"object_to_world": [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]],
                    "target": [0, 0, 0.9], "azimuth_deg": 45, "elevation_deg": 30, "ortho_scale": 3.6, "distance": 20}
                joints[view] = {}
                expected_depths = {}
                for name, (x, y, z) in spec["joints"].items():
                    wx, wy, wz = c*x - s*y, s*x + c*y, z - 0.9
                    joints[view][name] = [512 + (-wx + wy) / math.sqrt(2) * 1024/3.6,
                        512 - (-(wx + wy) / math.sqrt(8) + wz * math.sqrt(3)/2) * 1024/3.6]
                    expected_depths["body" if name == "root" else name] = 20 - ((wx + wy)*math.sqrt(3/8) + wz/2)
                configured = dict(spec, view_transforms=transforms)
                self.assertGreater(np.linalg.norm(np.array(projected(spec, spec["joints"]["head"], view)) - joints[view]["head"]), 100)
                for name, point in spec["joints"].items():
                    np.testing.assert_allclose(projected(configured, point, view), joints[view][name], atol=1e-10)
                actual_depths = camera_depths(configured, view)
                for name, expected in expected_depths.items():
                    self.assertAlmostEqual(actual_depths[name], expected)
                self.assertEqual(actual_depths["wing"] > actual_depths["tail"], view == "front")
                job = root / view
                job.mkdir()
                raw = Image.new("RGB", (1024, 1024), (0, 255, 0))
                raw.paste((90, 50, 30), (480, 480, 544, 560))
                raw.paste((140, 90, 70), (488, 444, 536, 500))
                raw.paste((110, 80, 50), (440, 480, 480, 496))
                raw.paste((100, 60, 40), (500, 560, 516, 584))
                raw.save(job / "raw.png")
                write_json(job / "kit.json", {"K": 4, "kind": "creature", "anatomy": "biped"})
                process_raw(job / "raw.png", job / "kit.json", job / "processed.png")
                labels = Image.new("RGBA", (1024, 1024))
                labels.paste((255, 0, 0, 255), (480, 480, 544, 560))
                labels.paste((0, 0, 255, 255), (488, 444, 536, 500))
                labels.paste((255, 255, 0, 255), (440, 480, 480, 496))
                labels.paste((0, 255, 255, 255), (500, 560, 516, 584))
                labels.save(cache / f"{view}_parts.png")
                labels.save(cache / f"{view}_clay.png")
                for name, rect in [("body", (480, 480, 544, 560)), ("head", (488, 444, 536, 500)),
                                   ("wing", (440, 480, 480, 496)), ("tail", (500, 560, 516, 584))]:
                    solo = Image.new("RGBA", (1024, 1024))
                    solo.paste((255, 255, 255, 255), rect)
                    solo.save(cache / f"{view}_solo_{name}.png")
            write_json(root / "views.json", transforms)
            write_json(cache / "joints_px.json", joints)
            inputs = {p: digest(p) for p in root.rglob("*") if p.is_file()}
            args = argparse.Namespace(spec=root / "spec.json", front_job=root / "front", rear_job=root / "rear",
                                      front_raw=None, rear_raw=None, renders=cache, palette=root / "palette.json",
                                      rig_recipe=root / "rig.json", color_config=None, blender="unused",
                                      view_transforms=root / "views.json",
                                      resume_scaffold=False, allow_incomplete_renders=False)
            for case in ["a", "b"]:
                args.case = root / case
                with patch("maquette_cutout.render_maquette") as blender:
                    report = build(args)
                blender.assert_not_called()
                self.assertTrue(report["complete"], report)
                self.assertTrue(report["rest_identity"]["ok"])
                requests = read_json(args.case / "hidden_requests/index.json")["requests"]
                self.assertEqual([r["hidden_pixel_count"] for r in requests if r["part"] == "body"], [60, 60])
                manifest = read_json(args.case / "source/maquette_manifest.json")
                self.assertTrue(manifest["complete"])
                self.assertEqual(manifest["files"], {p.name: digest(p) for p in cache.iterdir()})
            self.assertEqual(case_hashes(root / "a"), case_hashes(root / "b"))
            self.assertEqual(read_json(root / "a/source/view_transforms.json"), transforms)
            for view in transforms:
                layout = read_json(root / f"a/layouts/{view}.json")
                self.assertEqual(set(layout["joints"]), {"root", "head", "wing", "tail"})
                self.assertEqual(layout["maquette_depths"], camera_depths(dict(spec, view_transforms=transforms), view))
            self.assertTrue(all(digest(path) == value for path, value in inputs.items()))
            args.case = root / "wrong_camera"
            args.view_transforms = None
            with self.assertRaisesRegex(CutoutError, "Cached joints do not match"):
                build(args)
            # Normal operation fails closed when a solo is missing.
            (cache / "rear_solo_head.png").unlink()
            args.case = root / "missing"
            with self.assertRaisesRegex(CutoutError, "Missing solo"):
                build(args)
            self.assertFalse(args.case.exists(), "Reject incomplete inputs before creating a case")

    def test_hidden_neighbours_report_occluders_and_four_connected_border(self):
        hidden = np.array([[False, False, False], [False, True, False], [False, False, False]])
        owners = np.array([[3, 1, 3], [2, 1, 0], [3, -1, 3]])
        actual = material_neighbours(hidden, owners, 0, ["self", "cloth", "belt", "diagonal"])
        self.assertEqual(actual["occluding_parts"], [{"part": "cloth", "pixels": 1}])
        self.assertEqual(actual["bordering_parts"], [{"part": "cloth", "pixels": 1}, {"part": "belt", "pixels": 1}])

    def test_registration_recovers_crop_and_placement_from_gate(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            raw = Image.new("RGBA", (64, 64), (0, 255, 0, 255))
            pixels = np.array(raw)
            pixels[12:52, 8:40] = [90, 50, 30, 255]
            Image.fromarray(pixels).save(root / "raw.png")
            write_json(root / "kit.json", {"K": 64, "kind": "creature", "anatomy": "biped"})
            record = process_raw(root / "raw.png", root / "kit.json", root / "processed.png")
            transform = registration(root / "raw.png", record)
            np.testing.assert_allclose(transform.scale, [0.25, 0.25])
            np.testing.assert_allclose(transform.point([8, 12]), record["placement"])
            rendered = Image.new("RGBA", (64, 64))
            rendered.paste((90, 50, 30, 255), (8, 12, 40, 52))
            self.assertEqual(transform.image(rendered).tobytes(), Image.open(root / "processed.png").tobytes())
            # Missing material outside the paint crop must still register.
            rendered.putpixel((4, 14), (255, 0, 0, 255))
            self.assertLess(transform.point([4, 14])[0], record["placement"][0])
            bad = dict(record, raw_sha256="not-the-raw")
            with self.assertRaisesRegex(CutoutError, "digest"):
                registration(root / "raw.png", bad)

    def test_noninteger_reduction_and_fit_match_gate_alpha_bounds(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            # K_eff=1.5, outward block rounding and a width-limited fit.
            raw = Image.new("RGB", (384, 384), (0, 255, 0))
            raw.paste((70, 30, 20), (1, 27, 383, 362))
            raw.save(root / "raw.png")
            write_json(root / "kit.json", {"K": 4, "kind": "creature", "anatomy": "biped"})
            record = process_raw(root / "raw.png", root / "kit.json", root / "processed.png")
            transform = registration(root / "raw.png", record)
            self.assertLess(record["fit_scale"], 1)
            self.assertEqual(transform.trace["reduced_size"], [255, 224])
            self.assertEqual(transform.trace["after_fit"], record["drawn_size"])
            # The point/image contract uses actual rounded dimensions, not fit_scale twice.
            np.testing.assert_allclose(transform.point([transform.trace["raw_crop"][0], transform.trace["raw_crop"][1]]), record["placement"])

    def test_nearest_is_euclidean_and_depth_breaks_diagonal_ties(self):
        labels = np.full((7, 7), -1, dtype=np.int16)
        labels[0, 0] = 0
        labels[0, 4] = 1
        labels[6, 3] = 2
        names = ["far", "near", "middle"]
        depths = {"far": 30, "near": 10, "middle": 20}
        mask = np.ones(labels.shape, dtype=bool)
        mask[5, 5] = False
        actual, report = nearest_labels(labels, mask, names, depths)
        seeds = [(y, x, int(labels[y, x])) for y, x in zip(*np.nonzero(labels >= 0))]
        for y, x in zip(*np.nonzero(mask)):
            expected = min(seeds, key=lambda p: ((p[0] - y) ** 2 + (p[1] - x) ** 2, depths[names[p[2]]], names[p[2]]))[2]
            self.assertEqual(actual[y, x], expected)
        self.assertEqual(actual[2, 2], 1)
        self.assertEqual(actual[5, 5], -1)
        self.assertTrue(report["near"]["above_15_percent"])
        self.assertEqual(report["near"]["reassigned_pixels"], report["near"]["painted_pixels"] - 1)

    def test_reassignment_limit_is_strictly_above_fifteen_percent(self):
        labels = np.zeros((1, 20), dtype=np.int16)
        labels[0, :3] = -1
        _, report = nearest_labels(labels, np.ones_like(labels, dtype=bool), ["one"], {"one": 0})
        self.assertEqual(report["one"]["reassigned_share"], 0.15)
        self.assertFalse(report["one"]["above_15_percent"])
        with self.assertRaises(CutoutError):
            nearest_labels(np.full((2, 2), -1), np.ones((2, 2), dtype=bool), ["one"], {"one": 0})

    def test_camera_depth_and_projection_reverse_on_rear(self):
        spec = {"target": [0, 0, 0], "ortho_scale": 4, "joints": {"a": [1, 1, 0], "b": [-1, -1, 0]},
                "labels": {"a": [1, 0, 0], "b": [0, 0, 1]},
                "shapes": [{"type": "ellipsoid", "part": n, "at": n} for n in ["a", "b"]]}
        self.assertEqual(depth_order(camera_depths(spec, "front")), ["b", "a"])
        self.assertEqual(depth_order(camera_depths(spec, "rear")), ["a", "b"])
        self.assertEqual(projected(spec, [0, 0, 0], "front", 8), [4, 4])
        front, rear = projected(spec, [1, 0, 0], "front", 8), projected(spec, [1, 0, 0], "rear", 8)
        np.testing.assert_allclose(np.array(front) + rear, [8, 8])

    def test_hidden_requires_another_painted_owner_not_empty_canvas(self):
        solo = np.array([[True, True, True], [False, True, False]])
        owners = np.array([[0, 1, -1], [1, 0, -1]])
        hidden, outside = hidden_region(solo, owners, 0)
        np.testing.assert_array_equal(hidden, [[False, True, False], [False, False, False]])
        np.testing.assert_array_equal(outside, [[False, False, True], [False, False, False]])
        paint = Image.new("RGBA", (3, 2), (10, 20, 30, 255))
        request = request_image(paint, owners, 0, hidden)
        self.assertEqual(request.getpixel((0, 0)), (10, 20, 30, 255))
        self.assertEqual(request.getpixel((1, 0)), (255, 0, 255, 255))
        self.assertEqual(request.getpixel((2, 0)), (0, 255, 0, 255))

    def test_decode_uses_registered_palette_and_keeps_background_unowned(self):
        image = Image.new("RGBA", (3, 1))
        image.putpixel((0, 0), (10, 20, 30, 255))
        image.putpixel((1, 0), (200, 80, 40, 255))
        names = ["cold", "warm"]
        labels = decode_labels(image, {"cold": [10, 20, 30], "warm": [200, 80, 40]}, names, {"cold": 2, "warm": 1})
        np.testing.assert_array_equal(labels, [[0, 1, -1]])


class GaolerCaseTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("godot"), "Godot unavailable for complete gaoler rebuild")
    def test_complete_gaoler_rebuild_and_authored_motion_parameters(self):
        import importlib.util
        module = importlib.util.spec_from_file_location("gaoler_rebuild", CASE / "probes/rebuild.py")
        rebuild_probe = importlib.util.module_from_spec(module)
        module.loader.exec_module(rebuild_probe)
        with tempfile.TemporaryDirectory(prefix="rr02-rebuild-test-") as folder:
            fresh = Path(folder).resolve() / "case"
            rebuild_probe.rebuild(CASE, fresh)
            report = rebuild_probe.compare(CASE, fresh)
            self.assertTrue(report["ok"], report["different_files"])
            print(f"GAOLER REBUILD: PASS ({report['compared_files']} files)", flush=True)
            # The review's three omitted artifacts must each fail comparison.
            for name in ["recipes/front_ownership.json", "recipes/rear_ownership.json", "build_report.json", "baseline.sha256.json"]:
                path = fresh / name
                original = path.read_bytes()
                path.write_bytes(original + b"\n")
                self.assertIn(name, rebuild_probe.compare(CASE, fresh)["different_files"])
                path.write_bytes(original)
            (fresh / "hidden/rear/orphan.png").write_bytes(b"orphan")
            self.assertIn("hidden/rear/orphan.png", rebuild_probe.compare(fresh, CASE)["different_files"])
            (fresh / "hidden/rear/orphan.png").unlink()
            # Change authored recipe data, run the actual layout generator, then
            # evaluate the generated GDScript sampler headlessly. Constraints
            # are absent in both layouts to isolate these two director values.
            recipe = read_json(fresh / "recipes/rig.json")
            spec, palette = read_json(fresh / "source/spec.json"), read_json(fresh / "source/label_palette.json")
            shutil.rmtree(fresh / "segmented/rear")
            build_view(fresh, spec, "rear", palette, recipe, False)
            before = read_json(fresh / "layouts/rear.json")
            write_json(fresh / "before.json", before)
            recipe["rear_torso_lean"]["rotation_rad_per_hit"] = 0.14
            recipe["rear_torso_lean"]["shoulder_offset_per_prep"] = [2, -6]
            write_json(fresh / "recipes/rig.json", recipe)
            shutil.rmtree(fresh / "segmented/rear")
            build_view(fresh, spec, "rear", palette, read_json(fresh / "recipes/rig.json"), False)
            after = read_json(fresh / "layouts/rear.json")
            self.assertEqual(after["rear_torso_lean"], recipe["rear_torso_lean"])
            script = fresh / "check_lean.gd"
            script.write_text('''extends SceneTree
func _initialize() -> void:
\tpreload("res://scripts/parallel_runtime.gd").apply_from_environment()
\tvar sampler = load(%s)
\tvar before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(%s))
\tvar after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(%s))
\tfor clip: String in ["strike", "manacle_pin"]:
\t\tfor phase: float in [0.08, 0.22, 0.42, 0.56]:
\t\t\tvar old: Dictionary = sampler.sample_pose(clip, phase, before, "rear")
\t\t\tvar changed: Dictionary = sampler.sample_pose(clip, phase, after, "rear")
\t\t\tvar envelopes: Vector2 = sampler._punch_envelopes(clip, phase)
\t\t\tassert(is_equal_approx(changed["torso"]["rotation"] - old["torso"]["rotation"], 0.07 * envelopes.y))
\t\t\tassert((changed["upper_fist"]["position"] - old["upper_fist"]["position"]).is_equal_approx(Vector2(2, -3) * envelopes.x))
\t\t\tassert(sampler.sample_pose(clip, phase, before, "front") == sampler.sample_pose(clip, phase, after, "front"))
\tassert(sampler.sample_pose("walk", 0.5, before, "rear") == sampler.sample_pose("walk", 0.5, after, "rear"))
\tprint("RECIPE_MOTION_PARAMETERS: PASS")
\tquit(0)
''' % (json.dumps(str(fresh / "motion.gd")), json.dumps(str(fresh / "before.json")), json.dumps(str(fresh / "layouts/rear.json"))))
            command = [sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", "rr-02", "--stream", "--",
                "godot", "--headless", "--path", str(PROJECT), "--script", str(script)]
            result = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertNotIn("SCRIPT ERROR:", result.stdout)
            self.assertIn("RECIPE_MOTION_PARAMETERS: PASS", result.stdout)

    def test_value_gate_measures_runtime_hidden_pixels_and_rejects_stale_previews(self):
        import importlib.util
        module = importlib.util.spec_from_file_location("runtime_value_gate", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(module)
        module.loader.exec_module(gates)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ["source", "recipes", "layouts", "registered", "hidden", "hidden_fills"]:
                shutil.copytree(CASE / name, root / name)
            shutil.copyfile(CASE / "cutout.json", root / "cutout.json")
            self.assertTrue(all(row["ok"] for row in gates.value_counts(root)))
            path = root / "hidden/rear/thigh_far.png"
            pixels = np.array(Image.open(path).convert("RGBA"))
            pixels[pixels[..., 3] > 128, :3] = 220
            Image.fromarray(pixels).save(path)
            row = next(r for r in gates.value_counts(root) if (r["view"], r["part"]) == ("rear", "thigh_far"))
            self.assertFalse(row["ok"])
            self.assertAlmostEqual(row["hidden_median_l"], 87.7609, places=3)
            self.assertAlmostEqual(row["preview_median_l"], 15.9564, places=3)
            self.assertEqual(row["preview_runtime_different_pixels"], row["hidden_pixels"])
            self.assertEqual(row["runtime_coverage_errors"], 0)
            # Updating a preview to conceal the mismatch still fails L* limits.
            preview_path = root / "hidden_fills/rear_thigh_far.png"
            preview = np.array(Image.open(preview_path))
            mask = np.load(root / "registered/rear_hidden_thigh_far.npy")
            preview[mask, :3] = 220
            Image.fromarray(preview).save(preview_path)
            row = next(r for r in gates.value_counts(root) if (r["view"], r["part"]) == ("rear", "thigh_far"))
            self.assertFalse(row["ok"])
            self.assertEqual(row["preview_runtime_different_pixels"], 0)
            pixels[pixels[..., 3] > 128, 3] = 0
            Image.fromarray(pixels).save(path)
            row = next(r for r in gates.value_counts(root) if (r["view"], r["part"]) == ("rear", "thigh_far"))
            self.assertFalse(row["ok"])
            self.assertEqual(row["runtime_coverage_errors"], row["hidden_pixels"])

    def test_rendered_hidden_owners_measure_pixels_and_reject_runtime_palette_mismatch(self):
        import importlib.util
        module = importlib.util.spec_from_file_location("rendered_value_gate", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(module)
        module.loader.exec_module(gates)
        pixels = np.zeros((20, 20, 4), dtype=np.uint8)
        pixels[2:18, 2:18] = [220, 220, 220, 255]
        owners = np.full((20, 20), -1)
        owners[2:18, 2:18] = 0
        parts = [{"name": "hidden_thigh", "logical_part": "thigh_far", "bone": "thigh", "hidden_material": True}]
        empty = np.zeros((20, 20), dtype=bool)
        palette = {"hidden_thigh": gates.rgba_codes(np.array([[40, 35, 30, 255]], dtype=np.uint8))}
        report = gates.frame_counts(pixels, owners, parts, empty, empty, "rear", "walk", np.array([50, 70, 30]), runtime_palettes=palette)
        self.assertEqual(report["hidden_runtime_mismatch_pixels"], 256)
        self.assertAlmostEqual(report["rendered_hidden_values"][0]["rendered_median_l"], 87.7609, places=3)

    def test_registered_rest_is_exact_rgba_including_hidden_underlays(self):
        config = read_json(CASE / "cutout.json")
        for view, path in config["layouts"].items():
            with self.subTest(view=view):
                layout = read_json(CASE / path)
                rest = Image.new("RGBA", (255, 255))
                for part in sorted(layout["parts"], key=lambda p: p["z_index"]):
                    rest.alpha_composite(Image.open(CASE / part["file"]).convert("RGBA"), tuple(part["offset"]))
                approved = Image.open(CASE / "source" / view / "processed.png").convert("RGBA")
                self.assertEqual(rest.tobytes(), approved.tobytes())
                self.assertFalse(layout.get("joint_meshes"), "Director requires rigid cloth, no skins")
        self.assertTrue(validate(CASE)["ok"])

    def test_production_motion_and_approved_paint_are_untouched_copies(self):
        self.assertIn("gaoler_motion.gd", read_json(CASE / "cutout.json")["sources"])
        self.assertEqual(digest(CASE / "gaoler_motion.gd"), digest(PROJECT / "scripts/chainbound_gaoler_cutout/motion.gd"))
        for view, job in [("front", "mq3_front_v4"), ("rear", "mq3_rear_v3")]:
            self.assertEqual(digest(CASE / "source" / view / "processed.png"), digest(PROJECT / "spec/art_identity/jobs/chainbound_gaoler" / job / "processed.png"))

    def test_all_labels_have_measured_requests_and_seven_clip_exposure(self):
        names = read_json(CASE / "source/spec.json")["labels"]
        index = read_json(CASE / "hidden_requests/index.json")
        requests = index["requests"]
        self.assertEqual(index["samples_sha256"], digest(CASE / "proof/motion_samples.json"))
        for path, expected in read_json(CASE / "proof/motion_samples.json")["inputs"].items():
            self.assertFalse(Path(path).is_absolute(), "Motion proof must remain portable with the case")
            self.assertEqual(digest(CASE / path), expected)
        self.assertEqual({(r["view"], r["part"]) for r in requests}, {(v, n) for v in ["front", "rear"] for n in names})
        self.assertEqual([r["max_exposed_pixels"] for r in requests], sorted([r["max_exposed_pixels"] for r in requests], reverse=True))
        plan = (CASE / "hidden_requests/paint_plan.md").read_text()
        for request in requests:
            self.assertEqual(request["status"], "measured")
            self.assertEqual(request["exposure_status"], "sampled_cpu_visibility")
            self.assertIsInstance(request["hidden_pixel_count"], int)
            self.assertEqual({m["clip"] for m in request["clip_exposure"]}, {"idle", "walk", "strike", "hit", "death", "chain_reel", "manacle_pin"})
            self.assertTrue(all(m["sampled_frames"] > 0 for m in request["clip_exposure"]))
            self.assertIn(f"{request['view']} / {request['part']}", plan)
            self.assertIn(request["material"], plan)
            path = CASE / request["image"]
            with Image.open(path) as native, Image.open(path.with_name(path.stem + "_4x.png")) as enlarged:
                self.assertEqual(enlarged.tobytes(), native.resize((1020, 1020), Image.Resampling.NEAREST).tobytes())

    def test_complete_render_manifest_matches_every_provided_input(self):
        manifest = read_json(CASE / "source/maquette_manifest.json")
        self.assertTrue(manifest["complete"])
        self.assertEqual(manifest["missing"], [])
        self.assertEqual(len(manifest["files"]), 47)
        supplied = PROJECT / "spec/art_identity/jobs/chainbound_gaoler/mq3_maquette_renders"
        for name, expected in manifest["files"].items():
            self.assertEqual(digest(CASE / "source/maquette" / name), expected)
            self.assertEqual(digest(supplied / name), expected)

    def test_rigid_cloth_matches_production_bones_and_parenting(self):
        config = read_json(CASE / "cutout.json")
        self.assertEqual(config["design_placeholders"], {})
        for view, path in config["layouts"].items():
            layout = read_json(CASE / path)
            production = read_json(PROJECT / f"assets/units/chainbound_gaoler_cutout/{view}.json")
            for label, counterpart in [("tabard", "tabard"), ("coat_near", "coat_fist"), ("coat_far", "coat_hook")]:
                original = next(p for p in production["parts"] if p["name"] == counterpart)
                parts = [p for p in layout["parts"] if p.get("logical_part", p["name"]) == label]
                self.assertTrue(parts, (view, label))
                for part in parts:
                    self.assertEqual(part["bone"], original["bone"])
                    self.assertEqual(layout["joints"][part["bone"]]["parent"], production["joints"][original["bone"]]["parent"])
                    self.assertEqual(part.get("equipment_slot"), original.get("equipment_slot"))

    def test_material_and_speck_cleanup_is_reproducible_and_preserves_rest_depth(self):
        recipe = read_json(CASE / "recipes/rig.json")
        spec = read_json(CASE / "source/spec.json")
        palette = read_json(CASE / "source/label_palette.json")
        names = list(spec["labels"])
        for view in ["front", "rear"]:
            paint = np.array(Image.open(CASE / f"source/{view}/processed.png").convert("RGBA"))
            original = np.load(CASE / f"registered/{view}_original_owners.npy")
            owners = np.load(CASE / f"registered/{view}_owners.npy")
            trousers, material = material_reference(CASE, spec, palette, view, recipe["ownership_cleanup"])
            solos = {n: np.array(Image.open(CASE / f"registered/{view}_solo_{n}.png"))[..., 3] > 128 for n in names}
            expected, hidden, report = clean_ownership(original, paint, names, solos, view, material, recipe["ownership_cleanup"])
            labels = decode_labels(Image.open(CASE / f"registered/{view}_parts.png"), palette, names, camera_depths(spec, view))
            expected, hidden, shadow_report = occlusion_shadow_ownership(expected, hidden, paint, labels, names, solos, recipe["occlusion_shadow"])
            self.assertEqual(shadow_report, read_json(CASE / f"proof/{view}_occlusion_shadow.json"))
            np.testing.assert_array_equal(expected, owners)
            np.testing.assert_array_equal(trousers, np.load(CASE / f"registered/{view}_trousers.npy"))
            self.assertEqual(report, read_json(CASE / f"proof/{view}_ownership_cleanup.json"))
            if view == "front":
                self.assertEqual({n: r["moved_to_tabard"] for n, r in report["material_transfers"].items()},
                                 {"pelvis": 71, "thigh_far": 174, "thigh_near": 67, "shin_far": 303, "shin_near": 104, "coat_far": 11, "coat_near": 20})
            else:
                self.assertTrue(all(r["moved_to_tabard"] == 0 for r in report["material_transfers"].values()))
            for i, name in enumerate(names):
                np.testing.assert_array_equal(hidden[i], np.load(CASE / f"registered/{view}_hidden_{name}.npy"))
                self.assertFalse([c for c in components8((owners == i) | hidden[i])[1:] if c.sum() < 12], (view, name))
            layout = read_json(CASE / f"layouts/{view}.json")
            order = depth_order(camera_depths(spec, view))
            for part in layout["parts"]:
                if part.get("hidden_material"):
                    continue
                image = np.array(Image.open(CASE / part["file"]))
                x, y = part["offset"]
                original_crop = original[y:y+image.shape[0], x:x+image.shape[1]]
                self.assertTrue(np.all(original_crop[image[..., 3] > 0] == names.index(part["rest_depth_source"])))
                if part.get("occlusion_shadow"):
                    self.assertEqual(part["bone"], "pelvis")
                    self.assertEqual(part["z_index"], -1)
                else:
                    self.assertEqual(part["z_index"], order.index(part["rest_depth_source"]))

    def test_trouser_fill_gate_and_rear_arm_draw_order_in_all_samples(self):
        # Round7 fills newly exposed leg support with trousers, using the sparse
        # near-thigh shadow reference where needed; visible rest RGBA stays exact.
        manifest = read_json(CASE / "hidden_fills/index.json")
        for request in manifest["requests"]:
            if request["part"] in ["pelvis", "thigh_far", "thigh_near", "shin_far", "shin_near"]:
                sparse = request["own_visible_pixels"] < 40
                material = request["part"] in ["shin_far", "shin_near"]
                self.assertEqual(request["donor_parts"], ["thigh_near" if sparse or material else request["part"]])
                self.assertNotIn("cross_view_donor", request)
                if sparse or material:
                    reference = request["value_reference_substitution"]
                    self.assertEqual(reference["view"], request["view"])
                    self.assertEqual(reference["part"], "thigh_near")
                    shift = -6 if sparse else 0
                    self.assertEqual(reference["l_shift"], shift)
                    self.assertEqual(reference["rule"], "sparse" if sparse else "trousers_material")
                    self.assertAlmostEqual(reference["source_median_l"] + shift, reference["target_median_l"])
                    paint = np.array(Image.open(CASE / f"source/{request['view']}/processed.png"))
                    owners = np.load(CASE / f"registered/{request['view']}_owners.npy")
                    names = list(read_json(CASE / "source/spec.json")["labels"])
                    near = paint[owners == names.index("thigh_near"), :3]
                    self.assertEqual(reference["source_rgb_sha256"], array_digest(near))
                    self.assertAlmostEqual(reference["source_median_l"], np.median(to_lab(near)[:, 0]))
                    self.assertNotIn("design_placeholder", request)
                value = request["value_distribution"]
                self.assertLessEqual(value["median_difference_l"], 8)
                self.assertGreater(value["hidden_midtones_pixels"], 0)
                pixels = np.array(Image.open(CASE / request["preview"]))
                mask = np.load(CASE / f"registered/{request['view']}_hidden_{request['part']}.npy")
                actual = float(np.median(to_lab(pixels[mask, :3])[:, 0]))
                self.assertAlmostEqual(actual, value["hidden_median_l"])
                if request["part"] != "pelvis":
                    self.assertGreaterEqual(float(to_lab(pixels[mask, :3])[:, 0].min()), 15)
        layouts = {v: read_json(CASE / f"layouts/{v}.json") for v in ["front", "rear"]}
        samples = read_json(CASE / "proof/motion_samples.json")["samples"]
        self.assertEqual(len(samples), 458)
        for sample in samples:
            parts = layouts[sample["view"]]["parts"]
            actual = sample["draw_order"]
            if sample["view"] == "rear" and sample["clip"] in ["strike", "manacle_pin"]:
                occluder = min(actual[p["name"]] for p in parts if p.get("logical_part", p["name"]) in ["head", "torso", "coat_near", "coat_far"])
                arm = [p for p in parts if p["bone"] in ["upper_fist", "fore_fist", "hand_fist"]]
                self.assertTrue(all(actual[p["name"]] < occluder for p in arm))
                self.assertEqual(len({actual[p["name"]] - p["z_index"] for p in arm}), 1)
            else:
                self.assertTrue(all(actual[p["name"]] == p["z_index"] for p in parts))

    def test_rear_arm_constraint_preserves_front_and_non_arm_motion(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("rr02_motion_gates", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gates)
        samples = read_json(CASE / "proof/motion_samples.json")["samples"]
        original = read_json(CASE / "proof/motion_samples_unconstrained.json")["samples"]
        layout = read_json(CASE / "layouts/rear.json")
        checked = 0
        for sample, before in zip(samples, original):
            constrained = sample["view"] == "rear" and sample["clip"] in ["strike", "manacle_pin"]
            for name, matrix in sample["bones"].items():
                if not constrained or name not in ["upper_fist", "fore_fist", "hand_fist"]:
                    np.testing.assert_allclose(matrix, before["bones"][name], rtol=0, atol=0.0001)
            if constrained:
                _, owners, _, arm, body = gates.rasterize(CASE, layout, sample)
                arm_ids = [i for i, part in enumerate(layout["parts"]) if part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]]
                self.assertFalse(np.any(np.isin(owners, arm_ids)))
                self.assertFalse(np.any(arm & ~body), (sample["clip"], sample["frame"]))
                checked += 1
        self.assertEqual(checked, 70)

    def test_rear_lean_and_shoulder_follow_authorized_envelopes(self):
        before = read_json(CASE / "provenance/round5/proof/motion_samples_unconstrained.json")["samples"]
        after = read_json(CASE / "proof/motion_samples_unconstrained.json")["samples"]
        joints = read_json(CASE / "layouts/rear.json")["joints"]
        def matrix(values):
            a, b, c, d, x, y = values
            return np.array([[a, c, x], [b, d, y], [0, 0, 1.]])
        def curve(t, keys):
            for (a, va), (b, vb) in zip(keys, keys[1:]):
                if t <= b:
                    u = (t - a) / (b - a)
                    return va + (vb - va) * u * u * (3 - 2 * u)
            return keys[-1][1]
        def descendant(name, parent):
            while name is not None:
                if name == parent:
                    return True
                name = joints[name]["parent"]
            return False
        for old, new in zip(before, after):
            self.assertEqual([old[k] for k in ["view", "clip", "frame"]], [new[k] for k in ["view", "clip", "frame"]])
            changed = new["view"] == "rear" and new["clip"] in ["strike", "manacle_pin"]
            if changed:
                t = new["phase"]
                if new["clip"] == "strike":
                    prep = curve(t, [(0, 0), (.22, 1), (.30, 1), (.42, 0), (1, 0)])
                    hit = curve(t, [(0, 0), (.30, 0), (.42, 1), (.56, 1), (1, 0)])
                else:
                    prep = curve(t, [(0, 0), (.08, 1), (4/38, 0), (1, 0)])
                    hit = curve(t, [(0, 0), (.08, 0), (4/38, 1), (12/38, 1), (.65, .55), (1, 0)])
                theta = .07 * hit
                rotation = np.array([[np.cos(theta), -np.sin(theta)], [np.sin(theta), np.cos(theta)]])
                pivot = matrix(old["bones"]["torso"])[:2, 2]
                transform = np.eye(3)
                transform[:2, :2] = rotation
                transform[:2, 2] = pivot - rotation @ pivot
                shoulder = matrix(new["bones"]["torso"])[:2, :2] @ np.array([0, -3 * prep])
            for name, values in old["bones"].items():
                expected = matrix(values)
                if changed and descendant(name, "torso"):
                    expected = transform @ expected
                    if descendant(name, "upper_fist"):
                        expected[:2, 2] += shoulder
                np.testing.assert_allclose(matrix(new["bones"][name]), expected, rtol=0, atol=.0001,
                    err_msg=str((new["view"], new["clip"], new["frame"], name)))

    def test_motion_gate_scopes_logical_owners_and_uses_strict_threshold(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("rr02_motion_gate_counts", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gates)
        pixels = np.zeros((16, 16, 4), dtype=np.uint8)
        pixels[2:7, 2:7] = [84, 28, 24, 255]
        pixels[12, 12] = [20, 16, 21, 255]
        owners = np.full((16, 16), -1)
        owners[pixels[..., 3] > 0] = 0
        arm, body = np.zeros((16, 16), bool), np.zeros((16, 16), bool)
        arm[10, 10] = True
        report = gates.frame_counts(pixels, owners, [{"name": "metal"}], arm, body, "rear", "strike", to_lab(np.array([84, 28, 24])))
        self.assertEqual(report["tabard_non_tabard_pixels"], 0)
        for view, part, count in [("rear", "thigh_far", 25), ("rear", "shin_far", 0), ("front", "shin_far", 25)]:
            result = gates.frame_counts(pixels, owners, [{"name": "physical", "logical_part": part}], arm, body, view, "strike", to_lab(np.array([84, 28, 24])))
            self.assertEqual(result["tabard_non_tabard_pixels"], count)
            self.assertEqual(set(result["tabard_collisions_by_part"]), set(gates.TABARD_GATE_PARTS[view]))
        reference = to_lab(np.array([84, 28, 24]))
        for distance, expected in [(12, 0), (11.999, 25)]:
            shifted = reference + np.array([distance, 0, 0])
            result = gates.frame_counts(pixels, owners, [{"name": "pelvis"}], arm, body, "front", "strike", shifted)
            self.assertEqual(result["tabard_non_tabard_pixels"], expected)
        self.assertEqual(report["detached_small_pixels"], 1)
        self.assertEqual(report["rear_arm_outside_pixels"], 1)
        pixels[11, 11] = pixels[12, 12]
        owners[11, 11] = 0
        self.assertEqual(gates.frame_counts(pixels, owners, [{"name": "metal"}], arm, body, "rear", "strike", to_lab(np.array([84, 28, 24])))["detached_small_pixels"], 2)

    def test_new_dark_region_gate_requires_same_part_rest_provenance(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("rr02_dark_gate", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gates)
        pixels = np.zeros((16, 16, 4), dtype=np.uint8)
        pixels[3:7, 3:7] = [5, 5, 5, 255]
        owners = np.full((16, 16), -1)
        owners[pixels[..., 3] > 0] = 0
        parts = [{"name": "thigh_near"}, {"name": "thigh_far"}]
        empty = np.zeros((16, 16), dtype=bool)
        baseline = np.full((16, 16), -1)
        def count():
            return gates.frame_counts(pixels, owners, parts, empty, empty, "front", "walk", np.array([50, 50, 50]), baseline)["new_leg_dark_pixels"]
        self.assertEqual(count(), 16)
        baseline[3:7, 3:7] = 1
        self.assertEqual(count(), 16)  # Darkness on the other leg does not exempt it.
        baseline[3:7, 3:7] = 0
        self.assertEqual(count(), 0)
        baseline[:] = -1
        pixels[6, 3:7] = 0
        self.assertEqual(count(), 0)  # Exactly 12 new dark pixels is allowed.
        pixels[6, 7] = [5, 5, 5, 255]
        owners[6, 7] = 0
        self.assertEqual(count(), 13)  # Diagonal connection counts (8-connected).

    @unittest.skipUnless(shutil.which("godot"), "Godot unavailable for native-probe pose regression")
    def test_native_capture_pose_path_includes_rest_headlessly(self):
        command = [sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", "rr-02", "--stream", "--",
            "godot", "--headless", "--path", str(PROJECT), "--script", str(CASE / "probes/native_motion.gd"),
            "--", "--case", str(CASE / "cutout.json"), "--check-poses"]
        result = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("SCRIPT ERROR:", result.stdout)
        self.assertIn("MAQUETTE_NATIVE_POSES: PASS (460 poses; five surfaces; GPU readback not exercised)", result.stdout)

    @unittest.skipUnless(shutil.which("godot"), "Godot unavailable for native-probe output regression")
    def test_native_mask_output_is_data_but_real_screenshots_still_validate(self):
        import visual_probe_runner as visual
        kinds = ["rgba", "owners", "arm", "body", "rest_dark"]
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory).resolve()
            pixels = np.zeros((512, 512, 4), dtype=np.uint8)
            pixels[..., :3] = ((np.indices((512, 512)).sum(axis=0) % 2) * 200 + 20)[..., None]
            pixels[..., 3] = 255
            Image.fromarray(pixels).save(fixture / "rgba.png")
            for kind in kinds[1:]:
                Image.new("RGBA", (512, 512)).save(fixture / (kind + ".png"))
            command = [sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", "rr-02", "--stream", "--",
                "godot", "--headless", "--path", str(PROJECT), "--script", str(CASE / "probes/native_motion.gd"),
                "--", "--case", str(CASE / "cutout.json"), "--check-output", str(fixture)]
            result = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150)
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertNotIn("SCRIPT ERROR:", result.stdout)
            self.assertIn("MAQUETTE_NATIVE_OUTPUT: PASS", result.stdout)
            report = read_json(fixture / "output_contract.json")
            self.assertTrue(report["ok"])
            screenshots = visual.collect_pngs(str(fixture / "screenshots"), "unused", fixture / "home")
            self.assertEqual(screenshots, [fixture / "screenshots/front_rest/rgba_0000.png"])
            visual.validate_pngs(screenshots, 1, [(512, 512)])
            for kind in kinds[1:]:
                path = fixture / report["files"][kind]
                self.assertNotIn(path, screenshots)
                self.assertEqual(Image.open(path).tobytes(), Image.open(fixture / (kind + ".png")).tobytes())
                with self.assertRaises(visual.ProbeError):
                    visual.validate_pngs([path], 1)  # Deliberately blank data is legitimate.
            Image.new("RGBA", (512, 512)).save(screenshots[0])
            with self.assertRaisesRegex(visual.ProbeError, "effectively black"):
                visual.validate_pngs(screenshots, 1)  # No exemption for a bad real screenshot.

    def test_native_capture_collects_only_accepted_data_and_forwards_timeout(self):
        import importlib.util
        from types import SimpleNamespace
        spec = importlib.util.spec_from_file_location("rr02_capture_transport", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gates)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "case"
            output = Path(directory) / "reel"
            output.mkdir()
            write_json(root / "cutout.json", read_json(CASE / "cutout.json"))
            screenshots = Path(directory) / "accepted_screenshots"
            (screenshots / "front_rest").mkdir(parents=True)
            captured = {}
            def fake_runner(command, check):
                self.assertFalse(check)
                self.assertEqual(float(command[command.index("--timeout") + 1]), 1234)
                self.assertEqual(command[command.index("--min-images") + 1], "504")
                self.assertIn("1920x1080", command)
                self.assertIn("512x512", command)
                data_root = Path(command[command.index("--data-output") + 1])
                captured["data_root"] = data_root
                data = data_root / "accepted_attempt"
                (data / "front_rest").mkdir(parents=True)
                (data_root / "rejected_attempt").mkdir()
                (data_root / "rejected_attempt/wrong.png").write_bytes(b"not the accepted attempt")
                files = {}
                for kind in ["rgba", "owners", "arm", "body", "rest_dark"]:
                    relative = f"front_rest/{kind}_0000.png"
                    path = (screenshots if kind == "rgba" else data) / relative
                    Image.new("RGBA", (512, 512)).save(path)
                    files[kind] = relative if kind == "rgba" else "data/" + relative
                write_json(screenshots / "native_motion_manifest.json", {"frames": [{"view": "front", "clip": "rest", "frame": 0, "files": files}]})
                write_json(screenshots / "native_motion_transport.json", {"data_directory": str(data)})
                write_json(output / "native_motion_result.json", {"ok": True, "images": [{"path": str(screenshots / files["rgba"])}]})
                return SimpleNamespace(returncode=0)
            def inspect_collected(*args):
                destination = output / "motion_gate_capture"
                hashes = read_json(destination / "sha256.json")
                self.assertEqual(len(hashes), 6)  # Five surfaces and the portable manifest.
                self.assertEqual(sum(p.startswith("data/") for p in hashes), 4)
                self.assertFalse((destination / "native_motion_transport.json").exists())
                self.assertFalse((destination / "data/wrong.png").exists())
                for relative, expected in hashes.items():
                    self.assertEqual(digest(destination / relative), expected)
                return {"ok": True}
            with patch("cutout_pipeline.proof.verify_render", return_value={"ok": True}), patch("subprocess.run", side_effect=fake_runner), patch.object(gates, "native_gates", side_effect=inspect_collected):
                self.assertTrue(gates.capture_native(root, output, "rr-02", 1234)["ok"])
            self.assertFalse(captured["data_root"].exists())
            # Missing mask data must fail before creating an apparently complete capture.
            (screenshots / "native_motion_transport.json").write_text(json.dumps({"data_directory": str(screenshots)}))
            missing = output / "incomplete"
            with self.assertRaisesRegex(CutoutError, "Missing native capture data"):
                gates.collect_native_output(screenshots, screenshots, missing)
            self.assertFalse(missing.exists())

    def test_native_capture_timeout_and_screenshot_contract(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("rr02_capture_options", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gates)
        self.assertEqual(gates.NATIVE_CAPTURE_TIMEOUT_SECONDS, 900)
        self.assertEqual(gates.positive_seconds("1234.5"), 1234.5)
        for value in ["0", "-1", "nan", "inf"]:
            with self.assertRaises(argparse.ArgumentTypeError):
                gates.positive_seconds(value)
        config = read_json(CASE / "cutout.json")
        count = len(config["layouts"]) * (1 + sum(c["frames"] for c in config["clips"].values()))
        self.assertEqual(count, 460)
        self.assertEqual(gates.native_screenshot_count(config), count + len(config["layouts"]) * (1 + 3 * len(config["clips"])))
        self.assertEqual(gates.native_screenshot_count({"layouts": {"front": "unused"}, "clips": {"single": {"frames": 1}}}), 4)
        with patch("subprocess.run") as process:
            for timeout in [0, -1, float("nan"), float("inf")]:
                with self.assertRaisesRegex(CutoutError, "positive and finite"):
                    gates.capture_native(CASE, CASE, "rr-02", timeout)
            process.assert_not_called()

    def _native_gate_fixture(self, directory):
        """Portable native_gates fixture; only renderer attestation is mocked.

        Real PNG decoding, checksums, input binding, coverage, rest calibration,
        owner lookup and pixel gates run. Owner 80 has eight opaque hidden-thigh
        pixels; the rear strike arm has 1,718 pixels inside the body mask.
        """
        import importlib.util
        spec = importlib.util.spec_from_file_location("native_mask_regression", CASE / "probes/motion_gates.py")
        gates = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gates)
        root, output = Path(directory) / "case", Path(directory) / "capture"
        capture = output / "motion_gate_capture"
        capture.mkdir(parents=True)
        labels = ["torso"] + gates.LEG_PARTS
        parts = [{"name": f"node_{i}", "logical_part": "thigh_far" if i == 80 else "torso",
                  "bone": "leg", "hidden_material": i == 80, "file": "pixel.png"} for i in range(1, 81)]
        config = {"layouts": {v: f"layouts/{v}.json" for v in ["front", "rear"]},
                  "clips": {c: {"frames": 1} for c in ["idle", "strike"]}}
        write_json(root / "cutout.json", config)
        write_json(root / "source/spec.json", {"labels": dict.fromkeys(labels, [0, 0, 0])})
        gate = read_json(CASE / "recipes/rig.json")["ownership_cleanup"]["tabard_gate"]
        write_json(root / "recipes/rig.json", {"hidden_value_distribution": {"parts": []}, "ownership_cleanup": {"tabard_gate": gate}})
        write_json(root / "proof/front_ownership_cleanup.json", {"materials": {"tabard_cloth": {"median_lab": [50, 70, 30]}}})
        Image.new("RGBA", (1, 1), (100, 100, 100, 255)).save(root / "pixel.png")
        frames, views = [], {}
        for view in config["layouts"]:
            write_json(root / config["layouts"][view], {"parts": parts, "logical_parts": labels})
            (root / f"source/{view}").mkdir()
            Image.new("RGBA", (255, 255)).save(root / f"source/{view}/processed.png")
            (root / "registered").mkdir(exist_ok=True)
            np.save(root / f"registered/{view}_owners.npy", np.full((255, 255), -1, dtype=np.int16))
            for part in gates.LEG_PARTS:
                Image.new("RGBA", (255, 255)).save(root / f"registered/{view}_visible_dark_{part}.png")
            views[view] = {str(i): {"node": p["name"], "logical_part": p["logical_part"], "bone": p["bone"], "hidden": p["hidden_material"]}
                           for i, p in enumerate(parts, 1)}
            for clip in ["rest", "idle", "strike"]:
                surfaces = {kind: np.zeros((512, 512, 4), dtype=np.uint8) for kind in ["rgba", "owners", "arm", "body", "rest_dark"]}
                if (view, clip) == ("front", "idle"):
                    surfaces["rgba"][200, 200:208] = [100, 100, 100, 255]
                    surfaces["owners"][200, 200:208] = [80, 0, 0, 255]
                if (view, clip) == ("rear", "strike"):
                    for kind in ["arm", "body"]:
                        surfaces[kind].reshape(-1, 4)[:1718] = [255, 255, 255, 255]
                files = {}
                for kind, pixels in surfaces.items():
                    relative = ("" if kind == "rgba" else "data/") + f"{view}_{clip}/{kind}_0000.png"
                    path = capture / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    Image.fromarray(pixels).save(path)
                    files[kind] = relative
                if clip != "rest":
                    (output / f"{view}_{clip}").mkdir()
                    Image.fromarray(surfaces["rgba"]).save(output / f"{view}_{clip}/pose_0000.png")
                frames.append({"view": view, "clip": clip, "frame": 0, "files": files})
        write_json(capture / "native_motion_manifest.json", {"ok": True, "inputs": {"cutout.json": digest(root / "cutout.json")},
                   "views": views, "frames": frames})
        write_json(capture / "sha256.json", {str(p.relative_to(capture)): digest(p) for p in sorted(capture.rglob("*")) if p.is_file()})
        return gates, root, output

    def test_native_gates_rejects_checksum_refreshed_surface_size_mutations(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as directory, patch("cutout_pipeline.proof.verify_render", return_value={"ok": True}), contextlib.redirect_stdout(io.StringIO()):
            gates, root, output = self._native_gate_fixture(directory)
            self.assertTrue(gates.native_gates(root, output)["ok"])  # Empty 512px masks are legitimate.
            capture = output / "motion_gate_capture"
            hashes = read_json(capture / "sha256.json")
            for kind in ["rgba", "owners", "arm", "body", "rest_dark"]:
                with self.subTest(surface=kind):
                    relative = ("" if kind == "rgba" else "data/") + f"rear_strike/{kind}_0000.png"
                    path = capture / relative
                    before = path.read_bytes()
                    if kind == "arm":
                        self.assertEqual(int((np.array(Image.open(path))[..., 3] > 0).sum()), 1718)
                    Image.new("RGBA", (1, 1)).save(path)
                    hashes[relative] = digest(path)
                    write_json(capture / "sha256.json", hashes)
                    with self.assertRaisesRegex(CutoutError, f"Native surface dimensions failed: rear/strike/0/{kind}; expected 512x512, got 1x1"):
                        gates.native_gates(root, output)
                    path.write_bytes(before)
                    hashes[relative] = digest(path)
                    write_json(capture / "sha256.json", hashes)

    def test_native_gates_rejects_checksum_refreshed_zero_and_unknown_opaque_ids(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as directory, patch("cutout_pipeline.proof.verify_render", return_value={"ok": True}), contextlib.redirect_stdout(io.StringIO()):
            gates, root, output = self._native_gate_fixture(directory)
            control = gates.native_gates(root, output)
            self.assertTrue(control["ok"])
            idle = next(r for r in control["records"] if (r["view"], r["clip"]) == ("front", "idle"))
            self.assertEqual(idle["rendered_hidden_values"][0]["visible_hidden_pixels"], 8)
            capture = output / "motion_gate_capture"
            hashes = read_json(capture / "sha256.json")
            for kind, message in [("owners", "Native owner IDs/alpha failed validation"), ("rest_dark", "Native visible-rest dark provenance IDs failed validation")]:
                for invalid_id in [0, 65535]:
                    with self.subTest(surface=kind, invalid_id=invalid_id):
                        relative = f"data/front_idle/{kind}_0000.png"
                        path = capture / relative
                        before = path.read_bytes()
                        pixels = np.array(Image.open(path))
                        if kind == "owners":
                            self.assertTrue(np.all(pixels[200, 200:208] == [80, 0, 0, 255]))
                        pixels[200, 200:208] = [invalid_id % 256, invalid_id // 256, 0, 255]
                        Image.fromarray(pixels).save(path)
                        hashes[relative] = digest(path)
                        write_json(capture / "sha256.json", hashes)
                        with self.assertRaisesRegex(CutoutError, message):
                            gates.native_gates(root, output)
                        path.write_bytes(before)
                        hashes[relative] = digest(path)
                        write_json(capture / "sha256.json", hashes)

    def test_native_collector_publishes_success_only_after_motion_gates(self):
        import contextlib
        import importlib.util
        import io
        from types import SimpleNamespace
        spec = importlib.util.spec_from_file_location("rr02_native_collector", CASE / "probes/proof.py")
        collector = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(collector)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "case"
            output = Path(directory) / "capture"
            (root / "source/front").mkdir(parents=True)
            (output / "front_walk").mkdir(parents=True)
            frame = Image.new("RGBA", (4, 4), (50, 40, 30, 255))
            for path in [root / "source/front/processed.png", output / "front_rest.png", output / "front_walk/pose_0000.png"]:
                frame.save(path)
            write_json(root / "cutout.json", {"layouts": {"front": "unused"}})
            write_json(output / "render_manifest.json", {"clips": [{"cycle_frames": 1, "facing": "front", "clip": "walk", "folder": "front_walk"}]})
            write_json(output / "proof_sha256.json", {})
            verification = root / "proof/native_keyframes/verification.json"
            with patch.object(collector, "verify_render", return_value={"ok": True}), patch.object(collector, "contact_sheet") as sheets:
                with patch.dict(sys.modules, {"motion_gates": SimpleNamespace(native_gates=lambda *args: {"ok": False})}):
                    with self.assertRaisesRegex(CutoutError, "Native motion gates failed"):
                        collector.native(root, output)
                sheets.assert_not_called()
                self.assertFalse(verification.exists())
                stdout = io.StringIO()
                with patch.dict(sys.modules, {"motion_gates": SimpleNamespace(native_gates=lambda *args: {"ok": True})}), contextlib.redirect_stdout(stdout):
                    collector.native(root, output)
                self.assertIn("MAQUETTE_PROOF: PASS", stdout.getvalue())
                self.assertEqual(read_json(verification)["native_motion_gates"], "PASS")

    def test_chain_reel_has_three_painted_links_at_production_fractions(self):
        for view in ["front", "rear"]:
            layout = read_json(CASE / f"layouts/{view}.json")
            original = read_json(CASE / f"source/production/{view}.json")["joints"]
            joints = layout["joints"]
            start = np.array(joints["chain"]["position"])
            axis = np.array(joints["hook"]["position"]) - start
            reference_start = np.array(original["chain_a"]["position"])
            reference_axis = np.array(original["hook"]["position"]) - reference_start
            for bone in ["chain_b", "chain_c"]:
                fraction = (np.array(original[bone]["position"]) - reference_start) @ reference_axis / (reference_axis @ reference_axis)
                np.testing.assert_allclose(joints[bone]["position"], start + fraction * axis)
            self.assertEqual({p["bone"] for p in layout["parts"] if p.get("logical_part") == "chain"}, {"chain", "chain_b", "chain_c"})
            self.assertEqual(joints["hook"]["parent"], "chain_c")

    def test_joint_registration_uses_cached_projection_without_manual_refitting(self):
        original = read_json(CASE / "source/maquette/joints_px.json")
        spec = read_json(CASE / "source/spec.json")
        for view in original:
            definition = read_json(CASE / "registered" / f"{view}_registration.json")
            transform = Registration(**definition)
            actual = read_json(CASE / "registered" / f"{view}_joints_px.json")
            for name, point in original[view].items():
                np.testing.assert_allclose(projected(spec, spec["joints"][name], view), point, atol=0.02)
                np.testing.assert_allclose(actual[name], transform.point(point))


if __name__ == "__main__":
    unittest.main(verbosity=2)
