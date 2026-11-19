#!/usr/bin/env python3
"""Verify terminal authority, recovery-file deletion, read errors and bounded quit."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import time

from integrity_proof import environment

PROJECT = Path(__file__).resolve().parents[2]
PROBE = Path(__file__).with_name("perf147_probe.gd")
SAVE = "current_run.save"
TERMINALS = ("victory-none", "victory-chosen", "defeat-none", "defeat-chosen",
             "abandoned", "embrace", "victory-pending", "defeat-pending")
QUIT_ROUTES = ("save-and-quit", "window-close", "steam-shutdown")
SYNC_ROUTE = "sync-barrier"
CASES = ("terminal", "blocked-backup", "read-failure", *QUIT_ROUTES)
QUIT_OUTER_TIMEOUT = 25
SAVE_DEADLINE = 8.0
CLEANUP_ALLOWANCE = 2.5
KILLED = 0 if os.name == "nt" else 256 - signal.SIGKILL
RELAUNCH_BACKUP_SEED = "seed=144 saved_mode=room"
READ_FIXED = "PERF147 READ unavailable=true rotation_rejected=true files_unchanged=true"
READ_BASE = "PERF147 READ unavailable=false rotation_rejected=false files_unchanged=false selected_seed=144"


def _run(project: Path, output: Path, case: str, mode: str = "", env: dict | None = None) -> tuple[int, str]:
    command = [
        sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", "perf-147",
        "--timeout", str(QUIT_OUTER_TIMEOUT if case in (*QUIT_ROUTES, SYNC_ROUTE) else 90),
        "--stream", "--", "godot", "--headless", "--path", str(project), "--script",
        str(PROBE), "--", f"--case={case}", f"--output={output}", f"--mode={mode}",
    ]
    log = output / f"{case}.log"
    with log.open("w") as stream:
        code = subprocess.run(command, env=env or environment(), stdout=stream, stderr=subprocess.STDOUT).returncode
    contents = log.read_text()
    for line in contents.splitlines():
        if line.startswith("PERF147 "):
            print(line, flush=True)
    return code, contents


def _prepare(project: Path, output: Path, mode: str = "room") -> bool:
    output.mkdir(parents=True)
    code, log = _run(project, output, "prepare", mode)
    return code == 0 and f"PERF147 PREPARED mode={mode}" in log


def _terminal(project: Path, output: Path, control: bool) -> bool:
    results = []
    for mode in TERMINALS:
        folder = output / mode
        if not _prepare(project, folder, mode):
            results.append(False)
            continue
        code, log = _run(project, folder, "relaunch", mode)
        if control and not mode.endswith("-pending"):
            results.append(code == 1 and "continue=true " + RELAUNCH_BACKUP_SEED in log)
        else:
            results.append(code == 0)
    print(f"PERF147 TERMINAL MODES: {sum(results)}/{len(results)} expected outcomes", flush=True)
    return all(results)


@contextmanager
def _block_delete(path: Path):
    if sys.platform == "darwin":
        flags = path.stat().st_flags
        os.chflags(path, flags | stat.UF_IMMUTABLE)
        try:
            yield
        finally:
            os.chflags(path, flags)
    elif os.name == "nt":
        import ctypes
        from ctypes import wintypes

        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [
            wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
            wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE,
        ]
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        generic_read, share_read, open_existing, normal_attributes = 0x80000000, 1, 3, 0x80
        handle = kernel.CreateFileW(str(path), generic_read, share_read,
                                    None, open_existing, normal_attributes, None)
        if handle == ctypes.c_void_p(-1).value:
            raise OSError(ctypes.get_last_error(), "could not lock backup against deletion")
        try:
            yield
        finally:
            kernel.CloseHandle(handle)
    else:
        raise OSError("The delete-denial fixture requires macOS or Windows")


def _blocked_backup(project: Path, output: Path, control: bool) -> bool:
    if not _prepare(project, output, "abandoned"):
        return False
    with _block_delete(output / (SAVE + ".backup")):
        code, log = _run(project, output, "clear")
    resume_code, resume_log = _run(project, output, "relaunch", "abandoned")
    if control:
        return (code == 1 and "reported_failure=false live_unchanged=false backup_unchanged=true" in log
                and resume_code == 1 and RELAUNCH_BACKUP_SEED in resume_log)
    return code == 0 and "reported_failure=true live_unchanged=true backup_unchanged=true" in log and resume_code == 0


def _with_read_fault(project: Path, overlay: Path, control: bool) -> None:
    """Inject a short read after a real open in a disposable project overlay."""
    overlay.mkdir()
    for directory in project.iterdir():
        if directory.name in {".git", "scripts", "output"}:
            continue
        (overlay / directory.name).symlink_to(directory, target_is_directory=directory.is_dir())
    (overlay / "scripts").mkdir()
    for path in (project / "scripts").iterdir():
        dest = overlay / "scripts" / path.name
        if path.name != "progression_store.gd":
            dest.symlink_to(path, target_is_directory=path.is_dir())
            continue
        source = path.read_text()
        start = source.index("static func _inspect_run_file(")
        needle = "\tvar raw: Variant = file.get_var(false)" if control else "\tvar payload := file.get_buffer(length)\n\tread_error = file.get_error()"
        found = source.index(needle, start) + len(needle)
        error = "\t\traw = null" if control else "\t\tpayload = PackedByteArray()\n\t\tread_error = ERR_FILE_CANT_READ"
        injection = '\n\tif path == OS.get_environment("LABYRINTH_PROOF_READ_FAIL"):\n\t\tprint("PERF147 READ_FAULT open=", file.is_open())\n' + error
        dest.write_text(source[:found] + injection + source[found:])


def _read_failure(project: Path, output: Path, control: bool) -> bool:
    if not _prepare(project, output):
        return False
    overlay = output / "isolated-read-fault"
    _with_read_fault(project, overlay, control)
    code, log = _run(overlay, output, "read-failure", env={
        **environment(), "LABYRINTH_PROOF_READ_FAIL": str(output / SAVE),
    })
    if control:
        return code == 1 and "PERF147 READ_FAULT open=true" in log and READ_BASE in log
    resume_code, resume_log = _run(project, output, "relaunch", "room")
    return (code == 0 and "PERF147 READ_FAULT open=true" in log and READ_FIXED in log
            and resume_code == 0 and "continue=true seed=83 saved_mode=room" in resume_log)


def _quit(project: Path, output: Path, route: str, control: bool) -> bool:
    if not _prepare(project, output):
        return False
    code, log = _run(project, output, route)
    exited = time.time()
    request = output / "request.json"
    if not request.exists():
        return False
    elapsed = exited - json.loads(request.read_text())["unix_seconds"]
    digest = (output / "stalled.sha256").read_text().strip()
    match = hashlib.sha256((output / SAVE).read_bytes()).hexdigest() == digest
    pumped = "PERF147 QUIT remained_responsive=true" in log
    print(f"PERF147 QUIT {route} exit_sec={elapsed:.3f} runner={code} "
          f"pumped={str(pumped).lower()} live_unchanged={str(match).lower()}", flush=True)
    if control:
        if route in ("save-and-quit", SYNC_ROUTE):
            return code == 124 and not pumped and elapsed > SAVE_DEADLINE + CLEANUP_ALLOWANCE and match
        return code == KILLED and not pumped and match
    responsiveness_ok = pumped if route != SYNC_ROUTE else "Persistence did not settle within the save deadline." in log
    if code != KILLED or not responsiveness_ok or not match or not SAVE_DEADLINE <= elapsed <= SAVE_DEADLINE + CLEANUP_ALLOWANCE:
        return False
    resume_code, _ = _run(project, output, "relaunch", "room")
    return resume_code == 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", choices=(*CASES, SYNC_ROUTE), action="append")
    parser.add_argument("--control", action="store_true", help="Expect the original perf-146 failures.")
    args = parser.parse_args()
    project = args.project.resolve()
    results = []
    for case in args.case or CASES:
        output = args.output.resolve() / case
        if case == "terminal":
            passed = _terminal(project, output, args.control)
        elif case == "blocked-backup":
            passed = _blocked_backup(project, output, args.control)
        elif case == "read-failure":
            passed = _read_failure(project, output, args.control)
        else:
            passed = _quit(project, output, case, args.control)
        status = "REPRODUCED" if args.control else "PASS"
        print(f"PERF147 {case}: {status if passed else 'FAIL'}", flush=True)
        results.append(passed)
    print(f"PERF147 PROOF: {sum(results)}/{len(results)} expected outcomes", flush=True)
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
