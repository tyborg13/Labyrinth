"""Mirror source, runtime, preservation and adversarial gate checks; no GUI."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/glacial_mirror')]
from rr18_case import CASE, DIRECTOR, PIECES, ASSETS
from rr18_checks import knee_report, support_report, production_rest_report
from cutout_pipeline.cases import read_json, digest, CutoutError
from humanoid_cutout.gates import source_errors, structure_errors, bone_errors, bindings, native_errors
from humanoid_cutout.compiler import compile_motion
from maquette_motion.silhouette import components
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from maquette_motion.features import source_pixels
from rr18_seams import frame_state, frame_report
from rr18_source_stage import raw_identity, visible_errors
from maquette_motion.pixels import render
from rr23_preservation import UNIT_HEAD, protected_changes

PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID','rr-23')
PROOF_TIMEOUT_SECONDS = 180
FIXTURE_SLIDE_PX = 1
FIXTURE_RGB_XOR_MASK = 1
FIXTURE_ROTATION_RAD = 0.1
FIXTURE_FRAME = 5
REPAIRED_REAR_FRAMES = {'move': (1,), 'refraction': (13,14,15,16,17,58,59), 'guard': (7,8,16,47,48)}
REPAIRED_REAR_COVERAGE = (('move', 1, 298, 305), ('refraction', 13, 298, 305), ('refraction', 14, 298, 305), ('refraction', 15, 298, 305), ('refraction', 16, 298, 305), ('refraction', 17, 298, 305), ('refraction', 58, 298, 305), ('refraction', 59, 298, 305), ('guard', 7, 298, 305), ('guard', 8, 298, 305), ('guard', 16, 300, 181), ('guard', 16, 338, 187), ('guard', 47, 298, 305), ('guard', 48, 298, 305))
AIR_PROOF_FRAMES = (('front','guard',20),('rear','refraction',32),('rear','idle',0))


def godot(script,*args):
    result = subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',PROOF_TASK_ID,'--stream','--',
        'godot','--headless','--path','.','--script',script,'--',*map(str,args)],cwd=PROJECT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
    if result.returncode: raise AssertionError(result.stdout+result.stderr)
    return result.stdout+result.stderr


class MirrorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layouts = {v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
        cls.data = read_json(CASE/'compiled_motion.json')
        cls.build = read_json(CASE/'proof/build.json')
        with tempfile.TemporaryDirectory(prefix='rr18-evidence-') as folder:
            path=Path(folder)/'samples.json'
            godot('tests/rr18/action_direction.gd','--case',CASE,'--output',path)
            cls.samples=read_json(path)
        cls.bound=bindings(CASE)

    def test_director_import_and_effective_compiler(self):
        self.assertEqual((CASE/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        self.assertEqual((ASSETS/'humanoid_v2/director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR,'glacial_mirror',self.layouts,self.data['projection']),self.data)
        self.assertEqual(self.data['TODO_DESIGN'],{})

    def test_both_source_cuts_are_lossless_rigid_and_covered(self):
        for view,layout in self.layouts.items():
            with self.subTest(view=view):
                self.assertEqual(structure_errors(layout,self.build),[])
                self.assertEqual(source_errors(CASE,layout,self.build),[])
                self.assertEqual(layout['joint_meshes'],[])
                self.assertEqual(layout['source_labels'],PIECES)
                self.assertEqual(len([p for p in layout['parts'] if not p.get('hidden_material')]),15)
                self.assertEqual(self.build['views'][view]['rest_mismatch_pixels'],0)
                self.assertEqual(layout['idle_groups']['weapon_arm'],[])
                for part in layout['parts']:
                    if not part.get('hidden_material'):
                        pixels=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))
                        self.assertEqual(len(components(pixels[...,3]>0)[1]),1,part['name'])
                self.assertIn('fist_near',layout['idle_groups']['upper_body'])
                self.assertIn('fist_far',layout['idle_groups']['upper_body'])
                self.assertEqual([f['name'] for f in layout['features']],['ice_mirror'] if view=='front' else [])
                for name,expected in self.build['views'][view]['delivery'].items():
                    self.assertEqual(digest(PROJECT/'spec/art_identity/maquettes/glacial_mirror/delivery'/name),expected)

    def test_real_bone_idle_signed_motion_and_direction(self):
        for view,layout in self.layouts.items():
            self.assertEqual(bone_errors(layout,self.data,self.samples,self.bound),[])
            report=direction_report(layout,self.data,self.samples,self.bound,require_presented=True)
            self.assertEqual(report['errors'],[])
            for clip in ('refraction','guard'): self.assertGreater(report['clip_positive_checks'][clip],0)

    def test_dense_reach_including_interval_minimum(self):
        for layout in self.layouts.values():
            report=reach_report(layout,self.data,step_distance_px=self.samples['step_distance_px'],screen_pixel_scale=self.samples['screen_pixel_scale'])
            self.assertEqual(report['errors'],[])
            self.assertEqual(report['dense_intervals'],1000)
            self.assertTrue(report['overreach'])

    def test_both_leg_gait_and_density_rests_pass(self):
        for view,layout in self.layouts.items():
            self.assertEqual(read_json(CASE/'anatomy.json')['knee_policy']['near_straight_deg'],10)
            self.assertEqual(knee_report(layout,self.data,self.samples)['errors'],[])
            self.assertEqual(support_report(layout,self.data,self.samples)['errors'],[])
            report=production_rest_report(layout,CASE,ASSETS)
            self.assertEqual(report['errors'],[])
            self.assertEqual(report['snapshot_mismatch_pixels'],0)
            self.assertEqual(len(knee_report(layout,self.data,self.samples)['swings']),6)
            self.assertNotIn('leg_roles',layout)
            for side in ('near','far'):
                track=next(t for t in self.data['view_tracks'][view]['move'] if t['bone']=='foot_'+side and t['channel']=='forward_px')
                self.assertEqual(track['forward_mode'],'world_step')

    def test_boulder_layers_share_registered_anchor_in_real_runtime(self):
        for view,layout in self.layouts.items():
            for part in layout['parts']:
                main=next(p for p in layout['parts'] if not p.get('hidden_material') and p['logical_part']==part['logical_part'])
                self.assertEqual(part['presentation_anchor'],main['presentation_anchor'])
                self.assertEqual(part['bbox'],main['bbox'])
            for row in self.samples['samples']:
                if row['view']!=view or row['kind']!='presented':continue
                for part in layout['parts']:
                    t=sprite_transform(layout,row,part)
                    packed=[t[0,0],t[1,0],t[0,1],t[1,1],t[0,2],t[1,2]]
                    np.testing.assert_allclose(row['parts'][part['name']]['transform'],packed,atol=.0001,rtol=0)

    def test_independent_crop_snap_mutation_reopens_internal_seams(self):
        layout=copy.deepcopy(self.layouts['front'])
        row=next(r for r in self.samples['samples'] if r['view']=='front' and r['clip']=='move' and r['kind']=='presented' and r['frame']==22)
        self.assertEqual(frame_state(CpuPose(CASE,layout),row)[1],[])
        for part in layout['parts']:
            part.pop('presentation_anchor',None)
            image=Image.open(CASE/part['file']).convert('RGBA');box=image.getbbox()
            # Store each old independent crop only in the temporary fixture.
            part['offset']=[part['offset'][0]+box[0],part['offset'][1]+box[1]]
            part['bbox']=[*part['offset'],part['offset'][0]+box[2]-box[0],part['offset'][1]+box[3]-box[1]]
            part['fixture_crop']=box
        model=CpuPose(CASE,layout)
        for part in layout['parts']:
            model.images[part['file']]=np.asarray(Image.open(CASE/part['file']).convert('RGBA').crop(part['fixture_crop']))
            model.images[layout['proof_layers'][part['name']]['mask']]=np.asarray(Image.open(CASE/layout['proof_layers'][part['name']]['mask']).convert('RGBA').crop(part['fixture_crop']))
        self.assertTrue(frame_state(model,row)[1])

    def test_approved_air_pockets_in_both_views_pass_the_case_policy(self):
        for view,clip,frame in AIR_PROOF_FRAMES:
            with self.subTest(view=view,clip=clip,frame=frame):
                model=CpuPose(CASE,copy.deepcopy(self.layouts[view]))
                row=next(r for r in self.samples['samples'] if r['view']==view and r['clip']==clip and r['frame']==frame and r['kind']=='presented')
                _,report=frame_report(model,row)
                self.assertEqual(report['failures'],[])
                self.assertTrue(report['air_pockets'])

    def test_repaired_rear_continuations_close_every_native_confirmed_pocket(self):
        model=CpuPose(CASE,copy.deepcopy(self.layouts['rear']))
        for clip,frames in REPAIRED_REAR_FRAMES.items():
            for frame in frames:
                row=next(r for r in self.samples['samples'] if r['view']=='rear' and r['clip']==clip and r['frame']==frame and r['kind']=='presented')
                self.assertEqual(frame_state(model,row)[1],[],(clip,frame))
                layers,_=model.layers(row)
                occupied=np.zeros((512,512),dtype=bool)
                for part in model.layout['parts']:
                    samples=render(Image.open(CASE/part['file']).convert('RGBA'),sprite_transform(model.layout,row,part),with_ties=True)
                    occupied|=np.logical_and.reduce([image[...,3]>0 for image in samples.candidates])
                for expected_clip,expected_frame,x,y in REPAIRED_REAR_COVERAGE:
                    if (clip,frame)==(expected_clip,expected_frame):self.assertTrue(occupied[y,x],(clip,frame,x,y))

    def test_raw_authoring_and_clean_presentation_identity_are_independently_exact(self):
        for view,layout in self.layouts.items():
            self.assertEqual(raw_identity(view)['errors'],[])
            visible={p['logical_part']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
            depths={p['logical_part']:p['z_index'] for p in layout['parts'] if not p.get('hidden_material')}
            self.assertEqual(visible_errors(visible,depths,view,12),[])

    def test_runtime_adapters_and_contact_reduced_motion(self):
        self.assertIn('RR18 RUNTIME: PASS',godot('tests/rr18/runtime_test.gd'))

    def test_native_probe_loads_every_rigid_surface_and_mask(self):
        with tempfile.TemporaryDirectory(prefix='rr18-probe-load-') as folder:
            self.assertIn('RR18 NATIVE PROBE LOAD: PASS',godot('tests/rr18/native_capture.gd','--case',CASE,'--output',folder,'--validate-only'))

    def test_unverified_native_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='rr18-native-missing-') as folder:
            with self.assertRaises(CutoutError): native_errors(CASE,Path(folder))

    def test_mutation_idle_rotation_is_caught(self):
        samples=copy.deepcopy(self.samples)
        row=next(r for r in samples['samples'] if r['view']=='front' and r['clip']=='idle')
        row['bones']['torso']['global'][1]=FIXTURE_ROTATION_RAD
        self.assertTrue(any('idle rotation/scale: torso' in e for e in bone_errors(self.layouts['front'],self.data,samples,self.bound)))

    def test_mutation_zero_forward_loses_required_coverage(self):
        data=copy.deepcopy(self.data)
        for view in data['view_tracks']:
            for clip in ('refraction','guard'):
                for t in data['view_tracks'][view][clip]:
                    if t['channel']=='forward_px':
                        for k in t['keys']:k['value']=0
            errors=direction_report(self.layouts[view],data,self.samples,self.bound,require_presented=True)['errors']
            for clip in ('refraction','guard'):
                self.assertTrue(any(f'{view}/{clip}: no positive direction checks' in e for e in errors))

    def test_mutation_second_swing_no_knee_is_caught(self):
        samples=copy.deepcopy(self.samples)
        for row in samples['samples']:
            if row['view']=='front' and row['clip']=='move' and row['kind']=='presented' and .32<row['phase']<.48:
                a,c=[np.array(row['bones'][p+'_near']['global'][4:]) for p in ('thigh','foot')]
                row['bones']['shin_near']['global'][4:]=((a+c)/2).tolist()
        errors=knee_report(self.layouts['front'],self.data,samples)['errors']
        self.assertIn('front/near: peak knee below 15 degrees',errors)

    def test_mutation_action_support_slide_is_caught(self):
        samples=copy.deepcopy(self.samples)
        row=next(r for r in samples['samples'] if r['view']=='rear' and r['clip']=='guard' and r['kind']=='presented' and r['frame']==FIXTURE_FRAME)
        row['bones']['foot_far']['global'][4]+=FIXTURE_SLIDE_PX
        errors=support_report(self.layouts['rear'],self.data,samples)['errors']
        self.assertTrue(any(f'rear/guard/far/frame {FIXTURE_FRAME}: stance moved' in e for e in errors))

    def test_mutation_visible_source_rgba_is_caught(self):
        with tempfile.TemporaryDirectory(prefix='rr18-source-mutation-') as folder:
            case=Path(folder)/'case';shutil.copytree(CASE,case,ignore=shutil.ignore_patterns('proof','__pycache__'))
            part=next(p for p in self.layouts['front']['parts'] if p['name']=='torso')
            path=case/part['file'];pixels=np.array(Image.open(path).convert('RGBA'))
            y,x=np.argwhere(pixels[...,3]>0)[0];pixels[y,x,0]^=FIXTURE_RGB_XOR_MASK;Image.fromarray(pixels).save(path)
            self.assertIn('rest: composed source mismatch',source_errors(case,self.layouts['front'],self.build))

    def test_mutation_production_treatment_cannot_hide_rest_mismatch(self):
        with tempfile.TemporaryDirectory(prefix='rr18-production-rest-') as folder:
            assets=Path(folder)/'assets';shutil.copytree(ASSETS,assets)
            for view,layout in self.layouts.items():
                self.assertEqual(production_rest_report(layout,CASE,assets)['mismatch_pixels'],0)
                path=assets/'humanoid_v2'/view/'torso.png'
                pixels=np.array(Image.open(path).convert('RGBA'))
                y,x=np.argwhere(pixels[...,3]>0)[0]
                pixels[y,x,0]^=FIXTURE_RGB_XOR_MASK;Image.fromarray(pixels).save(path)
                report=production_rest_report(layout,CASE,assets)
                self.assertFalse(report['ok'])
                self.assertEqual(report['mismatch_pixels'],1)

    def test_density_snapshot_mutation_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='rr18-density-snapshot-') as folder:
            assets=Path(folder)/'assets';shutil.copytree(ASSETS,assets)
            for view,layout in self.layouts.items():
                path=assets/'humanoid_v2'/view/'rest.png'
                pixels=np.array(Image.open(path).convert('RGBA'))
                y,x=np.argwhere(pixels[...,3]>0)[0]
                pixels[y,x,0]^=FIXTURE_RGB_XOR_MASK;Image.fromarray(pixels).save(path)
                report=production_rest_report(layout,CASE,assets)
                self.assertFalse(report['ok'])
                self.assertEqual(report['mismatch_pixels'],0)
                self.assertEqual(report['snapshot_mismatch_pixels'],1)

    def test_other_creatures_and_director_inputs_unchanged(self):
        self.assertEqual(protected_changes(PROJECT,end=UNIT_HEAD),[])

    def test_committed_protected_mutation_is_caught(self):
        # Commit only in a disposable fixture repository, never this worktree.
        with tempfile.TemporaryDirectory(prefix='rr23-preservation-',dir=CASE/'proof') as folder:
            project=Path(folder)
            def git(*args):
                return subprocess.check_output(['git',*args],cwd=project,text=True).strip()
            git('init','-q')
            git('config','user.name','Preservation fixture')
            git('config','user.email','fixture@example.invalid')
            protected=project/'spec/peer_benchmark/staged/rr-18/motion_tracks.json'
            protected.parent.mkdir(parents=True)
            protected.write_text('approved fixture\n')
            git('add','.')
            git('commit','-qm','baseline fixture')
            baseline=git('rev-parse','HEAD')
            self.assertEqual(protected_changes(project,baseline,{}),[])
            protected.write_text('committed protected mutation\n')
            git('add','.')
            git('commit','-qm','protected mutation fixture')
            self.assertEqual(git('diff','--name-only'),'')
            self.assertEqual(protected_changes(project,baseline,{}),[str(protected.relative_to(project))])
            import hashlib
            approved={str(protected.relative_to(project)):hashlib.sha256(protected.read_bytes()).hexdigest()}
            self.assertEqual(protected_changes(project,baseline,approved),[])
            protected.write_text('unapproved replacement at allowlisted path\n')
            self.assertEqual(protected_changes(project,baseline,approved),[str(protected.relative_to(project))])


if __name__=='__main__':unittest.main(verbosity=2)
