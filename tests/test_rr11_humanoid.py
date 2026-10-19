"""Thrall source, production and mutation contracts; never launches a GUI."""
import copy
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/arc_thrall')]
from rr11_build import CASE, DIRECTOR, PIECES, recipe_for, registered_transform, label_palette, native_depths, bind_layout
from rr11_knees import knee_report, support_report, lift_track, swing_intervals, PRESENTED_TARGET_TOLERANCE_PX
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.source_view import prepare
from humanoid_cutout.mesh import weights_for
from humanoid_cutout.bone_contracts import leg_bend_side
from humanoid_cutout.leg_roles import roles_for, resolve_bone
from cutout_pipeline.cases import read_json, digest

PROOF_TASK_ID = 'rr-15'
PROOF_TIMEOUT_SECONDS = 180
FIXTURE_ROTATION_DEG = 1.0
FIXTURE_HIP_PX = [100, 100]
FIXTURE_ANKLE_PX = [100, 140]
FIXTURE_FORWARD_KNEE_PX = [90, 120]
FIXTURE_STRAIGHT_KNEE_PX = [100, 120]
FIXTURE_REVERSED_KNEE_PX = [110, 120]
FIXTURE_STANCE_FRAME = 20
FIXTURE_STANCE_SLIDE_PX = 1


class ThrallTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in ('front', 'rear')}
        cls.data = read_json(CASE / 'compiled_motion.json')
        cls.build = read_json(CASE / 'proof/build.json')
        with tempfile.TemporaryDirectory(prefix='rr11-bones-') as folder:
            path = Path(folder) / 'samples.json'
            result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', 'tests/rr11/action_direction.gd', '--',
                '--case', str(CASE), '--output', str(path)], cwd=PROJECT, capture_output=True, text=True,
                timeout=PROOF_TIMEOUT_SECONDS)
            if result.returncode: raise AssertionError(result.stdout + result.stderr)
            cls.samples = read_json(path)
        cls.bound = bindings(CASE)

    def test_protected_copy_and_compiler(self):
        self.assertEqual((CASE / 'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR, 'arc_thrall', self.layouts, self.data['projection']), self.data)
        self.assertEqual(self.data['TODO_DESIGN'], {})

    def test_every_view_cut_source_and_native_inputs(self):
        for view, layout in self.layouts.items():
            with self.subTest(view=view):
                self.assertEqual(structure_errors(layout, self.build), [])
                self.assertEqual(source_errors(CASE, layout, self.build), [])
                self.assertEqual(self.build['views'][view]['rest_mismatch_pixels'], 0)
                self.assertEqual(layout['source_labels'], PIECES)
                self.assertEqual(layout['joints']['tube_tip']['parent'], 'fore_near')
                self.assertEqual(layout['joints']['pelvis']['parent'], 'root')
                self.assertEqual(layout['joints']['loincloth_tip']['parent'], 'pelvis')
                self.assertNotIn('hand_near', layout['joints'])
                self.assertNotIn('club', layout['joints'])
                self.assertNotIn('collar', layout['joints'])
                self.assertEqual({m['name'] for m in layout['joint_meshes'] if not m['hidden_material']},
                                 {'sleeve_far', 'leg_near', 'leg_far', 'loincloth'})
                for filename, expected in self.build['views'][view]['delivery'].items():
                    self.assertEqual(digest(PROJECT / 'spec/art_identity/maquettes/arc_thrall/delivery' / filename), expected)

    def test_shoulder_rule_and_cap_landmark(self):
        native = read_json(PROJECT / 'spec/art_identity/maquettes/arc_thrall/delivery/joints_px.json')['front']
        near, far = map(np.asarray, (native['shoulder_near'], native['shoulder_far']))
        self.assertLess(abs((near[1] - far[1]) - .15 * abs(near[0] - far[0])), 10)
        for view in self.layouts:
            spec = read_json(CASE / f'{view}_baseline/source/spec_native.json')
            recipe = recipe_for('arc_thrall', spec, view)
            tube = next(p for p in spec['pieces'] if p['part'] == 'fore_near')
            vertices, axis, mouth = map(np.asarray, (tube['vertices'], tube['socket']['axis'], tube['socket']['mouth']))
            distance = np.sum((vertices-mouth) * axis, axis=1)
            cap = np.asarray(recipe['joints']['tube_tip']['position_3d'])
            self.assertAlmostEqual(float(np.sum((cap-mouth) * axis)), float(distance.max()), places=7)

    def test_covered_member_is_only_allowed_inside_visible_fusion(self):
        baseline = CASE / 'rear_baseline'
        thigh = Image.open(baseline / 'pieces/rear/thigh_near.png').convert('RGBA')
        self.assertIsNone(thigh.getbbox())
        self.assertIsNotNone(Image.open(baseline / 'pieces/rear/shin_near.png').getbbox())
        inputs = read_json(CASE / 'inputs.json')
        inputs['fused_occlusion'] = False
        with tempfile.TemporaryDirectory(prefix='rr11-source-') as folder:
            with self.assertRaisesRegex(ValueError, 'TODO_DESIGN_rear_thigh_near_hidden_paint'):
                prepare(PROJECT, Path(folder), inputs, 'rear', PIECES, registered_transform,
                    label_palette, native_depths, lambda creature, spec: recipe_for(creature, spec, 'rear'), bind_layout)

    def test_production_closure_and_registration(self):
        assets = PROJECT / 'assets/units/arc_thrall_cutout/humanoid_v2'
        self.assertEqual((assets / 'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        for view in self.layouts:
            layout = read_json(assets / (view + '.json'))
            self.assertEqual(layout['rig'], 'humanoid_v2')
            self.assertEqual(layout['ik_chains'], self.layouts[view]['ik_chains'])
            for part in layout['parts'] + layout['joint_meshes']:
                self.assertNotIn('experiments/', part['file'])
                self.assertTrue((assets / part['file']).is_file())
            self.assertNotIn('experiments/', layout['motion_data'])

    def test_idle_motion_and_signed_tube_targets(self):
        for layout in self.layouts.values():
            errors = bone_errors(layout, self.data, self.samples, self.bound)
            self.assertEqual(errors, [])
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['view'] == 'front' and r['clip'] == 'tether' and r['kind'] == 'authored' and r['phase'] == .35)
        row['bones']['tube_tip']['global'][4] += 1
        self.assertTrue(any('signed hand target: tube_tip' in e for e in bone_errors(self.layouts['front'], self.data, mutant, self.bound)))

    def test_idle_mesh_tuck_and_basis_mutations(self):
        layout, build = copy.deepcopy(self.layouts['front']), copy.deepcopy(self.build)
        layout['joint_meshes'] = [m for m in layout['joint_meshes'] if m['name'] != 'leg_near']
        self.assertTrue(any('required meshes differ' in e for e in structure_errors(layout, build)))
        build['tucks'][0]['minimum_px'] = 2
        self.assertTrue(any('tuck' in e for e in structure_errors(self.layouts['front'], build)))
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['view'] == 'front' and r['clip'] == 'idle')
        angle = math.radians(FIXTURE_ROTATION_DEG)
        row['bones']['torso']['global'][:4] = [math.cos(angle), math.sin(angle), -math.sin(angle), math.cos(angle)]
        self.assertTrue(any('idle rotation' in e for e in bone_errors(self.layouts['front'], self.data, mutant, self.bound)))

    def test_leg_roles_resolve_tracks_and_mode_only_jab(self):
        anatomy = read_json(CASE / 'anatomy.json')
        self.assertEqual(anatomy['knee_policy'], {'near_straight_deg': 6})
        for view, expected in [('front', {'stride': 'near', 'trailing': 'far'}), ('rear', {'stride': 'far', 'trailing': 'near'})]:
            self.assertEqual(roles_for(anatomy, view), expected)
            for role, side in expected.items():
                self.assertEqual(resolve_bone('foot_' + role, anatomy, view), 'foot_' + side)
            track = lift_track(self.layouts[view], self.data)
            self.assertEqual(track['bone'], 'foot_' + expected['stride'])
            self.assertEqual(track['source'], 'foot_stride.lift_px')
            self.assertEqual(self.data['view_forward_modes'][view]['jab'], {'foot_' + expected['trailing']: 'body'})
        wrong = copy.deepcopy(anatomy)
        wrong['leg_roles']['rear']['trailing'] = 'far'
        with self.assertRaisesRegex(ValueError, 'distinct'): roles_for(wrong, 'rear')
        missing = copy.deepcopy(anatomy)
        missing['leg_roles'] = {}
        with self.assertRaisesRegex(ValueError, 'TODO_DESIGN'): resolve_bone('foot_stride', missing, 'front')

    def test_case_threshold_applies_only_to_near_straight_rest(self):
        anatomy = read_json(CASE / 'anatomy.json')
        for view, layout in self.layouts.items():
            for side in ('near', 'far'):
                self.assertEqual(leg_bend_side(layout, anatomy, side, view), 1 if view == 'front' else -1)
        old = copy.deepcopy(anatomy)
        old.pop('knee_policy')
        with self.assertRaisesRegex(ValueError, 'disagrees'): leg_bend_side(self.layouts['front'], old, 'near', 'front')
        missing = copy.deepcopy(anatomy)
        missing['legs']['near'].pop('front')
        with self.assertRaisesRegex(ValueError, 'required'): leg_bend_side(self.layouts['front'], missing, 'near', 'front')
        wrong_far = copy.deepcopy(anatomy)
        wrong_far['legs']['far']['front']['bend_side'] = -1
        with self.assertRaisesRegex(ValueError, 'disagrees'): leg_bend_side(self.layouts['front'], wrong_far, 'far', 'front')

    def test_peak_direction_and_apex_mutations(self):
        layout = self.layouts['front']
        report = copy.deepcopy(self.samples)
        # A reversed bent knee must fail even on the exempt trailing leg.
        row = next(r for r in report['samples'] if r['view'] == 'front' and r['clip'] == 'move' and r['kind'] == 'presented' and .15 < r['phase'] < .25)
        for joint, xy in [('thigh', FIXTURE_HIP_PX), ('shin', FIXTURE_REVERSED_KNEE_PX), ('foot', FIXTURE_ANKLE_PX)]:
            row['bones'][joint + '_far']['global'][4:] = xy
        self.assertTrue(any('trailing: bent knee against facing' in e for e in knee_report(layout, self.data, report)['errors']))
        # Straighten the entire first stride swing: the peak gate must fail.
        report = copy.deepcopy(self.samples)
        start, end = swing_intervals(lift_track(layout, self.data)['keys'])[0]
        for row in report['samples']:
            if row['view'] == 'front' and row['clip'] == 'move' and row['kind'] == 'presented' and start < row['phase'] < end:
                for joint, xy in [('thigh', FIXTURE_HIP_PX), ('shin', FIXTURE_STRAIGHT_KNEE_PX), ('foot', FIXTURE_ANKLE_PX)]:
                    row['bones'][joint + '_near']['global'][4:] = xy
        errors = knee_report(layout, self.data, report)['errors']
        self.assertTrue(any('peak knee' in e and 'below 15' in e for e in errors))
        self.assertTrue(any('apex stride knee' in e for e in errors))
        self.assertTrue(knee_report(layout, self.data, {'samples': []})['errors'])

    def test_presented_stride_support_is_stationary_and_on_target(self):
        for view, layout in self.layouts.items():
            with self.subTest(view=view):
                report = support_report(layout, self.data, self.samples)
                self.assertEqual(report['errors'], [])
                self.assertEqual(report['maximum_stance_frame_change_px'], 0)
                self.assertEqual(report['maximum_jab_frame_change_px'], 0)
                for group in ('stance', 'jab'):
                    for row in report[group]:
                        if row['kind'] == 'presented':
                            self.assertLessEqual(row['target_error_px'], PRESENTED_TARGET_TOLERANCE_PX)

    def test_one_frame_stride_slide_fails_move_and_jab_in_both_views(self):
        for view, layout in self.layouts.items():
            foot = 'foot_' + self.data['leg_roles'][view]['stride']
            for clip in ('move', 'jab'):
                with self.subTest(view=view, clip=clip):
                    report = copy.deepcopy(self.samples)
                    row = next(r for r in report['samples'] if r['view'] == view and r['clip'] == clip and
                               r['kind'] == 'presented' and r['frame'] == FIXTURE_STANCE_FRAME)
                    # At the fractional half-step, the adjacent grid point is
                    # still within the allowed snap radius. Stationarity must
                    # reject that one-frame slide independently of target error.
                    direction = -1 if view == 'front' else 1
                    row['bones'][foot]['global'][4] += direction * FIXTURE_STANCE_SLIDE_PX
                    result = support_report(layout, self.data, report)
                    self.assertTrue(any('stride stance moved 1.000000 px' in e for e in result['errors']))
                    if clip == 'move': self.assertFalse(any('stride target error' in e for e in result['errors']))

    def test_constant_stance_shift_fails_target_without_sliding(self):
        layout = self.layouts['front']
        report = copy.deepcopy(self.samples)
        first_swing = swing_intervals(lift_track(layout, self.data)['keys'])[0][0]
        for row in report['samples']:
            if row['view'] == 'front' and row['clip'] == 'move' and row['kind'] == 'presented' and row['phase'] <= first_swing:
                row['bones']['foot_near']['global'][4] += FIXTURE_STANCE_SLIDE_PX
        result = support_report(layout, self.data, report)
        self.assertTrue(any('stride target error' in e for e in result['errors']))
        self.assertFalse(any('stride stance moved' in e for e in result['errors']))

    def test_chain_field_is_finite_and_normalized(self):
        for layout in self.layouts.values():
            mesh = next(m for m in layout['joint_meshes'] if m['name'] == 'loincloth')
            weights = weights_for(mesh['vertices'], mesh['bbox'], layout['joints'], read_json(CASE / 'anatomy.json')['meshes']['loincloth'])
            self.assertTrue(np.isfinite(list(weights.values())).all())
            self.assertTrue(np.allclose(np.sum(list(weights.values()), axis=0), 1))


if __name__ == '__main__': unittest.main()
