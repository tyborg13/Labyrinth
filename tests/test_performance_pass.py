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

    def test_surface_target_or_preview_changes_reject_comparison(self):
        import copy
        baseline = {"benchmarks": {"surface_frame": {"result": {"hover": {"chain_bolt": {
            "target_count": 2, "target_tiles": ["(2, 2)", "(3, 3)"],
            "presentation_digests": [11, 12], "committed_state_digest": 42,
        }}}}}}
        for field, replacement in (("target_tiles", ["(2, 2)", "(4, 4)"]), ("presentation_digests", [11, 13])):
            candidate = copy.deepcopy(baseline)
            candidate["benchmarks"]["surface_frame"]["result"]["hover"]["chain_bolt"][field] = replacement
            problems = performance_pass._compatibility_problems(baseline, candidate)
            self.assertTrue(any(field in problem for problem in problems))

    def test_targeted_native_selection_requires_native_flag(self):
        args = performance_pass.build_parser().parse_args(["run", "--task-id", "proof", "--benchmark", "surface_frame"])
        with self.assertRaisesRegex(ValueError, "requires --native"):
            performance_pass.command_run(args)

    def test_surface_cpu_route_changes_reject_comparison(self):
        baseline = {"benchmarks": {"surface_cpu": {"result": {"cases": {"chain": {"route_digest": 11}}}}}}
        candidate = {"benchmarks": {"surface_cpu": {"result": {"cases": {"chain": {"route_digest": 12}}}}}}
        self.assertTrue(any("route_digest differs" in problem for problem in performance_pass._compatibility_problems(baseline, candidate)))

    def test_process_clock_reports_cannot_compare_to_post_draw_reports(self):
        for benchmark in ("runtime_frame", "reward_animation"):
            baseline = {"benchmarks": {benchmark: {"result": {}}}}
            candidate = {"benchmarks": {benchmark: {"result": {"sample_boundary": "RenderingServer.frame_post_draw_v1"}}}}
            problems = performance_pass._compatibility_problems(baseline, candidate)
            self.assertTrue(any("sample boundary metadata missing" in problem for problem in problems))


    def test_different_cpu_profiles_reject_comparison(self):
        baseline = {"environment": {"cpu_profile": "normal"}}
        candidate = {"environment": {"cpu_profile": "background"}}
        self.assertTrue(any("CPU scheduling profile differs" in p for p in performance_pass._compatibility_problems(baseline, candidate)))

    def test_ui_trade_semantics_reject_comparison(self):
        baseline = {"benchmarks": {"ui_flow": {"result": {"interaction_semantics": {"buy": {"held_embers": 10}}}}}}
        candidate = {"benchmarks": {"ui_flow": {"result": {"interaction_semantics": {"buy": {"held_embers": 20}}}}}}
        self.assertTrue(any("interaction_semantics differs" in p for p in performance_pass._compatibility_problems(baseline, candidate)))

    def test_profile_wraps_only_child_command(self):
        from unittest.mock import patch
        command = ["python3", "tools/godot_task_runner.py", "--", "godot"]
        with patch.object(performance_pass.sys, "platform", "darwin"), patch.object(performance_pass.shutil, "which", return_value="/usr/sbin/taskpolicy"):
            self.assertEqual(performance_pass._cpu_profile_command(command, "normal"), command)
            self.assertEqual(performance_pass._cpu_profile_command(command, "background"), ["/usr/sbin/taskpolicy", "-c", "background", *command])
        with patch.object(performance_pass.sys, "platform", "linux"):
            with self.assertRaisesRegex(ValueError, "macOS"):
                performance_pass._cpu_profile_command(command, "background")


if __name__ == "__main__":
    unittest.main()
