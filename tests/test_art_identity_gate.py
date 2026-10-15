#!/usr/bin/env python3
"""Behavioral contracts for the director-owned visual identity gate."""
import argparse
import ast
import copy
import json
import os
import runpy
from pathlib import Path
import shutil
import subprocess
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
POST_STEP_FIXTURE_SEED = 103
POST_STEP_FIXTURE_SIDE = 32
POST_STEP_FIXTURE_RGB_MAX = 120
PAIR_FIXTURE_REAR_TONE = (150, 150, 150)
NON_ACCENT_FIXTURE_SIDE = 32
NON_ACCENT_FIXTURE_BODY = (60, 50, 40, 255)
NON_ACCENT_FIXTURE_ACCENT = (0, 180, 255, 255)
NON_ACCENT_FIXTURE_ACCENT_RECT = (2, 2, 10, 10)
MAQUETTE_FIXTURE_JOB_ID = "fixture-maquette-job"
MAQUETTE_FIXTURE_REF_LABELS = ("fixture_parts", "fixture_identity")
MAQUETTE_INVALID_ROLE = "unknown_role"
RAW_STEP_FIXTURE_ID = "fixture"
RAW_STEP_FRONT_JOB = gate.IDENTITY / "jobs/fixture/front"
RAW_STEP_FIXTURE_SEED = 105
RAW_STEP_FIXTURE_SIDE = 64
RAW_STEP_FIXTURE_EDIT_SIDE = 80
RAW_STEP_REFRESH_EDIT_RGBA = (190, 80, 60, 255)
RAW_STEP_CHANGED_REFERENCE_RGBA = (1, 2, 3, 255)
RAW_STEP_FIXTURE_BOX = [18, 12, 28, 36]
RAW_STEP_FIXTURE_REGION = {"name": "fixture wrap", "box": [16, 8, 48, 56], "seed": None,
                           "min_chroma": 0.1, "hue_deg": [340, 20], "lab_scale": [0.8, 0.7, 0.6]}
# Decoded goldens re-recorded from the passing art-05 byte goldens (2026-10-15).
# Independent of the thin wrappers and PNG encoder; exercise RGB conversion, LANCZOS and hue wrap.
RAW_STEP_LEGACY_PIXEL_SHA256 = {
    "raw": "ae3b017af374fcccf330e6d4ac041a8aa1ff57fa4a70b8436d333107d86c9373",
    "edit": "7a8f8a6f2ee780cdf7eca3d29bb5d637887cf7f561dc5b3dc544e461a2723dc2",
    "composite": "b45629935c7262a01286d68eb9f507f714ed176f1e388547b2c709ec9379be77",
    "tone": "d4a00b9a0a760afe2694c5c19e9d7c9e74f54341a0189b2cc10815c1f9578ad0",
    "mask": "77208bb9ad762fe2ab0785f24e8efec319748d70a0c7c16cfe3774128ada0234",
}
REENCODE_COMPRESSION_LEVEL = 0  # Proof-only zlib setting deliberately unlike Pillow's default.
TONE_LIMIT_FIXTURE_COLORS = ((110, 85, 65, 255), (240, 150, 30, 255), (240, 235, 230, 255))
TONE_LIMIT_FIXTURE_REGION = {"name": "brown body", "box": [0, 0, 3, 1], "max_chroma": 0.3,
                             "max_value": 0.8, "lab_scale": [0.7, 0.6, 0.6]}
CORE_FIXTURE_FRONT_BODY = (55, 50, 45, 255)
CORE_FIXTURE_REAR_BODY = (120, 80, 60, 255)
CORE_FIXTURE_PALE = (226, 201, 253, 255)
CORE_FIXTURE_ACCENT = (160, 30, 230, 255)
CORE_FIXTURE_DIM = (120, 100, 140, 255)
CORE_FIXTURE_SATURATED = (140, 100, 150, 255)
CORE_FIXTURE_GREEN = (90, 250, 90, 255)
CORE_FIXTURE_SIDE = 16
CORE_FIXTURE_XY = (2, 2)
CORE_FIXTURE_DIM_XY = (3, 2)
CORE_FIXTURE_SATURATED_XY = (4, 2)
CORE_FIXTURE_GREEN_XY = (5, 2)
HUE_FIXTURE_DEGREES = (335, 336, 0, 24, 25, 26, 334, 180)
DOMINANT_HUE_FIXTURE_COUNTS = {5: 40, 20: 5, 70: 4, 140: 51}
DOMINANT_HUE_FIXTURE_LAB = {"lightness": 50, "chroma": 80}
BODY_SHARE_FIXTURE_SIZE = (20, 1)
BODY_SHARE_FIXTURE_LIMIT_COUNT = 5
BODY_COVERAGE_PROOF_MAX_SHARE = 0.10
ASCII_STDOUT_FIXTURE_RAW = "r\u00e4w.png"
REAR_PALETTE_PROOF_JOBS = (
    ("frostglass_lancer", "mq1_front_v3", "mq1_rear_v3"),
    ("lightning_wisp", "mq1_front_v2", "mq1_rear_v2"),
)
BODY_COVERAGE_PROOF_JOBS = (
    ("chainbound_gaoler", "mq3_front_v4", "mq3_rear_v3"),
    ("frostglass_lancer", "mq1_front_v3", "mq1_rear_v3"),
    ("lightning_wisp", "mq1_front_v2", "mq1_rear"),
    ("lightning_wisp", "mq1_front_v2", "mq1_rear_v2"),
    # No approved bloomer rear exists: these are the review's front-as-rear stand-ins.
    ("shale_bloomer", "mq2_front", "mq2_front"),
    ("shale_bloomer", "mq3_front_v2", "mq3_front_v2"),
)
HISTORICAL_REPROCESS_INPUTS = (
    ("chainbound_gaoler", "mq3_rear", "mq3_rear_v3/refs/raw_approved.png"),
    ("frostglass_lancer", "mq1_rear", "mq1_rear_v3/refs/raw_approved.png"),
    ("lightning_wisp", "mq1_rear", "mq1_rear_v2/refs/01_wisp_mq1_rear_raw.png"),
)


def rear_palette_proof(out: Path) -> list:
    """Headless art-07 proof using disposable recipe copies; approved files are read-only."""
    reports = []
    for identity, front_job, rear_job in REAR_PALETTE_PROOF_JOBS:
        jobs = ROOT / gate.IDENTITY / "jobs" / identity
        folder = out / identity
        folder.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as scratch:
            copied = Path(scratch) / "rear"
            shutil.copytree(jobs / rear_job, copied)
            kit = gate.read_json(copied / "kit.json")
            kit.pop("match_reference", None)
            gate.write_json(copied / "kit.json", kit)
            gate.process_raw(None, copied / "kit.json", folder / "before.png")
        front = gate.rgba(jobs / front_job / "processed.png")
        front.save(folder / "front.png")
        before = gate.rgba(folder / "before.png")
        legacy = gate.palette_match(front, before, gate.LEGACY_PALETTE_MATCH_PARAMETERS)
        coverage = {}
        after = gate.palette_match(front, before, report=coverage)
        legacy.save(folder / "legacy.png")
        after.save(folder / "after.png")
        pixels, old, new = map(np.asarray, (before, legacy, after))
        lab = gate.to_lab(pixels[..., :3].astype(float))
        core = (pixels[..., 3] > 0) & (lab[..., 0] >= gate.PALETTE_MATCH_PARAMETERS["accent_lightness"])
        changed = np.any(old != pixels, axis=-1) & core
        # Sample the greatest RGB channel change among bright cores, with stable row-major ties.
        loss = lab[..., 0] - gate.to_lab(old[..., :3].astype(float))[..., 0]
        delta = np.abs(old[..., :3].astype(int) - pixels[..., :3].astype(int)).max(-1)
        y, x = np.unravel_index(np.where(core, delta, -1).argmax(), core.shape)
        reports.append({"id": identity, "bright_core_pixels": int(core.sum()),
                        "legacy_changed_core_pixels": int(changed.sum()),
                        "new_changed_core_pixels": int(np.any(new != pixels, axis=-1)[core].sum()),
                        "sample_xy": [int(x), int(y)], "before_rgb": pixels[y, x, :3].tolist(),
                        "legacy_rgb": old[y, x, :3].tolist(), "after_rgb": new[y, x, :3].tolist(),
                        "max_legacy_channel_change": int(delta[y, x]),
                        "max_legacy_lightness_loss": float(loss[core].max()),
                        "parameters": gate.PALETTE_MATCH_PARAMETERS, **coverage})
    gate.write_json(out / "results.json", reports)
    return reports


