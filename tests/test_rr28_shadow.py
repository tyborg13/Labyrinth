"""Capacitor shadow records stay exact while other figures evolve."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROOF_TIMEOUT_SECONDS = 90


def godot(script, *args):
    return subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id',
        os.environ.get('LABYRINTH_TASK_ID', 'rr-28'), '--stream', '--', 'godot', '--headless',
        '--path', '.', '--script', script, '--', *map(str, args)], cwd=ROOT,
        capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)


class CapacitorShadowTests(unittest.TestCase):
    def test_only_own_records_are_required_and_compared_exactly(self):
        with tempfile.TemporaryDirectory(prefix='rr28-shadow-') as temporary:
            for mutation, expected in [('other', 0), ('entry', 1), ('source', 1), ('missing', 1)]:
                with self.subTest(mutation=mutation):
                    baseline = Path(temporary) / (mutation + '.res')
                    made = godot('tests/rr28/shadow_fixture.gd', '--output', baseline, '--mutation', mutation)
                    self.assertEqual(made.returncode, 0, made.stdout + made.stderr)
                    result = godot('experiments/cutouts/storm_capacitor/rr17_shadow_check.gd', '--baseline', baseline)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    if mutation == 'other':
                        self.assertIn('PASS (2 Capacitor records unchanged)', result.stdout + result.stderr)
                    elif mutation == 'entry':
                        self.assertIn('Capacitor shadow changed:', result.stdout + result.stderr)
                    elif mutation == 'source':
                        self.assertIn('Capacitor shadow source changed:', result.stdout + result.stderr)
                    else:
                        self.assertIn('Missing Capacitor shadow baseline:', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
