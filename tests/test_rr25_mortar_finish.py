"""Updated Mortar mask regression and foreign-surface contamination mutations."""
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/slag_mortar')]
from rr22_case import CASE, DIRECTOR
from rr22_surface_gates import continuation_errors
from cutout_pipeline.cases import read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components

FIXTURE_SIZE_PX = 4
FIXTURE_POT_RGBA = [70, 70, 70, 255]
FIXTURE_SKIN_RGBA = [110, 60, 30, 255]


class MortarFinishTests(unittest.TestCase):
    def test_updated_masks_remove_near_arm_islands_without_changing_rest(self):
        self.assertEqual((CASE / 'source/make_crucible_mask.py').read_bytes(),
                         (DIRECTOR.parent / 'make_crucible_mask.py').read_bytes())
        for view in ('front', 'rear'):
            with self.subTest(view=view):
                layout = read_json(CASE / f'layouts/{view}.json')
                arm = next(p for p in layout['parts'] if p['name'] == 'arm_near')
                self.assertEqual(len(components(source_pixels(CASE, arm)[..., 3] > 0)[1]), 1)
                mask_path = DIRECTOR.parent / f'crucible_mask_{view}.png'
                self.assertEqual((CASE / f'source/{view}/crucible_mask.png').read_bytes(), mask_path.read_bytes())
                pot = next(p for p in layout['parts'] if p['name'] == 'mortar')
                self.assertTrue(np.array_equal(source_pixels(CASE, pot)[..., 3] > 0,
                                               np.asarray(Image.open(mask_path)) > 0))
                self.assertEqual(read_json(CASE / 'proof/build.json')['views'][view]['rest_mismatch_pixels'], 0)

    def test_all_covered_surfaces_use_own_piece_paint_in_both_views(self):
        for view in ('front', 'rear'):
            layout = read_json(CASE / f'layouts/{view}.json')
            for part in layout['parts']:
                if not part.get('hidden_material'):
                    continue
                visible = next(p for p in layout['parts'] if not p.get('hidden_material')
                               and p['logical_part'] == part['logical_part'])
                self.assertEqual(continuation_errors(source_pixels(CASE, visible), source_pixels(CASE, part),
                                                     view + '/' + part['name']), [])

    def test_pot_hidden_fill_rejects_even_one_skin_texel(self):
        visible = np.zeros((FIXTURE_SIZE_PX, FIXTURE_SIZE_PX, 4), dtype=np.uint8)
        hidden = np.zeros_like(visible)
        visible[0, 0] = hidden[1, 0] = FIXTURE_POT_RGBA
        self.assertEqual(continuation_errors(visible, hidden, 'mortar'), [])
        hidden[1, 0] = FIXTURE_SKIN_RGBA
        self.assertEqual(continuation_errors(visible, hidden, 'mortar'),
                         ['mortar: 1 continuation texels lack own-piece donors'])
        hidden[1, 0, 3] = 0
        self.assertEqual(continuation_errors(visible, hidden, 'mortar'), [])


if __name__ == '__main__':
    unittest.main()
