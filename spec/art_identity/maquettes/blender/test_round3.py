"""Regressions for anatomical sewn cloth and the director's metric accessories."""
import json
from pathlib import Path
from copy import deepcopy
from collections import Counter
import unittest
import numpy as np

from .compile_recipe import compile_recipe
from .sewn_garment import topology_report
from .neck_collar import oval, neck_circle
from .rounded_hood import rest_mesh
from .sculpted_blade import crescent
from .lathe_profile import smooth_axis
from .cloth_cache import topology_hash, read_cache

ROOT = Path(__file__).resolve().parents[1]
BACK_SHEET_TEST_DEFAULTS={'shoulders':['near','far'],'width_px':100,'height_px':80,'columns':12,
                          'pin_rows':[0]}


class RoundThreeTests(unittest.TestCase):
    def test_sewn_rest_is_one_surface_with_neck_waist_and_two_open_cuffs(self):
        recipe = json.loads((ROOT / 'hoarfrost_seer/measurements.json').read_text())
        spec = compile_recipe(recipe)
        cloth = next(p for p in spec['pieces'] if 'sewn_parts' in p)
        mesh = cloth['pattern']['explicit']
        self.assertEqual(topology_report(mesh['vertices'], mesh['faces']),
                         {'connected': True, 'nonmanifold_edges': 0, 'boundary_loops': 4})
        self.assertEqual(set(mesh['owners']), {list(spec['labels']).index(p) for p in cloth['sewn_parts']})
        self.assertLess(len(cloth['pattern']['pins']), len(mesh['vertices']) / 2)
        self.assertNotIn('sleeve_upper_far', [p['id'] for p in spec['pieces']])

    def test_metric_oval_dimensions_include_wire_and_alternate_space(self):
        points = oval(.06, .035, .012, 64)
        self.assertAlmostEqual(np.ptp(points[:, 0]) + .012, .035)
        self.assertAlmostEqual(np.ptp(points[:, 1]) + .012, .06)
        with self.assertRaises(ValueError):
            oval(.06, .01, .012, 64)

    def test_neck_ring_fits_the_native_cross_section_and_tilts_forward(self):
        angles = np.linspace(0, 2 * np.pi, 32, endpoint=False)
        vertices = [[.1*np.cos(a), .1*np.sin(a), z] for z in (-.2,.2) for a in angles]
        faces = [[j,(j+1)%32,(j+1)%32+32,j+32] for j in range(32)]
        centre, radius, first, second = neck_circle(vertices, faces, ['neck']*32, [0,0,0], 10, 'neck')
        self.assertGreater(radius, .1)
        np.testing.assert_allclose(centre,[0,0,0],atol=1e-9)
        self.assertAlmostEqual(np.degrees(np.arctan2(-first[2],first[0])),10)
        self.assertAlmostEqual(np.dot(first,second),0)

    def test_director_collar_and_chain_values_are_exact(self):
        spec = compile_recipe(json.loads((ROOT / 'arc_thrall/measurements.json').read_text()))
        ring = next(p for p in spec['pieces'] if p['type']=='neck_collar')
        self.assertEqual((ring['neck_clearance'],ring['tube_diameter'],ring['tilt_degrees']),(.01,.035,10))
        self.assertEqual(ring['chain'],{'count':3,'length':.06,'width':.035,'wire_diameter':.012,'alternate_degrees':90})
        self.assertEqual(ring['part'],'collar')

    def test_rounded_cowl_uses_native_skull_and_oval_opening(self):
        angles = np.linspace(0,2*np.pi,32)
        hem = [[.3*np.cos(t),.3*np.sin(t),.8] for t in angles]
        vertices,faces,pins,report=rest_mesh([[-.1,-.1,1],[.1,.1,1.3]],hem,.6,.24,.04)
        self.assertAlmostEqual(report['opening_width'], .12)
        self.assertLess(len(pins),len(vertices)/2)
        self.assertGreater(len(report['opening_rows']),2)
        self.assertGreater(len(faces),500)
        self.assertTrue(np.isfinite(vertices).all())

    def test_crescent_is_a_closed_sculpted_volume_with_one_tapering_tip(self):
        v,f=crescent([[0,.1,1],[.3,.1,.5],[0,0,0]],[[0,-.1,1],[.15,-.1,.5],[0,0,0]],.04)
        edges=Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
        self.assertTrue(all(count==2 for count in edges.values()))
        self.assertGreater(np.ptp(np.array(v)[:12,0]),.02)
        self.assertGreater(np.ptp(np.array(v)[:12,2]),0)
        np.testing.assert_allclose(v[-1],[0,0,0])

    def test_lathed_profile_preserves_measured_axis_controls_and_bell_radii(self):
        axis=[[0,0,0],[.1,0,.4],[.4,0,.8]]
        dense,radii=smooth_axis(axis,[.01,.02,.1])
        np.testing.assert_allclose(np.array(dense)[::8],axis)
        self.assertEqual(radii[::8],[.01,.02,.1])
        self.assertTrue(all(r>0 for r in radii))

    def test_sewn_ownership_is_independent_of_mutated_material_slots(self):
        from types import SimpleNamespace
        from .ownership import expected_materials,materials_match
        class Obj(dict):pass
        obj=Obj(sewn_parts=['torso','fore_far'])
        obj.data=SimpleNamespace(attributes={'sewn_owner':SimpleNamespace(data=[SimpleNamespace(value=i) for i in [0,1]])},
                                 polygons=[SimpleNamespace(material_index=0),SimpleNamespace(material_index=0)])
        owners=expected_materials(obj,{'labels':{'torso':[],'fore_far':[]}},[1,0,0])
        self.assertEqual(owners,[0,1])
        self.assertFalse(materials_match(obj,owners))
        obj.data.attributes['sewn_owner'].data[-1].value=2
        with self.assertRaisesRegex(ValueError,'unregistered'):
            expected_materials(obj,{'labels':{'torso':[],'fore_far':[]}},[1,0,0])

    def test_cache_integrity_binds_sewn_owner_tags_too(self):
        payload={key:[] for key in ('edges','loop_vertices','loop_edges','polygon_starts','polygon_totals','polygon_smooth')}
        payload['sewn_owners']=[0,1]
        before=topology_hash(payload)
        payload['sewn_owners'][1]=0
        self.assertNotEqual(before,topology_hash(payload))

    def test_back_sheet_allowance_is_a_free_grid_in_the_native_shoulder_frame(self):
        from .back_sheet import draft,frame
        spec={'joints':{'near':[0,.3,1.5],'far':[0,-.3,1.4]},'ortho_scale':2.4}
        config=BACK_SHEET_TEST_DEFAULTS
        recipe=json.loads((ROOT/'gloam_stalker/measurements.json').read_text())
        physics=deepcopy(recipe['surfaces'][0]['drape'])
        physics['pin_rows']=config['pin_rows']
        for field in ('pin_filled_spans','pin_opening_rows'):physics.pop(field,None)
        native=next(p for p in compile_recipe(recipe)['pieces'] if p['type']=='cloth')
        from .drape import tailor
        piece=tailor(draft(spec,config,native,'cape','cape_near'),physics)
        from .contract import pattern_mesh
        vertices,faces=pattern_mesh(piece['pattern'],piece['rag'])
        self.assertTrue(np.isfinite(vertices).all())
        self.assertEqual(len(faces),11*physics['row_subdivisions'])
        self.assertLess(len(piece['pattern']['pins']),len(vertices))
        near,far,lateral,forward=frame(spec,config)
        self.assertAlmostEqual(np.dot(lateral,forward),0)
        self.assertGreater(np.ptp(np.array(vertices)@lateral),np.linalg.norm(near-far))

    def test_mask_contour_keeps_its_concavity(self):
        from .masked_hood import contains
        polygon=[[0,0],[4,0],[4,4],[2,2],[0,4]]
        self.assertTrue(contains([2,1],polygon))
        self.assertFalse(contains([2,3],polygon))
        self.assertFalse(contains([5,1],polygon))

    def test_sewn_yoke_preserves_the_entire_measured_banner_and_seam_length(self):
        from .cloth_attachment import sew_yoke
        recipe=json.loads((ROOT/'gale_herald/measurements.json').read_text())
        spec=compile_recipe(recipe)
        banner=deepcopy(next(p for p in spec['pieces'] if p['id']=='banner_far_front'))
        before=deepcopy(banner['pattern']['rows'])
        result=sew_yoke(banner,spec,'shoulder_far')
        self.assertEqual(result['pattern']['rows'][1:],before)
        self.assertEqual(banner['pattern']['rows'],before)
        root=result['pattern']['rows'][0]['points']
        self.assertAlmostEqual(np.linalg.norm(np.subtract(root[-1],root[0])),result['yoke_seam_length'])
        self.assertAlmostEqual(root[0][2],spec['joints']['shoulder_far'][2])

    def test_coverage_excludes_colour_spill_outside_solos_and_requires_real_part_colour(self):
        from types import SimpleNamespace
        from .pixel_coverage import part_coverage
        raster=SimpleNamespace(names=['head','torso'],owners=np.array([[0,0],[1,-1]]),
            masks={'head':np.array([[True,False],[False,False]]),
                   'torso':np.array([[False,False],[True,False]])})
        pixels=np.array([[[255,0,0,255],[255,0,0,255]],[[128,128,0,255],[0,0,0,0]]])
        result=part_coverage({'labels':{'head':[1,0,0],'torso':[0,1,0]}},raster,pixels)
        self.assertEqual(result['head']['depth_tested_owner_pixels'],2)
        self.assertEqual(result['head']['visible_pixels'],1)
        self.assertEqual(result['head']['visible_fraction_of_solo'],1)
        self.assertEqual(result['head']['pure_owner_pixels'],1)
        self.assertEqual(result['torso']['pure_owner_pixels'],0)

    def test_all_four_canonical_specs_match_source_recipes(self):
        for name in ('hoarfrost_seer','gale_herald','arc_thrall','gloam_stalker'):
            compiled=compile_recipe(json.loads((ROOT/name/'measurements.json').read_text()))
            generated=ROOT/name/'spec_native.json'
            if generated.exists():
                self.assertEqual(compiled,json.loads(generated.read_text()))
            else:
                from .contract import digest
                provenance=json.loads((ROOT/name/'delivery/provenance.json').read_text())
                self.assertEqual(digest(compiled),provenance['spec_hash'])


if __name__=='__main__':
    unittest.main()
