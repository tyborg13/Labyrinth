"""Headless checks of en-05's protected data and approved-asset registration."""
from pathlib import Path
import hashlib
import json
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from process_board_density import derive, pixel_digest
from process_en03_enemy_assets import resize
from process_en05_enemy_assets import PORTRAIT_CANVAS, PORTRAIT_TOP

RAW = Path('/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art')
ENEMIES = ('glacial_mirror', 'gust_shrike')
ICONS = ('reflect', 'dive', 'flying')


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

    def test_registered_art_and_portraits(self):
        density = json.loads((ROOT / 'spec/assets/board_pixel_density/registry.json').read_text())
        density_entries = {entry['id']: entry for entry in density['entries']}
        identity = json.loads((ROOT / 'spec/art_identity/registry.json').read_text())
        identity_entries = {entry['path']: entry for entry in identity['entries']}
        crops = json.loads((ROOT / 'spec/peer_benchmark/staged/reart/portrait_crops.json').read_text())['crops']
        for name in ENEMIES:
            with self.subTest(enemy=name):
                path = f'assets/art/enemies/{name}.png'
                expected, record = derive(density_entries[name], path)
                with Image.open(ROOT / path) as board:
                    self.assertEqual(pixel_digest(board), record['pixel_sha256'])
                    self.assertEqual(board.convert('RGBA').tobytes(), expected.tobytes())
                entry = identity_entries[path]
                self.assertEqual(entry['id'], name)
                with Image.open(ROOT / f'assets/art/portraits/{name}.png') as portrait:
                    self.assertEqual(portrait.size, (PORTRAIT_CANVAS, PORTRAIT_CANVAS))
                    self.assertEqual(portrait.mode, 'RGBA')
                    self.assertIsNotNone(portrait.getchannel('A').getbbox())
                    if entry['entry_kind'] == 'kit':
                        self.assertEqual(entry['pixel_sha256'], record['pixel_sha256'])
                        kit = json.loads((ROOT / entry['kit_path']).read_text())
                        self.assertEqual(entry['kit_version'], kit['kit_version'])
                        with Image.open(ROOT / entry['source_path']) as source:
                            self.assertEqual(pixel_digest(source), entry['source_pixel_sha256'])
                            bounds = source.getchannel('A').getbbox()
                            self.assertEqual(bounds[3] - bounds[1], kit['target_h'])
                            cx, cy, side = crops[name]
                            left, top = cx - side // 2, cy - side // 2
                            expected_portrait = resize(source.crop((left, top, left + side, top + side)), portrait.size)
                        self.assertEqual(portrait.tobytes(), expected_portrait.tobytes())
                    else:
                        # Gust Shrike retains its en-05 registration pending re-art.
                        self.assertEqual(entry['entry_kind'], 'pending_reart')
                        self.assertEqual(portrait.getchannel('A').getbbox()[1], PORTRAIT_TOP)

    def test_density_registry_additions(self):
        registry = json.loads((ROOT / 'spec/assets/board_pixel_density/registry.json').read_text())
        entries = {entry['id']: entry for entry in registry['entries']}
        for name in ENEMIES:
            self.assertEqual(entries[name]['paths'], [f'assets/art/enemies/{name}.png'])
            self.assertTrue((ROOT / 'spec/assets/board_pixel_density/sources' / entries[name]['paths'][0]).is_file())


if __name__ == '__main__':
    unittest.main()
