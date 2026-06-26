#!/usr/bin/env python3
"""Manage isolated Codex task worktrees for Labyrinth of Ash."""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any


BRANCH_PREFIX = "codex/"
METADATA_NAME = "labyrinth-parallel-task.json"


class CommandError(RuntimeError):
    def __init__(self, message: str, result: subprocess.CompletedProcess[str] | None = None):
        super().__init__(message)
        self.result = result


def run_git(repo: Path, args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise CommandError("git %s failed: %s" % (" ".join(args), detail), result)
    return result


def repo_root(path: Path) -> Path:
    result = run_git(path, ["rev-parse", "--show-toplevel"])
    return Path(result.stdout.strip()).resolve()


def git_path(repo: Path, name: str) -> Path:
    result = run_git(repo, ["rev-parse", "--git-path", name])
    return Path(result.stdout.strip()).resolve()


def current_branch(repo: Path) -> str:
    result = run_git(repo, ["branch", "--show-current"])
    return result.stdout.strip()


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "task")[:72]


def unique_branch(repo: Path, task_id: str) -> str:
    base = BRANCH_PREFIX + task_id
    branch = base
    suffix = 2
    while run_git(repo, ["rev-parse", "--verify", "--quiet", branch], check=False).returncode == 0:
        branch = "%s-%d" % (base, suffix)
        suffix += 1
    return branch


def unique_path(base_dir: Path, task_id: str) -> Path:
    path = base_dir / task_id
    suffix = 2
    while path.exists():
        path = base_dir / ("%s-%d" % (task_id, suffix))
        suffix += 1
    return path


def metadata_for(repo: Path) -> dict[str, Any]:
    path = git_path(repo, METADATA_NAME)
    if not path.exists():
        branch = current_branch(repo)
        task_id = branch.removeprefix(BRANCH_PREFIX) if branch.startswith(BRANCH_PREFIX) else ""
        return {"task_id": task_id, "branch": branch, "metadata_path": str(path)}
    return json.loads(path.read_text())


def write_metadata(worktree: Path, metadata: dict[str, Any]) -> None:
    path = git_path(worktree, METADATA_NAME)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")


def default_worktree_root(root: Path) -> Path:
    return root.parent / ("%s.worktrees" % root.name)


