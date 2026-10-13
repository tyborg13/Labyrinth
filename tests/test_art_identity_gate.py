#!/usr/bin/env python3
"""Behavioral contracts for the director-owned visual identity gate."""
import argparse
import ast
import copy
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import art_identity_gate as gate

FIXTURES = ROOT / "tests/fixtures/art_identity"


def prototype_functions(filename, namespace):
    """Load only function definitions: scratch scripts have import-time writes."""
    tree = ast.parse((ROOT / "spec/art_identity/prototype" / filename).read_text())
    functions = ast.Module(body=[node for node in tree.body if isinstance(node, ast.FunctionDef)], type_ignores=[])
    exec(compile(functions, filename, "exec"), namespace)


class GateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.temp = Path(self.directory.name)

    def mask_image(self, name, shape):
        data = np.zeros(shape.shape + (4,), dtype=np.uint8)
        data[shape] = [60, 50, 40, 255]
        path = self.temp / (name + ".png")
        Image.fromarray(data).save(path)
        return path

    def kit_args(self, folder="kit", **overrides):
        subject = self.temp / "subject.md"
        subject.write_text("Test fixture subject.\n")
        args = dict(id="fixture", subject=str(subject), view="creature_front", size_class="medium", anatomy="biped",
                    peers=["harrier_front", "grave_surgeon_front"], front_ref=None, target_h=None, target_w=None,
                    out_dir=str(self.temp / folder))
        args.update(overrides)
        return argparse.Namespace(**args)

    def test_disk_symmetry_and_border_safe_opening(self):
        ys, xs = np.ogrid[:81, :81]
        shape = (xs - 40) ** 2 + (ys - 40) ** 2 <= 35 ** 2
        measured = gate.measure(self.mask_image("disk", shape))
        self.assertGreaterEqual(measured["symmetry"], 0.99)
        self.assertLess(measured["thin_abs"], 0.01)
        solid = np.ones((30, 30), dtype=bool)
        self.assertLess(gate.thin_share(solid, 2), 0.02)

    def test_one_pixel_lines_are_thin(self):
        measured = gate.measure(self.mask_image("line", np.ones((1, 100), dtype=bool)))
        self.assertAlmostEqual(measured["thin_abs"], 1.0)

    def test_alpha_bbox_uses_strict_128(self):
        image = Image.new("RGBA", (20, 20))
        ImageDraw.Draw(image).rectangle((5, 5, 14, 14), fill=(60, 50, 40, 255))
        image.putpixel((0, 0), (60, 50, 40, 128))
        path = self.temp / "alpha.png"
        image.save(path)
        measured = gate.measure(path, art_scale=0.8)
        self.assertEqual((measured["height"], measured["width"], measured["height_drawn"]), (10, 10, 8))

    def test_diamond_passes_and_square_fails_base_v(self):
        image = Image.new("L", (160, 100))
        ImageDraw.Draw(image).polygon([(10, 50), (80, 15), (150, 50), (80, 85)], fill=255)
        diamond = gate.measure(self.mask_image("diamond", np.asarray(image) > 0), kind="object", anatomy="plinth")
        square = gate.measure(self.mask_image("square", np.ones((80, 120), dtype=bool)), kind="object", anatomy="plinth")
        bands = gate.read_json(ROOT / gate.IDENTITY / "bands.json")["object_plinth"]
        for key, band in bands.items():
            self.assertTrue(gate.in_band(diamond[key], band))
            self.assertFalse(gate.in_band(square[key], band))

    def test_prototype_parity_three_canon_files(self):
        namespace = {"np": np, "Image": Image, "ImageFilter": ImageFilter}
        prototype_functions("metrics.py", namespace)
        prototype_metric = namespace["metrics"]
        prototype_functions("scale.py", namespace)
        canon = gate.canon_entries(ROOT)
        for name in ("hero_front", "crawler_front", "crag_outcrop"):
            entry = canon[name]
            path = ROOT / entry["path"]
            measured = gate.measure(path, kind=entry["kind"])
            original = prototype_metric(path)
            _, regions, feature, _ = namespace["shape_scale"](path)
            with self.subTest(name=name):
                self.assertEqual((measured["height"], measured["width"]), (original["h"], original["w"]))
                for current, old in (("symmetry", "sym"), ("thin_abs", "thin"), ("chroma", "chroma"), ("value", "val")):
                    self.assertLessEqual(abs(measured[current] - original[old]), 0.005)
                self.assertEqual(measured["regions"], regions)
                self.assertAlmostEqual(measured["feature_px"], feature, delta=0.005)
                mask = np.asarray(gate.rgba(path).crop(gate.alpha_bbox(gate.rgba(path))))[..., 3] > 128
                radius = round(0.03 * measured["height"])
                padded = np.pad(mask, radius + 2)
                opened = namespace["dilate"](namespace["erode"](padded, namespace["disk"](radius)), namespace["disk"](radius))
                self.assertAlmostEqual(measured["thin_rel"], 1 - opened.sum() / mask.sum(), delta=0.005)

    def test_director_regression_fixtures(self):
        bands = gate.read_json(ROOT / gate.IDENTITY / "bands.json")
        measured = gate.measure(FIXTURES / "storm_capacitor.png", kind="object", anatomy="plinth")
        self.assertFalse(gate.in_band(measured["base_v_left"], bands["object_plinth"]["base_v_left"]))
        self.assertFalse(gate.in_band(measured["base_v_right"], bands["object_plinth"]["base_v_right"]))
        self.assertAlmostEqual(measured["base_v_left"], 0.02, delta=0.005)
        landmarks = gate.read_json(FIXTURES / "landmarks.json")
        arc = gate.lateral_axis(landmarks["arc_thrall"])
        hero = gate.lateral_axis(landmarks["hero_front"])
        self.assertAlmostEqual(arc, 1.8, delta=0.1)
        self.assertAlmostEqual(hero, 13.5, delta=0.1)
        self.assertFalse(gate.in_band(arc, bands["creature"]["lateral_axis_deg"]))
        self.assertTrue(gate.in_band(hero, bands["creature"]["lateral_axis_deg"]))

    def test_kit_determinism_and_pixel_digest_binding(self):
        first, second = self.kit_args("one"), self.kit_args("two")
        gate.make_kit(first)
        gate.make_kit(second)
        one, two = Path(first.out_dir), Path(second.out_dir)
        self.assertEqual((one / "kit.json").read_bytes(), (two / "kit.json").read_bytes())
        self.assertEqual((one / "prompt.md").read_bytes(), (two / "prompt.md").read_bytes())
        kit = gate.read_json(one / "kit.json")
        self.assertEqual((kit["K"], kit["target_h"]), (4, 205))
        self.assertIn("820 pixels tall (205 game pixels)", (one / "prompt.md").read_text())
        for ref in kit["refs"]:
            self.assertEqual((one / ref["file"]).read_bytes(), (two / ref["file"]).read_bytes())
            image = gate.rgba(one / ref["file"])
            self.assertEqual(gate.pixel_digest(image), ref["pixel_sha256"])
            self.assertTrue(np.all(np.asarray(image)[-32:] == [0, 255, 0, 255]))
            occupied = np.any(np.asarray(image)[..., :3] != [0, 255, 0], axis=-1)
            ys, xs = np.nonzero(occupied)
            self.assertLessEqual(abs(int(xs.min()) - (image.width - 1 - int(xs.max()))), 1)
            self.assertLessEqual(abs(int(ys.min()) - (image.height - 1 - int(ys.max()))), 1)

    def test_kit_rejects_noncanon_wrong_kind_and_missing_rear_front(self):
        for peers in (["arc_thrall", "harrier_front"], ["crag_outcrop", "raised_cover"]):
            with self.assertRaises(ValueError):
                gate.make_kit(self.kit_args(peers=peers))
        with self.assertRaisesRegex(ValueError, "front-ref"):
            gate.make_kit(self.kit_args(view="creature_rear"))

    def test_rear_front_reference_is_unchanged_and_peers_match_view(self):
        args = self.kit_args(view="creature_rear", front_ref=FIXTURES / "hero_front.png")
        kit = gate.make_kit(args)
        self.assertEqual((Path(args.out_dir) / "refs/01_front_ref.png").read_bytes(), args.front_ref.read_bytes())
        self.assertEqual([ref.get("canon_id") for ref in kit["refs"][1:]],
                         ["hero_rear", "harrier_rear", "grave_surgeon_rear"])

    def test_object_kit_guide_and_factor_boundary(self):
        args = self.kit_args(view="object_plinth", anatomy="plinth", peers=["crag_outcrop", "raised_cover"], size_class="large")
        kit = gate.make_kit(args)
        self.assertEqual(kit["K"], 3)
        image = gate.rgba(Path(args.out_dir) / "refs/footprint_guide.png")
        self.assertEqual(image.size, (1024, 1024))
        self.assertEqual(image.getpixel((512, 960))[:3], (40, 40, 40))
        for height, factor in ((225, 4), (226, 3)):
            self.assertEqual(gate.make_kit(self.kit_args(str(height), target_h=height))["K"], factor)

    def test_process_exact_k_size_placement_and_determinism(self):
        raw = Image.new("RGB", (1024, 1024), "#00ff00")
        ImageDraw.Draw(raw).rectangle((17, 19, 56, 98), fill=(70, 50, 40))
        source, kit = self.temp / "raw.png", self.temp / "kit.json"
        raw.save(source)
        gate.write_json(kit, {"K": 4, "kind": "creature", "anatomy": "biped"})
        record = gate.process_raw(source, kit, self.temp / "one.png")
        gate.process_raw(source, kit, self.temp / "two.png")
        self.assertEqual(record["drawn_size"], [10, 20])
        self.assertEqual((record["k_eff"], record["fit_scale"]), (4.0, 1.0))
        self.assertEqual(gate.alpha_bbox(gate.rgba(self.temp / "one.png")), (123, 226, 133, 246))
        self.assertEqual((self.temp / "one.png").read_bytes(), (self.temp / "two.png").read_bytes())
        self.assertEqual((self.temp / "one.json").read_bytes(), (self.temp / "two.json").read_bytes())
        self.assertEqual(set(np.asarray(gate.rgba(self.temp / "one.png"))[..., 3].flat), {0, 255})

    def test_process_matches_prototype_premultiplied_box(self):
        raw = Image.new("RGB", (1024, 1024), "#00ff00")
        draw = ImageDraw.Draw(raw)
        draw.rectangle((1, 1, 68, 86), fill=(60, 50, 40))
        path, kit = self.temp / "raw.png", self.temp / "kit.json"
        raw.save(path)
        gate.write_json(kit, {"K": 4})
        namespace = {"np": np, "Image": Image}
        prototype_functions("process.py", namespace)
        namespace["process"](path, 4, self.temp / "prototype.png")
        gate.process_raw(path, kit, self.temp / "current.png")
        self.assertEqual(gate.pixel_digest(gate.rgba(self.temp / "prototype.png")), gate.pixel_digest(gate.rgba(self.temp / "current.png")))

    def test_process_unmixes_key_blends_instead_of_olive_fringe(self):
        # Director fix 2026-10-12: bright paint blended with the key (e.g. (110, 222, 75)) used to despill to olive.
        raw = Image.new("RGB", (1024, 1024), "#00ff00")
        draw = ImageDraw.Draw(raw)
        draw.rectangle((100, 100, 199, 299), fill=(60, 50, 40))
        draw.rectangle((100, 100, 103, 299), fill=(110, 222, 75))  # one output column of mostly-key blend at the edge
        path, kit = self.temp / "raw.png", self.temp / "kit.json"
        raw.save(path)
        gate.write_json(kit, {"K": 4})
        gate.process_raw(path, kit, self.temp / "out.png")
        pixels = np.asarray(gate.rgba(self.temp / "out.png")).astype(int)
        visible = pixels[pixels[..., 3] > 0][:, :3]
        self.assertFalse(((np.abs(visible[:, 0] - visible[:, 1]) < 12) & (visible[:, 1] > visible[:, 2] + 20)).any())
        box = gate.alpha_bbox(gate.rgba(self.temp / "out.png"))
        self.assertEqual(box[2] - box[0], 24)

    def test_process_uniformly_fits_tall_sprite_without_clipping_paint(self):
        raw = Image.new("RGB", (1024, 1024), "#00ff00")
        draw = ImageDraw.Draw(raw)
        draw.rectangle((20, 10, 419, 509), fill=(60, 50, 40))
        draw.rectangle((20, 510, 419, 1009), fill=(80, 70, 60))
        path, kit = self.temp / "tall.png", self.temp / "kit.json"
        raw.save(path)
        gate.write_json(kit, {"K": 4})
        record = gate.process_raw(path, kit, self.temp / "out.png")
        self.assertEqual(record["fit_scale"], 0.96)
        self.assertEqual(record["drawn_size"], [96, 240])
        image = gate.rgba(self.temp / "out.png")
        self.assertEqual(gate.alpha_bbox(image), (80, 6, 176, 246))
        self.assertEqual(image.getpixel((128, 6)), (60, 50, 40, 255))
        self.assertEqual(image.getpixel((128, 245)), (80, 70, 60, 255))
        self.assertEqual(record["shift"], [0, 0])

    def test_process_uniformly_fits_wide_sprite(self):
        raw = Image.new("RGB", (1024, 1024), "#00ff00")
        draw = ImageDraw.Draw(raw)
        draw.rectangle((8, 20, 1015, 419), fill=(60, 50, 40))
        path, kit = self.temp / "wide.png", self.temp / "kit.json"
        raw.save(path)
        gate.write_json(kit, {"K": 4})
        record = gate.process_raw(path, kit, self.temp / "out.png")
        self.assertEqual(record["fit_scale"], 251 / 252)
        self.assertEqual(record["drawn_size"], [251, 100])
        image = gate.rgba(self.temp / "out.png")
        self.assertEqual(gate.alpha_bbox(image), (3, 146, 254, 246))
        pixels = np.asarray(image)
        self.assertTrue(np.all(pixels[pixels[..., 3] > 0] == [60, 50, 40, 255]))

    def test_fit_premultiplication_excludes_transparent_green(self):
        sprite = Image.new("RGBA", (252, 250), (0, 255, 0, 0))
        draw = ImageDraw.Draw(sprite)
        draw.rectangle((0, 0, 125, 249), fill=(60, 50, 40, 255))
        draw.rectangle((0, 125, 251, 249), fill=(60, 50, 40, 255))
        fitted, scale = gate.fit_sprite(sprite)
        self.assertEqual((fitted.size, scale), ((242, 240), 0.96))
        pixels = np.asarray(fitted)
        self.assertEqual(set(pixels[..., 3].flat), {0, 255})
        self.assertTrue(np.all(pixels[pixels[..., 3] > 0] == [60, 50, 40, 255]))

    def test_process_off_size_1280_canvas_uses_effective_factor(self):
        raw = Image.new("RGB", (1280, 1280), "#00ff00")
        ImageDraw.Draw(raw).rectangle((17, 19, 141, 268), fill=(60, 50, 40))
        path, kit = self.temp / "pilot.png", self.temp / "kit.json"
        raw.save(path)
        gate.write_json(kit, {"K": 4})
        record = gate.process_raw(path, kit, self.temp / "out.png")
        self.assertEqual((record["K"], record["k_eff"], record["fit_scale"]), (4, 5.0, 1.0))
        self.assertEqual(record["drawn_size"], [25, 50])
        self.assertEqual(gate.alpha_bbox(gate.rgba(self.temp / "out.png")), (116, 196, 141, 246))

    def test_process_noninteger_factor_and_nonsquare_rejection(self):
        raw = Image.new("RGB", (1254, 1254), "#00ff00")
        ImageDraw.Draw(raw).rectangle((20, 20, 508, 508), fill=(60, 50, 40))
        path, kit = self.temp / "pilot.png", self.temp / "kit.json"
        raw.save(path)
        gate.write_json(kit, {"K": 4})
        record = gate.process_raw(path, kit, self.temp / "out.png")
        self.assertEqual(record["k_eff"], 4.8984375)
        self.assertEqual(record["drawn_size"], [100, 100])
        raw.crop((0, 0, 1254, 1024)).save(path)
        with self.assertRaisesRegex(ValueError, "must be square"):
            gate.process_raw(path, kit, self.temp / "rejected.png")
        self.assertFalse((self.temp / "rejected.png").exists())

    def test_sheet_backdrop_uses_real_capture_and_slot_contract(self):
        root = self.minimal_root()
        directory = root / gate.IDENTITY / "backdrop"
        directory.mkdir()
        backdrop = Image.new("RGBA", (1920, 1080), "#14100c")
        backdrop.putpixel((0, 0), (1, 2, 3, 255))
        backdrop.save(directory / "empty_board.png")
        row = [{"centre": [160 + index * 320, 400], "screen_px_per_canvas_px": 0.634} for index in range(6)]
        gate.write_json(directory / "slots.json", {"rows": [row, row], "size": [1920, 1080], "ui_scale": 1.0})
        image, slots = gate.sheet_backdrop(root)
        self.assertEqual(image.getpixel((0, 0)), (1, 2, 3, 255))
        self.assertEqual(slots, row)

    def minimal_root(self):
        root = self.temp / "root"
        directory = root / gate.IDENTITY
        directory.mkdir(parents=True)
        for name in ("bands.json", "preamble.md", "views.md"):
            shutil.copyfile(ROOT / gate.IDENTITY / name, directory / name)
        gate.write_json(directory / "canon.json", {"entries": []})
        gate.write_json(root / "spec/assets/board_pixel_density/registry.json", {"entries": []})
        gate.write_json(root / "data/enemies.json", {"fixture": {"art_path": "assets/hero.png", "art_scale": 1.0}})
        (root / "assets").mkdir()
        shutil.copyfile(FIXTURES / "hero_front.png", root / "assets/hero.png")
        return root

    def test_committed_registry_and_strict_pending_warnings(self):
        report, failures = gate.check_registry()
        self.assertEqual(failures, 0, "\n".join(report))
        self.assertEqual(sum(line.startswith("WARN ") for line in report), 12)
        report, failures = gate.check_registry(strict=True)
        self.assertEqual(failures, 12)

    def test_changed_legacy_pixels_fail_and_readoption_refused(self):
        root = self.minimal_root()
        gate.adopt_legacy(root)
        self.assertEqual(gate.check_registry(root)[1], 0)
        image = gate.rgba(root / "assets/hero.png")
        image.putpixel((128, 128), (255, 0, 0, 255))
        image.save(root / "assets/hero.png")
        report, failures = gate.check_registry(root)
        self.assertEqual(failures, 1)
        self.assertTrue(any("pixel digest changed" in line for line in report))
        with self.assertRaises(ValueError):
            gate.adopt_legacy(root)

    def kit_registry(self):
        root = self.minimal_root()
        args = self.kit_args()
        kit = gate.make_kit(args)
        shutil.copytree(args.out_dir, root / "jobs/fixture")
        canon = gate.read_json(ROOT / gate.IDENTITY / "canon.json")
        gate.write_json(root / gate.IDENTITY / "canon.json", canon)
        for reference in canon["entries"]:
            target = root / reference["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / reference["path"], target)
        shutil.copyfile(FIXTURES / "hero_front.png", root / "jobs/fixture/sheet.png")
        measured = gate.measure(root / "assets/hero.png")
        entry = dict(id="fixture", path="assets/hero.png", entry_kind="kit", kind="creature", anatomy="biped", size_class="medium",
                     kit_path="jobs/fixture/kit.json", job_id=kit["job_id"], kit_version=kit["kit_version"],
                     prompt_path="jobs/fixture/prompt.md", raw_sha256="a" * 64, sheet_path="jobs/fixture/sheet.png",
                     pixel_sha256=gate.pixel_digest(gate.rgba(root / "assets/hero.png")), judge={"verdict": "PASS", "date": "2026-10-12"},
                     owner_approval="Test-only approval", landmarks={"far": [106, 209], "near": [160, 222]}, exceptions=[])
        bands = gate.read_json(root / gate.IDENTITY / "bands.json")
        for metric, band in gate.metric_bands(entry, bands).items():
            value = measured.get(metric, 1.0 if metric == "art_scale" else gate.lateral_axis(entry["landmarks"]))
            if not gate.in_band(value, band):
                entry["exceptions"].append({"metric": metric, "value": value, "reason": "Test-only canon calibration exception"})
        registry = {"entries": [entry]}
        for path, metadata in gate.coverage(root).items():
            if path != entry["path"]:
                registry["entries"].append(dict(metadata, path=path, entry_kind="legacy",
                                                 pixel_sha256=gate.pixel_digest(gate.rgba(root / path))))
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        return root, registry, entry

    def test_kit_entry_requires_judge_and_landmarks_and_hard_limits(self):
        root, registry, entry = self.kit_registry()
        report, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(report))
        del entry["judge"]["verdict"]
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        report, failures = gate.check_registry(root)
        self.assertGreater(failures, 0)
        self.assertTrue(any("judge requires PASS" in line for line in report))
        del entry["landmarks"]
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        self.assertTrue(any("lateral_axis=None" in line for line in gate.check_registry(root)[0]))
        entry["exceptions"] = [{"metric": "thin_rel", "value": 0.21, "reason": "Test"}]
        self.assertTrue(any("thin_rel" in line for line in gate.metric_failures(entry, {"thin_rel": 0.21}, gate.read_json(root / gate.IDENTITY / "bands.json"))))

    def test_kit_provenance_rejects_changed_prompt_refs_and_version(self):
        for change in ("prompt", "refs", "version"):
            with self.subTest(change=change):
                # Use isolated roots for each provenance failure.
                root, registry, entry = self.kit_registry()
                if change == "prompt":
                    (root / entry["prompt_path"]).write_text("Changed prompt")
                elif change == "refs":
                    path = next((root / "jobs/fixture/refs").glob("*.png"))
                    image = gate.rgba(path)
                    image.putpixel((0, 0), (0, 0, 0, 255))
                    image.save(path)
                else:
                    entry["kit_version"] = "b" * 64
                    gate.write_json(root / gate.IDENTITY / "registry.json", registry)
                self.assertGreater(gate.check_registry(root)[1], 0)
                shutil.rmtree(root)
                shutil.rmtree(self.temp / "kit")

    def test_coverage_missing_duplicate_and_unknown_id_fail(self):
        root = self.minimal_root()
        gate.adopt_legacy(root)
        registry = gate.read_json(root / gate.IDENTITY / "registry.json")
        legacy = next(e for e in registry["entries"] if e["entry_kind"] == "legacy")
        registry["entries"].remove(legacy)
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        self.assertTrue(any("missing registry entry" in line for line in gate.check_registry(root)[0]))
        registry["entries"] += [legacy, copy.deepcopy(legacy)]
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        self.assertTrue(any("duplicate" in line for line in gate.check_registry(root)[0]))
        self.assertGreater(gate.check_registry(root, entry_id="unknown")[1], 0)

    def test_sheet_synthetic_backdrop_front_rear_and_landmarks(self):
        args = self.kit_args()
        gate.make_kit(args)
        output = self.temp / "sheet.png"
        gate.make_sheet(FIXTURES / "hero_front.png", FIXTURES / "hero_front.png", Path(args.out_dir) / "kit.json", output,
                        landmarks={"far": [106, 209], "near": [160, 222]})
        image = gate.rgba(output)
        self.assertEqual(image.width, 3840)
        self.assertGreater(image.height, 1500)
        self.assertTrue(np.any(np.all(np.asarray(image)[..., :3] == [224, 72, 60], axis=-1)))

    def test_sheet_fit_scale_info_matches_bound_process_sidecar(self):
        args = self.kit_args()
        gate.make_kit(args)
        kit = Path(args.out_dir) / "kit.json"
        raw = Image.new("RGB", (1024, 1024), "#00ff00")
        ImageDraw.Draw(raw).rectangle((20, 10, 419, 1009), fill=(60, 50, 40))
        path, front = self.temp / "raw.png", self.temp / "front.png"
        raw.save(path)
        gate.process_raw(path, kit, front)
        calls = []
        original_draw = ImageDraw.Draw
        def recording_draw(*draw_args, **draw_kwargs):
            draw = original_draw(*draw_args, **draw_kwargs)
            original_text = draw.text
            def recording_text(position, text, *text_args, **text_kwargs):
                calls.append((text, text_kwargs.get("fill")))
                return original_text(position, text, *text_args, **text_kwargs)
            draw.text = recording_text
            return draw
        with patch.object(gate.ImageDraw, "Draw", side_effect=recording_draw):
            gate.make_sheet(front, None, kit, self.temp / "sheet.png")
        info_rows = [text for text, color in calls if "front.fit_scale" in text and color == "#c9a25e"]
        self.assertEqual(len(info_rows), 1)
        self.assertIn("0.9600", info_rows[0])
        self.assertTrue(info_rows[0].endswith("INFO"))
        image = gate.rgba(front)
        image.putpixel((128, 128), (1, 2, 3, 255))
        image.save(front)
        with self.assertRaisesRegex(ValueError, "sidecar pixel digest changed"):
            gate.processed_fit_scale(front)

    def test_canon_sheet_covers_both_views_objects_scales_and_exact_doubling(self):
        canon = gate.canon_entries(ROOT)
        for view in ("front", "rear"):
            with self.subTest(view=view):
                path = self.temp / ("canon-" + view + ".png")
                with patch.object(gate, "render_board_row", wraps=gate.render_board_row) as render:
                    ids = gate.make_canon_sheet(path, view)
                expected = {entry["id"] for entry in canon.values() if entry["kind"] == "object" or entry["view"] == view}
                self.assertEqual(set(ids), expected)
                self.assertEqual(len(ids), 20)
                self.assertTrue({"crag_outcrop", "raised_cover", "watch_brazier"}.issubset(ids))
                subjects = [subject for call in render.call_args_list for subject in call.args[2]]
                self.assertEqual([subject[2] for subject in subjects], ids)
                by_id = {label: (image, scale) for image, scale, label in subjects}
                self.assertEqual(by_id["crawler_" + view][1], 0.64)
                self.assertEqual(by_id["stone_warden_" + view][1], 1.18)
                for id, (image, _) in by_id.items():
                    self.assertEqual(gate.pixel_digest(image), gate.pixel_digest(gate.rgba(ROOT / canon[id]["path"])))
                output = gate.rgba(path)
                self.assertEqual(output.width, 3840)
                native_height = output.height // 3
                native = output.crop((0, 0, 1920, native_height))
                doubled = output.crop((0, native_height, 3840, output.height))
                self.assertEqual(gate.pixel_digest(doubled), gate.pixel_digest(native.resize(doubled.size, gate.RESAMPLE.NEAREST)))
                repeated = self.temp / ("canon-" + view + "-repeated.png")
                gate.make_canon_sheet(repeated, view)
                self.assertEqual(path.read_bytes(), repeated.read_bytes())
        args = gate.parser().parse_args(["canon-sheet", "--out", str(self.temp / "cli.png")])
        self.assertEqual(args.view, "front")

    def test_board_row_labels_survive_real_backdrop_crop(self):
        image = Image.new("RGBA", (1920, 1080), "#14100c")
        slots = [{"centre": [160 + index * 320, 400], "screen_px_per_canvas_px": 0.634} for index in range(6)]
        row = gate.render_board_row(image, slots, [(gate.rgba(FIXTURES / "hero_front.png"), 1.0, "hero_front")])
        label_pixels = np.asarray(row)[:32, :300, :3]
        self.assertTrue(np.any(np.any(label_pixels != [20, 16, 12], axis=-1)))


if __name__ == "__main__":
    unittest.main()
