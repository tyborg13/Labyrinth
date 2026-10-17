"""Replay director-captured pixels without requiring a window server."""
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest
from maquette_motion import pixels
from maquette_motion.gates import unpack

FIXTURES = PROJECT / 'tests/maquette_cutout/native_fixtures'


class NativeRasterTests(unittest.TestCase):
    def fixtures(self):
        manifests = ('manifest.json', 'wisp_manifest.json')
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
                expected = pixels.render(source, unpack(row['transform']))
                self.assertEqual(int(pixels.changed(actual, expected).sum()), 0)
                self.assertTrue(pixels.native_frame_matches(actual, expected))

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
            # These independently captured matrices differ only by float32
            # cancellation, but straddle a native vertex subpixel boundary.
            wrong = dict(native, samples=fixture['report']['samples'])
            errors, _ = pixels.shimmer(case, fixture['report'], wrong)
            self.assertTrue(any('does not match its source transform' in e for e in errors))


if __name__ == '__main__':
    unittest.main()
