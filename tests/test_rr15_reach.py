"""Dense unclamped reach diagnostics and regressions for the old rear jab."""
import copy
import json
from pathlib import Path
import sys
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/arc_thrall'))
from cutout_pipeline.cases import read_json
from humanoid_cutout.reach import report

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
PROOF_STEP_PX = 96.0
PROOF_SCALE = 2.0
MAXIMUM_MUTATION_FACTOR = 2
MINIMUM_ROUNDING_TOLERANCE_PX = .1
OLD_CONTACT_REACH_PX = 43.04


class ReachTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = read_json(CASE / 'compiled_motion.json')
        cls.layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in ('front', 'rear')}

    def reach(self, view, data=None):
        return report(self.layouts[view], self.data if data is None else data,
                      step_distance_px=PROOF_STEP_PX, screen_pixel_scale=PROOF_SCALE)

    def test_new_rear_paths_clear_minimum_margin_and_maximum_in_dense_samples(self):
        rear = self.reach('rear')
        # Director rr-27 feedback 2 changes this measured Tether minimum.
        # Keep the independent allowed-minimum assertion: approved keys do
        # not waive the existing reach gate, which currently fails.
        for clip, expected_minimum in [('jab', 66.2), ('tether', 25.770793547018958)]:
            path = next(r for r in rear['paths'] if r['clip'] == clip and r['target'] == 'tube_tip')
            self.assertGreaterEqual(path['samples'], 1001)
            self.assertAlmostEqual(path['minimum_px'], expected_minimum, delta=MINIMUM_ROUNDING_TOLERANCE_PX)
            self.assertGreaterEqual(path['minimum_px'], path['allowed_minimum_px'])
            self.assertLessEqual(path['maximum_px'], path['allowed_maximum_px'])

    def test_old_rear_jab_mutation_fails_and_finds_an_interior_minimum(self):
        data = copy.deepcopy(self.data)
        base = read_json(CASE / 'director_motion.json')['arc_thrall']['clips']['jab']['keys']
        for track in data['view_tracks']['rear']['jab']:
            if track['source'] in ('tube_tip.forward_px', 'tube_tip.lift_px'):
                track['keys'] = [{'at': row[0], 'value': row[1],
                    'interpolation': row[2] if len(row) > 2 else 'smoothstep'} for row in base[track['source']]]
        result = self.reach('rear', data)
        self.assertTrue(any('rear/jab/tube_tip: minimum reach' in e for e in result['errors']))
        path = next(r for r in result['paths'] if r['clip'] == 'jab' and r['target'] == 'tube_tip')
        self.assertGreater(path['minimum_phase'], .3)
        self.assertLess(path['minimum_phase'], .45)
        self.assertLess(path['minimum_px'], OLD_CONTACT_REACH_PX)  # Independently traced contact distance.

    def test_overextended_target_is_reported_not_failed(self):
        # Keep this maximum-reach mutation on the previously valid fixture;
        # the new feedback-2 path independently fails minimum reach below.
        from rr27_tether_identity import before_bytes
        data = json.loads(before_bytes('experiments/cutouts/arc_thrall/rr11/compiled_motion.json'))
        track = next(t for t in data['view_tracks']['rear']['tether'] if t['source'] == 'tube_tip.forward_px')
        for row in track['keys']:
            row['value'] *= MAXIMUM_MUTATION_FACTOR
        result = self.reach('rear', data)
        self.assertFalse(any('rear/tether/tube_tip' in e for e in result['errors']))
        self.assertTrue(any('rear/tether/tube_tip: maximum reach' in e for e in result['overreach']))

    def test_current_data_passes_with_documented_overreach(self):
        # Director 2026-10-19: death flings and the front jab claw reach past full extension on purpose.
        expected = {'front/move/hand_far', 'front/jab/hand_far', 'front/death/tube_tip',
                    'front/death/hand_far', 'rear/death/hand_far'}
        front, rear = self.reach('front'), self.reach('rear')
        self.assertEqual(front['errors'] + rear['errors'], [])
        self.assertEqual({e.split(':')[0] for e in front['overreach'] + rear['overreach']}, expected)


if __name__ == '__main__':
    unittest.main()
