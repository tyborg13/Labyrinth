#!/usr/bin/env python3
"""Serve a local browser board for the Labyrinth autonomous task queue."""

from __future__ import annotations

import argparse
import datetime as _dt
import json
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
from typing import Any
from urllib.parse import parse_qs, urlparse

import labyrinth_task_queue as task_queue


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
DEFAULT_STALE_HOURS = 12.0

LANES: list[dict[str, Any]] = [
    {
        "id": "ready",
        "title": "Ready To Pick Up",
        "summary": "Reviewed work a worker can take",
        "statuses": ["ready"],
    },
    {
        "id": "backlog",
        "title": "Backlog",
        "summary": "Proposed or needs revision",
        "statuses": ["proposed", "needs_revision"],
    },
    {
        "id": "assigned",
        "title": "Assigned And Running",
        "summary": "Leased or adopted by workers",
        "statuses": ["leased", "in_progress"],
    },
    {
        "id": "review",
        "title": "Review And Inspection",
        "summary": "Peer review, user inspection, or landing approval",
        "statuses": ["implementation_review", "ready_for_user", "approved_to_land"],
    },
    {
        "id": "terminal",
        "title": "Terminal",
        "summary": "Done, blocked, rejected, or abandoned",
        "statuses": ["done", "blocked", "rejected", "abandoned"],
    },
]

LANE_BY_STATUS = {
    status: lane["id"]
    for lane in LANES
    for status in lane["statuses"]
}
TERMINAL_STATUSES = {"done", "blocked", "rejected", "abandoned"}
REVIEW_STATUSES = {"implementation_review", "ready_for_user", "approved_to_land"}
ASSIGNED_STATUSES = {"leased", "in_progress"}
STALE_STATUSES = {"leased", "in_progress", "implementation_review"}

STATUS_LABELS = {
    "proposed": "Proposed",
    "needs_revision": "Needs Revision",
    "ready": "Ready",
    "leased": "Leased",
    "in_progress": "In Progress",
    "implementation_review": "Impl Review",
    "ready_for_user": "Ready For User",
    "approved_to_land": "Approved To Land",
    "done": "Done",
    "rejected": "Rejected",
    "abandoned": "Abandoned",
    "blocked": "Blocked",
}


def utc_now() -> _dt.datetime:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)


def parse_utc(value: Any) -> _dt.datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = _dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=_dt.timezone.utc)
    return parsed.astimezone(_dt.timezone.utc)


def seconds_since(value: Any, now: _dt.datetime) -> float | None:
    parsed = parse_utc(value)
    if parsed is None:
        return None
    return max(0.0, (now - parsed).total_seconds())


