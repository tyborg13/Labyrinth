"""Exact-tie acceptance cannot hide third colours, held flips or stale paint."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from maquette_motion import pixels, native_ties, gates
from maquette_motion.raster import nearest_quad, EXACT_TIE_EPSILON
from maquette_motion.raster import QuadSamples

SYNTHETIC_SIZE = 12
SYNTHETIC_BOUNDS = (0, 0, SYNTHETIC_SIZE + 2, SYNTHETIC_SIZE + 2)
SYNTHETIC_THIRD_COLOUR = (251, 7, 199, 255)
SYNTHETIC_OPAQUE_COLOUR = (80, 100, 120, 255)


class NativeTieTests(unittest.TestCase):
    def samples(self, offset=(0.5, 0.5)):
        y, x = np.indices((SYNTHETIC_SIZE, SYNTHETIC_SIZE))
        paint = np.stack((x + 10, y + 20, x + y + 30, np.full_like(x, 255)), axis=-1).astype(np.uint8)
        transform = np.eye(3)
        transform[:2, 2] = offset
        return nearest_quad(paint, transform, SYNTHETIC_BOUNDS, with_ties=True)

    def test_both_axes_allow_independent_adjacent_choices(self):
        samples = self.samples()
        self.assertTrue(samples.ties[5, 5])
        self.assertEqual(len({tuple(c[5, 5]) for c in samples.candidates}), 4)
        for candidate in samples.candidates:
            actual = samples.default.copy()
            actual[5, 5] = candidate[5, 5]
            self.assertTrue(pixels.native_frame_matches(actual, samples.default, samples))

    def test_third_colour_at_a_tie_is_not_an_edge_allowance(self):
        samples = self.samples()
        actual = samples.default.copy()
        actual[5, 5] = SYNTHETIC_THIRD_COLOUR
        # The old 1px + 1% rule alone would accept this single bad pixel.
        self.assertTrue(pixels.native_frame_matches(actual, samples.default))
        self.assertFalse(pixels.native_frame_matches(actual, samples.default, samples))

    def test_texture_edge_ties_never_accept_nonexistent_transparent_texels(self):
        paint = np.full((SYNTHETIC_SIZE, SYNTHETIC_SIZE, 4), SYNTHETIC_OPAQUE_COLOUR, np.uint8)
        transform = np.eye(3)
        transform[:2, 2] = 0.5
        samples = nearest_quad(paint, transform, SYNTHETIC_BOUNDS, with_ties=True)
        actual = samples.default.copy()
        actual[0, :] = 0
        actual[:, 0] = 0
        self.assertEqual(int(pixels.changed(actual, samples.default).sum()), 23)
        self.assertFalse(pixels.native_frame_matches(actual, samples.default))
        self.assertFalse(pixels.native_frame_matches(actual, samples.default, samples))
        for candidate in samples.candidates:
            np.testing.assert_array_equal(candidate[0, :SYNTHETIC_SIZE], samples.default[0, :SYNTHETIC_SIZE])
            np.testing.assert_array_equal(candidate[:SYNTHETIC_SIZE, 0], samples.default[:SYNTHETIC_SIZE, 0])
        # Reversed axes include the maximum UV edge under top-left coverage.
        transform[:2, :2] *= -1
        transform[:2, 2] = SYNTHETIC_SIZE + 0.5
        reversed_samples = nearest_quad(paint, transform, SYNTHETIC_BOUNDS, with_ties=True)
        for candidate in reversed_samples.candidates:
            self.assertEqual(int((candidate[..., 3] > 0).sum()), SYNTHETIC_SIZE ** 2)

    def test_non_ties_keep_the_existing_rule_and_allowance(self):
        samples = self.samples(offset=(0, 0))
        self.assertFalse(samples.ties.any())
        actual = samples.default.copy()
        actual[5, 5] = SYNTHETIC_THIRD_COLOUR
        self.assertEqual(pixels.native_frame_matches(actual, samples.default, samples),
                         pixels.native_frame_matches(actual, samples.default))
        actual[4:7, 4:7] = SYNTHETIC_THIRD_COLOUR
        self.assertFalse(pixels.native_frame_matches(actual, samples.default, samples))

    def test_native_choice_is_explained_at_boundary_but_never_during_hold(self):
        samples = self.samples()
        first = samples.default.copy()
        second = first.copy()
        second[5, 5] = samples.alternative[5, 5]
        before, _ = native_ties.select(first, samples)
        after, _ = native_ties.select(second, samples)
        explained = native_ties.explanation(before, after, False, samples.default, samples.default)
        self.assertEqual(pixels.residual(first, second, *explained)[0], 0)
        held = native_ties.explanation(before, after, True, samples.default, samples.default)
        self.assertEqual(pixels.residual(first, second, *held)[0], 1)
        stable = native_ties.explanation(after, after, True, samples.default, samples.default)
        self.assertEqual(pixels.residual(second, second, *stable)[0], 0)

    def test_report_counts_only_occupied_ties_even_for_whole_scanlines(self):
        self.assertEqual(EXACT_TIE_EPSILON, 1e-6)
        normal = native_ties.statistics(self.samples(offset=(0, 0)))
        broken = native_ties.statistics(self.samples())
        self.assertEqual(normal['pixels'], 0)
        self.assertGreater(broken['fraction'], 0.02)
        self.assertLessEqual(broken['pixels'], broken['occupied_pixels'])

    def test_high_tie_occupancy_is_report_only_in_the_pixel_gate(self):
        from test_maquette_native_raster import FIXTURES
        import json
        fixture = json.loads((FIXTURES / 'native_clock.json').read_text())
        case = PROJECT / fixture['case']
        read_json, render = pixels.read_json, pixels.render

        def one_part_layout(path):
            result = read_json(path)
            if path.name == 'front.json':
                historical = dict(fixture['historical_part'])
                historical['file'] = str(PROJECT / historical['file'])
                result['parts'] = [historical]
            elif path.name == 'rear.json':
                result['parts'] = []
            return result

        def broken_ties(*args, **kwargs):
            image = render(*args, **dict(kwargs, with_ties=False))
            if kwargs.get('with_ties'):
                return QuadSamples(image, image, image, image, image[..., 3] > 0)
            return image

        with patch.object(pixels, 'read_json', side_effect=one_part_layout), patch.object(pixels, 'render', side_effect=broken_ties):
            errors, metric = pixels.shimmer(case, fixture['report'])
        self.assertEqual(errors, [])
        self.assertGreater(metric['parts'][0]['ties']['max_fraction'], 0.02)

    def test_saved_capture_keeps_render_bindings_exact_across_oracle_revision(self):
        recorded = {'paint.png': 'paint', 'runtime:scripts/maquette_cutout_runtime/rig.gd': 'rig',
                    'runtime:tools/maquette_motion/raster.py': 'old oracle'}
        current = dict(recorded, **{'runtime:tools/maquette_motion/raster.py': 'new oracle'})
        with patch.object(gates, 'input_bindings', return_value=current):
            self.assertTrue(gates.bindings_match(Path('.'), recorded))
            self.assertEqual(recorded['runtime:tools/maquette_motion/raster.py'], 'old oracle')
            for key in ('paint.png', 'runtime:scripts/maquette_cutout_runtime/rig.gd'):
                self.assertFalse(gates.bindings_match(Path('.'), dict(recorded, **{key: 'changed'})))
            self.assertFalse(gates.bindings_match(Path('.'), dict(recorded, unexpected='value')))
            self.assertFalse(gates.bindings_match(Path('.'), None))


if __name__ == '__main__':
    unittest.main()
