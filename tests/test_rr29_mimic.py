"""rr29 implementation fidelity and negative controls; no renderer claims."""
import copy
import json
import math
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'experiments/cutouts/hollow_mimic')]
from rr29_build import CASE,BASE,ASSETS,DIRECTOR,read_json
from rr29_measure import wave,arm_report,draw_report,camera_sides,depths
from humanoid_cutout.gait import validate,expand
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.gait_continuations import errors as continuation_errors
from humanoid_cutout.gates import structure_errors,source_errors
from art_identity_gate import pixel_digest,process_raw

TEST_DEFAULTS={'timeout_s':180,'mutation_angle_deg':5,'mutation_frame':20}


def godot(script,*args):
    return subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-29','--stream','--',
        'godot','--headless','--path','.','--script',script,'--',*map(str,args)],cwd=ROOT,
        capture_output=True,text=True,timeout=TEST_DEFAULTS['timeout_s'])


class MimicRevisionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=read_json(CASE/'compiled_motion.json')
        cls.layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
        with tempfile.TemporaryDirectory(prefix='rr29-samples-') as temporary:
            path=Path(temporary)/'samples.json'
            result=godot('tests/rr29/samples.gd','--case',CASE,'--output',path)
            if result.returncode:raise AssertionError(result.stdout+result.stderr)
            cls.samples=read_json(path)
        cls.before=read_json(CASE/'proof/before_samples.json')

    def test_protected_director_and_other_clips_are_exact(self):
        for p in (CASE,ASSETS):self.assertEqual((p/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR,'hollow_mimic',self.layouts,self.data['projection']),self.data)
        old=read_json(BASE/'compiled_motion.json')
        for view in self.layouts:
            for clip in self.data['clips']:
                if clip!='move':self.assertEqual(self.data['view_tracks'][view][clip],old['view_tracks'][view][clip])

    def test_exact_new_rest_rigid_head_and_recomputed_continuations(self):
        build=read_json(CASE/'proof/build.json')
        for view,layout in self.layouts.items():
            self.assertEqual(structure_errors(layout,build),[])
            self.assertEqual(source_errors(CASE,layout,build),[])
            self.assertEqual(continuation_errors(CASE,layout),[])
            self.assertNotIn('head',[m['name'] for m in layout['joint_meshes']])
            self.assertEqual(pixel_digest(Image.open(CASE/layout['rest_source'])),
                pixel_digest(Image.open(ROOT/read_json(CASE/'inputs.json')[view+'_job']/'processed.png')))

    def test_analytical_pendulum_no_hand_slide_and_exact_fk(self):
        gait=self.data['clips']['move']['gait']
        for layout in self.layouts.values():
            generated=expand(gait,layout,'move')
            self.assertFalse(any(key.startswith('hand_') for key in generated))
        report=arm_report(self.samples,self.before)
        # Travel shortfalls are design-owner findings, not waived acceptance.
        self.assertFalse(any('FK differs' in e for e in report['errors']),report['errors'])
        for view in report['views'].values():
            for arm in view.values():self.assertTrue(all(v>0 for v in arm['step_arc_departure_px']))

    def test_pendulum_gate_rejects_straight_slide_and_changed_forearm(self):
        mutant=copy.deepcopy(self.samples)
        for r in mutant['samples']:
            if r['clip']=='move':
                r['bones']['hand_near']['global'][4:]=r['bones']['upper_near']['global'][4:]
        report=arm_report(mutant,self.before)
        self.assertTrue(any('arc' in e or 'travel' in e for e in report['errors']))
        mutant=copy.deepcopy(self.samples)
        row=next(r for r in mutant['samples'] if r['kind']=='authored' and r['clip']=='move')
        row['bones']['fore_far']['global'][0]+=TEST_DEFAULTS['mutation_angle_deg']
        self.assertTrue(any('FK differs' in e for e in arm_report(mutant,self.before)['errors']))

    def test_phase_and_bad_director_models_are_rejected(self):
        gait=copy.deepcopy(self.data['clips']['move']['gait'])
        validate(gait,'move')
        for at in (0,1):self.assertEqual(wave(gait,'near',at),0)
        for field,value in [('model','unknown'),('phase','same_side_leg')]:
            changed=copy.deepcopy(gait);changed['arm_swing'][field]=value
            with self.assertRaises(ValueError):validate(changed,'move')
        changed=copy.deepcopy(gait);changed['arm_swing']['near']['forearm_lag_s']=-1
        with self.assertRaises(ValueError):validate(changed,'move')

    def test_per_frame_draw_order_and_restoration_both_views(self):
        report=draw_report(self.samples)
        self.assertTrue(report['ok'],report['errors'])
        self.assertEqual([(r['clip'],r['side']) for r in report['findings']], [('block','near')]*33)
        self.assertEqual([r['frame'] for r in report['findings']],list(range(9,42)))
        mutant=copy.deepcopy(self.samples)
        row=next(r for r in mutant['samples'] if r['view']=='front' and r['clip']=='block' and r['frame']==TEST_DEFAULTS['mutation_frame'])
        row['parts']['hand_near']['z_index']=0
        self.assertTrue(draw_report(mutant)['errors'])

    def test_far_crossing_and_camera_view_are_geometric(self):
        layout=self.layouts['front']
        pose=copy.deepcopy(next(r for r in self.samples['samples'] if r['view']=='front' and r['clip']=='block' and r['frame']==TEST_DEFAULTS['mutation_frame']))
        # Place the far hand on the midline; preserves all body and source data.
        pose['bones']['hand_far']['global'][4]=pose['bones']['torso']['global'][4]
        self.assertIn('far',camera_sides(layout,pose))
        self.assertGreater(depths(layout,pose)['sleeve_far'],depths(layout,pose)['torso'])
        pose['view']='rear';self.assertEqual(camera_sides(layout,pose),[])

    def test_processing_replays_and_moved_prompt_bytes(self):
        for view in self.layouts:
            job=ROOT/f'spec/art_identity/jobs/hollow_mimic/mq11_{view}'
            kit=read_json(job/'kit.json')
            with tempfile.TemporaryDirectory(prefix='rr29-paint-replay-') as temporary:
                out=Path(temporary)/'processed.png'
                process_raw(job/'refs/raw_approved.png',job/'kit.json',out)
                self.assertEqual(pixel_digest(Image.open(out)),read_json(job/'processed.json')['pixel_sha256'])
            original=subprocess.check_output(['git','show','HEAD:'+kit['prompt_source']],cwd=ROOT)
            self.assertEqual((job/'prompt.md').read_bytes(),original)

    def test_native_capture_load_only(self):
        with tempfile.TemporaryDirectory(prefix='rr29-native-load-') as temporary:
            result=godot('tests/rr29/native_probe.gd','--case',CASE,'--output',temporary,'--validate-only')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RR29 NATIVE PROBE LOAD: PASS',result.stdout)


if __name__=='__main__':unittest.main()
