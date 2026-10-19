"""Director negative-space rule: source air passes, damaged paint never does."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools')]
from humanoid_cutout.source_space import PaintedComponents, pocket_report, apply_painted_components
from humanoid_cutout.silhouette_gates import detached_metrics
from humanoid_cutout.gates import clean_metrics
from humanoid_cutout.native_exceptions import frame_errors, DETACHED_RULE
from maquette_motion import pixels

FIXTURE_SIZE = 255
FIXTURE_DISPLACEMENT_PX = 8
FIXTURE_DARK_TIP_RGBA = [10, 10, 10, 255]
FIXTURE_BRIGHT_TIP_RGBA = [100, 60, 40, 255]


class SourceSpaceTests(unittest.TestCase):
    def test_review_connected_tip_cannot_detach_even_when_dark_or_skinned(self):
        for skinned in (False, True):
            with tempfile.TemporaryDirectory(prefix='rr25-detached-') as folder:
                root = Path(folder)
                paint = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), dtype=np.uint8)
                paint[10:25, 10:25] = FIXTURE_BRIGHT_TIP_RGBA
                paint[10, 25:27] = FIXTURE_DARK_TIP_RGBA
                for name in ('rest.png', 'part.png'):
                    Image.fromarray(paint).save(root / name)
                part = {'name': 'arm', 'file': 'part.png', 'offset': [0, 0],
                        'z_index': 0, 'bone': 'upper'}
                layout = {'rest_source': 'rest.png', 'parts': [part],
                          'joint_meshes': [{'name': 'arm'}] if skinned else []}
                pose = {'parts': {'arm': {'transform': [1, 0, 0, 1, 0, 0]}}}
                policy = PaintedComponents(root, layout)
                checks = np.zeros_like(paint)
                checks[paint[..., 3] > 0] = [255, 0, 0, 255]
                checks = pixels.render(Image.fromarray(checks), np.eye(3))
                for rgba in (FIXTURE_BRIGHT_TIP_RGBA, FIXTURE_DARK_TIP_RGBA):
                    with self.subTest(skinned=skinned, rgba=rgba):
                        mutant = paint.copy()
                        mutant[10, 25] = 0  # Remove the originally painted bridge.
                        mutant[10, 26] = rgba
                        layers = [(part, pixels.render(Image.fromarray(mutant), np.eye(3)), checks)]
                        certified = policy.report(layers, pose)
                        self.assertEqual(certified, [])
                        metric = apply_painted_components(clean_metrics(layers), certified)
                        self.assertEqual(metric['exempt_outline_components'], 0)
                        self.assertEqual(metric['stray_components'], 1)
                        self.assertEqual(metric['stray_pixels'], 1)
                        if rgba == FIXTURE_DARK_TIP_RGBA:
                            legacy = detached_metrics(layers[0][1])
                            self.assertEqual(legacy['exempt_outline_components'], 1)
                            with self.assertRaisesRegex(ValueError, 'strict detached metrics'):
                                apply_painted_components(legacy, certified)
                        spaces = pocket_report(layers)
                        errors = frame_errors(('front', 'death', 0), metric, spaces['failures'])
                        self.assertIn("('front', 'death', 0): " + DETACHED_RULE, errors)

    def test_natural_air_reports_each_bound(self):
        paint = np.zeros((12, 12, 4), dtype=np.uint8)
        paint[2:10, 2:10] = [100, 60, 40, 255]
        paint[4:7, 4:7] = 0
        checks = paint.copy()
        checks[checks[..., 3] > 0] = [255, 0, 0, 255]
        result = pocket_report([({}, paint, checks)])
        self.assertEqual(result['failures'], [])
        self.assertEqual(result['air_pockets'], [{'bbox': [4, 4, 7, 7], 'pixel_count': 9,
                         'painted_or_tuck_pixels': 0, 'joint_tear': False}])

    def test_single_missing_painted_or_tuck_texel_fails(self):
        for continuation in (0, 255):
            paint = np.zeros((12, 12, 4), dtype=np.uint8)
            paint[2:10, 2:10] = [100, 60, 40, 255]
            checks = paint.copy()
            checks[checks[..., 3] > 0] = [255, continuation, 0, 255]
            paint[5, 5] = 0
            result = pocket_report([({}, paint, checks)])
            self.assertEqual(result['air_pockets'], [])
            self.assertEqual(result['failures'][0]['pixel_count'], 1)
            self.assertEqual(result['failures'][0]['painted_or_tuck_pixels'], 1)

    def test_joint_tear_never_becomes_air(self):
        paint = np.zeros((12, 12, 4), dtype=np.uint8)
        paint[2:10, 2:10] = [100, 60, 40, 255]
        paint[4:7, 4:7] = 0
        checks = paint.copy()
        checks[checks[..., 3] > 0] = [255, 0, 0, 255]
        result = pocket_report([({}, paint, checks)], [{'bbox': [4, 4, 7, 7], 'pixel_count': 9}])
        self.assertEqual(result['air_pockets'], [])
        self.assertTrue(result['failures'][0]['joint_tear'])

    def component_fixture(self, root, *, connected=False, skinned=False, dark=False):
        paint = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), dtype=np.uint8)
        paint[10:25, 10:25] = [100, 60, 40, 255]
        paint[10:12, 34:36] = [30, 20, 10, 255] if dark else [100, 60, 40, 255]
        if connected:
            paint[10, 25:34] = [100, 60, 40, 255]
        Image.fromarray(paint).save(root / 'rest.png')
        # Source painting and source cuts are independent inputs. A mutant cut
        # may detach material that was connected in the approved painting.
        paint[10, 25:34] = 0
        Image.fromarray(paint).save(root / 'part.png')
        part = {'name': 'head', 'logical_part': 'head', 'file': 'part.png',
                'offset': [0, 0], 'bone': 'head', 'z_index': 0}
        layout = {'rest_source': 'rest.png', 'parts': [part],
                  'joint_meshes': [{'name': 'head'}] if skinned else []}
        transform = np.eye(3)
        transform[0, 2] = FIXTURE_DISPLACEMENT_PX
        pose = {'parts': {'head': {'transform': [1, 0, 0, 1, FIXTURE_DISPLACEMENT_PX, 0]}}}
        presented = pixels.render(Image.fromarray(paint), transform)
        return layout, pose, [(part, presented, presented.copy())]

    def test_painted_detached_component_follows_rigid_owner(self):
        with tempfile.TemporaryDirectory(prefix='rr22-space-') as folder:
            root = Path(folder)
            layout, pose, layers = self.component_fixture(root)
            policy = PaintedComponents(root, layout)
            accepted = policy.report(layers, pose)
            self.assertEqual(len(accepted), 1)
            self.assertEqual(accepted[0]['owner'], 'head')
            metric = apply_painted_components(detached_metrics(layers[0][1], allow_outline=False), accepted)
            self.assertEqual(metric['stray_components'], 0)
            self.assertEqual(metric['stray_pixels'], 0)
            frozen = copy.deepcopy(pose)
            frozen['parts']['head']['transform'][4] = 0
            self.assertEqual(policy.report(layers, frozen), [])

    def test_cut_induced_component_and_skinned_island_fail(self):
        for options in ({'connected': True}, {'skinned': True}):
            with self.subTest(options=options), tempfile.TemporaryDirectory(prefix='rr22-space-') as folder:
                root = Path(folder)
                layout, pose, layers = self.component_fixture(root, **options)
                self.assertEqual(PaintedComponents(root, layout).report(layers, pose), [])
                self.assertEqual(detached_metrics(layers[0][1], allow_outline=False)['stray_components'], 1)

    def test_unrelated_stray_does_not_borrow_certification(self):
        with tempfile.TemporaryDirectory(prefix='rr22-space-') as folder:
            root = Path(folder)
            layout, pose, layers = self.component_fixture(root)
            layers[0][1][170:174, 170:174] = [90, 50, 30, 255]
            accepted = PaintedComponents(root, layout).report(layers, pose)
            metric = apply_painted_components(detached_metrics(layers[0][1], allow_outline=False), accepted)
            self.assertEqual(metric['stray_components'], 1)
            self.assertEqual(metric['stray_pixels'], 16)
            self.assertEqual(metric['exempt_outline_components'], 0)

    def test_painted_outline_is_not_subtracted_from_unrelated_stray(self):
        with tempfile.TemporaryDirectory(prefix='rr22-space-') as folder:
            root = Path(folder)
            layout, pose, layers = self.component_fixture(root)
            for name in ('rest.png', 'part.png'):
                paint = np.asarray(Image.open(root / name).convert('RGBA')).copy()
                paint[10:12, 34:36] = 0
                paint[10:12, 26] = [30, 20, 10, 255]
                Image.fromarray(paint).save(root / name)
            transform = pixels.unpack(pose['parts']['head']['transform'])
            presented = pixels.render(Image.fromarray(paint), transform)
            presented[170:174, 170:174] = [90, 50, 30, 255]
            layers = [(layers[0][0], presented, presented.copy())]
            accepted = PaintedComponents(root, layout).report(layers, pose)
            self.assertEqual(len(accepted), 1)
            metric = apply_painted_components(detached_metrics(presented, allow_outline=False), accepted)
            self.assertEqual(metric['stray_components'], 1)
            self.assertEqual(metric['stray_pixels'], 16)
            self.assertEqual(metric['exempt_outline_components'], 0)


if __name__ == '__main__':
    unittest.main()
