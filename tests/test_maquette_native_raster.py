"""Replay director-captured pixels without requiring a window server."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest
from maquette_motion import pixels
from maquette_motion import native_ties
from maquette_motion.gates import unpack

FIXTURES = PROJECT / 'tests/maquette_cutout/native_fixtures'
SYNTHETIC_STEP_DISTANCE_PX = 80
SYNTHETIC_STALE_TRANSLATION_PX = 0.01


class NativeRasterTests(unittest.TestCase):
    def fixtures(self, manifests=('manifest.json', 'wisp_manifest.json', 'seam_manifest.json')):
        rows = [row for name in manifests for row in json.loads((FIXTURES / name).read_text())['fixtures']]
        for row in rows:
            source = PROJECT / row['source']
            capture = FIXTURES / row['capture']
            self.assertEqual(digest(source), row['source_sha256'])
            self.assertEqual(digest(capture), row['capture_sha256'])
            yield row, Image.open(source).convert('RGBA'), np.asarray(Image.open(capture).convert('RGBA'))

    def test_saved_native_surfaces_match_source_transform(self):
        for row, source, actual in self.fixtures():
            with self.subTest(part=row['part'], frame=row['frame'], kind=row['kind']):
                samples = pixels.render(source, unpack(row['transform']), with_ties=True)
                selected, invalid = native_ties.select(actual, samples)
                self.assertFalse(invalid.any())
                self.assertEqual(int(pixels.changed(actual, selected).sum()), 0)
                self.assertTrue(pixels.native_frame_matches(actual, samples.default, samples))

    def test_crop_preserves_fixed_canvas_sampling(self):
        for row, source, actual in self.fixtures():
            with self.subTest(part=row['part'], frame=row['frame']):
                ys, xs = np.nonzero(actual[..., 3])
                margin = pixels.PROOF_DEFAULTS['bounds_margin_px']
                left, top = max(0, int(xs.min()) - margin), max(0, int(ys.min()) - margin)
                right, bottom = min(actual.shape[1], int(xs.max()) + 1 + margin), min(actual.shape[0], int(ys.max()) + 1 + margin)
                transform = unpack(row['transform'])
                full = pixels.render(source, transform)
                cropped = pixels.render(source, transform, (left, top, right, bottom))
                np.testing.assert_array_equal(cropped, full[top:bottom, left:right])
                full_samples = pixels.render(source, transform, with_ties=True)
                cropped_samples = pixels.render(source, transform, (left, top, right, bottom), with_ties=True)
                np.testing.assert_array_equal(full, full_samples.default)
                for field in ('default', 'alternative', 'alternative_u', 'alternative_v', 'ties'):
                    np.testing.assert_array_equal(getattr(cropped_samples, field), getattr(full_samples, field)[top:bottom, left:right])

    def test_seam_fixture_exercises_the_opposite_exact_tie_choice(self):
        row, source, actual = next(item for item in self.fixtures() if item[0]['part'] == 'seam_core_arc_right')
        samples = pixels.render(source, unpack(row['transform']), with_ties=True)
        self.assertEqual(int(pixels.changed(actual, samples.default).sum()), 3)
        self.assertFalse(pixels.native_frame_matches(actual, samples.default))
        for x in (308, 311, 312):
            self.assertTrue(samples.ties[274, x])
            np.testing.assert_array_equal(actual[274, x], samples.alternative[274, x])

    def test_rr07_rotated_before_fixtures_require_the_subtexel_band(self):
        for row, source, actual in self.fixtures(('rr07_manifest.json',)):
            with self.subTest(creature=row['creature'], part=row['part'], frame=row['frame']):
                self.assertEqual(row['kind'], 'before')
                with patch('maquette_motion.raster.SUBTEXEL_TIE_EPSILON', 1e-6):
                    exact = pixels.render(source, unpack(row['transform']), with_ties=True)
                self.assertEqual(int(pixels.changed(actual, exact.default).sum()), row['default_diff_pixels'])
                self.assertFalse(pixels.native_frame_matches(actual, exact.default, exact))
                samples = pixels.render(source, unpack(row['transform']), with_ties=True)
                selected, invalid = native_ties.select(actual, samples)
                self.assertFalse(invalid.any())
                self.assertEqual(int(pixels.changed(actual, selected).sum()), row['subtexel_residual_pixels'])
                self.assertTrue(pixels.native_frame_matches(actual, samples.default, samples))
                transform = unpack(row['transform'])
                full = pixels.render(source, transform, with_ties=True)
                bounds = (128, 128, 384, 384)
                cropped = pixels.render(source, transform, bounds, with_ties=True)
                for field in ('default', 'alternative', 'alternative_u', 'alternative_v', 'ties'):
                    np.testing.assert_array_equal(getattr(cropped, field), getattr(full, field)[128:384, 128:384])

    def test_rr07_outer_edge_fixture_passes_as_one_counted_invalid_tie(self):
        for row, source, actual in self.fixtures(('rr07_edge_manifest.json',)):
            samples = pixels.render(source, unpack(row['transform']), with_ties=True)
            selected, invalid = native_ties.select(actual, samples)
            x, y = row['invalid_pixel_xy']
            self.assertTrue(invalid[y, x])
            self.assertEqual(int(invalid.sum()), row['invalid_tie_pixels'])
            self.assertEqual(int(pixels.changed(actual, selected).sum()), row['counted_changed_pixels'])
            self.assertEqual(int(actual[y, x, 3]), 0)
            for candidate in samples.candidates:
                self.assertEqual(int(candidate[y, x, 3]), 255)
            self.assertTrue(pixels.native_frame_matches(actual, samples.default, samples))

    def test_invalid_ties_are_reported_per_part_and_frame_without_counting_wrap_twice(self):
        fixture = json.loads((FIXTURES / 'rr07_edge_manifest.json').read_text())
        row = fixture['fixtures'][0]
        self.assertEqual(digest(FIXTURES / row['after_capture']), row['after_capture_sha256'])
        case = PROJECT / fixture['case']
        read_json = pixels.read_json

        def one_part_layout(path):
            result = read_json(path)
            if path.name == 'rear.json':
                historical = dict(fixture['historical_part'])
                historical['file'] = str(PROJECT / historical['file'])
                result['parts'] = [historical]
            elif path.name == 'front.json':
                result['parts'] = []
            return result

        sample = fixture['sample']
        poses = [dict(sample, view='front', parts={}), sample]
        native = {'directory': FIXTURES, 'samples': poses, 'frames': [
            {'view': row['view'], 'part': row['part'], 'frame': row['frame'],
             'before': row['capture'], 'after': row['after_capture']}]}
        report = {'samples': poses, 'step_distance_px': fixture['step_distance_px']}
        with patch.object(pixels, 'read_json', side_effect=one_part_layout):
            errors, metric = pixels.shimmer(case, report, native)
        self.assertEqual(errors, [])
        self.assertEqual(metric['invalid_tie_totals'], {'before': 1, 'after': 0})
        self.assertEqual(len(metric['parts']), 1)
        self.assertEqual(metric['parts'][0]['invalid_ties'], {
            'total': {'before': 1, 'after': 0},
            'frames': [{'frame': row['frame'], 'before': 1, 'after': 0}]})
        self.assertEqual(metric['totals']['after']['held_unexplained_pixels'], 0)

    def test_native_loop_rejects_a_held_flip_between_valid_candidates(self):
        row, source, actual = next(item for item in self.fixtures() if item[0]['part'] == 'seam_core_arc_right')
        case = PROJECT / 'experiments/cutouts/lightning_wisp/mq4'
        read_json = pixels.read_json
        definition = read_json(case / 'compiled_motion.json')['clips']['idle']
        count = round(definition['seconds'] * 60)
        samples = pixels.render(source, unpack(row['transform']), with_ties=True)
        flipped = actual.copy()
        flipped[274, 308] = samples.default[274, 308]
        self.assertTrue(pixels.native_frame_matches(flipped, samples.default, samples))

        def isolated_layout(path):
            result = read_json(path)
            if path.name == 'front.json':
                result['parts'] = []
            elif path.name == 'rear.json':
                part = dict(next(p for p in result['parts'] if p['name'] == row['part']))
                part['file'] = str(PROJECT / row['source'])
                result['parts'] = [part]
            return result

        poses = [{'view': view, 'clip': 'idle', 'frame': frame, 'phase': frame / count,
                  'presented_phase': pixels.phase_for(definition, frame / count),
                  'parts': {row['part']: {'transform': row['transform'], 'before': row['transform']}}}
                 for view in ('front', 'rear') for frame in (12, 13)]
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            Image.fromarray(actual).save(directory / 'stable.png')
            Image.fromarray(flipped).save(directory / 'flipped.png')
            frames = [{'view': 'rear', 'frame': frame, 'part': row['part'], 'before': 'stable.png', 'after': 'stable.png'}
                      for frame in (12, 13)]
            native = {'samples': poses, 'frames': frames, 'directory': directory}
            with patch.object(pixels, 'read_json', side_effect=isolated_layout):
                errors, metric = pixels.shimmer(case, {'samples': poses, 'step_distance_px': SYNTHETIC_STEP_DISTANCE_PX}, native)
                self.assertEqual(errors, [])
                self.assertEqual(metric['totals']['after']['held_unexplained_pixels'], 0)
                frames[1]['after'] = 'flipped.png'
                errors, metric = pixels.shimmer(case, {'samples': poses, 'step_distance_px': SYNTHETIC_STEP_DISTANCE_PX}, native)
                self.assertTrue(any('unexplained shimmer' in e for e in errors), errors)
                self.assertGreater(metric['totals']['after']['held_unexplained_pixels'], 0)

    def test_native_replay_uses_the_matrices_that_staged_its_surfaces(self):
        fixture = json.loads((FIXTURES / 'native_clock.json').read_text())
        case = PROJECT / fixture['case']
        native = dict(fixture['native'], directory=FIXTURES)
        for frame in native['frames']:
            for kind in ('before', 'after'):
                self.assertEqual(digest(FIXTURES / frame[kind]), frame[kind + '_sha256'])
        read_json = pixels.read_json

        def one_part_layout(path):
            result = read_json(path)
            if path.name == 'front.json':
                historical = dict(fixture['historical_part'])
                historical['file'] = str(PROJECT / historical['file'])
                result['parts'] = [historical]
            elif path.name == 'rear.json':
                result['parts'] = []
            return result

        with patch.object(pixels, 'read_json', side_effect=one_part_layout):
            errors, metric = pixels.shimmer(case, fixture['report'], native)
            self.assertEqual(errors, [])
            self.assertEqual(metric['totals']['after']['held_unexplained_pixels'], 0)
            # Float32 cancellation straddles a vertex subpixel boundary, but
            # the resulting UVs are now legal sub-texel ties (rr-07 feedback 2).
            # Preserve the historical fixture and require a stale-clock
            # mutation beyond that band to remain observable.
            import copy
            stale_samples = copy.deepcopy(fixture['report']['samples'])
            for row in stale_samples:
                for part in row['parts'].values():
                    part['before'][4] += SYNTHETIC_STALE_TRANSLATION_PX
                    part['transform'][4] += SYNTHETIC_STALE_TRANSLATION_PX
            wrong = dict(native, samples=stale_samples)
            errors, _ = pixels.shimmer(case, fixture['report'], wrong)
            self.assertTrue(any('does not match its source transform' in e for e in errors))


if __name__ == '__main__':
    unittest.main()
