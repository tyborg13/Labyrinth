"""Gait compiler contracts, real runtime mutations, and preservation evidence."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.gait import evaluate, expand, schedule
from humanoid_cutout.walk_gates import report, rigid_air_errors
from humanoid_cutout.rigid_joint_gap import gap
from humanoid_cutout import walk_gates
from cutout_pipeline.cases import read_json

CASES={'arc_thrall':'rr11','glacial_mirror':'rr18'}
DIRECTOR_DATA_REVISION='80d5ec39b'
FIXTURE_SLIDE_PX=1.
FIXTURE_AIR_PX=4.
PROOF_TIMEOUT_SECONDS=180
PROOF_TASK_ID=os.environ.get('LABYRINTH_TASK_ID','gait-01')


def run_godot(script,*args):
    result=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',PROOF_TASK_ID,'--stream','--',
        'godot','--headless','--path','.','--script',script,'--',*map(str,args)],cwd=ROOT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
    if result.returncode:raise AssertionError(result.stdout+result.stderr)
    return result.stdout+result.stderr


def changed_paths():
    """Cover committed implementation, working changes and untracked sources."""
    result=set()
    for command in (['git','diff','--name-only',DIRECTOR_DATA_REVISION,'HEAD'],
                    ['git','diff','--name-only','HEAD'],
                    ['git','ls-files','--others','--exclude-standard']):
        result.update(subprocess.check_output(command,cwd=ROOT,text=True).splitlines())
    return result


class GaitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases={}
        for creature,rr in CASES.items():
            case=ROOT/'experiments/cutouts'/creature/rr
            with tempfile.TemporaryDirectory(prefix='gait01-') as folder:
                output=Path(folder)/'samples.json'
                run_godot('tests/rr11/action_direction.gd','--case',case,'--output',output)
                samples=read_json(output)
            data=read_json(case/'compiled_motion.json')
            layouts={view:read_json(case/f'layouts/{view}.json') for view in data['view_tracks']}
            cls.cases[creature]=(case,data,layouts,samples)

    def test_expansion_schedule_root_lanes_and_exact_lift(self):
        for case,data,layouts,samples in self.cases.values():
            gait=data['clips']['move']['gait']
            swings=schedule(gait)
            np.testing.assert_allclose([(s['start'],s['end']) for s in swings],[(0,.08),(.12,.28),(.32,.48),(.52,.68),(.72,.88),(.92,1)])
            self.assertEqual([s['side'] for s in swings],['near','far']*3)
            for view in layouts:
                tracks=data['view_tracks'][view]['move']
                root=next(t for t in tracks if t['source']=='root.forward_px')
                self.assertEqual(evaluate(root['keys'],.3),.3)
                for swing in swings:
                    lift=next(t for t in tracks if t['source']=='foot_'+swing['side']+'.lift_px')
                    self.assertAlmostEqual(evaluate(lift['keys'],(swing['start']+swing['end'])/2),gait['lift_px'])
                for side in ('near','far'):
                    lane=next(t for t in tracks if t['source']=='foot_'+side+'.lane_px')
                    self.assertEqual(evaluate(lane['keys'],0),0)
                    self.assertEqual(evaluate(lane['keys'],1),0)

    def test_generated_channel_conflicts_include_view_overrides(self):
        for case,data,layouts,_ in self.cases.values():
            author=read_json(case/'director_motion.json')
            creature=data['creature']
            for channel in ('foot_near.forward_px','foot_far.lift_px','pelvis.lift_px','root.forward_px','foot_near.lane_px'):
                for view_override in (False,True):
                    mutant=copy.deepcopy(author)
                    clip=mutant[creature]['clips']['move']
                    keys=clip.setdefault('view_keys',{}).setdefault('rear',{}) if view_override else clip['keys']
                    keys[channel]=[[0,0],[1,0]]
                    with tempfile.TemporaryDirectory(prefix='gait01-director-') as folder:
                        source=Path(folder)/'motion.json';source.write_text(json.dumps(mutant))
                        with self.assertRaisesRegex(ValueError,'director key on generated channel'):
                            compile_motion(source,creature,layouts,data['projection'])

    def test_bad_models_unknown_nested_fields_and_odd_counts_are_errors(self):
        _,data,layouts,_=self.cases['arc_thrall']
        for key,value in [('model','other'),('steps_per_tile',5),('unknown',1),('settle_px',{'oops':1}),('arm_swing',{'near':{'bone':'tube_tip','px':2,'oops':1}})]:
            gait=copy.deepcopy(data['clips']['move']['gait']);gait[key]=value
            with self.assertRaises(ValueError):expand(gait,layouts['front'],'move')
        with self.assertRaisesRegex(ValueError,'only move'):expand(data['clips']['move']['gait'],layouts['front'],'hit')

    def test_one_pixel_planted_foot_mutation_is_caught_on_both_legs(self):
        for _,data,layouts,samples in self.cases.values():
            for view,layout in layouts.items():
                for side in ('near','far'):
                    mutant=copy.deepcopy(samples)
                    row=next(r for r in mutant['samples'] if r['view']==view and r['clip']=='move' and r['kind']=='presented' and .28<r['phase']<.32)
                    row['bones']['foot_'+side]['global'][4]+=FIXTURE_SLIDE_PX
                    errors=report(layout,data,mutant)['errors']
                    self.assertTrue(any('stance moved' in e or 'foot target error' in e for e in errors))

    def test_zero_lift_swing_is_caught(self):
        _,data,layouts,samples=self.cases['arc_thrall']
        mutant=copy.deepcopy(data)
        for track in mutant['view_tracks']['front']['move']:
            if track['source']=='foot_near.lift_px':
                for key in track['keys']:key['value']=0.
        self.assertTrue(any('swing lift differs' in e for e in report(layouts['front'],mutant,samples)['errors']))

    def test_rigid_four_pixel_air_mutation_is_caught(self):
        # Two painted unit squares touching at rest; move one exactly 4 px.
        first=np.array([[0.,0.]])
        rest=np.array([[1.,0.]])
        basis=np.eye(2)
        self.assertEqual(gap(first,basis,rest,basis),0.)
        air=gap(first,basis,rest+np.array([FIXTURE_AIR_PX,0.]),basis)
        self.assertEqual(air,FIXTURE_AIR_PX)
        self.assertTrue(rigid_air_errors([{'joint':'fixture/knee','air_px':air}]))

    def rigid_gap_fixture(self, side='near', skinned_side=None):
        """Translate approved painted pieces into an exact four-pixel gap."""
        case,data,layouts,samples=self.cases['glacial_mirror']
        layout=copy.deepcopy(layouts['front'])
        row=copy.deepcopy(next(r for r in samples['samples'] if r['view']=='front' and
                              r['clip']=='move' and r['kind']=='presented' and r['frame']==0))
        bones={name+'_'+leg for leg in ('near','far') for name in ('thigh','shin','foot')}
        layout['parts']=[p for p in layout['parts'] if p['bone'] in bones and not p.get('hidden_material')]
        self.assertEqual(len(layout['parts']),6)
        pixels={}
        for part in layout['parts']:
            with Image.open(case/part['file']) as image:
                y,x=np.nonzero(np.asarray(image.convert('RGBA'))[...,3])
            points=np.column_stack((x,y)).astype(float)
            pixels[part['bone']]=(part['name'],points)
            # Give each pair an overlapping opaque pixel at rest.
            row['parts'][part['name']]['transform']=[1.,0.,0.,1.,*(-points[0]).tolist()]
        _,shin=pixels['shin_'+side]
        foot_name,foot=pixels['foot_'+side]
        shin_edge=shin[np.argmax(shin[:,0])]-shin[0]
        foot_edge=foot[np.argmin(foot[:,0])]
        offset=shin_edge+np.array([1.+FIXTURE_AIR_PX,0.])-foot_edge
        row['parts'][foot_name]['transform']=[1.,0.,0.,1.,*offset.tolist()]
        layout['joint_meshes']=[{'name':'unrelated_arm', 'weights':{'upper_near':[1.], 'fore_near':[0.]}}]
        if skinned_side:
            layout['joint_meshes'].append({'name':'leg_skin',
                'weights':{'thigh_'+skinned_side:[1.], 'shin_'+skinned_side:[0.]}})
        return layout,data,{**samples,'samples':[row]}

    def assert_rigid_gap_rejected(self, fixture):
        result=report(*fixture)
        self.assertTrue(any('rigid air 4.000000 px > 3' in error for error in result['errors']))
        self.assertAlmostEqual(result['maximum_rigid_air_px'],FIXTURE_AIR_PX)
        return result

    def test_four_pixel_gap_with_unrelated_arm_mesh_is_caught(self):
        self.assert_rigid_gap_rejected(self.rigid_gap_fixture())

    def test_each_rigid_leg_is_checked_beside_a_skinned_leg(self):
        for side,other in (('near','far'),('far','near')):
            with self.subTest(rigid_side=side):
                fixture=self.rigid_gap_fixture(side,other)
                result=self.assert_rigid_gap_rejected(fixture)
                self.assertFalse(walk_gates.skinned(fixture[0],side))
                self.assertTrue(walk_gates.skinned(fixture[0],other))
                self.assertTrue(all(record['joint'].endswith(('_'+side)) for record in result['rigid_air']))

    def test_removing_rigid_air_integration_is_caught(self):
        fixture=self.rigid_gap_fixture()
        self.assert_rigid_gap_rejected(fixture)
        # Removing measurement from the integrated report must fail the same
        # assertion as the shipped four-pixel arm-mesh regression test.
        with patch.object(walk_gates,'joint_air',return_value=[]):
            with self.assertRaises(AssertionError):
                self.assert_rigid_gap_rejected(fixture)

    def test_shared_walk_writer_separates_summary_and_full_diagnostics(self):
        result=self.assert_rigid_gap_rejected(self.rigid_gap_fixture())
        reports={'front':result}
        with tempfile.TemporaryDirectory(prefix='gait01-summary-') as folder:
            case=Path(folder)
            for name in ('knees','supports'):
                walk_gates.write_reports(case,name,reports)
                compact=read_json(case/f'proof/{name}.json')['front']
                full=read_json(case/f'proof/logs/walk_gates/{name}.json')['front']
                self.assertEqual(full,result)
                for field in ('frames','stance','rigid_air','jab'):
                    self.assertNotIn(field,compact)
                for field in ('ok','errors','swings','maximum_fit_px','maximum_total_pelvis_drop_px','maximum_rigid_air_px'):
                    self.assertEqual(compact[field],result[field])
                self.assertEqual(compact['sample_counts']['frames'],len(result['frames']))
                failures=[r for r in result['rigid_air']
                          if r['air_px']>walk_gates.MAX_RIGID_AIR_PX+walk_gates.EPSILON]
                self.assertEqual(compact['rigid_air_failures'],failures)
                self.assertLess(len(json.dumps(compact)),len(json.dumps(full)))

    def test_projected_skin_preserves_width_and_rigid_pieces_keep_unit_basis(self):
        for creature,(_,data,layouts,samples) in self.cases.items():
            for row in samples['samples']:
                if row['clip']!='move' or row['kind']!='authored':continue
                layout=layouts[row['view']]
                for side in ('near','far'):
                    for upper,lower in (('thigh_','shin_'),('shin_','foot_')):
                        first=np.asarray(layout['joints'][upper+side]['position'])
                        end=np.asarray(layout['joints'][lower+side]['position'])
                        rest=end-first
                        basis=np.array(row['bones'][upper+side]['global'][:4]).reshape(2,2).T
                        if creature=='arc_thrall':
                            normal=np.array([-rest[1],rest[0]])/np.linalg.norm(rest)
                            self.assertAlmostEqual(float(np.linalg.norm(basis@normal)),1.,places=5)
                            actual=np.asarray(row['bones'][lower+side]['global'][4:])-row['bones'][upper+side]['global'][4:]
                            np.testing.assert_allclose(basis@rest,actual,atol=.0001,rtol=0)
                        else:
                            np.testing.assert_allclose(basis.T@basis,np.eye(2),atol=.0001,rtol=0)

    def test_move_probe_loads_all_24_frames_without_a_window(self):
        for case,_,_,_ in self.cases.values():
            with tempfile.TemporaryDirectory(prefix='gait01-probe-') as folder:
                self.assertIn('GAIT MOVE PROBE LOAD: PASS (24 frames; 12 per view)',
                    run_godot('tests/gait01/move_capture.gd','--case',case,'--output',folder,'--validate-only'))

    def test_thrall_runtime_diagnostic_uses_declared_supports(self):
        self.assertIn('RR11 RUNTIME: PASS',run_godot('tests/rr11/runtime_checks.gd'))

    def test_preservation_scope_includes_the_committed_implementation(self):
        self.assertIn('scripts/maquette_cutout_runtime/humanoid_gait.gd',changed_paths())

    def test_non_move_tracks_and_out_of_scope_assets_remain_identical(self):
        for case,data,_,_ in self.cases.values():
            relative=str((case/'compiled_motion.json').relative_to(ROOT))
            old=json.loads(subprocess.check_output(['git','show',DIRECTOR_DATA_REVISION+':'+relative],cwd=ROOT))
            for view in data['view_tracks']:
                for clip in data['clips']:
                    if clip=='move':continue
                    self.assertEqual(data['view_tracks'][view][clip],old['view_tracks'][view][clip])
                    self.assertEqual(data['clips'][clip],old['clips'][clip])
        changed=changed_paths()
        protected=('assets/units/protagonist_cutout/','scripts/protagonist_cutout/',
                   'assets/units/hoarfrost_seer_cutout/','experiments/cutouts/hoarfrost_seer/',
                   'assets/units/storm_capacitor_cutout/','experiments/cutouts/storm_capacitor/',
                   'spec/peer_benchmark/staged/')
        self.assertEqual([p for p in changed if p.startswith(protected)],[])
        self.assertEqual([p for p in changed if p.endswith('.png')],[])


if __name__=='__main__':unittest.main(verbosity=2)
