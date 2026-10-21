"""rr30 supplied-input, cut, hinge and hard acceptance contracts."""
import sys
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT/'tools'), str(PROJECT/'experiments/cutouts/slag_mortar')]
from rr30_case import CASE, DIRECTOR, ASSETS
from cutout_pipeline.cases import read_json
from humanoid_cutout.compiler import compile_motion
from art_identity_gate import verify_job_recipe


PROOF_TIMEOUT_SECONDS = 180


class MortarV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory(prefix='rr30-bones-') as folder:
            output=Path(folder)/'samples.json'
            result=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',
                os.environ.get('LABYRINTH_TASK_ID','rr-30'),'--stream','--','godot','--headless','--path','.',
                '--script','tests/rr22/samples.gd','--','--case',str(CASE),'--output',str(output)],
                cwd=PROJECT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
            if result.returncode: raise AssertionError(result.stdout+result.stderr)
            cls.samples=read_json(output)

    def test_production_runtime_loads_and_preserves_input_adapters(self):
        result=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',
            os.environ.get('LABYRINTH_TASK_ID','rr-30'),'--stream','--','godot','--headless','--path','.',
            '--script','tests/rr30/runtime_checks.gd'],cwd=PROJECT,capture_output=True,text=True,
            timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_protected_motion_byte_for_byte_and_only_director_actions_change(self):
        self.assertEqual((CASE/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        self.assertEqual((ASSETS/'humanoid_v2/director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        old=read_json(PROJECT/'spec/peer_benchmark/staged/rr-30/motion_tracks.json')['slag_mortar']
        new=read_json(DIRECTOR)['slag_mortar']
        for clip in ('idle','move'):
            self.assertEqual(new['clips'][clip],old['clips'][clip])
        for clip, definition in old['clips'].items():
            for key,value in definition.items():
                if key not in ('keys','gait','note','intents'):
                    self.assertEqual(new['clips'][clip][key],value)
            self.assertEqual(new['clips'][clip].get('intents'),definition.get('intents'))
        production=read_json(ASSETS/'humanoid_v2/compiled_motion.json')
        self.assertEqual(production['clips']['brace']['intents'],old['clips']['brace']['intents'])
        # The director restored brace's selector in the staged data, so editable and production motion are identical.
        editable=read_json(CASE/'compiled_motion.json')
        self.assertEqual(production,editable)
        for clip in ('land','hit'):
            for channel,rows in old['clips'][clip]['keys'].items():
                if channel!='head.lean_deg':
                    self.assertEqual(new['clips'][clip]['keys'][channel],rows)

    def test_rigid_shells_and_true_hinge_in_both_views(self):
        build=read_json(CASE/'proof/build.json')
        for view in ('front','rear'):
            layout=read_json(CASE/('layouts/'+view+'.json'))
            meshes={m['name'] for m in layout['joint_meshes']}
            self.assertEqual(build['views'][view]['rest_mismatch_pixels'],0)
            self.assertEqual(layout['joints']['flap']['parent'],'belt')
            self.assertEqual(layout['joints']['belt']['parent'],'pelvis')
            hinge=read_json(CASE/'ownership_traces.json')[view]['hinge_px']
            self.assertEqual(layout['joints']['flap']['position'],hinge)
            from maquette_motion.features import source_pixels
            belt=next(p for p in layout['parts'] if p['name']=='belt')
            self.assertGreater(source_pixels(CASE,belt)[hinge[1],hinge[0],3],0)
            for name,bone in [('belt','belt'),('flap','flap'),('bracer_near','fore_near'),('bracer_far','fore_far')]:
                part=next(p for p in layout['parts'] if p['name']==name)
                self.assertEqual(part['bone'],bone)
                self.assertNotIn(name,meshes)
                self.assertNotIn('hidden_'+name,meshes)
                if name.startswith('bracer_'):
                    arm=next(p for p in layout['parts'] if p['name']=='fore_'+name.split('_',1)[1])
                    self.assertGreater(part['z_index'],arm['z_index'])

    def test_compiler_keeps_authored_swing_and_resolves_director_sway(self):
        data=read_json(CASE/'compiled_motion.json')
        layouts={v:read_json(CASE/('layouts/'+v+'.json')) for v in ('front','rear')}
        self.assertEqual(compile_motion(DIRECTOR,'slag_mortar',layouts,data['projection']),data)
        self.assertEqual(data['TODO_DESIGN'],{})
        self.assertEqual(read_json(CASE/'cutout.json')['design_placeholders'],{})
        for view in layouts:
            self.assertTrue(any(t['channel']=='swing_deg' for t in data['view_tracks'][view]['hit']))

    def test_identity_recipes_replay_the_supplied_raw(self):
        for view in ('front','rear'):
            job=PROJECT/('spec/art_identity/jobs/slag_mortar/mq11_'+view)
            self.assertEqual(read_json(job/'kit.json')['K'],4)
            verify_job_recipe(job/'kit.json',PROJECT,require_inputs=True)
            self.assertEqual(read_json(job/'judge.json')['date'],'2026-10-20')

    def test_every_rigid_piece_meets_director_stretch_limit(self):
        from humanoid_cutout.stretch import report as stretch_report
        from humanoid_cutout.gates import bindings
        data=read_json(CASE/'compiled_motion.json')
        layouts={v:read_json(CASE/('layouts/'+v+'.json')) for v in ('front','rear')}
        report=stretch_report(CASE,layouts,data,self.samples,bindings(CASE),
            maximum_stretch=read_json(CASE/'cutout.json')['stretch_gate']['maximum_stretch'])
        self.assertEqual(report['maximum_stretch'],.12)
        self.assertEqual(report['errors'],[])
        self.assertEqual(len(report['pieces']),sum(len(l['parts']) for l in layouts.values()))
        self.assertLess(max(r['maximum_percent'] for r in report['pieces'].values()),.0001)


    def test_all_limb_segments_are_rigid_and_director08_is_the_source(self):
        inputs=read_json(CASE/'inputs.json')
        for view in ('front','rear'):
            self.assertEqual(inputs[view+'_delivery'],'tests/mq11_proof/director_08/slag_mortar/capture')
            layout=read_json(CASE/('layouts/'+view+'.json'))
            self.assertEqual(layout['joint_meshes'],[])
            parts={p['name']:p for p in layout['parts']}
            for side in ('near','far'):
                for prefix in ('upper','fore','hand','thigh','shin','foot'):
                    name=prefix+'_'+side
                    self.assertEqual(parts[name]['bone'],name)
                    self.assertEqual(parts[name]['declared_uniform_scale'],1.)
            self.assertNotIn('arm_near',parts)
            self.assertNotIn('leg_near',parts)
        rear=read_json(PROJECT/'spec/art_identity/jobs/slag_mortar/mq11_rear/kit.json')
        self.assertTrue(rear['provided_prompt_source'].endswith('slag_mortar_rear_mq11b.md'))
        self.assertTrue(all('refs_slag_mortar_rear_mq11b/' in r['source_file'] for r in rear['refs']))

    def test_sway_is_delayed_contact_sine_with_endpoint_ramps(self):
        import math
        from humanoid_cutout.gait import flap_sway
        definition=read_json(CASE/'compiled_motion.json')['clips']['move']
        lag=definition['gait']['flap_sway']['lag_s']/definition['seconds']
        self.assertEqual(flap_sway(definition,0.),0.)
        self.assertEqual(flap_sway(definition,1.),0.)
        self.assertAlmostEqual(flap_sway(definition,.28+lag),0.)
        self.assertAlmostEqual(flap_sway(definition,.33+lag),4.)
        self.assertAlmostEqual(flap_sway(definition,.43+lag),-4.)
        phase=.1
        cycle=(phase-lag)/.08
        envelope=(phase/.12)**2*(3-2*phase/.12)
        self.assertAlmostEqual(flap_sway(definition,phase),4*math.sin(math.tau*cycle)*envelope)

    def test_fresh_godot_flap_sway_in_both_views(self):
        import math
        # Independent director fixture: six contacts, delayed sine, authored
        # swing and endpoint ramps. Do not use the Python motion/sway oracle.
        contacts = [0., .08, .28, .48, .68, .88, 1.]
        data=read_json(CASE/'compiled_motion.json')
        for view in ('front','rear'):
            rows=[r for r in self.samples['samples'] if
                  (r['view'],r['clip'],r['kind'])==(view,'move','presented')]
            self.assertEqual(len(rows),51)
            measured_sway=[]
            for row in rows:
                phase=row['phase']
                delayed=max(0.,phase-.06/.85)
                left,right=next((a,b) for a,b in zip(contacts,contacts[1:]) if delayed<=b)
                ramp=min(1.,phase/.12,(1.-phase)/.12)
                sway=4*math.sin(math.tau*(delayed-left)/(right-left))*ramp*ramp*(3-2*ramp)
                blend=min(1.,phase/.15) if phase<=.9 else (1.-phase)/.1
                authored=-3*blend*blend*(3-2*blend)
                expected=(authored+sway)*data['projection'][view]['lean_sign']
                local=row['direction_bones']['flap']['local']
                actual=math.degrees(math.atan2(local[1],local[0]))
                self.assertAlmostEqual(actual,expected,places=3,msg=str((view,row['frame'])))
                measured_sway.append(actual-authored*data['projection'][view]['lean_sign'])
                # Confirm the visible sprite also receives that motion after
                # the existing director 1.5-degree presentation quantization.
                belt=row['direction_bones']['belt']['global']
                world=math.degrees(math.atan2(belt[1],belt[0]))+expected
                snapped=math.copysign(math.floor(abs(world/1.5)+.5)*1.5,world)
                painted=row['parts']['flap']['transform']
                self.assertAlmostEqual(math.degrees(math.atan2(painted[1],painted[0])),snapped,places=3)
            self.assertGreater(max(measured_sway),3.)
            self.assertLess(min(measured_sway),-3.)

    def test_rigid_joint_coverage_at_observed_failure_frames(self):
        from rr30_seams import CpuPose, frame_report
        from humanoid_cutout.source_space import DetachedSource, gate_errors
        observed={'front': [('move',7),('move',26),('move',47),('lob',59),
                            ('brace',9),('brace',49),('death',70),('death',72)],
                  'rear': [('move',20),('scatter',35),('scatter',36)]}
        for view, frames in observed.items():
            model=CpuPose(CASE,read_json(CASE/('layouts/'+view+'.json')))
            model.detached_source=DetachedSource(CASE,model.layout)
            for clip,frame in frames:
                pose=next(r for r in self.samples['samples'] if
                    (r['view'],r['clip'],r['frame'],r['kind'])==(view,clip,frame,'presented'))
                _,holes,metrics,_,_=frame_report(model,pose)
                self.assertEqual(gate_errors((view,clip,frame),metrics,holes),[])


if __name__=='__main__': unittest.main()
