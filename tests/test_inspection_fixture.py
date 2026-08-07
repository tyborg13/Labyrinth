from __future__ import annotations

import json
import os
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

    def test_route_depth_survives_the_self_healing_command(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project",
                str(ROOT),
                "--task-id",
                "deep-map-fixture-test",
                "--run-id",
                "deep-map-fixture-test-run",
                "--dry-run",
                "--scenario",
                "start",
                "--route-depth",
                "9",
                "--summary",
                "Inspect the radial map at depth nine.",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--scenario start --route-depth 9", result.stdout)
        self.assertIn("--launch --scenario start --route-depth 9", result.stdout)

    def test_route_depth_rejects_invalid_values_semantically(self) -> None:
        task_id = f"invalid-route-depth-test-{os.getpid()}"
        for value in ["-1", "0", "bananas", "24"]:
            with self.subTest(value=value):
                result = subprocess.run(
                    [
                        sys.executable,
                        str(SCRIPT),
                        "--project",
                        str(ROOT),
                        "--task-id",
                        task_id,
                        "--run-id",
                        f"{task_id}-{value}",
                        "--no-verify",
                        "--scenario",
                        "start",
                        "--route-depth",
                        value,
                    ],
                    cwd=ROOT,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    timeout=60,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("--route-depth", result.stdout + result.stderr)

    def test_route_depth_rejects_non_start_scenarios_semantically(self) -> None:
        task_id = f"non-start-route-depth-test-{os.getpid()}"
        for value in ["-1", "9"]:
            with self.subTest(value=value):
                result = subprocess.run(
                    [
                        sys.executable,
                        str(SCRIPT),
                        "--project",
                        str(ROOT),
                        "--task-id",
                        task_id,
                        "--run-id",
                        f"{task_id}-{value}",
                        "--no-verify",
                        "--scenario",
                        "combat",
                        "--route-depth",
                        value,
                    ],
                    cwd=ROOT,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    timeout=60,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("only available with --scenario start", result.stdout + result.stderr)

    def test_deepest_route_depth_generates_a_verified_room_with_live_moves(self) -> None:
        task_id = f"deepest-route-depth-test-{os.getpid()}"
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project",
                str(ROOT),
                "--task-id",
                task_id,
                "--run-id",
                task_id,
                "--verify",
                "--scenario",
                "start",
                "--route-depth",
                "23",
                "--summary",
                "Verify the deepest non-terminal traversed route fixture.",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
        )
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        payload_line = next(
            line
            for line in result.stdout.splitlines()
            if line.startswith("INSPECTION_FIXTURE_RESULT ")
        )
        payload = json.loads(payload_line.removeprefix("INSPECTION_FIXTURE_RESULT "))
        self.assertEqual(payload["mode"], "room")
        self.assertEqual(payload["current_depth"], 23)
        self.assertGreaterEqual(len(payload["available_moves"]), 2)
        self.assertIn("Inspection fixture verified.", result.stdout)


if __name__ == "__main__":
    unittest.main()
