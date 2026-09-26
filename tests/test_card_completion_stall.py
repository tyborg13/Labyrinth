#!/usr/bin/env python3
"""Standalone synthetic tests for native stall capture/comparison acceptance."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("card_completion_stall", ROOT / "tools/card_completion_stall.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)
HASH = "a" * 64


def report(completion_ms=50):
    """A complete schema-2 capture; no external proof files or Godot required."""
    sources = {name: HASH for name in TOOL.SOURCE_PATHS}
    runtime = {"project.godot": HASH, "scripts/run_scene.gd": HASH}
    row = dict(
        warmup=False, card_id="gust_step", targets=["(1, 2)"], lock_count=1,
        before_state={"analytics": {"combat_id": "isolated"}},
        after_state={"analytics": {"combat_id": "isolated"}},
        interaction=dict(step_count=1, total_target_count=1, max_target_count=1, reached_confirmation=False),
        environment_violations=[],
        after=dict(live_scene_nodes=10, orphan_nodes=0, geometric_hand_hit_indices=[0],
                   hovered_hand_index=0, routed_hand_index=0),
        # First two frames precede the completion window. Last two represent the
        # observed deferred tail, so both displacement directions are testable.
        raw=dict(frame_ids=[1, 2, 3, 4, 5, 6, 7],
                 frame_interval_ms=[1, 1, 1, 1, completion_ms, 1, 1]),
        unlock_frame=5,
    )
    warmup = copy.deepcopy(row)
    warmup["warmup"] = True
    return dict(
        schema_version=2, process_returncode=0, requested_repetitions=1, result_parse_failures=[],
        sources=sources, sources_after=copy.deepcopy(sources),
        runtime_sources=runtime, runtime_sources_after=copy.deepcopy(runtime),
        capture_tool=dict(sha256=HASH, sha256_after=HASH),
        capture_valid=True, capture_failure_reasons=[], environment={},
        result=dict(trace_enabled=False, errors=[], unfocused_observations=0, focus_pauses=0,
                    repetitions=[warmup, row], engine="fixture", renderer="fixture", os="fixture",
                    viewport=[1920, 1080], settings={}),
    )


class CaptureValidationTests(unittest.TestCase):
    def test_valid_capture(self):
        self.assertEqual(TOOL.capture_failures(report()), [])

    def test_reject_invalid_raw_evidence(self):
        cases = (
            ("failed process", lambda r: r.update(process_returncode=1)),
            ("missing exit code", lambda r: r.pop("process_returncode")),
            ("zero repetitions", lambda r: r.update(requested_repetitions=0)),
            ("wrong repetition count", lambda r: r.update(requested_repetitions=2)),
            ("no repetitions", lambda r: r["result"].update(repetitions=[])),
            ("missing warmup", lambda r: r["result"]["repetitions"][0].update(warmup=False)),
            ("extra warmup", lambda r: r["result"]["repetitions"][1].update(warmup=True)),
            ("orphan", lambda r: r["result"]["repetitions"][1]["after"].update(orphan_nodes=1)),
            ("empty samples", lambda r: r["result"]["repetitions"][1]["raw"].update(frame_ids=[])),
            ("missing unlock", lambda r: r["result"]["repetitions"][1].update(unlock_frame=99)),
            ("nonfinite sample", lambda r: r["result"]["repetitions"][1]["raw"]["frame_interval_ms"].__setitem__(0, float("nan"))),
            ("runtime mutation", lambda r: r["runtime_sources_after"].update({"scripts/new.gd": HASH})),
            ("missing runtime binding", lambda r: r.pop("runtime_sources")),
            ("tool mutation", lambda r: r["capture_tool"].update(sha256_after="b" * 64)),
            ("result parse failure", lambda r: r.update(result_parse_failures=["bad JSON"])),
            ("focus loss", lambda r: r["result"].update(focus_pauses=1)),
            ("pointer drift", lambda r: r["result"]["repetitions"][1]["environment_violations"].append({"frame": 2})),
        )
        for label, mutate in cases:
            with self.subTest(label=label):
                invalid = report()
                mutate(invalid)
                self.assertTrue(TOOL.capture_failures(invalid))

    def test_reject_node_growth(self):
        invalid = report()
        invalid["requested_repetitions"] = 2
        rows = invalid["result"]["repetitions"]
        rows.append(copy.deepcopy(rows[1]))
        rows[2]["after"]["live_scene_nodes"] += 1
        self.assertIn("Scene node count changed across measured repetitions", TOOL.capture_failures(invalid))

    def test_parser_rejects_zero_repetitions_before_capture(self):
        argv = ["card_completion_stall.py", "run", "--output", "unused.json",
                "--task-id", "synthetic", "--repetitions", "0"]
        with mock.patch.object(TOOL.sys, "argv", argv), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                TOOL.main()
        self.assertEqual(error.exception.code, 2)


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="completion-comparator-test-")
        self.addCleanup(self.directory.cleanup)
        self.folder = Path(self.directory.name)
        self.output = self.folder / "comparison.json"
        self.base = [report(50), report(50)]
        self.candidate = [report(20), report(20)]

    def compare(self):
        paths = {}
        for side in ("base", "candidate"):
            paths[side] = []
            for index, capture in enumerate(getattr(self, side)):
                path = self.folder / f"{side}-{index}.json"
                path.write_text(json.dumps(capture))
                paths[side].append(path)
        args = SimpleNamespace(**paths, output=self.output, minimum_reduction_ms=10)
        with contextlib.redirect_stdout(io.StringIO()):
            TOOL.compare(args)
        return json.loads(self.output.read_text())

    def test_accept_valid_matched_blocks(self):
        result = self.compare()
        self.assertTrue(result["accepted"])
        self.assertEqual(result["capture_tool_sha256"], HASH)
        self.assertEqual(result["candidate"]["repetitions"], 2)
        self.assertEqual(result["source_bindings"]["candidate"]["runtime_sources"], self.candidate[0]["runtime_sources"])

    def test_reject_mixed_candidate_sources(self):
        for key in ("runtime_sources", "runtime_sources_after"):
            self.candidate[1][key]["scripts/extra.gd"] = HASH
        with self.assertRaisesRegex(ValueError, "Mixed candidate sources"):
            self.compare()

    def test_reject_mixed_baseline_sources(self):
        for key in ("runtime_sources", "runtime_sources_after"):
            self.base[1][key]["scripts/extra.gd"] = HASH
        with self.assertRaisesRegex(ValueError, "Mixed base sources"):
            self.compare()

    def test_reject_different_tool_between_blocks(self):
        self.candidate[1]["capture_tool"].update(sha256="b" * 64, sha256_after="b" * 64)
        with self.assertRaisesRegex(ValueError, "Capture tool differs"):
            self.compare()

    def test_reject_archived_failed_capture(self):
        self.candidate[1].update(capture_valid=False, capture_failure_reasons=["failed"])
        with self.assertRaisesRegex(ValueError, "not recorded as valid"):
            self.compare()

    def test_revalidate_failed_process_despite_valid_flag(self):
        self.candidate[1]["process_returncode"] = 1
        with self.assertRaisesRegex(ValueError, "Probe process failed"):
            self.compare()

    def test_reject_wrong_target(self):
        self.candidate[0]["result"]["repetitions"][1]["targets"].append("(0, 0)")
        with self.assertRaisesRegex(ValueError, "Unmatched gameplay targets"):
            self.compare()

    def test_reject_displaced_200ms_stall_outside_completion_window(self):
        row = self.candidate[0]["result"]["repetitions"][1]
        row["raw"]["frame_interval_ms"][0] = 200
        self.assertEqual(TOOL.samples(self.candidate[0])[1]["completion_max_ms"], 20)
        with self.assertRaisesRegex(ValueError, "Whole-action upper tail regressed"):
            self.compare()
        result = json.loads(self.output.read_text())
        self.assertFalse(result["accepted"])
        self.assertIn("Whole-action upper tail regressed", result["failure_reasons"])
        self.assertEqual(result["candidate"]["whole_max_ms"]["maximum"], 200)

    def test_reject_200ms_stall_in_deferred_tail(self):
        self.candidate[0]["result"]["repetitions"][1]["raw"]["frame_interval_ms"][-1] = 200
        with self.assertRaises(ValueError):
            self.compare()
        result = json.loads(self.output.read_text())
        self.assertFalse(result["accepted"])
        self.assertIn("Completion upper tail regressed", result["failure_reasons"])
        self.assertEqual(result["candidate"]["completion_max_ms"]["maximum"], 200)


if __name__ == "__main__":
    unittest.main()
