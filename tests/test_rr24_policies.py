"""Decided Thrall air/ownership rules: paint and tucks can never become air."""
from copy import deepcopy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/arc_thrall')]
from rr24_build import CASE,read_json
from rr24_seams import SkirtAirPolicy,frame_report
from tools.humanoid_cutout.cpu_pose import CpuPose,MeshSamples
from tools.humanoid_cutout.silhouette_gates import OwnedPixels
from maquette_motion.pixels import PROOF_DEFAULTS

FIXTURE_SIZE_PX=24
FIXTURE_BODY=(slice(4,20),slice(4,20))
FIXTURE_AIR=(slice(8,12),slice(8,12))
FIXTURE_SPLIT_X=10
FIXTURE_PUNCH=(slice(5,7),slice(6,8))
FIXTURE_SKIN_PUNCH=(slice(5,7),slice(12,14))
FIXTURE_JOINT_PUNCH=(slice(5,7),slice(9,11))
FIXTURE_CHECK=(255,0,0,255)


class ThrallAirTests(unittest.TestCase):
    def setUp(self):
        folder=tempfile.TemporaryDirectory(prefix='rr24-air-');self.addCleanup(folder.cleanup)
        self.case=Path(folder.name)
        (self.case/'rr24_policy.json').write_bytes((CASE/'rr24_policy.json').read_bytes())
        self.source=np.zeros((FIXTURE_SIZE_PX,)*2,dtype=bool)
        self.source[FIXTURE_BODY]=True;self.source[FIXTURE_AIR]=False
        self.anatomy={'ownership':{'names':['loincloth','thigh_near','torso'],
            'joint_pairs':[['loincloth','thigh_near'],['loincloth','torso']],
            'segments':{},'free_space_owners':[]}}
        self.layout={'canvas_size':[FIXTURE_SIZE_PX]*2,'parts':[],'proof_layers':{},'joints':{}}
        self.maps={};self.allowed={}
        offset=PROOF_DEFAULTS['source_offset'];size=PROOF_DEFAULTS['canvas_size']
        yy,xx=np.indices(self.source.shape);uv=np.column_stack((xx.ravel(),yy.ravel()))
        for name,logical,section in [('skirt','loincloth',slice(None,FIXTURE_SPLIT_X)),
                                      ('leg','thigh_near',slice(FIXTURE_SPLIT_X,None))]:
            mask=np.zeros_like(self.source);mask[:,section]=self.source[:,section]
            rgba=np.zeros((*mask.shape,4),dtype=np.uint8);rgba[mask]=FIXTURE_CHECK
            Image.fromarray(rgba).save(self.case/(name+'.png'))
            self.layout['parts'].append({'name':name,'logical_part':logical,'offset':[0,0]})
            self.layout['proof_layers'][name]={'mask':name+'.png','mask_offset':[0,0]}
            self.maps[name]=MeshSamples(uv+offset,uv)
            raster=np.zeros((size,size),dtype=bool);raster[offset:offset+FIXTURE_SIZE_PX,offset:offset+FIXTURE_SIZE_PX]=mask
            self.allowed[name]=raster
        with patch('rr24_seams.load',return_value=self.anatomy):
            self.policy=SkirtAirPolicy(self.case,self.layout)

    def posed(self,source=None):
        source=self.source if source is None else source
        size=PROOF_DEFAULTS['canvas_size'];offset=PROOF_DEFAULTS['source_offset']
        occupied=np.zeros((size,size),dtype=bool)
        occupied[offset:offset+FIXTURE_SIZE_PX,offset:offset+FIXTURE_SIZE_PX]=source
        owners=occupied.astype(np.uint8).view(OwnedPixels);owners.ownership=self.anatomy['ownership']
        owners[:,offset+FIXTURE_SPLIT_X:]*=2
        return occupied,owners

    def report(self,source=None,allowed=None):
        occupied,owners=self.posed(source)
        return self.policy.report(occupied,owners,np.ones_like(occupied),[],{'clip':'jab'},self.maps,allowed)

    def test_skinned_skirt_leg_air_is_reported_with_bounds(self):
        report=self.report()
        self.assertEqual(report['failures'],[])
        self.assertEqual([(p['bbox'],p['pixel_count'],p['painted_or_tuck_pixels'])for p in report['air_pockets']],
                         [([136,136,140,140],16,0)])

    def test_holes_through_cloth_skin_and_joint_fail(self):
        for punch in [FIXTURE_PUNCH,FIXTURE_SKIN_PUNCH,FIXTURE_JOINT_PUNCH]:
            damaged=self.source.copy();damaged[punch]=False
            report=self.report(damaged)
            self.assertEqual([p['painted_or_tuck_pixels']for p in report['failures']],[4])
            self.assertEqual(len(report['air_pockets']),1)

    def test_missing_tuck_and_hidden_non_boundary_piece_fail(self):
        for name in ('skirt','hidden_torso'):
            if name=='hidden_torso':
                self.layout['parts'].append({'name':name,'logical_part':'torso','offset':[0,0]})
                self.maps[name]=self.maps['skirt']
                self.policy.allowed[name]=np.zeros_like(self.source)
            self.policy.allowed[name][9,9]=True
            report=self.report()
            self.assertEqual(len(report['failures']),1)
            self.assertEqual(report['failures'][0]['painted_or_tuck_pixels'],1)
            self.policy.allowed[name][9,9]=False

    def test_native_mask_path_rejects_painted_holes(self):
        damaged=self.source.copy();damaged[FIXTURE_PUNCH]=False
        report=self.report(damaged,self.allowed)
        self.assertEqual([p['painted_or_tuck_pixels']for p in report['failures']],[4])
        self.assertEqual(len(report['air_pockets']),1)

    def test_policy_does_not_allow_torso_belt_air(self):
        occupied,owners=self.posed();owners[owners==2]=3
        report=self.policy.report(occupied,owners,np.ones_like(occupied),[],{'clip':'jab'},self.maps)
        self.assertEqual(report['air_pockets'],[])
        self.assertEqual([p['pixel_count']for p in report['failures']],[16])


