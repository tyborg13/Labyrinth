"""Director-approved air passes; missing stone/tuck/mirror pixels never do."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT/'tools'))
from humanoid_cutout.rigid_air import RigidAirPolicy, for_case, POLICY
from humanoid_cutout.silhouette_gates import joint_holes
from humanoid_cutout.anatomy import load, validate
from maquette_motion.pixels import PROOF_DEFAULTS

FIXTURE_SIZE_PX = 24
FIXTURE_BODY = (slice(4,20),slice(4,20))
FIXTURE_AIR = (slice(8,12),slice(8,12))
FIXTURE_SPLIT_X = 10
FIXTURE_PUNCH = (slice(5,7),slice(6,8))
FIXTURE_RGBA = [60,70,80,255]
FIXTURE_CHECK_RGBA = [255,0,0,255]
IDENTITY_TRANSFORM = [1,0,0,1,0,0]


class AirPolicyTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory(prefix='rr18-air-policy-')
        self.addCleanup(self.folder.cleanup)
        self.case=Path(self.folder.name)
        self.paint=np.zeros((FIXTURE_SIZE_PX,FIXTURE_SIZE_PX,4),dtype=np.uint8)
        self.paint[FIXTURE_BODY]=FIXTURE_RGBA
        self.paint[FIXTURE_AIR]=0
        Image.fromarray(self.paint).save(self.case/'source.png')
        self.anatomy={'seam_policy':POLICY,'seam_protected_pieces':[],
            'ownership':{'names':['left','right'],'joint_pairs':[['left','right']],
                         'segments':{},'free_space_owners':[]}}
        self.layout={'canvas_size':[FIXTURE_SIZE_PX]*2,'rest_source':'source.png',
                     'joint_meshes':[],'parts':[],'proof_layers':{}}
        for name,section in [('left',slice(None,FIXTURE_SPLIT_X)),('right',slice(FIXTURE_SPLIT_X,None))]:
            checks=np.zeros_like(self.paint)
            allowed=np.zeros(self.paint.shape[:2],dtype=bool)
            allowed[:,section]=self.paint[:,section,3]>0
            checks[allowed]=FIXTURE_CHECK_RGBA
            Image.fromarray(checks).save(self.case/(name+'.png'))
            self.layout['parts'].append({'name':name,'logical_part':name,'offset':[0,0]})
            self.layout['proof_layers'][name]={'mask':name+'.png','mask_offset':[0,0]}
        self.transforms={name:IDENTITY_TRANSFORM for name in ('left','right')}

    def posed(self, paint=None):
        paint=self.paint if paint is None else paint
        size=PROOF_DEFAULTS['canvas_size'];offset=PROOF_DEFAULTS['source_offset']
        occupied=np.zeros((size,size),dtype=bool)
        occupied[offset:offset+FIXTURE_SIZE_PX,offset:offset+FIXTURE_SIZE_PX]=paint[...,3]>0
        owners=occupied.astype(np.uint8)
        owners[:,offset+FIXTURE_SPLIT_X:]*=2
        return occupied,owners

    def report(self, paint=None):
        return RigidAirPolicy(self.case,self.layout,self.anatomy).report(*self.posed(paint),self.transforms)

    def test_air_between_stones_passes_without_a_frame_exception(self):
        report=self.report()
        self.assertEqual(report['failures'],[])
        self.assertEqual(len(report['air_pockets']),1)
        pocket=report['air_pockets'][0]
        self.assertEqual(pocket['pixel_count'],16)
        self.assertEqual(pocket['stone_pixels'],0)
        self.assertEqual(pocket['surrounding_pieces'],['left','right'])

    def test_punched_stone_interior_fails_with_single_owner_boundary(self):
        damaged=self.paint.copy();damaged[FIXTURE_PUNCH]=0
        report=self.report(damaged)
        self.assertEqual(len(report['failures']),1)
        self.assertEqual(report['failures'][0]['stone_pixels'],4)
        self.assertEqual(report['failures'][0]['surrounding_pieces'],['left'])
        self.assertEqual(len(report['air_pockets']),1)

    def test_one_missing_stone_pixel_fails(self):
        damaged=self.paint.copy();damaged[5,6]=0
        report=self.report(damaged)
        self.assertEqual(report['failures'][0]['stone_pixels'],1)

    def test_missing_piece_cannot_hide_by_disappearing_from_the_boundary(self):
        checks=np.zeros_like(self.paint);checks[9,9]=FIXTURE_CHECK_RGBA
        Image.fromarray(checks).save(self.case/'middle.png')
        self.layout['parts'].append({'name':'middle','logical_part':'middle','offset':[0,0]})
        self.layout['proof_layers']['middle']={'mask':'middle.png','mask_offset':[0,0]}
        self.anatomy['ownership']['names'].append('middle')
        self.transforms['middle']=IDENTITY_TRANSFORM
        report=self.report()
        self.assertEqual(report['failures'][0]['stone_pixels'],1)
        self.assertNotIn('middle',report['failures'][0]['surrounding_pieces'])
        self.assertEqual(report['failures'][0]['source']['middle']['painted_or_tuck_pixels'],1)

    def test_transparent_paint_does_not_exempt_a_missing_tuck(self):
        checks=np.array(Image.open(self.case/'left.png'))
        checks[9,9]=[255,255,0,255]
        Image.fromarray(checks).save(self.case/'left.png')
        report=self.report()
        self.assertEqual(len(report['failures']),1)
        self.assertEqual(report['failures'][0]['source']['left']['painted_or_tuck_pixels'],1)

    def test_protected_torso_cannot_contain_an_air_pocket(self):
        # A single logical torso owns this ring. Its transparent interior is
        # protected even though the approved source is transparent there.
        checks=np.zeros_like(self.paint);checks[self.paint[...,3]>0]=FIXTURE_CHECK_RGBA
        Image.fromarray(checks).save(self.case/'left.png')
        self.layout['parts']=self.layout['parts'][:1]
        self.anatomy['seam_protected_pieces']=['left']
        self.anatomy['ownership']['names']=['left']
        occupied,_=self.posed()
        report=RigidAirPolicy(self.case,self.layout,self.anatomy).report(occupied,occupied.astype(np.uint8),self.transforms)
        self.assertEqual(report['failures'][0]['stone_pixels'],16)
        self.assertEqual(report['failures'][0]['source']['left']['protected_silhouette_pixels'],16)

    def test_unprotected_air_stays_allowed_when_other_stones_occupy_source_coordinates(self):
        # Move the approved source's unrelated paint into the gap; neither
        # surrounding piece's silhouette/tuck acquires those texels.
        source=self.paint.copy();source[FIXTURE_AIR]=FIXTURE_RGBA
        Image.fromarray(source).save(self.case/'source.png')
        self.assertEqual(self.report()['failures'],[])

    def test_strict_default_keeps_rejecting_joint_air_for_other_figures(self):
        for creature,version in [('hoarfrost_seer','rr10'),('arc_thrall','rr11')]:
            case=PROJECT/f'experiments/cutouts/{creature}/{version}'
            anatomy=load(case)
            self.assertIsNone(for_case(case,{},anatomy))
        occupied,owners=self.posed()
        self.assertEqual(joint_holes(occupied,np.ones_like(occupied),owners,ownership=self.anatomy['ownership']),[16])

    def test_case_contract_rejects_unknown_policy_and_skinned_air_rigs(self):
        anatomy=load(PROJECT/'experiments/cutouts/glacial_mirror/rr18')
        anatomy['seam_policy']='allow_every_hole'
        with self.assertRaises(ValueError):validate(anatomy)
        layout=copy.deepcopy(self.layout);layout['joint_meshes']=[{'name':'skin'}]
        with self.assertRaisesRegex(ValueError,'skinned'):
            RigidAirPolicy(self.case,layout,self.anatomy)


if __name__=='__main__':unittest.main(verbosity=2)
