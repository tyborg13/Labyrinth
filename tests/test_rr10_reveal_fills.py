"""rr-13 source regressions; native mesh seam acceptance stays windowed."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.gates import source_errors, dark_slab_blocks
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.pixels import rest_identity

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
# Observed source texels absent at a9d6c7b5e, not player-facing parameters.
FIXTURE_SLEEVE_XY = {'front': (106, 149), 'rear': (160, 128)}
FIXTURE_MOVE_HEM_XY = (169, 236)


def read(path):
    return json.loads(path.read_bytes())


def mask(path):
    with Image.open(path) as image:
        return np.asarray(image).copy() > 0


class RevealFillTests(unittest.TestCase):
    def supplied(self, layout, name):
        images = [source_pixels(CASE, p) for p in layout['parts'] if p['logical_part'] == name]
        supplied = np.zeros_like(images[0])
        for image in images:
            supplied[image[..., 3] > 0] = image[image[..., 3] > 0]
        return supplied

    def remove(self, view, layout, name, target):
        with tempfile.TemporaryDirectory(prefix='rr13-reveal-mutation-') as folder:
            case = Path(folder) / 'case'
            shutil.copytree(CASE, case, ignore=shutil.ignore_patterns('proof'))
            for part in layout['parts']:
                if part['logical_part'] != name:
                    continue
                image = source_pixels(case, part)
                image[target] = 0
                x, y, right, bottom = part['bbox']
                Image.fromarray(image[y:bottom, x:right]).save(case / part['file'])
            self.assertIn('tuck: missing actual texels: ' + name,
                          source_errors(case, layout, read(CASE / 'proof/build.json')))

    def test_full_sleeve_footprints_have_cloth_in_both_views_and_removal_fails(self):
        for view in ('front', 'rear'):
            layout = read(CASE / f'layouts/{view}.json')
            definition = rules(CASE, view)
            for name in ('torso', 'robe'):
                with self.subTest(view=view, piece=name):
                    target = mask(CASE / layout['covered_surface_masks'][name])
                    self.assertTrue(target.any())
                    supplied = self.supplied(layout, name)
                    self.assertTrue((supplied[target, 3] == 255).all())
                    dark = outline_class(supplied, definition) & target
                    self.assertFalse(dark.any())
                    self.assertEqual(dark_slab_blocks(dark), 0)
                    self.remove(view, layout, name, target)
            x, y = FIXTURE_SLEEVE_XY[view]
            self.assertTrue(mask(CASE / layout['covered_surface_masks']['torso'])[y, x])
            self.assertEqual(self.supplied(layout, 'torso')[y, x, 3], 255)
        self.assertEqual(rest_identity(CASE)['views']['front']['different_pixels'], 0)
        self.assertEqual(rest_identity(CASE)['views']['rear']['different_pixels'], 0)

    def test_move_step_has_covered_hem_continuation_and_removal_fails(self):
        layout = read(CASE / 'layouts/front.json')
        target = mask(CASE / layout['covered_surface_masks']['hem'])
        x, y = FIXTURE_MOVE_HEM_XY
        self.assertTrue(target[y, x])
        supplied = self.supplied(layout, 'robe')
        self.assertEqual(supplied[y, x, 3], 255)
        # It is behind the rigid boot at rest and follows the existing robe
        # field in move; no second independently animated hem is introduced.
        boot = self.supplied(layout, 'foot_near')
        self.assertEqual(boot[y, x, 3], 255)
        underlay = next(m for m in layout['joint_meshes'] if m['name'] == 'hidden_robe')
        robe = next(m for m in layout['joint_meshes'] if m['name'] == 'robe')
        self.assertEqual(underlay['weight_bounds'], robe['bbox'])
        self.remove('front', layout, 'robe', target)


if __name__ == '__main__':
    unittest.main()
