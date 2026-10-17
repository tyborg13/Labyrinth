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
import threading
import time

from godot_task_runner import TIMEOUT_RETURN_CODE, slugify


# Keep the historical order, including the static-facing additions that ran first.
SUITES = (
    "en04_enemies_test", "en05_enemies_test", "en06_enemies_test", "static_facing_test",
    "combat_feel_test", "event_view_test", "event_rules_test", "biome_test",
    "health_ghost_test", "movement_undo_test", "threats_at_rest_test",
    "encounter_tables_test", "run_score_test", "sfx_bank_test", "sfx_sync_bank_test",
    "sfx_sync_harness", "section_map_v2_test", "en01_enemies_test",
    "en02_enemies_test", "en03_enemies_test", "magic_deck_input_test",
    "run_end_recap_tests", "main_menu_resume_test",
    "suites/full_scene_presentation_program", "suites/full_scene_interaction_program",
)
MAX_CHILDREN = 3  # The owning main-body Godot occupies the fourth process slot.
SUITE_TIMEOUT_SECONDS = 180.0
PROGRAM_BUDGET_SECONDS = 900.0
POLL_SECONDS = 0.02
WRAPPER_CLEANUP_SECONDS = 5.0


def child_command(args: argparse.Namespace, suite: str, timeout: float) -> list[str]:
    command = [
        sys.executable, str(Path(__file__).with_name("godot_task_runner.py")),
        "--project", str(args.project), "--task-id", slugify(args.task_id + "-" + suite),
        "--timeout", str(timeout), "--stream", "--", args.godot,
        "--headless", "--path", str(args.project), "--script", "res://tests/" + suite + ".gd",
    ]
    if suite == "sfx_sync_harness":
        command.extend(["--", "--assert-onsets"])
    return command


def write_report(path: Path, report: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(path)


def stop_wrapper(process: subprocess.Popen) -> None:
    # The wrapper handles TERM and cleans its own Godot session and descendants.
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=WRAPPER_CLEANUP_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()  # Its parent-death watchdog also cleans the Godot.
            process.wait()


def run_suites(args: argparse.Namespace, cancelled: threading.Event) -> dict:
    started = time.monotonic()
    deadline = started + args.budget
    suites = list(args.suite or SUITES)
    results: list[dict | None] = [None] * len(suites)
    active: dict[int, tuple] = {}
    next_index = 0
    logs = args.result_file.with_suffix(".logs")
    logs.mkdir(parents=True, exist_ok=True)
    report = {"complete": False, "results": results, "seconds": 0.0, "failed": False}
    previous_state = None

    def finish(index: int, code: int, elapsed: float, log_path: Path, reason: str = "") -> None:
        results[index] = {
            "name": suites[index], "returncode": code, "seconds": round(elapsed, 3),
            "log_path": str(log_path), "timed_out": code == TIMEOUT_RETURN_CODE,
            "reason": reason,
        }

    try:
        while next_index < len(suites) or active:
            remaining = deadline - time.monotonic()
            if cancelled.is_set() or remaining <= 0:
                reason = "parent interrupted" if cancelled.is_set() else "full suite budget exhausted"
                for index, (process, log, child_start, log_path, _timeout) in list(active.items()):
                    stop_wrapper(process)
                    log.close()
                    finish(index, TIMEOUT_RETURN_CODE, time.monotonic() - child_start, log_path, reason)
                    del active[index]
                for index in range(next_index, len(suites)):
                    log_path = logs / ("%02d-%s.log" % (index, slugify(suites[index])))
                    log_path.write_text(reason + " before " + suites[index] + "\n")
                    finish(index, TIMEOUT_RETURN_CODE, 0.0, log_path, reason)
                break
            while next_index < len(suites) and len(active) < args.jobs:
                index = next_index
                next_index += 1
                log_path = logs / ("%02d-%s.log" % (index, slugify(suites[index])))
                log = log_path.open("w")
                child_start = time.monotonic()
                timeout = min(args.timeout, deadline - child_start)
                try:
                    process = subprocess.Popen(
                        child_command(args, suites[index], timeout), cwd=args.project,
                        stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                    )
                except OSError as exc:
                    log.write(str(exc) + "\n")
                    log.close()
                    finish(index, 1, time.monotonic() - child_start, log_path, "launch failed")
                    continue
                active[index] = (process, log, child_start, log_path, timeout)
            for index, (process, log, child_start, log_path, timeout) in list(active.items()):
                code = process.poll()
                elapsed = time.monotonic() - child_start
                reason = ""
                if code is None and elapsed >= timeout + WRAPPER_CLEANUP_SECONDS:
                    stop_wrapper(process)
                    code = TIMEOUT_RETURN_CODE
                    reason = "task wrapper timed out"
                if code is not None:
                    log.close()
                    finish(index, code, time.monotonic() - child_start, log_path, reason)
                    del active[index]
            state = (next_index, tuple(row is not None for row in results))
            if state != previous_state:
                report["seconds"] = round(time.monotonic() - started, 3)
                write_report(args.result_file, report)
                previous_state = state
            cancelled.wait(POLL_SECONDS)
    finally:
        for process, log, _start, _path, _timeout in active.values():
            stop_wrapper(process)
            log.close()
    report.update(complete=True, seconds=round(time.monotonic() - started, 3),
                  failed=any(row is None or row["returncode"] != 0 for row in results))
    write_report(args.result_file, report)
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--task-id", default=os.environ.get("LABYRINTH_TASK_ID", "program-suites"))
    parser.add_argument("--result-file", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=MAX_CHILDREN)
    parser.add_argument("--timeout", type=float, default=SUITE_TIMEOUT_SECONDS)
    parser.add_argument("--budget", type=float, default=PROGRAM_BUDGET_SECONDS)
    parser.add_argument("--suite", action="append", help="Run a focused child (repeatable); default: all children.")
    parser.add_argument("--watch-parent-stdin", action="store_true")
    args = parser.parse_args(argv)
    if not 1 <= args.jobs <= MAX_CHILDREN or args.timeout <= 0 or args.budget <= 0:
        parser.error("jobs must be 1..3; timeout and budget must be positive")
    args.project = args.project.resolve()
    args.result_file = args.result_file.resolve()
    args.result_file.parent.mkdir(parents=True, exist_ok=True)
    cancelled = threading.Event()
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda _signum, _frame: cancelled.set())
    if args.watch_parent_stdin:
        # OS.execute_with_pipe holds this pipe open. EOF also covers SIGKILL of
        # the owning Godot, when signal handlers and exit hooks cannot run.
        def watch_parent() -> None:
            if not sys.stdin.buffer.read(1):
                cancelled.set()
        threading.Thread(target=watch_parent, daemon=True).start()
    return 1 if run_suites(args, cancelled)["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