def command_start(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    task_id = slugify(args.task_id or args.task or "task")
    worktree_root = Path(args.worktree_root).expanduser().resolve() if args.worktree_root else default_worktree_root(root)
    branch = args.branch or unique_branch(root, task_id)
    if not branch.startswith(BRANCH_PREFIX):
        raise CommandError("Task branches must use %s*: %s" % (BRANCH_PREFIX, branch))
    path = Path(args.path).expanduser().resolve() if args.path else unique_path(worktree_root, branch.removeprefix(BRANCH_PREFIX))

    if args.fetch:
        run_git(root, ["fetch", "origin", "master"])
    base_ref = args.base or "master"
    base_commit = run_git(root, ["rev-parse", "--verify", "%s^{commit}" % base_ref]).stdout.strip()

    payload = {
        "task_id": task_id,
        "branch": branch,
        "base_ref": base_ref,
        "base_commit": base_commit,
        "worktree_path": str(path),
        "created_at_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    if args.dry_run:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    path.parent.mkdir(parents=True, exist_ok=True)
    run_git(root, ["worktree", "add", "-b", branch, str(path), base_ref])
    write_metadata(path, payload)

    print("Created Labyrinth task worktree")
    print("  branch: %s" % branch)
    print("  path: %s" % path)
    print("  base: %s (%s)" % (base_ref, base_commit[:12]))
    print("")
    print("Use this in Godot/task commands:")
    print("  LABYRINTH_TASK_ID=%s" % task_id)
    print("")
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_adopt(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    primary = primary_worktree(root)
    branch = current_branch(root)
    if root == primary and branch == "master" and not args.allow_primary:
        raise CommandError("Refusing to adopt the primary master checkout. Create a task worktree first.")
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status:
        raise CommandError("Refusing to adopt dirty worktree %s. Adopt before editing." % root)

    task_id = slugify(args.task_id or args.task or branch or root.name)
    target_branch = args.branch or (branch if branch.startswith(BRANCH_PREFIX) else unique_branch(root, task_id))
    if not target_branch.startswith(BRANCH_PREFIX):
        raise CommandError("Task branches must use %s*: %s" % (BRANCH_PREFIX, target_branch))

    if args.fetch:
        run_git(root, ["fetch", "origin", "master"])
    base_ref = args.base or "master"
    base_commit = run_git(root, ["rev-parse", "--verify", "%s^{commit}" % base_ref]).stdout.strip()
    head_commit = run_git(root, ["rev-parse", "--verify", "HEAD"]).stdout.strip()
    payload = {
        "task_id": task_id,
        "branch": target_branch,
        "base_ref": base_ref,
        "base_commit": base_commit,
        "worktree_path": str(root),
        "adopted_at_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    if args.dry_run:
        payload["current_branch"] = branch
        payload["current_head"] = head_commit
        payload["would_fast_forward"] = head_commit != base_commit
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    if head_commit != base_commit:
        run_git(root, ["merge", "--ff-only", base_ref])
        head_commit = run_git(root, ["rev-parse", "--verify", "HEAD"]).stdout.strip()
    if head_commit != base_commit:
        raise CommandError("Could not align %s to %s" % (root, base_ref))

    if branch != target_branch:
        run_git(root, ["branch", "-m", target_branch])
        branch = target_branch
        payload["branch"] = branch

    write_metadata(root, payload)
    print("Adopted Labyrinth task worktree")
    print("  branch: %s" % branch)
    print("  path: %s" % root)
    print("  base: %s (%s)" % (base_ref, base_commit[:12]))
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_status(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    metadata = metadata_for(root)
    branch = current_branch(root)
    status = run_git(root, ["status", "--short"]).stdout.splitlines()
    payload = {
        "repo": str(root),
        "branch": branch,
        "task_id": metadata.get("task_id", ""),
        "base_ref": metadata.get("base_ref", ""),
        "base_commit": metadata.get("base_commit", ""),
        "dirty": bool(status),
        "status": status,
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_env(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    metadata = metadata_for(root)
    task_id = args.task_id or str(metadata.get("task_id", "")) or slugify(current_branch(root))
    user_dir = "Labyrinth of Ash Parallel %s" % slugify(task_id)
    if args.format == "json":
        print(json.dumps({"LABYRINTH_TASK_ID": task_id, "LABYRINTH_USER_DIR_NAME": user_dir}, indent=2, sort_keys=True))
    else:
        print("export LABYRINTH_TASK_ID=%s" % shell_quote(task_id))
        print("export LABYRINTH_USER_DIR_NAME=%s" % shell_quote(user_dir))
    return 0


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def require_task_branch(root: Path) -> str:
    branch = current_branch(root)
    if not branch.startswith(BRANCH_PREFIX):
        raise CommandError("Refusing to operate on non-task branch %r; expected %s*" % (branch, BRANCH_PREFIX))
    return branch


def command_commit(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    run_git(root, ["diff", "--check"])
    before = run_git(root, ["status", "--short"]).stdout.strip()
    if not before and not args.allow_empty:
        raise CommandError("No changes to commit in %s" % root)
    if before:
        run_git(root, ["add", "-A"])
    commit_args = ["commit", "-m", args.message]
    if args.allow_empty:
        commit_args.append("--allow-empty")
    run_git(root, commit_args)
    commit_sha = run_git(root, ["rev-parse", "--short", "HEAD"]).stdout.strip()
    print("Committed %s on %s" % (commit_sha, branch))
    return 0


def command_push(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    run_git(root, ["push", "-u", args.remote, branch])
    print("Pushed %s to %s" % (branch, args.remote))
    return 0


def command_cleanup(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    primary = primary_worktree(root)
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status and not args.force:
        raise CommandError("Refusing to remove dirty worktree %s. Commit, clean, or pass --force." % root)
    if args.require_pushed:
        upstream = run_git(root, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], check=False)
        if upstream.returncode != 0:
            raise CommandError("Refusing cleanup before %s has an upstream. Push first or pass --no-require-pushed." % branch)
        ahead = run_git(root, ["rev-list", "--count", "%s..HEAD" % upstream.stdout.strip()]).stdout.strip()
        if int(ahead or "0") > 0:
            raise CommandError("Refusing cleanup: %s has %s unpushed commits." % (branch, ahead))
    parent = root.parent
    os.chdir(str(parent if parent.exists() else Path.home()))
    remove_args = ["worktree", "remove", str(root)]
    if args.force:
        remove_args.append("--force")
    run_git(root, remove_args)
    print("Removed worktree %s" % root)
    if args.delete_branch and branch.startswith(BRANCH_PREFIX):
        repo_for_branch = Path(args.repo_for_branch).resolve() if args.repo_for_branch else primary
        run_git(repo_for_branch, ["branch", "-d", branch])
        print("Deleted local branch %s" % branch)
    return 0


def primary_worktree(repo: Path) -> Path:
    result = run_git(repo, ["worktree", "list", "--porcelain"])
    for line in result.stdout.splitlines():
        if line.startswith("worktree "):
            return Path(line.removeprefix("worktree ")).resolve()
    return repo


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="Repository/worktree path.")
    sub = parser.add_subparsers(dest="command", required=True)

    start = sub.add_parser("start", help="Create a task worktree from master.")
    start.add_argument("--task", default="", help="Human task description used to derive an id.")
    start.add_argument("--task-id", default="", help="Stable task id.")
    start.add_argument("--branch", default="", help="Explicit branch name; must start with codex/.")
    start.add_argument("--worktree-root", default="", help="Directory that contains task worktrees.")
    start.add_argument("--path", default="", help="Explicit worktree path.")
    start.add_argument("--base", default="", help="Base ref. Defaults to local master. Use --base origin/master for remote master.")
    start.add_argument("--fetch", dest="fetch", action="store_true", default=False, help="Fetch origin master before resolving the base ref.")
    start.add_argument("--no-fetch", dest="fetch", action="store_false", help="Do not fetch before creating the worktree.")
    start.add_argument("--dry-run", action="store_true", help="Print planned worktree details without changing git state.")
    start.set_defaults(func=command_start)

    adopt = sub.add_parser("adopt", help="Adopt the current clean worktree as a task worktree.")
    adopt.add_argument("--task", default="", help="Human task description used to derive an id.")
    adopt.add_argument("--task-id", default="", help="Stable task id.")
    adopt.add_argument("--branch", default="", help="Explicit branch name; must start with codex/.")
    adopt.add_argument("--base", default="", help="Base ref. Defaults to local master. Use --base origin/master for remote master.")
    adopt.add_argument("--fetch", dest="fetch", action="store_true", default=False, help="Fetch origin master before resolving the base ref.")
    adopt.add_argument("--no-fetch", dest="fetch", action="store_false", help="Do not fetch before adopting.")
    adopt.add_argument("--allow-primary", action="store_true", help="Allow adopting the primary checkout; normally refused.")
    adopt.add_argument("--dry-run", action="store_true")
    adopt.set_defaults(func=command_adopt)

    status = sub.add_parser("status", help="Report task/worktree status.")
    status.set_defaults(func=command_status)

    env = sub.add_parser("env", help="Print environment variables for parallel-safe Godot runs.")
    env.add_argument("--task-id", default="", help="Override task id.")
    env.add_argument("--format", choices=["shell", "json"], default="shell")
    env.set_defaults(func=command_env)

    commit = sub.add_parser("commit", help="Commit all changes in the task worktree.")
    commit.add_argument("-m", "--message", required=True)
    commit.add_argument("--allow-empty", action="store_true")
    commit.set_defaults(func=command_commit)

    push = sub.add_parser("push", help="Push the task branch.")
    push.add_argument("--remote", default="origin")
    push.set_defaults(func=command_push)

    cleanup = sub.add_parser("cleanup", help="Remove a completed task worktree.")
    cleanup.add_argument("--force", action="store_true")
    cleanup.add_argument("--require-pushed", dest="require_pushed", action="store_true", default=True)
    cleanup.add_argument("--no-require-pushed", dest="require_pushed", action="store_false")
    cleanup.add_argument("--delete-branch", action="store_true")
    cleanup.add_argument("--repo-for-branch", default="", help="Repository to use when deleting the local branch.")
    cleanup.set_defaults(func=command_cleanup)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args) or 0)
    except CommandError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
