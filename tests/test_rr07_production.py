"""Real RunScene callbacks, plus frozen/contact/coverage mutations for rr-07."""
import copy
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/hoarfrost_seer'))
from rr07_inputs import CREATURES, read_json
from rr07_prepare import case_for
from maquette_motion.gates import production_errors

PROOF_TIMEOUT_SECONDS = 180
PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID', 'rr-13')


class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='rr07-production-')
        cls.reports = {}
        for creature in CREATURES:
            output = Path(cls.temporary.name) / creature
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream',
                       '--', 'godot', '--headless', '--path', '.', '--script',
                       'tests/rr10/production_capture.gd' if creature=='hoarfrost_seer' else 'tests/rr07/production_capture.gd',
                       '--', '--type', creature, '--output', str(output), '--logic-only']
            process = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.reports[creature] = read_json(output / 'logic_frames.json')

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def errors(self, creature, report):
        if creature=='hoarfrost_seer':
            from humanoid_cutout.production_gates import production_errors as humanoid_errors
            case=PROJECT/'experiments/cutouts/hoarfrost_seer/rr10'
            return humanoid_errors(case,report,read_json(case/'compiled_motion.json'))
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
            word='three' if creature=='hoarfrost_seer' else 'six'
            self.assertIn('idle: fewer than '+word+' changing bone poses', self.errors(creature, mutant))

    def test_removed_contact_and_missing_action_are_rejected(self):
        for creature, report in self.reports.items():
            clip = 'mark' if creature == 'hoarfrost_seer' else 'tether'
            contact = read_json(case_for(creature) / 'compiled_motion.json')['clips'][clip]['contact']
            mutant = copy.deepcopy(report)
            mutant['frames'] = [r for r in mutant['frames'] if not
                (r['stage'] == clip and abs(r['snapshot']['phase'] - contact) < 1e-6)]
            self.assertIn(clip + ': missing real contact frame', self.errors(creature, mutant))
            mutant['frames'] = [r for r in mutant['frames'] if r['stage'] != 'move']
            self.assertIn('move: fewer than six action frames', self.errors(creature, mutant))

    def test_tether_animates_only_the_actor_and_vfx_begins_at_contact(self):
        report = self.reports['arc_thrall']
        rows = [r for r in report['frames'] if r['stage'] == 'tether']
        self.assertTrue(rows)
        self.assertTrue(all(r['partner_clip'] != 'tether' for r in rows))
        contact = read_json(case_for('arc_thrall') / 'compiled_motion.json')['clips']['tether']['contact']
        effects = [r for r in rows if r['effect'].get('action_type') == 'tether_beam']
        self.assertTrue(effects)
        self.assertAlmostEqual(min(r['snapshot']['phase'] for r in effects), contact, places=6)

    def test_icefall_marks_begin_at_contact(self):
        rows = [r for r in self.reports['hoarfrost_seer']['frames'] if r['stage'] == 'mark' and r['marks'] > 0]
        self.assertTrue(rows)
        contact = read_json(case_for('hoarfrost_seer') / 'compiled_motion.json')['clips']['mark']['contact']
        self.assertAlmostEqual(min(r['snapshot']['phase'] for r in rows), contact, places=6)


if __name__ == '__main__':
    unittest.main()
