"""Live-action expectations and exact native proof inventories for qa-26."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROCESS_TIMEOUT_SECONDS = 300  # Debug-only headless runner budget.


class ProductionProbeTests(unittest.TestCase):
    def test_live_selectors_and_unchanged_authored_clips(self):
        result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'qa-26', '--stream', '--',
                                 'godot', '--headless', '--path', '.', '--script', 'tests/qa26/production_cases_test.gd'],
                                cwd=ROOT, capture_output=True, text=True, timeout=PROCESS_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('QA26 PRODUCTION CASES: PASS', result.stdout)
        for line in result.stdout.splitlines():
            if line.startswith('QA26 '):
                print(line)

    def test_native_contracts_cover_every_live_clip(self):
        cases = [
            ('tests/qa26/ember_hoarder_production_contract.json',
             {'idle', 'move', 'kindle', 'hit', 'death'}, 0),
            ('tests/rr22/production_contract.json',
             {'idle', 'move', 'lob', 'land', 'brace', 'scatter', 'hit', 'death'}, 1),
            ('tests/rr20/production_contract.json',
             {'idle', 'move', 'bolt', 'hit', 'death'}, 0),
        ]
        for path, clips, other_images in cases:
            with self.subTest(contract=path):
                contract = json.loads((ROOT / path).read_text())
                patterns = {item['pattern'] for item in contract['required_images']}
                self.assertEqual(patterns, {'frame_*_' + clip + '.png' for clip in clips} |
                                 ({'prebattle_panel.png'} if other_images else set()))
                self.assertEqual(contract['min_images'], len(clips) * 6 + other_images)
                self.assertEqual(contract['expected_sizes'], ['1920x1080'])
                for item in contract['required_images']:
                    self.assertEqual((item['width'], item['height']), (1920, 1080))
                    if item['pattern'].startswith('frame_'):
                        self.assertEqual(item['min_count'], 6)


if __name__ == '__main__':
    unittest.main()
