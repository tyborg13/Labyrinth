"""Headless checks of en-05's protected data and approved-asset registration."""
from pathlib import Path
import hashlib
import json
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = Path('/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art')
ENEMIES = ('glacial_mirror', 'gust_shrike')
ICONS = ('reflect', 'dive', 'flying')
HEIGHT_RATIOS = {'glacial_mirror': 1.15, 'gust_shrike': .85}
ROUNDING_TOLERANCE_PIXELS = 1 # Integer raster registration only.


class En05Assets(unittest.TestCase):
    def test_protected_data(self):
        authored = json.loads((ROOT / 'spec/peer_benchmark/staged/enemies/wave_e2.json').read_text())
        production = json.loads((ROOT / 'data/enemies.json').read_text())
        for name in ENEMIES:
            self.assertEqual(production[name], authored[name])

    def test_approved_sources_and_dimensions(self):
        expected = dict((line.split()[1], line.split()[0]) for line in
                        (ROOT / 'spec/peer_benchmark/staged/enemies/raw_sha256.txt').read_text().splitlines())
        for family, names, dimensions in [('enemies', ENEMIES, (255, 255)), ('icons', ICONS, (64, 64))]:
            for name in names:
                source = RAW / family / f'{name}.png'
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), expected[f'{family}/{name}.png'])
                image = Image.open(ROOT / f'assets/art/{family}/{name}.png')
                self.assertEqual(image.size, dimensions)
                self.assertEqual(image.mode, 'RGBA')
                self.assertIsNotNone(image.getchannel('A').getbbox())

    def test_baseline_height_and_portraits(self):
        baseline = Image.open(ROOT / 'assets/art/enemies/chainbound_gaoler.png').getchannel('A').getbbox()[3]
        hero = Image.open(ROOT / 'assets/units/protagonist_cutout/front/front_assembled_rest_v9.png').getchannel('A').getbbox()
        for name in ENEMIES:
            bounds = Image.open(ROOT / f'assets/art/enemies/{name}.png').getchannel('A').getbbox()
            self.assertEqual(bounds[3], baseline)
            self.assertLessEqual(abs(bounds[3] - bounds[1] - round((hero[3] - hero[1]) * HEIGHT_RATIOS[name])), ROUNDING_TOLERANCE_PIXELS)
            portrait = Image.open(ROOT / f'assets/art/portraits/{name}.png')
            self.assertEqual(portrait.size, (128, 128))
            self.assertEqual(portrait.getchannel('A').getbbox()[1], 8)

    def test_density_registry_additions(self):
        registry = json.loads((ROOT / 'spec/assets/board_pixel_density/registry.json').read_text())
        entries = {entry['id']: entry for entry in registry['entries']}
        for name in ENEMIES:
            self.assertEqual(entries[name]['paths'], [f'assets/art/enemies/{name}.png'])
            self.assertTrue((ROOT / 'spec/assets/board_pixel_density/sources' / entries[name]['paths'][0]).is_file())


if __name__ == '__main__':
    unittest.main()
