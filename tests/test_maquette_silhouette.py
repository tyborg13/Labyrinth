"""rr-05 orphan and widened-joint mutations on synthetic proof-only pixels."""
from pathlib import Path
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest, read_json, write_json
from maquette_motion import silhouette
from maquette_motion.continuity import clean_visible
from maquette_motion.features import source_pixels

FIXTURE_RGBA = (73, 48, 29, 255)
FIXTURE_SIZE = 255
FIXTURE_BODY = (20, 20, 40, 40)
FIXTURE_ORPHAN_XY = (200, 200)


class SilhouetteTests(unittest.TestCase):
    def test_director_native_examples_match_supplied_counts(self):
        fixtures = PROJECT / 'tests/maquette_cutout/silhouette_fixtures'
        manifest = read_json(fixtures / 'manifest.json')
        for row in manifest['fixtures']:
            with self.subTest(capture=row['capture']):
                path = fixtures / row['capture']
                self.assertEqual(digest(path), row['sha256'])
                mask = np.array(Image.open(path).convert('RGBA'))[..., 3] > 0
                metric, _, _ = silhouette.measure(mask, distance=manifest['distance_px'], grid_distance=True)
                self.assertEqual(metric['detached_pixels'], row['detached_pixels'])
                self.assertEqual(metric['islands'], row['islands'])

    def fixture(self, root):
        shape = (FIXTURE_SIZE, FIXTURE_SIZE)
        body = np.zeros(shape, bool)
        body[20:40, 20:40] = True
        left, right = np.zeros(shape, bool), np.zeros(shape, bool)
        left[21:39, 21:30], right[21:39, 30:39] = True, True
        border = body & ~left & ~right
        rows = []
        for view in ('front', 'rear'):
            parts = []
            (root / f'source/{view}').mkdir(parents=True)
            source = np.zeros((*shape, 4), np.uint8)
            source[body] = FIXTURE_RGBA
            Image.fromarray(source).save(root / f'source/{view}/processed.png')
            for name, mask in (('left', left), ('right', right), ('border', border)):
                image = np.zeros_like(source)
                image[mask] = FIXTURE_RGBA
                file = f'{view}_{name}.png'
                Image.fromarray(image).save(root / file)
                parts.append({'name': name, 'logical_part': name, 'bone': name, 'file': file,
                              'offset': [0, 0], 'bbox': [0, 0, FIXTURE_SIZE, FIXTURE_SIZE], 'z_index': 0})
            write_json(root / f'layouts/{view}.json', {'parts': parts, 'rest_source': f'source/{view}/processed.png'})
            rows.append({'view': view, 'clip': 'fixture', 'phase': 0, 'presented_phase': 0, 'frame': 0,
                         'parts': {p['name']: {'transform': [1, 0, 0, 1, 0, 0], 'alpha': 1} for p in parts}})
        return {'samples': rows}

    def test_connectivity_is_eight_and_single_pixel_is_not_ignored(self):
        diagonal = np.eye(4, dtype=bool)
        self.assertEqual(len(silhouette.components(diagonal)[1]), 1)
        self.assertEqual(len(silhouette.components(diagonal, 4)[1]), 4)
        body = np.zeros((32, 32), bool)
        body[10:22, 10:22] = True
        body[10, 8] = True
        self.assertEqual(silhouette.measure(body)[0]['islands'], 0)  # exactly 2 px
        body[10, 8], body[10, 6] = False, True
        self.assertEqual(silhouette.measure(body)[0]['detached_pixels'], 1)

    def test_derive_gate_rejects_orphan_and_cleanup_preserves_rest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            self.assertTrue(silhouette.part_report(root)['ok'])
            layout = read_json(root / 'layouts/front.json')
            part = layout['parts'][0]
            image = np.array(Image.open(root / part['file']))
            image[25, 35] = FIXTURE_RGBA
            Image.fromarray(image).save(root / part['file'])
            self.assertFalse(silhouette.part_report(root)['ok'])
            transfers = clean_visible(root, 'front', layout)
            self.assertEqual(transfers, [{'from': 'left', 'to': 'right', 'pixels': 1}])
            write_json(root / 'layouts/front.json', layout)
            self.assertTrue(silhouette.part_report(root)['ok'])
            composed = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), np.uint8)
            for part in layout['parts']:
                image = source_pixels(root, part)
                composed[image[..., 3] > 0] = image[image[..., 3] > 0]
            np.testing.assert_array_equal(composed, np.array(Image.open(root / 'source/front/processed.png')))
        print('MAQUETTE SILHOUETTE MUTATION: orphan pixel rejected; connected reassignment preserves rest')

    def test_widened_joint_gap_fails_cpu_and_native_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = self.fixture(root)
            self.assertTrue(silhouette.pose_report(root, report, legacy_hole_gate=True)['ok'])
            report['samples'][0]['parts']['right']['transform'][4] = 2
            result = silhouette.pose_report(root, report, legacy_hole_gate=True)
            self.assertFalse(result['ok'])
            self.assertGreaterEqual(result['poses'][0]['new_hole_pixels'], 2)
            # Simulated native alpha fixture exercises the saved-surface path;
            # it is never claimed as renderer evidence.
            frames = []
            for row in report['samples']:
                layout = read_json(root / f'layouts/{row["view"]}.json')
                mask = silhouette.compose(root, layout, row)
                image = np.zeros((*mask.shape, 4), np.uint8)
                image[mask] = FIXTURE_RGBA
                file = row['view'] + '_simulated.png'
                Image.fromarray(image).save(root / file)
                frames.append(dict(view=row['view'], clip='fixture', frame=0, file=file, sha256=digest(root / file)))
            native = {'directory': root, 'frames': frames}
            result = silhouette.pose_report(root, report, native, legacy_hole_gate=True)
            self.assertFalse(result['ok'])
            self.assertEqual(result['poses'][0]['new_hole_pixels'], 36)
            native['frames'].pop()
            self.assertTrue(any('missing native' in e for e in silhouette.pose_report(root, report, native)['errors']))
        print('MAQUETTE SILHOUETTE MUTATION: widened joint gap rejected by legacy CPU and saved-surface gates; feedback8 hard gate in seam tests')

    def test_existing_rest_hole_remains_allowed_but_new_hole_fails(self):
        mask = np.zeros((32, 32), bool)
        mask[4:28, 4:28] = True
        mask[10:12, 10:12] = False
        baseline = silhouette.holes(mask)
        self.assertEqual(silhouette.measure(mask, baseline)[0]['new_holes'], 0)
        mask[18:20, 18:20] = False
        self.assertEqual(silhouette.measure(mask, baseline)[0]['new_hole_pixels'], 4)

    def test_saved_surface_orphan_pixel_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = self.fixture(root)
            frames = []
            for row in report['samples']:
                mask = silhouette.compose(root, read_json(root / f'layouts/{row["view"]}.json'), row)
                image = np.zeros((*mask.shape, 4), np.uint8)
                image[mask] = FIXTURE_RGBA
                if row['view'] == 'front':
                    x, y = FIXTURE_ORPHAN_XY
                    image[y, x] = FIXTURE_RGBA
                file = row['view'] + '_orphan_simulated.png'
                Image.fromarray(image).save(root / file)
                frames.append(dict(view=row['view'], clip='fixture', frame=0, file=file, sha256=digest(root / file)))
            result = silhouette.pose_report(root, report, {'frames': frames, 'directory': root})
            self.assertFalse(result['ok'])
            self.assertEqual(result['poses'][0]['detached_pixels'], 1)
            self.assertEqual(result['poses'][1]['detached_pixels'], 0)


if __name__ == '__main__':
    unittest.main()
