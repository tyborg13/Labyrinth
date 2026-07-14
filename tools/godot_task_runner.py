#!/usr/bin/env python3
"""Run a Godot command with task-local HOME, logs, and Labyrinth runtime env."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time
from typing import TextIO


FAILURE_MARKERS = (
    "SCRIPT ERROR:",
    "Parse Error:",
    "ERROR: Failed to load script",
    "TEST RESULT: FAIL",
)
DEFAULT_TIMEOUT_SECONDS = 300.0
TERMINATION_GRACE_SECONDS = 2.0
TIMEOUT_RETURN_CODE = 124


@dataclass
class CommandResult:
    returncode: int
    stdout: str
    stderr: str
    timed_out: bool = False


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "task")[:80]


def make_unique_run_id(task_id: str) -> str:
    task_part = task_id[:40].strip("-._") or "task"
    return slugify("%s-%d-%d" % (task_part, time.time_ns(), os.getpid()))


def infer_task_id(project: Path) -> str:
    env_task = os.environ.get("LABYRINTH_TASK_ID", "").strip()
    if env_task:
        return slugify(env_task)
    result = subprocess.run(
        ["git", "-C", str(project), "branch", "--show-current"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    branch = result.stdout.strip()
    if branch.startswith("codex/"):
        return slugify(branch[len("codex/"):])
    return "manual"


def shell_quote(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_./:=+-]+", value):
        return value
    return "'" + value.replace("'", "'\"'\"'") + "'"


def format_seconds(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    return ("%0.3f" % value).rstrip("0").rstrip(".")


def read_pipe(pipe: TextIO, sink: TextIO, chunks: list[str], stream: bool) -> None:
    try:
        while True:
            chunk = pipe.readline()
            if chunk == "":
                break
            chunks.append(chunk)
            if stream:
                sink.write(chunk)
                sink.flush()
    finally:
        pipe.close()


def terminate_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        process.terminate()
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            process.wait()
            return
    try:
        process.wait(timeout=TERMINATION_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            process.kill()
        else:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait()


def run_task_command(command: list[str], project: Path, env: dict[str, str], timeout: float | None, stream: bool) -> CommandResult:
    process = subprocess.Popen(
        command,
        cwd=str(project),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=1,
        start_new_session=(os.name != "nt"),
    )
    stdout_chunks: list[str] = []
    stderr_chunks: list[str] = []
    stdout_thread = threading.Thread(
        target=read_pipe,
        args=(process.stdout, sys.stdout, stdout_chunks, stream),
        daemon=True,
    )
    stderr_thread = threading.Thread(
        target=read_pipe,
        args=(process.stderr, sys.stderr, stderr_chunks, stream),
        daemon=True,
    )
    stdout_thread.start()
    stderr_thread.start()

    timed_out = False
    try:
        returncode = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        terminate_process_tree(process)
        returncode = TIMEOUT_RETURN_CODE

    stdout_thread.join()
    stderr_thread.join()
    stdout = "".join(stdout_chunks)
    stderr = "".join(stderr_chunks)
    if not stream:
        if stdout:
            print(stdout, end="" if stdout.endswith("\n") else "\n")
        if stderr:
            print(stderr, file=sys.stderr, end="" if stderr.endswith("\n") else "\n")
    return CommandResult(returncode=returncode, stdout=stdout, stderr=stderr, timed_out=timed_out)


def command_run(args: argparse.Namespace) -> int:
    if not args.command:
        raise SystemExit("error: provide a command after --")
    if args.timeout < 0:
        raise SystemExit("error: --timeout must be non-negative")
    project = Path(args.project).resolve()
    task_id = slugify(args.task_id or infer_task_id(project))
    run_id = slugify(args.run_id) if args.run_id else make_unique_run_id(task_id)
    home_dir = Path(args.godot_home_root).expanduser().resolve() / run_id
    home_dir.mkdir(parents=True, exist_ok=True)

    command = list(args.command)
    if command and Path(command[0]).name == "godot" and "--log-file" not in command:
        command = [command[0], "--log-file", str(home_dir / "godot.log"), *command[1:]]

    env = os.environ.copy()
    env["HOME"] = str(home_dir)
    env["LABYRINTH_TASK_ID"] = run_id
    env["LABYRINTH_USER_DIR_NAME"] = "Labyrinth of Ash Parallel %s" % run_id
    env["LABYRINTH_DISABLE_STEAM"] = "1"

    print("Running task-local command:")
    print("  task: %s" % task_id)
    print("  run: %s" % run_id)
    print("  HOME: %s" % home_dir)
    print("  command: %s" % " ".join(shell_quote(part) for part in command))
    timeout = args.timeout if args.timeout > 0 else None
    print("  timeout: %s" % ("%ss" % format_seconds(args.timeout) if timeout is not None else "disabled"))
    if args.stream:
        print("  stream: enabled")
    result = run_task_command(command, project, env, timeout, args.stream)
    combined_output = result.stdout + "\n" + result.stderr
    if result.timed_out:
        print("error: command timed out after %s seconds." % format_seconds(args.timeout), file=sys.stderr)
        return TIMEOUT_RETURN_CODE
    if result.returncode == 0 and godot_output_has_failure(combined_output):
        print("error: Godot reported script or test failures despite exit code 0.", file=sys.stderr)
        return 1
    return result.returncode


def godot_output_has_failure(output: str) -> bool:
    return any(marker in output for marker in FAILURE_MARKERS)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=".", help="Project directory used as cwd.")
    parser.add_argument("--task-id", default="", help="Stable task id.")
    parser.add_argument("--run-id", default="", help="Explicit isolated run id. Defaults to task id plus timestamp.")
    parser.add_argument("--godot-home-root", default="/private/tmp/labyrinth-godot-home")
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Seconds before terminating the command. Use 0 to disable. Defaults to %(default)s.",
    )
    parser.add_argument(
        "--stream",
        action="store_true",
        help="Tee command output live while preserving captured output for failure-marker scanning.",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run after --.")
    parser.set_defaults(func=command_run)
    return parser


def main(argv: list[str] | None = None) -> int:
    raw_args = list(sys.argv[1:] if argv is None else argv)
    if "--" in raw_args:
        raw_args.remove("--")
    args = build_parser().parse_args(raw_args)
    return int(args.func(args) or 0)


if __name__ == "__main__":
    raise SystemExit(main())
