#!/usr/bin/env python3
"""Tests for the task-local Godot command wrapper."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools" / "godot_task_runner.py"


class GodotTaskRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.home_root = tempfile.TemporaryDirectory()
        self.addCleanup(self.home_root.cleanup)

    def run_fake_command(self, run_id: str, code: str, *runner_args: str) -> subprocess.CompletedProcess[str]:
        command = [
            sys.executable,
            str(RUNNER),
            "--project",
            str(ROOT),
            "--task-id",
            "runner-test",
            "--run-id",
            run_id,
            "--godot-home-root",
            self.home_root.name,
            *runner_args,
            "--",
            sys.executable,
            "-c",
            code,
        ]
        return subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
        )

    def test_success_preserves_task_namespace(self) -> None:
        result = self.run_fake_command(
            "runner-success",
            "import os\nprint('stdout ok')\nprint(os.environ['LABYRINTH_TASK_ID'])\n",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("stdout ok", result.stdout)
        self.assertIn("runner-success", result.stdout)

    def test_runner_disables_steam_initialization(self) -> None:
        result = self.run_fake_command(
            "runner-steam-disabled",
            "import os\nprint(os.environ['LABYRINTH_DISABLE_STEAM'])\n",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("\n1\n", result.stdout)

    def test_allow_steam_removes_the_forced_disable_flag(self) -> None:
        result = self.run_fake_command(
            "runner-steam-enabled",
            "import os\nprint(os.environ.get('LABYRINTH_DISABLE_STEAM', 'missing'))\n",
            "--allow-steam",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Steam: enabled", result.stdout)
        self.assertIn("\nmissing\n", result.stdout)

    def test_nonzero_exit_is_returned(self) -> None:
        result = self.run_fake_command(
            "runner-nonzero",
            "import sys\nprint('before nonzero')\nsys.exit(7)\n",
        )

        self.assertEqual(result.returncode, 7)
        self.assertIn("before nonzero", result.stdout)

    def test_timeout_terminates_command(self) -> None:
        result = self.run_fake_command(
            "runner-timeout",
            "import time\nprint('started', flush=True)\ntime.sleep(5)\n",
            "--timeout",
            "0.5",
            "--stream",
        )

        self.assertEqual(result.returncode, 124)
        self.assertIn("started", result.stdout)
        self.assertIn("timed out after 0.5 seconds", result.stderr)

    def test_streaming_output_still_triggers_failure_marker_scan(self) -> None:
        result = self.run_fake_command(
            "runner-marker",
            "print('SCRIPT ERROR: fake script failure')\n",
            "--stream",
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("SCRIPT ERROR: fake script failure", result.stdout)
        self.assertIn("reported script or test failures", result.stderr)

    def test_editor_scan_requires_explicit_opt_in(self) -> None:
        command = [
            sys.executable,
            str(RUNNER),
            "--project",
            str(ROOT),
            "--task-id",
            "runner-test",
            "--godot-home-root",
            self.home_root.name,
            "--",
            "godot",
            "--headless",
            "--editor",
            "--quit",
        ]
        result = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing Godot --editor scan", result.stderr)
        self.assertIn(".import/.uid sidecars", result.stderr)


if __name__ == "__main__":
    unittest.main()
