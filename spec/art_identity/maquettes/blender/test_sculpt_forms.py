"""Director-feedback regression proof for native forms, contacts and crops."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

from .compile_recipe import compile_recipe
from .contract import digest, validate
from .limb_mesh import section_mesh
from .sculpt_profile import deform, sculpt_weight, validate_profile
from .sewn_garment import topology_report
from .solid_review import front_crop

ROOT=Path(__file__).resolve().parents[1]


class SculptFormsTests(unittest.TestCase):
    def recipe(self,name):return json.loads((ROOT/name/'measurements.json').read_text())

    def test_director_joint_and_label_locks_survive_form_revision(self):
        for name in ('burrow_grub','ember_tick','glacial_mirror'):
            data=self.recipe(name)
            self.assertEqual(digest(data['joints_px']),data['feedback_1_contract']['locked_joints_sha256'])
            self.assertEqual(digest(data['labels']),data['feedback_1_contract']['locked_labels_sha256'])

    def test_limb_sections_are_closed_curved_and_spines_are_real_volume(self):
        points=[[0,0,0],[.15,.1,.08],[.25,.23,-.10],[.28,.3,-.24]]
        sculpt={'ridge_depth':.1,'ridge_count':3,'asymmetry':.04,'spines':[]}
        vertices,faces=section_mesh(points,[.07,.09,.04,.003],sculpt)
        self.assertEqual(topology_report(vertices,faces),{'connected':True,'nonmanifold_edges':0,'boundary_loops':0})
        self.assertEqual((vertices,faces),section_mesh(points,[.07,.09,.04,.003],sculpt))
        sculpt['spines']=[{'t':.5,'angle':-1.2,'length':.04,'radius':.008}]
        spined,polygons=section_mesh(points,[.07,.09,.04,.003],sculpt)
        self.assertGreater(len(spined),len(vertices))
        self.assertEqual(topology_report(spined,polygons)['nonmanifold_edges'],0)

    def test_fracture_chip_is_a_closed_tapered_volume(self):
        from .mass_fracture import wedge
        vertices,faces=wedge([.1,-.2,.3],[.08,.025,.12],[.2,.4,.7])
        self.assertEqual(topology_report(vertices,faces),{'connected':True,'nonmanifold_edges':0,'boundary_loops':0})
        self.assertEqual((vertices,faces),wedge([.1,-.2,.3],[.08,.025,.12],[.2,.4,.7]))
        self.assertEqual(len(vertices),6)
        self.assertEqual(sum(len(face)==3 for face in faces),2)

    def test_tick_knee_remains_the_upper_lower_boundary(self):
        spec=compile_recipe(self.recipe('ember_tick'))
        pieces={p['id']:p for p in spec['pieces']}
        for side in ('near','far'):
            for i in range(1,5):
                key=f'leg_{side}_{i}'
                upper,lower=(pieces[key+'_'+part] for part in ('upper','lower'))
                np.testing.assert_allclose(upper['path'][-1],spec['joints'][key+'_1'],atol=1e-12)
                np.testing.assert_allclose(lower['path'][0],upper['path'][-1],atol=1e-12)
                self.assertGreaterEqual(len(lower['path']),4)
                self.assertTrue(upper['sculpt']['spines'] and lower['sculpt']['spines'])

    def test_skin_caps_are_softened_folds_asymmetric_and_relief_nonconstant(self):
        spec=compile_recipe(self.recipe('burrow_grub'))
        mass=next(p for p in spec['pieces'] if p['id']=='seg_3')
        profile=mass['profile'];radii=mass['radii']
        bottom=deform([0,0,-radii[2]],radii,profile)
        self.assertGreater(bottom[2],-radii[2])
        points=[[x*.02,y*.02,.1] for x in range(10) for y in range(10)]
        weights=[sculpt_weight(p,mass['relief'],profile) for p in points]
        self.assertGreater(max(weights)-min(weights),.1)
        bad=deepcopy(profile);bad['underside']['compression']=0
        with self.assertRaises(ValueError):validate_profile(bad)

    def test_stone_feet_require_real_contacts_and_thick_ground_supported_volumes(self):
        spec=compile_recipe(self.recipe('glacial_mirror'))
        self.assertEqual(len(spec['native_contacts']),8)
        self.assertIn(['shoulder_far_mass','shoulder_far_bedding'],spec['native_contacts'])
        self.assertIn(['shoulder_far_bedding','torso'],spec['native_contacts'])
        self.assertIn(['upper_far','elbow_far_bedding'],spec['native_contacts'])
        self.assertIn(['elbow_far_bedding','fore_far'],spec['native_contacts'])
        for side in ('near','far'):
            foot=next(p for p in spec['pieces'] if p['id']=='foot_'+side)
            self.assertGreater(foot['radii'][2]*2,foot['minimum_support_thickness'])
            self.assertEqual(foot['support_z'],.15)
            self.assertTrue(foot['fractures'])
        bad=deepcopy(spec);bad['native_contacts']=[['shin_far','missing']]
        with self.assertRaises(ValueError):validate(bad)

    def test_two_times_crop_preserves_native_pixels_and_clay_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);(folder/'delivery').mkdir()
            native=Image.new('RGBA',(64,64));native.paste((110,90,80,255),(20,22,40,45))
            source=folder/'delivery/front_clay.png';native.save(source);before=source.read_bytes()
            result=front_crop(folder);self.assertTrue(result['rgba_identical'])
            proof=json.loads((folder/'delivery/review/front_clay_2x.json').read_text())
            expected=native.crop(proof['source_bounds_px']);expected=expected.resize((expected.width*2,expected.height*2),Image.Resampling.NEAREST)
            with Image.open(folder/'delivery/review/front_clay_2x.webp') as actual:
                np.testing.assert_array_equal(np.asarray(actual.convert('RGBA')),np.asarray(expected))
            self.assertEqual(source.read_bytes(),before)


if __name__=='__main__':unittest.main()
