#!/usr/bin/env python3
"""Buffer isolated program suites while the owning Godot runs its main body."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import threading
import time

from godot_task_runner import TIMEOUT_RETURN_CODE, godot_output_has_failure, slugify, terminate_windows_process_tree
from windows_process_job import spawn_owned_process
from test_execution_sources import program_paths


# The explicit registry owns pass and on-demand programs in scheduling order.
# BASE_SUITES remains an empty compatibility hook for the registry reader.
BASE_SUITES = ()
SUPPLEMENTAL_MANIFEST = Path(os.environ.get("LABYRINTH_PROGRAM_MANIFEST", str(Path(__file__).resolve().parents[1] / "tests/headless_test_programs.json")))
SUPPLEMENTAL_PROGRAMS = json.loads(SUPPLEMENTAL_MANIFEST.read_text(encoding="utf-8"))
SUPPLEMENTAL_BY_NAME = {program["path"].removeprefix("tests/").removesuffix(".gd"): program
                        for program in SUPPLEMENTAL_PROGRAMS}
SUITES = tuple(path.removeprefix("tests/").removesuffix(".gd")
               for name in BASE_SUITES + tuple(SUPPLEMENTAL_BY_NAME)
               for path in program_paths("tests/" + name + ".gd"))
MAX_CHILDREN = min(6, max(1, (os.cpu_count() or 1) // 3))
SUITE_TIMEOUT_SECONDS = 300.0
POLL_SECONDS = 0.02
WRAPPER_CLEANUP_SECONDS = 5.0


def write_child_bootstrap(path: Path, suite: str, *, target: str | None = None,
                          parallel_runtime: str = "res://scripts/parallel_runtime.gd") -> None:
    # Inherit the standalone SceneTree so its lifecycle and awaits are unchanged.
    # Namespace initialization precedes even suites that omit it themselves.
    target = target or "res://tests/" + suite + ".gd"
    path.write_text('''extends %s

func _initialize() -> void:
\tpreload(%s).apply_from_environment()
\tvar log_path: String = OS.get_environment("LABYRINTH_GODOT_LOG_PATH")
\tprint("PROGRAM SUITE PATHS: " + JSON.stringify({"user_data": OS.get_user_data_dir(), "user_file": ProjectSettings.globalize_path("user://program-suite-isolation.json"), "log_file": log_path}))
\tawait super._initialize()
''' % (json.dumps(target), json.dumps(parallel_runtime)), encoding="utf-8")


def task_command(project: Path, task_id: str, timeout: float, command: list[str]) -> list[str]:
    return [sys.executable, str(Path(__file__).with_name("godot_task_runner.py")),
            "--project", str(project), "--task-id", slugify(task_id),
            "--timeout", str(timeout), "--stream", "--", *command]


def child_command(args: argparse.Namespace, suite: str, timeout: float, bootstrap: Path, engine_log: Path) -> list[str]:
    task_id = args.task_id + "-" + suite
    program = SUPPLEMENTAL_BY_NAME.get(suite, {})
    if program.get("mode", "script") != "script":
        # A serial fixture occupies one ordinary scheduler slot. Its stages use
        # the same bootstrap/isolation path and share this child's outer cap.
        return task_command(args.project, task_id, timeout, [
            sys.executable, str(Path(__file__).with_name("program_suite_fixture.py")),
            "--project", str(args.project), "--suite", suite, "--directory", str(bootstrap.parent),
            "--godot", args.godot, "--task-id", task_id, "--timeout", str(timeout)])
    command = task_command(args.project, task_id, timeout, [args.godot,
        "--log-file", str(engine_log), "--headless", "--path", str(args.project),
        "--script", str(bootstrap),
    ])
    if suite == "sfx_sync_harness" or suite.startswith("suites/sfx_sync_"):
        command.extend(["--", "--assert-onsets"])
    if suite.startswith("suites/encounter_"):
        command.extend(["--", "--placement-report-directory=" + str(args.placement_report_directory)])
    user_args = list(program.get("args", []))
    if getattr(args, "perf", False):
        user_args.append("--perf-checks")
    if user_args:
        if "--" not in command[command.index(args.godot) + 1:]:
            command.append("--")
        command.extend(user_args)
    return command


def write_report(path: Path, report: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(path)


def stop_wrapper(process: subprocess.Popen, *, platform: str | None = None) -> None:
    # The wrapper handles TERM and cleans its own Godot session and descendants.
    if (platform or os.name) == "nt":
        terminate_windows_process_tree(process)
        return
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=WRAPPER_CLEANUP_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()  # Its parent-death watchdog also cleans the Godot.
            process.wait()


def run_suites(args: argparse.Namespace, cancelled: threading.Event, *, clock=time.monotonic, wait=None) -> dict:
    wait = cancelled.wait if wait is None else wait
    started = clock()
    suites = list(args.suite or selected_suites(getattr(args, "perf", False), getattr(args, "on_demand", None)))
    results: list[dict | None] = [None] * len(suites)
    attempts: list[list[dict]] = [[] for _ in suites]
    active: dict[int, tuple] = {}
    logs = args.result_file.with_suffix(".logs")
    logs.mkdir(parents=True, exist_ok=True)
    args.placement_report_directory = Path(tempfile.mkdtemp(prefix="placement-", dir=logs))
    report = {"complete": False, "results": results, "retries": [], "seconds": 0.0, "failed": False}

    def finish(index: int, code: int, elapsed: float, log_path: Path, reason: str = "") -> None:
        # A timeout cannot conceal an assertion or script failure printed first.
        if code == TIMEOUT_RETURN_CODE and godot_output_has_failure(log_path.read_text(errors="replace")):
            code, reason = 1, "failure before timeout"
        attempt = {
            "name": suites[index], "returncode": code, "seconds": round(elapsed, 3),
            "log_path": str(log_path), "timed_out": code == TIMEOUT_RETURN_CODE,
            "engine_log_path": str(log_path.parent / ("%02d-attempt-%d" % (index, len(attempts[index]) + 1)) / "godot.log"),
            "reason": reason,
        }
        attempts[index].append(attempt)
        results[index] = dict(attempt, attempts=list(attempts[index]),
                              seconds=round(sum(row["seconds"] for row in attempts[index]), 3))

    def publish() -> None:
        report["seconds"] = round(clock() - started, 3)
        report["retries"] = [suites[i] for i, rows in enumerate(attempts) if len(rows) > 1]
        write_report(args.result_file, report)

    try:
        # First retain the parallel pool. Only after every first attempt has
        # finished do timeouts get their one serial retry, with a fresh HOME.
        for retry in (False, True):
            pending = list(range(len(suites))) if not retry else [
                i for i, row in enumerate(results) if row is not None and row["timed_out"]]
            limit = 1 if retry else args.jobs
            while pending or active:
                if cancelled.is_set():
                    for index, (process, log, child_start, log_path, _timeout) in list(active.items()):
                        stop_wrapper(process)
                        log.close()
                        finish(index, 1, clock() - child_start, log_path, "parent interrupted")
                        del active[index]
                    for index in pending:
                        log_path = logs / ("%02d-cancelled.log" % index)
                        log_path.write_text("parent interrupted before " + suites[index] + "\n")
                        finish(index, 1, 0.0, log_path, "parent interrupted")
                    pending.clear()
                    break
                while pending and len(active) < limit:
                    index = pending.pop(0)
                    attempt = len(attempts[index]) + 1
                    log_path = logs / ("%02d-%s-attempt-%d.log" % (index, slugify(suites[index]), attempt))
                    child_directory = logs / ("%02d-attempt-%d" % (index, attempt))
                    child_directory.mkdir(parents=True, exist_ok=True)
                    bootstrap = child_directory / (Path(suites[index]).name + ".gd")
                    write_child_bootstrap(bootstrap, suites[index])
                    log = log_path.open("w")
                    child_start = clock()
                    timeout = float(SUPPLEMENTAL_BY_NAME.get(suites[index], {}).get("timeout_seconds", args.timeout))
                    try:
                        process = spawn_owned_process(
                            child_command(args, suites[index], timeout, bootstrap, child_directory / "godot.log"), cwd=args.project,
                            env=dict(os.environ, LABYRINTH_CEL_LOOK=os.environ.get("LABYRINTH_CEL_LOOK", "off")),
                            stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                        )
                    except OSError as exc:
                        log.write(str(exc) + "\n")
                        log.close()
                        finish(index, 1, clock() - child_start, log_path, "launch failed")
                        continue
                    active[index] = (process, log, child_start, log_path, timeout)
                changed = False
                for index, (process, log, child_start, log_path, timeout) in list(active.items()):
                    code = process.poll()
                    elapsed = clock() - child_start
                    reason = ""
                    if code is None and elapsed >= timeout + WRAPPER_CLEANUP_SECONDS:
                        stop_wrapper(process)
                        code, reason = TIMEOUT_RETURN_CODE, "task wrapper timed out"
                    if code is not None:
                        stop_wrapper(process)
                        log.close()
                        finish(index, code, clock() - child_start, log_path, reason)
                        del active[index]
                        changed = True
                if changed:
                    publish()
                wait(POLL_SECONDS)
            if cancelled.is_set():
                break
    finally:
        for process, log, _start, _path, _timeout in active.values():
            stop_wrapper(process)
            log.close()
    report.update(complete=True, failed=cancelled.is_set() or any(
        row is None or row["returncode"] != 0 for row in results))
    publish()
    return report


def selected_suites(perf: bool = False, on_demand: list[str] | None = None) -> tuple[str, ...]:
    if on_demand is not None:
        return tuple(name for name in SUITES if SUPPLEMENTAL_BY_NAME.get(name, {}).get("on_demand")
                     and ("all" in on_demand or SUPPLEMENTAL_BY_NAME[name]["group"] in on_demand))
    if perf:
        return tuple(name for name in SUITES if (
            SUPPLEMENTAL_BY_NAME.get(name, {}).get("perf_checks", False)
            or SUPPLEMENTAL_BY_NAME.get(name, {}).get("group") == "perf"))
    return tuple(name for name in SUITES if not SUPPLEMENTAL_BY_NAME.get(name, {}).get("on_demand") and SUPPLEMENTAL_BY_NAME.get(name, {}).get("group") != "perf")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--task-id", default=os.environ.get("LABYRINTH_TASK_ID", "program-suites"))
    parser.add_argument("--result-file", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=MAX_CHILDREN)
    parser.add_argument("--timeout", type=float, default=SUITE_TIMEOUT_SECONDS)
    parser.add_argument("--perf", action="store_true", help="Run the opt-in speed guards and their functional fixtures.")
    parser.add_argument("--on-demand", nargs="+", metavar="GROUP",
                        choices=sorted({p["group"] for p in SUPPLEMENTAL_PROGRAMS if p.get("on_demand")} | {"all"}),
                        help="Run only explicit on-demand groups (or all).")
    parser.add_argument("--suite", action="append", help="Run a focused child (repeatable); default: all children.")
    parser.add_argument("--watch-parent-stdin", action="store_true")
    args = parser.parse_args(argv)
    if not 1 <= args.jobs <= MAX_CHILDREN or args.timeout <= 0:
        parser.error("jobs must be 1..%d; timeout must be positive" % MAX_CHILDREN)
    args.project = args.project.resolve()
    args.result_file = args.result_file.resolve()
    args.result_file.parent.mkdir(parents=True, exist_ok=True)
    cancelled = threading.Event()
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda _signum, _frame: cancelled.set())
    if args.watch_parent_stdin:
        # OS.execute_with_pipe holds this pipe open. EOF also covers SIGKILL of
        # the owning Godot, when signal handlers and exit hooks cannot run.
        # os.read, not sys.stdin.buffer: a daemon thread blocked in the buffered
        # reader holds its lock at exit, and Python aborts ("quit unexpectedly").
        def watch_parent() -> None:
            if not os.read(sys.stdin.fileno(), 1):
                cancelled.set()
        threading.Thread(target=watch_parent, daemon=True).start()
    return 1 if run_suites(args, cancelled)["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
