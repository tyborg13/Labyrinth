"""Corrective native forms and director feedback 2 construction constraints."""
from copy import deepcopy
import json
import unittest
from collections import Counter
import numpy as np
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.hollow_mimic.batch_proof import ROOT

FIXTURE = {'axis': [[0.,0,0],[0.,0,2]], 'points': [[1.,0,.5],[-1.,0,1.5],[0.,2,1]],
           'ring': [[1.,0,1],[0,1.,1],[-1.,0,1],[0,-1.,1]],
           'fabric': {'folds':3,'depth_m':.03,'rag_m':.1,'tears':5,'thick_m':.02},
           'affine_points': [[0.,0,0],[.1,0,.1],[.2,0,.2],[0,.2,.1]],
           'profile_outline': [[90,70],[140,70],[140,150],[90,150]]}


class CorrectiveFormsTests(unittest.TestCase):
    def recipe(self,name):
        return json.loads((ROOT/name/'measurements.json').read_text())

    def test_radial_sculpt_preserves_axial_positions_and_unowned_skin(self):
        from spec.art_identity.maquettes.blender.form_finish import finish
        points=np.array(FIXTURE['points']);original=points.copy()
        result=finish(points,[],[{'root':1},{'root':1},{'other':1}],
                      [{'region':'root','head':'a','tail':'b'}],
                      dict(zip(('a','b'),FIXTURE['axis'])),{'radial_scales':{'root':1.3}})
        np.testing.assert_allclose(result[:2,:2],points[:2,:2]*1.3)
        np.testing.assert_array_equal(result[:,2],points[:,2])
        np.testing.assert_array_equal(result[2],points[2])
        np.testing.assert_array_equal(points,original)

    def test_folded_fabric_is_closed_thick_and_preserves_input(self):
        from spec.art_identity.maquettes.blender.folded_fabric import sculpt
        rows=[FIXTURE['ring'],(np.array(FIXTURE['ring'])*[1.4,1.4,.2]).tolist()]
        original=deepcopy(rows)
        vertices,faces=sculpt(rows,True,FIXTURE['fabric'])
        edges=Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,face[1:]+face[:1]))
        self.assertTrue(edges)
        self.assertEqual(set(edges.values()),{2})
        self.assertEqual(rows,original)
        half=len(vertices)//2
        np.testing.assert_allclose(np.linalg.norm(np.array(vertices[:half])-vertices[half:],axis=1),.02,atol=1e-10)

    def test_affine_core_keeps_native_samples_affine(self):
        from spec.art_identity.maquettes.blender.source_cage import fit_points
        spec=compile_recipe(self.recipe('hollow_mimic'))
        points=np.array(FIXTURE['affine_points'])
        polygon=FIXTURE['profile_outline']
        result=fit_points(spec,points,{'front':polygon},'affine_core',points)
        np.testing.assert_allclose(result[1],(result[0]+result[2])/2,atol=1e-12)
        np.testing.assert_array_equal(points[0],[0,0,0])

    def test_mimic_has_one_unified_nine_lock_sculpt_and_four_suit_segments(self):
        recipe=self.recipe('hollow_mimic');spec=compile_recipe(recipe)
        hair=next(p for p in spec['pieces'] if p['id']=='hair_crown')
        self.assertEqual(len(hair['swept_sections']),9)
        self.assertTrue(all(section['radii'][-1] < section['radii'][0]/10 for section in hair['swept_sections']))
        self.assertEqual(len([p for p in spec['pieces'] if p['id'].startswith('suit_')]),4)
        self.assertEqual(set(spec['base']['half_open_hands']),{'near','far'})
        for side in ('near','far'):
            self.assertTrue(any(p['id']=='ankle_boot_'+side and p['part']=='foot_'+side for p in spec['pieces']))
            self.assertTrue(any(p['id']=='thick_sole_'+side for p in spec['pieces']))

    def test_briar_hood_and_mantle_are_shaped_meshes_with_sculpted_folds(self):
        recipe=self.recipe('briar_weaver');spec=compile_recipe(recipe)
        hood=next(p for p in spec['pieces'] if p['id']=='bark_leaf_hood')
        mantle=next(p for p in spec['pieces'] if p['id']=='shaggy_leaf_clumps')
        self.assertEqual(hood['type'],'rigid_shell')
        self.assertEqual(mantle['type'],'rigid_shell')
        self.assertGreater(len(hood['vertices']),5000)
        self.assertGreater(len(mantle['vertices']),1000)
        self.assertFalse(any(p['id']=='leaf_mantle' for p in spec['pieces']))
        self.assertTrue(spec['base']['form_finish']['spirals'])

    def test_mortar_ratio_bands_and_apron_are_the_requested_forms(self):
        recipe=self.recipe('slag_mortar');spec=compile_recipe(recipe)
        cup=next(p for p in spec['pieces'] if p['id']=='crucible')
        length=np.linalg.norm(np.array(cup['path'][-1])-cup['path'][0])
        diameter=2*cup['radius']*max(cup['taper'])
        self.assertAlmostEqual(length/diameter,.8,places=5)
        data=next(s for s in recipe['surfaces'] if s['id']=='crucible')
        self.assertEqual(len([b for b in data['bands'] if b.get('role')!='rolled_rim']),2)
        self.assertEqual(len([b for b in data['bands'] if b.get('role')=='rolled_rim']),1)
        self.assertTrue(all(p['thick']==.012 for p in spec['pieces'] if p['part']=='apron'))

    def test_invalid_new_shape_controls_fail_before_native_jobs(self):
        recipe=self.recipe('hollow_mimic');recipe['form_finish']['radial_scales']['unknown']=1.3
        with self.assertRaisesRegex(ValueError,'unknown anatomical region'):compile_recipe(recipe)
        recipe=self.recipe('hollow_mimic');recipe['half_open_hands']['near']=2
        with self.assertRaisesRegex(ValueError,'Half-open hand'):compile_recipe(recipe)


