"""Director regressions for rotation-only supports and nonlinear reach bounds."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'tests/rr14')]
from fixture import build
from cutout_pipeline.cases import read_json
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.reach import report, world_bounds, proven_linear
from humanoid_cutout.action_direction import pose_values
from humanoid_cutout.bone_contracts import fk_world

TASK_ID = 'rr-16'
PROOF_TIMEOUT_SECONDS = 180
PHASE_TOLERANCE = 1e-6
DISTANCE_TOLERANCE_PX = 1e-4
DIP_PHASES = (0, .5001, .5009, 1)
FORE_VALUES_PX = (0, 0, 30, 30)
HAND_VALUES_PX = (-34, -34, -64, -64)
TRUE_MINIMUM_PHASE = .5007309401076758
TRUE_MINIMUM_PX = 23.113248654051866
EXPECTED_SUPPORT_PX = (20, 31)
SUPPORT_PHASE = .5
PROOF_STEP_DISTANCE_PX = 96
PROOF_SCREEN_PIXEL_SCALE = 2
BOUND_ENCLOSURE_SAMPLE_COUNT = 9

# Temporary headless probe: it imports no resources into the project's tree.
SUPPORT_PROBE = '''extends SceneTree
const Runtime = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
func _initialize() -> void:
\tpreload("res://scripts/parallel_runtime.gd").apply_from_environment()
\tvar args: PackedStringArray = OS.get_cmdline_user_args()
\tvar fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--fixture") + 1]))
\tvar failures: Array[String]
\tfor version: String in ["base", "with_rotation"]:
\t\tfor view: String in ["front", "rear"]:
\t\t\tvar world: Dictionary = Runtime.world_transforms(fixture[version], "jab", float(fixture["phase"]), fixture["layout"], view)
\t\t\tvar point: Vector2 = (world["foot_near"] as Transform2D).origin
\t\t\tif point != Vector2(fixture["expected"][0], fixture["expected"][1]):
\t\t\t\tfailures.append(version + "/" + view + ": " + str(point))
\tfor failure: String in failures: push_error(failure)
\tprint("RR16 SUPPORT MODES: %s (4 views/configurations)" % ["PASS" if failures.is_empty() else "FAIL"])
\tquit(0 if failures.is_empty() else 1)
'''


def curved_fixture():
    layout = {'facing': 'front', 'joints': {
        'root': {'parent': None, 'position': [0, 0]},
        'upper_near': {'parent': 'root', 'position': [0, 0]},
        'fore_near': {'parent': 'upper_near', 'position': [40, 0]},
        'hand_near': {'parent': 'fore_near', 'position': [60, 0]}}}
    tracks = [{'bone': bone, 'channel': 'forward_px', 'forward_mode': 'pixels',
               'keys': [{'at': phase, 'value': value, 'interpolation': interpolation}
                        for phase, value in zip(DIP_PHASES, values)]}
              for bone, values, interpolation in [('fore_near', FORE_VALUES_PX, 'linear'),
                                                  ('hand_near', HAND_VALUES_PX, 'smoothstep')]]
    return layout, {'projection': {'front': {'forward': [1, 0]}},
                    'view_tracks': {'front': {'jab': tracks}}}


class FeedbackTests(unittest.TestCase):
    def test_chord_pruning_requires_affine_translations_and_constant_rotations(self):
        _, data = curved_fixture()
        tracks = data['view_tracks']['front']['jab']
        self.assertFalse(proven_linear(tracks, DIP_PHASES[1], DIP_PHASES[2]))
        linear = copy.deepcopy(tracks)
        for track in linear:
            for key in track['keys']:
                key['interpolation'] = 'linear'
        self.assertTrue(proven_linear(linear, DIP_PHASES[1], DIP_PHASES[2]))
        rotation = copy.deepcopy(linear[0])
        rotation['channel'] = 'lean_deg'
        self.assertFalse(proven_linear([*linear, rotation], DIP_PHASES[1], DIP_PHASES[2]))
        for key in linear[0]['keys']:
            key['interpolation'] = 'hold'
        self.assertFalse(proven_linear(linear, DIP_PHASES[1], DIP_PHASES[2]))

    def test_fk_boxes_enclose_real_rotating_paths_and_world_step_anchors(self):
        case = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
        data = read_json(case / 'compiled_motion.json')
        for view in data['view_tracks']:
            layout = read_json(case / f'layouts/{view}.json')
            forward = np.asarray(data['projection'][view]['forward'])
            for clip in ('move', 'tether', 'death'):
                tracks = data['view_tracks'][view][clip]
                phases = sorted({0., 1., *(key['at'] for track in tracks for key in track['keys'])})
                for start, end in zip(phases, phases[1:]):
                    step = PROOF_STEP_DISTANCE_PX / PROOF_SCREEN_PIXEL_SCALE
                    boxes = world_bounds(layout, data, view, clip, forward, step, start, end)
                    for phase in np.linspace(start, end, BOUND_ENCLOSURE_SAMPLE_COUNT):
                        values, modes = pose_values(data, view, clip, phase)
                        fk = fk_world(layout, values, modes, forward, step)
                        for name, transform in fk.items():
                            point = transform[:2, 2]
                            bounds = np.asarray(boxes[name])
                            self.assertTrue(np.all(point >= bounds[:, 0]) and np.all(point <= bounds[:, 1]),
                                            (view, clip, start, end, phase, name, point, bounds))

    def test_zero_lean_keeps_body_support_metadata_and_runtime_position_in_both_views(self):
        with tempfile.TemporaryDirectory(prefix='rr16-rotation-support-') as folder:
            case = Path(folder)
            layout, _, _, data = build(case)
            layouts = {view: dict(layout, facing=view) for view in ('front', 'rear')}
            author = read_json(case / 'director_motion.json')
            author['synthetic_humanoid']['clips'] = {'jab': {'seconds': 1, 'keys': {
                'pelvis.lift_px': [[0, -1], [1, -1]], 'foot_near.forward_mode': 'body'},
                'view_keys': {'rear': {}}}}
            path = case / 'director_motion.json'
            path.write_text(json.dumps(author))
            base = compile_motion(path, 'synthetic_humanoid', layouts, data['projection'])
            author['synthetic_humanoid']['clips']['jab']['keys']['foot_near.lean_deg'] = [[0, 0], [1, 0]]
            path.write_text(json.dumps(author))
            rotated = compile_motion(path, 'synthetic_humanoid', layouts, data['projection'])
            for view in layouts:
                self.assertEqual(base['view_forward_modes'][view], rotated.get('view_forward_modes', {}).get(view))
                self.assertEqual(rotated['view_forward_modes'][view]['jab'], {'foot_near': 'body'})
            # Added author keys necessarily add a track and change the author digest.
            # All other compiled bytes, including both views' support metadata, agree.
            normalized = copy.deepcopy(rotated)
            normalized['director_sha256'] = base['director_sha256']
            for view in layouts:
                normalized['view_tracks'][view]['jab'] = [track for track in normalized['view_tracks'][view]['jab']
                                                         if track['source'] != 'foot_near.lean_deg']
            self.assertEqual(json.dumps(base, sort_keys=True), json.dumps(normalized, sort_keys=True))
            fixture = case / 'comparison.json'
            fixture.write_text(json.dumps({'layout': layout, 'base': base, 'with_rotation': rotated,
                                           'expected': EXPECTED_SUPPORT_PX, 'phase': SUPPORT_PHASE}))
            probe = case / 'support_modes.gd'
            probe.write_text(SUPPORT_PROBE)
            result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', TASK_ID,
                '--stream', '--', 'godot', '--headless', '--path', '.', '--script', str(probe),
                '--', '--fixture', str(fixture)], cwd=PROJECT, capture_output=True, text=True,
                timeout=PROOF_TIMEOUT_SECONDS)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('RR16 SUPPORT MODES: PASS (4 views/configurations)', result.stdout)
            print('RR16 SUPPORT MODES: PASS (4 views/configurations)')

    def test_mixed_linear_smoothstep_reach_dip_fails_at_true_minimum(self):
        layout, data = curved_fixture()
        result = report(layout, data, step_distance_px=PROOF_STEP_DISTANCE_PX, screen_pixel_scale=PROOF_SCREEN_PIXEL_SCALE)
        self.assertFalse(result['ok'])
        self.assertTrue(any('front/jab/hand_near: minimum reach' in error for error in result['errors']))
        path = result['paths'][0]
        self.assertEqual(path['allowed_minimum_px'], 24)
        self.assertAlmostEqual(path['minimum_px'], TRUE_MINIMUM_PX, delta=DISTANCE_TOLERANCE_PX)
        self.assertAlmostEqual(path['minimum_phase'], TRUE_MINIMUM_PHASE, delta=PHASE_TOLERANCE)
        print('RR16 CURVED REACH: FAIL AS REQUIRED (%.9f px at %.9f)' %
              (path['minimum_px'], path['minimum_phase']))


if __name__ == '__main__':
    unittest.main()
