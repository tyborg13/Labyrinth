#!/usr/bin/env python3
"""Tests for the Labyrinth queue board snapshot."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))

import labyrinth_queue_board as queue_board  # noqa: E402


def make_task(task_id: str, status: str, *, paths: list[str] | None = None, priority: int = 3) -> dict[str, object]:
    return {
        "schema_version": 1,
        "id": task_id,
        "title": task_id.replace("-", " ").title(),
        "status": status,
        "priority": priority,
        "created_at_utc": "2026-06-27T00:00:00Z",
        "updated_at_utc": "2026-06-27T01:00:00Z",
        "proposal": {
            "problem": "Problem for %s" % task_id,
            "proposed_change": "Change for %s" % task_id,
            "impact": "",
            "risk": "",
            "estimated_size": "small",
            "acceptance_criteria": ["works"],
            "required_proof": ["proof"],
            "rejection_conditions": [],
        },
        "parallel_safety": {
            "likely_touched_files": paths or [],
            "shared_state_risks": [],
            "safe_parallel_neighbors": [],
            "avoid_parallel_with": [],
            "notes": "",
        },
        "history": [
            {
                "at_utc": "2026-06-27T01:00:00Z",
                "actor": "test",
                "status": status,
                "note": "set %s" % status,
            }
        ],
        "worker": {},
        "implementation_review": {},
        "scout_review": {},
    }


class LabyrinthQueueBoardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.queue_root = Path(self.tempdir.name)

    def write_task(self, location: str, task: dict[str, object]) -> None:
        path = self.queue_root / location / ("%s.json" % task["id"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(task, indent=2, sort_keys=True) + "\n")

    def test_snapshot_groups_lanes_and_marks_stale_ready_conflicts(self) -> None:
        active = make_task("active-runner", "in_progress", paths=["scripts/run_scene.gd"])
        active["worker"] = {
            "branch": "codex/active-runner",
            "heartbeat_at_utc": "2026-06-27T01:00:00Z",
            "leased_by": "worker",
            "thread_id": "thread-1",
            "worktree_path": "/tmp/worktree",
        }
        ready = make_task("ready-overlap", "ready", paths=["scripts/run_scene.gd"], priority=5)
        abandoned = make_task("abandoned-work", "abandoned")

        self.write_task("queue", active)
        self.write_task("queue", ready)
        self.write_task("archive", abandoned)

        snapshot = queue_board.build_board_snapshot(
            repo=ROOT,
            queue_root=self.queue_root,
            include_archive=True,
            stale_hours=0.001,
        )

        lanes = {lane["id"]: lane for lane in snapshot["lanes"]}
        ready_task = lanes["ready"]["tasks"][0]
        active_task = lanes["assigned"]["tasks"][0]
        terminal_task = lanes["terminal"]["tasks"][0]

        self.assertEqual(snapshot["counts"]["ready"], 1)
        self.assertEqual(snapshot["counts"]["terminal"], 1)
        self.assertEqual(snapshot["counts"]["stale_active"], 1)
        self.assertEqual(ready_task["id"], "ready-overlap")
        self.assertEqual(ready_task["conflict_score"], 10)
        self.assertEqual(ready_task["conflict_tasks"], ["active-runner"])
        self.assertTrue(active_task["is_stale"])
        self.assertEqual(terminal_task["id"], "abandoned-work")
        self.assertTrue(terminal_task["is_archived"])

    def test_snapshot_reports_invalid_queue_files(self) -> None:
        bad_path = self.queue_root / "queue" / "bad.json"
        bad_path.parent.mkdir(parents=True, exist_ok=True)
        bad_path.write_text("{not json\n")

        snapshot = queue_board.build_board_snapshot(repo=ROOT, queue_root=self.queue_root)

        self.assertEqual(snapshot["counts"]["total"], 0)
        self.assertEqual(len(snapshot["errors"]), 1)
        self.assertIn("bad.json", snapshot["errors"][0]["path"])


if __name__ == "__main__":
    unittest.main()
