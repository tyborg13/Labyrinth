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
from rr29_measure import wave,envelope_at,arm_report,draw_report,camera_sides,depths
from humanoid_cutout.gait import validate,expand
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.gait_continuations import errors as continuation_errors
from humanoid_cutout.gates import structure_errors,source_errors
from art_identity_gate import pixel_digest,process_raw

TEST_DEFAULTS={'timeout_s':180,'mutation_angle_deg':5,'mutation_frame':20,
    'residue_fixture_size_px':2,'residue_channel_mutation':1}


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
            from rr29_baseline import sample
            cls.before=sample(Path(temporary)/'before.json')

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
        self.assertTrue(report['ok'],report['errors'])
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
        for envelope in ({'ramp_fraction':0,'ease':'smoothstep'}, {'ramp_fraction':.12,'ease':'linear'},
                         {'ramp_fraction':float('nan'),'ease':'smoothstep'}):
            changed=copy.deepcopy(gait);changed['arm_swing']['envelope']=envelope
            with self.assertRaises(ValueError):validate(changed,'move')

    def test_envelope_ramps_amplitude_and_lag_and_endpoints_are_rest(self):
        gait=self.data['clips']['move']['gait'];ramp=gait['arm_swing']['envelope']['ramp_fraction']
        for phase,expected in ((0,0),(ramp/2,.5),(ramp,1),(1-ramp,1),(1-ramp/2,.5),(1,0)):
            self.assertAlmostEqual(envelope_at(gait,phase),expected)
        report=arm_report(self.samples,self.before)
        self.assertFalse(any('endpoint' in e for e in report['errors']),report['errors'])
        mutant=copy.deepcopy(self.samples)
        row=next(r for r in mutant['samples'] if (r['kind'],r['view'],r['clip'],r['phase'])==('presented','front','move',1))
        row['bones']['hand_near']['global'][4]+=TEST_DEFAULTS['mutation_angle_deg']
        self.assertTrue(any('endpoint' in e for e in arm_report(mutant,self.before)['errors']))

    def test_per_frame_draw_order_and_restoration_both_views(self):
        report=draw_report(self.samples)
        self.assertTrue(report['ok'],report['errors'])
        self.assertEqual([(r['clip'],r['side']) for r in report['findings']], [('block','near')]*33)
        self.assertEqual([r['frame'] for r in report['findings']],list(range(9,42)))
        mutant=copy.deepcopy(self.samples)
        row=next(r for r in mutant['samples'] if r['view']=='front' and r['clip']=='block' and r['frame']==TEST_DEFAULTS['mutation_frame'])
        row['parts']['hand_near']['z_index']=0
        self.assertTrue(draw_report(mutant)['errors'])

    def test_every_sample_part_has_a_finite_native_node_transform(self):
        for row in self.samples['samples']:
            self.assertEqual(set(row['parts']),{p['name'] for p in self.layouts[row['view']]['parts']})
            self.assertEqual(set(row['part_draw_order']),set(row['parts']))
            self.assertEqual(len(row['part_draw_order']),len(row['parts']))
            # Independent known tree relationship: skeleton sprites precede
            # the rig's skinned meshes, even when their z values tie.
            self.assertLess(row['part_draw_order'].index('head'),row['part_draw_order'].index('hand_near'))
            self.assertLess(row['part_draw_order'].index('hand_near'),row['part_draw_order'].index('sleeve_near'))
            for name,part in row['parts'].items():
                self.assertIn('transform',part,(row['view'],row['clip'],row['frame'],name))
                self.assertEqual(len(part['transform']),6)
                self.assertTrue(all(math.isfinite(v) for v in part['transform']))

    def test_far_arm_runtime_promotion_restoration_and_rear_exclusion(self):
        result=godot('tests/rr29/far_arm_fixture.gd')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RR29 FAR ARM RUNTIME: PASS (26 checks)',result.stdout)

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
            original=(ROOT/kit['prompt_source']).read_bytes()
            self.assertEqual((job/'prompt.md').read_bytes(),original)
        front=ROOT/'spec/art_identity/maquettes/hollow_mimic/prompt_front_mq11b.md'
        self.assertEqual(front.read_bytes(),(ROOT/'spec/peer_benchmark/staged/paintovers/hollow_mimic_front_mq11b.md').read_bytes())
        for name in ('hollow_mimic_rear_mq11.md','hollow_mimic_rear_mq11_r2.md'):
            original=subprocess.check_output(['git','show','681868048^:spec/peer_benchmark/staged/paintovers/'+name],cwd=ROOT)
            self.assertEqual((ROOT/'spec/art_identity/maquettes/hollow_mimic'/name.replace('hollow_mimic_','prompt_')).read_bytes(),original)

    def test_recorded_rear_residue_correction_replays_and_rejects_tampering(self):
        from art_identity_gate import verify_job_recipe
        from art_identity_post_steps import apply
        from unittest.mock import patch
        job=ROOT/'spec/art_identity/jobs/hollow_mimic/mq11_rear';processed=read_json(job/'processed.json')
        self.assertEqual(verify_job_recipe(job/'kit.json',require_inputs=True),[])
        corrections=processed['post_steps'][-1]['corrections']
        self.assertEqual(processed['post_steps'][-1]['pixels'],[[156,65],[141,93]])
        self.assertEqual([r['after'] for r in corrections],[[12,10,12,255],[16,14,15,255]])
        self.assertTrue(all(r['after'][1]<=max(r['after'][0],r['after'][2]) for r in corrections))
        changed=copy.deepcopy(processed)
        changed['post_steps'][-1]['corrections'][0]['after'][0]+=TEST_DEFAULTS['residue_channel_mutation']
        import art_identity_gate as gate
        original_read=gate.read_json
        with patch.object(gate,'read_json',side_effect=lambda p: changed if Path(p)==job/'processed.json' else original_read(p)):
            with self.assertRaisesRegex(ValueError,'correction differs'):verify_job_recipe(job/'kit.json')
        with self.assertRaisesRegex(ValueError,'not green-dominant'):
            size=TEST_DEFAULTS['residue_fixture_size_px']
            apply(Image.new('RGBA',(size,size)),[{'step':'key_residue_4_neighbour_mean','pixels':[[0,0]]}],pixel_digest)

    def test_rear_revision_prompt_tampering_fails_certification(self):
        import art_identity_gate as gate
        from unittest.mock import patch
        job=ROOT/'spec/art_identity/jobs/hollow_mimic/mq11_rear'
        kit=read_json(job/'kit.json');prompt=(job/kit['prompt_path']).read_bytes()
        self.assertEqual(gate.prompt_kit_version(kit,prompt),kit['kit_version'])
        self.assertEqual(gate.kit_version_verification(kit,prompt),'prompt_chain_ordered_refs')
        self.assertEqual(gate.verify_job_recipe(job/'kit.json',require_inputs=True),[])
        read_bytes=Path.read_bytes
        for target,reason in ((job/kit['revision_prompt_path'],'revision_prompt digest changed'),
                              (ROOT/kit['revision_prompt_source'],'revision_prompt source differs')):
            with self.subTest(target=target):
                with patch.object(Path,'read_bytes',lambda p: read_bytes(p)+b'\ntampered\n' if p==target else read_bytes(p)):
                    with self.assertRaisesRegex(ValueError,reason):gate.verify_job_recipe(job/'kit.json')
                    registry=read_json(ROOT/'spec/art_identity/registry.json')
                    entry=next(e for e in registry['entries'] if e.get('kit_path')==str((job/'kit.json').relative_to(ROOT)))
                    errors,_=gate.validate_kit_entry(entry,ROOT,read_json(ROOT/'spec/art_identity/bands.json'),{})
                    self.assertTrue(any(reason in e for e in errors),errors)
        changed=copy.deepcopy(kit)
        for suffix in ('path','source','sha256'):
            changed['prompt_'+suffix],changed['revision_prompt_'+suffix]=changed['revision_prompt_'+suffix],changed['prompt_'+suffix]
        original_read=gate.read_json
        with patch.object(gate,'read_json',side_effect=lambda p:changed if Path(p)==job/'kit.json' else original_read(p)):
            with self.assertRaisesRegex(ValueError,'chain kit_version'):gate.verify_job_recipe(job/'kit.json')
        print('RR29 REAR PROMPT TAMPERING: PASS (job revision, canonical revision and reordered chain rejected)')

    def test_native_capture_load_only(self):
        with tempfile.TemporaryDirectory(prefix='rr29-native-load-') as temporary:
            result=godot('tests/rr29/native_probe.gd','--case',CASE,'--output',temporary,'--validate-only')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RR29 NATIVE PROBE LOAD: PASS',result.stdout)


if __name__=='__main__':unittest.main()
