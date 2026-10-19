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

PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID','rr-18')
PROOF_TIMEOUT_SECONDS = 180
FIXTURE_SLIDE_PX = 1
FIXTURE_RGB_XOR_MASK = 1
FIXTURE_ROTATION_RAD = 0.1
FIXTURE_FRAME = 5


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
            if row['view']=='front' and row['clip']=='move' and row['kind']=='presented' and .5<row['phase']<.9:
                a,c=[np.array(row['bones'][p+'_far']['global'][4:]) for p in ('thigh','foot')]
                row['bones']['shin_far']['global'][4:]=((a+c)/2).tolist()
        errors=knee_report(self.layouts['front'],self.data,samples)['errors']
        self.assertIn('front/far: swing peak below 15 degrees',errors)

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
                for part in layout['parts']:
                    shutil.copyfile(CASE/part['file'],assets/'humanoid_v2'/view/Path(part['file']).name)
                self.assertEqual(production_rest_report(layout,CASE,assets)['mismatch_pixels'],0)
                path=assets/'humanoid_v2'/view/'torso.png'
                pixels=np.array(Image.open(path).convert('RGBA'))
                y,x=np.argwhere(pixels[...,3]>0)[0]
                pixels[y,x,0]^=FIXTURE_RGB_XOR_MASK;Image.fromarray(pixels).save(path)
                report=production_rest_report(layout,CASE,assets)
                self.assertFalse(report['ok'])
                self.assertEqual(report['mismatch_pixels'],1)

    def test_other_creatures_and_director_inputs_unchanged(self):
        prefixes=('assets/units/arc_thrall_cutout/','assets/units/hoarfrost_seer_cutout/',
            'experiments/cutouts/arc_thrall/','experiments/cutouts/hoarfrost_seer/',
            'scripts/maquette_cutout_runtime/humanoid_', 'tools/humanoid_cutout/',
            'spec/art_identity/maquettes/glacial_mirror/','spec/art_identity/jobs/glacial_mirror/',
            'spec/peer_benchmark/staged/rr-18/')
        changed=subprocess.check_output(['git','diff','--name-only'],cwd=PROJECT,text=True).splitlines()
        self.assertEqual([p for p in changed if p.startswith(prefixes)],[])


if __name__=='__main__':unittest.main(verbosity=2)
