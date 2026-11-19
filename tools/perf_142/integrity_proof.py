#!/usr/bin/env python3
"""Run the perf-145 fault probes and time the actual Godot process exit."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[2]
PROBES = Path(__file__).resolve().parent
INTEGRITY_CASES = ("replacement", "empty", "profile", "steam", "debug-seed", "clock")
COVER_QUIT_CASES = ("early-preload", "mid-graph", "loading-cover")
QUIT_CASES = ("title-idle", *COVER_QUIT_CASES, "combat", "startup-fade")
TEST_CLOCK = 1795090000
WATCHDOG_CASES = ("stalled-io", "stalled-scene", "idle-scene-load")
EXIT_BUDGET_MS = 3000
WATCHDOG_MIN_MS = 2400
SAVE_WATCHDOG_MIN_MS = 8000
SAVE_EXIT_BUDGET_MS = 10500  # Eight-second save deadline plus cleanup/exit allowance.
HIDE_BUDGET_USEC = 100000
PID_POLL_SECONDS = 0.005
WINDOWED_RUNNER_TIMEOUT = 30
MANUAL_RUNNER_TIMEOUT = 90
LEAK = re.compile(r"still in use|instances leaked at exit|leaked .* at exit|RID.*leaked", re.I)
ORIGINAL = re.compile(r"^PERF145 ORIGINAL (.+) ([0-9a-f]{64}|missing)$", re.M)
FINAL = re.compile(r"PERF145 FINALIZE elapsed_usec=(\d+) frames=(\d+) longest_usec=(\d+) hidden_usec=(-?\d+)")
CLOCK = re.compile(r"PERF145 CLOCK seed=(\d+)")


def environment() -> dict[str, str]:
    return {
        **os.environ,
        "LABYRINTH_DEMO": "1",
        "LABYRINTH_CEL_LOOK": "all",
        "LABYRINTH_DISABLE_STEAM": "1",
    }


def run_headless(project: Path, probe: str, log: Path, task_id: str, *arguments: str) -> tuple[int, str]:
    command = [
        sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", task_id,
        "--stream", "--", "godot", "--headless", "--path", str(project), "--script",
        str(PROBES / probe), "--", *arguments,
    ]
    result = subprocess.run(command, env=environment(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    log.write_text(result.stdout)
    return result.returncode, result.stdout


def stage_clock(project: Path, stage: Path) -> None:
    """Inject a constant wall-clock second into the allocator in a disposable project view."""
    for entry in project.iterdir():
        if entry.name in {".git", "scripts", "output"}:
            continue
        (stage / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
    scripts = stage / "scripts"
    scripts.mkdir()
    allocator = "initial_run_graph.gd" if (project / "scripts/initial_run_graph.gd").is_file() else "run_scene.gd"
    for entry in (project / "scripts").iterdir():
        dest = scripts / entry.name
        if entry.name == allocator:
            original = "int(Time.get_unix_time_from_system()) &"
            text = entry.read_text()
            if text.count(original) != 1:
                raise RuntimeError(f"expected one automatic clock read in {entry}")
            dest.write_text(text.replace(original, f"{TEST_CLOCK} &"))
        else:
            dest.symlink_to(entry, target_is_directory=entry.is_dir())


def clock_receipt(project: Path, output: Path, task_id: str) -> bool:
    with tempfile.TemporaryDirectory(prefix="clock-", dir=output) as directory:
        stage = Path(directory)
        stage_clock(project, stage)
        storage = stage / "fixture"
        storage.mkdir()
        seeds = []
        for launch in (1, 2):
            code, log = run_headless(stage, "integrity_probe.gd", output / f"clock-{launch}.log", task_id,
                                     "--case=clock", f"--storage={storage}")
            match = CLOCK.search(log)
            if code or not match or "PERF145 CLOCK abandoned=true" not in log:
                return False
            seeds.append(int(match[1]))
        print(f"PERF145 clock: {'REPRODUCED' if seeds[0] == seeds[1] else 'ABSENT'} launches={seeds}")
        return seeds[0] == seeds[1]


def integrity(project: Path, output: Path, case: str, control: bool, task_id: str) -> bool:
    if case == "clock":
        return clock_receipt(project, output, task_id)
    code, log = run_headless(project, "integrity_probe.gd", output / f"{case}.log", task_id, f"--case={case}")
    if code:
        print(f"PERF145 {case}: ERROR runner={code}")
        return False
    original = ORIGINAL.search(log)
    unchanged = None
    if original:
        path = Path(original[1])
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"
        unchanged = original[2] == actual
        print(f"PERF145 {case} checkpoint: before={original[2]} after={actual}")
    is_release = not (project / "scripts/initial_run_graph.gd").is_file()
    if control:
        expected = {
            "replacement": unchanged is False and "queued=true" in log,
            "empty": unchanged is False and "revealed=true has_seed=false has_graph=false" in log,
            "profile": unchanged is True and "PERF145 PROFILE marker_lost=true" in log and "run_counter=1" in log,
            "steam": "connected=false" in log and "committed_seed=145" in log,
            "debug-seed": ("no_background_graph=true seed=146" if is_release else "cancelled=false pending=true") in log,
        }
        passed = expected[case]
    else:
        expected = {
            "replacement": unchanged is True and "queued=false dialog=true disk_seed=144" in log,
            "empty": unchanged is True and "queued=false dialog=true" in log and "revealed=false" in log,
            "profile": unchanged is True and "PERF145 PROFILE marker_lost=true" in log and "run_counter=1" in log,
            "steam": "connected=true" in log and "cancelled=true disk_seed=-1" in log,
            "debug-seed": "cancelled=true pending=true" in log and "seed=146 disk_seed=146" in log,
        }
        passed = expected[case] and not LEAK.search(log)
    outcome = "REPRODUCED" if control and not (is_release and case == "debug-seed") else "PASS"
    if not control and case == "profile": outcome = "REPRODUCED"
    print(f"PERF145 {case}: {outcome if passed else 'FAIL'}")
    return passed


def pid_alive(pid: int) -> bool:
    # kill(pid, 0) is POSIX's existence check. Windows Python implements
    # os.kill via TerminateProcess, so use a read-only process handle there.
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes

        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x00100000, False, pid)  # SYNCHRONIZE
        if not handle:
            return False
        try:
            return kernel.WaitForSingleObject(handle, 0) == 0x102  # WAIT_TIMEOUT
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def quit_receipt(project: Path, output: Path, case: str, control: bool, display: str, manual: bool,
                 title_idle_msec: int, background: bool, task_id: str) -> bool:
    directory = output / case
    directory.mkdir(parents=True, exist_ok=True)
    stamp = directory / "request.json"
    stamp.unlink(missing_ok=True)
    arguments = [f"--case={case}", f"--output={directory}"]
    if case == "title-idle":
        arguments.append(f"--title-idle-msec={title_idle_msec}")
    if control:
        arguments.append("--control")
    if display:
        arguments.append("--capture")
        if manual:
            arguments.append("--native-input")
        command = [
            sys.executable, str(PROJECT / "tools/visual_probe_runner.py"), "--project", str(project),
            "--task-id", task_id, "--no-headless", "--display-driver", display, "--audio-driver", "Dummy",
            "--expect-size", "1920x1080", "--proof-contract", str(PROBES / "quit_visual_proof.json"),
            "--result-manifest", str(directory / "images.json"), "--timeout",
            str(MANUAL_RUNNER_TIMEOUT if manual else WINDOWED_RUNNER_TIMEOUT),
            str(PROBES / "quit_probe.gd"), "--", *arguments,
        ]
        if manual:
            print(f"PERF145 native {case}: close the window once the fixture appears", flush=True)
    else:
        command = [
            sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", task_id,
            "--stream", "--", "godot", "--headless", "--path", str(project), "--script",
            str(PROBES / "quit_probe.gd"), "--", *arguments,
        ]
    log_path = directory / "godot.log"
    if background:
        # Restrict the game runner while leaving the PID observer responsive.
        command = ["/usr/sbin/taskpolicy", "-c", "background", *command]
    with log_path.open("w") as log_file:
        process = subprocess.Popen(command, env=environment(), stdout=log_file, stderr=subprocess.STDOUT)
        while not stamp.is_file() and process.poll() is None:
            time.sleep(PID_POLL_SECONDS)
        exit_ms = None
        request = {}
        if stamp.is_file():
            request = json.loads(stamp.read_text())
            while process.poll() is None and pid_alive(request["pid"]):
                time.sleep(PID_POLL_SECONDS)
            exit_ms = (time.time_ns() / 1000 - request["unix_usec"]) / 1000
        code = process.wait()
    log = log_path.read_text()
    final = FINAL.search(log)
    hidden = int(final[4]) if final else -1
    phase = next((line for line in log.splitlines() if line.startswith("PERF145 QUIT phase=")), "")
    print(phase)
    if exit_ms is None:
        print(f"PERF145 quit {case}: ERROR missing request runner={code} log={log_path}")
        return False
    preserved = True
    if "save_path" in request and case != "combat":
        save = Path(request["save_path"])
        preserved = save.is_file() and hashlib.sha256(save.read_bytes()).hexdigest() == request["save_sha256"]
        print(f"PERF145 {case} checkpoint_preserved={str(preserved).lower()}")
    idle_load_confirmed = "cover=false" in phase and "graph=false" in phase and "threaded_scene=true" in phase
    if case == "idle-scene-load":
        preserved = preserved and "save_path" in request and idle_load_confirmed
    if control and case in {"early-preload", "idle-scene-load"}:
        passed = exit_ms > EXIT_BUDGET_MS and "threaded_scene=true" in phase and preserved
        outcome = "REPRODUCED"
    elif control and case == "title-idle":
        passed = code == 0 and final is not None
        outcome = f"BASELINE resource_warning={str(bool(LEAK.search(log))).lower()}"
    elif final is None and (case in WATCHDOG_CASES or case in COVER_QUIT_CASES
                            or (case == "title-idle" and idle_load_confirmed)):
        # Godot uses TerminateProcess with exit code 0 on Windows.
        watchdog_exit = code != 0 or os.name == "nt"
        minimum_ms, budget_ms = WATCHDOG_MIN_MS, EXIT_BUDGET_MS
        if case == "stalled-io":
            minimum_ms, budget_ms = SAVE_WATCHDOG_MIN_MS, SAVE_EXIT_BUDGET_MS
            temporary = Path(request.get("save_path", "") + ".tmp")
            preserved = (preserved and "PERF145 STALLED_IO temporary_started=true" in log
                         and temporary.is_file() and temporary.stat().st_size == 4)
        passed = (watchdog_exit and minimum_ms <= exit_ms <= budget_ms
                  and preserved and not LEAK.search(log))
        if display:
            observed = re.search(r"PERF145 WINDOW_MINIMIZED usec=(\d+)", log)
            hidden = int(observed[1]) if observed else -1
            passed = passed and 0 <= hidden <= HIDE_BUDGET_USEC
        outcome = "PASS watchdog"
    else:
        passed = (code == 0 and bool(final) and exit_ms <= EXIT_BUDGET_MS and preserved
                  and not LEAK.search(log) and case not in WATCHDOG_CASES)
        if display:
            passed = passed and 0 <= hidden <= HIDE_BUDGET_USEC
        outcome = "PASS"
    hidden_text = "headless" if not display else f"{hidden / 1000:.3f} ms"
    final_text = f"{int(final[1]) / 1000:.3f} ms" if final else "unavailable"
    print(f"PERF145 quit {case}: {outcome if passed else 'FAIL'} hidden={hidden_text} finalize={final_text} exit={exit_ms:.3f} ms runner={code}")
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--task-id", default="perf-145")
    parser.add_argument("--control", action="store_true")
    parser.add_argument("--case", action="append", choices=(*INTEGRITY_CASES, *QUIT_CASES, *WATCHDOG_CASES))
    parser.add_argument("--display")
    parser.add_argument("--manual", action="store_true")
    parser.add_argument("--title-idle-msec", type=int, default=0)
    parser.add_argument("--background", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = args.project.resolve()
    defaults = (*INTEGRITY_CASES, "early-preload") if args.control else (*INTEGRITY_CASES, *QUIT_CASES, *WATCHDOG_CASES)
    results = []
    for case in args.case or defaults:
        if case in INTEGRITY_CASES:
            results.append(integrity(project, output, case, args.control, args.task_id))
        else:
            results.append(quit_receipt(project, output, case, args.control, args.display, args.manual,
                                        args.title_idle_msec, args.background, args.task_id))
    print(f"PERF145 PROOF: {sum(results)}/{len(results)} expected outcomes")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
