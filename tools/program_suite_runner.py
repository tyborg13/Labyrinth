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

from godot_task_runner import TIMEOUT_RETURN_CODE, slugify, terminate_windows_process_tree
from windows_process_job import spawn_owned_process
from test_execution_sources import program_paths


# Keep the historical order, including the static-facing additions that ran first.
BASE_SUITES = (
    "en04_enemies_test", "en05_enemies_test", "en06_enemies_test", "static_facing_test",
    "combat_feel_test", "event_view_test", "event_rules_test", "biome_test",
    "health_ghost_test", "movement_undo_test", "threats_at_rest_test",
    "suites/encounter_rules_program", "suites/encounter_placement_0_program",
    "suites/encounter_placement_1_program", "suites/encounter_placement_summary_program",
    "run_score_test", "sfx_bank_test", "sfx_sync_bank_test",
    "suites/sfx_sync_0_program", "suites/sfx_sync_1_program", "suites/sfx_sync_2_program",
    "section_map_v2_test", "en01_enemies_test",
    "en02_enemies_test", "en03_enemies_test", "magic_deck_input_test",
    "opening_boon_test", "run_end_recap_tests", "main_menu_resume_test",
    "suites/full_scene_presentation_program", "suites/full_scene_cutouts_program",
    "suites/full_scene_creature_cutouts_program", "suites/full_scene_audio_program",
    "suites/full_scene_navigation_program", "suites/full_scene_card_drag_program",
    "suites/full_scene_controls_program",
    "suites/full_scene_clock_program",
    "suites/full_scene_choices_program", "suites/full_scene_interaction_program",
    "opening_boon_recovery_test", "section_map_v5_test", "section_map_v5_layout_test",
    "suites/section_map_performance_program",
)
SUPPLEMENTAL_MANIFEST = Path(__file__).resolve().parents[1] / "tests/headless_test_programs.json"
SUPPLEMENTAL_PROGRAMS = json.loads(SUPPLEMENTAL_MANIFEST.read_text(encoding="utf-8"))
SUPPLEMENTAL_BY_NAME = {program["path"].removeprefix("tests/").removesuffix(".gd"): program
                        for program in SUPPLEMENTAL_PROGRAMS}
SUITES = tuple(path.removeprefix("tests/").removesuffix(".gd")
               for name in BASE_SUITES + tuple(SUPPLEMENTAL_BY_NAME)
               for path in program_paths("tests/" + name + ".gd"))
MAX_CHILDREN = min(6, max(1, (os.cpu_count() or 1) // 3))
SUITE_TIMEOUT_SECONDS = 180.0
PROGRAM_BUDGET_SECONDS = 900.0
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
    if program.get("args"):
        command.extend(["--", *program["args"]])
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
    deadline = started + args.budget
    suites = list(args.suite or SUITES)
    results: list[dict | None] = [None] * len(suites)
    active: dict[int, tuple] = {}
    next_index = 0
    logs = args.result_file.with_suffix(".logs")
    logs.mkdir(parents=True, exist_ok=True)
    # A fresh directory also prevents stale placement aggregates when a focused
    # command reuses its result-file path. Children keep separate user:// roots.
    args.placement_report_directory = Path(tempfile.mkdtemp(prefix="placement-", dir=logs))
    report = {"complete": False, "results": results, "seconds": 0.0, "failed": False}
    previous_state = None

    def finish(index: int, code: int, elapsed: float, log_path: Path, reason: str = "") -> None:
        results[index] = {
            "name": suites[index], "returncode": code, "seconds": round(elapsed, 3),
            "log_path": str(log_path), "timed_out": code == TIMEOUT_RETURN_CODE,
            "engine_log_path": str(logs / ("%02d" % index) / "godot.log"),
            "reason": reason,
        }

    try:
        while next_index < len(suites) or active:
            remaining = deadline - clock()
            if cancelled.is_set() or remaining <= 0:
                reason = "parent interrupted" if cancelled.is_set() else "full suite budget exhausted"
                for index, (process, log, child_start, log_path, _timeout) in list(active.items()):
                    stop_wrapper(process)
                    log.close()
                    finish(index, TIMEOUT_RETURN_CODE, clock() - child_start, log_path, reason)
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
                child_directory = logs / ("%02d" % index)
                child_directory.mkdir(parents=True, exist_ok=True)
                bootstrap = child_directory / (Path(suites[index]).name + ".gd")
                write_child_bootstrap(bootstrap, suites[index])
                log = log_path.open("w")
                child_start = clock()
                timeout = min(args.timeout, deadline - child_start)
                try:
                    process = spawn_owned_process(
                        child_command(args, suites[index], timeout, bootstrap, child_directory / "godot.log"), cwd=args.project,
                        stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                    )
                except OSError as exc:
                    log.write(str(exc) + "\n")
                    log.close()
                    finish(index, 1, clock() - child_start, log_path, "launch failed")
                    continue
                active[index] = (process, log, child_start, log_path, timeout)
            for index, (process, log, child_start, log_path, timeout) in list(active.items()):
                code = process.poll()
                elapsed = clock() - child_start
                reason = ""
                if code is None and elapsed >= timeout + WRAPPER_CLEANUP_SECONDS:
                    stop_wrapper(process)
                    code = TIMEOUT_RETURN_CODE
                    reason = "task wrapper timed out"
                if code is not None:
                    stop_wrapper(process)
                    log.close()
                    finish(index, code, clock() - child_start, log_path, reason)
                    del active[index]
            state = (next_index, tuple(row is not None for row in results))
            if state != previous_state:
                report["seconds"] = round(clock() - started, 3)
                write_report(args.result_file, report)
                previous_state = state
            wait(max(0.0, min(POLL_SECONDS, deadline - clock())))
    finally:
        for process, log, _start, _path, _timeout in active.values():
            stop_wrapper(process)
            log.close()
    report.update(complete=True, seconds=round(clock() - started, 3),
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
        parser.error("jobs must be 1..%d; timeout and budget must be positive" % MAX_CHILDREN)
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
