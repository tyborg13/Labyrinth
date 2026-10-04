"""Verify VP4 source provenance, keyed edges, mask levels and shipped geometry."""
import hashlib
import fnmatch
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art/ui/visual_pass_4"
sys.path.insert(0, str(ROOT / "tools"))
import process_visual_pass_4_assets as processor


class VisualPass4Assets(unittest.TestCase):
    def test_replacement_ring_geometry_is_measured_from_alpha(self):
        yy, xx = np.mgrid[:512, :512] + 0.5
        distance = np.hypot(xx - 256, yy - 256)
        for inner, colour in ((120, (168, 118, 66)), (182, (96, 78, 60))):
            with self.subTest(inner_radius=inner), tempfile.TemporaryDirectory(prefix=".vp4-asset-test-", dir=ROOT) as temporary:
                folder = Path(temporary)
                sources, output = folder / "sources", folder / "output"
                sources.mkdir()
                output.mkdir()
                rgb = np.zeros((512, 512, 3), dtype=np.uint8)
                rgb[:] = (0, 255, 0)
                rgb[(distance >= inner) & (distance < 210)] = colour
                Image.fromarray(rgb).save(sources / "medallion_ring.png")
                with mock.patch.object(processor, "SOURCES", sources), mock.patch.object(processor, "OUT", output):
                    image = processor.process_keyed("medallion_ring.png", 256, square=True)
                geometry = processor.ring_geometry(np.asarray(image)[..., 3])
                self.assertAlmostEqual(geometry["inner_radius"] / geometry["outer_radius"], inner / 210, delta=0.015)
                self.assertEqual(image.size, (256, 256))
                self.assertEqual(image.getpixel((128, 128))[3], 0)

    def test_runtime_geometry_is_in_every_export_preset(self):
        presets = (ROOT / "export_presets.cfg").read_text()
        filters = re.findall(r'^include_filter="([^"]*)"', presets, re.MULTILINE)
        self.assertEqual(len(filters), len(re.findall(r'^\[preset\.\d+\]$', presets, re.MULTILINE)))
        self.assertGreater(len(filters), 0)
        for index, include_filter in enumerate(filters):
            with self.subTest(preset=index):
                self.assertTrue(any(fnmatch.fnmatch("assets/art/ui/visual_pass_4/medallion_ring.json", pattern)
                                    for pattern in include_filter.split(",")))

    def test_approved_sources_match_readme(self):
        readme = (ROOT / "spec/assets/visual_pass_4/README.md").read_text()
        hashes = re.findall(r"\| `([^`]+\.png)` \| `([a-f0-9]{64})` \|", readme)
        self.assertEqual({name for name, _ in hashes}, {path.name for path in (ROOT / "spec/assets/visual_pass_4/sources").glob("*.png")})
        self.assertTrue({"shop_banner.png", "shelf_label.png"}.issubset(dict(hashes)))
        for name, expected in hashes:
            with self.subTest(source=name):
                source = ROOT / "spec/assets/visual_pass_4/sources" / name
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected)

    def test_production_alpha_and_sizes(self):
        for name in ("medallion_ring", "price_tag", "ink_pool_a", "ink_pool_b", "shop_banner", "shelf_label"):
            with self.subTest(asset=name), Image.open(OUT / f"{name}.png") as image:
                self.assertEqual(image.mode, "RGBA")
                pixels = np.asarray(image)
                alpha = pixels[..., 3]
                self.assertEqual(int(alpha.min()), 0)
                self.assertGreater(int(alpha.max()), 240)
                self.assertTrue(((alpha > 0) & (alpha < 255)).any())
                if name.startswith("ink_pool"):
                    self.assertEqual(image.width, 768)
                    self.assertTrue((pixels[..., :3] == 255).all())
                else:
                    if name in ("shop_banner", "shelf_label"):
                        self.assertEqual(image.width, 1100 if name == "shop_banner" else 360)
                        self.assertLess(image.height, image.width)
                    else:
                        self.assertEqual(image.height, 256)
                    visible = pixels[..., 3] > 0
                    rgb = pixels[..., :3].astype(float)
                    self.assertTrue((rgb[..., 1][visible] <= np.maximum(rgb[..., 0], rgb[..., 2])[visible] * 1.02 + 1).all())
                if name == "medallion_ring":
                    self.assertEqual(image.size, (256, 256))

    def test_signage_matches_keyed_cropped_premultiplied_pipeline(self):
        with tempfile.TemporaryDirectory(prefix=".vp4-signage-test-", dir=ROOT) as temporary:
            output = Path(temporary)
            with mock.patch.object(processor, "OUT", output):
                for name, width in (("shop_banner.png", 1100), ("shelf_label.png", 360)):
                    with self.subTest(asset=name):
                        derived = processor.process_keyed(name, width, target_width=True)
                        with Image.open(OUT / name) as shipped:
                            self.assertEqual(derived.size, shipped.size)
                            np.testing.assert_array_equal(np.asarray(derived), np.asarray(shipped))
                        alpha = np.asarray(derived)[..., 3]
                        ys, xs = np.where(alpha > 5)
                        self.assertLessEqual(xs.min(), 6)
                        self.assertLessEqual(alpha.shape[1] - 1 - xs.max(), 6)
                        self.assertLessEqual(ys.min(), 6)
                        self.assertLessEqual(alpha.shape[0] - 1 - ys.max(), 6)

    def test_ring_metadata_matches_shipped_alpha(self):
        metadata = json.loads((OUT / "medallion_ring.json").read_text())
        with Image.open(OUT / "medallion_ring.png") as image:
            self.assertEqual(metadata["size"], list(image.size))
            solid = np.asarray(image)[..., 3] > metadata["alpha_threshold"]
        cx, cy = metadata["center"]
        ys, xs = np.where(solid)
        self.assertEqual([cx, cy], [(xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2])
        self.assertFalse(solid[int(cy), int(cx)])
        inner, outer = metadata["inner_radius"], metadata["outer_radius"]
        self.assertTrue(0 < inner < outer < 128)
        measured_inner, measured_outer = [], []
        for angle in np.linspace(0, 2 * np.pi, 360, endpoint=False):
            radii = np.arange(0, 128, 0.25)
            x = (cx + np.cos(angle) * radii).astype(int)
            y = (cy + np.sin(angle) * radii).astype(int)
            hits = radii[solid[y, x]]
            self.assertGreater(len(hits), 0)
            measured_inner.append(hits.min())
            measured_outer.append(hits.max() + 0.25)
        self.assertAlmostEqual(inner, float(np.median(measured_inner)), delta=0.5)
        self.assertAlmostEqual(outer, float(np.median(measured_outer)), delta=0.5)
        self.assertEqual(metadata["source"], "spec/assets/visual_pass_4/sources/medallion_ring.png")


if __name__ == "__main__":
    unittest.main()
