#!/usr/bin/env python3
"""Create a task-local Labyrinth inspection save and print the launch command."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


BRANCH_PREFIX = "codex/"


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "inspection")[:80]


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
    if branch.startswith(BRANCH_PREFIX):
        return slugify(branch.removeprefix(BRANCH_PREFIX))
    return "manual"


def shell_quote(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_./:=,+-]+", value):
        return value
    return "'" + value.replace("'", "'\"'\"'") + "'"


def command_text(command: list[str]) -> str:
    return " ".join(shell_quote(part) for part in command)


def value_after(args: list[str], flag: str, default: str = "") -> str:
    for index, value in enumerate(args):
        if value == flag and index + 1 < len(args):
            return args[index + 1]
        if value.startswith(flag + "="):
            return value.split("=", 1)[1]
    return default


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog=(
            "Fixture options not recognized by this wrapper are passed through to "
            "tools/inspection_fixture.gd. Example: tools/inspection_fixture.py "
            "--scenario combat --hand quick_stab,bone_dart --summary 'targeting check'"
        ),
    )
    parser.add_argument("--project", default=".", help="Project directory.")
    parser.add_argument("--task-id", default="", help="Task id. Defaults to LABYRINTH_TASK_ID or codex/* branch name.")
    parser.add_argument("--run-id", default="", help="Stable inspection run id. Defaults to <task-id>-inspection.")
    parser.add_argument("--godot", default="godot", help="Godot executable.")
    parser.add_argument("--godot-home-root", default="/private/tmp/labyrinth-godot-home")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without running Godot.")
    return parser


def main(argv: list[str] | None = None) -> int:
    raw_args = list(sys.argv[1:] if argv is None else argv)
    parser = build_parser()
    args, fixture_args = parser.parse_known_args(raw_args)
    project = Path(args.project).expanduser().resolve()
    task_id = slugify(args.task_id or infer_task_id(project))
    run_id = slugify(args.run_id or f"{task_id}-inspection")

    generator_command = [
        sys.executable,
        "tools/godot_task_runner.py",
        "--project",
        str(project),
        "--task-id",
        task_id,
        "--run-id",
        run_id,
        "--godot-home-root",
        args.godot_home_root,
        "--",
        args.godot,
        "--headless",
        "--path",
        ".",
        "--script",
        "tools/inspection_fixture.gd",
        "--",
        *fixture_args,
    ]
    launch_command = [
        "python3",
        "tools/godot_task_runner.py",
        "--task-id",
        task_id,
        "--run-id",
        run_id,
        "--godot-home-root",
        args.godot_home_root,
        "--",
        args.godot,
        "--path",
        ".",
    ]
    scenario = value_after(fixture_args, "--scenario", "combat")
    summary = value_after(fixture_args, "--summary", "")

    print("Inspection fixture generator:")
    print("  task: %s" % task_id)
    print("  run: %s" % run_id)
    print("  scenario: %s" % scenario)
    print("  command: %s" % command_text(generator_command))
    print("")
    print("Inspection launch command from the task worktree:")
    print("  %s" % command_text(launch_command))
    print("")
    print("Queue complete flags:")
    print("  --inspection-scenario %s" % shell_quote(scenario))
    print("  --inspection-run-id %s" % shell_quote(run_id))
    print("  --inspection-summary %s" % shell_quote(summary or ("Continue opens the %s inspection fixture." % scenario)))
    print("  --inspection-launch %s" % shell_quote(command_text(launch_command)))
    print("")

    if args.dry_run:
        return 0

    sys.stdout.flush()
    result = subprocess.run(generator_command, cwd=str(project))
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
