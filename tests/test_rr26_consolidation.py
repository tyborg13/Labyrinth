"""Consolidated action selection and hash-verified committed pose recovery."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LOG = ROOT / 'experiments/cutouts/hollow_mimic/rr20/proof/logs'
PROOF_TIMEOUT_SECONDS = 180
# An observed sampler float whose decimal lexeme Godot's JSON parser rounds.
FIXTURE_TINY_BONE_NUMBER = '0.000000000465661287307739'


class ConsolidationTests(unittest.TestCase):
    def run_script(self, script, *args):
        return subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id',
            os.environ.get('LABYRINTH_TASK_ID', 'rr-26'), '--stream', '--', 'godot', '--headless',
            '--path', '.', '--script', script, '--', *map(str, args)], cwd=ROOT,
            capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)

    def test_case_priority_contact_fallback_and_unchanged_other_paths(self):
        result = self.run_script('tests/rr26/action_dispatch.gd')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('RR26 ACTION DISPATCH: PASS (10 checks;', result.stdout)

    def test_recovery_preserves_raw_pose_numbers_and_rejects_tampered_rows(self):
        with tempfile.TemporaryDirectory(prefix='rr26-record-recovery-', dir=LOG) as folder:
            folder = Path(folder)
            current, metadata, recovered = [folder / name for name in ('current.json', 'committed.json', 'recovered.json')]
            full = ('{"fps":60.0,"ok":true,"samples":[{"bones":{"root":{"global":[1.0,0.0,0.0,1.0,'
                    + FIXTURE_TINY_BONE_NUMBER + ',0.0]}},"clip":"idle","frame":0,"kind":"presented",'
                    '"phase":0.0,"view":"front"}],"screen_pixel_scale":1.0}')
            current.write_text(full)
            expected = hashlib.sha256(current.read_bytes()).hexdigest()
            metadata.write_text(json.dumps({'fps': 60.0, 'ok': True, 'screen_pixel_scale': 1.0,
                'full_samples': {'file': 'logs/samples.json', 'sha256': expected}}))
            result = self.run_script('tests/rr26/canonical_record.gd', metadata, current, recovered)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(recovered.read_bytes(), current.read_bytes())
            current.write_text(full.replace(FIXTURE_TINY_BONE_NUMBER, '0.0'))
            result = self.run_script('tests/rr26/canonical_record.gd', metadata, current, recovered)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn('RR26 COMMITTED RECORD RECONSTRUCTION: FAIL', result.stdout)
            self.assertEqual(json.loads(metadata.read_text())['full_samples']['sha256'], expected)


if __name__ == '__main__': unittest.main()
