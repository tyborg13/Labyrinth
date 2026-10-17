#!/usr/bin/env python3
"""Exercise Windows tree cancellation natively, or with taskkill semantics on POSIX."""

from __future__ import annotations

from contextlib import nullcontext
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import godot_task_runner
import program_suite_runner

FIXTURE_SLEEP_SECONDS = 60
STARTUP_TIMEOUT_SECONDS = 5
CLEANUP_TIMEOUT_SECONDS = 5
POLL_SECONDS = 0.02


def process_alive(pid):
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
        kernel.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
        kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return False
        try:
            code = wintypes.DWORD()
            return bool(kernel.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


class WindowsTreeCancellationTests(unittest.TestCase):
    def test_windows_cancellation_paths_leave_no_child_or_grandchild(self):
        for entry in (program_suite_runner.stop_wrapper, godot_task_runner.terminate_process_tree):
            with self.subTest(entry=entry.__name__), tempfile.TemporaryDirectory() as directory:
                self.assert_tree_cleanup(entry, Path(directory))

    def assert_tree_cleanup(self, entry, directory):
        pid_file = directory / "pids.json"
        # Ignore SIGCHLD on POSIX so the simulated utility doesn't leave zombies
        # in the process-liveness assertions. Windows uses its real taskkill.
        setup = "import os,signal,subprocess,sys,time,json\nif hasattr(signal,'SIGCHLD'): signal.signal(signal.SIGCHLD,signal.SIG_IGN)\n"
        leaf = "import time;time.sleep(%d)" % FIXTURE_SLEEP_SECONDS
        child = (setup + "p=subprocess.Popen([sys.executable,'-c',%r])\n" % leaf
                 + "open(%r,'w').write(json.dumps([os.getppid(),os.getpid(),p.pid]))\n" % str(pid_file)
                 + "time.sleep(%d)\n" % FIXTURE_SLEEP_SECONDS)
        parent = setup + "p=subprocess.Popen([sys.executable,'-c',%r])\ntime.sleep(%d)\n" % (child, FIXTURE_SLEEP_SECONDS)
        process = subprocess.Popen([sys.executable, "-c", parent], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        pids = []
        try:
            deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
            while time.monotonic() < deadline:
                if pid_file.exists() and pid_file.stat().st_size:
                    pids = json.loads(pid_file.read_text())
                    break
                time.sleep(POLL_SECONDS)
            self.assertEqual(len(pids), 3, "Fixture tree did not start")
            self.assertEqual(pids[0], process.pid)

            def simulated_taskkill(command, **_kwargs):
                # Emulate /T faithfully: without it, only the wrapper dies and
                # the descendant-liveness assertions below fail.
                self.assertEqual(command[:3], ["taskkill", "/PID", str(process.pid)])
                targets = reversed(pids) if "/T" in command else [process.pid]
                for pid in targets:
                    try:
                        os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                return subprocess.CompletedProcess(command, 0, "", "")

            context = nullcontext() if os.name == "nt" else mock.patch.object(
                godot_task_runner.subprocess, "run", side_effect=simulated_taskkill)
            with context:
                entry(process, platform="nt")
            deadline = time.monotonic() + CLEANUP_TIMEOUT_SECONDS
            while any(process_alive(pid) for pid in pids) and time.monotonic() < deadline:
                time.sleep(POLL_SECONDS)
            self.assertEqual([pid for pid in pids if process_alive(pid)], [])
        finally:
            for pid in reversed(pids):
                if process_alive(pid):
                    os.kill(pid, signal.SIGTERM if os.name == "nt" else signal.SIGKILL)
            if process.poll() is None:
                process.kill()
            process.wait(timeout=CLEANUP_TIMEOUT_SECONDS)


if __name__ == "__main__":
    unittest.main()
