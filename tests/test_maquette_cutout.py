#!/usr/bin/env python3
"""Observable registration, ownership, hidden-material and approved-rest contracts."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from art_identity_gate import process_raw, silhouette_edge
from cutout_pipeline.cases import CutoutError, PROJECT, case_hashes, digest, read_json, write_json
from cutout_pipeline.validation import validate
from maquette_cutout import (FILL_DEFAULTS, MAGENTA, Registration, build, camera_depths, decode_labels, depth_order,
                            fill_donors, fill_hidden, fill_pixels, part_palette, same_material_donors,
                            hidden_region, material_neighbours, nearest_labels, projected,
                            registration, request_image)

CASE = PROJECT / "experiments/cutouts/chainbound_gaoler/mq3"


class HiddenFillTests(unittest.TestCase):
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
            expected_parts = {"thigh_far", "hand_near", "tabard"}
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


class SyntheticMaquetteTests(unittest.TestCase):
    def test_complete_synthetic_case_is_repeatable_and_keeps_all_source_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            spec = {"target": [0, 0, 0], "ortho_scale": 4,
                    "joints": {"root": [0, 0, 0], "head": [0, 0, 0.4]},
                    "labels": {"body": [1, 0, 0], "head": [0, 0, 1]},
                    "shapes": [{"type": "ellipsoid", "part": "body", "at": "root"},
                               {"type": "ellipsoid", "part": "head", "at": "head"}]}
            write_json(root / "spec.json", spec)
            recipe = {"character_id": "synthetic", "joints": {"root": {"joint": "root", "parent": None},
                       "head": {"joint": "head", "parent": "root"}}, "parts": {"body": "root", "head": "head"},
                      "motion": "motion.gd", "clips": {"idle": {"frames": 2, "duration": 1, "loop": True}},
                      "rigid_bones": [], "contact_feet": []}
            write_json(root / "rig.json", recipe)
            write_json(root / "palette.json", {"body": [255, 0, 0], "head": [0, 0, 255]})
            cache = root / "renders"
            cache.mkdir()
            joints = {}
            for view in ["front", "rear"]:
                job = root / view
                job.mkdir()
                raw = Image.new("RGB", (1024, 1024), (0, 255, 0))
                raw.paste((90, 50, 30), (480, 480, 544, 560))
                raw.paste((140, 90, 70), (488, 444, 536, 500))
                raw.save(job / "raw.png")
                write_json(job / "kit.json", {"K": 4, "kind": "creature", "anatomy": "biped"})
                process_raw(job / "raw.png", job / "kit.json", job / "processed.png")
                labels = Image.new("RGBA", (1024, 1024))
                labels.paste((255, 0, 0, 255), (480, 480, 544, 560))
                labels.paste((0, 0, 255, 255), (488, 444, 536, 500))
                labels.save(cache / f"{view}_parts.png")
                labels.save(cache / f"{view}_clay.png")
                for name, rect in [("body", (480, 480, 544, 560)), ("head", (488, 444, 536, 500))]:
                    solo = Image.new("RGBA", (1024, 1024))
                    solo.paste((255, 255, 255, 255), rect)
                    solo.save(cache / f"{view}_solo_{name}.png")
                joints[view] = {n: projected(spec, p, view) for n, p in spec["joints"].items()}
            write_json(cache / "joints_px.json", joints)
            inputs = {p: digest(p) for p in root.rglob("*") if p.is_file()}
            args = argparse.Namespace(spec=root / "spec.json", front_job=root / "front", rear_job=root / "rear",
                                      front_raw=None, rear_raw=None, renders=cache, palette=root / "palette.json",
                                      rig_recipe=root / "rig.json", color_config=None, blender="unused",
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
            self.assertTrue(all(digest(path) == value for path, value in inputs.items()))
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

    def test_all_labels_have_measured_requests_and_five_clip_exposure(self):
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
            self.assertEqual({m["clip"] for m in request["clip_exposure"]}, {"idle", "walk", "strike", "hit", "death"})
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
