"""Own a Windows descendant tree before allowing its first thread to execute.

The job handle is non-inheritable. Closing it (including owner process death)
kills descendants even after the original process exits. No breakaway flags
are set; nested scheduler/task-runner jobs require Windows 8 or later.
"""

from __future__ import annotations

import ctypes
import os
import subprocess


CREATE_SUSPENDED = 0x00000004
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9
TH32CS_SNAPTHREAD = 0x00000004
THREAD_SUSPEND_RESUME = 0x00000002
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
DWORD_ERROR = 0xFFFFFFFF

# Fixed-width Windows types also make the API boundary testable on POSIX,
# where ctypes.c_ulong (and wintypes.DWORD) may have a different width.
DWORD = ctypes.c_uint32
HANDLE = ctypes.c_void_p
SIZE_T = ctypes.c_size_t


class BasicLimitInformation(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_int64), ("PerJobUserTimeLimit", ctypes.c_int64),
        ("LimitFlags", DWORD), ("MinimumWorkingSetSize", SIZE_T),
        ("MaximumWorkingSetSize", SIZE_T), ("ActiveProcessLimit", DWORD),
        ("Affinity", SIZE_T), ("PriorityClass", DWORD), ("SchedulingClass", DWORD),
    ]


class ExtendedLimitInformation(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", BasicLimitInformation),
        ("IoInfo", ctypes.c_uint64 * 6),
        ("ProcessMemoryLimit", SIZE_T), ("JobMemoryLimit", SIZE_T),
        ("PeakProcessMemoryUsed", SIZE_T), ("PeakJobMemoryUsed", SIZE_T),
    ]


class ThreadEntry(ctypes.Structure):
    _fields_ = [
        ("dwSize", DWORD), ("cntUsage", DWORD), ("th32ThreadID", DWORD),
        ("th32OwnerProcessID", DWORD), ("tpBasePri", ctypes.c_int32),
        ("tpDeltaPri", ctypes.c_int32), ("dwFlags", DWORD),
    ]


def load_kernel():
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    signatures = {
        "CreateJobObjectW": (HANDLE, [HANDLE, ctypes.c_wchar_p]),
        "SetInformationJobObject": (ctypes.c_int, [HANDLE, ctypes.c_int, HANDLE, DWORD]),
        "AssignProcessToJobObject": (ctypes.c_int, [HANDLE, HANDLE]),
        "CloseHandle": (ctypes.c_int, [HANDLE]),
        "CreateToolhelp32Snapshot": (HANDLE, [DWORD, DWORD]),
        "Thread32First": (ctypes.c_int, [HANDLE, ctypes.POINTER(ThreadEntry)]),
        "Thread32Next": (ctypes.c_int, [HANDLE, ctypes.POINTER(ThreadEntry)]),
        "OpenThread": (HANDLE, [DWORD, ctypes.c_int, DWORD]),
        "ResumeThread": (DWORD, [HANDLE]),
    }
    for name, (result, arguments) in signatures.items():
        function = getattr(kernel, name)
        function.restype = result
        function.argtypes = arguments
    return kernel


class WindowsJob:
    def __init__(self, kernel=None):
        self.kernel = load_kernel() if kernel is None else kernel
        self.handle = self.kernel.CreateJobObjectW(None, None)
        if not self.handle:
            raise OSError("CreateJobObjectW failed")
        limits = ExtendedLimitInformation()
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not self.kernel.SetInformationJobObject(
                self.handle, JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
                ctypes.byref(limits), ctypes.sizeof(limits)):
            self.close()
            raise OSError("SetInformationJobObject(KILL_ON_JOB_CLOSE) failed")

    def assign(self, process):
        if not self.kernel.AssignProcessToJobObject(self.handle, int(process._handle)):
            raise OSError("AssignProcessToJobObject failed")

    def resume(self, process):
        # Popen closes the primary thread handle. Find that thread while it is
        # still suspended; assignment must precede its first user instruction.
        snapshot = self.kernel.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
        if snapshot in (None, INVALID_HANDLE_VALUE):
            raise OSError("CreateToolhelp32Snapshot failed")
        try:
            entry = ThreadEntry()
            entry.dwSize = ctypes.sizeof(entry)
            found = self.kernel.Thread32First(snapshot, ctypes.byref(entry))
            while found:
                if entry.th32OwnerProcessID == process.pid:
                    thread = self.kernel.OpenThread(THREAD_SUSPEND_RESUME, False, entry.th32ThreadID)
                    if not thread:
                        raise OSError("OpenThread failed")
                    try:
                        if self.kernel.ResumeThread(thread) == DWORD_ERROR:
                            raise OSError("ResumeThread failed")
                    finally:
                        self.kernel.CloseHandle(thread)
                    return
                entry.dwSize = ctypes.sizeof(entry)
                found = self.kernel.Thread32Next(snapshot, ctypes.byref(entry))
            raise OSError("Suspended process thread not found")
        finally:
            self.kernel.CloseHandle(snapshot)

    def close(self):
        if self.handle is not None:
            if not self.kernel.CloseHandle(self.handle):
                raise OSError("CloseHandle(job) failed")
            self.handle = None


def spawn_owned_process(command, *, platform=None, job_factory=None, **kwargs):
    if (platform or os.name) != "nt":
        return subprocess.Popen(command, **kwargs)
    job = (WindowsJob if job_factory is None else job_factory)()
    process = None
    try:
        kwargs["creationflags"] = kwargs.get("creationflags", 0) | CREATE_SUSPENDED
        process = subprocess.Popen(command, **kwargs)
        job.assign(process)
        process._labyrinth_windows_job = job
        job.resume(process)
        return process
    except BaseException:
        # Fail closed: an assignment error must never release an unowned child.
        if process is not None:
            process.kill()
            process.wait()
        job.close()
        raise


def close_owned_job(process):
    job = getattr(process, "_labyrinth_windows_job", None)
    if job is None:
        return False
    job.close()
    return True
