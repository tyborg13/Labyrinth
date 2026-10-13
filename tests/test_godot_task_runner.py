#!/usr/bin/env python3
"""Tests for the task-local Godot command wrapper."""

from __future__ import annotations

import os
import signal
import shutil
import time
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools" / "godot_task_runner.py"
FIXTURE_SLEEP_SECONDS = 60
STARTUP_TIMEOUT_SECONDS = 5
WATCHDOG_STARTUP_WAIT_SECONDS = 0.1
NORMAL_EXIT_WAIT_SECONDS = 0.2
CLEANUP_TIMEOUT_SECONDS = 4
RUNNER_COMMUNICATE_TIMEOUT_SECONDS = 6
PROCESS_POLL_SECONDS = 0.01
LIVENESS_POLL_SECONDS = 0.05
INTERRUPTED_COMMAND_TIMEOUT_SECONDS = 0.5


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

    @unittest.skipIf(os.name == "nt", "POSIX process group regression")
    def test_runner_signals_leave_no_child_or_grandchild(self) -> None:
        for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP, signal.SIGKILL):
            with self.subTest(signum=signum):
                self._assert_process_group_cleanup(signum)

    @unittest.skipIf(os.name == "nt", "POSIX process group regression")
    def test_timeout_kills_a_term_ignoring_descendant(self) -> None:
        self._assert_process_group_cleanup(None, timeout=True)

    @unittest.skipIf(os.name == "nt", "POSIX process group regression")
    def test_normal_exit_cleans_up_descendants_holding_output_pipes(self) -> None:
        self._assert_process_group_cleanup(None, normal_exit=True)

    @unittest.skipIf(os.name == "nt" or shutil.which("godot") is None, "Needs POSIX Godot")
    def test_killing_runner_mid_godot_test_leaves_no_godot_child(self) -> None:
        self._assert_process_group_cleanup(signal.SIGTERM, godot=True)

    def _assert_process_group_cleanup(self, signum, timeout=False, normal_exit=False, godot=False) -> None:
        pid_path = Path(self.home_root.name) / "pids.txt"
        pid_path.unlink(missing_ok=True)
        grandchild = f"import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep({FIXTURE_SLEEP_SECONDS})"
        code = (
            "import os, subprocess, sys, time\n"
            f"child = subprocess.Popen([sys.executable, '-c', {grandchild!r}])\n"
            f"open({str(pid_path)!r}, 'w').write(str(os.getpid()) + ' ' + str(child.pid))\n"
            + (f"time.sleep({NORMAL_EXIT_WAIT_SECONDS})\n" if normal_exit else f"time.sleep({FIXTURE_SLEEP_SECONDS})\n")
        )
        command = [sys.executable, str(RUNNER), "--project", str(ROOT), "--task-id", "qa-01",
                   "--godot-home-root", self.home_root.name, "--timeout", str(INTERRUPTED_COMMAND_TIMEOUT_SECONDS) if timeout else "0",
                   "--stream", "--"]
        if godot:
            fixture = Path(self.home_root.name) / "runner_wait.gd"
            fixture.write_text('extends SceneTree\nfunc _initialize() -> void:\n\tvar file := FileAccess.open("' + str(pid_path) + '", FileAccess.WRITE)\n\tfile.store_string(str(OS.get_process_id()))\n\tfile.close()\n')
            command.extend(["godot", "--headless", "--path", str(ROOT), "--script", str(fixture)])
        else:
            command.extend([sys.executable, "-c", code])
        runner = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        pids = []
        try:
            deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
            while not pid_path.exists() and time.monotonic() < deadline:
                time.sleep(PROCESS_POLL_SECONDS)
            self.assertTrue(pid_path.exists(), "Child did not start")
            pids = [int(pid) for pid in pid_path.read_text().split()]
            # The parent-death watcher is installed before the runner starts its readers.
            time.sleep(WATCHDOG_STARTUP_WAIT_SECONDS)
            if signum is not None:
                runner.send_signal(signum)
            stdout, stderr = runner.communicate(timeout=RUNNER_COMMUNICATE_TIMEOUT_SECONDS)
            expected = -signal.SIGKILL if signum == signal.SIGKILL else 128 + signum if signum else 124 if timeout else 0
            self.assertEqual(runner.returncode, expected, stdout + stderr)
            deadline = time.monotonic() + CLEANUP_TIMEOUT_SECONDS
            living = pids
            while living and time.monotonic() < deadline:
                living = []
                for pid in pids:
                    try:
                        os.kill(pid, 0)
                    except ProcessLookupError:
                        continue
                    living.append(pid)
                if living:
                    time.sleep(LIVENESS_POLL_SECONDS)
            self.assertEqual(living, [], "Runner left live children: " + str(living))
        finally:
            if runner.poll() is None:
                runner.kill()
                runner.communicate(timeout=RUNNER_COMMUNICATE_TIMEOUT_SECONDS)
            for pid in pids:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

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
