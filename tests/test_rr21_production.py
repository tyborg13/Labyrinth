"""Real resolver -> board playback acceptance, both front and true rear."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/briar_weaver')]
from rr21_case import CASE
from rr21_production import errors, motion_gates
from cutout_pipeline.cases import read_json
from tests.test_rr21_cutout import run_script


class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = read_json(CASE / 'compiled_motion.json')
        cls.reports = {}
        for view in ('front', 'rear'):
            output = CASE / 'proof/logs/production' / view
            args = ['--type', 'briar_weaver', '--output', output, '--logic-only']
            if view == 'rear': args.append('--rear')
            transcript = run_script('tests/rr21/production_capture.gd', *args)
            output.joinpath('transcript.txt').write_text(transcript)
            cls.reports[view] = read_json(output / 'logic_frames.json')

    def test_real_contacts_sounds_outcomes_and_complete_progression(self):
        for view, report in self.reports.items():
            with self.subTest(view=view):
                self.assertEqual(errors(report, self.data), [])
                for clip in ('thornwall', 'lash', 'mend', 'move'):
                    rows = [r for r in report['frames'] if r['stage'] == clip]
                    self.assertTrue(all(r['snapshot']['facing'] == view for r in rows))

    def test_revised_actual_board_move_knees_and_supports_pass(self):
        for view, report in self.reports.items():
            result = motion_gates(report, self.data)
            self.assertEqual(result['errors'], [], view)
            self.assertEqual(len(result['knees']['swings']), 2)
            self.assertEqual(result['supports']['maximum_stance_frame_change_px'], 0)
            self.assertEqual(result['design_placeholders'], {})

    def test_mutations_reject_late_contact_stale_binding_and_missing_pose(self):
        original = self.reports['front']
        for kind in ('contact', 'binding', 'pose', 'early_heal', 'reversed_pose'):
            mutant = copy.deepcopy(original)
            if kind == 'contact':
                for row in mutant['frames']:
                    if row['stage'] == 'lash' and abs(row['snapshot']['phase'] - .45) < 1e-6:
                        row['snapshot']['phase'] += .01
            elif kind == 'binding': mutant['inputs'] = {}
            elif kind == 'pose':
                next(r for r in mutant['frames'] if r['stage'] == 'thornwall')['bones'] = {}
            elif kind == 'early_heal':
                next(r for r in mutant['frames'] if r['stage'] == 'mend')['ally_hp'] = 5
            else:
                next(r for r in mutant['frames'] if r['stage'] == 'lash')['bones']['hand_near']['global'][4] += 1
            self.assertTrue(errors(mutant, self.data), kind)


if __name__ == '__main__': unittest.main()
