"""Pixel formulas, historical native negatives, contour attribution and budgets."""
from copy import deepcopy
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/slag_mortar')]
from cutout_pipeline.cases import read_json
from humanoid_cutout import image_gates as gates
from rr31_images import ImageGate, CASE, rest_pose
from rr31_budgets import validate

FIXTURE_SIZE_PX = 48
FIXTURE_ZONE = {'joint': [24.,12.]}
PROBE_TEST_STEP_PX = 96.
PROBE_TEST_SCALE = 2.
PROBE_TEST_OFFSET = 6.
PROBE_TEST_TIMEOUT_SECONDS = 180
CONTOUR_MUTATION_TRANSLATION_PX = 4


class MorphologyTests(unittest.TestCase):
    def setUp(self):
        self.alpha = np.zeros((FIXTURE_SIZE_PX,FIXTURE_SIZE_PX),dtype=bool)
        self.alpha[12:36,12:36] = True

    def notch(self):
        result = self.alpha.copy()
        result[12:17,23] = False
        return result

    def fray(self):
        result = self.alpha.copy()
        result[8:12,24] = True
        return result

    def test_exact_euclidean_disks(self):
        self.assertEqual(len(gates.offsets(1)),5)
        self.assertEqual(len(gates.offsets(2)),13)
        self.assertNotIn((2,1),gates.offsets(2))

    def test_rest_passes_and_notch_is_not_a_hole_test(self):
        rest = gates.measure(self.alpha,FIXTURE_ZONE)
        self.assertEqual(gates.compare(rest,rest),[])
        changed = gates.measure(self.notch(),FIXTURE_ZONE)
        self.assertGreater(changed['joint']['notches'],rest['joint']['notches'])
        self.assertTrue(any(e['metric']=='notches' for e in gates.compare(rest,changed)))

    def test_fray_allowance_is_exactly_two(self):
        rest = {'joint':dict(notches=0,frays=4)}
        self.assertEqual(gates.compare(rest,{'joint':dict(notches=0,frays=6)}),[])
        self.assertEqual(gates.compare(rest,{'joint':dict(notches=0,frays=7)})[0]['metric'],'frays')
        self.assertGreater(gates.measure(self.fray(),FIXTURE_ZONE)['joint']['frays'],
                           gates.measure(self.alpha,FIXTURE_ZONE)['joint']['frays']+2)

    def test_native_pixels_and_fourteen_pixel_zone(self):
        mask = np.zeros_like(self.alpha)
        mask[10,10] = mask[10,24] = mask[10,25] = True
        self.assertEqual(gates.counts(mask,{'joint':[10.5,10.5]}),{'joint':2})

    def test_two_pixel_interior_threshold(self):
        inside = gates.interior(self.alpha)
        self.assertFalse(inside[12,20])
        self.assertTrue(inside[13,20])  # nearest transparent centre is 2 px away

    def test_notch_and_fray_mutations_are_detected_independently(self):
        rest = gates.measure(self.alpha,FIXTURE_ZONE)
        for alpha,metric in ((self.notch(),'notches'),(self.fray(),'frays')):
            measured = gates.measure(alpha,FIXTURE_ZONE)
            def acceptance():
                self.assertTrue(any(e['metric']==metric for e in gates.compare(rest,measured)))
            acceptance()
            with mock.patch.object(gates,'compare',return_value=[]):
                with self.assertRaises(AssertionError): acceptance()


