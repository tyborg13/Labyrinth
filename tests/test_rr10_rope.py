"""Exact director rope ownership and cloth-under-tail regressions; headless."""
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
from cutout_pipeline.cases import digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import outline_class, rules
from maquette_motion.silhouette import components
from humanoid_cutout.gates import source_errors

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
MASK_SHA256 = '26bc001a33b23ba21dada83c27e8c0e1d7fd21eb067e7b5ded4329509595444c'
IDLE_DROP_SOURCE_PX = 2  # Binding spec; no test-selected animation value.


def read(path):
    return json.loads(path.read_text())


def visible_source(case, part, layout):
    image = source_pixels(case, part)
    record = layout['proof_layers'][part['name']]
    checks = Image.new('RGBA', (255,255))
    checks.paste(Image.open(case / record['mask']).convert('RGBA'), tuple(record['mask_offset']))
    image[np.asarray(checks)[...,1] > 0] = 0
    return image


def replace_pixel(case, part, y, x, rgba):
    image = np.asarray(Image.open(case / part['file']).convert('RGBA')).copy()
    image[y-part['offset'][1], x-part['offset'][0]] = rgba
    Image.fromarray(image).save(case / part['file'])


class RopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = read(CASE / 'inputs.json')
        cls.layout = read(CASE / 'layouts/front.json')
        cls.build = read(CASE / 'proof/build.json')
        cls.record = cls.layout['ownership_overrides'][0]
        cls.mask = np.asarray(Image.open(CASE / cls.record['file']))[...,3] > 0
        cls.required = np.asarray(Image.open(CASE / cls.record['underlay_required_mask'])) > 0
        cls.paint = np.asarray(Image.open(CASE / cls.layout['rest_source']).convert('RGBA'))

    def test_protected_exact_mask_and_rear_input_contract(self):
        self.assertEqual(digest(CASE / self.record['file']), MASK_SHA256)
        self.assertEqual(self.record['sha256'], MASK_SHA256)
        self.assertEqual(int(self.mask.sum()), 465)
        self.assertEqual(len(components(self.mask)[1]), 1)
        self.assertTrue(np.all(np.asarray(Image.open(CASE / self.record['file']))[self.mask] == 255))
        self.assertEqual(self.inputs['rope_masks']['rear']['file'], 'inputs/rope_mask_rear.png')
        rear=self.inputs['rope_masks']['rear']
        self.assertEqual(digest(CASE/rear['file']),rear['sha256'])
        self.assertEqual((CASE/rear['file']).read_bytes(),(PROJECT/'spec/peer_benchmark/staged/rr-10/rope_mask_rear.png').read_bytes())
        self.assertEqual(rear['pixels'],242)
        self.assertNotIn('rope_colour_connectivity', self.inputs)
        self.assertNotIn('TODO_DESIGN_mq6_rear_delivery_and_paint', read(CASE / 'cutout.json')['design_placeholders'])

    def test_masked_pixels_are_torso_and_unmasked_ownership_is_unchanged(self):
        baseline_path = PROJECT / self.build['source_ownership']
        old = read(baseline_path)
        for part in self.layout['parts']:
            if part.get('hidden_material'): continue
            actual = visible_source(CASE, part, self.layout)
            original = np.zeros_like(self.paint)
            for source in old['parts']:
                if any(source.get(k) for k in ('hidden_material','seam_underlay','silhouette_backing')): continue
                if source.get('logical_part') not in self.layout['source_labels'][part['logical_part']]: continue
                layer = source_pixels(baseline_path.parent.parent, source)
                selected = layer[...,3] > 0
                original[selected] = layer[selected]
            with self.subTest(piece=part['name']):
                self.assertTrue(np.array_equal(actual[~self.mask], original[~self.mask]))
                if part['name'] == 'torso': self.assertTrue(np.array_equal(actual[self.mask], self.paint[self.mask]))
                else: self.assertFalse(actual[self.mask,3].any())
        self.assertEqual(self.build['ownership_overrides'][0]['previous_owners'], {'torso':391,'robe':74})
        self.assertEqual(source_errors(CASE, self.layout, self.build), [])

    def test_cloth_covers_tail_area_uncovered_by_the_authored_idle_drop(self):
        robe = source_pixels(CASE, next(p for p in self.layout['parts'] if p['name']=='robe'))
        self.assertEqual(int(self.required.sum()), 74)
        self.assertTrue(np.all(robe[self.required,3] == 255))
        self.assertFalse(outline_class(robe, rules(CASE,'front'))[self.required].any())
        shifted = np.zeros_like(self.mask)
        shifted[IDLE_DROP_SOURCE_PX:] = self.mask[:-IDLE_DROP_SOURCE_PX]
        exposed = self.required & ~shifted
        self.assertTrue(exposed.any())
        self.assertTrue(np.all(robe[exposed,3] == 255))
        self.assertFalse(np.array_equal(robe[self.required], self.paint[self.required]))

    def test_mask_tampering_fails_the_hash_gate(self):
        with tempfile.TemporaryDirectory(prefix='rr10-rope-hash-') as folder:
            case = Path(folder) / 'case'
            shutil.copytree(CASE, case, ignore=shutil.ignore_patterns('proof'))
            image = np.asarray(Image.open(case / self.record['file'])).copy()
            image[self.mask] = 0
            Image.fromarray(image).save(case / self.record['file'])
            errors = source_errors(case, self.layout, self.build)
            self.assertIn('protected ownership mask hash differs: inputs/rope_mask_front.png', errors)

    def test_missing_hidden_cloth_fails_even_though_the_rope_covers_it_at_rest(self):
        with tempfile.TemporaryDirectory(prefix='rr10-rope-cloth-') as folder:
            case = Path(folder) / 'case'
            shutil.copytree(CASE, case, ignore=shutil.ignore_patterns('proof'))
            part = next(p for p in self.layout['parts'] if p['name']=='robe')
            y,x = np.argwhere(self.required)[0]
            replace_pixel(case, part, y, x, [0,0,0,0])
            errors = source_errors(case, self.layout, self.build)
            self.assertIn('ownership override missing cloth continuation: robe', errors)
            self.assertNotIn('rest: composed source mismatch', errors)

    def test_rope_returned_to_mesh_fails_despite_identical_composed_rest(self):
        with tempfile.TemporaryDirectory(prefix='rr10-rope-owner-') as folder:
            case = Path(folder) / 'case'
            shutil.copytree(CASE, case, ignore=shutil.ignore_patterns('proof'))
            y,x = np.argwhere(self.required)[0]
            torso = next(p for p in self.layout['parts'] if p['name']=='torso')
            robe = next(p for p in self.layout['parts'] if p['name']=='robe')
            replace_pixel(case, torso, y, x, [0,0,0,0])
            replace_pixel(case, robe, y, x, self.paint[y,x])
            errors = source_errors(case, self.layout, self.build)
            self.assertIn('ownership partition differs: torso', errors)
            self.assertNotIn('rest: composed source mismatch', errors)


if __name__ == '__main__': unittest.main()
