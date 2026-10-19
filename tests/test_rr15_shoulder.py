"""Reopen the director's three native shoulder holes with the retained texture."""
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/arc_thrall')]
from cutout_pipeline.cases import read_json
from humanoid_cutout.cpu_pose import CpuPose
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import interior_donors, rules
from maquette_motion.pixels import rest_identity
from rr15_cpu_proof import CASE, frame_state
from rr15_shoulder_proof import BEFORE

# Exact canvas pixels retained in the director's native holes sheet.
NATIVE_HOLES = {('tether', 61): [(234, 192), (235, 192)],
                ('jab', 26): [(242, 190), (243, 190)],
                ('jab', 27): [(242, 190), (243, 190)]}


class ShoulderContinuationTests(unittest.TestCase):
    def test_material_is_added_only_beneath_the_rest_torso(self):
        layout = read_json(CASE / 'layouts/rear.json')
        part = next(p for p in layout['parts'] if p['name'] == 'hidden_upper_near')
        before = np.asarray(Image.open(BEFORE).convert('RGBA'))
        current = np.asarray(Image.open(CASE / part['file']).convert('RGBA'))
        original = before[..., 3] > 0
        self.assertTrue(np.array_equal(current[original], before[original]))
        added = (current[..., 3] > 0) & ~original
        self.assertTrue(added.any())
        torso = source_pixels(CASE, next(p for p in layout['parts'] if p['name'] == 'torso'))
        left, top, right, bottom = part['bbox']
        self.assertTrue((torso[top:bottom, left:right, 3][added] > 0).all())
        own = source_pixels(CASE, next(p for p in layout['parts'] if p['name'] == 'upper_near'))
        donors = interior_donors(own, rules(CASE / 'rear_baseline', 'rear'))
        palette = set(map(tuple, donors[donors[..., 3] > 0]))
        self.assertTrue(all(tuple(pixel) in palette for pixel in current[added]))
        self.assertTrue(rest_identity(CASE)['ok'])
        production = PROJECT / 'assets/units/arc_thrall_cutout/humanoid_v2/rear/hidden_upper_near.png'
        density = PROJECT / 'spec/assets/board_pixel_density/sources' / production.relative_to(PROJECT)
        self.assertEqual(production.read_bytes(), (CASE / part['file']).read_bytes())
        self.assertEqual(density.read_bytes(), production.read_bytes())

    def test_all_three_holes_close_and_removing_the_cover_reopens_them(self):
        model = CpuPose(CASE, read_json(CASE / 'layouts/rear.json'))
        overrides = {p['name']: model.image(p['file']).copy() for p in model.layout['parts']}
        overrides['hidden_upper_near'] = np.asarray(Image.open(BEFORE).convert('RGBA'))
        samples = read_json(CASE / 'proof/samples.json')['samples']
        for (clip, frame), pixels in NATIVE_HOLES.items():
            with self.subTest(clip=clip, frame=frame):
                pose = next(r for r in samples if r['view'] == 'rear' and r['kind'] == 'presented'
                            and r['clip'] == clip and r['frame'] == frame)
                after, before = frame_state(model, pose), frame_state(model, pose, overrides)
                self.assertEqual(after[-1], [])
                self.assertEqual(before[-1], [2])
                for x, y in pixels:
                    self.assertGreater(after[1][y, x], 0)
                    self.assertEqual(before[1][y, x], 0)


if __name__ == '__main__':
    unittest.main()
