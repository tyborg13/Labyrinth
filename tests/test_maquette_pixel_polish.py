"""rr-05 whole-feature, step-clock and temporal-residual mutations."""
import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
import shutil
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_cutout_build import CREATURES, case_for
from maquette_motion import features, pixels
from maquette_motion.feature_builder import ownership_adapter, extract_nodes
from maquette_cutout_polish import derive

SYNTHETIC_BODY_RGBA = [20, 30, 40, 255]
SYNTHETIC_FEATURE_RGBA = [200, 100, 20, 255]
SYNTHETIC_BODY_BOX = (10, 10, 14, 14)
SYNTHETIC_FEATURE_BOX = (11, 11, 13, 12)
CROP_PADDING_SOURCE_PX = 2


class FeatureTests(unittest.TestCase):
    def fixture(self, root):
        # Debug-only synthetic pixels; never used as player-facing art.
        paint = np.zeros((255, 255, 4), dtype=np.uint8)
        x, y, right, bottom = SYNTHETIC_BODY_BOX
        paint[y:bottom, x:right] = SYNTHETIC_BODY_RGBA
        x, y, right, bottom = SYNTHETIC_FEATURE_BOX
        paint[y:bottom, x:right] = SYNTHETIC_FEATURE_RGBA
        feature = np.zeros((255, 255), dtype=np.uint8)
        feature[y:bottom, x:right] = 255
        declarations = {'features': [{'name': 'test_gem', 'views': {}}], 'approved_sha256': {}}
        rows = []
        for view in features.VIEWS:
            source = root / f'source/{view}'
            source.mkdir(parents=True)
            Image.fromarray(paint).save(source / 'processed.png')
            Image.fromarray(feature).save(root / f'{view}_mask.png')
            declarations['approved_sha256'][view] = digest(source / 'processed.png')
            declarations['features'][0]['views'][view] = {'mask': f'{view}_mask.png', 'owner': 'core'}
            (root / 'layouts').mkdir(exist_ok=True)
            feature_paint = paint.copy()
            feature_paint[feature == 0] = 0
            under = paint.copy()
            under[feature > 0] = 0
            Image.fromarray(feature_paint).save(root / f'{view}_gem.png')
            Image.fromarray(under).save(root / f'{view}_body.png')
            parts = [{'name': 'gem', 'feature': 'test_gem', 'bone': 'core', 'file': f'{view}_gem.png', 'offset': [0, 0], 'z_index': 2},
                     {'name': 'body', 'bone': 'body', 'file': f'{view}_body.png', 'offset': [0, 0], 'z_index': 1}]
            write_json(root / f'layouts/{view}.json', {'parts': parts})
            rows.extend({'view': view, 'clip': 'test_action', 'phase': at, 'parts': {'gem': {'bone': 'core', 'transform': [1, 0, 0, 1, at, 0]}}} for at in (0.0, 0.5, 1.0))
        write_json(root / 'features.json', declarations)
        write_json(root / 'compiled_motion.json', {'parts': {'core': 'core'}})
        return rows

    def test_one_feature_node_passes_and_split_pixel_mutation_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rows = self.fixture(root)
            self.assertEqual(features.integrity_errors(root, rows), [])
            report = features.integrity_report(root, rows)
            for feature in report['features']:
                self.assertTrue(feature['ok'])
                self.assertEqual(feature['mask_pixels'], 2)
                self.assertEqual(feature['preserved_pixels'], 2)
                self.assertEqual(feature['painted_nodes'], ['gem'])
                self.assertEqual(feature['owner_bone'], 'core')
                self.assertEqual(feature['sampled_poses'], 3)
                self.assertEqual(feature['poses_by_clip'], {'test_action': 3})
            for view in features.VIEWS:
                gem = np.array(Image.open(root / f'{view}_gem.png'))
                body = np.array(Image.open(root / f'{view}_body.png'))
                body[11, 11] = gem[11, 11]
                gem[11, 11] = 0
                Image.fromarray(gem).save(root / f'{view}_gem.png')
                Image.fromarray(body).save(root / f'{view}_body.png')
            errors = features.integrity_errors(root, rows)
            for view in features.VIEWS:
                self.assertTrue(any(e.startswith(view + '/') and 'split' in e for e in errors), errors)
            print('MAQUETTE PIXEL MUTATION: split_feature rejected in both views')

    def test_hidden_overlap_must_be_behind_and_wrong_sample_bone_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rows = self.fixture(root)
            for view in features.VIEWS:
                layout = read_json(root / f'layouts/{view}.json')
                under = np.array(Image.open(root / f'{view}_body.png'))
                under[11, 11:13] = SYNTHETIC_BODY_RGBA
                Image.fromarray(under).save(root / f'{view}_body.png')
                layout['parts'][1]['hidden_material'] = True
                write_json(root / f'layouts/{view}.json', layout)
            self.assertEqual(features.integrity_errors(root, rows), [])
            layout['parts'][1]['z_index'] = 3
            write_json(root / 'layouts/rear.json', layout)
            self.assertTrue(any('not behind' in e for e in features.integrity_errors(root, rows)))
            rows[0]['parts']['gem']['bone'] = 'body'
            self.assertTrue(any('sampled feature ownership' in e for e in features.integrity_errors(root, rows)))

    def test_reassignment_rederives_hidden_support_for_stolen_visible_pixels(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            original = np.full((255, 255), -1, dtype=np.int16)
            original[10:14, 10:14] = 1
            solos = {'core': np.zeros((255, 255), dtype=bool), 'body': np.zeros((255, 255), dtype=bool)}
            owners, hidden, declared = features.ownership(root, 'front', original, ['core', 'body'], solos)
            mask = declared[0]['pixels']
            self.assertTrue(np.all(owners[mask] == 0))
            self.assertTrue(np.all(hidden[1][mask]))
            self.assertFalse(hidden[0][mask].any())

    def test_unresolved_design_never_certifies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            data = read_json(root / 'features.json')
            data['TODO_DESIGN'] = ['TODO_DESIGN_debug_mask']
            write_json(root / 'features.json', data)
            with self.assertRaisesRegex(CutoutError, 'Unresolved feature design'):
                features.declarations(root, 'front')

    def test_versioned_adapter_rebuilds_whole_feature_and_hidden_support(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rows = self.fixture(root)
            owners = np.full((255, 255), -1, dtype=np.int16)
            owners[10:14, 10:14] = 1
            stub = SimpleNamespace(nearest_labels=lambda *args: (owners.copy(), {}),
                                   hidden_region=lambda solo, current, part: (solo & (current >= 0) & (current != part), solo & (current < 0)))
            original = stub.nearest_labels
            with ownership_adapter(stub, root) as state:
                state['view'] = 'front'
                current, _ = stub.nearest_labels(None, None, ['core', 'body'], None)
                hidden, _ = stub.hidden_region(np.zeros((255, 255), dtype=bool), current.copy(), 1)
                self.assertTrue(np.all(current[11, 11:13] == 0))
                self.assertTrue(np.all(hidden[11, 11:13]))
            self.assertIs(stub.nearest_labels, original)
            for view in features.VIEWS:
                (root / f'segmented/{view}').mkdir(parents=True)
                write_json(root / f'segmented/{view}/segmentation.json', {'parts': []})
                (root / 'recipes').mkdir(exist_ok=True)
                extract_nodes(root, view, {'core': 'core'})
                for row in rows:
                    if row['view'] == view:
                        row['parts']['feature_test_gem'] = row['parts'].pop('gem')
            self.assertEqual(features.integrity_errors(root, rows), [])


class PixelPresentationTests(unittest.TestCase):
    def test_expanding_a_hidden_only_crop_preserves_its_source_anchor(self):
        creature = 'shale_bloomer'
        original = case_for(creature)
        with tempfile.TemporaryDirectory(dir=PROJECT/'tests') as temporary:
            root = Path(temporary)/'case'
            shutil.copytree(original, root)
            layout = read_json(root/'layouts/front.json')
            part = next(p for p in layout['parts'] if p['name'] == 'root_stem_l')
            old_offset = part['offset'].copy()
            part.setdefault('presentation_anchor', old_offset)
            image = Image.open(root/part['file']).convert('RGBA')
            padded = Image.new('RGBA', (image.width + CROP_PADDING_SOURCE_PX, image.height))
            padded.paste(image, (CROP_PADDING_SOURCE_PX, 0))
            padded.save(root/part['file'])
            part['offset'][0] -= CROP_PADDING_SOURCE_PX
            part['bbox'][0] -= CROP_PADDING_SOURCE_PX
            write_json(root/'layouts/front.json', layout)
            path = Path(temporary)/'samples.json'
            sampled = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-05', '--stream', '--',
                'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/pixel_samples.gd', '--',
                '--case', str(root), '--output', str(path)], cwd=PROJECT, capture_output=True, text=True, timeout=60)
            self.assertEqual(sampled.returncode, 0, sampled.stdout + sampled.stderr)
            original_rows = {(r['clip'], r['frame']): r for r in self.reports[creature]['samples'] if r['view'] == 'front'}
            maximum = 0.
            for row in read_json(path)['samples']:
                if row['view'] != 'front': continue
                before = pixels.unpack(original_rows[row['clip'], row['frame']]['parts'][part['name']]['transform'])
                after = pixels.unpack(row['parts'][part['name']]['transform'])
                before[:2, 2] -= before[:2, :2] @ np.asarray(old_offset)
                after[:2, 2] -= after[:2, :2] @ np.asarray(part['offset'])
                maximum = max(maximum, float(np.max(np.abs(before - after))))
            self.assertLessEqual(maximum, pixels.PROOF_DEFAULTS['transform_tolerance'])
            print(f'MAQUETTE CROP ANCHOR: PASS (504 front poses; maximum source-affine residual {maximum:.9f})')

    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.reports = {}
        for creature in CREATURES:
            path = Path(cls.directory.name) / (creature + '.json')
            result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-05', '--stream', '--',
                'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/pixel_samples.gd', '--',
                '--case', str(case_for(creature)), '--output', str(path)], cwd=PROJECT, capture_output=True, text=True, timeout=60)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            cls.reports[creature] = read_json(path)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def test_actual_painted_nodes_snap_and_keep_full_rate_actions(self):
        for creature, report in self.reports.items():
            self.assertEqual(pixels.transform_errors(case_for(creature), report), [])
            data = read_json(case_for(creature) / 'compiled_motion.json')
            for row in report['samples']:
                if not data['clips'][row['clip']].get('loop'):
                    self.assertEqual(row['phase'], row['presented_phase'])

    def test_wisp_painted_veins_and_eye_share_core_source_transform(self):
        case = case_for('lightning_wisp')
        tolerance = pixels.PROOF_DEFAULTS['transform_tolerance']
        for row in self.reports['lightning_wisp']['samples']:
            layout = read_json(case / f'layouts/{row["view"]}.json')
            shared = {}
            for part in layout['parts']:
                if part['bone'] != 'core':
                    continue
                matrix = pixels.unpack(row['parts'][part['name']]['transform'])
                matrix[:2, 2] -= matrix[:2, :2] @ np.asarray(part['offset'])
                shared[part['name']] = matrix
            for name, matrix in shared.items():
                with self.subTest(view=row['view'], clip=row['clip'], frame=row['frame'], part=name):
                    np.testing.assert_allclose(matrix, shared['core'], atol=tolerance, rtol=0)

    def test_independent_crop_snapping_mutation_is_rejected(self):
        case = case_for('lightning_wisp')
        mutant = copy.deepcopy(self.reports['lightning_wisp'])
        data = read_json(case / 'compiled_motion.json')
        for row in mutant['samples']:
            layout = read_json(case / f'layouts/{row["view"]}.json')
            bones = pixels.expected_bones(data, layout, row['view'], row['clip'], row['presented_phase'], mutant['step_distance_px'])
            for part in layout['parts']:
                transform = pixels.snapped(pixels.painted(bones[part['bone']]['global'], part, layout))
                row['parts'][part['name']]['transform'] = [transform[0, 0], transform[1, 0], transform[0, 1], transform[1, 1], transform[0, 2], transform[1, 2]]
        errors = pixels.transform_errors(case, mutant)
        for view in ('front', 'rear'):
            self.assertTrue(any(e.startswith(view + '/') and '/arc_left:' in e for e in errors))
        self.assertTrue(any('/feature_eye:' in e for e in errors))
        print('MAQUETTE PIXEL MUTATION: independent core-crop snapping rejected in both views')

    def test_idle_before_after_and_unstepped_mutation(self):
        for creature, report in self.reports.items():
            with self.subTest(creature=creature):
                errors, metric = pixels.shimmer(case_for(creature), report)
                self.assertEqual(errors, [])
                self.assertEqual(metric['totals']['after']['held_unexplained_pixels'], 0)
                self.assertGreater(metric['totals']['before']['held_unexplained_pixels'], 0)
                print(f'MAQUETTE SHIMMER CPU: {creature}: {metric["totals"]}')
                mutant = copy.deepcopy(report)
                # Replay continuous unquantized paint as if presentation had
                # been bypassed, while retaining the required hold clock.
                for row in mutant['samples']:
                    for part in row['parts'].values():
                        part['transform'] = part['before']
                self.assertTrue(pixels.transform_errors(case_for(creature), mutant))
                errors, mutation = pixels.shimmer(case_for(creature), mutant)
                self.assertTrue(errors)
                self.assertGreater(mutation['totals']['after']['held_unexplained_pixels'], 0)
                print(f'MAQUETTE PIXEL MUTATION: {creature}/unstepped_paint rejected')

    def test_native_residual_rejects_a_changed_held_pixel(self):
        old = np.zeros((4, 4, 4), dtype=np.uint8)
        old[1:3, 1:3] = SYNTHETIC_BODY_RGBA
        noise = old.copy()
        noise[1, 1, 0] += 1
        self.assertEqual(pixels.residual(old, noise, old, old), (1, 0.25))
        self.assertEqual(pixels.residual(old, noise, old, noise), (0, 0.0))
        self.assertFalse(pixels.native_frame_matches(np.zeros_like(old), old))
        self.assertTrue(pixels.native_frame_matches(old, old))
        stale = np.roll(old, 2, axis=0)
        self.assertFalse(pixels.native_frame_matches(stale, old))

    def test_clock_wrap_and_all_looping_clips(self):
        loop = {'seconds': 2.8, 'loop': True}
        for frame in range(168):
            self.assertAlmostEqual(pixels.phase_for(loop, frame / 168), (frame // 6) / 28)
        self.assertEqual(pixels.phase_for(loop, 1.0), 0.0)
        self.assertEqual(pixels.phase_for({'seconds': 1, 'loop': False}, 0.149), 0.149)

    def test_feature_derivation_runs_end_to_end_on_isolated_approved_paint_fixture(self):
        original = case_for('lightning_wisp')
        with tempfile.TemporaryDirectory(dir=original.parent, prefix='rr05-feature-test-') as directory:
            root = Path(directory) / 'case'
            shutil.copytree(original, root)
            declaration = {'features': [{'name': 'debug_tail_pixel', 'views': {}}], 'approved_sha256': {}}
            names = list(read_json(root / 'source/spec.json')['labels'])
            for view in features.VIEWS:
                owners = np.load(root / f'registered/{view}_owners.npy')
                # One existing tail pixel is a debug-only ownership fixture,
                # never an adopted eye mask or an alteration of source paint.
                y, x = np.argwhere(owners == names.index('tail'))[0]
                mask = np.zeros((255, 255), dtype=np.uint8)
                mask[y, x] = 255
                Image.fromarray(mask).save(root / f'{view}_fixture_mask.png')
                declaration['approved_sha256'][view] = digest(root / f'source/{view}/processed.png')
                declaration['features'][0]['views'][view] = {'owner': 'core', 'mask': f'{view}_fixture_mask.png'}
            write_json(root / 'features.json', declaration)
            result = derive(root)
            self.assertTrue(result['ok'])
            self.assertTrue(result['rest_identity']['ok'])
            for view in features.VIEWS:
                layout = read_json(root / f'layouts/{view}.json')
                node = next(p for p in layout['parts'] if p.get('feature') == 'debug_tail_pixel')
                self.assertEqual(node['bone'], 'core')
                self.assertEqual(int((features.source_pixels(root, node)[..., 3] > 0).sum()), 1)
            print('MAQUETTE FEATURE DERIVATION: PASS (isolated one-pixel fixture; both approved views reconstruct exactly)')


if __name__ == '__main__':
    unittest.main()
