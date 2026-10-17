#!/usr/bin/env python3
"""Exercise launch-owned Windows jobs natively or through a Win32 simulation."""

from __future__ import annotations

from contextlib import nullcontext
import ctypes
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
import windows_process_job as jobs

FIXTURE_SLEEP_SECONDS = 60
STARTUP_TIMEOUT_SECONDS = 5
CLEANUP_TIMEOUT_SECONDS = 5
POLL_SECONDS = 0.02
SIMULATED_JOB_HANDLE = 100
SIMULATED_SNAPSHOT_HANDLE = 101
SIMULATED_THREAD_HANDLE = 102


def process_alive(pid):
    if os.name == "nt":
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


def kill_pids(pids):
    for pid in reversed(pids):
        if not process_alive(pid):
            continue
        try:
            os.kill(pid, signal.SIGTERM if os.name == "nt" else signal.SIGKILL)
        except OSError:
            # Windows TerminateProcess can report ERROR_ACCESS_DENIED for an
            # exited process whose handle is still retained. Recheck liveness
            # after any exit race; never suppress an error for a live process.
            if process_alive(pid):
                raise


def stop_fixture_process(process):
    if process is None:
        return
    try:
        if process.poll() is None:
            try:
                process.kill()
            except OSError:
                if process.poll() is None:
                    raise
    finally:
        process.wait(timeout=CLEANUP_TIMEOUT_SECONDS)


def cleanup_fixture(process, pids, unrelated):
    try:
        try:
            if process is not None:
                jobs.close_owned_job(process)
        finally:
            try:
                kill_pids(pids)
            finally:
                stop_fixture_process(process)
    finally:
        # An owned-tree cleanup error must not strand the independent sleeper.
        stop_fixture_process(unrelated)


class SimulatedKernel:
    """Simulate the Win32 boundary, retaining membership after the root exits.

    The fixture is gated until ResumeThread. Its PID file represents the OS's
    inherited job membership, independent of whether its root is still alive.
    The implementation above this boundary is the actual ctypes job code.
    """
    def __init__(self, case, gate, pid_file):
        self.case, self.gate, self.pid_file = case, gate, pid_file
        self.events = []
        self.pid = None
        self.limit_flags = 0
        self.creation_flags = 0

    def CreateJobObjectW(self, security, name):
        self.case.assertIsNone(security)  # Non-inheritable owner handle.
        self.case.assertIsNone(name)
        self.events.append("create")
        return SIMULATED_JOB_HANDLE

    def SetInformationJobObject(self, handle, kind, pointer, size):
        self.case.assertEqual(handle, SIMULATED_JOB_HANDLE)
        self.case.assertEqual(kind, jobs.JOB_OBJECT_EXTENDED_LIMIT_INFORMATION)
        limits = ctypes.cast(pointer, ctypes.POINTER(jobs.ExtendedLimitInformation)).contents
        self.limit_flags = limits.BasicLimitInformation.LimitFlags
        self.case.assertEqual(size, ctypes.sizeof(jobs.ExtendedLimitInformation))
        self.events.append("set-limits")
        return True

    def AssignProcessToJobObject(self, handle, process_handle):
        self.case.assertEqual(handle, SIMULATED_JOB_HANDLE)
        self.case.assertFalse(self.gate.exists(), "Child must not execute before assignment")
        self.pid = process_handle
        self.events.append("assign")
        return True

    def CreateToolhelp32Snapshot(self, flags, pid):
        self.case.assertEqual((flags, pid), (jobs.TH32CS_SNAPTHREAD, 0))
        return SIMULATED_SNAPSHOT_HANDLE

    def Thread32First(self, snapshot, pointer):
        self.case.assertEqual(snapshot, SIMULATED_SNAPSHOT_HANDLE)
        # Include an unrelated thread to exercise PID filtering and Thread32Next.
        entry = ctypes.cast(pointer, ctypes.POINTER(jobs.ThreadEntry)).contents
        entry.th32OwnerProcessID = self.pid + 1
        return True

    def Thread32Next(self, snapshot, pointer):
        entry = ctypes.cast(pointer, ctypes.POINTER(jobs.ThreadEntry)).contents
        entry.th32OwnerProcessID = self.pid
        entry.th32ThreadID = self.pid
        return True

    def OpenThread(self, access, inherit, thread):
        self.case.assertEqual((access, inherit, thread), (jobs.THREAD_SUSPEND_RESUME, False, self.pid))
        return SIMULATED_THREAD_HANDLE

    def ResumeThread(self, thread):
        self.case.assertEqual(thread, SIMULATED_THREAD_HANDLE)
        self.case.assertEqual(self.events, ["create", "set-limits", "launch-suspended", "assign"])
        self.events.append("resume")
        self.gate.touch()
        return 1

    def CloseHandle(self, handle):
        if handle == SIMULATED_JOB_HANDLE:
            self.events.append("close-job")
            if self.limit_flags & 0x2000:
                members = json.loads(self.pid_file.read_text()) if self.pid_file.exists() else [self.pid]
                kill_pids([pid for pid in members if pid is not None])
        else:
            self.case.assertIn(handle, (SIMULATED_THREAD_HANDLE, SIMULATED_SNAPSHOT_HANDLE))
        return True


