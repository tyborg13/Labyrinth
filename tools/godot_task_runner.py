#!/usr/bin/env python3
"""Run a Godot command with task-local HOME, logs, and Labyrinth runtime env."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "task")[:80]


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


def command_run(args: argparse.Namespace) -> int:
    if not args.command:
        raise SystemExit("error: provide a command after --")
    project = Path(args.project).resolve()
    task_id = slugify(args.task_id or infer_task_id(project))
    run_id = slugify(args.run_id or "%s-%d" % (task_id, int(time.time())))
    home_dir = Path(args.godot_home_root).expanduser().resolve() / run_id
    home_dir.mkdir(parents=True, exist_ok=True)

    command = list(args.command)
    if command and Path(command[0]).name == "godot" and "--log-file" not in command:
        command = [command[0], "--log-file", str(home_dir / "godot.log"), *command[1:]]

    env = os.environ.copy()
    env["HOME"] = str(home_dir)
    env["LABYRINTH_TASK_ID"] = run_id
    env["LABYRINTH_USER_DIR_NAME"] = "Labyrinth of Ash Parallel %s" % run_id

    print("Running task-local command:")
    print("  task: %s" % task_id)
    print("  run: %s" % run_id)
    print("  HOME: %s" % home_dir)
    print("  command: %s" % " ".join(shell_quote(part) for part in command))
    return subprocess.run(command, cwd=str(project), env=env).returncode


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=".", help="Project directory used as cwd.")
    parser.add_argument("--task-id", default="", help="Stable task id.")
    parser.add_argument("--run-id", default="", help="Explicit isolated run id. Defaults to task id plus timestamp.")
    parser.add_argument("--godot-home-root", default="/private/tmp/labyrinth-godot-home")
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
