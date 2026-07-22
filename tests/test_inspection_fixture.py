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

    def test_skill_progression_options_survive_the_self_healing_command(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project",
                str(ROOT),
                "--task-id",
                "skill-fixture-test",
                "--run-id",
                "skill-fixture-test-run",
                "--dry-run",
                "--scenario",
                "character",
                "--level",
                "3",
                "--skills",
                "quick_wits,rehearsed_escape",
                "--moltshards",
                "2",
                "--summary",
                "Inspect learned skills.",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        expected_options = (
            "--scenario character --level 3 "
            "--skills quick_wits,rehearsed_escape --moltshards 2"
        )
        self.assertIn(expected_options, result.stdout)
        self.assertIn("--launch " + expected_options, result.stdout)

    def test_banked_skill_points_survive_the_self_healing_command(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project",
                str(ROOT),
                "--task-id",
                "banked-skill-fixture-test",
                "--run-id",
                "banked-skill-fixture-test-run",
                "--dry-run",
                "--scenario",
                "character",
                "--level",
                "5",
                "--skills",
                "quick_wits,rehearsed_escape",
                "--moltshards",
                "1",
                "--summary",
                "Inspect two learned and two unspent skill points.",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        expected_options = (
            "--scenario character --level 5 "
            "--skills quick_wits,rehearsed_escape --moltshards 1"
        )
        self.assertIn(expected_options, result.stdout)
        self.assertIn("--launch " + expected_options, result.stdout)


if __name__ == "__main__":
    unittest.main()
