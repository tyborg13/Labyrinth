#!/usr/bin/env python3
"""Create a task-local Labyrinth inspection save and print the launch command."""

from __future__ import annotations

import argparse
import datetime as dt
import json
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


def worktree_command(project: Path, command: list[str]) -> str:
    return "cd %s && %s" % (shell_quote(str(project)), command_text(command))


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
    parser.add_argument("--manifest", default="", help="Write verified fixture metadata to this JSON file.")
    parser.add_argument("--verify", dest="verify", action="store_true", default=True)
    parser.add_argument("--no-verify", dest="verify", action="store_false")
    parser.add_argument("--launch", action="store_true", help="Regenerate, verify, and then launch the game.")
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
    verifier_command = [
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
        "tools/inspection_fixture_verify.gd",
    ]
    direct_launch_command = [
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
    manifest_path = Path(args.manifest).expanduser().resolve() if args.manifest else (
        Path("/private/tmp/labyrinth-inspection-manifests") / (run_id + ".json")
    )
    self_healing_command = [
        "python3",
        "tools/inspection_fixture.py",
        "--project",
        str(project),
        "--task-id",
        task_id,
        "--run-id",
        run_id,
        "--godot",
        args.godot,
        "--godot-home-root",
        args.godot_home_root,
        "--manifest",
        str(manifest_path),
        "--launch",
        *fixture_args,
    ]
    scenario = value_after(fixture_args, "--scenario", "combat")
    summary = value_after(fixture_args, "--summary", "")
    generator_command_text = worktree_command(project, generator_command)
    verifier_command_text = worktree_command(project, verifier_command)
    launch_command_text = worktree_command(project, self_healing_command)

    print("Inspection fixture generator:")
    print("  task: %s" % task_id)
    print("  run: %s" % run_id)
    print("  scenario: %s" % scenario)
    print("  command: %s" % generator_command_text)
    if args.verify:
        print("  verifier: %s" % verifier_command_text)
    print("  manifest: %s" % manifest_path)
    print("")
    print("Inspection launch command (regenerates and verifies the pre-action state first):")
    print("  %s" % launch_command_text)
    print("")
    print("Verified handoff input:")
    print("  --inspection-manifest %s" % shell_quote(str(manifest_path)))
    print("")

    if args.dry_run:
        return 0

    sys.stdout.flush()
    result = subprocess.run(generator_command, cwd=str(project))
    if result.returncode != 0:
        return result.returncode
    if args.verify:
        result = subprocess.run(verifier_command, cwd=str(project))
        if result.returncode != 0:
            return result.returncode
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "task_id": task_id,
                "run_id": run_id,
                "scenario": scenario,
                "summary": summary,
                "fixture_args": fixture_args,
                "verified": bool(args.verify),
                "generated_at_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                "generator_command": generator_command_text,
                "verifier_command": verifier_command_text if args.verify else "",
                "launch_command": launch_command_text,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    print("Inspection fixture manifest: %s" % manifest_path)
    if args.launch:
        return subprocess.run(direct_launch_command, cwd=str(project)).returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
