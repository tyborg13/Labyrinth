#!/usr/bin/env python3
"""Keep performance comparisons from accepting absent timing or changed work."""

import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "performance_pass", Path(__file__).resolve().parents[1] / "tools" / "performance_pass.py"
)
performance_pass = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(performance_pass)


class PerformancePassTest(unittest.TestCase):
    def test_gpu_metrics_require_positive_timing_evidence(self):
        phase = {"viewport_render_gpu_ms": {"median": 0.0}}
        report = {"benchmarks": {"runtime_frame": {"result": {"idle": phase}}}}
        metric = "runtime_frame.idle.viewport_render_gpu_ms.median"
        self.assertIsNone(performance_pass._metric_value(report, metric))
        phase["viewport_render_gpu_timing_available"] = False
        self.assertIsNone(performance_pass._metric_value(report, metric))
        phase["viewport_render_gpu_timing_available"] = True
        phase["viewport_render_gpu_ms"]["median"] = 2.5
        self.assertEqual(performance_pass._metric_value(report, metric), 2.5)

    def test_forecast_semantic_changes_reject_comparison(self):
        baseline = {"benchmarks": {"simulation": {"result": {"enemy_forecast_digest": 11}}}}
        candidate = {"benchmarks": {"simulation": {"result": {"enemy_forecast_digest": 12}}}}
        problems = performance_pass._compatibility_problems(baseline, candidate)
        self.assertTrue(any("enemy forecast digest differs" in problem for problem in problems))

    def test_native_enemy_round_changes_reject_comparison(self):
        baseline = {"benchmarks": {"runtime_frame": {"result": {"enemy_round_digests": {"specialists": {"digest": 11, "steps": 3, "enemy_activations": 2}}}}}}
        candidate = {"benchmarks": {"runtime_frame": {"result": {"enemy_round_digests": {"specialists": {"digest": 12, "steps": 3, "enemy_activations": 2}}}}}}
        problems = performance_pass._compatibility_problems(baseline, candidate)
        self.assertTrue(any("enemy round semantics differs" in problem for problem in problems))

    def test_process_clock_reports_cannot_compare_to_post_draw_reports(self):
        for benchmark in ("runtime_frame", "reward_animation"):
            baseline = {"benchmarks": {benchmark: {"result": {}}}}
            candidate = {"benchmarks": {benchmark: {"result": {"sample_boundary": "RenderingServer.frame_post_draw_v1"}}}}
            problems = performance_pass._compatibility_problems(baseline, candidate)
            self.assertTrue(any("sample boundary metadata missing" in problem for problem in problems))


if __name__ == "__main__":
    unittest.main()
