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
WATCHDOG_JOIN_MARGIN_SECONDS = 1.0
TIMEOUT_RETURN_CODE = 124
WINDOWS_TREE_CLEANUP_SECONDS = 5.0


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


class RunnerInterrupted(BaseException):
    def __init__(self, signum: int):
        self.signum = signum


def terminate_windows_process_tree(process: subprocess.Popen[str]) -> None:
    # Terminate the tree while its root still exists. TerminateProcess on the
    # wrapper first would bypass Python's finally block and orphan Godot.
    deadline = time.monotonic() + WINDOWS_TREE_CLEANUP_SECONDS
    result = subprocess.run(
        ["taskkill", "/PID", str(process.pid), "/T", "/F"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        timeout=WINDOWS_TREE_CLEANUP_SECONDS,
    )
    if result.returncode != 0 and process.poll() is None:
        raise RuntimeError("Windows process-tree cleanup failed: " + result.stderr.strip())
    process.wait(timeout=max(0.0, deadline - time.monotonic()))


def terminate_process_tree(process: subprocess.Popen[str], *, platform: str | None = None) -> None:
    # The group may still contain descendants after its leader has exited.
    if (platform or os.name) == "nt":
        if process.poll() is None:
            terminate_windows_process_tree(process)
        return
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            process.wait()
            return
    try:
        process.wait(timeout=TERMINATION_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


# A separate session observes EOF on a parent-owned pipe. It handles even
# SIGKILL, which Python cannot catch, without macOS-specific dependencies.
PARENT_DEATH_WATCHDOG = """
import os, signal, sys, time
fd, group = map(int, sys.argv[1:3])
grace = float(sys.argv[3])
for sig in (signal.SIGINT, signal.SIGHUP):
    signal.signal(sig, signal.SIG_IGN)
if not os.read(fd, 1):
    try:
        os.killpg(group, signal.SIGTERM)
        time.sleep(grace)
        os.killpg(group, signal.SIGKILL)
    except ProcessLookupError:
        pass
os.close(fd)
"""


def run_task_command(command: list[str], project: Path, env: dict[str, str], timeout: float | None, stream: bool) -> CommandResult:
    process = None
    watchdog = None
    watchdog_write = None
    previous_handlers = {}

    def interrupted(signum: int, _frame: object) -> None:
        raise RunnerInterrupted(signum)

    # Install before launching, so TERM/INT/HUP cannot strand a just-created child.
    if threading.current_thread() is threading.main_thread():
        for signum in (signal.SIGINT, signal.SIGTERM, *([signal.SIGHUP] if hasattr(signal, "SIGHUP") else [])):
            previous_handlers[signum] = signal.signal(signum, interrupted)
    stdout_chunks: list[str] = []
    stderr_chunks: list[str] = []
    threads: list[threading.Thread] = []
    timed_out = False
    try:
        process = subprocess.Popen(
            command, cwd=str(project), env=env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=1,
            start_new_session=(os.name != "nt"),
        )
        if os.name != "nt":
            watchdog_read, watchdog_write = os.pipe()
            try:
                watchdog = subprocess.Popen(
                    [sys.executable, "-c", PARENT_DEATH_WATCHDOG,
                     str(watchdog_read), str(process.pid), str(TERMINATION_GRACE_SECONDS)],
                    pass_fds=(watchdog_read,), start_new_session=True,
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
            finally:
                os.close(watchdog_read)
        for pipe, sink, chunks in ((process.stdout, sys.stdout, stdout_chunks), (process.stderr, sys.stderr, stderr_chunks)):
            thread = threading.Thread(target=read_pipe, args=(pipe, sink, chunks, stream), daemon=True)
            thread.start()
            threads.append(thread)
        try:
            returncode = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            returncode = TIMEOUT_RETURN_CODE
    except RunnerInterrupted as exc:
        returncode = 128 + exc.signum
    finally:
        # Repeated signals during cleanup must not interrupt group termination.
        for signum in previous_handlers:
            signal.signal(signum, signal.SIG_IGN)
        try:
            if process is not None:
                terminate_process_tree(process)
            if watchdog_write is not None:
                try:
                    os.write(watchdog_write, b"done")
                except BrokenPipeError:
                    pass
                finally:
                    os.close(watchdog_write)
            if watchdog is not None:
                watchdog.wait(timeout=TERMINATION_GRACE_SECONDS + WATCHDOG_JOIN_MARGIN_SECONDS)
            for thread in threads:
                thread.join()
        finally:
            for signum, handler in previous_handlers.items():
                signal.signal(signum, handler)
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
    if command_requests_editor_scan(command) and not args.allow_editor_scan:
        raise SystemExit(
            "error: refusing Godot --editor scan; it generates project-wide .import/.uid sidecars in clean worktrees. "
            "Use a runtime test for parser coverage, or pass --allow-editor-scan only when the metadata changes are intentional."
        )
    if command_is_godot(command) and "--log-file" not in command:
        command = [command[0], "--log-file", str(home_dir / "godot.log"), *command[1:]]

    env = os.environ.copy()
    env["HOME"] = str(home_dir)
    if "--log-file" in command:
        env["LABYRINTH_GODOT_LOG_PATH"] = command[command.index("--log-file") + 1]
    else:
        env.pop("LABYRINTH_GODOT_LOG_PATH", None)
    # Godot and supporting libraries may prefer these over HOME. Never inherit
    # a shared Windows roaming profile or a host's explicit Linux XDG root.
    for variable, directory in (
        ("APPDATA", "AppData/Roaming"), ("LOCALAPPDATA", "AppData/Local"),
        ("XDG_DATA_HOME", "xdg/data"), ("XDG_CONFIG_HOME", "xdg/config"),
        ("XDG_CACHE_HOME", "xdg/cache"), ("XDG_STATE_HOME", "xdg/state"),
    ):
        isolated_path = home_dir / directory
        isolated_path.mkdir(parents=True, exist_ok=True)
        env[variable] = str(isolated_path)
    env["LABYRINTH_TASK_ID"] = run_id
    env["LABYRINTH_USER_DIR_NAME"] = "Escape the Umbra Parallel %s" % run_id
    if args.allow_steam:
        env.pop("LABYRINTH_DISABLE_STEAM", None)
    else:
        env["LABYRINTH_DISABLE_STEAM"] = "1"

    print("Running task-local command:")
    print("  task: %s" % task_id)
    print("  run: %s" % run_id)
    print("  HOME: %s" % home_dir)
    print("  Steam: %s" % ("enabled" if args.allow_steam else "disabled"))
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


def command_is_godot(command: list[str]) -> bool:
    return bool(command) and command[0].replace("\\", "/").rsplit("/", 1)[-1].lower() in ("godot", "godot.exe")


def command_requests_editor_scan(command: list[str]) -> bool:
    return command_is_godot(command) and "--editor" in command


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
    parser.add_argument(
        "--allow-steam",
        action="store_true",
        help="Permit Steam initialization for Steam-specific inspection. Steam is disabled by default for isolated tests and visual proof.",
    )
    parser.add_argument(
        "--allow-editor-scan",
        action="store_true",
        help="Permit an intentional Godot --editor filesystem scan that may update project-wide .import/.uid metadata.",
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
