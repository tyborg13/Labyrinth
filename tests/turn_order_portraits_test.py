#!/usr/bin/env python3
"""Verify every builder-owned portrait against its current shipped source.

Run directly, or discover with: python3 -m unittest discover -s tests -p '*_test.py' -v
The builder owns the key list and crop rules; this test must not duplicate them.
"""

from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
PASS_LINE = "TURN ORDER ASSETS: PASS (verify; all)"


class TurnOrderPortraitTests(unittest.TestCase):
    def test_all_portraits_match_shipped_source_crops(self):
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools/godot_task_runner.py"),
                "--task-id", "por-01",
                "--stream",
                "--",
                "godot", "--headless", "--path", str(ROOT),
                "--script", "tools/build_turn_order_assets.gd",
                "--", "--verify-only",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn(PASS_LINE, result.stdout)
        print(PASS_LINE)


if __name__ == "__main__":
    unittest.main()
