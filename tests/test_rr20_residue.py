"""Director feedback-1 boundaries, same-piece donors and GPU-mask contracts."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'tools'), str(ROOT/'experiments/cutouts/hollow_mimic')]
from residue import residue_mask, clean_piece, count, feature_mask
from case import CASE, read_json, digest
import gates as rr20
from maquette_motion.features import source_pixels

FIXTURE_COLOURS = [(24,36,0,255), (26,38,26,255), (22,33,0,255),
    (80,92,45,255), (95,88,45,255), (0,26,7,255), (0,255,0,0)]
FIXTURE_BROWN = [50,20,10,255]
FIXTURE_GREEN = [0,255,0,255]
FIXTURE_SIZE_PX = 4


class ResidueTests(unittest.TestCase):
    def test_inclusive_margin_and_ratio_preserve_olive_and_brown(self):
        image = np.asarray([FIXTURE_COLOURS], dtype=np.uint8)
        self.assertEqual(residue_mask(image).tolist(), [[True,False,False,False,False,True,False]])
        clean, _, _ = clean_piece(image, np.zeros_like(image))
        self.assertEqual(count(clean), 0)
        for index in (1,2,3,4,6): np.testing.assert_array_equal(clean[0,index], image[0,index])

    def test_feature_residue_stays_and_cannot_donate_to_unmasked_paint(self):
        image = np.asarray([[FIXTURE_GREEN,[0,26,7,255],FIXTURE_BROWN]],dtype=np.uint8)
        feature = np.asarray([[True,False,False]])
        clean, _, replacements = clean_piece(image, np.zeros_like(image), feature)
        np.testing.assert_array_equal(clean[0,0], image[0,0])
        np.testing.assert_array_equal(clean[0,1], image[0,2])
        self.assertEqual(replacements, [{'at':[1,0], 'donor':[2,0]}])
        self.assertEqual(count(clean, feature), 0)
        self.assertEqual(count(clean), 1)

    def test_declared_feature_masks_accept_luminance_and_alpha_masks(self):
        with tempfile.TemporaryDirectory(prefix='rr20-feature-format-') as temporary:
            folder = Path(temporary)
            selected = np.asarray([[True,False,True]])
            Image.fromarray(selected.astype('uint8')*255).save(folder/'luma.png')
            rgba = np.zeros((1,3,4),dtype=np.uint8); rgba[selected] = 255
            Image.fromarray(rgba).save(folder/'alpha.png')
            for file in ('luma.png','alpha.png'):
                layout = {'canvas_size':[3,1], 'features':[{'name':'eye','piece':'head','mask':file}]}
                np.testing.assert_array_equal(feature_mask(folder,layout,'head'), selected)
                self.assertFalse(feature_mask(folder,layout,'torso').any())

    def test_nearest_donor_can_come_from_same_piece_hidden_fill(self):
        visible = np.zeros((FIXTURE_SIZE_PX,FIXTURE_SIZE_PX,4),dtype=np.uint8)
        hidden = visible.copy()
        visible[0,0] = [100,80,50,255]
        visible[2,2] = [0,26,7,127]
        hidden[2,1] = FIXTURE_BROWN
        clean, fill, replacements = clean_piece(visible, hidden)
        self.assertEqual(replacements, [{'at':[2,2], 'donor':[1,2]}])
        np.testing.assert_array_equal(clean[2,2], [50,20,10,127])
        np.testing.assert_array_equal(fill, hidden)
        np.testing.assert_array_equal(clean[...,3], visible[...,3])
        np.testing.assert_array_equal(visible[2,2], [0,26,7,127])

    def test_no_donor_is_an_error_instead_of_inventing_paint(self):
        image = np.asarray([[FIXTURE_GREEN]],dtype=np.uint8)
        with self.assertRaisesRegex(ValueError, 'no non-residue donor'):
            clean_piece(image, np.zeros_like(image))
        clean, _, rows = clean_piece(image, np.zeros_like(image), np.ones((1,1),dtype=bool))
        np.testing.assert_array_equal(clean, image)
        self.assertEqual(rows, [])

    def test_derivation_gate_rejects_unrelated_non_residue_repaint(self):
        layout = read_json(CASE/'layouts/rear.json')
        self.assertEqual(rr20.residue_derivation_errors(layout), [])
        def mutant(case, part):
            image = source_pixels(case, part).copy()
            if part['name'] == 'head':
                y,x = np.argwhere(image[...,3]>0)[0]
                image[y,x,:3] = FIXTURE_BROWN[:3]
            return image
        with patch.object(rr20, 'source_pixels', side_effect=mutant):
            self.assertTrue(any('residue derivation differs' in e for e in rr20.residue_derivation_errors(layout)))

    def test_native_feature_exemption_requires_complete_hashed_gpu_masks(self):
        with tempfile.TemporaryDirectory(prefix='rr20-feature-') as temporary:
            folder = Path(temporary)
            image = np.asarray([[FIXTURE_GREEN,FIXTURE_BROWN]],dtype=np.uint8)
            Image.fromarray(image).save(folder/'frame.png')
            mask = np.zeros_like(image); mask[0,0] = 255
            Image.fromarray(mask).save(folder/'mask.png')
            record = {'view':'front','clip':'idle','frame':0,'name':'eye','file':'mask.png','sha256':digest(folder/'mask.png')}
            manifest = {'frames':[{'view':'front','clip':'idle','frame':0,'file':'frame.png'}], 'feature_masks':[record]}
            layout = {'front':{'features':[{'name':'eye'}]}}
            self.assertEqual(rr20.native_residue_errors(folder,manifest,layout), [])
            manifest['feature_masks'] = []
            errors = rr20.native_residue_errors(folder,manifest,layout)
            self.assertTrue(any('missing native feature mask' in e for e in errors))
            self.assertTrue(any('presented chroma-key residue' in e for e in errors))
            manifest['feature_masks'] = [dict(record,sha256='stale')]
            self.assertTrue(any('changed native feature mask' in e for e in rr20.native_residue_errors(folder,manifest,layout)))
            manifest['feature_masks'] = [record]
            image[0,1] = FIXTURE_GREEN
            Image.fromarray(image).save(folder/'frame.png')
            self.assertTrue(any('presented chroma-key residue' in e for e in rr20.native_residue_errors(folder,manifest,layout)))


if __name__ == '__main__': unittest.main()
