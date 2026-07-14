from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "labyrinth_task_queue.py"
HEAD = subprocess.run(
    ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip()


class LabyrinthTaskQueueTests(unittest.TestCase):
    def run_queue(self, queue_root: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--repo", str(ROOT), "--queue-root", str(queue_root), *args],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_verified_handoff_file_completes_queue_without_flag_bridge(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            queue_root = root / "tasks"
            proposal_path = root / "proposal.json"
            proposal_path.write_text(
                json.dumps(
                    {
                        "id": "handoff-test",
                        "title": "Handoff test",
                        "priority": 3,
                        "proposal": {
                            "problem": "Long queue commands are error prone.",
                            "why_now": "Workers currently copy many fields.",
                            "proposed_change": "Package one handoff file.",
                            "impact": "Queue completion is reliable.",
                            "risk": "The file could omit required review state.",
                            "estimated_size": "small",
                            "risk_tier": "low",
                            "acceptance_criteria": ["One handoff file carries reviewed state."],
                            "required_proof": ["Queue unit test."],
                            "rejection_conditions": ["Reject an unreviewed handoff."],
                        },
                        "parallel_safety": {"likely_touched_files": ["tools/labyrinth_task_queue.py"]},
                    }
                )
            )
            imported = self.run_queue(
                queue_root,
                "import",
                "--file",
                str(proposal_path),
                "--status",
                "ready",
                "--reviewer",
                "scout",
                "--review-summary",
                "ready",
            )
            self.assertEqual(imported.returncode, 0, imported.stderr)

            handoff_path = root / "handoff.json"
            handoff = self.run_queue(
                queue_root,
                "handoff",
                "handoff-test",
                "--reviewer",
                "peer",
                "--signoff",
                "Reviewed all requirements.",
                "--proof",
                "Focused tests pass.",
                "--commit",
                HEAD,
                "--inspection-not-applicable",
                "Tooling-only change.",
                "--output",
                str(handoff_path),
            )
            self.assertEqual(handoff.returncode, 0, handoff.stderr)
            completed = self.run_queue(
                queue_root,
                "complete",
                "handoff-test",
                "--handoff-file",
                str(handoff_path),
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            task = json.loads((queue_root / "queue" / "handoff-test.json").read_text())
            self.assertEqual(task["status"], "ready_for_user")
            self.assertEqual(task["proposal"]["risk_tier"], "low")
            self.assertEqual(task["implementation_review"]["reviewer"], "peer")
            self.assertFalse(task["inspection_fixture"]["applicable"])

    def test_ready_task_requires_acceptance_and_proof(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            proposal_path = root / "proposal.json"
            proposal_path.write_text(json.dumps({"id": "empty-contract", "title": "Empty contract"}))
            result = self.run_queue(
                root / "tasks",
                "import",
                "--file",
                str(proposal_path),
                "--status",
                "ready",
                "--reviewer",
                "scout",
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("proposal.problem", result.stderr)

    def test_handoff_accepts_matching_verified_fixture_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            manifest = root / "fixture.json"
            manifest.write_text(
                json.dumps(
                    {
                        "task_id": "fixture-handoff",
                        "run_id": "fixture-run",
                        "scenario": "reward",
                        "summary": "Inspect the reward choice.",
                        "verified": True,
                        "launch_command": "cd /tmp/task && python3 tools/inspection_fixture.py --launch --scenario reward",
                    }
                )
            )
            handoff_path = root / "handoff.json"
            result = self.run_queue(
                root / "tasks",
                "handoff",
                "fixture-handoff",
                "--reviewer",
                "peer",
                "--signoff",
                "signed off",
                "--proof",
                "fixture verified",
                "--commit",
                HEAD,
                "--inspection-manifest",
                str(manifest),
                "--output",
                str(handoff_path),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(handoff_path.read_text())
            self.assertTrue(payload["inspection_fixture"]["applicable"])
            self.assertEqual(payload["inspection_fixture"]["run_id"], "fixture-run")


if __name__ == "__main__":
    unittest.main()
