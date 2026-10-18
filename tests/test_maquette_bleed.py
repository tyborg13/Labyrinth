"""Support-bleed geometry, protection and edge-colour regressions."""
from pathlib import Path
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import write_json
from maquette_motion.bleed import domains, edge_texels
from maquette_motion.seam_support import connected_extension
from maquette_motion.seam_support import repair
from maquette_motion import silhouette
from cutout_pipeline.cases import read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components

FIXTURE_LEFT_RGBA = (71, 42, 19, 255)
FIXTURE_RIGHT_RGBA = (29, 53, 91, 255)
FIXTURE_SEPARATION_PX = 3


class BleedTests(unittest.TestCase):
    def test_real_repair_closes_a_joint_gap_without_changing_rest(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            rows = []
            for view in ('front', 'rear'):
                body = np.zeros((255, 255), bool)
                body[10:30, 10:40] = True
                left, right = np.zeros_like(body), np.zeros_like(body)
                left[11:29, 11:24], right[11:29, 24:39] = True, True
                parts = []
                for name, mask, bone, z in [('left', left, 'left', 0), ('right', right, 'right', 1),
                                            ('border', body & ~left & ~right, 'border', 2),
                                            ('hidden_left', left, 'left', -1)]:
                    image = np.zeros((255, 255, 4), np.uint8)
                    image[mask] = FIXTURE_LEFT_RGBA
                    file = view + '_' + name + '.png'
                    Image.fromarray(image).save(case / file)
                    parts.append(dict(name=name, bone=bone, z_index=z, file=file, offset=[0, 0], bbox=[0, 0, 255, 255],
                                      **({'hidden_material': True} if name.startswith('hidden') else {})))
                source = np.zeros((255, 255, 4), np.uint8)
                source[body] = FIXTURE_LEFT_RGBA
                (case / f'source/{view}').mkdir(parents=True)
                Image.fromarray(source).save(case / f'source/{view}/processed.png')
                write_json(case / f'layouts/{view}.json', {'parts': parts, 'rest_source': f'source/{view}/processed.png'})
                rows.append({'view': view, 'clip': 'fixture', 'frame': 0, 'phase': 0, 'presented_phase': 0, 'parts': {
                    p['name']: {'transform': [1, 0, 0, 1, FIXTURE_SEPARATION_PX if p['bone'] == 'right' else 0, 0], 'alpha': 1}
                    for p in parts}})
            samples = {'samples': rows}
            before = silhouette.pose_report(case, samples)
            self.assertTrue(all(r['new_hole_pixels'] == 54 for r in before['poses']))
            proof = repair(case, samples)
            self.assertEqual(sum(j['accepted_pixels'] for j in proof['joints']), 108)
            self.assertTrue(silhouette.pose_report(case, samples)['ok'])
            self.assertTrue(silhouette.part_report(case)['ok'])
            for view in ('front', 'rear'):
                composed = np.zeros((255, 255, 4), np.uint8)
                for p in sorted(read_json(case / f'layouts/{view}.json')['parts'], key=lambda p: p['z_index']):
                    image = source_pixels(case, p)
                    composed[image[..., 3] > 0] = image[image[..., 3] > 0]
                np.testing.assert_array_equal(composed, np.array(Image.open(case / f'source/{view}/processed.png')))

    def test_replication_uses_euclidean_nearest_edge(self):
        seed = np.zeros((8, 8, 4), np.uint8)
        seed[0, 0], seed[0, 5] = FIXTURE_LEFT_RGBA, FIXTURE_RIGHT_RGBA
        target = np.ones((8, 8), bool)
        result = edge_texels(seed, target)
        self.assertTrue(np.all(result[3, 2] == FIXTURE_LEFT_RGBA))
        self.assertTrue(np.all(result[3, 3] == FIXTURE_RIGHT_RGBA))
        np.testing.assert_array_equal(result[seed[..., 3] > 0], seed[seed[..., 3] > 0])

    def test_seam_extension_connects_requested_texels_without_crossing_protection(self):
        seed = np.zeros((12, 12), bool)
        seed[3:6, 2:4] = True
        allowed = np.zeros_like(seed)
        allowed[3:6, 2:10] = True
        requested = np.zeros_like(seed)
        requested[4, 9] = True
        connected = connected_extension(seed, requested, allowed)
        self.assertTrue(connected[4, 9])
        self.assertEqual(len(components(connected)[1]), 1)
        allowed[:, 6] = False
        protected = connected_extension(seed, requested, allowed)
        self.assertFalse(protected[4, 9])
        self.assertFalse(protected[:, 6].any())

    def test_margin_edge_replication_draw_order_and_protected_features(self):
        with tempfile.TemporaryDirectory() as temporary:
            case = Path(temporary)
            rows = []
            for view in ('front', 'rear'):
                left = np.zeros((255, 255, 4), np.uint8)
                right = left.copy()
                left[10:20, 10:20] = FIXTURE_LEFT_RGBA
                right[10:20, 20:30] = FIXTURE_RIGHT_RGBA
                feature = np.zeros_like(left)
                feature[14:16, 21:23] = FIXTURE_RIGHT_RGBA
                parts = []
                for name, image, bone, z, extra in (
                    ('left', left, 'left', 0, {}),
                    ('hidden_left', left, 'left', -1, {'hidden_material': True}),
                    ('right', right, 'right', 1, {}),
                    ('feature_eye', feature, 'right', 2, {'feature': 'eye'})):
                    file = view + '_' + name + '.png'
                    Image.fromarray(image).save(case / file)
                    parts.append(dict(name=name, file=file, bone=bone, z_index=z,
                                      offset=[0, 0], bbox=[0, 0, 255, 255], **extra))
                write_json(case / f'layouts/{view}.json', {'parts': parts})
                source = left.copy()
                source[right[..., 3] > 0] = right[right[..., 3] > 0]
                (case / f'source/{view}').mkdir(parents=True)
                Image.fromarray(source).save(case / f'source/{view}/processed.png')
                rows.append({'view': view, 'clip': 'fixture', 'frame': 0, 'parts': {
                    p['name']: {'transform': [1, 0, 0, 1, FIXTURE_SEPARATION_PX if p['bone'] == 'right' else 0, 0]}
                    for p in parts}})
            records, surfaces = domains(case, {'samples': rows})
            for record in records:
                self.assertEqual(record['joints'][0]['margin_px'], FIXTURE_SEPARATION_PX + 1)
                self.assertEqual(record['joints'][0]['maximum_sampled_separation_px'], FIXTURE_SEPARATION_PX)
                seed, result = surfaces[record['view'], record['part']]
                added = (result[..., 3] > 0) & (seed[..., 3] == 0)
                self.assertTrue(added.any())
                self.assertTrue(np.all(result[added] == FIXTURE_LEFT_RGBA))
                self.assertFalse(added[14:16, 21:23].any())
                self.assertFalse(added[:, 30:].any())
                self.assertFalse(added[:10].any())
                # Blue neighbour covers every added red texel at rest.
                self.assertTrue(np.all(np.argwhere(added)[:, 1] >= 20))


if __name__ == '__main__':
    unittest.main()
