"""Director feedback 3 thresholds and native far-elbow regression proof."""
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest
from humanoid_cutout.gates import clean_metrics
from humanoid_cutout.silhouette_gates import (
    OWNER_IDS, JOINT_PAIRS, detached_metrics, joined_boundary, joint_holes, posed_owners)
from maquette_motion.silhouette import dilate

# Debug-only threshold fixtures; no production art or tuning.
FIXTURE_SIZE_PX = 24
FIXTURE_BODY_SLICE = slice(5, 19)
FIXTURE_BODY_RGBA = (60, 70, 80, 255)
FIXTURE_OUTLINE_RGBA = (18, 18, 23, 255)
FIXTURE_LUMA_BELOW_RGBA = (30, 30, 30, 255)
FIXTURE_LUMA_ABOVE_RGBA = (31, 31, 31, 255)
BOUNDARY_FIXTURE_SIZE_PX = 12
BOUNDARY_FIXTURE_HOLE = (slice(4, 6), slice(4, 7))


class SilhouetteGateTests(unittest.TestCase):
    def body(self):
        image = np.zeros((FIXTURE_SIZE_PX, FIXTURE_SIZE_PX, 4), dtype=np.uint8)
        image[FIXTURE_BODY_SLICE, FIXTURE_BODY_SLICE] = FIXTURE_BODY_RGBA
        return image

    def test_outline_exemption_size_colour_and_distance_boundaries(self):
        image = self.body()
        image[3, 8:10] = FIXTURE_OUTLINE_RGBA  # Exactly 2 px from main.
        self.assertEqual(detached_metrics(image), {
            'stray_components': 0, 'stray_pixels': 0, 'exempt_outline_components': 1})
        for change in ('third_pixel', 'bright_pixel', 'one_bright_pixel', 'too_far'):
            with self.subTest(change=change):
                mutant = image.copy()
                if change == 'third_pixel': mutant[3, 10] = FIXTURE_OUTLINE_RGBA
                if change == 'bright_pixel': mutant[3, 8:10] = FIXTURE_LUMA_ABOVE_RGBA
                if change == 'one_bright_pixel': mutant[3, 8] = FIXTURE_LUMA_ABOVE_RGBA
                if change == 'too_far':
                    mutant[3, 8:10] = 0; mutant[2, 8:10] = FIXTURE_OUTLINE_RGBA
                self.assertEqual(detached_metrics(mutant)['stray_components'], 1)
        # Distance is between components, rather than every pixel in each.
        mutant = image.copy(); mutant[3, 9] = 0; mutant[2, 8] = FIXTURE_OUTLINE_RGBA
        self.assertEqual(detached_metrics(mutant)['stray_components'], 0)
        mutant = image.copy(); mutant[3, 8:10] = FIXTURE_LUMA_BELOW_RGBA
        self.assertEqual(detached_metrics(mutant)['stray_components'], 0)
        # Any other detached component fails, including clusters above 8 px.
        mutant = self.body(); mutant[1, 6:15] = FIXTURE_OUTLINE_RGBA
        self.assertEqual(detached_metrics(mutant)['stray_pixels'], 9)

    def test_exemption_uses_visible_layer_colour(self):
        image = self.body(); image[3, 8] = FIXTURE_OUTLINE_RGBA
        front = np.zeros_like(image); front[3, 8] = [60, 70, 80, 255]
        checks = np.zeros_like(image); checks[..., 0] = checks[..., 3] = 255
        layers = [({'z_index': 0}, image, checks), ({'z_index': 1}, front, checks)]
        self.assertEqual(clean_metrics(layers)['stray_components'], 1)
        self.assertEqual(clean_metrics(layers[::-1])['stray_components'], 1)

    def opening(self):
        occupied = np.ones((BOUNDARY_FIXTURE_SIZE_PX, BOUNDARY_FIXTURE_SIZE_PX), dtype=bool)
        hole = np.zeros_like(occupied); hole[BOUNDARY_FIXTURE_HOLE] = True
        occupied[hole] = False  # Ten four-neighbour boundary pixels.
        boundary = np.argwhere(dilate(hole, 1) & occupied)
        return occupied, hole, boundary

    def test_eighty_percent_is_inclusive_and_requires_both_joined_owners(self):
        occupied, hole, boundary = self.opening()
        for pair in JOINT_PAIRS:
            owners = np.full(occupied.shape, OWNER_IDS['hand_near'], dtype=np.uint8)
            a, b = map(OWNER_IDS.get, pair)
            # A third owner explicitly outside the chosen pair.
            neighbours = {name for joined in JOINT_PAIRS if set(joined) & set(pair) for name in joined}
            outsider = next(OWNER_IDS[name] for name in OWNER_IDS
                            if name not in neighbours and name != 'staff')
            owners[:] = outsider
            for y, x in boundary[:7]: owners[y, x] = a
            y, x = boundary[7]; owners[y, x] = b
            with self.subTest(pair=pair):
                self.assertTrue(joined_boundary(hole, occupied, owners))
                owners[y, x] = outsider
                self.assertFalse(joined_boundary(hole, occupied, owners))
        owners[:] = OWNER_IDS['upper_far']
        self.assertFalse(joined_boundary(hole, occupied, owners))

    def test_staff_and_unjoined_negative_space_remain_free(self):
        occupied, hole, boundary = self.opening()
        owners = np.full(occupied.shape, OWNER_IDS['fore_far'], dtype=np.uint8)
        owners[6:] = OWNER_IDS['hand_far']
        self.assertTrue(joined_boundary(hole, occupied, owners))
        y, x = boundary[0]; owners[y, x] = OWNER_IDS['staff']
        self.assertFalse(joined_boundary(hole, occupied, owners))
        owners[:] = OWNER_IDS['robe']; owners[6:] = OWNER_IDS['hand_near']
        self.assertFalse(joined_boundary(hole, occupied, owners))
        self.assertEqual(joint_holes(occupied, hole, owners), [])

    def test_native_far_elbow_three_pixel_gap_still_fails(self):
        folder = PROJECT / 'tests/rr10/feedback3'
        record = json.loads((folder / 'capture.json').read_text())
        for name, row in record['files'].items():
            self.assertEqual(digest(folder / name), row['sha256'])
        image = np.array(Image.open(folder / 'sleeve_far.png').convert('RGBA'))
        seam = np.array(Image.open(folder / 'elbow_seam.png').convert('RGBA'))[..., 3] > 0
        parts = [{'name': 'sleeve_far', 'logical_part': 'sleeve_far'}]
        row = {'name': 'sleeve_far', 'z_index': 0}
        def check(paint):
            owners = posed_owners([(row, paint, None)], parts, record['bones'], record['source_offset'])
            return joint_holes(paint[..., 3] > 0, seam, owners)
        self.assertEqual(check(image), [])
        x, y = record['elbow_gap_centre']; radius = record['elbow_gap_width_px'] // 2
        mutant = image.copy()
        region = (slice(y-radius, y+radius+1), slice(x-radius, x+radius+1))
        self.assertTrue((mutant[region][..., 3] == 255).all())
        mutant[region] = 0
        self.assertEqual(check(mutant), [9])


if __name__ == '__main__':
    unittest.main()
