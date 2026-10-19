"""Nearest own-surface continuations, rounded domains and strict green checks."""
from pathlib import Path
import sys
import tempfile
import json
import unittest
from unittest.mock import patch
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/glacial_mirror')]
from humanoid_cutout.material_gates import green_dominant, colour_errors
from rr18_materials import continue_surfaces, continuation_errors, surface_donors
import rr18_source_stage as source_stage

FIXTURE_SIZE=24
FIXTURE_SURFACE_A=(70,80,100,255)
FIXTURE_SURFACE_B=(110,120,140,255)
FIXTURE_FLAT=(180,180,180,255)
FIXTURE_GREEN=(20,60,20,255)
FIXTURE_SEED=(12,12)
DIRECTOR_MARGIN=12
DIRECTOR_DEPTH=3


class MaterialTests(unittest.TestCase):
    def setUp(self):
        stone=np.zeros((FIXTURE_SIZE,FIXTURE_SIZE,4),dtype=np.uint8)
        stone[8:16,8:12]=FIXTURE_SURFACE_A
        stone[12:16,8:12]=FIXTURE_SURFACE_B
        cover=np.zeros_like(stone);cover[6:18,12:18]=FIXTURE_SURFACE_A
        self.visible={'stone':stone,'neighbour':cover}
        self.hidden={'stone':np.zeros_like(stone)}
        self.hidden['stone'][10:14,12]=FIXTURE_FLAT
        self.anatomy={'joint_continuations':{'depth_px':DIRECTOR_DEPTH},
                      'material_policy':{'green_dominance_margin':DIRECTOR_MARGIN}}
        self.definition={'visible_luma_cutoff':0,'outline_palette':[]}
        self.recipes={'rear':{'stone':{'source_points':[FIXTURE_SEED],'covers':['neighbour']}}}

    def repair(self):
        with patch('rr18_materials.read_json',return_value=self.recipes):
            return continue_surfaces(self.visible,self.hidden,self.anatomy,'rear',self.definition)

    def test_green_boundary_is_strict_and_ignores_transparent_rgb(self):
        image=np.array([[[20,32,20,255],[20,33,20,255],[20,60,20,0]]],dtype=np.uint8)
        np.testing.assert_array_equal(green_dominant(image,DIRECTOR_MARGIN),[[False,True,False]])
        self.assertEqual(colour_errors(image,self.anatomy['material_policy']),['green-dominant texels: 1'])
        self.assertEqual(colour_errors(image,{}),[])

    def test_green_cannot_supply_a_continuation(self):
        self.visible['stone'][10,11]=FIXTURE_GREEN
        donors=surface_donors(self.visible['stone'],DIRECTOR_MARGIN)
        self.assertEqual(donors[10,11,3],0)
        self.repair()
        self.assertFalse(green_dominant(self.hidden['stone'],DIRECTOR_MARGIN).any())

    def test_extension_is_rounded_connected_and_beneath_rest_cover(self):
        before=self.hidden['stone'][...,3]>0
        self.repair()
        added=(self.hidden['stone'][...,3]>0)&~before
        y,x=np.nonzero(added);sx,sy=FIXTURE_SEED
        self.assertTrue(added.any())
        self.assertTrue(((x-sx)**2+(y-sy)**2<=DIRECTOR_DEPTH**2).all())
        self.assertTrue((self.visible['neighbour'][...,3][added]>0).all())

    def test_continuations_use_exact_varied_own_surface_texels(self):
        self.repair()
        pixels=self.hidden['stone'];colours={tuple(c) for c in pixels[pixels[...,3]>0]}
        self.assertEqual(colours,{FIXTURE_SURFACE_A,FIXTURE_SURFACE_B})
        self.assertEqual(continuation_errors(self.visible,self.hidden,self.anatomy,self.definition),[])

    def test_flat_patch_mutation_is_rejected(self):
        self.repair()
        image=self.hidden['stone'];image[image[...,3]>0]=FIXTURE_FLAT
        self.assertTrue(continuation_errors(self.visible,self.hidden,self.anatomy,self.definition))

    def test_uncovered_edge_extension_is_round_not_a_rectangle(self):
        self.visible['neighbour'][:]=0
        self.repair()
        self.assertEqual(self.hidden['stone'][12,15,3],255)
        self.assertEqual(self.hidden['stone'][15,15,3],0)

    def test_visible_cleanup_does_not_modify_the_raw_authoring_input(self):
        self.visible['stone'][10,11]=FIXTURE_GREEN
        before=self.visible['stone'].copy()
        cleaned,corrections=source_stage.clean_visible(self.visible,DIRECTOR_MARGIN)
        np.testing.assert_array_equal(self.visible['stone'],before)
        self.assertEqual(len(corrections),1)
        self.assertEqual(tuple(cleaned['stone'][10,11]),FIXTURE_SURFACE_A)
        self.assertFalse(green_dominant(cleaned['stone'],DIRECTOR_MARGIN).any())

    def test_raw_authoring_identity_and_tamper_gate_remain_exact(self):
        from PIL import Image
        with tempfile.TemporaryDirectory(prefix='rr18-raw-stage-') as folder:
            case=Path(folder);(case/'approved').mkdir()
            source=Image.new('RGBA',(255,255))
            for image in self.visible.values():source.alpha_composite(Image.fromarray(image))
            source.save(case/'approved/processed.png')
            (case/'inputs.json').write_text(json.dumps({'front_job':'approved'}))
            with patch.object(source_stage,'CASE',case),patch.object(source_stage,'PROJECT',case):
                source_stage.raw_cut(self.visible,{'stone':0,'neighbour':1},'front')
                self.assertEqual(source_stage.raw_identity('front')['mismatch_pixels'],0)
                manifest=json.loads((case/'raw_cut/front.json').read_text())
                path=case/manifest['parts'][0]['file'];pixels=np.array(Image.open(path))
                pixels[0,0,0]^=1;Image.fromarray(pixels).save(path)
                self.assertFalse(source_stage.raw_identity('front')['ok'])


if __name__=='__main__':unittest.main(verbosity=2)