class MortarImageTests(unittest.TestCase):
    def test_eight_native_stages_dispatch_through_required_runners(self):
        # Execute the real shell control flow with only python dispatch replaced.
        # This validates commands/contracts without starting a windowed engine.
        with tempfile.TemporaryDirectory(prefix='rr31-driver-') as folder:
            root = Path(folder)
            log = root/'commands.jsonl'
            shim = root/'python3'
            shim.write_text('#!'+sys.executable+'\nimport json,os,sys\n'
                'with open(os.environ["RR31_COMMAND_LOG"],"a") as out:\n'
                ' out.write(json.dumps(sys.argv[1:])+"\\n")\n')
            shim.chmod(0o755)
            env = dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'],
                       RR31_COMMAND_LOG=str(log),LABYRINTH_TASK_ID='rr-31')
            for stage in ('density','rest','native','sheets','walk','idle','production','review'):
                result = subprocess.run(['sh','experiments/cutouts/slag_mortar/rr30_proof.sh',stage],
                    cwd=PROJECT,env=env,capture_output=True,text=True,timeout=PROBE_TEST_TIMEOUT_SECONDS)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            commands = [json.loads(line) for line in log.read_text().splitlines()]
        visual = [c for c in commands if c[0]=='tools/visual_probe_runner.py']
        self.assertEqual(len(visual),7)
        for command in visual:
            for flag in ('--no-headless','--proof-contract','--overwrite-result-manifest'):
                self.assertIn(flag,command)
            self.assertEqual(command[command.index('--expect-size')+1],'1920x1080')
            self.assertEqual(command[command.index('--task-id')+1],'rr-31')
        self.assertTrue(any(c[:2]==['experiments/cutouts/slag_mortar/rr31_images.py','native'] for c in commands))
        for command in (c for c in commands if 'godot' in c):
            self.assertEqual(command[0],'tools/godot_task_runner.py')

    def test_isolated_sampler_actually_moves_angles_and_gait_lanes(self):
        data = read_json(CASE/'compiled_motion.json')
        requests = []
        for view,clips in data['view_tracks'].items():
            tracks = {t['source']:t for tracks in clips.values() for t in tracks}
            for channel in ('flap.swing_deg','foot_near.lane_px'):
                requests.append(dict(view=view,track=tracks[channel],values=[0.,PROBE_TEST_OFFSET]))
        with tempfile.TemporaryDirectory(prefix='rr31-joint-test-') as folder:
            root = Path(folder)
            source,output = root/'requests.json',root/'samples.json'
            source.write_text(json.dumps(dict(requests=requests,step_distance_px=PROBE_TEST_STEP_PX,
                                              screen_pixel_scale=PROBE_TEST_SCALE)))
            result = subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',
                os.environ.get('LABYRINTH_TASK_ID','rr-31'),'--stream','--','godot','--headless','--path','.',
                '--script','tests/rr31/joint_samples.gd','--','--requests',str(source),'--output',str(output)],
                cwd=PROJECT,capture_output=True,text=True,timeout=PROBE_TEST_TIMEOUT_SECONDS)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            rows = read_json(output)['samples']
        self.assertEqual(len(rows),8)
        for request in requests:
            group = [r for r in rows if r['view']==request['view'] and r['channel']==request['track']['source']]
            self.assertNotEqual(group[0]['parts'],group[1]['parts'])

    def test_all_rest_material_states_are_exact(self):
        for view in ('front','rear'):
            gate = ImageGate(CASE,read_json(CASE/f'layouts/{view}.json'))
            for clip in ('rest','lob','death','move'):
                pose = dict(rest_pose(gate.layout),clip=clip)
                result = gate.frame(pose,gate.layers(pose))
                self.assertTrue(result['ok'],result)

    def test_interior_contour_attribution_and_mutation(self):
        gate = ImageGate(CASE,read_json(CASE/'layouts/front.json'))
        pose = rest_pose(gate.layout)
        pose['parts']['torso']['transform'][4] += CONTOUR_MUTATION_TRANSLATION_PX
        layers = gate.layers(pose)
        def acceptance():
            result = gate.frame(pose,layers)
            self.assertTrue(any(e['piece']=='torso' for e in result['interior_contour']))
        acceptance()
        with mock.patch.dict(gate.contours,{'torso':np.zeros_like(gate.contours['torso'])}):
            with self.assertRaises(AssertionError): acceptance()

    def test_retained_round3_native_lob_brace_death_fail(self):
        fixture = np.load(PROJECT/'tests/rr31/round3_native.npz')
        records = read_json(PROJECT/'tests/rr31/round3_native.json')
        for row in records['frames']:
            rest = gates.measure(fixture[row['view']+'_rest'],records['rest_centroids'][row['view']])
            posed = gates.measure(fixture[row['id']],row['centroids'])
            self.assertTrue(gates.compare(rest,posed),row['id'])

    def test_director_import_and_production_are_byte_identical(self):
        provided = (PROJECT/'spec/peer_benchmark/staged/rr-31/motion_tracks.json').read_bytes()
        self.assertEqual((CASE/'director_motion.json').read_bytes(),provided)
        self.assertEqual((PROJECT/'assets/units/slag_mortar_cutout/humanoid_v2/director_motion.json').read_bytes(),provided)


class BudgetTests(unittest.TestCase):
    def budgets(self):
        return dict(views={'front':{'hand_near.lift_px':{
            side:dict(maximum_passing=3.,first_failing=3.25,rest_passes=True,censored=False)
            for side in ('positive','negative')}}})

    def director(self,value):
        return dict(clips={'lob':dict(keys={'hand_near.lift_px':[[0,0],[.5,value],[1,0]]})})

    def test_exact_limit_passes_and_excess_gets_named_without_changing_data(self):
        director = self.director(4.)
        unchanged = deepcopy(director)
        result = validate(self.budgets(),director)
        self.assertFalse(result['ok'])
        self.assertIn('TODO_DESIGN_budget_lob_hand_near_lift_px',result['TODO_DESIGN'])
        self.assertEqual(director,unchanged)
        self.assertTrue(validate(self.budgets(),self.director(3.))['ok'])

    def test_signed_limits_missing_channels_and_view_overrides(self):
        budget = self.budgets()
        budget['views']['front']['hand_near.lift_px']['negative']['maximum_passing'] = 1.
        self.assertFalse(validate(budget,self.director(-2.))['ok'])
        director = self.director(0.)
        director['clips']['lob']['view_keys'] = {'front':{'hand_near.lift_px':[[0,4.]]}}
        self.assertFalse(validate(budget,director)['ok'])
        budget['views']['front'].clear()
        self.assertFalse(validate(budget,director)['ok'])


if __name__ == '__main__': unittest.main()
