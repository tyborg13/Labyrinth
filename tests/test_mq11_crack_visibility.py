"""Registered crack stroke coverage and hair-depth visibility, without Blender."""
from copy import deepcopy
import unittest
from unittest.mock import patch

import numpy as np

from spec.art_identity.maquettes.hollow_mimic.owner_review import measurements
from spec.art_identity.maquettes.hollow_mimic.owner_review.candidate import compile_candidate, GATES
from spec.art_identity.maquettes.raster import camera

CRACK_FIXTURE = {'size': 100, 'source_size': 100,
                 'feature': {'source_path_px': [[20.5, 30.5], [20.5, 79.5], [70.5, 79.5]], 'stroke_width_px': 1.},
                 'wide_stroke_px': 3., 'source_scale': 2,
                 'hair_depth': 1., 'mask_depth': 0., 'behind_depth': -1.,
                 'expected_crack_pixels': 100, 'passing_visible_pixels': 85, 'hidden_pixels': 98,
                 'registered_width_source_px': 2., 'occluder_depth_offset_m': .01}


def hair_quads(spec, mask, pixels):
    """Actual body-space triangles that cover the selected front-view pixels."""
    matrix, target, basis, scale = camera(spec, 'front')
    vertices, faces = [], []
    for y, x in zip(*np.where(pixels)):
        depth = mask[y, x] + CRACK_FIXTURE['occluder_depth_offset_m']
        quad = np.array([[x, y, depth], [x + 1, y, depth],
                         [x + 1, y + 1, depth], [x, y + 1, depth]], float)
        coords = np.column_stack(((quad[:, 0] / len(mask) - .5) * scale,
                                  (.5 - quad[:, 1] / len(mask)) * scale, quad[:, 2]))
        world = coords @ basis + target
        body = (world - matrix[:3, 3]) @ np.linalg.inv(matrix[:3, :3]).T
        start = len(vertices)
        vertices.extend(body.tolist())
        faces.append([start, start + 1, start + 2, start + 3])
    return {'vertices': vertices, 'faces': faces}


