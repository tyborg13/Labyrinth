"""Schema validation and authored straight-leg direction, including failures."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'tests/rr14')]
from fixture import build
from humanoid_cutout.anatomy import load, for_layout, validate
from humanoid_cutout.bone_contracts import leg_bend_side
from humanoid_cutout.compiler import compile_motion

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-14/feedback1')
SEER = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
PROOF_TIMEOUT_SECONDS = 180


class AnatomyTests(unittest.TestCase):
    def setUp(self):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix='anatomy-', dir=SCRATCH)
        self.addCleanup(self.temporary.cleanup)
        self.case = Path(self.temporary.name)
        self.layout, self.anatomy, _, self.compiled = build(self.case)

    def assert_rejected_loaded_and_embedded(self, data, pattern):
        (self.case / 'anatomy.json').write_text(json.dumps(data))
        with self.subTest(source='loaded'), self.assertRaisesRegex(ValueError, pattern):
            load(self.case)
        with self.subTest(source='embedded'), self.assertRaisesRegex(ValueError, pattern):
            for_layout({'anatomy': data})

    def test_both_cases_validate_loaded_and_embedded(self):
        for case in (SEER, self.case):
            data = load(case)
            self.assertEqual(for_layout({'anatomy': data}), data)

    def test_schema_version_and_types_apply_to_embedded_as_well_as_loaded(self):
        for version in (2, True, '1'):
            data = copy.deepcopy(self.anatomy); data['schema_version'] = version
            self.assert_rejected_loaded_and_embedded(data, 'schema_version')
        data = copy.deepcopy(self.anatomy); data['idle_groups']['upper_body']['stationary'] = 1
        self.assert_rejected_loaded_and_embedded(data, 'stationary')

    def test_unknown_keys_at_each_structured_level_are_rejected(self):
        paths = [(), ('meshes', 'leg_near'), ('idle_groups', 'weapon_arm'),
                 ('ownership',), ('ownership', 'segments', 'arm_far'),
                 ('joint_continuations',), ('tucks',), ('covered_surfaces',), ('integration',),
                 ('held_depth_roles', 'tube'), ('legs',), ('legs', 'near'), ('legs', 'near', 'front')]
        for path in paths:
            with self.subTest(path=path):
                data = copy.deepcopy(self.anatomy)
                target = data
                for part in path: target = target[part]
                target['misspelled_field'] = None
                self.assert_rejected_loaded_and_embedded(data, 'misspelled_field')
        data = copy.deepcopy(self.anatomy)
        data['held_depth_roles']['tube']['policy']['frront'] = 'behind_body'
        self.assert_rejected_loaded_and_embedded(data, 'frront')

    def test_absent_grip_requires_explicit_null_and_griip_is_not_accepted(self):
        self.assertIsNone(validate(self.anatomy)['held_depth_roles']['tube']['grip'])
        data = copy.deepcopy(self.anatomy)
        del data['held_depth_roles']['tube']['grip']
        self.assert_rejected_loaded_and_embedded(data, r'grip: required key missing')
        data['held_depth_roles']['tube']['griip'] = None
        self.assert_rejected_loaded_and_embedded(data, 'griip')

    def test_schema_enforces_array_sizes_uniqueness_enums_and_required_recipe_fields(self):
        changes = [('owners', ['upper_far']), ('owners', ['upper_far', 'fore_far', 'claw'])]
        for field, value in changes:
            data = copy.deepcopy(self.anatomy); data['ownership']['segments']['arm_far'][field] = value
            self.assert_rejected_loaded_and_embedded(data, 'owners')
        data = copy.deepcopy(self.anatomy); data['ownership']['names'].append('claw')
        self.assert_rejected_loaded_and_embedded(data, 'duplicate')
        data = copy.deepcopy(self.anatomy); data['legs']['near']['front']['bend_side'] = 0
        self.assert_rejected_loaded_and_embedded(data, 'bend_side')
        data = copy.deepcopy(self.anatomy); del data['meshes']['leg_near']['cuff_rows_px']
        self.assert_rejected_loaded_and_embedded(data, 'schema variant')

    def test_straight_legs_require_per_view_policy_and_compiler_copies_it(self):
        self.assertEqual(self.compiled['legs'], self.anatomy['legs'])
        for side in ('near', 'far'):
            for view, sign in [('front', 1), ('rear', -1)]:
                self.assertEqual(leg_bend_side(self.layout, self.anatomy, side, view), sign)
                data = copy.deepcopy(self.anatomy)
                del data['legs'][side][view]
                with self.assertRaisesRegex(ValueError, r'legs.%s.%s.bend_side: required for straight rest leg' % (side, view)):
                    leg_bend_side(self.layout, data, side, view)
        data = copy.deepcopy(self.anatomy); del data['legs']['near']['front']
        (self.case / 'anatomy.json').write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'required for straight rest leg'):
            compile_motion(self.case / 'director_motion.json', 'synthetic_humanoid', {'front': self.layout}, self.compiled['projection'])

    def test_bent_leg_keeps_rest_side_and_rejects_disagreeing_data(self):
        layout = copy.deepcopy(self.layout)
        layout['joints']['shin_near']['position'] = [17, 24]
        layout['joints']['foot_near']['position'] = [20, 28]
        self.assertEqual(leg_bend_side(layout, self.anatomy, 'near', 'front'), 1)
        no_policy = copy.deepcopy(self.anatomy); no_policy.pop('legs')
        self.assertEqual(leg_bend_side(layout, no_policy, 'near', 'front'), 1)
        wrong = copy.deepcopy(self.anatomy); wrong['legs']['near']['front']['bend_side'] = -1
        with self.assertRaisesRegex(ValueError, 'disagrees with rest bend side'):
            leg_bend_side(layout, wrong, 'near', 'front')

    def test_collinearity_tolerance_is_normalized_to_segment_lengths(self):
        no_policy = copy.deepcopy(self.anatomy); no_policy.pop('legs')
        for scale in (1., 100.):
            layout = copy.deepcopy(self.layout)
            layout['joints']['shin_near']['position'][0] += 5e-7
            for joint in layout['joints'].values(): joint['position'] = [v * scale for v in joint['position']]
            with self.assertRaisesRegex(ValueError, 'required for straight rest leg'):
                leg_bend_side(layout, no_policy, 'near', 'front')

    def test_runtime_missing_and_conflicting_knee_policies_fail_loudly(self):
        for mode in ('missing_front', 'missing_rear', 'conflict_front', 'conflict_rear'):
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-14', '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', 'tests/rr14/runtime_checks.gd', '--',
                       '--case', str(self.case), '--invalid-knee-policy', mode]
            result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            log = result.stdout + result.stderr
            (SCRATCH / ('invalid-knee-' + mode + '.log')).write_text(log)
            with self.subTest(mode=mode):
                self.assertNotEqual(result.returncode, 0, log)
                self.assertIn('Invalid humanoid leg IK: legs.near.', log)
                self.assertIn('disagrees with rest bend side' if mode.startswith('conflict') else 'required for straight rest leg', log)
                self.assertNotIn('Parse Error', log)


if __name__ == '__main__':
    unittest.main()
