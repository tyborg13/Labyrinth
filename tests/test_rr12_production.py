"""Real RunScene callbacks, plus frozen/contact/coverage mutations for rr-12."""
import copy
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/burrow_grub'))
from rr12_inputs import CREATURES, read_json
from rr12_prepare import case_for
from maquette_motion.gates import production_errors

PROOF_TIMEOUT_SECONDS = 180


class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='rr12-production-')
        cls.reports = {}
        for creature in CREATURES:
            output = Path(cls.temporary.name) / creature
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-12'), '--stream',
                       '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr12/production_capture.gd',
                       '--', '--type', creature, '--output', str(output), '--logic-only']
            process = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.reports[creature] = read_json(output / 'logic_frames.json')

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def errors(self, creature, report):
        return production_errors(report, read_json(case_for(creature) / 'compiled_motion.json'))

    def test_real_callbacks_have_six_changing_frames_and_contact(self):
        for creature, report in self.reports.items():
            self.assertTrue(report['ok'], report['errors'])
            self.assertFalse(report['native_pixels'])
            self.assertEqual(self.errors(creature, report), [])

    def test_frozen_idle_is_rejected(self):
        for creature, report in self.reports.items():
            mutant = copy.deepcopy(report)
            for row in mutant['frames']:
                if row['stage'] == 'idle': row['pose_sha256'] = 'frozen'
            self.assertIn('idle: fewer than six changing bone poses', self.errors(creature, mutant))

    def test_removed_contact_and_missing_action_are_rejected(self):
        for creature, report in self.reports.items():
            clip = 'erupt' if creature == 'burrow_grub' else 'kindle'
            contact = read_json(case_for(creature) / 'compiled_motion.json')['clips'][clip]['contact']
            mutant = copy.deepcopy(report)
            mutant['frames'] = [r for r in mutant['frames'] if not
                (r['stage'] == clip and abs(r['snapshot']['phase'] - contact) < 1e-6)]
            self.assertIn(clip + ': missing real contact frame', self.errors(creature, mutant))
            mutant['frames'] = [r for r in mutant['frames'] if r['stage'] != 'move']
            self.assertIn('move: fewer than six action frames', self.errors(creature, mutant))

    def test_burrow_finishes_hidden_and_erupt_feedback_begins_at_contact(self):
        report = self.reports['burrow_grub']
        buried = [r for r in report['frames'] if r['stage'] == 'burrow']
        self.assertTrue(buried)
        self.assertTrue(all(not r['burrowed'] for r in buried if r['snapshot']['phase'] < 1))
        self.assertTrue(any(r['burrowed'] for r in buried if r['snapshot']['phase'] == 1))
        eruption = [r for r in report['frames'] if r['stage'] == 'erupt']
        contact = read_json(case_for('burrow_grub') / 'compiled_motion.json')['clips']['erupt']['contact']
        self.assertEqual(min(r['snapshot']['phase'] for r in eruption), 0)
        self.assertTrue(all(r['root_alpha'] == 0 for r in eruption if r['snapshot']['phase'] == 0))
        feedback = [r for r in eruption if r['erupt_dust']]
        self.assertTrue(feedback)
        self.assertAlmostEqual(min(r['snapshot']['phase'] for r in feedback), contact, places=6)
        self.assertEqual(len({r['actor_tile'] for r in eruption}), 1)

    def test_kindle_bonus_and_effect_start_at_authored_contact(self):
        rows = [r for r in self.reports['ember_tick']['frames'] if r['stage'] == 'kindle']
        contact = read_json(case_for('ember_tick') / 'compiled_motion.json')['clips']['kindle']['contact']
        self.assertTrue(rows)
        self.assertTrue(all(r['kindled_bonus'] == 0 and not r['effect'] for r in rows if r['snapshot']['phase'] < contact))
        effected = [r for r in rows if r['kindled_bonus'] > 0 and r['effect']]
        self.assertTrue(effected)
        self.assertAlmostEqual(min(r['snapshot']['phase'] for r in effected), contact, places=6)


if __name__ == '__main__':
    unittest.main()
