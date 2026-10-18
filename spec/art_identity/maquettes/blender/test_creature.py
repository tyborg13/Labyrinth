"""Portable acceptance contracts for the optional native solid builder path."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import shutil
from unittest.mock import Mock, patch
from types import SimpleNamespace

import numpy as np
from PIL import Image

from .compile_recipe import compile_recipe
from .contract import digest, validate
from .creature_recipe import shell_path
from .facing import axis_report, board_spec
from .solid_review import silhouette_fit, inspect_figure
from ..raster import Raster, project

ROOT = Path(__file__).resolve().parents[1]
FIGURES = ('burrow_grub','ember_tick','glacial_mirror')
TEST_DEFAULTS = {'mask_size': 64, 'test_alpha_rectangle': (10,5,54,60)}


def recipe(name):
    return json.loads((ROOT/name/'measurements.json').read_text())


class CreatureContractTests(unittest.TestCase):
    def test_exact_parts_and_native_anatomy(self):
        expected = {
            'burrow_grub': {'head','tail'} | {f'seg_{i}' for i in range(1,7)} | {f'leg_{s}_{i}' for s in ('near','far') for i in range(1,4)},
            'ember_tick': {'head','shell'} | {f'leg_{s}_{i}_{p}' for s in ('near','far') for i in range(1,5) for p in ('upper','lower')},
            'glacial_mirror': {'head','torso','pelvis'} | {f'{p}_{s}' for s in ('near','far') for p in ('upper','fore','hand','thigh','shin','foot')}}
        for name in FIGURES:
            with self.subTest(figure=name):
                spec=compile_recipe(recipe(name));validate(spec)
                self.assertEqual(set(spec['labels']),expected[name])
                self.assertEqual({p['part'] for p in spec['pieces']},expected[name])
                self.assertTrue(all(p.get('rig_bone') for p in spec['pieces']))
                self.assertFalse(any(p.get('capture_view') for p in spec['pieces']))
                self.assertEqual(spec['base']['asset'],'realistic_body_male' if name=='glacial_mirror' else 'procedural_chain')
                self.assertTrue(axis_report(board_spec(spec),[1,0,0])['passed'])
                self.assertFalse(axis_report(board_spec(spec),[1,1,0])['passed'])
                if spec['base']['asset']=='procedural_chain':
                    by_name={b['name']:b for b in spec['armature']['bones']}
                    a,b=(np.array(spec['joints'][by_name[n]['head']]) for n in spec['forward_bones'])
                    measured=b-a;measured[2]=0
                    self.assertTrue(axis_report(spec,measured.tolist())['passed'])
                    self.assertFalse(axis_report(spec,(-measured).tolist())['passed'])

    def test_protected_sources_have_exact_hashes(self):
        for name in FIGURES:
            data=recipe(name)
            for view,path in data['sources'].items():
                self.assertEqual(hashlib.sha256((ROOT.parents[2]/path).read_bytes()).hexdigest(),data['source_sha256'][view])

    def test_batch_a_compiles_to_unchanged_delivery_hashes(self):
        for name in ('hoarfrost_seer','gale_herald','arc_thrall','gloam_stalker'):
            with self.subTest(figure=name):
                spec=compile_recipe(recipe(name))
                old=json.loads((ROOT/name/'delivery/build_report.json').read_text())
                self.assertEqual(digest(spec),old['spec_hash'])

    def test_round_trip_cracks_lie_on_shell_and_retain_the_source_stroke(self):
        spec=compile_recipe(recipe('ember_tick'))
        shell=next(p for p in spec['pieces'] if p['id']=='shell')
        item=next(p for p in recipe('ember_tick')['native_solids']['surfaces'] if p['id']=='shell')
        strokes=[('front',p) for p in item['crack_paths_px']]+[('rear',p) for p in item.get('rear_crack_paths_px',[])]
        self.assertEqual(len(shell['grooves']['paths']),len(strokes))
        for path,(view,stroke) in zip(shell['grooves']['paths'],strokes):
            p=np.array(path)
            np.testing.assert_allclose((((p-shell['centre'])/shell['radii'])**2).sum(1),1,atol=1e-10)
            np.testing.assert_allclose(project(spec,p[[0,-1]],view,size=256)[:,:2],[stroke[0],stroke[-1]],atol=1e-10)
        with self.assertRaisesRegex(ValueError,'outside shell'):
            shell_path(spec,shell,[[0,0],[1,1]])

    def test_geometry_features_keep_whole_ownership(self):
        grub=compile_recipe(recipe('burrow_grub'))
        teeth=[p for p in grub['pieces'] if p['id'].startswith('tooth_')]
        self.assertTrue(teeth)
        self.assertTrue(all(p['part']=='head' and p['rig_bone']=='head' for p in teeth))
        golem=compile_recipe(recipe('glacial_mirror'))
        slab=next(p for p in golem['pieces'] if p['id']=='ice_mirror_slab')
        self.assertEqual((slab['part'],slab['rig_bone']),('torso','torso'))
        stones=[p for p in golem['pieces'] if p['type']=='sculpted_mass']
        self.assertGreaterEqual(len(stones),15)
        self.assertEqual({p['part'] for p in stones},set(golem['labels']))
        self.assertTrue(all(p['surface']=='boulder' and p['chips'] and p['relief']['strength']>0 and p['bevel']['segments']>=2 for p in stones))

    def test_mass_contract_rejects_missing_relief_bevel_and_binding(self):
        original=compile_recipe(recipe('glacial_mirror'))
        for change in (lambda p:p.update(radii=[1,0,1]),lambda p:p['relief'].update(strength=0),
                       lambda p:p.update(chips=[]),lambda p:p['bevel'].update(segments=1),
                       lambda p:p.update(rig_bone='missing')):
            with self.subTest(change=change):
                spec=deepcopy(original);change(spec['pieces'][0])
                with self.assertRaises(ValueError):validate(spec)

    def test_whole_silhouette_fit_handles_crawler_and_catches_wrong_shape(self):
        size=TEST_DEFAULTS['mask_size']
        source=Image.new('RGBA',(size,size))
        source.paste((255,255,255,255),TEST_DEFAULTS['test_alpha_rectangle'])
        mask=np.asarray(source)[:,:,3]>0
        raster=Raster(['body'],np.where(mask,0,-1),{'body':mask},{})
        self.assertEqual(silhouette_fit(source,raster,.7)['iou'],1)
        bad=mask.copy();bad[:,size//2:]=False
        failed=Raster(['body'],np.where(bad,0,-1),{'body':bad},{})
        self.assertFalse(silhouette_fit(source,failed,.7)['passed'])

    def test_review_refuses_missing_native_proof_before_creating_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)
            (folder/'measurements.json').write_text(json.dumps(recipe('ember_tick')))
            with self.assertRaises((ValueError,FileNotFoundError)):
                inspect_figure(folder)
            self.assertFalse((folder/'delivery/fit_report.json').exists())

    def test_busy_bridge_lease_is_bounded_and_never_submits(self):
        from . import bridge_client as bridge
        with tempfile.TemporaryDirectory() as temporary, \
             patch.object(bridge,'fcntl',SimpleNamespace(flock=Mock(side_effect=BlockingIOError),LOCK_EX=2,LOCK_NB=4)), \
             patch.object(bridge.time,'monotonic',side_effect=[0,bridge.BRIDGE_DEFAULTS['lease_timeout_s']]), \
             patch.object(bridge,'submit') as submit:
            with self.assertRaisesRegex(TimeoutError,'serial lease unavailable'):
                bridge.run_job(__file__,[],root=temporary)
            submit.assert_not_called()

    def test_detached_or_wrong_bone_source_is_rejected_independently_of_materials(self):
        from .creature_rig import bindings_match
        rig=object()
        source=SimpleNamespace(parent=rig,parent_type='BONE',parent_bone='leg')
        pieces=[{'id':'leg_mesh','rig_bone':'leg'}]
        self.assertTrue(bindings_match(pieces,{'leg_mesh':source},rig))
        source.parent_bone='shell'
        self.assertFalse(bindings_match(pieces,{'leg_mesh':source},rig))
        self.assertFalse(bindings_match(pieces,{},rig))

    def test_feature_cannot_be_split_across_part_owners_or_view_faked(self):
        original=compile_recipe(recipe('glacial_mirror'))
        for update in ({'objects':['head']},{'visibility':{'side':'visible'}},
                       {'visibility':{'rear':'anything'}}):
            spec=deepcopy(original)
            spec['native_features']['ice_mirror_slab'].update(update)
            with self.assertRaises(ValueError):validate(spec)

    def test_failed_native_workflow_does_not_attempt_proof_or_staging(self):
        from . import solid_workflow
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)
            (folder/'measurements.json').write_text(json.dumps(recipe('ember_tick')))
            with patch.object(solid_workflow,'native_job',side_effect=TimeoutError('fixture bridge unavailable')) as native, \
                 patch.object(solid_workflow,'stage') as staging:
                with self.assertRaises(TimeoutError):solid_workflow.build_and_prove(folder)
                self.assertEqual(native.call_count,1)
                staging.assert_not_called()

    def test_native_modifier_stack_rejects_flattened_stone_and_removed_cracks(self):
        from .sculpted_mass import native_stack_matches
        stone=compile_recipe(recipe('glacial_mirror'))['pieces'][0]
        subdiv=SimpleNamespace(name='rounded_mass_subdivision',type='SUBSURF',levels=stone['subdivision_levels'],render_levels=stone['subdivision_levels'])
        relief=SimpleNamespace(name='modelled_surface_relief',type='DISPLACE',strength=stone['relief']['strength'])
        bevel=SimpleNamespace(name='modelled_chipped_bevel',type='BEVEL',width=stone['bevel']['width'],segments=stone['bevel']['segments'])
        fracture=SimpleNamespace(name='modelled_fracture_0',type='BOOLEAN',operation='DIFFERENCE',solver='EXACT',object=object())
        source=SimpleNamespace(modifiers=[subdiv,relief,bevel,fracture],get=lambda key: key=='modelled_profile')
        for mod in source.modifiers:mod.show_render=mod.show_viewport=True
        self.assertTrue(native_stack_matches(stone,source))
        source.modifiers=[subdiv,relief]
        self.assertFalse(native_stack_matches(stone,source))
        self.assertFalse(native_stack_matches(stone,None))
        shell=next(p for p in compile_recipe(recipe('ember_tick'))['pieces'] if p['id']=='shell')
        source=SimpleNamespace(modifiers=[SimpleNamespace(name='rounded_mass_subdivision',type='SUBSURF',render_levels=1),
            SimpleNamespace(name='modelled_surface_relief',type='DISPLACE',strength=shell['relief']['strength'])],get=lambda key:True)
        self.assertFalse(native_stack_matches(shell,source))

    def test_ordered_mass_topology_is_closed_and_chips_keep_manifold_caps(self):
        from .mass_topology import uv_sphere,ico_sphere,clip_convex
        from .sewn_garment import topology_report
        shapes=[uv_sphere(16,8),ico_sphere(2)]
        shapes.extend(clip_convex(*ico_sphere(2),[1,0,0],d) for d in (0,.5,.91))
        for vertices,faces in shapes:
            self.assertEqual(topology_report(vertices,faces),{'connected':True,'nonmanifold_edges':0,'boundary_loops':0})
        vertices,faces=ico_sphere(2)
        for normal,distance in [([1,.6,.7],.8),([-.5,1,.2],.7),([.1,-.3,1],.9)]:
            vertices,faces=clip_convex(vertices,faces,normal,distance)
        self.assertEqual(topology_report(vertices,faces)['boundary_loops'],0)
        self.assertEqual(uv_sphere(16,8),uv_sphere(16,8))

    def test_relief_weights_are_bounded_repeatable_and_spatially_varying(self):
        from .surface_relief import relief_weight
        points=[[.1,.2,.3],[-.2,.7,.04],[0,0,0]]
        first=[relief_weight(p,.1,2) for p in points]
        self.assertEqual(first,[relief_weight(p,.1,2) for p in points])
        self.assertTrue(all(0<=w<=1 for w in first))
        self.assertGreater(max(first)-min(first),.1)

    def test_solid_delivery_requires_its_modelling_and_feature_checks(self):
        from .delivery_validation import geometry_checks
        checks=geometry_checks(compile_recipe(recipe('glacial_mirror')))
        for name in ('native_rigid_bindings','native_sculpted_surfaces','whole_native_features'):
            self.assertIn(name,checks)

    def test_mask_packing_preserves_all_alpha_visible_pixels_and_clay_bytes(self):
        from .compact_capture import compact_capture
        from .capture_manifest import write_manifest
        from PIL.PngImagePlugin import PngInfo
        spec={'native_solid_revision':2,'pieces':[]}
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)/'capture';folder.mkdir()
            (folder/'joints_px.json').write_text('{}\n')
            sample=Image.new('RGBA',(16,16),(151,42,99,0))
            sample.putpixel((3,3),(20,70,120,255));sample.putpixel((4,4),(80,30,140,128))
            info=PngInfo();info.add_text('Date','native-stamp-fixture')
            names=['front_clay.png','rear_clay.png','front_parts.png','rear_parts.png']
            for name in names:sample.save(folder/name,pnginfo=info)
            before={name:(folder/name).read_bytes() for name in names}
            write_manifest(folder,digest(spec),'full',names)
            report=compact_capture(spec,folder)
            for name in ('front_clay.png','rear_clay.png'):self.assertEqual((folder/name).read_bytes(),before[name])
            packed=np.array(Image.open(folder/'front_parts.png').convert('RGBA'));original=np.array(sample)
            np.testing.assert_array_equal(packed[:,:,3],original[:,:,3])
            np.testing.assert_array_equal(packed[original[:,:,3]>0],original[original[:,:,3]>0])
            self.assertFalse(packed[:,:,:3][original[:,:,3]==0].any())
            self.assertEqual((folder.with_name('capture_raw_png')/'front_parts.png').read_bytes(),before['front_parts.png'])
            self.assertEqual(compact_capture(spec,folder),report)

    def test_lossless_contact_encoding_preserves_every_composed_rgba_pixel(self):
        from .solid_review import save_review_sheet
        with tempfile.TemporaryDirectory() as temporary:
            sheet=Image.new('RGBA',(16,16),(24,24,24,255));sheet.putpixel((5,5),(0,120,180,255))
            path=Path(temporary)/'sheet.webp';report=save_review_sheet(sheet,path)
            self.assertTrue(report['rgba_identical'])
            np.testing.assert_array_equal(np.array(Image.open(path).convert('RGBA')),np.array(sheet))

    def test_packed_native_delivery_rejects_false_flags_and_mismatched_raw_hashes(self):
        from .delivery_validation import validate_delivery
        original=ROOT/'burrow_grub/delivery'
        if not (original/'capture_packing.json').exists():self.skipTest('Build the native solid delivery first')
        spec=compile_recipe(recipe('burrow_grub'))
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary)
            for path in original.iterdir():
                if not path.is_file():continue
                if path.suffix=='.png':(folder/path.name).symlink_to(path)
                else:shutil.copyfile(path,folder/path.name)
            validate_delivery(spec,folder)
            path=folder/'capture_packing.json';before=path.read_bytes();data=json.loads(before)
            data['native_clay_bytes_unchanged']=False;path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError,'packing changed'):validate_delivery(spec,folder,require_binding=False)
            path.write_bytes(before);data=json.loads(before);data['images']['front_parts.png']['packed_sha256']='0'*64
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError,'hash differs'):validate_delivery(spec,folder,require_binding=False)


if __name__=='__main__':unittest.main()