class ThrallRealPolicyTests(unittest.TestCase):
    def test_director_tether_pocket_maps_to_air(self):
        layout=read_json(CASE/'layouts/front.json');model=CpuPose(CASE,layout)
        pose=next(p for p in read_json(CASE/'proof/samples.json')['samples']
                  if p['view']=='front'and p['clip']=='tether'and p['frame']==17 and p['kind']=='presented')
        report=frame_report(model,pose)[-1]
        self.assertEqual(report['failures'],[])
        self.assertIn(([265,305,268,309],8),[(p['bbox'],p['pixel_count'])for p in report['air_pockets']])
        self.assertTrue(all(p['painted_or_tuck_pixels']==0 for p in report['air_pockets']))

    def test_joint_registered_continuations_close_real_seams(self):
        samples=read_json(CASE/'proof/samples.json')['samples']
        for view,clip,frame in [('front','jab',11),('front','jab',12),('rear','death',71)]:
            model=CpuPose(CASE,read_json(CASE/f'layouts/{view}.json'))
            pose=next(p for p in samples if p['view']==view and p['clip']==clip and p['frame']==frame and p['kind']=='presented')
            self.assertEqual(frame_report(model,pose)[-1]['failures'],[])
            overrides={p['name']:model.image(p['file']).copy() for p in model.layout['parts']}
            for name,image in overrides.items():
                if name.startswith('joint_tuck_'):image[:]=0
            self.assertTrue(frame_report(model,pose,source_overrides=overrides)[-1]['failures'])

    def test_native_composer_keeps_original_code_and_private_validator(self):
        import rr24_native_proof
        from rr24_native_gates import errors
        from tools.humanoid_cutout import proof
        self.assertIs(rr24_native_proof.compose.__code__,proof.compose.__code__)
        self.assertIs(rr24_native_proof.compose.__globals__['native_errors'],errors)
        self.assertIsNot(proof.native_errors,errors)


if __name__=='__main__':unittest.main(verbosity=2)
