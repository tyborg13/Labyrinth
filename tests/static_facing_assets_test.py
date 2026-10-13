#!/usr/bin/env python3
"""Approved art-03 source, portrait, scale and density integration contracts."""
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from process_en03_enemy_assets import resize
from process_board_density import derive, load_registry, pixel_digest

APPROVED = json.loads((ROOT / 'spec/peer_benchmark/staged/reart/approved_sources.json').read_text())['enemies']
CROPS = json.loads((ROOT / 'spec/peer_benchmark/staged/reart/portrait_crops.json').read_text())['crops']
# Proof-only contact layout, matching the required exact 2x comparison.
CONTACT_ROW_HEIGHT = 290
CONTACT_APPROVED_X = 300
CONTACT_IMAGE_Y = 25
PORTRAIT_SIZE = (128, 128)
CONTACT_PORTRAIT_SIZE = (256, 256)


class ApprovedArtTests(unittest.TestCase):
    def test_exact_approved_sources_and_density_outputs(self):
        density = {e['id']: e for e in load_registry()['entries']}
        registry = json.loads((ROOT / 'spec/art_identity/registry.json').read_text())
        entries = {e['path']: e for e in registry['entries']}
        count = 0
        for name, approved in APPROVED.items():
            for facing in ('front', 'rear'):
                if facing not in approved:
                    continue
                suffix = '_rear' if facing == 'rear' else ''
                path = f'assets/art/enemies/{name}{suffix}.png'
                source = ROOT / approved[facing] / 'processed.png'
                record = entries[path]
                with Image.open(source) as image:
                    source_digest = pixel_digest(image)
                with Image.open(ROOT / 'spec/assets/board_pixel_density/sources' / path) as image:
                    self.assertEqual(pixel_digest(image), source_digest)
                self.assertEqual(record['source_path'], str(source.relative_to(ROOT)))
                self.assertEqual(record['source_pixel_sha256'], source_digest)
                expected, manifest = derive(density[name + suffix], path)
                with Image.open(ROOT / path) as image:
                    self.assertEqual(image.convert('RGBA').tobytes(), expected.tobytes())
                    self.assertEqual(image.size, (255, 255))
                self.assertEqual(record['pixel_sha256'], manifest['pixel_sha256'])
                self.assertEqual(record['post_steps'], json.loads(source.with_suffix('.json').read_text()).get('post_steps', []))
                count += 1
        self.assertEqual(count, 23)  # 12 fronts (11 art-03 + gust_shrike) + 11 rears (storm_capacitor has none)

    def test_portraits_follow_protected_crops_and_existing_processor(self):
        with Image.open(ROOT / 'tests/static_facing_portrait_contact.png') as image:
            contact = image.convert('RGB')
        for index, (name, approved) in enumerate(APPROVED.items()):
            cx, cy, side = CROPS[name]
            with Image.open(ROOT / approved['front'] / 'processed.png') as image:
                left, top = cx - side // 2, cy - side // 2
                expected = resize(image.crop((left, top, left + side, top + side)), PORTRAIT_SIZE)
            with Image.open(ROOT / f'assets/art/portraits/{name}.png') as image:
                self.assertEqual(image.size, PORTRAIT_SIZE)
                self.assertEqual(image.convert('RGBA').tobytes(), expected.tobytes())
            proof = Image.new('RGBA', CONTACT_PORTRAIT_SIZE, '#242020')
            proof.alpha_composite(expected.resize(CONTACT_PORTRAIT_SIZE, Image.Resampling.NEAREST))
            y = index * CONTACT_ROW_HEIGHT + CONTACT_IMAGE_Y
            actual = contact.crop((CONTACT_APPROVED_X, y, CONTACT_APPROVED_X + CONTACT_PORTRAIT_SIZE[0], y + CONTACT_PORTRAIT_SIZE[1]))
            self.assertEqual(actual.tobytes(), proof.convert('RGB').tobytes())

    def test_scales_rear_paths_and_no_remaining_pending_entry(self):
        enemies = json.loads((ROOT / 'data/enemies.json').read_text())
        for name, approved in APPROVED.items():
            self.assertEqual(enemies[name]['art_scale'], approved['art_scale'])
            if 'rear' in approved:
                self.assertEqual(enemies[name]['art_rear_path'], f'res://assets/art/enemies/{name}_rear.png')
            else:
                self.assertNotIn('art_rear_path', enemies[name])
        registry = json.loads((ROOT / 'spec/art_identity/registry.json').read_text())
        pending = [e['id'] for e in registry['entries'] if e['entry_kind'] == 'pending_reart']
        self.assertEqual(pending, [])


if __name__ == '__main__':
    unittest.main()