class RegisteredTriangleCrackTests(unittest.TestCase):
    def setUp(self):
        self.spec = compile_candidate('hollow_mimic')
        piece = next(p for p in self.spec['pieces'] if p['id'] == 'cracked_mask')
        self.mask_mesh = {'vertices': piece['outline_3d'], 'faces': [list(range(len(piece['outline_3d'])))]}
        self.mask = measurements.depth_image(self.spec, self.mask_mesh, 'front')
        self.feature = measurements.registered_crack(self.spec)
        # Only this fixture substitutes a synthetic width. Registration and all
        # projection, depth sampling and final measure() calls remain real.
        self.feature['stroke_width_px'] = CRACK_FIXTURE['registered_width_source_px']
        ys = np.flatnonzero(np.isfinite(self.mask).any(axis=1))
        self.top, self.bottom = int(ys[0]), int(ys[-1]) + 1
        cutoff = self.top + (self.bottom - self.top) * GATES['fringe_mask_top_fraction']
        self.fringe = np.isfinite(self.mask) & (np.arange(len(self.mask))[:, None] + .5 < cutoff)

    def report(self, pixels):
        meshes = {'hair_crown': hair_quads(self.spec, self.mask, pixels), 'cracked_mask': self.mask_mesh}
        with patch.object(measurements, 'registered_crack', return_value=self.feature):
            return measurements.measure(self.spec, meshes)

    def test_real_registered_path_is_visible_under_a_top_band_only_fringe(self):
        report = self.report(self.fringe)
        self.assertTrue(report['passed'])
        self.assertGreaterEqual(report['visible_crack_fraction'], .85)
        self.assertTrue(report['checks']['lower_mask_remains_visible'])
        print('MQ11_CRACK_TRIANGLE_FIXTURE: top_band_only; pixels=' + str(report['registered_crack_pixels']) +
              '; visible=' + str(report['visible_crack_pixels']) + '; passed=true')

    def test_real_triangles_hide_98_percent_of_registered_crack_while_midpoints_stay_clear(self):
        crack = measurements.stroke_pixels(self.feature['source_path_px'], self.feature['stroke_width_px'],
                                             GATES['native_size'], measurements.RECIPE_DEFAULTS['source_size'])
        clear_midpoints = np.zeros_like(crack)
        start = self.top + (self.bottom - self.top) / 3
        end = self.top + 2 * (self.bottom - self.top) / 3
        for y in np.flatnonzero(np.isfinite(self.mask).any(axis=1)):
            if start <= y + .5 < end:
                xs = np.flatnonzero(np.isfinite(self.mask[y]))
                clear_midpoints[y, xs[len(xs) // 2]] = True
        pixels = self.fringe | (crack & np.isfinite(self.mask) & ~clear_midpoints)
        self.assertFalse((pixels & clear_midpoints).any())
        report = self.report(pixels)
        self.assertGreaterEqual(1 - report['visible_crack_fraction'], .98)
        for check in ('rear_height', 'fringe_over_mask_top', 'lower_mask_remains_visible'):
            self.assertTrue(report['checks'][check], check)
        self.assertFalse(report['checks']['crack_band_remains_visible'])
        self.assertFalse(report['passed'])
        print('MQ11_CRACK_TRIANGLE_FIXTURE: hidden_over_98_percent; pixels=' + str(report['registered_crack_pixels']) +
              '; visible=' + str(report['visible_crack_pixels']) + '; passed=false; mask_midpoints_clear=true')


class RegisteredCrackTests(unittest.TestCase):
    def setUp(self):
        self.feature = deepcopy(CRACK_FIXTURE['feature'])
        size = CRACK_FIXTURE['size']
        self.mask = np.full((size, size), CRACK_FIXTURE['mask_depth'])
        self.hair = np.full_like(self.mask, -np.inf)

    def report(self):
        return measurements.crack_visibility(self.feature, self.hair, self.mask, CRACK_FIXTURE['source_size'])

    def test_top_band_fringe_keeps_the_actual_crack_visible(self):
        cutoff = int(len(self.mask) * measurements.GATES['fringe_mask_top_fraction'])
        self.hair[:cutoff] = CRACK_FIXTURE['hair_depth']
        report = self.report()
        self.assertTrue(report['passed'])
        self.assertEqual(report['registered_crack_pixels'], CRACK_FIXTURE['expected_crack_pixels'])
        self.assertEqual(report['visible_crack_fraction'], 1.)

    def test_98_percent_hidden_crack_fails_despite_visible_mask_midpoints(self):
        pixels = measurements.stroke_pixels(self.feature['source_path_px'], self.feature['stroke_width_px'],
                                              len(self.mask), CRACK_FIXTURE['source_size'])
        y, x = np.where(pixels)
        hidden = CRACK_FIXTURE['hidden_pixels']
        self.hair[y[:hidden], x[:hidden]] = CRACK_FIXTURE['hair_depth']
        self.assertTrue(np.isneginf(self.hair[len(self.mask) // 3:2 * len(self.mask) // 3, len(self.mask) // 2]).all())
        report = self.report()
        self.assertFalse(report['passed'])
        self.assertEqual(report['visible_crack_pixels'], 2)
        self.assertEqual(1 - report['visible_crack_fraction'], .98)

    def test_eighty_five_percent_is_inclusive_and_one_more_hidden_pixel_fails(self):
        pixels = measurements.stroke_pixels(self.feature['source_path_px'], self.feature['stroke_width_px'],
                                              len(self.mask), CRACK_FIXTURE['source_size'])
        y, x = np.where(pixels)
        visible = CRACK_FIXTURE['passing_visible_pixels']
        self.hair[y[visible:], x[visible:]] = CRACK_FIXTURE['hair_depth']
        report = self.report()
        self.assertEqual(report['visible_crack_fraction'], .85)
        self.assertTrue(report['passed'])
        self.hair[y[visible - 1], x[visible - 1]] = CRACK_FIXTURE['hair_depth']
        self.assertFalse(self.report()['passed'])

    def test_hair_behind_the_mask_does_not_hide_the_crack(self):
        self.hair[:] = CRACK_FIXTURE['behind_depth']
        self.assertEqual(self.report()['visible_crack_fraction'], 1.)

    def test_stroke_width_and_source_registration_scale_are_used(self):
        thin = measurements.stroke_pixels(self.feature['source_path_px'], self.feature['stroke_width_px'],
                                           len(self.mask), CRACK_FIXTURE['source_size'])
        wide = measurements.stroke_pixels(self.feature['source_path_px'], CRACK_FIXTURE['wide_stroke_px'],
                                           len(self.mask), CRACK_FIXTURE['source_size'])
        self.assertGreater(wide.sum(), thin.sum())
        self.assertTrue(np.all(wide[thin]))
        factor = CRACK_FIXTURE['source_scale']
        scaled = measurements.stroke_pixels(np.array(self.feature['source_path_px']) * factor,
                                             self.feature['stroke_width_px'] * factor,
                                             len(self.mask), CRACK_FIXTURE['source_size'] * factor)
        np.testing.assert_array_equal(scaled, thin)

    def test_missing_nonpositive_or_empty_registration_cannot_pass(self):
        for width in (0., -1., float('nan')):
            self.feature['stroke_width_px'] = width
            with self.subTest(width=width), self.assertRaisesRegex(ValueError, 'positive measured'):
                self.report()
        self.feature.pop('stroke_width_px')
        with self.assertRaises(KeyError):
            self.report()
        self.feature['stroke_width_px'] = CRACK_FIXTURE['feature']['stroke_width_px']
        self.feature['source_path_px'] = []
        with self.assertRaisesRegex(ValueError, 'finite source polyline'):
            self.report()

    def test_unresolved_width_is_rejected_instead_of_using_a_fixture_default(self):
        self.feature['stroke_width_px'] = 'TODO_DESIGN_FIXTURE_CRACK_STROKE_WIDTH'
        with self.assertRaisesRegex(ValueError, 'TODO_DESIGN_FIXTURE_CRACK_STROKE_WIDTH'):
            self.report()


if __name__ == '__main__':
    unittest.main()
