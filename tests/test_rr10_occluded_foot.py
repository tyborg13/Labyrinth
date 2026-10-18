"""Feedback 6: exact boot donors, hidden rest and physical regressions."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.gates import source_errors, clean_metrics, matrix, EPSILON
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules, outline_class

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
FIXTURE_SLAB_YX = (225, 73)
FIXTURE_SLAB_RGBA = (0, 0, 0, 255)  # Exact outline black present in the approved heel.
FIXTURE_MOVEMENT_MIN_PX = 1


def read(path):
    return json.loads(path.read_bytes())


class OccludedFootTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = read(CASE / 'layouts/rear.json')
        cls.record = cls.layout['occluded_surfaces'][0]
        cls.part = next(p for p in cls.layout['parts'] if p['name'] == cls.record['surface_part'])
        cls.boot = source_pixels(CASE, cls.part)
        cls.paint = np.asarray(Image.open(CASE / cls.layout['rest_source']).convert('RGBA'))
        cls.solo = np.asarray(Image.open(CASE / cls.record['solo_file']).convert('RGBA'))[..., 3] > 128
        cls.base = cls.solo & (cls.paint[..., 3] > 0)

    def test_every_base_texel_is_the_aligned_heel_or_exact_nearest_donor(self):
        baseline = CASE / 'rear_baseline'
        donor_part = next(p for p in read(baseline / 'layouts/rear.json')['parts'] if p['name'] == 'foot_far')
        donor = source_pixels(baseline, donor_part)
        dy, dx = np.nonzero(donor[..., 3])
        ty, tx = np.nonzero(self.solo)
        offset = self.record['derivation']['translation_px']
        self.assertEqual(offset, [-66, -12])
        self.assertEqual(int(dy.max()) + offset[1], int(ty.max()))
        self.assertLessEqual(abs((dx.min()+dx.max())/2 + offset[0] - (tx.min()+tx.max())/2), .5)
        donors = np.column_stack((dy + offset[1], dx + offset[0]))
        copied = nearest = 0
        for y, x in np.argwhere(self.base):
            index = int(np.argmin(np.sum((donors - [y, x]) ** 2, axis=1)))
            self.assertTrue(np.array_equal(self.boot[y, x], donor[dy[index], dx[index]]))
            if np.array_equal(donors[index], [y, x]): copied += 1
            else: nearest += 1
        self.assertEqual((copied, nearest), (152, 36))
        self.assertEqual(int(self.base.sum()), 188)
        # Approved paint and registered solo disagree only at these fringes.
        self.assertEqual(np.argwhere(self.solo & ~self.base).tolist(), [[230,87],[231,87],[233,78]])
        self.assertFalse((self.boot[self.solo & ~self.base, 3] > 0).any())
        self.assertEqual(int(outline_class(self.boot, rules(CASE,'rear'))[self.base].sum()), 22)

    def test_hidden_rest_source_ownership_and_four_pixel_top_tuck(self):
        self.assertEqual(read(CASE / 'inputs.json')['design_placeholders'], {})
        self.assertEqual(read(CASE / 'cutout.json')['design_placeholders'], {})
        visible = next(p for p in self.layout['parts'] if p['name'] == 'foot_near')
        self.assertFalse(source_pixels(CASE, visible)[...,3].any())
        self.assertEqual(self.part['bone'], 'foot_near')
        self.assertEqual(self.layout['joints']['foot_near']['parent'], 'hem_near')
        self.assertTrue(self.part['occluded_surface'])
        self.assertEqual(source_errors(CASE, self.layout, read(CASE/'proof/build.json')), [])
        tuck = np.asarray(Image.open(CASE/'tucks/rear_foot_near.png')) > 0
        report = next(t for t in read(CASE/'proof/build.json')['views']['rear']['tucks'] if t['piece']=='foot_near')
        self.assertEqual(report['minimum_px'],4)
        self.assertTrue(tuck.any())
        self.assertTrue((self.boot[tuck,3]==255).all())
        self.assertFalse(outline_class(self.boot,rules(CASE,'rear'))[tuck].any())

    def test_every_presented_foot_uses_the_same_planted_or_moving_hem_parent(self):
        samples = [r for r in read(CASE/'proof/samples.json')['samples'] if r['view']=='rear' and r['kind']=='presented']
        moving = False
        for row in samples:
            self.assertIn(self.part['name'],row['parts'])
            hem, foot = [matrix(row['bones'][name]['global']) for name in ('hem_near','foot_near')]
            self.assertTrue(np.allclose(hem[:2,:2], foot[:2,:2], atol=EPSILON, rtol=0))
            delta = foot[:2,2] - self.layout['joints']['foot_near']['position']
            if row['clip'] not in ('move','death'):
                self.assertTrue(np.allclose(delta,0,atol=EPSILON,rtol=0))
            if row['clip']=='move' and np.linalg.norm(delta)>FIXTURE_MOVEMENT_MIN_PX: moving=True
        self.assertTrue(moving)

    def test_dark_slab_mutation_fails_source_and_native_material_gates(self):
        mutated = self.boot.copy()
        # Test-only patch wholly inside the borrowed heel, not its top tuck.
        patch = np.zeros(self.base.shape,dtype=bool)
        y,x=FIXTURE_SLAB_YX
        patch[y:y+3,x:x+3]=True
        self.assertTrue(self.base[patch].all())
        mutated[patch]=FIXTURE_SLAB_RGBA
        with tempfile.TemporaryDirectory(prefix='rr10-boot-slab-') as folder:
            case=Path(folder)/'case'
            shutil.copytree(CASE,case,ignore=shutil.ignore_patterns('proof'))
            x,y,right,bottom=self.part['bbox']
            Image.fromarray(mutated[y:bottom,x:right]).save(case/self.part['file'])
            errors=source_errors(case,self.layout,read(CASE/'proof/build.json'))
            self.assertIn('occluded donor surface differs: foot_near',errors)
            self.assertIn('dark-slab: occluded donor surface: foot_near',errors)
        record=self.layout['proof_layers'][self.part['name']]
        checks=Image.new('RGBA',(255,255))
        checks.paste(Image.open(CASE/record['mask']),tuple(record['mask_offset']))
        metric=clean_metrics([(self.part,mutated,np.asarray(checks))],rules(CASE,'rear'))
        self.assertGreater(metric['dark_slab_blocks'],0)
        self.assertEqual(metric['exposed_outline_pixels'],0)  # Base outline is authorized boot paint.

    def test_transparent_boot_regression_fails_the_donor_gate(self):
        with tempfile.TemporaryDirectory(prefix='rr10-missing-boot-') as folder:
            case=Path(folder)/'case'
            shutil.copytree(CASE,case,ignore=shutil.ignore_patterns('proof'))
            x,y,right,bottom=self.part['bbox']
            Image.new('RGBA',(right-x,bottom-y)).save(case/self.part['file'])
            self.assertIn('occluded donor surface differs: foot_near',source_errors(case,self.layout,read(CASE/'proof/build.json')))


if __name__ == '__main__': unittest.main()
