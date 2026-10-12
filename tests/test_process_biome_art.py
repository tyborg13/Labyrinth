from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import process_biome_art as tool

RAW_DIR = Path("/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/biomes")
# Test-only sample stays below clipping at the approved 1.25 flash gain.
SPARK_GLOW_SAMPLE: tuple[int, int, int, int] = (180, 180, 180, 255)


def read_image(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


class BiomeArtTests(unittest.TestCase):
    def test_key_removes_green_and_antialiased_fringe(self):
        pixels = np.array([[[0, 255, 0, 255], [8, 240, 5, 255], [50, 180, 45, 255],
                            [60, 68, 55, 128], [150, 80, 30, 255]]], dtype=np.uint8)
        result = np.asarray(tool.key_green(Image.fromarray(pixels)))
        self.assertTrue((result[0, :3, 3] == 0).all())
        visible = result[..., 3] > 0
        self.assertTrue((result[..., 1][visible] <= np.maximum(result[..., 0], result[..., 2])[visible]).all())
        self.assertEqual(result[0, -1].tolist(), pixels[0, -1].tolist())

    def test_nearest_fill_and_template_alpha(self):
        repaint = Image.new("RGBA", (3, 3))
        repaint.putpixel((0, 0), (150, 60, 20, 255))
        repaint.putpixel((2, 2), (20, 60, 150, 255))
        template = Image.new("RGBA", (3, 3), (0, 0, 0, 128))
        result = tool.fit_repaint(repaint, template, True)
        self.assertEqual(result.getchannel("A").tobytes(), template.getchannel("A").tobytes())
        self.assertEqual(result.getpixel((1, 0))[:3], (150, 60, 20))
        self.assertEqual(result.getpixel((2, 1))[:3], (20, 60, 150))

    def test_variant_matching_and_raw_grade(self):
        floors = [Image.new("RGBA", (2, 2), (v, v, v, 255)) for v in (50, 90, 100, 180)]
        matched = tool.match_floors(floors)
        self.assertEqual([im.getpixel((0, 0))[0] for im in matched], [57, 95, 95, 153])
        graded = tool.grade(Image.new("RGBA", (1, 1), (200, 200, 200, 77)), [0.624, 0.600, 0.540])
        self.assertEqual(graded.getpixel((0, 0)), (125, 120, 108, 77))

    def test_idle_flicker_only_changes_glow_and_alternate_jitter(self):
        light = Image.new("RGBA", (4, 4))
        light.putpixel((1, 2), (240, 240, 240, 255))
        light.putpixel((2, 3), (30, 20, 10, 255))
        flame = tool.idle_sheet(light, (16, 16), "flame")
        glow = tool.idle_sheet(light, (16, 16), "glow")
        self.assertEqual(flame.getpixel((1, 2)), (206, 206, 206, 255))
        self.assertEqual(flame.getpixel((5, 1))[3], 255)
        self.assertEqual(glow.getpixel((5, 2))[3], 255)
        self.assertEqual(flame.getpixel((6, 3)), (30, 20, 10, 255))

    def test_spark_flashes_only_approved_frames_four_and_eleven(self):
        light = Image.new("RGBA", (4, 4))
        light.putpixel((1, 2), SPARK_GLOW_SAMPLE)
        light.putpixel((2, 3), (30, 20, 10, 255))
        sheet = tool.idle_sheet(light, (16, 16), "spark")
        for index in range(16):
            x, y = (index % 4) * 4, (index // 4) * 4
            self.assertEqual(sheet.getpixel((x + 1, y + 2)),
                             (225, 225, 225, 255) if index in (4, 11) else (162, 162, 162, 255))
            self.assertEqual(sheet.getpixel((x + 2, y + 3)), (30, 20, 10, 255))

    @unittest.skipUnless(RAW_DIR.exists(), "approved raw images unavailable; synthetic and shipped asset checks still run")
    def test_all_approved_outputs_determinism_alpha_density_sheet_and_mirror(self):
        data = json.loads((ROOT / "data/biomes.json").read_text())
        with tempfile.TemporaryDirectory(prefix="biome-art-test-") as scratch:
            for biome, definition in data["biomes"].items():
                if biome == "stone":
                    continue
                directory = Path(scratch) / biome
                report = tool.process_biome(RAW_DIR, biome, directory, definition)
                first = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.glob("*.png")}
                tool.process_biome(RAW_DIR, biome, directory, definition)
                self.assertEqual(first, {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.glob("*.png")})
                self.assertEqual(first, {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in (ROOT / "assets/art/biomes" / biome).glob("*.png")})
                self.assertEqual(len(first), 9)
                for name, values in report["outputs"].items():
                    self.assertIn("template_orphan_share", values)
                    image = read_image(directory / name)
                    if name.startswith("floor_") or name == "pillar.png":
                        path = "assets/placeholders/tiles/" + (name.replace("floor_", "base_floor_tile_") if name.startswith("floor_") else name)
                        template = read_image(ROOT / path)
                        self.assertEqual(image.size, template.size)
                        self.assertEqual(image.getchannel("A").tobytes(), template.getchannel("A").tobytes())
                        # Native 5% threshold from the board-density contract.
                        self.assertLessEqual(values["orphan_share"], 0.05)
                    pixels = np.asarray(image)
                    visible = pixels[..., 3] > 0
                    self.assertFalse(((pixels[..., 1].astype(int) > np.maximum(pixels[..., 0], pixels[..., 2]).astype(int) + 16) & visible).any())
                for side in ("left", "right"):
                    stone = read_image(ROOT / f"assets/art/tiles/column_torch_{side}_idle.png")
                    self.assertEqual(read_image(directory / f"light_{side}_idle.png").size, stone.size)
                    self.assertEqual(read_image(directory / f"light_{side}.png").size, (66, 121))
                left = read_image(directory / "light_left_idle.png")
                right = read_image(directory / "light_right_idle.png")
                for x, y, w, h in tool.density.frame_rects(left.size, {"grid": [4, 4]}):
                    box = (x, y, x+w, y+h)
                    self.assertEqual(ImageOps.mirror(left.crop(box)).tobytes(), right.crop(box).tobytes())


if __name__ == "__main__":
    unittest.main()
