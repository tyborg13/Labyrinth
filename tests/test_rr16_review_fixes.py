"""rr-15 adversarial inputs: mode-only metadata, narrow reach and exact pockets."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'tests/rr14')]
from fixture import build
from cutout_pipeline.cases import read_json
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.native_exceptions import JOINT_HOLE_RULE, METRIC_RULES, frame_errors, load
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.silhouette_gates import joint_holes

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
FIXTURE_LENGTHS_PX = (40, 20)
DIP_START_PHASE = .5001
DIP_END_PHASE = .5009
DIP_ENDPOINT_PX = 50
PHASE_TOLERANCE = 1e-6
REACH_TOLERANCE_PX = .1
MODE_FIXTURE_PELVIS_LIFT_PX = -1
POCKET_FIXTURE_SIZE_PX = 16
POCKET_BODY_BOUNDS = (3, 3, 13, 13)
POCKET_HOLE_BOUNDS = (7, 7, 9, 9)
POCKET_EXPECTED_PIXELS = 4


class ReviewFixTests(unittest.TestCase):
    def test_empty_override_cannot_change_either_views_mode_only_support(self):
        with tempfile.TemporaryDirectory(prefix='rr16-modes-') as folder:
            case = Path(folder)
            layout, _, _, compiled = build(case)
            layouts = {view: dict(layout, facing=view) for view in ('front', 'rear')}
            author = read_json(case / 'director_motion.json')
            clip = author['synthetic_humanoid']['clips']['move']
            # No leg roles; both modes have no numeric channel to carry them.
            clip['keys'] = {'pelvis.lift_px': [[0, MODE_FIXTURE_PELVIS_LIFT_PX], [1, MODE_FIXTURE_PELVIS_LIFT_PX]],
                            'foot_near.forward_mode': 'body', 'foot_far.forward_mode': 'world_step'}
            path = case / 'director_motion.json'
            path.write_text(json.dumps(author))
            before = compile_motion(path, 'synthetic_humanoid', layouts, compiled['projection'])
            clip['view_keys'] = {'rear': {}}
            path.write_text(json.dumps(author))
            after = compile_motion(path, 'synthetic_humanoid', layouts, compiled['projection'])
            # The author-file hash necessarily differs. Every effective output byte must agree.
            for data in (before, after):
                data.pop('director_sha256')
            self.assertEqual(json.dumps(before, sort_keys=True), json.dumps(after, sort_keys=True))
            for view in layouts:
                self.assertEqual(before['view_forward_modes'][view]['move'],
                                 {'foot_near': 'body', 'foot_far': 'world_step'})

    def test_short_interior_reach_dip_is_bisected_to_true_minimum(self):
        first, second = FIXTURE_LENGTHS_PX
        layout = {'facing': 'front', 'joints': {
            'root': {'parent': None, 'position': [0, 0]},
            'upper_near': {'parent': 'root', 'position': [0, 0]},
            'fore_near': {'parent': 'upper_near', 'position': [first, 0]},
            'hand_near': {'parent': 'fore_near', 'position': [first + second, 0]}}}
        track = {'bone': 'hand_near', 'channel': 'forward_px', 'forward_mode': 'pixels',
                 'keys': [{'at': phase, 'value': target - first - second, 'interpolation': 'linear'}
                          for phase, target in [(0, -DIP_ENDPOINT_PX), (DIP_START_PHASE, -DIP_ENDPOINT_PX),
                                                (DIP_END_PHASE, DIP_ENDPOINT_PX), (1, DIP_ENDPOINT_PX)]]}
        data = {'projection': {'front': {'forward': [1, 0]}},
                'view_tracks': {'front': {'jab': [track]}}}
        result = reach_report(layout, data, step_distance_px=96, screen_pixel_scale=2)
        self.assertFalse(result['ok'])
        self.assertTrue(any('front/jab/hand_near: minimum reach' in e for e in result['errors']))
        path = result['paths'][0]
        self.assertAlmostEqual(path['minimum_px'], 0, delta=REACH_TOLERANCE_PX)
        self.assertAlmostEqual(path['minimum_phase'], (DIP_START_PHASE + DIP_END_PHASE) / 2,
                               delta=PHASE_TOLERANCE)
        self.assertEqual(path['allowed_minimum_px'], 24)

    def test_extra_hole_in_each_approved_frame_is_rejected(self):
        approved = load(CASE)
        metric = dict.fromkeys(METRIC_RULES, 0)
        for clip, frame, counts in [('jab', 22, [2, 50]), ('death', 31, [7, 50])]:
            key = ('front', clip, frame)
            self.assertEqual(frame_errors(key, metric, counts, approved), [str(key) + ': ' + JOINT_HOLE_RULE])

    def test_pocket_requires_its_location_and_count_and_matches_only_once(self):
        approved = load(CASE)
        metric = dict.fromkeys(METRIC_RULES, 0)
        for row in read_json(CASE / 'gate_exceptions.json'):
            key = (row['view'], row['clip'], row['frames'][0])
            pocket = row['pocket']
            self.assertEqual(frame_errors(key, metric, [pocket], approved), [])
            for bad in [dict(pocket, pixel_count=pocket['pixel_count'] + 1),
                        dict(pocket, bbox=[n + 1 for n in pocket['bbox']])]:
                self.assertEqual(frame_errors(key, metric, [bad], approved), [str(key) + ': ' + JOINT_HOLE_RULE])
            self.assertEqual(frame_errors(key, metric, [pocket, pocket], approved),
                             [str(key) + ': ' + JOINT_HOLE_RULE])
            self.assertEqual(frame_errors(key, metric, [pocket, 50], approved),
                             [str(key) + ': ' + JOINT_HOLE_RULE])

    def test_case_pockets_match_the_retained_native_capture_evidence(self):
        evidence = read_json(PROJECT / 'experiments/cutouts/arc_thrall/rr16/pocket_evidence.json')
        actual = {(r['view'], r['clip'], r['frames'][0]): r['pocket']
                  for r in read_json(CASE / 'gate_exceptions.json')}
        self.assertEqual(actual, {tuple(row['key']): row['pocket'] for row in evidence})

    def test_native_hole_detector_retains_pocket_bounds(self):
        # A hole at the joint of two owners, without any transported rest hole.
        occupied = np.zeros((POCKET_FIXTURE_SIZE_PX,) * 2, dtype=bool)
        x, y, right, bottom = POCKET_BODY_BOUNDS
        occupied[y:bottom, x:right] = True
        x, y, right, bottom = POCKET_HOLE_BOUNDS
        occupied[y:bottom, x:right] = False
        owners = np.where(occupied, 1, 0).astype(np.uint8)
        owners[bottom:, :] *= 2
        ownership = {'names': ['torso', 'arm'], 'free_space_owners': [],
                     'joint_pairs': [['torso', 'arm']]}
        self.assertEqual(joint_holes(occupied, occupied, owners, ownership=ownership, pocket_details=True),
                         [{'bbox': list(POCKET_HOLE_BOUNDS), 'pixel_count': POCKET_EXPECTED_PIXELS}])


if __name__ == '__main__':
    unittest.main()
