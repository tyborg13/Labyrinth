from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "inspection_fixture.py"


class InspectionFixtureTests(unittest.TestCase):
    def test_handoff_command_is_self_healing_and_verified(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project",
                str(ROOT),
                "--task-id",
                "fixture-test",
                "--run-id",
                "fixture-test-run",
                "--dry-run",
                "--scenario",
                "reward",
                "--summary",
                "Inspect reward choice.",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("tools/inspection_fixture_verify.gd", result.stdout)
        self.assertIn("--launch --scenario reward", result.stdout)
        self.assertIn("regenerates and verifies the pre-action state first", result.stdout)

    def test_self_healing_launch_can_enable_steam_for_interactive_inspection(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project",
                str(ROOT),
                "--task-id",
                "steam-fixture-test",
                "--run-id",
                "steam-fixture-test-run",
                "--allow-steam",
                "--dry-run",
                "--scenario",
                "start",
                "--summary",
                "Inspect Steam integration.",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--allow-steam --launch --scenario start", result.stdout)


if __name__ == "__main__":
    unittest.main()
