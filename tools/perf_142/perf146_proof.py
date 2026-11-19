#!/usr/bin/env python3
"""Run the perf-146 regressions against the worktree or the perf-145 control."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

from integrity_proof import environment

PROJECT = Path(__file__).resolve().parents[2]
PROBES = Path(__file__).resolve().parent
TASK = "perf-146"
CASES = ("atomic", "continue-missing", "reveal-close", "slow-quit", "legacy")
CRASH_CASE = "crash-between-renames"
FEEDBACK_CASES = ("corrupt-live", "wrong-build-live", "unavailable-live", "stalled-quit")
MODE_CASE = "resume-modes"
MODES = ("room", "pre_battle", "combat", "reward", "campfire", "treasure", "graftwright",
         "event", "event-result", "escape", "victory", "defeat")
QUIT_MODES = ("event", "escape")
WINDOWED_CASES = ("continue-missing", "reveal-close", "slow-quit", MODE_CASE)
LEGACY_REFS = ("987546fd8", "047c5848f")
ATOMIC = "PERF146 ATOMIC live_unchanged={live} recovered=true"
CONTINUE = "PERF146 CONTINUE dialog={dialog} replacement={replacement} original_unchanged=true"
RESUMED = "PERF146 RESUME enabled=true resumed=true same_run=true byte_complete=true receipt={receipt} sha256="
REJECTED = "PERF146 RESUME enabled=true resumed=false same_run=false byte_complete=true"
FINAL = re.compile(r"PERF146 FINALIZE usec=(\d+)")
SLOW_WRITE_USEC = 4_500_000
MAX_WAIT_INJECTION_USEC = 500_000
SAVE_DEADLINE_SECONDS = 8.0
CLEANUP_ALLOWANCE_SECONDS = 2.5
STALL_PROBE_TIMEOUT_SECONDS = 45
SHARE_LOCK_POLL_SECONDS = 0.01


def _run(project: Path, directory: Path, probe: str, arguments: list[str],
         display: str = "") -> tuple[int, str]:
    log_path = directory / "godot.log"
    share_lock = os.name == "nt" and "--case=unavailable-live" in arguments
    if display:
        contract = "perf146_resume_visual_proof.json" if probe == "perf146_mode_probe.gd" else "perf146_visual_proof.json"
        command = [
            sys.executable, str(PROJECT / "tools/visual_probe_runner.py"), "--project", str(project),
            "--task-id", TASK, "--no-headless", "--display-driver", display, "--audio-driver", "Dummy",
            "--expect-size", "1920x1080", "--proof-contract", str(PROBES / contract),
            "--result-manifest", str(directory / "images.json"), str(PROBES / probe), "--",
            *arguments, "--capture",
        ]
    else:
        bounded = share_lock or "--case=stalled-quit" in arguments
        timeout = ["--timeout", str(STALL_PROBE_TIMEOUT_SECONDS)] if bounded else []
        command = [
            sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", TASK,
            *timeout, "--stream", "--", "godot", "--headless", "--path", str(project),
            "--script", str(PROBES / probe), "--", *arguments,
        ]
    with log_path.open("w") as log:
        with subprocess.Popen(command, env=environment(), stdout=log, stderr=subprocess.STDOUT) as process:
            if share_lock:
                _hold_windows_share_lock(process, directory)
            exit_code = process.wait()
    contents = log_path.read_text()
    for line in contents.splitlines():
        if line.startswith("PERF146 "):
            print(line, flush=True)
    return exit_code, contents


def _hold_windows_share_lock(process: subprocess.Popen, directory: Path) -> None:
    """Hold the real Windows file-sharing lock until the Godot probe retries."""
    import ctypes
    from ctypes import wintypes

    def wait_for_request(action: str) -> bool:
        request = directory / f"{action}.request"
        while process.poll() is None and not request.is_file():
            time.sleep(SHARE_LOCK_POLL_SECONDS)
        return request.is_file()

    if not wait_for_request("lock"):
        return
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [
        wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
        wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE,
    ]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    generic_read, no_sharing, open_existing, normal_attributes = 0x80000000, 0, 3, 0x80
    handle = kernel.CreateFileW(str(directory / "current_run.save"), generic_read, no_sharing,
                                None, open_existing, normal_attributes, None)
    if handle == ctypes.c_void_p(-1).value:
        print(f"PERF146 Windows share-lock fixture failed with error {ctypes.get_last_error()}", flush=True)
        return
    try:
        (directory / "lock.ready").touch()
        unlocked = wait_for_request("unlock")
    finally:
        kernel.CloseHandle(handle)
    if unlocked:
        (directory / "unlock.ready").touch()


def _probe(project: Path, directory: Path, case: str, *arguments: str, display: str = "") -> tuple[int, str]:
    directory.mkdir(parents=True)
    return _run(project, directory, "perf146_probe.gd",
                [f"--case={case}", f"--output={directory}", *arguments], display)


def _git(*arguments: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(PROJECT), *arguments])


def _historical_project(stage: Path, ref: str) -> None:
    """Overlay changed blobs from the exact revision on the local imported assets."""
    changes = set(_git("diff", "--name-only", "--no-renames", "-z", ref, "--").decode().split("\0")) - {""}
    historical = set(_git("ls-tree", "-r", "--name-only", "-z", ref).decode().split("\0")) - {""}
    for name in historical:
        if not (PROJECT / name).exists():
            changes.add(name)
    directories = {parent.as_posix() for name in changes for parent in Path(name).parents}
    linked = set()
    for name in sorted(historical):
        for parent in reversed(Path(name).parents):
            relative = parent.as_posix()
            if relative not in directories:
                if relative not in linked:
                    (stage / parent).symlink_to(PROJECT / parent, target_is_directory=True)
                    linked.add(relative)
                break
            (stage / parent).mkdir(exist_ok=True)
        else:
            dest = stage / name
            if name in changes:
                dest.write_bytes(_git("show", f"{ref}:{name}"))
            else:
                dest.symlink_to(PROJECT / name)
    for name in (".godot", "cel_look_variants"):
        if (PROJECT / name).is_dir() and not (stage / name).exists():
            (stage / name).symlink_to(PROJECT / name, target_is_directory=True)


def _legacy(project: Path, output: Path, control: bool) -> bool:
    outcomes = []
    for ref in LEGACY_REFS:
        directory = output / ref
        directory.mkdir(parents=True)
        fixture = directory / "historical.save"
        with tempfile.TemporaryDirectory(prefix="pinned-project-", dir=directory) as scratch:
            stage = Path(scratch)
            _historical_project(stage, ref)
            code, log = _run(stage, directory, "legacy_checkpoint_writer.gd", [str(fixture)])
        if code or "PERF146 LEGACY_WRITTEN" not in log:
            outcomes.append(False)
            continue
        code, log = _probe(project, directory / "continue", "resume", f"--source={fixture}")
        passed = code == 1 and REJECTED in log if control else code == 0 and RESUMED.format(receipt="") in log
        print(f"PERF146 legacy {ref}: {'REPRODUCED' if passed and control else 'PASS' if passed else 'FAIL'}", flush=True)
        outcomes.append(passed)
    return all(outcomes)


def _crash_recovery(project: Path, directory: Path) -> bool:
    code, log = _probe(project, directory, CRASH_CASE)
    live = directory / "current_run.save"
    backup = directory / "current_run.save.backup"
    temp = directory / "current_run.save.tmp"
    stamp = directory / "before-promotion.sha256"
    expected_exit = 0 if os.name == "nt" else 256 - signal.SIGKILL
    if code != expected_exit or live.exists() or not all(p.is_file() for p in (backup, temp, stamp)):
        return False
    digest = hashlib.sha256(backup.read_bytes()).hexdigest()
    if digest != stamp.read_text().strip() or f"PERF146 CRASH stage=recovery_ready live_missing=true backup_sha256={digest}" not in log:
        return False
    if hashlib.sha256(temp.read_bytes()).hexdigest() == digest:
        return False
    resumed = RESUMED.format(receipt="before-rename") + digest
    code, log = _probe(project, directory / "steam-first-launch", "resume-cloud-backup", f"--source={backup}")
    if code or "PERF146 CLOUD account_path=true backup_only=true" not in log or resumed not in log:
        return False
    code, log = _probe(project, directory / "local-relaunch", "resume-local-backup", f"--source={backup}")
    return code == 0 and resumed in log


def _case(project: Path, directory: Path, case: str, control: bool, display: str) -> bool:
    if case == "legacy":
        return _legacy(project, directory, control)
    if case == CRASH_CASE:
        return _crash_recovery(project, directory)
    code, log = _probe(project, directory, case, display=display)
    if case in ("corrupt-live", "wrong-build-live"):
        return code == 0 and f"PERF146 {case} offered=true replacement_prompt=true backup_unchanged=true resumed_backup=true" in log
    if case == "unavailable-live":
        return code == 0 and "PERF146 unavailable-live deferred=true files_unchanged=true resumed_newer_live=true" in log
    if case == "stalled-quit":
        return _stalled_quit_recovery(project, directory, code, log, time.time())
    if case == "atomic":
        if os.name == "nt":
            return code == 0 and ATOMIC.format(live="false") + " backup_unchanged=true" in log
        return code == 1 and ATOMIC.format(live="false") in log if control else code == 0 and ATOMIC.format(live="true") in log
    if case == "continue-missing":
        if control:
            return code == 1 and CONTINUE.format(dialog="false", replacement="true") in log
        return code == 0 and CONTINUE.format(dialog="true", replacement="false") in log
    finalized = FINAL.search(log)
    if case == "reveal-close":
        if code or not finalized or "PERF146 REVEAL installed=true cover_present=true" not in log:
            return False
    else:
        if "PERF146 SLOW_QUIT write_started=true" not in log:
            return False
        if control:
            if finalized or "PERF146 IN_FLIGHT" in log or (code == 0 and os.name != "nt"):
                return False
        else:
            if code or not finalized or int(finalized[1]) < SLOW_WRITE_USEC - MAX_WAIT_INJECTION_USEC:
                return False
            if "PERF146 IN_FLIGHT byte_exact=true" not in log:
                return False
    code, log = _probe(project, directory / "second-launch", "resume",
                       f"--source={directory / 'current_run.save'}")
    return code == 0 and RESUMED.format(receipt="" if control else case) in log


def _stalled_quit_recovery(project: Path, directory: Path, code: int, log: str, exited: float) -> bool:
    expected_exit = 0 if os.name == "nt" else 256 - signal.SIGKILL
    if code != expected_exit or FINAL.search(log) or "PERF146 STALLED_QUIT temporary_started=true" not in log:
        return False
    request = json.loads((directory / "quit-request.json").read_text())
    elapsed = exited - request["unix_seconds"]
    digest = (directory / "stalled-write.sha256").read_text().strip()
    live = directory / "current_run.save"
    temp = directory / "current_run.save.tmp"
    live_unchanged = live.is_file() and hashlib.sha256(live.read_bytes()).hexdigest() == digest
    print(f"PERF146 STALLED_QUIT exit_sec={elapsed:.3f} live_unchanged={str(live_unchanged).lower()}", flush=True)
    if not (SAVE_DEADLINE_SECONDS <= elapsed <= SAVE_DEADLINE_SECONDS + CLEANUP_ALLOWANCE_SECONDS):
        return False
    if not live_unchanged or not temp.is_file() or temp.stat().st_size != 4:
        return False
    code, log = _probe(project, directory / "second-launch", "resume", f"--source={live}")
    return code == 0 and RESUMED.format(receipt="before-stall") + digest in log


def _mode_matrix(project: Path, output: Path, modes: tuple[str, ...], display: str) -> bool:
    results = []
    for mode in modes:
        directory = output / mode
        directory.mkdir(parents=True)
        arguments = [f"--mode={mode}", f"--output={directory}"]
        if mode in QUIT_MODES:
            preparation = directory / "prepare-quit"
            preparation.mkdir()
            code, log = _run(project, preparation, "perf146_mode_probe.gd", [*arguments, "--write-on-quit"])
            if code or f"PERF146 MODE_QUIT {mode} " not in log:
                results.append(False)
                print(f"PERF146 mode {mode}: FAIL during quit fixture", flush=True)
                continue
        code, log = _run(project, directory, "perf146_mode_probe.gd", arguments, display)
        passed = code == 0 and f"PERF146 MODE {mode} title_continue=true same_run=true" in log
        print(f"PERF146 mode {mode}: {'PASS' if passed else 'FAIL'}", flush=True)
        results.append(passed)
    print(f"PERF146 RESUME MODES: {sum(results)}/{len(results)} passed", flush=True)
    return all(results)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", action="append", choices=(*CASES, CRASH_CASE, *FEEDBACK_CASES, MODE_CASE))
    parser.add_argument("--mode", action="append", choices=MODES, help="Select a mode within --case resume-modes.")
    parser.add_argument("--control", action="store_true")
    parser.add_argument("--display", choices=("macos", "windows"))
    args = parser.parse_args()
    defaults = WINDOWED_CASES if args.display else CASES if args.control else (*CASES, CRASH_CASE, *FEEDBACK_CASES, MODE_CASE)
    cases = args.case or defaults
    if args.display and (args.control or any(case not in WINDOWED_CASES for case in cases)):
        parser.error("windowed proof requires a supported capture scenario on the candidate")
    if args.control and any(case in (CRASH_CASE, *FEEDBACK_CASES, MODE_CASE) for case in cases):
        parser.error("the feedback cases require the candidate writer")
    if args.mode and (MODE_CASE not in cases or (args.display and any(mode not in QUIT_MODES for mode in args.mode))):
        parser.error("select --case resume-modes, with event or escape for windowed proof")
    modes = tuple(args.mode or (QUIT_MODES if args.display else MODES))
    results = []
    for case in cases:
        directory = args.output.resolve() / case
        if case == MODE_CASE:
            passed = _mode_matrix(args.project.resolve(), directory, modes, args.display or "")
        else:
            passed = _case(args.project.resolve(), directory, case, args.control, args.display or "")
        print(f"PERF146 {case}: {'REPRODUCED' if passed and args.control else 'PASS' if passed else 'FAIL'}", flush=True)
        results.append(passed)
    print(f"PERF146 PROOF: {sum(results)}/{len(results)} expected outcomes", flush=True)
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
