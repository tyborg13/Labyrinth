from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "parallel_task.py"
SPEC = importlib.util.spec_from_file_location("parallel_task", SCRIPT)
assert SPEC and SPEC.loader
PARALLEL_TASK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PARALLEL_TASK)


class ParallelTaskTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "-q", "-b", "master")
        self.git("config", "user.email", "workflow-tests@example.invalid")
        self.git("config", "user.name", "Workflow Tests")
        (self.repo / "base.txt").write_text("base\n")
        self.git("add", "base.txt")
        self.git("commit", "-q", "-m", "base")

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.repo), *args],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).stdout.strip()

    def runner(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--repo", str(self.repo), *args],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def record_contract(self) -> subprocess.CompletedProcess[str]:
        return self.runner(
            "contract",
            "--risk-tier",
            "standard",
            "--acceptance",
            "The preflight succeeds.",
            "--required-proof",
            "The index tree is unchanged.",
            "--inspection-expectation",
            "Tooling-only; no playable fixture.",
        )

    def test_preflight_proves_and_restores_git_index(self) -> None:
        self.git("switch", "-q", "-c", "codex/preflight")
        contract = self.record_contract()
        self.assertEqual(contract.returncode, 0, contract.stderr)
        tree_before = self.git("write-tree")
        result = self.runner("preflight")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("write-tree"), tree_before)
        self.assertEqual(self.git("status", "--short"), "")
        payload = json.loads(result.stdout)
        self.assertEqual(payload["ahead"], 0)
        self.assertEqual(payload["behind"], 0)
        self.assertTrue(payload["master_contained"])
        self.assertIn("temporary_branch_ref_write", payload["checks"])
        self.assertEqual(self.git("for-each-ref", "--format=%(refname)", "refs/heads/codex/git-write-smoke-*"), "")

    def test_preflight_reports_stale_task_branch(self) -> None:
        base = self.git("rev-parse", "HEAD")
        self.git("branch", "codex/stale", base)
        (self.repo / "upstream.txt").write_text("upstream\n")
        self.git("add", "upstream.txt")
        self.git("commit", "-q", "-m", "upstream")
        self.git("switch", "-q", "codex/stale")
        self.assertEqual(self.record_contract().returncode, 0)
        result = self.runner("preflight")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["behind"], 1)
        self.assertFalse(payload["master_contained"])

    def test_preflight_rejects_dirty_and_non_task_worktrees(self) -> None:
        non_task = self.runner("preflight", "--allow-draft-contract")
        self.assertNotEqual(non_task.returncode, 0)
        self.assertIn("non-task branch", non_task.stderr)
        self.git("switch", "-q", "-c", "codex/dirty")
        self.assertEqual(self.record_contract().returncode, 0)
        (self.repo / "dirty.txt").write_text("dirty\n")
        dirty = self.runner("preflight")
        self.assertNotEqual(dirty.returncode, 0)
        self.assertIn("clean worktree", dirty.stderr)

    def test_prepare_worker_creates_branch_at_requested_base(self) -> None:
        result = self.runner("prepare-worker", "--task-id", "prepared")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("rev-parse", "codex/prepared"), self.git("rev-parse", "master"))
        self.assertIn('"branchName": "codex/prepared"', result.stdout)

    def test_integration_preserves_approval_when_task_patch_is_unchanged(self) -> None:
        base = self.git("rev-parse", "HEAD")
        self.git("branch", "codex/integrate", base)
        (self.repo / "upstream.txt").write_text("upstream\n")
        self.git("add", "upstream.txt")
        self.git("commit", "-q", "-m", "upstream")
        self.git("switch", "-q", "codex/integrate")
        (self.repo / "task.txt").write_text("task\n")
        self.git("add", "task.txt")
        self.git("commit", "-q", "-m", "task")
        authorized = self.runner(
            "authorize-publish",
            "--reviewer",
            "peer-reviewer",
            "--user-approval",
            "User approved publication.",
        )
        self.assertEqual(authorized.returncode, 0, authorized.stderr)

        report = PARALLEL_TASK.integrate_ref(self.repo, "master")

        self.assertTrue(report["task_patch_unchanged"])
        self.assertTrue(report["approval_still_valid"])
        self.assertEqual((self.repo / "task.txt").read_text(), "task\n")
        self.assertEqual((self.repo / "upstream.txt").read_text(), "upstream\n")
        metadata = PARALLEL_TASK.metadata_for(self.repo)
        self.assertEqual(metadata["publication_authorization"]["commit"], self.git("rev-parse", "HEAD"))

    def test_push_requires_authorization_for_exact_head(self) -> None:
        remote_temp = tempfile.TemporaryDirectory()
        self.addCleanup(remote_temp.cleanup)
        remote = Path(remote_temp.name) / "remote.git"
        subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)
        self.git("remote", "add", "origin", str(remote))
        self.git("push", "-q", "origin", "master")
        self.git("switch", "-q", "-c", "codex/unauthorized")
        (self.repo / "task.txt").write_text("task\n")
        self.git("add", "task.txt")
        self.git("commit", "-q", "-m", "task")

        result = self.runner("push", "--no-update-local-master")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("without authorization for the exact HEAD", result.stderr)
        self.assertEqual(self.git("rev-parse", "origin/master"), self.git("rev-parse", "master"))

    def test_changed_integration_blocks_repeated_push_until_reauthorized(self) -> None:
        remote_temp = tempfile.TemporaryDirectory()
        self.addCleanup(remote_temp.cleanup)
        remote = Path(remote_temp.name) / "remote.git"
        upstream = Path(remote_temp.name) / "upstream"
        subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)
        self.git("remote", "add", "origin", str(remote))
        (self.repo / "shared.txt").write_text("one\ntwo\nthree\nfour\n")
        self.git("add", "shared.txt")
        self.git("commit", "-q", "-m", "shared base")
        self.git("push", "-q", "origin", "master")
        self.git("switch", "-q", "-c", "codex/approval-bypass")
        (self.repo / "shared.txt").write_text("ONE\ntwo\nthree\nfour\n")
        self.git("add", "shared.txt")
        self.git("commit", "-q", "-m", "task change")
        authorized = self.runner(
            "authorize-publish",
            "--reviewer",
            "peer-reviewer",
            "--user-approval",
            "User approved original HEAD.",
        )
        self.assertEqual(authorized.returncode, 0, authorized.stderr)

        subprocess.run(["git", "clone", "-q", "-b", "master", str(remote), str(upstream)], check=True)
        subprocess.run(["git", "-C", str(upstream), "config", "user.email", "workflow-tests@example.invalid"], check=True)
        subprocess.run(["git", "-C", str(upstream), "config", "user.name", "Workflow Tests"], check=True)
        (upstream / "shared.txt").write_text("one\ntwo\nthree\nFOUR\n")
        subprocess.run(["git", "-C", str(upstream), "add", "shared.txt"], check=True)
        subprocess.run(["git", "-C", str(upstream), "commit", "-q", "-m", "upstream change"], check=True)
        subprocess.run(["git", "-C", str(upstream), "push", "-q", "origin", "master"], check=True)

        first = self.runner("push", "--no-update-local-master")
        self.assertNotEqual(first.returncode, 0)
        self.assertIn("effective task patch changed", first.stderr)
        first_head = self.git("rev-parse", "HEAD")
        second = self.runner("push", "--no-update-local-master")
        self.assertNotEqual(second.returncode, 0)
        self.assertIn("without authorization for the exact HEAD", second.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), first_head)

        reauthorized = self.runner(
            "authorize-publish",
            "--reviewer",
            "peer-reviewer-second-pass",
            "--user-approval",
            "User approved the integrated HEAD.",
        )
        self.assertEqual(reauthorized.returncode, 0, reauthorized.stderr)
        final = self.runner("push", "--no-update-local-master")
        self.assertEqual(final.returncode, 0, final.stderr)
        self.assertEqual(self.git("rev-parse", "origin/master"), first_head)


if __name__ == "__main__":
    unittest.main()