def relative_time(value: Any, now: _dt.datetime) -> str:
    elapsed = seconds_since(value, now)
    if elapsed is None:
        return "unknown"
    if elapsed < 60:
        return "just now"
    minutes = int(elapsed // 60)
    if minutes < 60:
        return "%dm ago" % minutes
    hours = int(minutes // 60)
    if hours < 48:
        return "%dh ago" % hours
    days = int(hours // 24)
    if days < 30:
        return "%dd ago" % days
    months = int(days // 30)
    if months < 18:
        return "%dmo ago" % months
    years = int(days // 365)
    return "%dy ago" % max(years, 1)


def compact_text(value: Any, *, limit: int = 220) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "..."


def read_tasks(queue_root: Path, *, include_archive: bool) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    queue_dir, archive_dir = task_queue.queue_dirs(queue_root)
    sources = [("queue", queue_dir)]
    if include_archive:
        sources.append(("archive", archive_dir))

    tasks: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    for location, directory in sources:
        if not directory.exists():
            continue
        for path in sorted(directory.glob("*.json")):
            try:
                payload = task_queue.load_json(path)
                if not isinstance(payload, dict):
                    raise task_queue.QueueError("%s must contain a JSON object" % path)
            except Exception as exc:  # noqa: BLE001 - queue files are local state worth surfacing.
                errors.append({"path": str(path), "message": str(exc)})
                continue
            task = dict(payload)
            task["_queue_location"] = location
            task["_queue_file"] = str(path)
            tasks.append(task)
    return tasks, errors


def include_archive_from_query(query: dict[str, list[str]], *, default: bool) -> bool:
    raw = query.get("include_archive")
    if not raw:
        return default
    return raw[0] not in {"0", "false", "False"}


def lane_for_status(status: Any) -> str:
    return LANE_BY_STATUS.get(str(status or ""), "backlog")


def latest_history_note(task: dict[str, Any]) -> str:
    history = task.get("history")
    if not isinstance(history, list) or not history:
        return ""
    last = history[-1]
    if not isinstance(last, dict):
        return ""
    actor = str(last.get("actor") or "").strip()
    note = str(last.get("note") or "").strip()
    if actor and note:
        return "%s: %s" % (actor, note)
    return note or actor


def active_timestamp(task: dict[str, Any]) -> str:
    worker = task.get("worker") if isinstance(task.get("worker"), dict) else {}
    return str(worker.get("heartbeat_at_utc") or task.get("updated_at_utc") or task.get("created_at_utc") or "")


def sort_timestamp(value: Any) -> float:
    parsed = parse_utc(value)
    if parsed is None:
        return 0.0
    return parsed.timestamp()


def task_sort_key(task: dict[str, Any]) -> tuple[Any, ...]:
    status = str(task.get("status") or "")
    if status == "ready":
        score = task.get("conflict_score")
        if score is None:
            score = 999999
        return (int(score), -int(task.get("priority") or 0), str(task.get("id") or ""))
    if status in {"leased", "in_progress", "implementation_review"}:
        return (0 if task.get("is_stale") else 1, sort_timestamp(task.get("last_activity_at")), str(task.get("id") or ""))
    if status in {"ready_for_user", "approved_to_land"}:
        return (-int(task.get("priority") or 0), sort_timestamp(task.get("updated_at_utc")), str(task.get("id") or ""))
    if status in TERMINAL_STATUSES:
        return (-sort_timestamp(task.get("updated_at_utc")), str(task.get("id") or ""))
    return (-int(task.get("priority") or 0), str(task.get("status") or ""), str(task.get("id") or ""))


def enrich_task(
    task: dict[str, Any],
    *,
    now: _dt.datetime,
    active_tasks: list[dict[str, Any]],
    stale_hours: float,
) -> dict[str, Any]:
    status = str(task.get("status") or "")
    proposal = task.get("proposal") if isinstance(task.get("proposal"), dict) else {}
    safety = task.get("parallel_safety") if isinstance(task.get("parallel_safety"), dict) else {}
    worker = task.get("worker") if isinstance(task.get("worker"), dict) else {}
    implementation_review = task.get("implementation_review") if isinstance(task.get("implementation_review"), dict) else {}
    inspection_fixture = task.get("inspection_fixture") if isinstance(task.get("inspection_fixture"), dict) else {}

    conflict_score: int | None = None
    conflict_count = 0
    conflict_tasks: list[str] = []
    if status == "ready":
        report = task_queue.conflict_report(task, active_tasks)
        conflict_score = int(report.get("conflict_score", 0))
        conflicts = report.get("conflicts", [])
        if isinstance(conflicts, list):
            conflict_count = len(conflicts)
            conflict_tasks = [
                str(item.get("active_task"))
                for item in conflicts
                if isinstance(item, dict) and str(item.get("active_task") or "").strip()
            ][:4]

    last_activity_at = active_timestamp(task)
    stale_after_seconds = max(0.0, stale_hours * 3600.0)
    active_elapsed = seconds_since(last_activity_at, now)
    is_stale = bool(status in STALE_STATUSES and active_elapsed is not None and active_elapsed >= stale_after_seconds)

    likely_paths = task_queue.normalize_paths(safety.get("likely_touched_files"))
    history = task.get("history") if isinstance(task.get("history"), list) else []
    history_tail = [
        {
            "at_utc": str(item.get("at_utc") or ""),
            "at_label": relative_time(item.get("at_utc"), now),
            "actor": str(item.get("actor") or ""),
            "status": str(item.get("status") or ""),
            "note": compact_text(item.get("note"), limit=160),
        }
        for item in history[-3:]
        if isinstance(item, dict)
    ]

    return {
        "id": str(task.get("id") or ""),
        "title": str(task.get("title") or "Untitled task"),
        "status": status,
        "status_label": STATUS_LABELS.get(status, status or "Unknown"),
        "lane": lane_for_status(status),
        "priority": int(task.get("priority") or 0),
        "queue_location": str(task.get("_queue_location") or "queue"),
        "queue_file": str(task.get("_queue_file") or ""),
        "is_archived": task.get("_queue_location") == "archive",
        "is_terminal": status in TERMINAL_STATUSES,
        "is_review": status in REVIEW_STATUSES,
        "is_stale": is_stale,
        "created_at_utc": str(task.get("created_at_utc") or ""),
        "updated_at_utc": str(task.get("updated_at_utc") or ""),
        "updated_label": relative_time(task.get("updated_at_utc"), now),
        "last_activity_at": last_activity_at,
        "last_activity_label": relative_time(last_activity_at, now),
        "conflict_score": conflict_score,
        "conflict_count": conflict_count,
        "conflict_tasks": conflict_tasks,
        "summary": compact_text(proposal.get("problem") or proposal.get("proposed_change") or proposal.get("impact"), limit=260),
        "proposed_change": compact_text(proposal.get("proposed_change"), limit=260),
        "acceptance_count": len(task_queue.as_list(proposal.get("acceptance_criteria"))),
        "proof_count": len(task_queue.as_list(proposal.get("required_proof"))),
        "estimated_size": str(proposal.get("estimated_size") or ""),
        "risk": compact_text(proposal.get("risk"), limit=220),
        "likely_touched_files": likely_paths[:6],
        "likely_touched_count": len(likely_paths),
        "shared_state_risks": task_queue.text_list(safety.get("shared_state_risks"))[:4],
        "latest_history_note": compact_text(latest_history_note(task), limit=180),
        "history_tail": history_tail,
        "worker": {
            "thread_id": str(worker.get("thread_id") or ""),
            "branch": str(worker.get("branch") or ""),
            "worktree_path": str(worker.get("worktree_path") or ""),
            "leased_by": str(worker.get("leased_by") or ""),
            "leased_at_utc": str(worker.get("leased_at_utc") or ""),
            "heartbeat_at_utc": str(worker.get("heartbeat_at_utc") or ""),
            "heartbeat_label": relative_time(worker.get("heartbeat_at_utc"), now),
        },
        "implementation_review": {
            "reviewer": str(implementation_review.get("reviewer") or ""),
            "head_commit": str(implementation_review.get("head_commit") or ""),
            "proof_summary": compact_text(implementation_review.get("proof_summary"), limit=220),
            "signoff_summary": compact_text(implementation_review.get("signoff_summary"), limit=220),
        },
        "inspection_fixture": {
            "applicable": bool(inspection_fixture.get("applicable")),
            "scenario": str(inspection_fixture.get("scenario") or ""),
            "summary": compact_text(inspection_fixture.get("summary") or inspection_fixture.get("reason"), limit=180),
            "launch_command": str(inspection_fixture.get("launch_command") or ""),
        },
    }


def count_by(items: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in items:
        value = str(item.get(key) or "")
        counts[value] = counts.get(value, 0) + 1
    return counts


def build_board_snapshot(
    *,
    repo: Path,
    queue_root: Path | None = None,
    include_archive: bool = True,
    stale_hours: float = DEFAULT_STALE_HOURS,
) -> dict[str, Any]:
    resolved_queue_root = queue_root.expanduser().resolve() if queue_root else task_queue.default_queue_root(repo)
    now = utc_now()
    raw_tasks, errors = read_tasks(resolved_queue_root, include_archive=include_archive)
    active_tasks = [task for task in raw_tasks if task.get("status") in task_queue.ACTIVE_STATUSES]
    tasks = [
        enrich_task(task, now=now, active_tasks=active_tasks, stale_hours=stale_hours)
        for task in raw_tasks
    ]

    tasks_by_lane: dict[str, list[dict[str, Any]]] = {str(lane["id"]): [] for lane in LANES}
    for task in tasks:
        tasks_by_lane.setdefault(str(task["lane"]), []).append(task)
    for lane_tasks in tasks_by_lane.values():
        lane_tasks.sort(key=task_sort_key)

    lanes = [
        {
            "id": lane["id"],
            "title": lane["title"],
            "summary": lane["summary"],
            "statuses": lane["statuses"],
            "tasks": tasks_by_lane.get(str(lane["id"]), []),
        }
        for lane in LANES
    ]
    status_counts = count_by(tasks, "status")
    lane_counts = {lane["id"]: len(lane["tasks"]) for lane in lanes}
    ready_tasks = tasks_by_lane.get("ready", [])
    active_count = sum(1 for task in tasks if task["status"] in ASSIGNED_STATUSES)
    terminal_count = sum(1 for task in tasks if task["status"] in TERMINAL_STATUSES)
    archived_count = sum(1 for task in tasks if task["is_archived"])

    return {
        "schema_version": 1,
        "generated_at_utc": now.isoformat().replace("+00:00", "Z"),
        "generated_label": relative_time(now.isoformat(), now),
        "repo": str(repo.resolve()),
        "queue_root": str(resolved_queue_root),
        "include_archive": include_archive,
        "stale_hours": stale_hours,
        "counts": {
            "total": len(tasks),
            "ready": status_counts.get("ready", 0),
            "ready_clear": sum(1 for task in ready_tasks if task.get("conflict_score") == 0),
            "active": active_count,
            "review": sum(1 for task in tasks if task["status"] in REVIEW_STATUSES),
            "stale_active": sum(1 for task in tasks if task.get("is_stale")),
            "terminal": terminal_count,
            "archived": archived_count,
        },
        "status_counts": status_counts,
        "lane_counts": lane_counts,
        "lanes": lanes,
        "errors": errors,
    }


BOARD_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Labyrinth Queue Board</title>
  <style>
    :root {
      --bg: #151714;
      --bg-lift: #20231d;
      --panel: #282b24;
      --panel-strong: #32362c;
      --paper: #f7f1e6;
      --paper-soft: #efe5d3;
      --ink: #20231d;
      --muted: #9aa18d;
      --muted-ink: #5e6658;
      --line: #3b4034;
      --line-soft: #d9cdb9;
      --amber: #d49b35;
      --green: #47a37c;
      --teal: #4fa0a6;
      --blue: #5c82b6;
      --violet: #9a6ab0;
      --red: #bd5c54;
      --gray: #7d8378;
      --shadow: 0 18px 48px rgba(0, 0, 0, 0.28);
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: #f3efe7;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 14px;
      letter-spacing: 0;
    }

    button,
    input,
    select {
      font: inherit;
    }

    button {
      cursor: pointer;
    }

    .app {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    .topbar {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 20px;
      padding: 22px 24px 16px;
      border-bottom: 1px solid var(--line);
      background: #191b17;
    }

    .title-block {
      min-width: 240px;
    }

    .eyebrow {
      margin: 0 0 4px;
      color: var(--amber);
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
    }

    h1 {
      margin: 0;
      font-size: 26px;
      line-height: 1.08;
      font-weight: 780;
      letter-spacing: 0;
    }

    .queue-root {
      margin: 8px 0 0;
      max-width: 820px;
      color: var(--muted);
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 12px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .toolbar {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      flex-wrap: wrap;
      gap: 8px;
    }

    .control,
    .button {
      height: 38px;
      border: 1px solid #464c3e;
      border-radius: 8px;
      background: #24271f;
      color: #f5efe5;
      outline: none;
    }

    .control {
      min-width: 190px;
      padding: 0 12px;
    }

    .control:focus,
    .button:focus-visible {
      border-color: var(--amber);
      box-shadow: 0 0 0 3px rgba(212, 155, 53, 0.18);
    }

    .button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      min-width: 92px;
      padding: 0 12px;
      font-weight: 700;
    }

    .button:hover {
      background: #2e3329;
    }

    .meta-strip {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 24px 0;
      color: var(--muted);
      font-size: 12px;
    }

    .metrics {
      display: grid;
      grid-template-columns: repeat(7, minmax(120px, 1fr));
      gap: 10px;
      padding: 16px 24px;
    }

    .metric {
      min-height: 78px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
      padding: 12px;
      box-shadow: var(--shadow);
    }

    .metric-label {
      color: var(--muted);
      font-size: 11px;
      font-weight: 750;
      text-transform: uppercase;
    }

    .metric-value {
      margin-top: 6px;
      font-size: 26px;
      line-height: 1;
      font-weight: 780;
    }

    .metric-detail {
      margin-top: 7px;
      color: #c5cbb9;
      font-size: 12px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .alerts {
      display: none;
      margin: 0 24px 14px;
      border: 1px solid rgba(189, 92, 84, 0.56);
      border-radius: 8px;
      background: rgba(189, 92, 84, 0.12);
      color: #ffd8d4;
      padding: 10px 12px;
    }

    .alerts.visible {
      display: block;
    }

    .board-wrap {
      flex: 1;
      min-height: 0;
      padding: 0 0 22px;
    }

    .board {
      display: grid;
      grid-auto-flow: column;
      grid-auto-columns: minmax(228px, 1fr);
      gap: 14px;
      min-height: 640px;
      overflow-x: auto;
      padding: 0 24px 14px;
      scrollbar-color: #555c4e #20231d;
    }

    .lane {
      min-height: 620px;
      display: flex;
      flex-direction: column;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--bg-lift);
      overflow: hidden;
    }

    .lane-header {
      padding: 13px 13px 10px;
      border-bottom: 1px solid var(--line);
      background: var(--panel);
    }

    .lane-title-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .lane-title {
      margin: 0;
      font-size: 15px;
      line-height: 1.2;
      font-weight: 800;
      letter-spacing: 0;
    }

    .lane-count {
      min-width: 28px;
      height: 24px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid #505646;
      border-radius: 999px;
      background: #1a1d18;
      color: #f6f1e9;
      font-size: 12px;
      font-weight: 800;
    }

    .lane-summary {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.35;
    }

    .task-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
      padding: 12px;
    }

    .empty {
      min-height: 98px;
      display: grid;
      place-items: center;
      border: 1px dashed #454b3d;
      border-radius: 8px;
      color: var(--muted);
      text-align: center;
      padding: 12px;
    }

    .task-card {
      position: relative;
      border: 1px solid var(--line-soft);
      border-left: 5px solid var(--gray);
      border-radius: 8px;
      background: var(--paper);
      color: var(--ink);
      box-shadow: 0 10px 24px rgba(0, 0, 0, 0.16);
      overflow: hidden;
    }

    .task-card[data-status="ready"] { border-left-color: var(--green); }
    .task-card[data-status="leased"] { border-left-color: var(--amber); }
    .task-card[data-status="in_progress"] { border-left-color: var(--blue); }
    .task-card[data-status="implementation_review"] { border-left-color: var(--violet); }
    .task-card[data-status="ready_for_user"] { border-left-color: var(--teal); }
    .task-card[data-status="approved_to_land"] { border-left-color: #78964f; }
    .task-card[data-status="blocked"],
    .task-card[data-status="rejected"],
    .task-card[data-status="abandoned"] { border-left-color: var(--red); }
    .task-card[data-status="done"] { border-left-color: #7f887d; }

    .task-inner {
      padding: 12px 12px 11px;
    }

    .task-top {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 8px;
    }

    .task-title {
      margin: 0;
      min-width: 0;
      font-size: 15px;
      line-height: 1.24;
      font-weight: 820;
      letter-spacing: 0;
      overflow-wrap: anywhere;
    }

    .task-id {
      margin-top: 4px;
      color: var(--muted-ink);
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 11px;
      overflow-wrap: anywhere;
    }

    .badge-row {
      display: flex;
      flex-wrap: wrap;
      gap: 5px;
      justify-content: flex-end;
      max-width: 126px;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      min-height: 22px;
      max-width: 126px;
      border: 1px solid #cdbfaa;
      border-radius: 999px;
      padding: 2px 7px;
      background: #fff9ee;
      color: #4a4033;
      font-size: 11px;
      font-weight: 780;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .badge.status-ready { border-color: rgba(71, 163, 124, 0.55); color: #1d694d; }
    .badge.status-leased { border-color: rgba(212, 155, 53, 0.6); color: #80570e; }
    .badge.status-in_progress { border-color: rgba(92, 130, 182, 0.58); color: #2e5b91; }
    .badge.status-implementation_review,
    .badge.status-ready_for_user,
    .badge.status-approved_to_land { border-color: rgba(79, 160, 166, 0.6); color: #216870; }
    .badge.status-blocked,
    .badge.status-rejected,
    .badge.status-abandoned { border-color: rgba(189, 92, 84, 0.62); color: #8a3029; }

    .task-summary {
      margin: 8px 0 0;
      color: #34382f;
      line-height: 1.42;
      overflow-wrap: anywhere;
    }

    .facts {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 6px;
      margin-top: 10px;
    }

    .fact {
      min-width: 0;
      color: var(--muted-ink);
      font-size: 12px;
      line-height: 1.35;
      overflow-wrap: anywhere;
    }

    .fact strong {
      display: block;
      color: #2f342b;
      font-size: 11px;
      text-transform: uppercase;
    }

    .paths {
      display: flex;
      flex-wrap: wrap;
      gap: 5px;
      margin-top: 10px;
    }

    .path-pill {
      max-width: 100%;
      border: 1px solid #d4c5ad;
      border-radius: 999px;
      padding: 3px 7px;
      background: var(--paper-soft);
      color: #514839;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 11px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .history-note {
      margin-top: 10px;
      padding-top: 9px;
      border-top: 1px solid var(--line-soft);
      color: var(--muted-ink);
      font-size: 12px;
      line-height: 1.36;
      overflow-wrap: anywhere;
    }

    .stale-ribbon {
      display: none;
      padding: 6px 10px;
      background: rgba(189, 92, 84, 0.16);
      color: #8a3029;
      border-top: 1px solid rgba(189, 92, 84, 0.32);
      font-size: 12px;
      font-weight: 800;
    }

    .task-card.is-stale .stale-ribbon {
      display: block;
    }

    .hidden {
      display: none !important;
    }

    @media (max-width: 1100px) {
      .metrics {
        grid-template-columns: repeat(4, minmax(120px, 1fr));
      }
    }

    @media (max-width: 760px) {
      .topbar {
        align-items: stretch;
        flex-direction: column;
      }

      .toolbar {
        justify-content: stretch;
      }

      .control,
      .button {
        flex: 1 1 160px;
      }

      .metrics {
        grid-template-columns: repeat(2, minmax(120px, 1fr));
      }

      .board {
        grid-auto-flow: row;
        grid-auto-columns: unset;
        grid-template-columns: 1fr;
        min-height: auto;
        overflow-x: visible;
      }

      .lane {
        min-height: 220px;
      }
    }
  </style>
</head>
<body>
  <div class="app">
    <header class="topbar">
      <div class="title-block">
        <p class="eyebrow">Labyrinth Queue</p>
        <h1>Task Board</h1>
        <p class="queue-root" id="queueRoot">Loading queue...</p>
      </div>
      <div class="toolbar" aria-label="Board controls">
        <input class="control" id="search" type="search" placeholder="Search tasks">
        <select class="control" id="focus">
          <option value="all">All work</option>
          <option value="ready">Ready</option>
          <option value="active">Active</option>
          <option value="review">Review</option>
          <option value="terminal">Terminal</option>
          <option value="stale">Stale active</option>
        </select>
        <button class="button" id="refresh" type="button" title="Reload queue data">Refresh</button>
      </div>
    </header>
    <div class="meta-strip">
      <span id="generatedAt">Waiting for queue data</span>
      <span id="visibleCount"></span>
    </div>
    <section class="metrics" id="metrics" aria-label="Queue totals"></section>
    <section class="alerts" id="alerts"></section>
    <main class="board-wrap">
      <section class="board" id="board" aria-label="Task lanes"></section>
    </main>
  </div>
  <script>
    const state = {
      snapshot: null,
      query: "",
      focus: "all"
    };

    const terminalStatuses = new Set(["done", "blocked", "rejected", "abandoned"]);
    const activeStatuses = new Set(["leased", "in_progress"]);
    const reviewStatuses = new Set(["implementation_review", "ready_for_user", "approved_to_land"]);

    function el(tag, className, text) {
      const node = document.createElement(tag);
      if (className) node.className = className;
      if (text !== undefined && text !== null) node.textContent = text;
      return node;
    }

    function matchesFocus(task) {
      if (state.focus === "ready") return task.status === "ready";
      if (state.focus === "active") return activeStatuses.has(task.status);
      if (state.focus === "review") return reviewStatuses.has(task.status);
      if (state.focus === "terminal") return terminalStatuses.has(task.status);
      if (state.focus === "stale") return Boolean(task.is_stale);
      return true;
    }

    function searchableText(task) {
      return [
        task.id,
        task.title,
        task.status_label,
        task.summary,
        task.latest_history_note,
        task.worker && task.worker.leased_by,
        task.worker && task.worker.branch,
        task.likely_touched_files && task.likely_touched_files.join(" ")
      ].filter(Boolean).join(" ").toLowerCase();
    }

    function matchesQuery(task) {
      const query = state.query.trim().toLowerCase();
      if (!query) return true;
      return searchableText(task).includes(query);
    }

    function visibleTask(task) {
      return matchesFocus(task) && matchesQuery(task);
    }

    function renderMetrics(snapshot) {
      const metrics = document.getElementById("metrics");
      metrics.replaceChildren();
      const items = [
        ["Ready", snapshot.counts.ready, `${snapshot.counts.ready_clear} clear`],
        ["Active", snapshot.counts.active, `${snapshot.counts.stale_active} stale`],
        ["Review", snapshot.counts.review, "handoff lanes"],
        ["Terminal", snapshot.counts.terminal, "done or stopped"],
        ["Archived", snapshot.counts.archived, "included"],
        ["Total", snapshot.counts.total, "queue files"],
        ["Errors", snapshot.errors.length, "read issues"]
      ];
      for (const [label, value, detail] of items) {
        const card = el("article", "metric");
        card.append(el("div", "metric-label", label));
        card.append(el("div", "metric-value", String(value)));
        card.append(el("div", "metric-detail", detail));
        metrics.append(card);
      }
    }

    function appendFact(parent, label, value) {
      if (!value && value !== 0) return;
      const fact = el("div", "fact");
      fact.append(el("strong", "", label));
      fact.append(document.createTextNode(String(value)));
      parent.append(fact);
    }

    function renderPaths(card, task) {
      const paths = task.likely_touched_files || [];
      if (!paths.length) return;
      const pathWrap = el("div", "paths");
      for (const path of paths.slice(0, 4)) {
        pathWrap.append(el("span", "path-pill", path));
      }
      const extra = (task.likely_touched_count || paths.length) - Math.min(paths.length, 4);
      if (extra > 0) {
        pathWrap.append(el("span", "path-pill", `+${extra}`));
      }
      card.append(pathWrap);
    }

    function renderTask(task) {
      const card = el("article", "task-card");
      card.dataset.status = task.status || "";
      if (task.is_stale) card.classList.add("is-stale");

      const inner = el("div", "task-inner");
      const top = el("div", "task-top");
      const titleBlock = el("div", "");
      titleBlock.append(el("h2", "task-title", task.title || "Untitled task"));
      titleBlock.append(el("div", "task-id", task.id || ""));
      top.append(titleBlock);

      const badges = el("div", "badge-row");
      badges.append(el("span", `badge status-${task.status}`, task.status_label || task.status));
      badges.append(el("span", "badge", `p${task.priority}`));
      if (task.is_archived) badges.append(el("span", "badge", "archive"));
      top.append(badges);
      inner.append(top);

      if (task.summary) inner.append(el("p", "task-summary", task.summary));

      const facts = el("div", "facts");
      appendFact(facts, "Updated", task.updated_label);
      appendFact(facts, "Activity", task.last_activity_label);
      if (task.status === "ready") {
        appendFact(facts, "Overlap", task.conflict_score === 0 ? "clear" : `${task.conflict_score} score`);
        appendFact(facts, "Proof", `${task.proof_count} items`);
      }
      if (task.worker && (task.worker.leased_by || task.worker.thread_id)) {
        appendFact(facts, "Worker", task.worker.leased_by || task.worker.thread_id);
      }
      if (task.worker && task.worker.branch) {
        appendFact(facts, "Branch", task.worker.branch);
      }
      if (task.implementation_review && task.implementation_review.reviewer) {
        appendFact(facts, "Reviewer", task.implementation_review.reviewer);
      }
      if (task.inspection_fixture && task.inspection_fixture.summary) {
        appendFact(facts, "Inspection", task.inspection_fixture.summary);
      }
      if (facts.children.length) inner.append(facts);

      renderPaths(inner, task);
      if (task.latest_history_note) inner.append(el("div", "history-note", task.latest_history_note));

      card.append(inner);
      const stale = el("div", "stale-ribbon", `Stale active: no heartbeat for ${task.last_activity_label}`);
      card.append(stale);
      return card;
    }

    function renderBoard(snapshot) {
      const board = document.getElementById("board");
      board.replaceChildren();
      let visible = 0;
      for (const lane of snapshot.lanes) {
        const laneNode = el("section", "lane");
        const header = el("header", "lane-header");
        const titleRow = el("div", "lane-title-row");
        titleRow.append(el("h2", "lane-title", lane.title));
        const laneTasks = lane.tasks.filter(visibleTask);
        visible += laneTasks.length;
        titleRow.append(el("span", "lane-count", String(laneTasks.length)));
        header.append(titleRow);
        header.append(el("p", "lane-summary", lane.summary));
        laneNode.append(header);

        const list = el("div", "task-list");
        if (!laneTasks.length) {
          list.append(el("div", "empty", "No matching tasks"));
        } else {
          for (const task of laneTasks) list.append(renderTask(task));
        }
        laneNode.append(list);
        board.append(laneNode);
      }
      document.getElementById("visibleCount").textContent = `${visible} visible`;
    }

    function renderAlerts(snapshot) {
      const alerts = document.getElementById("alerts");
      alerts.replaceChildren();
      if (!snapshot.errors.length) {
        alerts.classList.remove("visible");
        return;
      }
      alerts.classList.add("visible");
      alerts.append(el("strong", "", "Queue read errors: "));
      alerts.append(document.createTextNode(snapshot.errors.map(error => `${error.path}: ${error.message}`).join(" | ")));
    }

    function render() {
      const snapshot = state.snapshot;
      if (!snapshot) return;
      document.getElementById("queueRoot").textContent = snapshot.queue_root;
      document.getElementById("generatedAt").textContent = `Updated ${new Date(snapshot.generated_at_utc).toLocaleString()}`;
      renderMetrics(snapshot);
      renderAlerts(snapshot);
      renderBoard(snapshot);
    }

    async function loadBoard() {
      const response = await fetch(`/api/queue?ts=${Date.now()}`);
      if (!response.ok) {
        throw new Error(`Queue request failed: ${response.status}`);
      }
      state.snapshot = await response.json();
      render();
    }

    document.getElementById("search").addEventListener("input", (event) => {
      state.query = event.target.value;
      render();
    });
    document.getElementById("focus").addEventListener("change", (event) => {
      state.focus = event.target.value;
      render();
    });
    document.getElementById("refresh").addEventListener("click", () => {
      loadBoard().catch((error) => {
        const alerts = document.getElementById("alerts");
        alerts.classList.add("visible");
        alerts.textContent = error.message;
      });
    });

    loadBoard().catch((error) => {
      const alerts = document.getElementById("alerts");
      alerts.classList.add("visible");
      alerts.textContent = error.message;
    });
    window.setInterval(() => {
      loadBoard().catch(() => {});
    }, 15000);
  </script>
</body>
</html>
"""


class QueueBoardHandler(BaseHTTPRequestHandler):
    server: "QueueBoardServer"

    def log_message(self, fmt: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), fmt % args), file=sys.stderr)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in {"", "/"}:
            self.send_text(BOARD_HTML, content_type="text/html; charset=utf-8")
            return
        if parsed.path in {"/api/queue", "/api/tasks"}:
            query = parse_qs(parsed.query)
            include_archive = include_archive_from_query(query, default=self.server.include_archive)
            snapshot = build_board_snapshot(
                repo=self.server.repo,
                queue_root=self.server.queue_root,
                include_archive=include_archive,
                stale_hours=self.server.stale_hours,
            )
            self.send_json(snapshot)
            return
        if parsed.path == "/favicon.ico":
            self.send_response(HTTPStatus.NO_CONTENT)
            self.end_headers()
            return
        self.send_error(HTTPStatus.NOT_FOUND, "Not found")

    def send_json(self, payload: Any) -> None:
        body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, text: str, *, content_type: str) -> None:
        body = text.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class QueueBoardServer(ThreadingHTTPServer):
    allow_reuse_address = True

    def __init__(
        self,
        server_address: tuple[str, int],
        handler_class: type[BaseHTTPRequestHandler],
        *,
        repo: Path,
        queue_root: Path | None,
        include_archive: bool,
        stale_hours: float,
    ) -> None:
        super().__init__(server_address, handler_class)
        self.repo = repo
        self.queue_root = queue_root
        self.include_archive = include_archive
        self.stale_hours = stale_hours


def create_server(
    *,
    host: str,
    port: int,
    repo: Path,
    queue_root: Path | None,
    include_archive: bool,
    stale_hours: float,
) -> QueueBoardServer:
    ports = [port] if port == 0 else list(range(port, port + 20))
    last_error: OSError | None = None
    for candidate in ports:
        try:
            return QueueBoardServer(
                (host, candidate),
                QueueBoardHandler,
                repo=repo,
                queue_root=queue_root,
                include_archive=include_archive,
                stale_hours=stale_hours,
            )
        except OSError as exc:
            last_error = exc
    if last_error is not None:
        raise last_error
    raise OSError("No port candidates available")


def serve(args: argparse.Namespace) -> int:
    repo = Path(args.repo).expanduser().resolve()
    queue_root = Path(args.queue_root).expanduser().resolve() if args.queue_root else None

    if args.once_json:
        snapshot = build_board_snapshot(
            repo=repo,
            queue_root=queue_root,
            include_archive=not args.no_archive,
            stale_hours=args.stale_hours,
        )
        print(json.dumps(snapshot, indent=2, sort_keys=True))
        return 0

    server = create_server(
        host=args.host,
        port=args.port,
        repo=repo,
        queue_root=queue_root,
        include_archive=not args.no_archive,
        stale_hours=args.stale_hours,
    )
    host, port = server.server_address[:2]
    print("Labyrinth queue board: http://%s:%s" % (host, port), flush=True)
    snapshot = build_board_snapshot(
        repo=repo,
        queue_root=queue_root,
        include_archive=not args.no_archive,
        stale_hours=args.stale_hours,
    )
    print("Queue root: %s" % snapshot["queue_root"], flush=True)
    print("Press Ctrl-C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("")
    finally:
        server.server_close()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="Repository/worktree path used to locate the default queue.")
    parser.add_argument("--queue-root", default="", help="Queue root. Defaults to the primary worktree .codex/tasks.")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Host interface for the local board.")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port for the local board. Use 0 for an ephemeral port.")
    parser.add_argument("--stale-hours", type=float, default=DEFAULT_STALE_HOURS, help="Active task heartbeat age considered stale.")
    parser.add_argument("--no-archive", action="store_true", help="Hide archived terminal task files.")
    parser.add_argument("--once-json", action="store_true", help="Print the board snapshot JSON and exit.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return serve(args)


if __name__ == "__main__":
    raise SystemExit(main())