class FormDeliveryProofTests(unittest.TestCase):
    def test_clean_regeneration_inventory_is_the_current_builder_and_recipe(self):
        from spec.art_identity.maquettes.blender.curate_delivery import sha
        from spec.art_identity.maquettes.blender.compile_recipe import PROJECT
        for name in ('hollow_mimic','briar_weaver','slag_mortar'):
            path=ROOT/name/'delivery/validation/regeneration/clean_input_sha256.json'
            inventory=json.loads(path.read_text())
            for relative,expected in inventory.items():
                self.assertEqual(sha(PROJECT/relative),expected,(name,relative))

    def test_painting_clay_pairs_and_before_after_table_are_bound_to_current_inputs(self):
        from spec.art_identity.maquettes.blender.curate_delivery import sha
        folder=ROOT/'hollow_mimic/delivery/review'
        receipt=json.loads((folder/'contact_sheet.json').read_text())
        before=json.loads((folder/'form_revision_before.json').read_text())
        table=(folder/'fit_table.md').read_text()
        for row,name in enumerate(('hollow_mimic','briar_weaver','slag_mortar')):
            recipe=json.loads((ROOT/name/'measurements.json').read_text())
            fit=json.loads((ROOT/name/'delivery/fit_report.json').read_text())
            for j,view in enumerate(('front','rear')):
                pair=[cell for cell in receipt['cells'] if cell['row']==row and cell['column'] in (2*j,2*j+1)]
                self.assertEqual([c['kind'] for c in pair],['painting','clay'])
                self.assertEqual([c['source_scale'] for c in pair],[4,1])
                self.assertEqual(sha(ROOT/pair[0]['path']),recipe['source_sha256'][view])
                self.assertEqual(sha(ROOT/pair[1]['path']),sha(ROOT/name/'delivery'/f'{view}_clay.png'))
                self.assertIn(f"{before[name]['fit_report']['views'][view]['iou']:.9f}",table)
                self.assertIn(f"{fit['views'][view]['iou']:.9f}",table)
