#!/usr/bin/env python3
"""Observable registration, ownership, hidden-material and approved-rest contracts."""
import argparse
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from art_identity_gate import process_raw
from cutout_pipeline.cases import CutoutError, PROJECT, case_hashes, digest, read_json, write_json
from cutout_pipeline.validation import validate
from maquette_cutout import (Registration, build, camera_depths, decode_labels, depth_order,
                            hidden_region, nearest_labels, projected, registration, request_image)

CASE = PROJECT / "experiments/cutouts/chainbound_gaoler/mq3"


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
                report = build(args)
                self.assertTrue(report["complete"], report)
                self.assertTrue(report["rest_identity"]["ok"])
                requests = read_json(args.case / "hidden_requests/index.json")["requests"]
                self.assertEqual([r["hidden_pixel_count"] for r in requests if r["part"] == "body"], [60, 60])
            self.assertEqual(case_hashes(root / "a"), case_hashes(root / "b"))
            self.assertTrue(all(digest(path) == value for path, value in inputs.items()))
            # Normal operation fails closed when a solo is missing.
            (cache / "rear_solo_head.png").unlink()
            args.case = root / "missing"
            with self.assertRaisesRegex(CutoutError, "Missing solo"):
                build(args)

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
                for mesh in layout["joint_meshes"]:
                    np.testing.assert_array_equal(np.array(mesh["vertices"]) - mesh["uvs"], np.tile(mesh["offset"], (len(mesh["vertices"]), 1)))
        self.assertTrue(validate(CASE)["ok"])

    def test_production_motion_and_approved_paint_are_untouched_copies(self):
        self.assertEqual(digest(CASE / "gaoler_motion.gd"), digest(PROJECT / "scripts/chainbound_gaoler_cutout/motion.gd"))
        for view, job in [("front", "mq3_front_v3"), ("rear", "mq3_rear_v2")]:
            self.assertEqual(digest(CASE / "source" / view / "processed.png"), digest(PROJECT / "spec/art_identity/jobs/chainbound_gaoler" / job / "processed.png"))

    def test_all_labels_have_requests_and_unavailable_solos_are_unknown(self):
        names = read_json(CASE / "source/spec.json")["labels"]
        requests = read_json(CASE / "hidden_requests/index.json")["requests"]
        self.assertEqual({(r["view"], r["part"]) for r in requests}, {(v, n) for v in ["front", "rear"] for n in names})
        for request in requests:
            if request["status"] == "missing_solo_render":
                self.assertIsNone(request["hidden_pixel_count"])
            path = CASE / request["image"]
            with Image.open(path) as native, Image.open(path.with_name(path.stem + "_4x.png")) as enlarged:
                self.assertEqual(enlarged.tobytes(), native.resize((1020, 1020), Image.Resampling.NEAREST).tobytes())

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
