"""Feedback-1 chroma band, source-preserving cleanup and frame exemptions."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/briar_weaver')]
from rr21_residue import residue, clean_piece, outside_count, feature_definitions, presented_feature_mask
from maquette_motion.pixels import render

FIXTURE_SIZE = (5, 5)
BROWN = (80, 60, 40, 255)
OLIVE = (70, 80, 40, 255)
KEY = (40, 100, 30, 255)
BAND_EDGE = (70, 105, 50, 255)
FRAME_SIZE = (512, 512)


class ResidueTests(unittest.TestCase):
    def test_inclusive_band_and_legitimate_olive_brown(self):
        rgba = np.asarray([[BROWN, OLIVE, KEY, BAND_EDGE,
            (70, 104, 50, 255), (7, 18, 6, 255), (8, 20, 7, 255), (0, 255, 0, 0)]], dtype=np.uint8)
        self.assertEqual(residue(rgba).tolist(), [[False, False, True, True, False, False, True, False]])

    def test_nearest_donor_can_be_same_piece_hidden_support_and_keeps_alpha(self):
        visible = np.zeros((*FIXTURE_SIZE, 4), dtype=np.uint8)
        hidden = visible.copy()
        visible[0, 0] = BROWN
        visible[4, 3] = (*KEY[:3], 90)
        hidden[4, 4] = OLIVE
        source = visible.copy()
        cleaned, counts = clean_piece([visible, hidden], np.zeros(FIXTURE_SIZE, dtype=bool))
        self.assertEqual(counts, [1, 0])
        self.assertEqual(cleaned[0][4, 3].tolist(), [*OLIVE[:3], 90])
        np.testing.assert_array_equal(source, visible)
        np.testing.assert_array_equal(cleaned[0][..., 3], visible[..., 3])

    def test_declared_feature_is_exact_and_ties_use_source_y_then_x(self):
        image = np.zeros((*FIXTURE_SIZE, 4), dtype=np.uint8)
        image[1, 2] = BROWN
        image[2, 1] = OLIVE
        image[2, 2] = KEY
        image[4, 4] = KEY
        exempt = np.zeros(FIXTURE_SIZE, dtype=bool); exempt[4, 4] = True
        cleaned, counts = clean_piece([image], exempt)
        self.assertEqual(counts, [1])
        np.testing.assert_array_equal(cleaned[0][2, 2], BROWN)
        np.testing.assert_array_equal(cleaned[0][4, 4], KEY)
        self.assertEqual(outside_count(cleaned[0], exempt), 0)
        self.assertEqual(outside_count(cleaned[0], np.zeros_like(exempt)), 1)

    def test_no_donor_from_another_piece_or_from_transparency(self):
        image = np.zeros((*FIXTURE_SIZE, 4), dtype=np.uint8)
        image[2, 2] = KEY
        with self.assertRaisesRegex(ValueError, 'TODO_DESIGN_residue_same_piece_donor'):
            clean_piece([image], np.zeros(FIXTURE_SIZE, dtype=bool))

    def test_feature_hash_rejects_mask_expansion(self):
        import hashlib
        with tempfile.TemporaryDirectory(prefix='rr21-feature-') as folder:
            case = Path(folder)
            Image.new('L', FIXTURE_SIZE).save(case / 'eye.png')
            record = {'front': [{'name': 'eye', 'piece': 'head', 'mask': 'eye.png',
                'sha256': hashlib.sha256((case / 'eye.png').read_bytes()).hexdigest()}]}
            (case / 'feature_masks.json').write_text(json.dumps(record))
            self.assertEqual(len(feature_definitions(case, 'front')), 1)
            Image.new('L', FIXTURE_SIZE, 255).save(case / 'eye.png')
            with self.assertRaisesRegex(ValueError, 'Declared feature mask changed'):
                feature_definitions(case, 'front')

    def test_native_exemption_follows_captured_owner_and_rejects_residue_elsewhere(self):
        # Rigid-quad fixture exercises gate logic only, not GPU motion proof.
        import hashlib
        with tempfile.TemporaryDirectory(prefix='rr21-presented-') as folder:
            case = Path(folder)
            mask = np.zeros((255, 255), dtype=np.uint8); mask[2, 2] = 255
            Image.fromarray(mask).save(case / 'eye.png')
            image = np.zeros((255, 255, 4), dtype=np.uint8); image[2, 2] = KEY; image[2, 3] = BROWN
            Image.fromarray(image).save(case / 'head.png')
            (case / 'feature_masks.json').write_text(json.dumps({'front': [{'name': 'eye', 'piece': 'head',
                'mask': 'eye.png', 'sha256': hashlib.sha256((case / 'eye.png').read_bytes()).hexdigest()}]}))
            transform = np.eye(3); transform[:2, 2] = [10, 0]
            actual = render(Image.fromarray(image), transform)
            Image.fromarray(actual).save(case / 'native_head.png')
            layout = {'facing': 'front', 'parts': [{'name': 'head', 'file': 'head.png', 'bbox': [0, 0, 255, 255]}]}
            rows = [{'name': 'head', 'transform': [1, 0, 0, 1, 10, 0], 'absolute_file': str(case / 'native_head.png')}]
            exempt = presented_feature_mask(case, layout, rows, FRAME_SIZE)
            self.assertEqual(outside_count(actual, exempt), 0)
            mutant = actual.copy(); mutant[0, 0] = KEY
            self.assertEqual(outside_count(mutant, exempt), 1)
            with self.assertRaisesRegex(ValueError, 'Missing native feature owner'):
                presented_feature_mask(case, layout, [], FRAME_SIZE)


if __name__ == '__main__': unittest.main()
