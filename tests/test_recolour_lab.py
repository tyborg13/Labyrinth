#!/usr/bin/env python3
"""Deterministic colour replay, alpha protection, CLI and provenance contracts."""
import contextlib
import copy
import io
import json
from pathlib import Path
import runpy
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import recolour_lab as tool

# Synthetic, test-only samples and repository identities.
FIXTURE_SEED = 1302026
FIXTURE_SIDE = 23
FIXTURE_COMMIT = "a" * 40
FIXTURE_PIXELS = ((181, 142, 110, 255), (140, 110, 83, 128), (4, 250, 90, 1), (11, 221, 39, 0))
FIXTURE_RECOLOURED_PIXEL = (137, 105, 80, 255)


class RecolourLabTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.temp = Path(directory.name).resolve()

    def test_pixel_identical_to_director_prototype(self):
        prototype = runpy.run_path(str(ROOT / "spec/art_identity/prototype/match_palette.py"))
        rng = np.random.default_rng(FIXTURE_SEED)
        pixels = rng.integers(0, 256, (FIXTURE_SIDE, FIXTURE_SIDE, 4), dtype=np.uint8)
        pixels[0, :4] = FIXTURE_PIXELS
        painted = pixels[..., 3] > 0
        expected = pixels.copy()
        lab = prototype["to_lab"](pixels[painted, :3].astype(float))
        lab[:, 0] *= 0.76
        lab[:, 1:] *= 0.85
        expected[painted, :3] = np.clip(np.rint(prototype["from_lab"](lab)), 0, 255).astype(np.uint8)
        actual = np.asarray(tool.recolour(Image.fromarray(pixels), 0.76, 0.85))
        np.testing.assert_array_equal(actual, expected)
        np.testing.assert_array_equal(actual[..., 3], pixels[..., 3])
        np.testing.assert_array_equal(actual[~painted], pixels[~painted])
        self.assertFalse(np.array_equal(actual[0, 2, :3], pixels[0, 2, :3]))

    def test_known_rounding_reference_and_determinism(self):
        source = Image.new("RGBA", (1, 1), FIXTURE_PIXELS[0])
        first = tool.recolour(source, 0.76, 0.85)
        self.assertEqual(first.getpixel((0, 0)), FIXTURE_RECOLOURED_PIXEL)
        self.assertEqual(first.tobytes(), tool.recolour(source, 0.76, 0.85).tobytes())
        self.assertGreater(tool.palette(source)["value"], tool.palette(first)["value"])

    def test_empty_paint_retains_hidden_pixels_and_reports_null(self):
        source = Image.new("RGBA", (2, 2), FIXTURE_PIXELS[-1])
        self.assertEqual(source.tobytes(), tool.recolour(source, 0.76, 0.85).tobytes())
        self.assertEqual(tool.palette(source), {"value": None, "chroma": None})

    def test_reject_modes_and_invalid_scales(self):
        for mode in ("RGB", "P", "L", "LA"):
            image = Image.new(mode, (1, 1))
            path = self.temp / (mode + ".png")
            image.save(path)
            with self.assertRaisesRegex(ValueError, "non-RGBA"):
                tool.read_rgba(path)
            with self.assertRaisesRegex(ValueError, "non-RGBA"):
                tool.recolour(image, 0.76, 0.85)
        for value in (-1, float("nan"), float("inf")):
            for scales in ((value, 0.85), (0.76, value)):
                with self.assertRaisesRegex(ValueError, "finite and nonnegative"):
                    tool.recolour(Image.new("RGBA", (1, 1)), *scales)
        with self.assertRaisesRegex(ValueError, "non-finite"):
            tool.recolour(Image.new("RGBA", (1, 1), (255, 255, 255, 255)), sys.float_info.max, 0.85)

    def test_cli_dry_run_write_and_batch_refusal(self):
        path = self.temp / "paint.png"
        Image.new("RGBA", (2, 2), FIXTURE_PIXELS[0]).save(path)
        original = path.read_bytes()
        args = ["--l-scale", "0.76", "--ab-scale", "0.85", str(path)]
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            self.assertEqual(tool.main(args), 0)
        self.assertEqual(path.read_bytes(), original)
        report = json.loads(stdout.getvalue())
        self.assertFalse(report["written"])
        self.assertLess(report["after"]["value"], report["before"]["value"])
        invalid = self.temp / "invalid.png"
        Image.new("RGB", (1, 1)).save(invalid)
        with self.assertRaises(ValueError):
            tool.main(["--in-place", *args, str(invalid)])
        self.assertEqual(path.read_bytes(), original)
        with self.assertRaisesRegex(ValueError, "duplicate"):
            tool.main(["--in-place", *args, str(path)])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tool.main(["--in-place", *args]), 0)
        self.assertEqual(tool.read_rgba(path).getpixel((0, 0)), FIXTURE_RECOLOURED_PIXEL)

    def test_source_replay_and_density_derivation_reject_unrecorded_edits(self):
        entry = {"id": "crawler", "paths": ["paint/body.png"], "mode": "regrid", "grid": 1.73,
                 "frames": None, "measurement_path": "paint/rest.png",
                 "rest_paths": {"front": ["paint/rest.png"]}}
        registry = {"hero_reference": "paint/hero.png", "entries": [entry]}
        before = Image.new("RGBA", (FIXTURE_SIDE, FIXTURE_SIDE), FIXTURE_PIXELS[0])
        before.putpixel((0, 0), FIXTURE_PIXELS[-1])
        sources = self.temp / "sources"
        for p in ["paint/body.png", "paint/rest.png"]:
            path = sources / p
            path.parent.mkdir(parents=True, exist_ok=True)
            tool.recolour(before, 0.76, 0.85).save(path)
        for p in tool.CRAWLER_DIRECT_PATHS:
            path = self.temp / p
            path.parent.mkdir(parents=True, exist_ok=True)
            tool.recolour(before, 0.76, 0.85).save(path)
        manifest_path = self.temp / "outputs.json"
        with patch.object(tool, "ROOT", self.temp), \
             patch.multiple(tool.density, ROOT=self.temp, SOURCES=sources, MANIFEST=manifest_path), \
             patch.object(tool.density, "load_registry", return_value=registry), \
             patch.object(tool, "baseline_bytes", return_value=json.dumps(registry).encode()), \
             patch.object(tool, "baseline_image", return_value=before):
            output, record = tool.density.derive(entry, entry["paths"][0])
            path = self.temp / entry["paths"][0]
            path.parent.mkdir(parents=True, exist_ok=True)
            output.save(path)
            manifest_path.write_text(json.dumps({entry["paths"][0]: record}))
            self.assertEqual(tool.crawler_inputs(FIXTURE_COMMIT)[0], entry)
            source_path = sources / entry["paths"][0]
            original = source_path.read_bytes()
            changed = tool.read_rgba(source_path)
            changed.putpixel((0, 0), (1, 2, 3, 0))
            changed.save(source_path)
            with self.assertRaisesRegex(ValueError, "source does not replay"):
                tool.crawler_inputs(FIXTURE_COMMIT)
            source_path.write_bytes(original)
            before.save(path)
            with self.assertRaisesRegex(ValueError, "stale crawler density paint"):
                tool.crawler_inputs(FIXTURE_COMMIT)
            entry["grid"] = 2.0
            with self.assertRaisesRegex(ValueError, "density settings changed"):
                tool.crawler_inputs(FIXTURE_COMMIT)

    def test_cli_requires_explicit_transform_or_fixed_baseline(self):
        for args in ([], ["--l-scale", "0.76", "missing.png"], ["--check-crawler"],
                     ["--record-crawler", "--baseline-ref", FIXTURE_COMMIT, "--in-place"],
                     ["--prepare-proof", "--baseline-ref", FIXTURE_COMMIT, "--paint-only"]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as failure:
                tool.main(args)
            self.assertEqual(failure.exception.code, 2)

    def registry_fixture(self):
        static = tool.CRAWLER_DIRECT_PATHS[0]
        rests = ["assets/units/crawler_cutout/front/rest.png", "assets/units/crawler_cutout/rear/rest.png"]
        before = Image.new("RGBA", (2, 2), FIXTURE_PIXELS[0])
        before.putpixel((0, 0), FIXTURE_PIXELS[-1])
        digest = tool.gate.pixel_digest(before)
        old = {"version": 1, "entries": [dict(id="crawler", entry_kind="legacy", path=p,
               metrics={"value": 0.3}, pixel_sha256=digest) for p in [static, *rests]]}
        old["entries"].append(dict(id="untouched", path="other.png", pixel_sha256="protected"))
        path = self.temp / "spec/art_identity/registry.json"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(old, indent=2) + "\n")
        for paint in [static, *rests]:
            target = self.temp / paint
            target.parent.mkdir(parents=True, exist_ok=True)
            tool.recolour(before, 0.76, 0.85).save(target)
        entry = {"id": "crawler", "rest_paths": {"front": rests[:1], "rear": rests[1:]}}
        return path, old, before, entry

    def test_registry_records_replay_and_keeps_adoption_and_other_entries(self):
        path, old, before, entry = self.registry_fixture()
        with patch.object(tool, "ROOT", self.temp), \
             patch.object(tool, "crawler_inputs", return_value=(entry, {})), \
             patch.object(tool.density, "rest_errors", return_value=[]), \
             patch.object(tool, "baseline_bytes", return_value=json.dumps(old).encode()), \
             patch.object(tool, "baseline_image", return_value=before), \
             contextlib.redirect_stdout(io.StringIO()):
            tool.crawler_registry(FIXTURE_COMMIT, False, True)
            tool.crawler_registry(FIXTURE_COMMIT, False, False)
            recorded = json.loads(path.read_text())
            self.assertEqual(recorded["entries"][-1], old["entries"][-1])
            self.assertEqual(recorded["entries"][0]["metrics"], old["entries"][0]["metrics"])
            for current in recorded["entries"][:-1]:
                self.assertEqual(current["post_steps"], [tool.crawler_step()])
                self.assertEqual(current["recolour_baseline"]["pixel_sha256"], tool.gate.pixel_digest(before))
            for field, value in (("post_steps", []), ("pixel_sha256", "invented"),
                                 ("recolour_baseline", {"commit": "other"}), ("metrics", {"value": 1})):
                modified = copy.deepcopy(recorded)
                modified["entries"][0][field] = value
                path.write_text(json.dumps(modified))
                with self.assertRaises(ValueError):
                    tool.crawler_registry(FIXTURE_COMMIT, False, False)

    def test_record_refuses_stale_rests_before_registry_write(self):
        path, old, before, entry = self.registry_fixture()
        original = path.read_bytes()
        with patch.object(tool, "crawler_inputs", return_value=(entry, {})), \
             patch.object(tool.density, "rest_errors", return_value=["native rebake needed"]):
            with self.assertRaisesRegex(ValueError, "native rebake needed"):
                tool.crawler_registry(FIXTURE_COMMIT, False, True)
        self.assertEqual(path.read_bytes(), original)

    def test_registry_refuses_substituted_previous_digest(self):
        path, old, before, entry = self.registry_fixture()
        original = path.read_bytes()
        old["entries"][0]["pixel_sha256"] = "invented"
        with patch.object(tool, "ROOT", self.temp), \
             patch.object(tool, "crawler_inputs", return_value=(entry, {})), \
             patch.object(tool, "baseline_bytes", return_value=json.dumps(old).encode()), \
             patch.object(tool, "baseline_image", return_value=before):
            with self.assertRaisesRegex(ValueError, "previous legacy digest"):
                tool.crawler_registry(FIXTURE_COMMIT, True, True)
        self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
