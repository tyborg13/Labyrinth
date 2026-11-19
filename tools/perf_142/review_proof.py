#!/usr/bin/env python3
"""Run the perf-144 repros against the worktree or a read-only control."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[2]
PROBES = Path(__file__).resolve().parent
CASES = ("close", "resume-seed", "retry", "socket", "settings", "quit", "debug-seed")
SHUTDOWN_WARNING = re.compile(r"still in use|instances leaked at exit|leaked .* at exit", re.I)
SAVE = re.compile(r"^PERF144 SAVE (.+) ([0-9a-f]{64})$", re.M)
EXIT = re.compile(r"PERF144 EXIT frames=(\d+) longest_usec=(\d+) elapsed_usec=(\d+) frame_budget_usec=(\d+)")


def stage_retry(project: Path, stage: Path) -> None:
    """Hold aside only the run scene, keeping the original projects untouched."""
    for entry in project.iterdir():
        if entry.name in {".git", "scenes"}:
            continue
        (stage / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
    scenes = stage / "scenes"
    scenes.mkdir()
    for entry in (project / "scenes").iterdir():
        if entry.name == "run_scene.tscn":
            shutil.copyfile(entry, scenes / "run_scene.held")
        else:
            (scenes / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())


def receipt(case: str, process: subprocess.CompletedProcess) -> str:
    log = process.stdout
    if process.returncode != 0:
        return f"Godot runner exited {process.returncode}"
    if case == "close":
        match = SAVE.search(log)
        if not match:
            return "missing pre-close save receipt"
        path = Path(match[1])
        after = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"
        if match[2] != after:
            return f"save changed before={match[2]} after={after}"
        if "PERF144 CLOSE graph_cancelled=true before_commit=true" not in log:
            return "graph did not cancel during boot"
        if SHUTDOWN_WARNING.search(log):
            return "engine reported a shutdown resource warning"
        print(f"PERF144 close: PASS sha256_before={match[2]} sha256_after={after}")
    elif case == "quit":
        match = EXIT.search(log)
        if not match:
            return "missing quit exit receipt"
        frames, longest, elapsed, budget = map(int, match.groups())
        if frames < 1 or longest > budget:
            return f"quit stalled frames={frames} longest_usec={longest} exit_usec={elapsed} budget_usec={budget}"
        if SHUTDOWN_WARNING.search(log):
            return "engine reported a shutdown resource warning"
        print(f"PERF144 quit: PASS frames={frames} longest_usec={longest} exit_usec={elapsed} budget_usec={budget}")
    elif f"PERF144 {case}: PASS" not in log:
        return "missing success receipt"
    return ""


def run(case: str, project: Path, output: Path, task_id: str) -> bool:
    with tempfile.TemporaryDirectory(prefix="perf-144-retry-", dir=output) as temporary:
        if case == "retry":
            stage = Path(temporary)
            stage_retry(project, stage)
            project = stage
        command = [
            sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", task_id,
            "--stream", "--", "godot", "--headless", "--path", str(project), "--script",
            str(PROBES / "review_probe.gd"), "--", f"--case={case}",
        ]
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (output / f"{case}.log").write_text(process.stdout)
    print(process.stdout, end="", flush=True)
    failure = receipt(case, process)
    if failure:
        print(f"PERF144 {case}: FAIL {failure}", flush=True)
    return not failure


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--task-id", default="perf-144")
    parser.add_argument("--case", choices=CASES, action="append")
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    results = [run(case, arguments.project.resolve(), output, arguments.task_id) for case in arguments.case or CASES]
    print(f"PERF144 REVIEW: {sum(results)}/{len(results)} passed", flush=True)
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
