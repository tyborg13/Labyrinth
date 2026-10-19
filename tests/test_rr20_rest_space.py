"""Generic spec §1 source-air and rigid detached-paint mutations."""
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from humanoid_cutout.rest_space import DetachedSource, pockets
from maquette_motion import pixels

FIXTURE_SIZE_PX = 32
FIXTURE_COLOR = [70, 60, 90, 255]
FIXTURE_SHIFT_PX = 4
FIXTURE_TURN_RADIANS = .3


class RestSpaceTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='rr20-rest-space-')
        self.addCleanup(self.folder.cleanup)
        self.case = Path(self.folder.name)
        self.paint = np.zeros((FIXTURE_SIZE_PX, FIXTURE_SIZE_PX, 4), dtype=np.uint8)
        self.paint[10:24, 10:24] = FIXTURE_COLOR
        self.paint[4:6, 12] = FIXTURE_COLOR
        Image.fromarray(self.paint).save(self.case / 'rest.png')
        self.checks = np.zeros_like(self.paint)
        self.checks[self.paint[..., 3] > 0] = [255, 0, 0, 255]
        Image.fromarray(self.checks).save(self.case / 'checks.png')
        self.part = {'name': 'head', 'logical_part': 'head', 'offset': [0, 0], 'z_index': 0}
        self.layout = {'rest_source': 'rest.png', 'parts': [self.part], 'joint_meshes': [],
                       'proof_layers': {'head': {'mask': 'checks.png', 'mask_offset': [0, 0]}}}
        self.transform = np.eye(3)

    def layer(self, paint=None):
        image = pixels.render(self.paint if paint is None else paint, self.transform)
        checks = pixels.render(self.checks, self.transform)
        return [(self.part, image, checks)]

    def detached(self, layers=None, transforms=None):
        matrix = [self.transform[0, 0], self.transform[1, 0], self.transform[0, 1],
                  self.transform[1, 1], *self.transform[:2, 2]]
        return DetachedSource(self.case, self.layout).report(
            self.layer() if layers is None else layers, {'head': matrix} if transforms is None else transforms)

    def test_source_detached_speck_moves_rigidly_with_owner(self):
        for turn in (0, FIXTURE_TURN_RADIANS):
            c, s = np.cos(turn), np.sin(turn)
            self.transform[:2, :2] = [[c, -s], [s, c]]
            self.transform[:2, 2] = FIXTURE_SHIFT_PX
            report = self.detached()
            self.assertEqual(report['metrics']['stray_components'], 0)
            self.assertEqual(report['source_components'][0]['piece'], 'head')
            self.assertEqual(report['source_components'][0]['source_bbox'], [12, 4, 13, 6])

    def test_novel_identical_coloured_speck_fails(self):
        mutant = self.paint.copy(); mutant[3, 25] = FIXTURE_COLOR
        report = self.detached(self.layer(mutant))
        self.assertEqual(report['metrics']['stray_components'], 1)

    def test_shifted_or_stretched_source_speck_fails(self):
        for extra in (False, True):
            mutant = self.paint.copy()
            if extra:
                mutant[3, 12] = FIXTURE_COLOR
            else:
                mutant[4:6, 12] = 0; mutant[4:6, 13] = FIXTURE_COLOR
            self.assertEqual(self.detached(self.layer(mutant))['metrics']['stray_components'], 1)

    def test_wrong_owner_and_missing_independent_transform_fail(self):
        layers = self.layer()
        renamed = [(dict(row, name='other'), image, checks) for row, image, checks in layers]
        self.assertEqual(self.detached(renamed)['metrics']['stray_components'], 1)
        self.assertEqual(self.detached(transforms={})['metrics']['stray_components'], 1)

    def test_isolated_piece_component_is_not_a_detached_painting_component(self):
        source = self.paint.copy(); source[5:11, 12] = FIXTURE_COLOR
        Image.fromarray(source).save(self.case / 'rest.png')
        self.assertEqual(self.detached()['metrics']['stray_components'], 1)

    def test_skinned_or_hidden_piece_cannot_authorize_rigid_speck(self):
        for key, value in (('joint_meshes', [{'name': 'head'}]),
                           ('parts', [dict(self.part, hidden_material=True)])):
            original = self.layout[key]; self.layout[key] = value
            self.assertEqual(self.detached()['metrics']['stray_components'], 1)
            self.layout[key] = original

    def test_air_reports_every_pocket_with_bounds(self):
        paint = self.paint.copy(); paint[14:16, 14:16] = 0; paint[20, 20] = 0
        checks = self.checks.copy(); checks[paint[..., 3] == 0] = 0
        report = pockets([(self.part, paint, checks)])
        self.assertEqual(report['failures'], [])
        self.assertEqual(report['air_pockets'], [
            {'bbox': [14, 14, 16, 16], 'pixel_count': 4},
            {'bbox': [20, 20, 21, 21], 'pixel_count': 1}])

    def test_one_missing_painted_pixel_rejects_whole_pocket(self):
        paint = self.paint.copy(); paint[14:16, 14:16] = 0
        checks = self.checks.copy(); checks[14:16, 14:16] = 0; checks[14, 14] = [255, 0, 0, 255]
        report = pockets([(self.part, paint, checks)])
        self.assertEqual(report['air_pockets'], [])
        self.assertEqual(report['failures'][0]['painted_or_tuck_pixels_by_piece'], {'head': 1})

    def test_missing_tuck_and_absent_rim_owner_cannot_hide_hole(self):
        paint = self.paint.copy(); paint[14:16, 14:16] = 0
        checks = self.checks.copy(); checks[14:16, 14:16] = 0
        tuck = np.zeros_like(checks); tuck[14, 14] = [0, 255, 0, 255]
        layers = [(self.part, paint, checks),
                  ({'name': 'missing', 'z_index': -1}, np.zeros_like(paint), tuck)]
        report = pockets(layers)
        self.assertEqual(report['failures'][0]['painted_or_tuck_pixels_by_piece'], {'missing': 1})

    def test_joint_tearing_and_single_pixel_missing_surface_fail(self):
        for section in ((slice(14, 16), slice(14, 16)), (slice(14, 15), slice(14, 15))):
            paint = self.paint.copy(); paint[section] = 0
            report = pockets([(self.part, paint, self.checks)])
            self.assertEqual(len(report['failures']), 1)
            self.assertEqual(report['air_pockets'], [])


if __name__ == '__main__': unittest.main()
