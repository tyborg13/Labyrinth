#!/usr/bin/env python3
"""Manage isolated Codex task worktrees for Escape the Umbra."""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Any


BRANCH_PREFIX = "codex/"
METADATA_NAME = "labyrinth-parallel-task.json"
RISK_TIERS = ("low", "standard", "high")


class CommandError(RuntimeError):
    def __init__(self, message: str, result: subprocess.CompletedProcess[str] | None = None):
        super().__init__(message)
        self.result = result


def run_git(
    repo: Path,
    args: list[str],
    *,
    check: bool = True,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        input=input_text,
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
    path = Path(result.stdout.strip())
    if not path.is_absolute():
        path = repo / path
    return path.resolve()


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


def empty_contract() -> dict[str, Any]:
    return {
        "risk_tier": "standard",
        "acceptance_criteria": [],
        "required_proof": [],
        "inspection_expectation": "",
    }


def normalized_contract(value: Any) -> dict[str, Any]:
    raw = value if isinstance(value, dict) else {}
    risk_tier = str(raw.get("risk_tier", "standard")).strip().lower()
    if risk_tier not in RISK_TIERS:
        risk_tier = "standard"
    return {
        "risk_tier": risk_tier,
        "acceptance_criteria": [str(item).strip() for item in raw.get("acceptance_criteria", []) if str(item).strip()],
        "required_proof": [str(item).strip() for item in raw.get("required_proof", []) if str(item).strip()],
        "inspection_expectation": str(raw.get("inspection_expectation", "")).strip(),
    }


def contract_problems(contract: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    if not contract.get("acceptance_criteria"):
        problems.append("at least one observable acceptance criterion is required")
    if not contract.get("required_proof"):
        problems.append("at least one required proof item is required")
    if contract.get("risk_tier") == "high" and not contract.get("inspection_expectation"):
        problems.append("high-risk tasks must declare an inspection expectation or why inspection is not applicable")
    return problems


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
        "contract": empty_contract(),
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
        "contract": normalized_contract(metadata_for(root).get("contract", {})),
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
    contract = normalized_contract(metadata.get("contract", {}))
    payload = {
        "repo": str(root),
        "branch": branch,
        "task_id": metadata.get("task_id", ""),
        "base_ref": metadata.get("base_ref", ""),
        "base_commit": metadata.get("base_commit", ""),
        "dirty": bool(status),
        "status": status,
        "contract": contract,
        "contract_ready": not contract_problems(contract),
        "contract_problems": contract_problems(contract),
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_contract(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    require_task_branch(root)
    metadata = metadata_for(root)
    existing = normalized_contract(metadata.get("contract", {}))
    contract = {
        "risk_tier": args.risk_tier or existing["risk_tier"],
        "acceptance_criteria": args.acceptance if args.acceptance is not None else existing["acceptance_criteria"],
        "required_proof": args.required_proof if args.required_proof is not None else existing["required_proof"],
        "inspection_expectation": (
            args.inspection_expectation
            if args.inspection_expectation is not None
            else existing["inspection_expectation"]
        ),
    }
    contract = normalized_contract(contract)
    problems = contract_problems(contract)
    if problems:
        raise CommandError("Incomplete task acceptance contract: %s" % "; ".join(problems))
    metadata["contract"] = contract
    metadata["contract_updated_at_utc"] = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    write_metadata(root, metadata)
    print(json.dumps({"ok": True, "contract": contract}, indent=2, sort_keys=True))
    return 0


def command_prepare_worker(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    task_id = slugify(args.task_id or args.task or "task")
    branch = args.branch or (BRANCH_PREFIX + task_id)
    if not branch.startswith(BRANCH_PREFIX):
        raise CommandError("Task branches must use %s*: %s" % (BRANCH_PREFIX, branch))
    if args.fetch:
        run_git(root, ["fetch", "origin", "master"])
    base_ref = args.base or "master"
    base_commit = ref_commit(root, base_ref)
    if not base_commit:
        raise CommandError("Could not resolve base ref %r" % base_ref)
    existing_commit = ref_commit(root, branch)
    if existing_commit:
        if not args.reuse or existing_commit != base_commit:
            raise CommandError(
                "Branch %s already exists at %s; expected %s. Pass --reuse only for an exact prepared branch."
                % (branch, existing_commit[:12], base_commit[:12])
            )
    elif not args.dry_run:
        run_git(root, ["branch", branch, base_ref])
    payload = {
        "task_id": task_id,
        "branch": branch,
        "base_ref": base_ref,
        "base_commit": base_commit,
        "starting_state": {"type": "branch", "branchName": branch},
        "dry_run": bool(args.dry_run),
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_preflight(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    metadata = metadata_for(root)
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status and not args.allow_dirty:
        raise CommandError("Git-write preflight requires a clean worktree; found:\n%s" % status)
    contract = normalized_contract(metadata.get("contract", {}))
    problems = contract_problems(contract)
    if problems and not args.allow_draft_contract:
        raise CommandError("Task acceptance contract is incomplete: %s" % "; ".join(problems))

    refresh = run_git(root, ["update-index", "--refresh"], check=False)
    if refresh.returncode != 0 and not args.allow_dirty:
        detail = refresh.stderr.strip() or refresh.stdout.strip()
        raise CommandError("git update-index --refresh failed: %s" % detail)
    tree_before = run_git(root, ["write-tree"]).stdout.strip()
    smoke_path = ".codex/.git-write-smoke-%d" % os.getpid()
    if run_git(root, ["ls-files", "--error-unmatch", smoke_path], check=False).returncode == 0:
        raise CommandError("Refusing to overwrite tracked smoke-test path %s" % smoke_path)
    blob = run_git(root, ["hash-object", "-w", "--stdin"], input_text="labyrinth git write smoke\n").stdout.strip()
    try:
        run_git(root, ["update-index", "--add", "--cacheinfo", "100644,%s,%s" % (blob, smoke_path)])
        run_git(root, ["write-tree"])
    finally:
        run_git(root, ["update-index", "--force-remove", smoke_path], check=False)
    tree_after = run_git(root, ["write-tree"]).stdout.strip()
    if tree_after != tree_before:
        raise CommandError("Git-write smoke test did not restore the original index tree")
    smoke_ref = "refs/heads/codex/git-write-smoke-%d" % os.getpid()
    if ref_commit(root, smoke_ref):
        raise CommandError("Refusing to overwrite Git-write smoke-test ref %s" % smoke_ref)
    head_commit = ref_commit(root, "HEAD")
    try:
        run_git(root, ["update-ref", smoke_ref, head_commit, "0" * len(head_commit)])
        if ref_commit(root, smoke_ref) != head_commit:
            raise CommandError("Git-write smoke-test ref did not resolve to HEAD")
    finally:
        run_git(root, ["update-ref", "-d", smoke_ref], check=False)
    if ref_commit(root, smoke_ref):
        raise CommandError("Git-write smoke test did not remove temporary branch ref %s" % smoke_ref)
    master_commit = ref_commit(root, args.master_ref)
    if not master_commit:
        raise CommandError("Could not resolve master ref %r" % args.master_ref)
    counts = run_git(root, ["rev-list", "--left-right", "--count", "%s...HEAD" % args.master_ref]).stdout.strip().split()
    behind = int(counts[0]) if len(counts) == 2 else 0
    ahead = int(counts[1]) if len(counts) == 2 else 0
    payload = {
        "ok": True,
        "repo": str(root),
        "branch": branch,
        "head": head_commit,
        "master_ref": args.master_ref,
        "master_commit": master_commit,
        "ahead": ahead,
        "behind": behind,
        "master_contained": is_ancestor(root, args.master_ref, "HEAD"),
        "head_contained_by_master": is_ancestor(root, "HEAD", args.master_ref),
        "index_tree": tree_after,
        "contract": contract,
        "contract_ready": not problems,
        "checks": [
            "clean_worktree",
            "update_index_refresh",
            "object_write",
            "index_add_remove",
            "index_restored",
            "temporary_branch_ref_write",
            "temporary_branch_ref_removed",
        ],
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def command_env(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    metadata = metadata_for(root)
    task_id = args.task_id or str(metadata.get("task_id", "")) or slugify(current_branch(root))
    user_dir = "Escape the Umbra Parallel %s" % slugify(task_id)
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


def ref_commit(repo: Path, ref: str) -> str:
    result = run_git(repo, ["rev-parse", "--verify", "%s^{commit}" % ref], check=False)
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def is_ancestor(repo: Path, ancestor_ref: str, descendant_ref: str) -> bool:
    return run_git(repo, ["merge-base", "--is-ancestor", ancestor_ref, descendant_ref], check=False).returncode == 0


def first_landed_ref(repo: Path, branch: str, refs: list[str]) -> str:
    for ref in refs:
        if ref_commit(repo, ref) and is_ancestor(repo, branch, ref):
            return ref
    return ""


def stable_patch_id(repo: Path, base_ref: str, head_ref: str = "HEAD") -> str:
    patch = run_git(repo, ["diff", "--binary", "--full-index", "%s..%s" % (base_ref, head_ref)]).stdout
    if not patch.strip():
        return "empty"
    result = run_git(repo, ["patch-id", "--stable"], input_text=patch)
    line = result.stdout.strip().splitlines()
    if not line:
        raise CommandError("Could not calculate a stable task patch id")
    return line[0].split()[0]


def integrate_ref(root: Path, required_master: str) -> dict[str, Any]:
    branch = require_task_branch(root)
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status:
        raise CommandError("Refusing to integrate into dirty worktree %s" % root)
    metadata = metadata_for(root)
    before_head = ref_commit(root, "HEAD")
    authorization = metadata.get("publication_authorization", {})
    authorization_matches_before = (
        isinstance(authorization, dict)
        and str(authorization.get("commit", "")) == before_head
        and bool(str(authorization.get("reviewer", "")).strip())
        and bool(str(authorization.get("user_approval", "")).strip())
    )
    before_base = run_git(root, ["merge-base", required_master, "HEAD"]).stdout.strip()
    before_patch_id = stable_patch_id(root, before_base)
    if not is_ancestor(root, required_master, "HEAD"):
        result = run_git(root, ["merge", "--no-edit", required_master], check=False)
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            raise CommandError(
                "Integration stopped with conflicts. Resolve them in the task worktree, rerun proof, and use `integrate` again: %s"
                % detail,
                result,
            )
    after_head = ref_commit(root, "HEAD")
    after_patch_id = stable_patch_id(root, required_master)
    report = {
        "branch": branch,
        "integrated_ref": required_master,
        "before_head": before_head,
        "after_head": after_head,
        "before_patch_id": before_patch_id,
        "after_patch_id": after_patch_id,
        "task_patch_unchanged": before_patch_id == after_patch_id,
        "approval_still_valid": before_patch_id == after_patch_id and authorization_matches_before,
    }
    if report["task_patch_unchanged"] and authorization_matches_before:
        metadata["publication_authorization"] = {
            **authorization,
            "commit": after_head,
            "mechanically_integrated_from": before_head,
            "mechanically_integrated_at_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        }
        metadata.pop("publication_invalidated", None)
    elif not report["task_patch_unchanged"]:
        metadata.pop("publication_authorization", None)
        metadata["publication_invalidated"] = {
            "commit": after_head,
            "previous_commit": before_head,
            "reason": "effective task patch changed during integration",
            "invalidated_at_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        }
    metadata["last_integration"] = {
        **report,
        "integrated_at_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    write_metadata(root, metadata)
    return report


def command_integrate(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    if args.fetch:
        run_git(root, ["fetch", args.remote, "master"])
    required_master = args.master_ref or ("%s/master" % args.remote if args.fetch else "master")
    if not ref_commit(root, required_master):
        raise CommandError("Could not resolve master ref %r" % required_master)
    report = integrate_ref(root, required_master)
    print(json.dumps(report, indent=2, sort_keys=True))
    if report["approval_still_valid"]:
        print("Task patch is unchanged; existing review and publication approval remain valid.")
    elif report["task_patch_unchanged"]:
        print("Task patch is unchanged; no current publication authorization was recorded.")
    else:
        print("Task patch changed during integration; rerun relevant proof and peer review before requesting publication approval.")
    return 0


def try_update_local_master(repo: Path, branch: str) -> str:
    primary = primary_worktree(repo)
    if current_branch(primary) != "master":
        return "Skipped local master update: primary worktree is on %s." % current_branch(primary)
    status = run_git(primary, ["status", "--short"]).stdout.strip()
    if status:
        return "Skipped local master update: primary worktree has local changes."
    result = run_git(primary, ["merge", "--ff-only", branch], check=False)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        return "Skipped local master update: %s" % detail
    return "Updated local master to %s." % ref_commit(primary, "master")[:12]


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


def command_authorize_publish(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status:
        raise CommandError("Publication authorization requires a clean worktree; found:\n%s" % status)
    head = ref_commit(root, "HEAD")
    metadata = metadata_for(root)
    metadata["publication_authorization"] = {
        "commit": head,
        "branch": branch,
        "reviewer": args.reviewer.strip(),
        "user_approval": args.user_approval.strip(),
        "authorized_at_utc": _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    metadata.pop("publication_invalidated", None)
    write_metadata(root, metadata)
    print(json.dumps({"ok": True, "publication_authorization": metadata["publication_authorization"]}, indent=2, sort_keys=True))
    return 0


def require_publication_authorization(root: Path) -> dict[str, Any]:
    metadata = metadata_for(root)
    head = ref_commit(root, "HEAD")
    authorization = metadata.get("publication_authorization", {})
    if not isinstance(authorization, dict) or str(authorization.get("commit", "")) != head:
        invalidated = metadata.get("publication_invalidated", {})
        detail = ""
        if isinstance(invalidated, dict) and invalidated:
            detail = " Last authorization was invalidated: %s." % str(invalidated.get("reason", "unknown reason"))
        raise CommandError(
            "Refusing publication of %s without authorization for the exact HEAD. After proof, peer signoff, and explicit user approval, run `parallel_task.py authorize-publish --reviewer ... --user-approval ...`.%s"
            % (head[:12], detail)
        )
    if not str(authorization.get("reviewer", "")).strip() or not str(authorization.get("user_approval", "")).strip():
        raise CommandError("Publication authorization is incomplete for %s" % head[:12])
    return authorization


def command_push(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status:
        raise CommandError("Refusing to land dirty worktree %s. Commit or clean changes first." % root)
    require_publication_authorization(root)
    if args.fetch:
        run_git(root, ["fetch", args.remote, "master"])
    required_master = args.master_ref or ("%s/master" % args.remote if args.fetch else "master")
    master_commit = ref_commit(root, required_master)
    if not master_commit:
        raise CommandError("Could not resolve master ref %r" % required_master)
    branch_commit = ref_commit(root, branch)
    if not is_ancestor(root, required_master, branch):
        if not args.auto_integrate:
            raise CommandError(
                "Refusing to push %s because %s (%s) is not contained. Run `parallel_task.py integrate`."
                % (branch, required_master, master_commit[:12])
            )
        report = integrate_ref(root, required_master)
        print(json.dumps({"integration": report}, indent=2, sort_keys=True))
        if not report["task_patch_unchanged"]:
            raise CommandError(
                "Integrated %s, but the effective task patch changed. The branch was not pushed; rerun relevant proof and peer review, then obtain publication approval for the updated branch."
                % required_master
            )
        require_publication_authorization(root)
        print("Integrated %s mechanically; the approved task patch is unchanged." % required_master)
        branch_commit = ref_commit(root, branch)
    run_git(root, ["push", args.remote, "%s:master" % branch])
    run_git(root, ["update-ref", "refs/remotes/%s/master" % args.remote, branch_commit], check=False)
    print("Pushed %s (%s) to %s/master" % (branch, branch_commit[:12], args.remote))
    if args.update_local_master:
        print(try_update_local_master(root, branch))
    return 0


def command_cleanup(args: argparse.Namespace) -> int:
    root = repo_root(Path(args.repo).resolve())
    branch = require_task_branch(root)
    primary = primary_worktree(root)
    status = run_git(root, ["status", "--short"]).stdout.strip()
    if status and not args.force:
        raise CommandError("Refusing to remove dirty worktree %s. Commit, clean, or pass --force." % root)
    if args.require_pushed:
        landed_refs = args.landed_ref or ["origin/master", "master"]
        landed_ref = first_landed_ref(root, branch, landed_refs)
        if not landed_ref:
            raise CommandError(
                "Refusing cleanup before %s is reachable from master. "
                "Land it with `python3 tools/parallel_task.py push` first or pass --no-require-pushed."
                % branch
            )
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

    prepare_worker = sub.add_parser("prepare-worker", help="Create a task branch before an app-visible worker thread is created.")
    prepare_worker.add_argument("--task", default="", help="Human task description used to derive an id.")
    prepare_worker.add_argument("--task-id", default="", help="Stable task id.")
    prepare_worker.add_argument("--branch", default="", help="Explicit branch name; must start with codex/.")
    prepare_worker.add_argument("--base", default="", help="Base ref. Defaults to local master.")
    prepare_worker.add_argument("--fetch", action="store_true", default=False)
    prepare_worker.add_argument("--reuse", action="store_true", help="Reuse the branch only when it still equals the requested base.")
    prepare_worker.add_argument("--dry-run", action="store_true")
    prepare_worker.set_defaults(func=command_prepare_worker)

    status = sub.add_parser("status", help="Report task/worktree status.")
    status.set_defaults(func=command_status)

    contract = sub.add_parser("contract", help="Record the task's acceptance, proof, and inspection contract.")
    contract.add_argument("--risk-tier", choices=RISK_TIERS, default="")
    contract.add_argument("--acceptance", action="append", default=None, help="Observable acceptance criterion; repeatable.")
    contract.add_argument("--required-proof", action="append", default=None, help="Required proof item; repeatable.")
    contract.add_argument("--inspection-expectation", default=None, help="Playable inspection target or a not-applicable reason.")
    contract.set_defaults(func=command_contract)

    preflight = sub.add_parser("preflight", help="Prove task branch, contract, object database, and Git index writes before editing.")
    preflight.add_argument("--allow-dirty", action="store_true", help="Allow a dirty worktree for diagnostic use.")
    preflight.add_argument("--allow-draft-contract", action="store_true", help="Do not fail when the acceptance contract is incomplete.")
    preflight.add_argument("--master-ref", default="master", help="Master ref used for ahead/behind and containment reporting.")
    preflight.set_defaults(func=command_preflight)

    env = sub.add_parser("env", help="Print environment variables for parallel-safe Godot runs.")
    env.add_argument("--task-id", default="", help="Override task id.")
    env.add_argument("--format", choices=["shell", "json"], default="shell")
    env.set_defaults(func=command_env)

    commit = sub.add_parser("commit", help="Commit all changes in the task worktree.")
    commit.add_argument("-m", "--message", required=True)
    commit.add_argument("--allow-empty", action="store_true")
    commit.set_defaults(func=command_commit)

    authorize_publish = sub.add_parser("authorize-publish", help="Record peer signoff and explicit user approval for the exact current HEAD.")
    authorize_publish.add_argument("--reviewer", required=True, help="Peer reviewer identity that signed off on this HEAD.")
    authorize_publish.add_argument("--user-approval", required=True, help="Reference or concise note for the user's explicit publication approval.")
    authorize_publish.set_defaults(func=command_authorize_publish)

    integrate = sub.add_parser("integrate", help="Integrate current master and report whether the effective task patch changed.")
    integrate.add_argument("--remote", default="origin")
    integrate.add_argument("--master-ref", default="")
    integrate.add_argument("--fetch", dest="fetch", action="store_true", default=True)
    integrate.add_argument("--no-fetch", dest="fetch", action="store_false")
    integrate.set_defaults(func=command_integrate)

    push = sub.add_parser("push", help="Land the approved task branch on remote master.")
    push.add_argument("--remote", default="origin")
    push.add_argument("--master-ref", default="", help="Ref that must be contained in the task branch. Defaults to remote/master after fetch.")
    push.add_argument("--fetch", dest="fetch", action="store_true", default=True, help="Fetch remote master before landing.")
    push.add_argument("--no-fetch", dest="fetch", action="store_false", help="Do not fetch before landing.")
    push.add_argument("--auto-integrate", dest="auto_integrate", action="store_true", default=True, help="Mechanically integrate newer master when the effective task patch stays unchanged.")
    push.add_argument("--no-auto-integrate", dest="auto_integrate", action="store_false")
    push.add_argument("--update-local-master", dest="update_local_master", action="store_true", default=True, help="Fast-forward the primary local master checkout when it is clean.")
    push.add_argument("--no-update-local-master", dest="update_local_master", action="store_false", help="Do not update the primary local master checkout after pushing.")
    push.set_defaults(func=command_push)

    cleanup = sub.add_parser("cleanup", help="Remove a completed task worktree.")
    cleanup.add_argument("--force", action="store_true")
    cleanup.add_argument("--require-pushed", dest="require_pushed", action="store_true", default=True, help="Require the task branch to be reachable from master before cleanup.")
    cleanup.add_argument("--no-require-pushed", dest="require_pushed", action="store_false", help="Allow cleanup before the task branch is reachable from master.")
    cleanup.add_argument("--landed-ref", action="append", default=[], help="Ref that may prove the task is landed; repeatable. Defaults to origin/master and master.")
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