def protected_share_proof(out: Path) -> list:
    reports = []
    for identity, front_job, rear_job in BODY_COVERAGE_PROOF_JOBS:
        jobs = ROOT / gate.IDENTITY / "jobs" / identity
        front, rear = (gate.rgba(jobs / job / "processed.png") for job in (front_job, rear_job))
        kit_path = jobs / rear_job / "kit.json"
        binding = gate.read_json(kit_path).get("match_reference")
        if binding is not None:
            front, _ = gate.derive_match_reference(binding, kit_path)
        report = {"id": identity, "front_job": front_job, "rear_job": rear_job,
                  "stand_in": front_job == rear_job, "front_masked": binding is not None and "derived_from" in binding}
        gate.palette_match(front, rear, report=report)
        reports.append(report)
    gate.write_json(out / "body-coverage.json", reports)
    return reports


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
                    peers=["arc_thrall_front", "grave_surgeon_front"], front_ref=None, target_h=None, target_w=None,
                    out_dir=str(self.temp / folder))
        args.update(overrides)
        return argparse.Namespace(**args)

    def raw_step_kit(self, folder=None):
        folder = folder or self.temp / "mq_recipe"
        refs = folder / "refs"
        refs.mkdir(parents=True, exist_ok=True)
        rng = np.random.default_rng(RAW_STEP_FIXTURE_SEED)
        pixels = np.zeros((RAW_STEP_FIXTURE_SIDE, RAW_STEP_FIXTURE_SIDE, 3), dtype=np.uint8)
        pixels[:] = [0, 255, 0]
        pixels[8:56, 16:48] = rng.integers(20, 150, (48, 32, 3), dtype=np.uint8)
        edit = Image.fromarray(rng.integers(0, 220, (RAW_STEP_FIXTURE_EDIT_SIDE, RAW_STEP_FIXTURE_EDIT_SIDE, 4), dtype=np.uint8))
        raw = Image.fromarray(pixels)
        composite = gate.composite_region(raw, edit, RAW_STEP_FIXTURE_BOX)
        tone = gate.tone_region(composite, [RAW_STEP_FIXTURE_REGION])
        for name, image in (("raw", raw), ("edit", edit), ("composite", composite), ("tone", tone)):
            image.save(refs / (name + ".png"))
        for name in ("tone", "mask"):
            gate.write_json(refs / (name + ".json"), [RAW_STEP_FIXTURE_REGION])

        def binding(name):
            return {"path": "refs/" + name, "sha256": gate.sha((refs / name).read_bytes())}

        kit_path = folder / "kit.json"
        kit = gate.read_json(kit_path) if kit_path.exists() else {"K": 4, "kit_kind": "maquette", "id": RAW_STEP_FIXTURE_ID}
        kit["raw_steps"] = [
            {"kind": "composite_region", "inputs": {"raw": binding("raw.png"), "edit": binding("edit.png")},
             "parameters": {"box": RAW_STEP_FIXTURE_BOX, "resample": "LANCZOS"},
             "output_raw_pixel_sha256": gate.pixel_digest(composite)},
            {"kind": "tone_region", "inputs": {"raw": {"previous_output_pixel_sha256": gate.pixel_digest(composite)},
                                                "config": binding("tone.json")},
             "parameters": {"space": "CIE Lab"}, "output_raw_pixel_sha256": gate.pixel_digest(tone)},
        ]
        kit["match_reference"] = {"path": "refs/tone.png", "pixel_sha256": gate.pixel_digest(tone)}
        gate.write_json(kit_path, kit)
        return kit_path

    def test_raw_step_pixels_match_legacy_scripts_and_wrappers(self):
        kit_path = self.raw_step_kit()
        refs = kit_path.parent / "refs"
        for name in ("raw", "edit", "composite", "tone"):
            self.assertEqual(gate.pixel_digest(gate.rgba(refs / (name + ".png"))), RAW_STEP_LEGACY_PIXEL_SHA256[name])
        masked = gate.mask_reference(gate.rgba(refs / "tone.png"), [RAW_STEP_FIXTURE_REGION])
        self.assertEqual(gate.pixel_digest(masked), RAW_STEP_LEGACY_PIXEL_SHA256["mask"])
        wrappers = [
            ("maquettes/chainbound_gaoler/composite_chain.py", [refs / "raw.png", refs / "edit.png"],
             "composite", list(map(str, RAW_STEP_FIXTURE_BOX))),
            ("prototype/tone_region.py", [refs / "composite.png"], "tone", [refs / "tone.json"]),
            ("prototype/mask_reference.py", [refs / "tone.png"], "mask", [refs / "mask.json"]),
        ]
        for script, inputs, name, suffix in wrappers:
            out = self.temp / (name + ".png")
            result = subprocess.run([sys.executable, str(ROOT / gate.IDENTITY / script),
                                     *map(str, inputs), str(out), *map(str, suffix)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(gate.pixel_digest(gate.rgba(out)), RAW_STEP_LEGACY_PIXEL_SHA256[name])

    def test_composite_resizes_edit_and_preserves_outside_box(self):
        kit_path = self.raw_step_kit()
        refs = kit_path.parent / "refs"
        raw, edit = gate.rgba(refs / "raw.png"), gate.rgba(refs / "edit.png")
        actual = gate.composite_region(raw, edit, RAW_STEP_FIXTURE_BOX)
        self.assertEqual(actual.mode, "RGB")
        x0, y0, x1, y1 = RAW_STEP_FIXTURE_BOX
        expected_edit = edit.convert("RGB").resize(raw.size, gate.RESAMPLE.LANCZOS)
        self.assertEqual(actual.crop((x0, y0, x1, y1)).tobytes(), expected_edit.crop((x0, y0, x1, y1)).tobytes())
        outside = np.ones((raw.height, raw.width), dtype=bool)
        outside[y0:y1, x0:x1] = False
        np.testing.assert_array_equal(np.asarray(actual)[outside], np.asarray(raw.convert("RGB"))[outside])

    def test_region_hue_wrap_and_seed_connectivity(self):
        colors = np.array([[[200, 20, 30], [200, 30, 20], [20, 200, 20], [20, 20, 200]]], dtype=float)
        region = dict(RAW_STEP_FIXTURE_REGION, box=[0, 0, 4, 1])
        np.testing.assert_array_equal(gate.region_mask(colors, region), [[True, True, False, False]])
        colors = np.full((5, 5, 3), [0, 255, 0], dtype=float)
        colors[1, 1] = colors[2, 2] = colors[4, 4] = [200, 20, 30]
        region.update(box=[0, 0, 5, 5], seed=[1, 1])
        hits = gate.region_mask(colors, region)
        self.assertEqual(np.argwhere(hits).tolist(), [[1, 1], [2, 2]])
        region["seed"] = [0, 0]
        with self.assertRaisesRegex(ValueError, "not a matching pixel"):
            gate.region_mask(colors, region)

    def test_raw_steps_replay_process_and_check_are_deterministic_and_read_only(self):
        kit_path = self.raw_step_kit()
        self.assertEqual(gate.pixel_digest(gate.replay_raw_steps(kit_path)), RAW_STEP_LEGACY_PIXEL_SHA256["tone"])
        (kit_path.parent / "refs/composite.png").unlink()  # The second raw comes from memory.
        out = kit_path.parent / "processed.png"
        one = gate.process_raw(None, kit_path, out, outline=True)
        two = gate.process_raw(None, kit_path, self.temp / "repeat.png", outline=True)
        self.assertEqual(one, two)
        self.assertEqual(out.read_bytes(), (self.temp / "repeat.png").read_bytes())
        before = {p: p.read_bytes() for p in kit_path.parent.rglob("*") if p.is_file()}
        self.assertEqual(len(gate.verify_job_recipe(kit_path)), 3)
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        with self.assertRaisesRegex(ValueError, "supplied raw differs"):
            gate.process_raw(kit_path.parent / "refs/edit.png", kit_path, out)

    def test_tone_max_chroma_excludes_amber_while_toning_brown(self):
        image = Image.fromarray(np.array([TONE_LIMIT_FIXTURE_COLORS], dtype=np.uint8))
        region = dict(TONE_LIMIT_FIXTURE_REGION)
        region.pop("max_value")
        actual = np.asarray(gate.tone_region(image, [region]))
        self.assertFalse(np.array_equal(actual[0, 0], np.asarray(image)[0, 0]))
        np.testing.assert_array_equal(actual[0, 1], TONE_LIMIT_FIXTURE_COLORS[1])
        # Bright neutral paint is low chroma; max_value independently excludes it.
        self.assertFalse(np.array_equal(actual[0, 2], np.asarray(image)[0, 2]))
        actual = np.asarray(gate.tone_region(image, [TONE_LIMIT_FIXTURE_REGION]))
        np.testing.assert_array_equal(actual[0, 1:], np.asarray(image)[0, 1:])
        np.testing.assert_array_equal(actual[..., 3], np.asarray(image)[..., 3])

    def test_region_maximum_filters_are_inclusive_and_validate_limits(self):
        colors = np.array([TONE_LIMIT_FIXTURE_COLORS], dtype=float)[..., :3]
        base = {"name": "limit boundary", "box": [0, 0, 3, 1]}
        for key, limit in (("max_chroma", (110 - 65) / 255), ("max_value", 110 / 255)):
            with self.subTest(key=key):
                self.assertTrue(gate.region_mask(colors, dict(base, **{key: limit}))[0, 0])
                self.assertFalse(gate.region_mask(colors, dict(base, **{key: float(np.nextafter(limit, 0))}))[0, 0])
                for invalid in (-0.1, 1.1, float("nan"), float("inf"), None, True, "0.3"):
                    with self.subTest(invalid=invalid), self.assertRaisesRegex(ValueError, key):
                        gate.region_mask(colors, dict(base, **{key: invalid}))
        np.testing.assert_array_equal(gate.region_mask(colors, base),
                                      gate.region_mask(colors, dict(base, max_chroma=1, max_value=1)))

    def test_region_all_limits_are_finite_unit_numbers_and_ordered(self):
        colors = np.array([TONE_LIMIT_FIXTURE_COLORS], dtype=float)[..., :3]
        base = {"name": "validated limits", "box": [0, 0, 3, 1]}
        for key in ("min_lum", "max_lum", "min_chroma", "max_chroma", "max_value"):
            for invalid in (-0.1, 1.1, float("nan"), float("inf"), -float("inf"), None, True, False, "0.3"):
                with self.subTest(key=key, invalid=invalid), self.assertRaisesRegex(ValueError, key):
                    gate.region_mask(colors, dict(base, **{key: invalid}))
            for valid in (0, 0.5, 1):
                gate.region_mask(colors, dict(base, **{key: valid}))
        for lower, upper in (("min_lum", "max_lum"), ("min_chroma", "max_chroma")):
            with self.subTest(lower=lower), self.assertRaisesRegex(ValueError, lower + " must not exceed " + upper):
                gate.region_mask(colors, dict(base, **{lower: 0.6, upper: 0.5}))
            gate.region_mask(colors, dict(base, **{lower: 0.5, upper: 0.5}))

    def test_palette_match_preserves_pale_cores_and_reference_accent_hues(self):
        front = Image.new("RGBA", (CORE_FIXTURE_SIDE, CORE_FIXTURE_SIDE), CORE_FIXTURE_FRONT_BODY)
        rear = Image.new("RGBA", front.size, CORE_FIXTURE_REAR_BODY)
        front.putpixel(CORE_FIXTURE_XY, CORE_FIXTURE_ACCENT)
        rear.putpixel(CORE_FIXTURE_XY, CORE_FIXTURE_PALE)
        rear.putpixel(CORE_FIXTURE_DIM_XY, CORE_FIXTURE_DIM)
        rear.putpixel(CORE_FIXTURE_SATURATED_XY, CORE_FIXTURE_SATURATED)
        pixels = np.asarray(rear).astype(float)
        lab = gate.to_lab(pixels[..., :3])
        body = gate.non_accent_mask(lab, pixels[..., 3])
        for x, y in (CORE_FIXTURE_XY, CORE_FIXTURE_DIM_XY, CORE_FIXTURE_SATURATED_XY):
            self.assertTrue(body[y, x])  # These were transferred by the old rule.
        self.assertLess(lab[CORE_FIXTURE_DIM_XY[1], CORE_FIXTURE_DIM_XY[0], 0], 80)
        legacy = gate.palette_match(front, rear, gate.LEGACY_PALETTE_MATCH_PARAMETERS)
        actual = gate.palette_match(front, rear)
        for xy in (CORE_FIXTURE_XY, CORE_FIXTURE_SATURATED_XY):
            self.assertNotEqual(legacy.getpixel(xy), rear.getpixel(xy))
            self.assertEqual(actual.getpixel(xy), rear.getpixel(xy))
        self.assertNotEqual(actual.getpixel(CORE_FIXTURE_DIM_XY), CORE_FIXTURE_DIM)
        self.assertNotEqual(actual.getpixel((0, 0)), rear.getpixel((0, 0)))
        # Bright protection also works with no chromatic accents in the reference.
        front.putpixel(CORE_FIXTURE_XY, CORE_FIXTURE_FRONT_BODY)
        self.assertEqual(gate.palette_match(front, rear).getpixel(CORE_FIXTURE_XY), CORE_FIXTURE_PALE)
        front.putpixel(CORE_FIXTURE_XY, (*CORE_FIXTURE_ACCENT[:3], 0))
        self.assertNotEqual(gate.palette_match(front, rear).getpixel(CORE_FIXTURE_DIM_XY), CORE_FIXTURE_DIM)
        np.testing.assert_array_equal(np.asarray(actual)[..., 3], np.asarray(rear)[..., 3])

    def test_palette_accent_hue_wrap_boundaries_and_lightness_boundary(self):
        radians = np.radians(HUE_FIXTURE_DEGREES)
        lab = np.stack((np.zeros_like(radians), np.cos(radians), np.sin(radians)), -1)
        protected = gate.palette_accent_protection(lab, np.array([0.0]), gate.PALETTE_MATCH_PARAMETERS)
        np.testing.assert_array_equal(protected, [True, True, True, True, True, False, False, False])
        lab[:, 0] = 80
        self.assertTrue(gate.palette_accent_protection(lab, np.array([]), gate.PALETTE_MATCH_PARAMETERS).all())
        lab[:, 0] = np.nextafter(80.0, 0)
        self.assertFalse(gate.palette_accent_protection(lab, np.array([]), gate.PALETTE_MATCH_PARAMETERS).any())

    def test_palette_match_all_bright_pixels_has_no_body_to_transfer(self):
        bright = Image.new("RGBA", (CORE_FIXTURE_SIDE, CORE_FIXTURE_SIDE), CORE_FIXTURE_PALE)
        body = Image.new("RGBA", bright.size, CORE_FIXTURE_REAR_BODY)
        for front, rear, shares in ((bright, body, {"front": 1.0, "rear": 0.0}),
                                    (body, bright, {"front": 0.0, "rear": 1.0}),
                                    (bright, bright, {"front": 1.0, "rear": 1.0})):
            with self.assertRaisesRegex(ValueError, "body is empty.*--allow-protected-share"):
                gate.palette_match(front, rear)
            report = {}
            actual = gate.palette_match(front, rear, dict(gate.PALETTE_MATCH_PARAMETERS, allow_protected_share=True), report)
            self.assertEqual(actual.tobytes(), rear.tobytes())
            self.assertEqual(report, {"kind": "palette_match", "skipped": "empty body",
                                      "protected_share": shares, "protected_body_share": shares})
            # The old recorded v1 algorithm remains available for exact historical replay.
            self.assertEqual(gate.palette_match(front, rear, gate.ART07_V1_PALETTE_MATCH_PARAMETERS).tobytes(), rear.tobytes())

    def test_dominant_accent_hues_use_pixel_weighted_bins_with_inclusive_five_percent(self):
        hues = np.array([hue for hue, count in DOMINANT_HUE_FIXTURE_COUNTS.items() for _ in range(count)])
        radians = np.radians(hues)
        lab = np.stack((np.full_like(radians, DOMINANT_HUE_FIXTURE_LAB["lightness"]),
                        np.cos(radians) * DOMINANT_HUE_FIXTURE_LAB["chroma"],
                        np.sin(radians) * DOMINANT_HUE_FIXTURE_LAB["chroma"]), -1)
        actual = gate.dominant_accent_hues(lab, np.ones(hues.shape, dtype=bool), gate.PALETTE_MATCH_PARAMETERS)
        np.testing.assert_array_equal(actual, [7.5, 22.5, 142.5])
        self.assertEqual(gate.dominant_accent_hues(lab, np.zeros(hues.shape, dtype=bool), gate.PALETTE_MATCH_PARAMETERS).size, 0)

    def test_hue_protection_requires_absolute_chroma_floor_and_own_percentile(self):
        parameters = gate.PALETTE_MATCH_PARAMETERS
        for chroma, expected in (([10.0] * 18 + [30.0, 29.999], [False] * 18 + [True, False]),
                                 ([60.0] * 19 + [55.0], [True] * 19 + [False])):
            lab = np.stack((np.full(len(chroma), 50.0), chroma, np.zeros(len(chroma))), -1)
            rgb = np.full(lab.shape, 100.0)  # Neutral RGB isolates the Lab hue/chroma rule.
            result = gate.bounded_accent_protection(rgb, lab, np.ones(len(chroma), bool), np.array([0.0]), parameters)
            np.testing.assert_array_equal(result, expected)

    def test_bright_green_key_residue_is_not_protected(self):
        front = Image.new("RGBA", (CORE_FIXTURE_SIDE, CORE_FIXTURE_SIDE), CORE_FIXTURE_FRONT_BODY)
        rear = Image.new("RGBA", front.size, CORE_FIXTURE_REAR_BODY)
        front.putpixel(CORE_FIXTURE_GREEN_XY, CORE_FIXTURE_GREEN)
        rear.putpixel(CORE_FIXTURE_GREEN_XY, CORE_FIXTURE_GREEN)
        self.assertGreater(gate.to_lab(np.array(CORE_FIXTURE_GREEN[:3], dtype=float))[0], 80)
        actual = gate.palette_match(front, rear)
        self.assertEqual(actual.getpixel(CORE_FIXTURE_GREEN_XY), (90, 90, 90, 255))
        # This assertion catches M6: allowing bright green to skip residue cleanup.
        self.assertNotEqual(actual.getpixel(CORE_FIXTURE_GREEN_XY), CORE_FIXTURE_GREEN)

    def test_protected_body_guard_is_inclusive_and_applies_to_both_images(self):
        body = Image.new("RGBA", BODY_SHARE_FIXTURE_SIZE, CORE_FIXTURE_REAR_BODY)
        for count in (BODY_SHARE_FIXTURE_LIMIT_COUNT, BODY_SHARE_FIXTURE_LIMIT_COUNT + 1):
            protected = body.copy()
            for x in range(count):
                protected.putpixel((x, 0), CORE_FIXTURE_PALE)
            for front, rear, label in ((protected, body, "front"), (body, protected, "rear")):
                with self.subTest(count=count, label=label):
                    if count == BODY_SHARE_FIXTURE_LIMIT_COUNT:
                        gate.palette_match(front, rear)
                    else:
                        with self.assertRaisesRegex(ValueError, label + " body: 30.0% protected.*--allow-protected-share"):
                            gate.palette_match(front, rear)
                        gate.palette_match(front, rear, dict(gate.PALETTE_MATCH_PARAMETERS, allow_protected_share=True))

    def test_lancer_and_wisp_rear_match_preserves_bright_cores_on_copies(self):
        for report in rear_palette_proof(self.temp / "proof"):
            with self.subTest(identity=report["id"]):
                self.assertGreater(report["bright_core_pixels"], 0)
                self.assertGreater(report["legacy_changed_core_pixels"], 0)
                self.assertEqual(report["new_changed_core_pixels"], 0)
                self.assertEqual(report["after_rgb"], report["before_rgb"])
                self.assertNotEqual(report["legacy_rgb"], report["before_rgb"])
                for share in report["protected_body_share"].values():
                    self.assertLessEqual(share, BODY_COVERAGE_PROOF_MAX_SHARE)

    def test_real_bodies_keep_at_least_ninety_percent_of_transfer_samples(self):
        for report in protected_share_proof(self.temp):
            with self.subTest(identity=report["id"], rear=report["rear_job"]):
                for share in report["protected_body_share"].values():
                    self.assertGreater(share, 0)
                    self.assertLessEqual(share, BODY_COVERAGE_PROOF_MAX_SHARE)

    def test_raw_steps_reject_changed_file_bytes_for_every_input_kind(self):
        kit_path = self.raw_step_kit()
        for name in ("raw.png", "edit.png", "tone.json"):
            with self.subTest(input=name):
                path = kit_path.parent / "refs" / name
                original = path.read_bytes()
                path.write_bytes(original + b"\n")  # Valid PNG/JSON, identical decoded data, changed file digest.
                with self.assertRaisesRegex(ValueError, "input sha256 changed"):
                    gate.replay_raw_steps(kit_path)
                path.write_bytes(original)

    def test_raw_steps_reject_output_chain_and_parameter_tampering(self):
        kit_path = self.raw_step_kit()
        original = gate.read_json(kit_path)
        for change, error in (("output", "output_raw_pixel_sha256 changed"), ("chain", "previous output"),
                              ("kind", "unknown kind"), ("parameters", "invalid composite_region parameters")):
            with self.subTest(change=change):
                kit = copy.deepcopy(original)
                if change == "output": kit["raw_steps"][-1]["output_raw_pixel_sha256"] = "0" * 64
                elif change == "chain": kit["raw_steps"][0]["output_raw_pixel_sha256"] = "0" * 64
                elif change == "kind": kit["raw_steps"][0]["kind"] = "unknown"
                else: kit["raw_steps"][0]["parameters"]["resample"] = "NEAREST"
                gate.write_json(kit_path, kit)
                with self.assertRaisesRegex(ValueError, error):
                    gate.replay_raw_steps(kit_path)

    def test_composite_rejects_extra_parameters_and_out_of_bounds_boxes(self):
        kit_path = self.raw_step_kit()
        original = gate.read_json(kit_path)
        mutations = [({"extra": True}, "invalid composite_region parameters")]
        for box in ([0, 0, RAW_STEP_FIXTURE_SIDE + 1, 1], [0, 0, 1, RAW_STEP_FIXTURE_SIDE + 1]):
            mutations.append(({"box": box}, "box exceeds approved raw"))
        for box in ([-1, 0, 1, 1], [0, -1, 1, 1], [1, 0, 1, 1], [0, 1, 1, 1], [0, 0, 1.0, 1]):
            mutations.append(({"box": box}, "invalid composite_region parameters"))
        for parameters, expected in mutations:
            with self.subTest(parameters=parameters):
                kit = copy.deepcopy(original)
                kit["raw_steps"][0]["parameters"].update(parameters)
                gate.write_json(kit_path, kit)
                with self.assertRaisesRegex(ValueError, expected):
                    gate.replay_raw_steps(kit_path)

    def test_legacy_output_byte_fields_require_rerecording(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        kit["raw_steps"][0]["output_raw_sha256"] = kit["raw_steps"][0]["output_raw_pixel_sha256"]
        for keep_pixel_field in (True, False):
            if not keep_pixel_field:
                kit["raw_steps"][0].pop("output_raw_pixel_sha256")
            gate.write_json(kit_path, kit)
            with self.subTest(keep_pixel_field=keep_pixel_field), self.assertRaisesRegex(ValueError, "re-record legacy byte digests"):
                gate.replay_raw_steps(kit_path)

    def test_record_steps_cli_migrates_legacy_digests_and_is_idempotent(self):
        kit_path = self.raw_step_kit()
        expected = gate.read_json(kit_path)
        refs = kit_path.parent / "refs"
        # Inputs are file-bound, so even an encoding/whitespace-only change needs recording.
        gate.rgba(refs / "raw.png").save(refs / "raw.png", compress_level=REENCODE_COMPRESSION_LEVEL)
        (refs / "tone.json").write_bytes((refs / "tone.json").read_bytes() + b"\n")
        legacy = copy.deepcopy(expected)
        for step in legacy["raw_steps"]:
            step["output_raw_sha256"] = "0" * 64
            step.pop("output_raw_pixel_sha256")
            for binding in step["inputs"].values():
                binding.pop("sha256", None)
        legacy["raw_steps"][1]["inputs"]["raw"] = {"path": "refs/composite.png", "sha256": "0" * 64}
        legacy["match_reference"] = {"path": "refs/tone.png", "sha256": "0" * 64}
        gate.write_json(kit_path, legacy)
        for step in expected["raw_steps"]:
            for binding in step["inputs"].values():
                if "path" in binding:
                    binding["sha256"] = gate.sha((kit_path.parent / binding["path"]).read_bytes())
        inputs = {path: path.read_bytes() for path in refs.iterdir()}
        command = [sys.executable, str(ROOT / "tools/art_identity_gate.py"), "record-steps", "--kit", str(kit_path)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('+      "output_raw_pixel_sha256"', result.stdout)
        self.assertIn('-      "output_raw_sha256"', result.stdout)
        self.assertIn('"sha256"', result.stdout)
        for name in ("composite.png", "tone.png"):
            self.assertIn("INPUT CHANGED refs/%s %s->%s" % (name, "0" * 64, gate.sha((refs / name).read_bytes())), result.stdout)
        self.assertEqual(gate.read_json(kit_path), expected)
        self.assertEqual(gate.pixel_digest(gate.replay_raw_steps(kit_path)), RAW_STEP_LEGACY_PIXEL_SHA256["tone"])
        self.assertEqual({path: path.read_bytes() for path in refs.iterdir()}, inputs)
        recorded = kit_path.read_bytes()
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "UNCHANGED " + str(kit_path) + "\n")
        self.assertEqual(kit_path.read_bytes(), recorded)
        (refs / "raw.png").unlink()
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("input missing", result.stderr)
        self.assertEqual(kit_path.read_bytes(), recorded)

    def test_record_steps_refreshes_all_outputs_and_previous_output_links(self):
        kit_path = self.raw_step_kit()
        refs = kit_path.parent / "refs"
        edit = gate.rgba(refs / "edit.png")
        edit.paste(RAW_STEP_REFRESH_EDIT_RGBA, (0, 0, edit.width, edit.height))
        edit.save(refs / "edit.png")
        composite = gate.composite_region(gate.rgba(refs / "raw.png"), edit, RAW_STEP_FIXTURE_BOX)
        tone = gate.tone_region(composite, [RAW_STEP_FIXTURE_REGION])
        gate.record_steps(kit_path)
        kit = gate.read_json(kit_path)
        self.assertEqual(kit["raw_steps"][0]["output_raw_pixel_sha256"], gate.pixel_digest(composite))
        self.assertEqual(kit["raw_steps"][1]["inputs"]["raw"], {"previous_output_pixel_sha256": gate.pixel_digest(composite)})
        self.assertEqual(kit["raw_steps"][1]["output_raw_pixel_sha256"], gate.pixel_digest(tone))
        self.assertNotEqual(gate.pixel_digest(tone), RAW_STEP_LEGACY_PIXEL_SHA256["tone"])
        self.assertEqual(gate.pixel_digest(gate.replay_raw_steps(kit_path)), gate.pixel_digest(tone))

    def test_record_steps_reports_changed_valid_input_hashes_separately_from_migration(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        refs = kit_path.parent / "refs"
        # Valid existing hashes must be audited for both step inputs and mask configs.
        front = self.temp / RAW_STEP_FRONT_JOB
        gate.write_json(front / "kit.json", {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID})
        shutil.copyfile(refs / "tone.png", front / "processed.png")
        kit["match_reference"] = {
            "derived_from": {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json")},
            "mask_config": {"path": "refs/mask.json", "sha256": gate.sha((refs / "mask.json").read_bytes())},
        }
        expected = []
        for binding in (kit["raw_steps"][0]["inputs"]["raw"], kit["raw_steps"][1]["inputs"]["config"],
                        kit["match_reference"]["mask_config"]):
            path = kit_path.parent / binding["path"]
            old = binding["sha256"]
            if path.suffix == ".png":
                gate.rgba(path).save(path, compress_level=REENCODE_COMPRESSION_LEVEL)
            else:
                path.write_bytes(path.read_bytes() + b"\n")
            expected.append("INPUT CHANGED %s %s->%s" % (binding["path"], old, gate.sha(path.read_bytes())))
        # An absent/invalid hash is migration, not a changed existing binding.
        kit["raw_steps"][0]["inputs"]["edit"].pop("sha256")
        gate.write_json(kit_path, kit)
        # Recording must use explicit UTF-8 bytes, even on hosts that translate text newlines.
        with patch.object(Path, "write_text", side_effect=AssertionError("record-steps must write bytes")):
            lines = gate.record_steps(kit_path, self.temp)
        self.assertEqual([line for line in lines if line.startswith("INPUT CHANGED ")], expected)
        self.assertNotIn(b"\r", kit_path.read_bytes())
        self.assertEqual(gate.record_steps(kit_path, self.temp), ["UNCHANGED " + str(kit_path)])

    def test_record_steps_refreshes_plain_and_masked_front_job_bindings(self):
        kit_path = self.raw_step_kit()
        front = self.temp / RAW_STEP_FRONT_JOB
        gate.write_json(front / "kit.json", {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID})
        shutil.copyfile(kit_path.parent / "refs/tone.png", front / "processed.png")
        kit = gate.read_json(kit_path)
        for masked in (False, True):
            with self.subTest(masked=masked):
                binding = {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json")}
                if masked:
                    binding["pixel_sha256"] = "0" * 64
                kit["match_reference"] = ({"derived_from": binding,
                    "mask_config": {"path": "refs/mask.json", "sha256": "0" * 64}} if masked else binding)
                gate.write_json(kit_path, kit)
                changes = gate.record_steps(kit_path, self.temp)
                self.assertIn('"pixel_sha256"', "\n".join(changes))
                recorded = gate.read_json(kit_path)["match_reference"]
                self.assertEqual((recorded["derived_from"] if masked else recorded)["pixel_sha256"],
                                 RAW_STEP_LEGACY_PIXEL_SHA256["tone"])
                if masked:
                    self.assertEqual(recorded["mask_config"]["sha256"], gate.sha((kit_path.parent / "refs/mask.json").read_bytes()))
                image, _ = gate.derive_match_reference(recorded, kit_path, self.temp)
                self.assertEqual(gate.pixel_digest(image), RAW_STEP_LEGACY_PIXEL_SHA256["mask" if masked else "tone"])

    def test_record_steps_missing_inputs_never_partially_write_kit(self):
        kit_path = self.raw_step_kit()
        front = self.temp / RAW_STEP_FRONT_JOB
        gate.write_json(front / "kit.json", {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID})
        shutil.copyfile(kit_path.parent / "refs/tone.png", front / "processed.png")
        kit = gate.read_json(kit_path)
        kit["raw_steps"][0]["output_raw_pixel_sha256"] = "0" * 64
        kit["match_reference"] = {"derived_from": {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json")},
                                  "mask_config": {"path": "refs/mask.json"}}
        paths = [kit_path.parent / "refs" / name for name in ("raw.png", "edit.png", "tone.json", "mask.json")]
        paths += [front / "kit.json", front / "processed.png"]
        for maquette in (True, False):
            kit["kit_kind"] = "maquette" if maquette else "standard"
            gate.write_json(kit_path, kit)
            original = kit_path.read_bytes()
            for path in paths:
                with self.subTest(maquette=maquette, missing=path.name):
                    data = path.read_bytes()
                    path.unlink()
                    with self.assertRaises((OSError, ValueError)):
                        gate.record_steps(kit_path, self.temp)
                    self.assertEqual(kit_path.read_bytes(), original)
                    path.write_bytes(data)

    def test_record_steps_rejects_unsafe_paths_invalid_parameters_and_broken_legacy_chain(self):
        kit_path = self.raw_step_kit()
        original = gate.read_json(kit_path)
        for change in ("path", "parameters", "chain"):
            with self.subTest(change=change):
                kit = copy.deepcopy(original)
                if change == "path":
                    kit["raw_steps"][0]["inputs"]["raw"]["path"] = "../raw.png"
                elif change == "parameters":
                    kit["raw_steps"][0]["parameters"]["resample"] = "NEAREST"
                else:
                    kit["raw_steps"][1]["inputs"]["raw"] = {"path": "refs/raw.png"}
                gate.write_json(kit_path, kit)
                before = kit_path.read_bytes()
                with self.assertRaises(ValueError):
                    gate.record_steps(kit_path)
                self.assertEqual(kit_path.read_bytes(), before)

    def test_missing_maquette_inputs_fail_and_standard_still_checks_present_inputs(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        for name in ("raw.png", "edit.png", "tone.json"):
            path = kit_path.parent / "refs" / name
            original = path.read_bytes()
            path.unlink()
            with self.subTest(input=name), self.assertRaisesRegex(ValueError, "input missing"):
                gate.replay_raw_steps(kit_path, allow_missing=True)
            path.write_bytes(original)
        kit.pop("kit_kind")
        gate.write_json(kit_path, kit)
        (kit_path.parent / "refs/raw.png").unlink()
        self.assertIsNone(gate.replay_raw_steps(kit_path, allow_missing=True))
        (kit_path.parent / "refs/tone.json").write_text("[]")
        with self.assertRaisesRegex(ValueError, "input sha256 changed"):
            gate.replay_raw_steps(kit_path, allow_missing=True)

    def test_recipe_paths_cannot_escape_job_or_maquette_input_folders(self):
        kit_path = self.raw_step_kit()
        original = gate.read_json(kit_path)
        shutil.copyfile(kit_path.parent / "refs/raw.png", kit_path.parent / "processed.png")
        for path in ("../raw.png", str(self.temp / "raw.png"), "processed.png"):
            kit = copy.deepcopy(original)
            kit["raw_steps"][0]["inputs"]["raw"]["path"] = path
            gate.write_json(kit_path, kit)
            with self.subTest(path=path), self.assertRaises(ValueError):
                gate.replay_raw_steps(kit_path)

    def test_plain_match_reference_rejects_existing_file_outside_maquette_input_folders(self):
        kit_path = self.raw_step_kit()
        shutil.copyfile(kit_path.parent / "refs/tone.png", kit_path.parent / "processed.png")
        spec = {"path": "processed.png", "pixel_sha256": RAW_STEP_LEGACY_PIXEL_SHA256["tone"]}
        with self.assertRaisesRegex(ValueError, "maquette input must be inside"):
            gate.derive_match_reference(spec, kit_path)

    def test_maquette_resolved_inputs_reject_symlinks_outside_allowed_folders(self):
        kit_path = self.raw_step_kit()
        job = kit_path.parent
        shutil.copyfile(job / "refs/raw.png", job / "copy.png")
        for folder in ("refs", "raw_inputs"):
            (job / folder).mkdir(exist_ok=True)
            link = job / folder / "linked.png"
            link.symlink_to("../copy.png")
            binding = {"path": str(link.relative_to(job)), "sha256": gate.sha(link.read_bytes())}
            spec = {"path": binding["path"], "pixel_sha256": gate.pixel_digest(gate.rgba(link))}
            with self.subTest(folder=folder):
                with self.assertRaisesRegex(ValueError, "maquette input must be inside"):
                    gate.recipe_input(binding, kit_path, "raw", maquette=True)
                with self.assertRaisesRegex(ValueError, "maquette input must be inside"):
                    gate.derive_match_reference(spec, kit_path)
            # Symlinks that resolve within an allowed input folder still work.
            link.unlink()
            link.symlink_to("../refs/raw.png")
            self.assertEqual(gate.recipe_input(binding, kit_path, "raw", maquette=True), link.read_bytes())
            self.assertEqual(gate.pixel_digest(gate.derive_match_reference(spec, kit_path)[0]), spec["pixel_sha256"])

    def test_derived_match_reference_binds_source_config_and_output_digests(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        front = self.temp / RAW_STEP_FRONT_JOB
        gate.write_json(front / "kit.json", {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID})
        shutil.copyfile(kit_path.parent / "refs/tone.png", front / "processed.png")
        gate.write_json(self.temp / gate.IDENTITY / "bands.json", gate.read_json(ROOT / gate.IDENTITY / "bands.json"))
        kit["match_reference"] = {
            "derived_from": {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json"), "pixel_sha256": kit["match_reference"]["pixel_sha256"]},
            "mask_config": {"path": "refs/mask.json", "sha256": gate.sha((kit_path.parent / "refs/mask.json").read_bytes())},
        }
        gate.write_json(kit_path, kit)
        image, binding = gate.derive_match_reference(kit["match_reference"], kit_path, self.temp)
        self.assertEqual(binding["reference_pixel_sha256"], RAW_STEP_LEGACY_PIXEL_SHA256["mask"])
        self.assertNotIn("reference_sha256", binding)
        source = gate.rgba(kit_path.parent / "refs/tone.png")
        np.testing.assert_array_equal(np.asarray(image)[..., :3], np.asarray(source)[..., :3])
        self.assertGreater((np.asarray(image)[..., 3] == 0).sum(), 0)
        out = kit_path.parent / "processed.png"
        record = gate.process_raw(None, kit_path, out, self.temp, outline=True)
        self.assertEqual(record["post_steps"][0]["match_reference"], kit["match_reference"])
        for path in (front / "processed.png", kit_path.parent / "refs/mask.json"):
            original = path.read_bytes()
            if path.suffix == ".png":
                changed = gate.rgba(path)
                changed.putpixel((0, 0), RAW_STEP_CHANGED_REFERENCE_RGBA)
                changed.save(path)
            else:
                path.write_bytes(original + b"\n")
            with self.subTest(input=path.name), self.assertRaisesRegex(ValueError, "input sha256 changed|front job processed pixel digest changed"):
                gate.verify_job_recipe(kit_path, self.temp)
            path.write_bytes(original)
        gate.rgba(front / "processed.png").save(front / "processed.png", compress_level=REENCODE_COMPRESSION_LEVEL)
        self.assertEqual(len(gate.verify_job_recipe(kit_path, self.temp)), 3)
        for field in ("reference_pixel_sha256", "pre_step_pixel_sha256"):
            changed = copy.deepcopy(record)
            changed["post_steps"][0][field] = "0" * 64
            gate.write_json(out.with_suffix(".json"), changed)
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "digest changed|post_steps mismatched"):
                gate.verify_job_recipe(kit_path, self.temp)

    def test_direct_match_reference_and_json_descriptor_cli(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        out = kit_path.parent / "processed.png"
        gate.process_raw(None, kit_path, out)
        self.assertEqual(len(gate.verify_job_recipe(kit_path)), 3)
        descriptor = kit_path.parent / "match.json"
        gate.write_json(descriptor, kit.pop("match_reference"))
        gate.write_json(kit_path, kit)
        command = [sys.executable, str(ROOT / "tools/art_identity_gate.py")]
        result = subprocess.run(command + ["process", "--kit", str(kit_path), "--out", str(out),
                                           "--match-front", str(descriptor)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(command + ["check", "--kit", str(kit_path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ART IDENTITY REPLAY: PASS", result.stdout)
        (kit_path.parent / "refs/tone.png").write_bytes(b"changed")
        result = subprocess.run(command + ["check", "--kit", str(kit_path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot identify image", result.stderr)

    def test_plain_front_job_reference_checks_pixels_and_front_job_path(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        front = self.temp / RAW_STEP_FRONT_JOB
        gate.write_json(front / "kit.json", {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID})
        shutil.copyfile(kit_path.parent / "refs/tone.png", front / "processed.png")
        gate.write_json(self.temp / gate.IDENTITY / "bands.json", gate.read_json(ROOT / gate.IDENTITY / "bands.json"))
        kit["match_reference"] = {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json"), "pixel_sha256": RAW_STEP_LEGACY_PIXEL_SHA256["tone"]}
        gate.write_json(kit_path, kit)
        gate.process_raw(None, kit_path, kit_path.parent / "processed.png", self.temp, outline=True)
        gate.rgba(front / "processed.png").save(front / "processed.png", compress_level=REENCODE_COMPRESSION_LEVEL)
        self.assertEqual(len(gate.verify_job_recipe(kit_path, self.temp)), 3)
        changed = gate.rgba(front / "processed.png")
        changed.putpixel((0, 0), RAW_STEP_CHANGED_REFERENCE_RGBA)
        changed.save(front / "processed.png")
        # A missing standard raw cannot hide a stale front binding.
        kit.pop("kit_kind")
        gate.write_json(kit_path, kit)
        (kit_path.parent / "refs/raw.png").unlink()
        with self.assertRaisesRegex(ValueError, "front job processed pixel digest changed"):
            gate.verify_job_recipe(kit_path, self.temp)
        for job_path in ("../front/kit.json", str(front / "kit.json"), "front/processed.png"):
            with self.subTest(job_path=job_path), self.assertRaises(ValueError):
                gate.derive_match_reference(dict(kit["match_reference"], job_path=job_path), kit_path, self.temp)
        gate.write_json(front / "kit.json", {"view": "creature_rear"})
        with self.assertRaisesRegex(ValueError, "front job kit.json"):
            gate.derive_match_reference(kit["match_reference"], kit_path, self.temp)

    def test_front_job_reference_rejects_extra_keys(self):
        kit_path = self.raw_step_kit()
        front = self.temp / RAW_STEP_FRONT_JOB
        gate.write_json(front / "kit.json", {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID})
        shutil.copyfile(kit_path.parent / "refs/tone.png", front / "processed.png")
        binding = {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json"),
                   "pixel_sha256": RAW_STEP_LEGACY_PIXEL_SHA256["tone"], "path": "refs/tone.png"}
        for masked in (False, True):
            spec = ({"derived_from": binding, "mask_config": {"path": "refs/mask.json",
                    "sha256": gate.sha((kit_path.parent / "refs/mask.json").read_bytes())}} if masked else binding)
            with self.subTest(masked=masked), self.assertRaisesRegex(ValueError, "front requires job_path and pixel_sha256"):
                gate.derive_match_reference(spec, kit_path, self.temp)

    def test_front_job_reference_requires_scoped_path_matching_id_and_valid_view(self):
        kit_path = self.raw_step_kit()
        front = self.temp / RAW_STEP_FRONT_JOB
        original = {"view": "creature_front", "id": RAW_STEP_FIXTURE_ID}
        gate.write_json(front / "kit.json", original)
        shutil.copyfile(kit_path.parent / "refs/tone.png", front / "processed.png")
        binding = {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json"), "pixel_sha256": RAW_STEP_LEGACY_PIXEL_SHA256["tone"]}
        for metadata, error in ((dict(original, id="another_creature"), "front job id must match"),
                                ({"view": "creature_front"}, "front job id must match"),
                                (dict(original, view=None), "front job kit.json"),
                                ({"id": RAW_STEP_FIXTURE_ID}, "front job kit.json")):
            gate.write_json(front / "kit.json", metadata)
            for record in (False, True):
                with self.subTest(metadata=metadata, record=record), self.assertRaisesRegex(ValueError, error):
                    gate.derive_match_reference(binding, kit_path, self.temp, record=record)
        gate.write_json(front / "kit.json", original)
        outside = self.temp / "other_front"
        shutil.copytree(front, outside)
        alias = self.temp / gate.IDENTITY / "jobs/outside_link"
        alias.symlink_to(outside, target_is_directory=True)
        for path in (outside, alias):
            spec = dict(binding, job_path=str((path / "kit.json").relative_to(self.temp)))
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "inside spec/art_identity/jobs/"):
                gate.derive_match_reference(spec, kit_path, self.temp)

    def test_front_job_path_requires_exact_identity_job_shape_and_no_self_reference(self):
        kit_path = self.raw_step_kit(self.temp / RAW_STEP_FRONT_JOB)
        binding = {"pixel_sha256": RAW_STEP_LEGACY_PIXEL_SHA256["tone"]}
        for path in ("fixture/kit.json", "fixture/nested/front/kit.json", "wrong_id/front/kit.json",
                     "fixture/front/other.json"):
            binding["job_path"] = str(gate.IDENTITY / "jobs" / path)
            for record in (False, True):
                with self.subTest(path=path, record=record), self.assertRaisesRegex(ValueError, "<id>/<job>/kit.json"):
                    gate.derive_match_reference(binding, kit_path, self.temp, record=record)
        alias = kit_path.parent.parent / "alias"
        alias.symlink_to(kit_path.parent, target_is_directory=True)
        for path in (kit_path, alias / "kit.json"):
            binding["job_path"] = str(path.relative_to(self.temp))
            for record in (False, True):
                with self.subTest(path=path, record=record), self.assertRaisesRegex(ValueError, "referencing kit itself"):
                    gate.derive_match_reference(binding, kit_path, self.temp, record=record)
        nested_alias = kit_path.parent.parent / "nested/alias"
        nested_alias.parent.mkdir()
        nested_alias.symlink_to(kit_path.parent, target_is_directory=True)
        binding["job_path"] = str((nested_alias / "kit.json").relative_to(self.temp))
        with self.assertRaisesRegex(ValueError, "<id>/<job>/kit.json"):
            gate.derive_match_reference(binding, kit_path, self.temp)

    def test_non_object_front_kit_is_a_clean_cli_error(self):
        kit_path = self.raw_step_kit()
        front = self.temp / RAW_STEP_FRONT_JOB / "kit.json"
        binding = {"job_path": str(RAW_STEP_FRONT_JOB / "kit.json"),
                   "pixel_sha256": RAW_STEP_LEGACY_PIXEL_SHA256["tone"]}
        for metadata in (None, [], "front", 1):
            gate.write_json(front, metadata)
            for record in (False, True):
                with self.subTest(metadata=metadata, record=record), self.assertRaisesRegex(ValueError, "must be an object"):
                    gate.derive_match_reference(binding, kit_path, self.temp, record=record)
        kit = gate.read_json(kit_path)
        kit["match_reference"] = binding
        gate.write_json(kit_path, kit)
        record_steps = gate.record_steps
        with patch.object(gate, "record_steps", side_effect=lambda path: record_steps(path, self.temp)), \
                patch.object(sys, "argv", ["art_identity_gate.py", "record-steps", "--kit", str(kit_path)]), \
                patch("builtins.print") as output:
            self.assertEqual(gate.main(), 1)
        output.assert_called_once_with("ART IDENTITY ERROR: match_reference front kit.json must be an object", file=sys.stderr)

    def test_record_steps_ascii_stdout_keeps_input_changed_line_and_escapes_paths(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        refs = kit_path.parent / "refs"
        (refs / "raw.png").rename(refs / ASCII_STDOUT_FIXTURE_RAW)
        binding = kit["raw_steps"][0]["inputs"]["raw"]
        binding.update(path="refs/" + ASCII_STDOUT_FIXTURE_RAW, sha256="0" * 64)
        gate.write_json(kit_path, kit)
        result = subprocess.run([sys.executable, str(ROOT / "tools/art_identity_gate.py"), "record-steps", "--kit", str(kit_path)],
                                env=dict(os.environ, PYTHONIOENCODING="ascii:strict"), capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode("ascii"))
        digest = gate.sha((refs / ASCII_STDOUT_FIXTURE_RAW).read_bytes())
        expected = "INPUT CHANGED refs/r\\xe4w.png %s->%s" % ("0" * 64, digest)
        self.assertIn(expected, result.stdout.decode("ascii"))
        self.assertEqual(gate.read_json(kit_path)["raw_steps"][0]["inputs"]["raw"]["sha256"], digest)

    def test_explicit_match_front_conflict_cannot_override_kit(self):
        kit_path = self.raw_step_kit()
        gate.write_json(self.temp / gate.IDENTITY / "bands.json", gate.read_json(ROOT / gate.IDENTITY / "bands.json"))
        out = kit_path.parent / "processed.png"
        # Both are real images inside the job; only tone.png agrees with the kit reference.
        direct = (kit_path.parent / "refs/edit.png").relative_to(self.temp)
        descriptor = kit_path.parent / "match.json"
        gate.write_json(descriptor, {"path": "refs/edit.png", "pixel_sha256": gate.pixel_digest(gate.rgba(self.temp / direct))})
        for reference in (direct, descriptor):
            with self.subTest(reference=reference), self.assertRaisesRegex(ValueError, "conflicts with kit match_reference"):
                gate.process_raw(None, kit_path, out, self.temp, match_front=reference)
        matching = (kit_path.parent / "refs/tone.png").relative_to(self.temp)
        gate.process_raw(None, kit_path, out, self.temp, match_front=matching)
        self.assertEqual(len(gate.verify_job_recipe(kit_path, self.temp)), 3)

    def test_legacy_direct_png_must_be_repo_relative_and_maquette_job_local(self):
        kit_path = self.raw_step_kit()
        kit = gate.read_json(kit_path)
        kit.pop("match_reference")
        gate.write_json(kit_path, kit)
        gate.write_json(self.temp / gate.IDENTITY / "bands.json", gate.read_json(ROOT / gate.IDENTITY / "bands.json"))
        local = kit_path.parent / "refs/tone.png"
        outside = self.temp / "outside.png"
        shutil.copyfile(local, outside)
        out = kit_path.parent / "processed.png"
        for path, error in ((local, "repository-relative"), (Path("outside.png"), "inside the maquette job folder")):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, error):
                gate.process_raw(None, kit_path, out, self.temp, match_front=path)
        record = gate.process_raw(None, kit_path, out, self.temp, match_front=local.relative_to(self.temp))
        self.assertNotIn("reference_sha256", record["post_steps"][0])
        self.assertEqual(len(gate.verify_job_recipe(kit_path, self.temp)), 3)
        for path, error in ((str(local), "repository-relative"), ("outside.png", "inside the maquette job folder")):
            changed = copy.deepcopy(record)
            changed["post_steps"][0]["reference"] = path
            gate.write_json(out.with_suffix(".json"), changed)
            with self.subTest(recorded_path=path), self.assertRaisesRegex(ValueError, error):
                gate.verify_job_recipe(kit_path, self.temp)

    def test_replay_accepts_processed_png_reencoding_and_rejects_recipe_sidecar_changes(self):
        kit_path = self.raw_step_kit()
        out = kit_path.parent / "processed.png"
        record = gate.process_raw(None, kit_path, out, outline=True)
        original = out.read_bytes()
        gate.rgba(out).save(out, compress_level=REENCODE_COMPRESSION_LEVEL)
        self.assertNotEqual(out.read_bytes(), original)
        self.assertIn("INFO processed.png encoded bytes different (pixels match)", gate.verify_job_recipe(kit_path))
        result = subprocess.run([sys.executable, str(ROOT / "tools/art_identity_gate.py"), "check", "--kit", str(kit_path)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ART IDENTITY REPLAY: PASS", result.stdout)
        out.write_bytes(original)
        record["raw_steps"] = []
        gate.write_json(out.with_suffix(".json"), record)
        with self.assertRaisesRegex(ValueError, "processed raw_steps mismatched"):
            gate.verify_job_recipe(kit_path)

    def recipe_registry(self):
        root, registry, entry = self.kit_registry()
        kit_path = self.raw_step_kit(root / "jobs/fixture")
        out = kit_path.parent / "processed.png"
        record = gate.process_raw(None, kit_path, out, root, outline=True)
        entry.pop("raw_sha256")
        entry.update(raw_pixel_sha256=record["raw_pixel_sha256"], source_pixel_sha256=record["pixel_sha256"], post_steps=record["post_steps"])
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        return root, registry, entry, kit_path, record

    def test_registry_check_replays_recipe_in_addition_to_existing_certification(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(reports))
        out = kit_path.parent / "processed.png"
        original = out.read_bytes()
        gate.rgba(out).save(out, compress_level=REENCODE_COMPRESSION_LEVEL)
        self.assertNotEqual(out.read_bytes(), original)
        reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(reports))
        (kit_path.parent / "refs/edit.png").write_bytes(b"changed")
        reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 1)
        self.assertTrue(any("raw_steps[0].edit input sha256 changed" in line for line in reports))

    def test_registry_warns_when_standard_recipe_inputs_are_absent(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        (kit_path.parent / "refs/raw.png").unlink()
        reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(reports))
        self.assertIn("WARN assets/hero.png: SKIP raw_steps replay: inputs absent", reports)
        self.assertEqual(reports[-1], "ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 1 skipped replays)")
        reports, failures = gate.check_registry(root, strict=True)
        self.assertEqual(failures, 1)
        self.assertIn("WARN assets/hero.png: SKIP raw_steps replay: inputs absent", reports)
        self.assertTrue(any("strict: SKIP raw_steps replay: inputs absent" in line for line in reports if line.startswith("FAIL ")))
        self.assertEqual(reports[-1], "ART IDENTITY CHECK: FAIL (1 failures, 0 pending_reart warnings, 1 skipped replays)")
        # The CLI must return a failure for a strict skipped replay too.
        check_registry = gate.check_registry
        with patch.object(gate, "check_registry", side_effect=lambda **kwargs: check_registry(root, **kwargs)), \
                patch.object(sys, "argv", ["art_identity_gate.py", "check", "--strict"]), patch("builtins.print"):
            self.assertEqual(gate.main(), 1)
        with self.assertRaisesRegex(ValueError, "input missing"):
            gate.verify_job_recipe(kit_path, root, require_inputs=True)

    def test_registry_raw_steps_reject_legacy_raw_digest_even_with_valid_pixel_digest(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        entry["raw_sha256"] = entry["raw_pixel_sha256"]
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 1)
        self.assertTrue(any("raw_steps registry entry requires raw_pixel_sha256, not raw_sha256" in line for line in reports))

    def test_missing_standard_inputs_do_not_bypass_post_step_structure_guards(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        (kit_path.parent / "refs/raw.png").unlink()
        for change in ("pre_step_digest", "parameters", "order"):
            with self.subTest(change=change):
                changed = copy.deepcopy(record)
                if change == "pre_step_digest":
                    changed["post_steps"][0]["pre_step_pixel_sha256"] = "invalid"
                elif change == "parameters":
                    changed["post_steps"][0]["parameters"] = {}
                else:
                    changed["post_steps"].reverse()
                gate.write_json(kit_path.parent / "processed.json", changed)
                error = ("unsupported post_steps order for replay" if change == "order"
                         else "processed post_steps parameters or pre-step digest invalid")
                with self.assertRaisesRegex(ValueError, error):
                    gate.verify_job_recipe(kit_path, root)

    def test_missing_standard_inputs_do_not_allow_a_direct_reference_without_digests(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        (kit_path.parent / "refs/raw.png").unlink()
        kit = gate.read_json(kit_path)
        reference = kit.pop("match_reference")
        gate.write_json(kit_path, kit)
        palette = record["post_steps"][0]
        palette.pop("match_reference")
        palette.pop("reference_pixel_sha256")
        palette["reference"] = str((kit_path.parent / reference["path"]).relative_to(root))
        self.assertNotIn("reference_sha256", palette)
        gate.write_json(kit_path.parent / "processed.json", record)
        with self.assertRaisesRegex(ValueError, "reference pixel digest changed"):
            gate.verify_job_recipe(kit_path, root)

    def test_recipe_exception_preserves_entry_failures_before_and_after_replay(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        entry["owner_approval"] = ""
        entry.pop("landmarks")
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        with patch.object(gate, "verify_job_recipe", side_effect=RuntimeError("fixture recipe exception")):
            reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 1)
        line = next(line for line in reports if line.startswith("FAIL assets/hero.png:"))
        for expected in ("owner_approval note missing", "recipe: fixture recipe exception", "lateral_axis=None"):
            self.assertIn(expected, line)

    def test_missing_standard_inputs_do_not_bypass_reference_or_final_raw_guards(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        (kit_path.parent / "refs/raw.png").unlink()
        kit = gate.read_json(kit_path)
        for change, expected in (("reference_digest", "reference digest changed"),
                                 ("final_raw", "differs from final raw_steps output"),
                                 ("kit_reference", "processed match_reference mismatched"),
                                 ("processed_pixels", "processed.png pixel digest changed")):
            with self.subTest(change=change):
                changed = copy.deepcopy(record)
                if change == "reference_digest": changed["post_steps"][0]["reference_pixel_sha256"] = "0" * 64
                elif change == "final_raw": changed["raw_pixel_sha256"] = "0" * 64
                elif change == "kit_reference": changed["post_steps"][0]["match_reference"]["path"] = "refs/edit.png"
                else: changed["pixel_sha256"] = "0" * 64
                gate.write_json(kit_path.parent / "processed.json", changed)
                with self.assertRaisesRegex(ValueError, expected):
                    gate.verify_job_recipe(kit_path, root)
        gate.write_json(kit_path.parent / "processed.json", record)
        reference = kit_path.parent / kit["match_reference"]["path"]
        changed = gate.rgba(reference)
        changed.putpixel((0, 0), (1, 2, 3, 255))
        changed.save(reference)
        with self.assertRaisesRegex(ValueError, "match_reference pixel digest changed"):
            gate.verify_job_recipe(kit_path, root)

    def test_absent_standard_inputs_still_reject_legacy_sidecar_byte_fields(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        (kit_path.parent / "refs/raw.png").unlink()
        changed = copy.deepcopy(record)
        changed["raw_sha256"] = "0" * 64
        gate.write_json(kit_path.parent / "processed.json", changed)
        with self.assertRaisesRegex(ValueError, "require raw_pixel_sha256, not raw_sha256"):
            gate.verify_job_recipe(kit_path, root)
        kit = gate.read_json(kit_path)
        kit.pop("match_reference")
        gate.write_json(kit_path, kit)
        for direct in (False, True):
            changed = copy.deepcopy(record)
            step = changed["post_steps"][0]
            step["reference_sha256"] = "0" * 64
            if direct:
                step.pop("match_reference")
                step["reference"] = "jobs/fixture/refs/tone.png"
            gate.write_json(kit_path.parent / "processed.json", changed)
            with self.subTest(direct=direct), self.assertRaisesRegex(ValueError, "requires reference_pixel_sha256, not reference_sha256"):
                gate.verify_job_recipe(kit_path, root)

    def test_committed_jobs_replay_approved_pixels_without_external_inputs(self):
        jobs = [path.parent.relative_to(ROOT) for path in sorted((ROOT / gate.IDENTITY / "jobs").rglob("kit.json"))
                if "raw_steps" in gate.read_json(path)]
        self.assertTrue(jobs)
        references = set()
        for job in jobs:
            binding = gate.read_json(ROOT / job / "kit.json").get("match_reference", {})
            binding = binding.get("derived_from", binding)
            if "job_path" in binding:
                references.add(Path(binding["job_path"]).parent)
        for job in set(jobs) | references:
            shutil.copytree(ROOT / job, self.temp / job)
        shutil.copyfile(ROOT / gate.IDENTITY / "bands.json", self.temp / gate.IDENTITY / "bands.json")
        for job in jobs:
            local = self.temp / job
            with self.subTest(job=str(job)):
                before = {p: gate.sha(p.read_bytes()) for p in local.rglob("*") if p.is_file()}
                self.assertEqual(len(gate.verify_job_recipe(local / "kit.json", self.temp, require_inputs=True)), 3)
                self.assertEqual(before, {p: gate.sha(p.read_bytes()) for p in before})
                kit = gate.read_json(local / "kit.json")
                self.assertEqual(kit["kit_kind"], "maquette")
                self.assertEqual(gate.prompt_kit_version(kit, (local / "prompt.md").read_bytes()), kit["kit_version"])
                approved = gate.read_json(local / "processed.json")
                output = self.temp / "reprocessed" / job / "processed.png"
                rebuilt = gate.process_raw(None, local / "kit.json", output, self.temp,
                                           outline=any(step["step"] == "clean_outline" for step in approved.get("post_steps", [])))
                self.assertEqual(rebuilt["pixel_sha256"], approved["pixel_sha256"])
                self.assertEqual(rebuilt.get("post_steps"), approved.get("post_steps"))
                self.assertEqual(output.read_bytes(), (local / "processed.png").read_bytes())

    def test_recipe_replay_uses_recorded_palette_parameters(self):
        kit_path = self.raw_step_kit()
        out = kit_path.parent / "processed.png"
        for parameters in (gate.LEGACY_PALETTE_MATCH_PARAMETERS, gate.ART07_V1_PALETTE_MATCH_PARAMETERS,
                           gate.PALETTE_MATCH_PARAMETERS):
            with self.subTest(parameters=parameters):
                record = gate.process_raw(None, kit_path, out, outline=True, palette_parameters=parameters)
                self.assertEqual(record["post_steps"][0]["parameters"], parameters)
                self.assertEqual(len(gate.verify_job_recipe(kit_path, require_inputs=True)), 3)
        for key in ("accent_lightness", "accent_hue_window_deg"):
            changed = copy.deepcopy(record)
            changed["post_steps"][0]["parameters"].pop(key)
            gate.write_json(out.with_suffix(".json"), changed)
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "parameters or pre-step digest invalid"):
                gate.verify_job_recipe(kit_path, require_inputs=True)

    def test_existing_rear_palette_parameter_defaults_are_all_preserved(self):
        checked = []
        for kit_path in sorted((ROOT / gate.IDENTITY / "jobs").rglob("kit.json")):
            if not gate.read_json(kit_path).get("view", "").endswith("_rear"):
                continue
            sidecar = kit_path.parent / "processed.json"
            if not sidecar.is_file():
                continue
            steps = [s for s in gate.read_json(sidecar).get("post_steps", []) if s.get("step") == "palette_match"]
            if len(steps) == 1 and gate.valid_palette_parameters(steps[0].get("parameters")):
                with self.subTest(kit=str(kit_path)):
                    self.assertEqual(gate.processing_palette_parameters(kit_path), steps[0]["parameters"])
                checked.append(kit_path)
        self.assertTrue(checked)

    def test_historical_rears_with_retained_raws_reprocess_to_approved_pixels(self):
        gate.write_json(self.temp / gate.IDENTITY / "bands.json", gate.read_json(ROOT / gate.IDENTITY / "bands.json"))
        for identity, job, raw_path in HISTORICAL_REPROCESS_INPUTS:
            source = ROOT / gate.IDENTITY / "jobs" / identity / job
            approved = gate.read_json(source / "processed.json")
            raw = source.parent / raw_path
            self.assertEqual(gate.sha(raw.read_bytes()), approved["raw_sha256"])
            local = self.temp / gate.IDENTITY / "jobs" / identity / job
            shutil.copytree(source, local)
            palette = next(s for s in approved["post_steps"] if s["step"] == "palette_match")
            # Historical direct references predate job-local path guards. Copy the exact reference pixels
            # into the disposable job without weakening those guards or changing approved metadata.
            reference = local / "refs/reprocess_reference.png"
            reference.parent.mkdir(exist_ok=True)
            shutil.copyfile(ROOT / palette["reference"], reference)
            out = self.temp / "historical-reprocessed" / identity / "processed.png"
            actual = gate.process_raw(raw, local / "kit.json", out, self.temp,
                                      match_front=reference.relative_to(self.temp), outline=True)
            with self.subTest(identity=identity, job=job):
                self.assertEqual(actual["post_steps"][0]["parameters"], palette["parameters"])
                self.assertEqual(actual["pixel_sha256"], approved["pixel_sha256"])
                self.assertEqual(out.read_bytes(), (source / "processed.png").read_bytes())

    def test_process_cli_defaults_to_recorded_palette_and_requires_explicit_upgrade(self):
        kit_path = self.raw_step_kit()
        approved = gate.process_raw(None, kit_path, kit_path.parent / "processed.png", outline=True, palette_parameters="legacy")
        for selection in (None, "legacy", "current"):
            output = self.temp / (str(selection) + ".png")
            args = [sys.executable, str(ROOT / "tools/art_identity_gate.py"), "process", "--kit", str(kit_path),
                    "--out", str(output), "--clean-outline"]
            if selection is not None:
                args += ["--palette-parameters", selection]
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            record = gate.read_json(output.with_suffix(".json"))
            expected = gate.PALETTE_MATCH_PARAMETERS if selection == "current" else gate.LEGACY_PALETTE_MATCH_PARAMETERS
            self.assertEqual(record["post_steps"][0]["parameters"], expected)
            if selection != "current":
                self.assertEqual(record["pixel_sha256"], approved["pixel_sha256"])
        # A future default change must not replace a recorded current opt-in either.
        gate.process_raw(None, kit_path, kit_path.parent / "processed.png", palette_parameters="current", allow_protected_share=True)
        replayed = gate.process_raw(None, kit_path, self.temp / "recorded-current.png")
        self.assertTrue(replayed["post_steps"][0]["parameters"]["allow_protected_share"])
        self.assertEqual(len(gate.verify_job_recipe(kit_path, require_inputs=True)), 3)

    def test_process_coverage_failure_is_atomic_and_override_is_recorded(self):
        kit_path = self.raw_step_kit()
        reference = Image.new("RGBA", (CORE_FIXTURE_SIDE, CORE_FIXTURE_SIDE), CORE_FIXTURE_FRONT_BODY)
        pixels = np.asarray(reference).copy()
        pixels[:CORE_FIXTURE_SIDE // 2] = CORE_FIXTURE_PALE
        reference = Image.fromarray(pixels)
        image_path = kit_path.parent / "refs/palette-guard.png"
        reference.save(image_path)
        kit = gate.read_json(kit_path)
        kit["match_reference"] = {"path": "refs/palette-guard.png", "pixel_sha256": gate.pixel_digest(reference)}
        gate.write_json(kit_path, kit)
        out = kit_path.parent / "processed.png"
        legacy = gate.process_raw(None, kit_path, out, palette_parameters="legacy")
        previous = (out.read_bytes(), out.with_suffix(".json").read_bytes())
        args = [sys.executable, str(ROOT / "tools/art_identity_gate.py"), "process", "--kit", str(kit_path),
                "--out", str(out), "--palette-parameters", "current"]
        rejected = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(rejected.returncode, 1)
        self.assertIn("front body: 50.0% protected", rejected.stderr)
        self.assertNotIn("Traceback", rejected.stderr)
        self.assertEqual((out.read_bytes(), out.with_suffix(".json").read_bytes()), previous)
        approved = subprocess.run(args + ["--allow-protected-share"], capture_output=True, text=True)
        self.assertEqual(approved.returncode, 0, approved.stderr)
        record = gate.read_json(out.with_suffix(".json"))
        self.assertTrue(record["post_steps"][0]["parameters"]["allow_protected_share"])
        self.assertEqual(record["post_steps"][0]["protected_body_share"]["front"], 0.5)
        self.assertEqual(len(gate.verify_job_recipe(kit_path, require_inputs=True)), 3)
        self.assertNotEqual(record["pixel_sha256"], legacy["pixel_sha256"])

    def empty_body_reference(self, kit_path):
        reference = Image.new("RGBA", (CORE_FIXTURE_SIDE, CORE_FIXTURE_SIDE), CORE_FIXTURE_PALE)
        reference.save(kit_path.parent / "refs/empty-body-front.png")
        kit = gate.read_json(kit_path)
        kit["match_reference"] = {"path": "refs/empty-body-front.png", "pixel_sha256": gate.pixel_digest(reference)}
        gate.write_json(kit_path, kit)

    def test_process_empty_body_requires_override_and_records_replayable_skip(self):
        kit_path = self.raw_step_kit()
        self.empty_body_reference(kit_path)
        out = kit_path.parent / "processed.png"
        args = [sys.executable, str(ROOT / "tools/art_identity_gate.py"), "process", "--kit", str(kit_path),
                "--out", str(out), "--palette-parameters", "current"]
        rejected = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(rejected.returncode, 1)
        self.assertIn("body is empty", rejected.stderr)
        self.assertIn("--allow-protected-share", rejected.stderr)
        self.assertNotIn("Traceback", rejected.stderr)
        self.assertFalse(out.exists())
        self.assertFalse(out.with_suffix(".json").exists())
        gate.process_raw(None, kit_path, out, palette_parameters="legacy")
        previous = (out.read_bytes(), out.with_suffix(".json").read_bytes())
        rejected = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(rejected.returncode, 1)
        self.assertEqual((out.read_bytes(), out.with_suffix(".json").read_bytes()), previous)
        approved = subprocess.run(args + ["--allow-protected-share"], capture_output=True, text=True)
        self.assertEqual(approved.returncode, 0, approved.stderr)
        record = gate.read_json(out.with_suffix(".json"))
        step = record["post_steps"][0]
        self.assertEqual(step["kind"], "palette_match")
        self.assertEqual(step["skipped"], "empty body")
        self.assertEqual(step["protected_share"], step["protected_body_share"])
        self.assertEqual(step["protected_share"]["front"], 1.0)
        self.assertTrue(step["parameters"]["allow_protected_share"])
        self.assertEqual(step["pre_step_pixel_sha256"], record["pixel_sha256"])
        self.assertEqual(len(gate.verify_job_recipe(kit_path, require_inputs=True)), 3)
        skipped = gate.rgba(out)
        # Recorded override survives default reprocessing; skipping match must not skip the next step.
        outlined = gate.process_raw(None, kit_path, out, outline=True)
        self.assertEqual(outlined["post_steps"][0], step)
        self.assertEqual(outlined["post_steps"][1]["pre_step_pixel_sha256"], record["pixel_sha256"])
        self.assertEqual(gate.rgba(out).tobytes(), gate.clean_outline(skipped).tobytes())
        self.assertEqual(len(gate.verify_job_recipe(kit_path, require_inputs=True)), 3)

    def test_registry_check_verifies_empty_body_skip_and_rejects_tampering(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        self.empty_body_reference(kit_path)
        out = kit_path.parent / "processed.png"
        record = gate.process_raw(None, kit_path, out, root, outline=True, allow_protected_share=True)
        entry.update(source_pixel_sha256=record["pixel_sha256"], post_steps=record["post_steps"])
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        reports, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(reports))
        for change in ("kind", "reason", "override", "shares", "unmarked"):
            with self.subTest(change=change):
                changed = copy.deepcopy(record)
                step = changed["post_steps"][0]
                if change == "kind": step["kind"] = "unknown"
                elif change == "reason": step["skipped"] = "unknown"
                elif change == "override": step["parameters"]["allow_protected_share"] = False
                elif change == "shares":
                    step["protected_share"]["rear"] = 0.5
                    step["protected_body_share"]["rear"] = 0.5
                else:
                    for field in ("kind", "skipped", "protected_share"):
                        step.pop(field)
                gate.write_json(out.with_suffix(".json"), changed)
                entry["post_steps"] = changed["post_steps"]
                gate.write_json(root / gate.IDENTITY / "registry.json", registry)
                reports, failures = gate.check_registry(root)
                self.assertEqual(failures, 1, "\n".join(reports))
                error = ("replayed processed post_steps mismatched" if change in ("shares", "unmarked")
                         else "palette_match empty-body skip record invalid")
                self.assertTrue(any("recipe: " + error in line for line in reports), "\n".join(reports))

    def test_missing_inputs_do_not_bypass_empty_body_skip_record_validation(self):
        root, registry, entry, kit_path, record = self.recipe_registry()
        self.empty_body_reference(kit_path)
        record = gate.process_raw(None, kit_path, kit_path.parent / "processed.png", root, allow_protected_share=True)
        (kit_path.parent / "refs/raw.png").unlink()
        self.assertEqual(gate.verify_job_recipe(kit_path, root), ["SKIP raw_steps replay: inputs absent"])
        for change in ("missing", "bool", "nonfinite", "negative", "above_one", "not_empty", "mismatch"):
            with self.subTest(change=change):
                changed = copy.deepcopy(record)
                step = changed["post_steps"][0]
                if change == "missing": step.pop("protected_share")
                elif change == "mismatch": step["protected_body_share"] = {"front": 0.0, "rear": 0.0}
                else:
                    value = {"bool": True, "nonfinite": float("inf"), "negative": -1.0,
                             "above_one": 2.0, "not_empty": 0.5}[change]
                    step["protected_share"] = {"front": value, "rear": 0.0}
                    step["protected_body_share"] = dict(step["protected_share"])
                # Deliberately malformed JSON number is input to the verifier, not tool output.
                (kit_path.parent / "processed.json").write_text(json.dumps(changed))
                with self.assertRaisesRegex(ValueError, "palette_match empty-body skip record invalid"):
                    gate.verify_job_recipe(kit_path, root)

    def test_unknown_recorded_parameters_fail_instead_of_silently_using_current(self):
        kit_path = self.raw_step_kit()
        for parameters in (None, {}, dict(gate.PALETTE_MATCH_PARAMETERS, allow_protected_share=1)):
            gate.write_json(kit_path.parent / "processed.json", {"post_steps": [{"step": "palette_match", "parameters": parameters}]})
            with self.subTest(parameters=parameters), self.assertRaisesRegex(ValueError, "recorded palette_match parameters"):
                gate.process_raw(None, kit_path, self.temp / "should-not-write.png")
            self.assertFalse((self.temp / "should-not-write.png").exists())

    def test_palette_match_and_outline_are_pixel_identical_to_prototypes(self):
        # Proof-only synthetic accents, green key residue, opaque islands and borders.
        rng = np.random.default_rng(POST_STEP_FIXTURE_SEED)
        pixels = rng.integers(0, POST_STEP_FIXTURE_RGB_MAX, (POST_STEP_FIXTURE_SIDE, POST_STEP_FIXTURE_SIDE, 4), dtype=np.uint8)
        pixels[..., 3] = 0
        pixels[3:29, 3:29, 3] = 255
        pixels[4:8, 4:8, :3] = [230, 0, 230]
        pixels[8:10, 8:10, :3] = [0, 80, 0]
        pixels[0, 0] = [200, 200, 200, 255]
        rear = self.temp / "rear.png"
        Image.fromarray(pixels).save(rear)
        front = FIXTURES / "hero_front.png"
        match = runpy.run_path(str(ROOT / "spec/art_identity/prototype/match_palette.py"))["match"]
        clean = runpy.run_path(str(ROOT / "spec/art_identity/prototype/clean_outline.py"))["clean"]
        match(front, rear, self.temp / "match.png")
        actual = gate.palette_match(gate.rgba(front), gate.rgba(rear), gate.LEGACY_PALETTE_MATCH_PARAMETERS)
        self.assertEqual(actual.tobytes(), gate.rgba(self.temp / "match.png").tobytes())
        clean(rear, self.temp / "clean.png")
        self.assertEqual(gate.clean_outline(gate.rgba(rear)).tobytes(), gate.rgba(self.temp / "clean.png").tobytes())

    def test_post_steps_order_parameters_and_pre_step_digests(self):
        image = Image.new("RGB", (1024, 1024), "#00ff00")
        ImageDraw.Draw(image).rectangle((320, 240, 700, 920), fill=(100, 90, 70))
        raw, kit = self.temp / "raw.png", self.temp / "kit.json"
        image.save(raw)
        gate.write_json(kit, {"K": 4})
        gate.process_raw(raw, kit, self.temp / "before.png")
        front = FIXTURES / "hero_front.png"
        record = gate.process_raw(raw, kit, self.temp / "after.png", match_front=front.relative_to(ROOT), outline=True)
        steps = record["post_steps"]
        self.assertEqual([s["step"] for s in steps], ["palette_match", "clean_outline"])
        self.assertEqual(steps[0]["parameters"], gate.PALETTE_MATCH_PARAMETERS)
        self.assertEqual(steps[1]["parameters"], gate.OUTLINE_PARAMETERS)
        before = gate.rgba(self.temp / "before.png")
        matched = gate.palette_match(gate.rgba(front), before)
        self.assertEqual(steps[0]["pre_step_pixel_sha256"], gate.pixel_digest(before))
        self.assertEqual(steps[1]["pre_step_pixel_sha256"], gate.pixel_digest(matched))
        self.assertEqual(steps[0]["reference_pixel_sha256"], gate.pixel_digest(gate.rgba(front)))
        self.assertEqual(gate.rgba(self.temp / "after.png").tobytes(), gate.clean_outline(matched).tobytes())
        self.assertEqual(record["pixel_sha256"], gate.pixel_digest(gate.rgba(self.temp / "after.png")))

    def test_edge_light_and_rear_consistency_bands(self):
        pixels = np.zeros((8, 8, 4), dtype=np.uint8)
        pixels[2:6, 2:6] = [20, 16, 21, 255]
        pixels[2, 2:5] = [255, 255, 255, 255]
        self.assertEqual(gate.edge_light_share(pixels), 3 / 12)
        border = np.full((4, 4, 4), 255, dtype=np.uint8)
        self.assertEqual(gate.edge_light_share(border), 1.0)
        front = self.temp / "front.png"
        Image.fromarray(pixels).save(front)
        rear = self.temp / "rear.png"
        pixels[2:6, 2:6, :3] = [100, 100, 100]
        Image.fromarray(pixels).save(rear)
        delta = gate.rear_consistency(front, rear)
        self.assertGreater(delta["value_delta"], 0.03)
        bands = gate.read_json(ROOT / gate.IDENTITY / "bands.json")
        limits = gate.metric_bands({"kind": "creature", "size_class": "medium", "facing": "rear"}, bands)
        self.assertEqual(limits["edge_light_share"], (None, 0.06))
        self.assertNotIn("lateral_axis", limits)

    def test_subject_rear_is_used_and_recorded_without_changing_front_subject(self):
        subject = self.temp / "rear_subject.md"
        subject.write_text("Rear-only fixture equipment side.\n")
        args = self.kit_args(view="creature_rear", front_ref=FIXTURES / "hero_front.png", subject_rear=subject)
        kit = gate.make_kit(args)
        self.assertEqual(kit["subject_rear"], str(subject))
        self.assertEqual(kit["subject_rear_sha256"], gate.sha(subject.read_bytes()))
        self.assertIn(subject.read_text(), (Path(args.out_dir) / "prompt.md").read_text())
        self.assertNotIn("Test fixture subject.", (Path(args.out_dir) / "prompt.md").read_text())
        with self.assertRaisesRegex(ValueError, "rear view"):
            gate.make_kit(self.kit_args("front", subject_rear=subject))

    def test_source_digest_and_post_steps_are_verified_separately_from_production(self):
        root, registry, entry = self.kit_registry()
        source = root / entry["source_path"]
        image = gate.rgba(source)
        image.putpixel((0, 0), (1, 2, 3, 0))
        image.save(source)
        report, failures = gate.check_registry(root)
        self.assertGreater(failures, 0)
        self.assertTrue(any("source pixel digest changed" in line for line in report))
        shutil.copyfile(root / entry["path"], source)
        entry["post_steps"] = [{"step": "invented"}]
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        report, failures = gate.check_registry(root)
        self.assertTrue(any("post_steps mismatched" in line for line in report))

    def test_source_cannot_be_redirected_to_another_job(self):
        root, registry, entry = self.kit_registry()
        target = root / "jobs/substituted.png"
        shutil.copyfile(root / entry["source_path"], target)
        shutil.copyfile((root / entry["source_path"]).with_suffix(".json"), target.with_suffix(".json"))
        entry["source_path"] = "jobs/substituted.png"
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        report, failures = gate.check_registry(root)
        self.assertTrue(any("source path is not the job" in line for line in report))

    def test_pair_consistency_is_enforced_for_each_registered_view(self):
        root, registry, entry = self.kit_registry()
        rear = dict(entry, path="assets/rear.png", source_path="jobs/rear/processed.png", facing="rear")
        (root / "jobs/rear").mkdir()
        image = gate.rgba(root / entry["path"])
        pixels = np.asarray(image).copy()
        pixels[pixels[..., 3] > 0, :3] = PAIR_FIXTURE_REAR_TONE
        Image.fromarray(pixels).save(root / rear["source_path"])
        shutil.copyfile(root / rear["source_path"], root / rear["path"])
        rear["pixel_sha256"] = rear["source_pixel_sha256"] = gate.pixel_digest(gate.rgba(root / rear["path"]))
        gate.write_json(root / "jobs/rear/processed.json", {"raw_sha256": rear["raw_sha256"], "pixel_sha256": rear["source_pixel_sha256"]})
        registry["entries"].append(rear)
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        report, failures = gate.check_registry(root, entry_id=entry["path"])
        self.assertTrue(any("rear_consistency.value_delta" in line for line in report))

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
        canon = gate.canon_entries(ROOT, include_retired=True)
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

    def test_retired_canon_resolves_for_provenance_but_not_for_new_kits(self):
        self.assertIn("harrier_front", gate.canon_entries(ROOT, include_retired=True))
        self.assertNotIn("harrier_front", gate.canon_entries(ROOT))
        with self.assertRaisesRegex(ValueError, "not canon"):
            gate.make_kit(self.kit_args(peers=["harrier_front", "grave_surgeon_front"]))

    def test_rear_front_reference_is_unchanged_and_peers_match_view(self):
        args = self.kit_args(view="creature_rear", front_ref=FIXTURES / "hero_front.png")
        kit = gate.make_kit(args)
        self.assertEqual((Path(args.out_dir) / "refs/01_front_ref.png").read_bytes(), args.front_ref.read_bytes())
        self.assertEqual([ref.get("canon_id") for ref in kit["refs"][1:]],
                         ["hero_rear", "arc_thrall_rear", "grave_surgeon_rear"])

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

    def test_rear_consistency_uses_the_palette_match_non_accent_mask(self):
        front = Image.new("RGBA", (NON_ACCENT_FIXTURE_SIDE, NON_ACCENT_FIXTURE_SIDE), NON_ACCENT_FIXTURE_BODY)
        pixels = np.asarray(front).copy()
        x0, y0, x1, y1 = NON_ACCENT_FIXTURE_ACCENT_RECT
        pixels[y0:y1, x0:x1] = NON_ACCENT_FIXTURE_ACCENT
        front = Image.fromarray(pixels)
        rear = Image.new("RGBA", front.size, NON_ACCENT_FIXTURE_BODY)
        front_path, rear_path = self.temp / "accent_front.png", self.temp / "plain_rear.png"
        front.save(front_path)
        rear.save(rear_path)
        lab = gate.to_lab(pixels[..., :3].astype(float))
        mask = gate.non_accent_mask(lab, pixels[..., 3])
        prototype = runpy.run_path(str(ROOT / "spec/art_identity/prototype/match_palette.py"))["body_mask"]
        np.testing.assert_array_equal(mask, prototype(lab, pixels[..., 3]))
        self.assertFalse(mask[y0:y1, x0:x1].any())
        values = gate.rear_consistency(front_path, rear_path)
        self.assertAlmostEqual(values["chroma_delta"], 0.0)
        self.assertAlmostEqual(values["value_delta"], 0.0)
        rgb = pixels[..., :3] / 255.0
        whole_chroma = float((rgb.max(-1) - rgb.min(-1)).mean())
        self.assertGreater(whole_chroma - gate.non_accent_palette(front_path)["chroma"], 0.03)

    def test_prompt_reconstructs_generation_version_for_both_factors(self):
        for size_class in ("medium", "large"):
            args = self.kit_args(size_class, size_class=size_class)
            kit = gate.make_kit(args)
            prompt = (Path(args.out_dir) / "prompt.md").read_bytes()
            self.assertEqual(gate.prompt_kit_version(kit, prompt), kit["kit_version"])
            self.assertEqual(gate.kit_version_verification(kit, prompt), "prompt_reconstructed")
            self.assertIn(b"1024x1024", prompt)

    def test_job_certification_ignores_regenerable_reference_files_and_current_clauses(self):
        root, registry, entry = self.kit_registry()
        shutil.rmtree(root / "jobs/fixture/refs")
        (root / gate.IDENTITY / "preamble.md").write_text("A later legitimate preamble revision.\n")
        (root / gate.IDENTITY / "views.md").write_text("Later view clauses.\n")
        with patch.object(gate, "enlarged_ref", side_effect=AssertionError("Check must not regenerate references")), \
             patch.object(gate, "view_body", side_effect=AssertionError("Check must not read current clauses")):
            report, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(report))
        self.assertTrue(any("kit_version prompt_reconstructed" in line for line in report))
        # Even corrupt files in the ignored directory do not own provenance.
        path = root / "jobs/fixture/refs/01_hero_front.png"
        path.parent.mkdir()
        path.write_bytes(b"Ignored regenerable file")
        self.assertEqual(gate.check_registry(root)[1], 0)

    def test_irrecoverable_historical_version_uses_bound_recorded_field(self):
        root, registry, entry = self.kit_registry()
        path = root / entry["kit_path"]
        kit = gate.read_json(path)
        kit["kit_version"] = entry["kit_version"] = "c" * 64
        gate.write_json(path, kit)
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        report, failures = gate.check_registry(root)
        self.assertEqual(failures, 0, "\n".join(report))
        self.assertTrue(any("kit_version recorded" in line for line in report))
        (root / entry["prompt_path"]).write_text("Changed stored prompt")
        report, failures = gate.check_registry(root)
        self.assertGreater(failures, 0)
        self.assertTrue(any("prompt digest changed" in line for line in report))

    def test_committed_registry_has_no_pending_warnings_even_in_strict_mode(self):
        report, failures = gate.check_registry()
        self.assertEqual(failures, 0, "\n".join(report))
        self.assertEqual(sum(line.startswith("WARN ") for line in report), 0)
        report, failures = gate.check_registry(strict=True)
        self.assertEqual(failures, 0, "\n".join(report))

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
        for reference in canon["entries"] + canon.get("retired", []):
            target = root / reference["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / reference["path"], target)
        shutil.copyfile(FIXTURES / "hero_front.png", root / "jobs/fixture/sheet.png")
        shutil.copyfile(root / "assets/hero.png", root / "jobs/fixture/processed.png")
        source_digest = gate.pixel_digest(gate.rgba(root / "assets/hero.png"))
        gate.write_json(root / "jobs/fixture/processed.json", {"raw_sha256": "a" * 64, "pixel_sha256": source_digest})
        measured = gate.measure(root / "assets/hero.png")
        entry = dict(id="fixture", path="assets/hero.png", entry_kind="kit", kind="creature", anatomy="biped", size_class="medium",
                     kit_path="jobs/fixture/kit.json", job_id=kit["job_id"], kit_version=kit["kit_version"],
                     prompt_path="jobs/fixture/prompt.md", prompt_sha256=kit["prompt_sha256"],
                     ref_pixel_sha256=gate.recorded_ref_digests(kit), raw_sha256="a" * 64, sheet_path="jobs/fixture/sheet.png",
                     source_path="jobs/fixture/processed.png", source_pixel_sha256=source_digest, facing="front",
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

    def maquette_registry(self, rear=False):
        root, registry, entry = self.kit_registry()
        # Maquette jobs live in mq* folders (their refs/ is committed only there).
        shutil.move(str(root / "jobs/fixture"), str(root / "jobs/mq_fixture"))
        for key in ("kit_path", "prompt_path", "sheet_path", "source_path"):
            entry[key] = entry[key].replace("jobs/fixture/", "jobs/mq_fixture/")
        path = root / entry["kit_path"]
        kit = gate.read_json(path)
        kit["kit_kind"] = "maquette"
        kit["prompt_source"] = "spec/art_identity/maquettes/fixture_prompt.md"
        kit["job_id"] = entry["job_id"] = MAQUETTE_FIXTURE_JOB_ID
        kit.pop("peers")  # Maquette references have roles, not standard peer ordering.
        for ref, role, label in zip(kit["refs"], ("maquette_parts", "identity"), MAQUETTE_FIXTURE_REF_LABELS):
            ref.update(role=role, canon_id=label)
        kit["refs"][2]["role"] = "canon"
        for index, role in enumerate(("maquette_clay", "edit_source"), 4):
            file = "refs/%02d_%s.png" % (index, role)
            shutil.copyfile(path.parent / kit["refs"][0]["file"], path.parent / file)
            kit["refs"].append(dict(file=file, role=role, pixel_sha256=kit["refs"][0]["pixel_sha256"]))
        retired = gate.canon_entries(root, include_retired=True)["harrier_front"]
        file = "refs/06_harrier_front.png"
        shutil.copyfile(root / retired["path"], path.parent / file)
        kit["refs"].append(dict(file=file, role="canon", canon_id="harrier_front",
                                pixel_sha256=gate.pixel_digest(gate.rgba(path.parent / file))))
        if rear:
            kit["view"] = "creature_rear"
            entry["facing"] = "rear"
        kit["kit_version"] = entry["kit_version"] = gate.prompt_kit_version(kit, (root / entry["prompt_path"]).read_bytes())
        entry["ref_pixel_sha256"] = gate.recorded_ref_digests(kit)
        gate.write_json(path, kit)
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        return root, registry, entry, kit

    def test_maquette_requires_mq_folder_prompt_source_and_string_ref_files(self):
        root, registry, entry, kit = self.maquette_registry()
        kit_path = root / entry["kit_path"]
        report = lambda: "\n".join(gate.check_registry(root)[0])
        source, file = kit["prompt_source"], kit["refs"][0]["file"]
        kit["prompt_source"] = "elsewhere/prompt.md"
        gate.write_json(kit_path, kit)
        self.assertIn("maquette prompt_source must name a prompt under spec/art_identity/maquettes/", report())
        kit["prompt_source"], kit["refs"][0]["file"] = source, None
        gate.write_json(kit_path, kit)
        self.assertIn("FAIL assets/hero.png", report())  # reported per entry, never a crash
        kit["refs"][0]["file"] = file
        gate.write_json(kit_path, kit)
        shutil.move(str(root / "jobs/mq_fixture"), str(root / "jobs/maquette_fixture"))
        for key in ("kit_path", "prompt_path", "sheet_path", "source_path"):
            entry[key] = entry[key].replace("jobs/mq_fixture/", "jobs/maquette_fixture/")
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        self.assertIn("maquette job folder must be named mq*", report())

    def test_valid_maquette_front_and_rear_allow_active_and_retired_hand_references(self):
        for rear in (False, True):
            with self.subTest(rear=rear):
                root, registry, entry, kit = self.maquette_registry(rear)
                report, failures = gate.check_registry(root)
                self.assertEqual(failures, 0, "\n".join(report))
                self.assertTrue(any("kit_version prompt_ordered_refs" in line for line in report))
                shutil.rmtree(root)
                shutil.rmtree(self.temp / "kit")

    def test_maquette_reference_paths_roles_and_ids_are_enforced(self):
        cases = (("outside", "under refs/"), ("traversal", "under refs/"), ("absolute", "under refs/"),
                 ("missing_file", "reference missing"), ("missing_role", "role missing or unknown"),
                 ("unknown_role", "role missing or unknown"), ("unknown_canon", "canon reference has unknown id"),
                 ("reused_canon", "non-canon maquette reference reuses canon id"),
                 ("no_parts", "requires a maquette_parts reference"))
        for change, expected in cases:
            with self.subTest(change=change):
                root, registry, entry, kit = self.maquette_registry()
                ref = kit["refs"][0]
                if change == "outside": ref["file"] = "processed.png"
                elif change == "traversal": ref["file"] = "refs/../processed.png"
                elif change == "absolute": ref["file"] = str(root / entry["source_path"])
                elif change == "missing_file": ref["file"] = "refs/missing.png"
                elif change == "missing_role": del ref["role"]
                elif change == "unknown_role": ref["role"] = MAQUETTE_INVALID_ROLE
                elif change == "unknown_canon": kit["refs"][2]["canon_id"] = "unknown_canon"
                elif change == "reused_canon": ref["canon_id"] = "hero_front"
                elif change == "no_parts": ref["role"] = "maquette_clay"
                gate.write_json(root / entry["kit_path"], kit)
                report, failures = gate.check_registry(root)
                self.assertGreater(failures, 0)
                self.assertTrue(any(expected in line for line in report), "\n".join(report))
                shutil.rmtree(root)
                shutil.rmtree(self.temp / "kit")

    def test_maquette_reference_pixels_are_checked_even_when_record_bindings_match(self):
        root, registry, entry, kit = self.maquette_registry()
        kit["refs"][0]["pixel_sha256"] = "b" * 64
        kit["kit_version"] = entry["kit_version"] = gate.prompt_kit_version(kit, (root / entry["prompt_path"]).read_bytes())
        entry["ref_pixel_sha256"] = gate.recorded_ref_digests(kit)
        gate.write_json(root / entry["kit_path"], kit)
        gate.write_json(root / gate.IDENTITY / "registry.json", registry)
        report, failures = gate.check_registry(root)
        self.assertGreater(failures, 0)
        self.assertTrue(any("reference pixel digest changed" in line for line in report), "\n".join(report))

    def test_maquette_job_id_is_nonempty_and_matches_registry(self):
        for job in ("", " ", MAQUETTE_FIXTURE_JOB_ID + "-changed"):
            with self.subTest(job=job):
                root, registry, entry, kit = self.maquette_registry()
                kit["job_id"] = job
                gate.write_json(root / entry["kit_path"], kit)
                report, failures = gate.check_registry(root)
                self.assertGreater(failures, 0)
                self.assertTrue(any("job id missing or mismatched" in line for line in report))
                shutil.rmtree(root)
                shutil.rmtree(self.temp / "kit")

    def test_rear_maquette_requires_identity(self):
        root, registry, entry, kit = self.maquette_registry(rear=True)
        kit["refs"][1]["role"] = "edit_source"
        gate.write_json(root / entry["kit_path"], kit)
        report, failures = gate.check_registry(root)
        self.assertGreater(failures, 0)
        self.assertTrue(any("rear maquette requires an identity reference" in line for line in report))

    def test_maquette_version_rejects_reordered_refs_and_matching_but_unreproducible_fields(self):
        for change in ("order", "version"):
            with self.subTest(change=change):
                root, registry, entry, kit = self.maquette_registry()
                if change == "order": kit["refs"].reverse()
                else: kit["kit_version"] = entry["kit_version"] = "b" * 64
                gate.write_json(root / entry["kit_path"], kit)
                gate.write_json(root / gate.IDENTITY / "registry.json", registry)
                report, failures = gate.check_registry(root)
                self.assertGreater(failures, 0)
                self.assertTrue(any("kit_version does not reproduce" in line for line in report))
                shutil.rmtree(root)
                shutil.rmtree(self.temp / "kit")

    def test_maquette_keeps_prompt_sidecar_approval_and_landmark_checks(self):
        for change, expected in (("prompt", "recorded prompt digest"), ("source", "source pixel digest"),
                                 ("post_steps", "processed post_steps"), ("judge", "judge requires PASS"),
                                 ("approval", "owner_approval note missing"), ("landmarks", "lateral_axis=None")):
            with self.subTest(change=change):
                root, registry, entry, kit = self.maquette_registry()
                if change == "prompt": entry["prompt_sha256"] = "b" * 64
                elif change == "source": entry["source_pixel_sha256"] = "b" * 64
                elif change == "post_steps": entry["post_steps"] = [{"step": "unknown"}]
                elif change == "judge": entry["judge"]["verdict"] = "FAIL"
                elif change == "approval": entry["owner_approval"] = ""
                elif change == "landmarks": del entry["landmarks"]
                gate.write_json(root / gate.IDENTITY / "registry.json", registry)
                report, failures = gate.check_registry(root)
                self.assertGreater(failures, 0)
                self.assertTrue(any(expected in line for line in report), "\n".join(report))
                shutil.rmtree(root)
                shutil.rmtree(self.temp / "kit")

    def test_shrike_maquette_versions_reproduce_from_protected_jobs(self):
        approved = gate.read_json(ROOT / "spec/peer_benchmark/staged/reart/approved_sources.json")["enemies"]["gust_shrike"]
        for view in ("front", "rear"):
            with self.subTest(view=view):
                job = ROOT / approved[view]
                kit = gate.read_json(job / "kit.json")
                prompt = (job / kit["prompt_path"]).read_bytes()
                self.assertEqual(kit["kit_version"], gate.prompt_kit_version(kit, prompt))
                self.assertEqual(gate.kit_version_verification(kit, prompt), "prompt_ordered_refs")

    def test_kit_provenance_rejects_changed_prompt_refs_and_version(self):
        for change in ("prompt", "ref_record", "version"):
            with self.subTest(change=change):
                # Use isolated roots for each provenance failure.
                root, registry, entry = self.kit_registry()
                if change == "prompt":
                    (root / entry["prompt_path"]).write_text("Changed prompt")
                elif change == "ref_record":
                    path = root / entry["kit_path"]
                    kit = gate.read_json(path)
                    kit["refs"][0]["pixel_sha256"] = "b" * 64
                    gate.write_json(path, kit)
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
                self.assertEqual(len(ids), 17)  # 16 prior entries + one art-04 shrike per view
                self.assertIn("gust_shrike_" + view, ids)
                self.assertTrue({"crag_outcrop", "raised_cover", "watch_brazier"}.issubset(ids))
                subjects = [subject for call in render.call_args_list for subject in call.args[2]]
                self.assertEqual([subject[2] for subject in subjects], ids)
                by_id = {label: (image, scale) for image, scale, label in subjects}
                self.assertEqual(by_id["burrow_grub_" + view][1], 0.85)
                self.assertEqual(by_id["slag_mortar_" + view][1], 1.04)
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