class WindowsTreeCancellationTests(unittest.TestCase):
    def test_win32_flag_values_are_independent_of_implementation(self):
        self.assertEqual(jobs.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, 0x2000)
        self.assertEqual(jobs.CREATE_SUSPENDED, 0x4)

    def test_cleanup_skips_dead_pids_and_accepts_exit_races(self):
        denied = PermissionError("terminated process retains its handle")
        denied.winerror = 5  # ERROR_ACCESS_DENIED
        for error in (ProcessLookupError(), denied):
            with self.subTest(error=type(error).__name__), \
                    mock.patch(__name__ + ".process_alive", side_effect=[False, True, False]), \
                    mock.patch.object(os, "kill", side_effect=error) as kill:
                kill_pids([123, 456])
                kill.assert_called_once()
        with mock.patch(__name__ + ".process_alive", return_value=True), \
                mock.patch.object(os, "kill", side_effect=denied), self.assertRaises(PermissionError):
            kill_pids([123])

    def test_unrelated_sleeper_is_reaped_even_if_owned_cleanup_raises(self):
        unrelated = subprocess.Popen([sys.executable, "-c", "import time;time.sleep(%d)" % FIXTURE_SLEEP_SECONDS])
        try:
            with mock.patch(__name__ + ".kill_pids", side_effect=OSError("fixture cleanup error")):
                with self.assertRaisesRegex(OSError, "fixture cleanup error"):
                    cleanup_fixture(None, [], unrelated)
            self.assertIsNotNone(unrelated.poll())
            self.assertFalse(process_alive(unrelated.pid))
        finally:
            stop_fixture_process(unrelated)

    def test_retained_handle_exit_race_is_reaped(self):
        denied = PermissionError("terminated process retains its handle")
        denied.winerror = 5
        process = mock.Mock()
        process.poll.side_effect = [None, 0]
        process.kill.side_effect = denied
        stop_fixture_process(process)
        process.wait.assert_called_once_with(timeout=CLEANUP_TIMEOUT_SECONDS)

    def test_simulated_job_close_honours_recorded_limit_flags(self):
        with tempfile.TemporaryDirectory() as directory:
            kernel = SimulatedKernel(self, Path(directory) / "gate", Path(directory) / "pids")
            kernel.pid = 123
            with mock.patch(__name__ + ".kill_pids") as kill:
                kernel.CloseHandle(SIMULATED_JOB_HANDLE)
                kill.assert_not_called()
                kernel.limit_flags = 0x2000
                kernel.CloseHandle(SIMULATED_JOB_HANDLE)
                kill.assert_called_once_with([123])

    def test_assignment_failure_never_resumes_an_unowned_child(self):
        process = mock.Mock(pid=123, _handle=456)
        job = mock.Mock()
        job.assign.side_effect = OSError("assignment denied")
        with mock.patch.object(jobs.subprocess, "Popen", return_value=process) as launch:
            with self.assertRaisesRegex(OSError, "assignment denied"):
                jobs.spawn_owned_process(["unused"], platform="nt", job_factory=lambda: job)
        self.assertEqual(launch.call_args.kwargs["creationflags"], 0x4)
        job.resume.assert_not_called()
        process.kill.assert_called_once_with()
        process.wait.assert_called_once_with()
        job.close.assert_called_once_with()

    def test_launch_owned_jobs_clean_alive_and_exited_roots(self):
        for entry in (program_suite_runner.stop_wrapper, godot_task_runner.terminate_process_tree):
            for root_exits in (False, True):
                with self.subTest(entry=entry.__name__, root_exits=root_exits), tempfile.TemporaryDirectory() as directory:
                    self.assert_tree_cleanup(entry, Path(directory), root_exits, owned=True)

    def test_taskkill_fallback_requires_owned_pid_tree_and_force_and_spares_unrelated(self):
        for entry in (program_suite_runner.stop_wrapper, godot_task_runner.terminate_process_tree):
            with self.subTest(entry=entry.__name__), tempfile.TemporaryDirectory() as directory:
                self.assert_tree_cleanup(entry, Path(directory), False, owned=False)

    def assert_tree_cleanup(self, entry, directory, root_exits, owned):
        pid_file, gate = directory / "pids.json", directory / "resume"
        # SIGCHLD=IGN avoids zombies in the POSIX liveness simulation.
        setup = "import os,signal,subprocess,sys,time,json\nif hasattr(signal,'SIGCHLD'): signal.signal(signal.SIGCHLD,signal.SIG_IGN)\n"
        leaf = "import time;time.sleep(%d)" % FIXTURE_SLEEP_SECONDS
        child = (setup + "p=subprocess.Popen([sys.executable,'-c',%r])\n" % leaf
                 + "open(%r,'w').write(json.dumps([os.getppid(),os.getpid(),p.pid]))\n" % str(pid_file)
                 + "time.sleep(%d)\n" % FIXTURE_SLEEP_SECONDS)
        parent = setup
        if owned and os.name != "nt":
            parent += "while not os.path.exists(%r): time.sleep(%r)\n" % (str(gate), POLL_SECONDS)
        parent += "p=subprocess.Popen([sys.executable,'-c',%r])\n" % child
        if root_exits:
            parent += "while not os.path.exists(%r) or not os.path.getsize(%r): time.sleep(%r)\n" % (str(pid_file), str(pid_file), POLL_SECONDS)
        else:
            parent += "time.sleep(%d)\n" % FIXTURE_SLEEP_SECONDS
        command = [sys.executable, "-c", parent]
        real_popen = subprocess.Popen
        unrelated = None
        kernel = None

        def simulated_popen(command, **kwargs):
            kernel.creation_flags = kwargs.pop("creationflags")
            suspended = bool(kernel.creation_flags & 0x4)
            kernel.events.append("launch-suspended" if suspended else "launch-running")
            if not suspended:
                gate.touch()  # CREATE_SUSPENDED=0 really allows early execution.
            self.assertEqual(kernel.creation_flags, 0x4)
            process = real_popen(command, **kwargs)
            process._handle = process.pid
            return process

        pids = []
        process = None
        try:
            unrelated = real_popen([sys.executable, "-c", leaf])
            kernel = SimulatedKernel(self, gate, pid_file)
            kwargs = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if not owned:
                process = real_popen(command, **kwargs)
            elif os.name == "nt":
                process = jobs.spawn_owned_process(command, **kwargs)
            else:
                with mock.patch.object(jobs.subprocess, "Popen", side_effect=simulated_popen):
                    process = jobs.spawn_owned_process(command, platform="nt",
                                                       job_factory=lambda: jobs.WindowsJob(kernel), **kwargs)
            deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
            while time.monotonic() < deadline:
                if pid_file.exists() and pid_file.stat().st_size:
                    pids = json.loads(pid_file.read_text())
                    break
                time.sleep(POLL_SECONDS)
            self.assertEqual(len(pids), 3, "Fixture tree did not start")
            self.assertEqual(pids[0], process.pid)
            if root_exits:
                self.assertEqual(process.wait(timeout=STARTUP_TIMEOUT_SECONDS), 0)
            else:
                self.assertIsNone(process.poll())

            def simulated_taskkill(command, **_kwargs):
                # No substring/prefix checks: losing /F, /T or the owned PID
                # must fail before this simulation sends any signal.
                self.assertEqual(command, ["taskkill", "/PID", str(process.pid), "/T", "/F"])
                kill_pids(pids)
                return subprocess.CompletedProcess(command, 0, "", "")

            context = nullcontext() if os.name == "nt" else mock.patch.object(
                godot_task_runner.subprocess, "run", side_effect=simulated_taskkill)
            with context:
                entry(process, platform="nt")
            deadline = time.monotonic() + CLEANUP_TIMEOUT_SECONDS
            while any(process_alive(pid) for pid in pids) and time.monotonic() < deadline:
                time.sleep(POLL_SECONDS)
            self.assertEqual([pid for pid in pids if process_alive(pid)], [])
            self.assertIsNone(unrelated.poll(), "Cancellation must spare unrelated processes")
            if owned and os.name != "nt":
                self.assertEqual(kernel.events[-1], "close-job")
                entry(process, platform="nt")  # Idempotent after root/job exit.
                self.assertEqual(kernel.events.count("close-job"), 1)
        finally:
            cleanup_fixture(process, pids, unrelated)


if __name__ == "__main__":
    unittest.main()
