#!/usr/bin/env python3
"""Manage the Labyrinth autonomous task queue."""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from typing import Any


STATUSES = {
    "proposed",
    "needs_revision",
    "ready",
    "leased",
    "in_progress",
    "implementation_review",
    "ready_for_user",
    "approved_to_land",
    "done",
    "rejected",
    "abandoned",
    "blocked",
}
ACTIVE_STATUSES = {
    "leased",
    "in_progress",
    "implementation_review",
    "ready_for_user",
    "approved_to_land",
}
SCOUT_REVIEW_RESULTS = {
    "approved": "ready",
    "request_changes": "needs_revision",
    "rejected": "rejected",
}
DEFAULT_QUEUE_ROOT_ENV = "LABYRINTH_TASK_QUEUE_ROOT"
RISK_TIERS = {"low", "standard", "high"}
ESTIMATED_SIZES = {"small", "medium", "large"}
CURRENT_SCHEMA_VERSION = 2


class QueueError(RuntimeError):
    pass


def utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "task")[:72]


def run_git(repo: Path, args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise QueueError("git %s failed: %s" % (" ".join(args), detail))
    return result


def repo_root(path: Path) -> Path:
    result = run_git(path, ["rev-parse", "--show-toplevel"], check=False)
    if result.returncode != 0:
        return path.resolve()
    return Path(result.stdout.strip()).resolve()


def primary_worktree(repo: Path) -> Path:
    result = run_git(repo, ["worktree", "list", "--porcelain"], check=False)
    if result.returncode != 0:
        return repo
    for line in result.stdout.splitlines():
        if line.startswith("worktree "):
            return Path(line.removeprefix("worktree ")).resolve()
    return repo


def default_queue_root(repo: Path) -> Path:
    override = os.environ.get(DEFAULT_QUEUE_ROOT_ENV, "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return primary_worktree(repo_root(repo)) / ".codex" / "tasks"


def queue_dirs(queue_root: Path) -> tuple[Path, Path]:
    return queue_root / "queue", queue_root / "archive"


def ensure_queue(queue_root: Path) -> None:
    queue_dir, archive_dir = queue_dirs(queue_root)
    queue_dir.mkdir(parents=True, exist_ok=True)
    archive_dir.mkdir(parents=True, exist_ok=True)


def task_path(queue_root: Path, task_id: str) -> Path:
    return queue_root / "queue" / ("%s.json" % task_id)


def archive_path(queue_root: Path, task_id: str) -> Path:
    return queue_root / "archive" / ("%s.json" % task_id)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise QueueError("%s is not valid JSON: %s" % (path, exc)) from exc


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    tmp_path.replace(path)


def iter_task_files(queue_root: Path, *, include_archive: bool = False) -> list[Path]:
    queue_dir, archive_dir = queue_dirs(queue_root)
    paths = sorted(queue_dir.glob("*.json")) if queue_dir.exists() else []
    if include_archive and archive_dir.exists():
        paths.extend(sorted(archive_dir.glob("*.json")))
    return paths


def load_task(queue_root: Path, task_id: str, *, include_archive: bool = False) -> dict[str, Any]:
    paths = [task_path(queue_root, task_id)]
    if include_archive:
        paths.append(archive_path(queue_root, task_id))
    for path in paths:
        if path.exists():
            payload = load_json(path)
            if not isinstance(payload, dict):
                raise QueueError("%s must contain a JSON object" % path)
            return payload
    raise QueueError("No queued task found for id %r" % task_id)


def load_tasks(queue_root: Path, *, include_archive: bool = False) -> list[dict[str, Any]]:
    tasks: list[dict[str, Any]] = []
    for path in iter_task_files(queue_root, include_archive=include_archive):
        payload = load_json(path)
        if not isinstance(payload, dict):
            raise QueueError("%s must contain a JSON object" % path)
        tasks.append(payload)
    return tasks


def as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def text_list(value: Any) -> list[str]:
    return [str(item).strip() for item in as_list(value) if str(item).strip()]


def normalize_path(value: str) -> str:
    path = value.strip().replace("\\", "/")
    while path.startswith("./"):
        path = path[2:]
    return path.strip("/")


def normalize_paths(value: Any) -> list[str]:
    seen: set[str] = set()
    paths: list[str] = []
    for raw in text_list(value):
        path = normalize_path(raw)
        if path and path not in seen:
            paths.append(path)
            seen.add(path)
    return paths


def normalize_parallel_safety(value: Any) -> dict[str, Any]:
    raw = value if isinstance(value, dict) else {}
    return {
        "likely_touched_files": normalize_paths(raw.get("likely_touched_files")),
        "shared_state_risks": text_list(raw.get("shared_state_risks")),
        "safe_parallel_neighbors": text_list(raw.get("safe_parallel_neighbors")),
        "avoid_parallel_with": text_list(raw.get("avoid_parallel_with")),
        "notes": str(raw.get("notes", "")).strip(),
    }


def normalize_proposal(value: Any) -> dict[str, Any]:
    raw = value if isinstance(value, dict) else {}
    risk_tier = str(raw.get("risk_tier", "standard")).strip().lower()
    if not risk_tier:
        risk_tier = "standard"
    return {
        "problem": str(raw.get("problem", "")).strip(),
        "why_now": str(raw.get("why_now", "")).strip(),
        "proposed_change": str(raw.get("proposed_change", "")).strip(),
        "impact": str(raw.get("impact", "")).strip(),
        "risk": str(raw.get("risk", "")).strip(),
        "estimated_size": str(raw.get("estimated_size", "")).strip(),
        "risk_tier": risk_tier,
        "acceptance_criteria": text_list(raw.get("acceptance_criteria")),
        "required_proof": text_list(raw.get("required_proof")),
        "rejection_conditions": text_list(raw.get("rejection_conditions")),
    }


def existing_ids(queue_root: Path) -> set[str]:
    ids: set[str] = set()
    for path in iter_task_files(queue_root, include_archive=True):
        ids.add(path.stem)
    return ids


def unique_task_id(queue_root: Path, preferred: str) -> str:
    used = existing_ids(queue_root)
    base = slugify(preferred)
    task_id = base
    suffix = 2
    while task_id in used:
        task_id = "%s-%d" % (base, suffix)
        suffix += 1
    return task_id


def normalize_task(raw: dict[str, Any], queue_root: Path, *, default_status: str, reviewer: str, review_summary: str) -> dict[str, Any]:
    proposal = normalize_proposal(raw.get("proposal"))
    title = str(raw.get("title") or raw.get("name") or proposal.get("problem") or "Untitled task").strip()
    task_id = str(raw.get("id") or raw.get("task_id") or "").strip()
    if task_id:
        task_id = slugify(task_id)
        if task_path(queue_root, task_id).exists() or archive_path(queue_root, task_id).exists():
            raise QueueError("Task id %r already exists" % task_id)
    else:
        task_id = unique_task_id(queue_root, title)
    status = str(default_status or raw.get("status") or "proposed").strip()
    if status not in STATUSES:
        raise QueueError("Unknown task status %r for %s" % (status, task_id))
    now = utc_now()
    task: dict[str, Any] = {
        "schema_version": CURRENT_SCHEMA_VERSION,
        "id": task_id,
        "title": title,
        "status": status,
        "priority": int(raw.get("priority", 3)),
        "created_at_utc": str(raw.get("created_at_utc") or now),
        "updated_at_utc": now,
        "proposal": proposal,
        "parallel_safety": normalize_parallel_safety(raw.get("parallel_safety")),
        "scout_review": raw.get("scout_review") if isinstance(raw.get("scout_review"), dict) else {},
        "worker": raw.get("worker") if isinstance(raw.get("worker"), dict) else {},
        "implementation_review": raw.get("implementation_review") if isinstance(raw.get("implementation_review"), dict) else {},
        "history": as_list(raw.get("history")),
    }
    if status == "ready" and task["scout_review"].get("status") != "approved":
        if not reviewer:
            raise QueueError("Ready task %s needs an approved scout_review or --reviewer" % task_id)
        task["scout_review"] = {
            "status": "approved",
            "reviewer": reviewer,
            "reviewed_at_utc": now,
            "summary": review_summary,
        }
    task["history"].append({"at_utc": now, "actor": "queue-import", "status": status, "note": "imported"})
    validate_task(task)
    return task


def validate_task(task: dict[str, Any]) -> None:
    for key in ("schema_version", "id", "title", "status", "priority", "proposal", "parallel_safety", "history"):
        if key not in task:
            raise QueueError("Task missing required field: %s" % key)
    if task["schema_version"] not in {1, CURRENT_SCHEMA_VERSION}:
        raise QueueError("Unsupported schema_version for %s: %r" % (task.get("id"), task.get("schema_version")))
    strict_contract = task["schema_version"] >= CURRENT_SCHEMA_VERSION
    if task["status"] not in STATUSES:
        raise QueueError("Unknown status for %s: %r" % (task["id"], task["status"]))
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,71}", str(task["id"])):
        raise QueueError("Invalid task id: %r" % task["id"])
    if not str(task["title"]).strip():
        raise QueueError("Task %s needs a title" % task["id"])
    proposal = task["proposal"]
    if not isinstance(proposal, dict):
        raise QueueError("Task %s proposal must be an object" % task["id"])
    for key in ("acceptance_criteria", "required_proof", "rejection_conditions"):
        if not isinstance(proposal.get(key), list):
            raise QueueError("Task %s proposal.%s must be a list" % (task["id"], key))
    if proposal.get("risk_tier", "standard") not in RISK_TIERS:
        raise QueueError("Task %s proposal.risk_tier must be one of %s" % (task["id"], ", ".join(sorted(RISK_TIERS))))
    if strict_contract:
        for key in ("problem", "why_now", "proposed_change", "impact", "risk"):
            if not str(proposal.get(key, "")).strip():
                raise QueueError("Task %s proposal.%s must not be empty" % (task["id"], key))
        if proposal.get("estimated_size") not in ESTIMATED_SIZES:
            raise QueueError("Task %s proposal.estimated_size must be one of %s" % (task["id"], ", ".join(sorted(ESTIMATED_SIZES))))
        for key, label in (
            ("acceptance_criteria", "observable acceptance criteria"),
            ("required_proof", "required proof"),
            ("rejection_conditions", "rejection conditions"),
        ):
            if not proposal.get(key):
                raise QueueError("Task %s needs %s" % (task["id"], label))
    safety = task["parallel_safety"]
    if not isinstance(safety, dict):
        raise QueueError("Task %s parallel_safety must be an object" % task["id"])
    for key in ("likely_touched_files", "shared_state_risks", "safe_parallel_neighbors", "avoid_parallel_with"):
        if not isinstance(safety.get(key), list):
            raise QueueError("Task %s parallel_safety.%s must be a list" % (task["id"], key))
    if strict_contract and not safety.get("likely_touched_files"):
        raise QueueError("Task %s needs concrete parallel_safety.likely_touched_files" % task["id"])
    if task["status"] == "ready" and task.get("scout_review", {}).get("status") != "approved":
        raise QueueError("Task %s is ready without approved scout_review" % task["id"])


def append_history(task: dict[str, Any], *, actor: str, status: str, note: str) -> None:
    task.setdefault("history", [])
    task["history"].append({"at_utc": utc_now(), "actor": actor, "status": status, "note": note})
    task["updated_at_utc"] = utc_now()


def path_conflicts(left: str, right: str) -> bool:
    a = normalize_path(left)
    b = normalize_path(right)
    if not a or not b:
        return False
    return a == b or a.startswith(b + "/") or b.startswith(a + "/")


def normalized_text_set(value: Any) -> set[str]:
    return {str(item).strip().lower() for item in as_list(value) if str(item).strip()}


def conflict_report(candidate: dict[str, Any], active_tasks: list[dict[str, Any]]) -> dict[str, Any]:
    candidate_paths = candidate.get("parallel_safety", {}).get("likely_touched_files", [])
    candidate_id = str(candidate.get("id", ""))
    candidate_risks = normalized_text_set(candidate.get("parallel_safety", {}).get("shared_state_risks", []))
    candidate_avoid_ids = set(candidate.get("parallel_safety", {}).get("avoid_parallel_with", []))
    conflicts: list[dict[str, Any]] = []
    score = 0
    for active in active_tasks:
        active_id = str(active.get("id", ""))
        active_safety = active.get("parallel_safety", {})
        active_paths = active_safety.get("likely_touched_files", [])
        active_risks = normalized_text_set(active_safety.get("shared_state_risks", []))
        active_avoid_ids = set(active_safety.get("avoid_parallel_with", []))
        overlaps = [
            {"candidate_path": left, "active_path": right}
            for left in candidate_paths
            for right in active_paths
            if path_conflicts(left, right)
        ]
        shared_risks = sorted(candidate_risks & active_risks)
        candidate_avoids_active = active_id in candidate_avoid_ids
        active_avoids_candidate = candidate_id in active_avoid_ids
        explicit_avoid = candidate_avoids_active or active_avoids_candidate
        if overlaps or shared_risks or explicit_avoid:
            weight = len(overlaps) * 10 + len(shared_risks) * 8 + (25 if explicit_avoid else 0)
            score += weight
            conflicts.append(
                {
                    "active_task": active_id,
                    "active_status": active.get("status", ""),
                    "weight": weight,
                    "candidate_avoids_active": candidate_avoids_active,
                    "active_avoids_candidate": active_avoids_candidate,
                    "explicit_avoid": explicit_avoid,
                    "path_overlaps": overlaps,
                    "shared_state_overlaps": shared_risks,
                }
            )
    return {"conflict_score": score, "conflicts": conflicts}


def command_init(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    ensure_queue(queue_root)
    print("Initialized Labyrinth task queue at %s" % queue_root)
    return 0


def raw_tasks_from_file(path: Path) -> list[dict[str, Any]]:
    payload = load_json(path)
    if isinstance(payload, dict) and isinstance(payload.get("tasks"), list):
        raw_tasks = payload["tasks"]
    elif isinstance(payload, list):
        raw_tasks = payload
    elif isinstance(payload, dict):
        raw_tasks = [payload]
    else:
        raise QueueError("Import payload must be an object, list, or object with tasks")
    tasks: list[dict[str, Any]] = []
    for raw in raw_tasks:
        if not isinstance(raw, dict):
            raise QueueError("Each imported task must be a JSON object")
        tasks.append(raw)
    return tasks


def command_import(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    ensure_queue(queue_root)
    raw_tasks = raw_tasks_from_file(Path(args.file).resolve())
    written: list[dict[str, Any]] = []
    for raw in raw_tasks:
        task = normalize_task(
            raw,
            queue_root,
            default_status=args.status,
            reviewer=args.reviewer,
            review_summary=args.review_summary,
        )
        write_json(task_path(queue_root, task["id"]), task)
        written.append(task)
    if args.json:
        print(json.dumps(written, indent=2, sort_keys=True))
    else:
        for task in written:
            print("Imported %s [%s] %s" % (task["id"], task["status"], task["title"]))
    return 0


def command_validate(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    paths = [Path(path).resolve() for path in args.files]
    if not paths:
        paths = iter_task_files(queue_root, include_archive=args.include_archive)
    for path in paths:
        payload = load_json(path)
        if isinstance(payload, dict) and isinstance(payload.get("tasks"), list):
            for raw in payload["tasks"]:
                normalize_task(raw, queue_root, default_status="proposed", reviewer="", review_summary="")
        elif isinstance(payload, list):
            for raw in payload:
                normalize_task(raw, queue_root, default_status="proposed", reviewer="", review_summary="")
        elif isinstance(payload, dict) and "schema_version" in payload:
            validate_task(payload)
        elif isinstance(payload, dict):
            normalize_task(payload, queue_root, default_status="proposed", reviewer="", review_summary="")
        else:
            raise QueueError("%s is not a task payload" % path)
        print("OK %s" % path)
    return 0


def command_list(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    tasks = load_tasks(queue_root, include_archive=args.include_archive)
    if args.status:
        allowed = set(args.status)
        tasks = [task for task in tasks if task.get("status") in allowed]
    tasks.sort(key=lambda task: (str(task.get("status")), -int(task.get("priority", 0)), str(task.get("id"))))
    if args.json:
        print(json.dumps(tasks, indent=2, sort_keys=True))
    else:
        for task in tasks:
            print("%-22s %-21s p%s  %s" % (task.get("id", ""), task.get("status", ""), task.get("priority", ""), task.get("title", "")))
    return 0


def command_show(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id, include_archive=args.include_archive)
    print(json.dumps(task, indent=2, sort_keys=True))
    return 0


def command_select(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    tasks = load_tasks(queue_root)
    active = [task for task in tasks if task.get("status") in ACTIVE_STATUSES]
    ready = [task for task in tasks if task.get("status") == "ready"]
    ranked: list[dict[str, Any]] = []
    for task in ready:
        report = conflict_report(task, active)
        item = {
            "id": task["id"],
            "title": task["title"],
            "priority": task.get("priority", 0),
            "likely_touched_files": task.get("parallel_safety", {}).get("likely_touched_files", []),
            **report,
        }
        ranked.append(item)
    ranked.sort(key=lambda item: (int(item["conflict_score"]), -int(item["priority"]), str(item["id"])))
    if args.limit:
        ranked = ranked[: args.limit]
    if args.json:
        print(json.dumps(ranked, indent=2, sort_keys=True))
    else:
        for item in ranked:
            label = "clear" if item["conflict_score"] == 0 else "conflicts=%s" % item["conflict_score"]
            print("%-22s p%s  %-12s %s" % (item["id"], item["priority"], label, item["title"]))
    return 0


def command_scout_review(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id)
    result = args.result
    next_status = SCOUT_REVIEW_RESULTS[result]
    task["scout_review"] = {
        "status": result,
        "reviewer": args.reviewer,
        "reviewed_at_utc": utc_now(),
        "summary": args.summary,
    }
    task["status"] = next_status
    append_history(task, actor=args.reviewer, status=next_status, note="scout review: %s" % args.summary)
    validate_task(task)
    write_json(task_path(queue_root, task["id"]), task)
    print("%s -> %s" % (task["id"], next_status))
    return 0


def command_lease(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id)
    if task.get("status") != "ready" and not args.force:
        raise QueueError("Task %s is %s, not ready. Pass --force to lease anyway." % (args.task_id, task.get("status")))
    now = utc_now()
    task["status"] = "leased"
    task["worker"] = {
        "thread_id": args.thread_id,
        "branch": args.branch,
        "worktree_path": args.worktree,
        "leased_by": args.worker,
        "leased_at_utc": now,
        "heartbeat_at_utc": now,
    }
    append_history(task, actor=args.worker, status="leased", note=args.note or "leased to worker")
    validate_task(task)
    write_json(task_path(queue_root, task["id"]), task)
    print("%s leased to %s" % (task["id"], args.thread_id or args.worker))
    return 0


def command_heartbeat(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id)
    task.setdefault("worker", {})
    task["worker"]["heartbeat_at_utc"] = utc_now()
    append_history(task, actor=args.actor, status=str(task.get("status")), note=args.note or "heartbeat")
    validate_task(task)
    write_json(task_path(queue_root, task["id"]), task)
    print("%s heartbeat" % task["id"])
    return 0


def command_mark(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id)
    task["status"] = args.status
    append_history(task, actor=args.actor, status=args.status, note=args.note)
    validate_task(task)
    write_json(task_path(queue_root, task["id"]), task)
    print("%s -> %s" % (task["id"], args.status))
    return 0


def verify_fixture_manifest(
    manifest_path: Path,
    expected_task_id: str,
    *,
    expected_commit: str = "",
    expected_branch: str = "",
) -> tuple[dict[str, Any], str]:
    path = manifest_path.expanduser().resolve()
    try:
        raw_bytes = path.read_bytes()
    except OSError as exc:
        raise QueueError("Could not read inspection manifest %s: %s" % (path, exc)) from exc
    fixture_manifest = load_json(path)
    if not isinstance(fixture_manifest, dict) or fixture_manifest.get("schema_version") != 2:
        raise QueueError("Inspection manifest must use schema_version 2 with structured verification metadata")
    if str(fixture_manifest.get("task_id", "")) != expected_task_id:
        raise QueueError("Inspection manifest task id %r does not match %r" % (fixture_manifest.get("task_id"), expected_task_id))
    required_text = ("run_id", "scenario", "summary", "launch_command", "project")
    missing = [key for key in required_text if not str(fixture_manifest.get(key, "")).strip()]
    if missing:
        raise QueueError("Inspection manifest is missing required field(s): %s" % ", ".join(missing))
    verification = fixture_manifest.get("verification", {})
    if not isinstance(verification, dict):
        raise QueueError("Inspection manifest verification must be an object")
    if verification.get("runner") != "tools/godot_task_runner.py" or verification.get("script") != "tools/inspection_fixture_verify.gd":
        raise QueueError("Inspection manifest does not name the standard fixture verifier")
    godot = str(verification.get("godot", "")).strip()
    if Path(godot).name.lower() not in {"godot", "godot4"}:
        raise QueueError("Inspection manifest Godot executable must be godot or godot4")
    godot_home_root = str(verification.get("godot_home_root", "")).strip()
    if not godot_home_root:
        raise QueueError("Inspection manifest needs verification.godot_home_root")
    project = Path(str(fixture_manifest["project"])).expanduser().resolve()
    if not (project / "tools" / "godot_task_runner.py").is_file() or not (project / "tools" / "inspection_fixture_verify.gd").is_file():
        raise QueueError("Inspection manifest project does not contain the standard fixture verifier: %s" % project)
    status = run_git(project, ["status", "--short"], check=False)
    if status.returncode != 0 or status.stdout.strip():
        raise QueueError("Inspection fixture project must be a clean Git worktree before verification")
    project_head = run_git(project, ["rev-parse", "HEAD"]).stdout.strip()
    if expected_commit and project_head != expected_commit:
        raise QueueError("Inspection fixture project HEAD %s does not match reviewed commit %s" % (project_head[:12], expected_commit[:12]))
    project_branch = run_git(project, ["branch", "--show-current"]).stdout.strip()
    if expected_branch and project_branch != expected_branch:
        raise QueueError("Inspection fixture project branch %r does not match reviewed branch %r" % (project_branch, expected_branch))
    command = [
        sys.executable,
        str(project / "tools" / "godot_task_runner.py"),
        "--project",
        str(project),
        "--task-id",
        expected_task_id,
        "--run-id",
        str(fixture_manifest["run_id"]),
        "--godot-home-root",
        godot_home_root,
        "--",
        godot,
        "--headless",
        "--path",
        ".",
        "--script",
        "tools/inspection_fixture_verify.gd",
    ]
    try:
        result = subprocess.run(command, cwd=str(project), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as exc:
        raise QueueError("Could not run the standard inspection verifier: %s" % exc) from exc
    combined = result.stdout + "\n" + result.stderr
    if result.returncode != 0 or "INSPECTION_FIXTURE_VERIFIED " not in combined:
        detail = combined.strip()[-2000:]
        raise QueueError("Inspection manifest state evidence failed independent verification: %s" % detail)
    return fixture_manifest, hashlib.sha256(raw_bytes).hexdigest()


def command_handoff(args: argparse.Namespace) -> int:
    repo = repo_root(Path(args.repo))
    commit_ref = args.commit or "HEAD"
    resolved_commit = run_git(repo, ["rev-parse", "--verify", "%s^{commit}" % commit_ref], check=False)
    if resolved_commit.returncode != 0:
        raise QueueError("Handoff commit %r does not resolve in %s" % (commit_ref, repo))
    commit = resolved_commit.stdout.strip()
    branch = run_git(repo, ["branch", "--show-current"]).stdout.strip()
    if args.inspection_manifest:
        manifest_path = Path(args.inspection_manifest).expanduser().resolve()
        fixture_manifest, manifest_sha256 = verify_fixture_manifest(
            manifest_path,
            args.task_id,
            expected_commit=commit,
            expected_branch=branch,
        )
        inspection_fixture = {
            "applicable": True,
            "scenario": str(fixture_manifest.get("scenario", "")),
            "run_id": str(fixture_manifest.get("run_id", "")),
            "summary": str(fixture_manifest.get("summary", "")),
            "launch_command": str(fixture_manifest.get("launch_command", "")),
            "manifest": str(manifest_path),
            "manifest_sha256": manifest_sha256,
        }
        if not inspection_fixture["summary"] or not inspection_fixture["launch_command"]:
            raise QueueError("Verified inspection manifest needs summary and launch_command")
    elif args.inspection_not_applicable:
        inspection_fixture = {"applicable": False, "reason": args.inspection_not_applicable}
    else:
        raise QueueError("Handoff needs --inspection-manifest or --inspection-not-applicable")
    payload = {
        "schema_version": 1,
        "task_id": args.task_id,
        "branch": branch,
        "commit": commit,
        "reviewer": args.reviewer,
        "signoff": args.signoff,
        "proof": args.proof,
        "residual_risks": args.residual_risk,
        "inspection_fixture": inspection_fixture,
        "created_at_utc": utc_now(),
    }
    output = Path(args.output).expanduser().resolve() if args.output else (
        Path("/private/tmp/labyrinth-task-handoffs") / (slugify(args.task_id) + ".json")
    )
    write_json(output, payload)
    print("Wrote verified task handoff: %s" % output)
    print(
        "Queue completion command: python3 tools/labyrinth_task_queue.py complete %s --handoff-file %s"
        % (shlex.quote(args.task_id), shlex.quote(str(output)))
    )
    return 0


def command_complete(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id)
    handoff: dict[str, Any] = {}
    if args.handoff_file:
        raw_handoff = load_json(Path(args.handoff_file).expanduser().resolve())
        if not isinstance(raw_handoff, dict):
            raise QueueError("--handoff-file must contain a JSON object")
        if str(raw_handoff.get("task_id", "")) != args.task_id:
            raise QueueError("Handoff task id %r does not match %r" % (raw_handoff.get("task_id"), args.task_id))
        handoff = raw_handoff
    reviewer = str(handoff.get("reviewer", args.reviewer)).strip()
    signoff = str(handoff.get("signoff", args.signoff)).strip()
    proof_value = handoff.get("proof", args.proof)
    proof = "; ".join(str(item) for item in proof_value) if isinstance(proof_value, list) else str(proof_value).strip()
    commit = str(handoff.get("commit", args.commit)).strip()
    residual_risks = handoff.get("residual_risks", [])
    if not reviewer or not signoff or not proof or not commit:
        raise QueueError("Ready-for-user handoff needs reviewer, signoff, proof, and commit")
    repo = repo_root(Path(args.repo))
    resolved_commit = run_git(repo, ["rev-parse", "--verify", "%s^{commit}" % commit], check=False)
    if resolved_commit.returncode != 0:
        raise QueueError("Handoff commit %r does not resolve in %s" % (commit, repo))
    commit = resolved_commit.stdout.strip()
    handoff_branch = str(handoff.get("branch", "")).strip()
    if handoff_branch:
        branch_commit = run_git(repo, ["rev-parse", "--verify", "%s^{commit}" % handoff_branch], check=False)
        if branch_commit.returncode != 0 or branch_commit.stdout.strip() != commit:
            raise QueueError("Handoff branch %r does not point to reviewed commit %s" % (handoff_branch, commit[:12]))
    handoff_fixture = handoff.get("inspection_fixture", {})
    if not isinstance(handoff_fixture, dict):
        raise QueueError("Handoff inspection_fixture must be an object")
    inspection_recorded_at = utc_now()
    not_applicable_reason = str(handoff_fixture.get("reason", "")) if handoff_fixture.get("applicable") is False else args.inspection_not_applicable
    if not_applicable_reason:
        inspection_fixture = {
            "applicable": False,
            "recorded_at_utc": inspection_recorded_at,
            "reason": not_applicable_reason,
        }
    else:
        if not args.handoff_file:
            raise QueueError("Applicable inspection fixtures require --handoff-file built from a verified manifest")
        fixture_manifest_path = str(handoff_fixture.get("manifest", "")).strip()
        expected_manifest_sha256 = str(handoff_fixture.get("manifest_sha256", "")).strip()
        if not fixture_manifest_path or not expected_manifest_sha256:
            raise QueueError("Applicable inspection handoff needs manifest and manifest_sha256 evidence")
        fixture_manifest, actual_manifest_sha256 = verify_fixture_manifest(
            Path(fixture_manifest_path),
            args.task_id,
            expected_commit=commit,
            expected_branch=handoff_branch,
        )
        if actual_manifest_sha256 != expected_manifest_sha256:
            raise QueueError("Inspection manifest changed after worker handoff was created")
        for key in ("scenario", "run_id", "summary", "launch_command"):
            if str(handoff_fixture.get(key, "")) != str(fixture_manifest.get(key, "")):
                raise QueueError("Inspection handoff field %s does not match its verified manifest" % key)
        inspection_summary = str(handoff_fixture.get("summary", args.inspection_summary)).strip()
        inspection_launch = str(handoff_fixture.get("launch_command", args.inspection_launch)).strip()
        if not inspection_summary:
            raise QueueError("Ready-for-user handoff needs --inspection-summary, or --inspection-not-applicable with a reason.")
        if not inspection_launch:
            raise QueueError("Ready-for-user handoff needs --inspection-launch, or --inspection-not-applicable with a reason.")
        inspection_fixture = {
            "applicable": True,
            "recorded_at_utc": inspection_recorded_at,
            "scenario": str(handoff_fixture.get("scenario", args.inspection_scenario)),
            "run_id": str(handoff_fixture.get("run_id", args.inspection_run_id)),
            "summary": inspection_summary,
            "launch_command": inspection_launch,
            "manifest": str(handoff_fixture.get("manifest", "")),
            "manifest_sha256": actual_manifest_sha256,
        }
    task["status"] = "ready_for_user"
    task["implementation_review"] = {
        "status": "signoff",
        "reviewer": reviewer,
        "reviewed_at_utc": utc_now(),
        "signoff_summary": signoff,
        "proof_summary": proof,
        "head_commit": commit,
        "residual_risks": residual_risks,
    }
    task["inspection_fixture"] = inspection_fixture
    append_history(task, actor=args.actor, status="ready_for_user", note="implementation reviewed and ready for user")
    validate_task(task)
    write_json(task_path(queue_root, task["id"]), task)
    print("%s ready_for_user" % task["id"])
    return 0


def command_landed(args: argparse.Namespace) -> int:
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else default_queue_root(Path(args.repo))
    task = load_task(queue_root, args.task_id)
    task["status"] = "done"
    task["landed"] = {
        "branch": "master",
        "commit": args.commit,
        "pushed_at_utc": utc_now(),
        "pushed_by": args.actor,
    }
    append_history(task, actor=args.actor, status="done", note=args.note or "landed on master")
    validate_task(task)
    src = task_path(queue_root, task["id"])
    if args.archive:
        write_json(archive_path(queue_root, task["id"]), task)
        src.unlink(missing_ok=True)
        print("%s done and archived" % task["id"])
    else:
        write_json(src, task)
        print("%s done" % task["id"])
    return 0


def command_board(args: argparse.Namespace) -> int:
    import labyrinth_queue_board

    return labyrinth_queue_board.serve(args)


def add_common(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", default=".", help="Repository/worktree path used to locate the default queue.")
    parser.add_argument("--queue-root", default="", help="Queue root. Defaults to primary worktree .codex/tasks.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common(parser)
    sub = parser.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init", help="Create queue directories.")
    init.set_defaults(func=command_init)

    import_parser = sub.add_parser("import", help="Import reviewed task JSON.")
    import_parser.add_argument("--file", required=True)
    import_parser.add_argument("--status", choices=sorted(STATUSES), default="ready")
    import_parser.add_argument("--reviewer", default="", help="Scout reviewer name when importing ready tasks.")
    import_parser.add_argument("--review-summary", default="")
    import_parser.add_argument("--json", action="store_true")
    import_parser.set_defaults(func=command_import)

    validate = sub.add_parser("validate", help="Validate queued tasks or task payload files.")
    validate.add_argument("files", nargs="*")
    validate.add_argument("--include-archive", action="store_true")
    validate.set_defaults(func=command_validate)

    list_parser = sub.add_parser("list", help="List tasks.")
    list_parser.add_argument("--status", action="append", choices=sorted(STATUSES))
    list_parser.add_argument("--include-archive", action="store_true")
    list_parser.add_argument("--json", action="store_true")
    list_parser.set_defaults(func=command_list)

    show = sub.add_parser("show", help="Print one task as JSON.")
    show.add_argument("task_id")
    show.add_argument("--include-archive", action="store_true")
    show.set_defaults(func=command_show)

    select = sub.add_parser("select", help="Rank ready tasks while surfacing likely collisions.")
    select.add_argument("--limit", type=int, default=0)
    select.add_argument("--json", action="store_true")
    select.set_defaults(func=command_select)

    scout_review = sub.add_parser("scout-review", help="Record scout-reviewer approval or rejection.")
    scout_review.add_argument("task_id")
    scout_review.add_argument("--result", required=True, choices=sorted(SCOUT_REVIEW_RESULTS))
    scout_review.add_argument("--reviewer", required=True)
    scout_review.add_argument("--summary", required=True)
    scout_review.set_defaults(func=command_scout_review)

    lease = sub.add_parser("lease", help="Lease a ready task to a worker thread.")
    lease.add_argument("task_id")
    lease.add_argument("--thread-id", default="")
    lease.add_argument("--branch", default="")
    lease.add_argument("--worktree", default="")
    lease.add_argument("--worker", default="orchestrator")
    lease.add_argument("--note", default="")
    lease.add_argument("--force", action="store_true")
    lease.set_defaults(func=command_lease)

    heartbeat = sub.add_parser("heartbeat", help="Update worker heartbeat timestamp.")
    heartbeat.add_argument("task_id")
    heartbeat.add_argument("--actor", default="orchestrator")
    heartbeat.add_argument("--note", default="")
    heartbeat.set_defaults(func=command_heartbeat)

    mark = sub.add_parser("mark", help="Set an arbitrary queue status.")
    mark.add_argument("task_id")
    mark.add_argument("status", choices=sorted(STATUSES))
    mark.add_argument("--actor", default="orchestrator")
    mark.add_argument("--note", required=True)
    mark.set_defaults(func=command_mark)

    handoff = sub.add_parser("handoff", help="Build one verified worker handoff file for orchestrator-owned queue completion.")
    handoff.add_argument("task_id")
    handoff.add_argument("--reviewer", required=True)
    handoff.add_argument("--signoff", required=True)
    handoff.add_argument("--proof", action="append", required=True)
    handoff.add_argument("--commit", default="", help="Defaults to current HEAD.")
    handoff.add_argument("--residual-risk", action="append", default=[])
    handoff.add_argument("--inspection-manifest", default="")
    handoff.add_argument("--inspection-not-applicable", default="")
    handoff.add_argument("--output", default="")
    handoff.set_defaults(func=command_handoff)

    complete = sub.add_parser("complete", help="Mark an implementation-reviewed task ready for user inspection.")
    complete.add_argument("task_id")
    complete.add_argument("--actor", default="orchestrator")
    complete.add_argument("--handoff-file", default="", help="Verified worker handoff JSON; replaces the individual flags below.")
    complete.add_argument("--reviewer", default="")
    complete.add_argument("--signoff", default="")
    complete.add_argument("--proof", default="")
    complete.add_argument("--commit", default="")
    complete.add_argument("--inspection-scenario", default="")
    complete.add_argument("--inspection-run-id", default="")
    complete.add_argument("--inspection-summary", default="")
    complete.add_argument("--inspection-launch", default="")
    complete.add_argument("--inspection-not-applicable", default="", help="Reason no playable inspection fixture applies.")
    complete.set_defaults(func=command_complete)

    landed = sub.add_parser("landed", help="Mark an approved task as landed on master.")
    landed.add_argument("task_id")
    landed.add_argument("--actor", default="orchestrator")
    landed.add_argument("--commit", required=True)
    landed.add_argument("--note", default="")
    landed.add_argument("--archive", action="store_true")
    landed.set_defaults(func=command_landed)

    board = sub.add_parser("board", help="Serve a local browser board for the queue.")
    board.add_argument("--host", default="127.0.0.1", help="Host interface for the local board.")
    board.add_argument("--port", type=int, default=8765, help="Port for the local board. Use 0 for an ephemeral port.")
    board.add_argument("--stale-hours", type=float, default=12.0, help="Active task heartbeat age considered stale.")
    board.add_argument("--no-archive", action="store_true", help="Hide archived terminal task files.")
    board.add_argument("--once-json", action="store_true", help="Print the board snapshot JSON and exit.")
    board.set_defaults(func=command_board)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args) or 0)
    except QueueError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
