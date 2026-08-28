#!/usr/bin/env python3
"""Run and compare Escape the Umbra performance evidence.

This wrapper keeps benchmark selection, result extraction, environment metadata,
and base-vs-candidate summaries consistent across performance passes.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import platform
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
HEADLESS_BENCHMARKS = {
    "simulation": ("PERF RESULT:", "tests/performance_benchmark.gd"),
    "runtime_integration": (
        "RUNTIME INTEGRATION PERF RESULT:",
        "tests/runtime_integration_performance_benchmark.gd",
    ),
    "trap_idle": (
        "TRAP IDLE PERF RESULT:",
        "tests/trap_idle_performance_benchmark.gd",
    ),
    "combat_board_submission": (
        "COMBAT BOARD SUBMISSION PERF RESULT:",
        "tests/combat_board_submission_performance_benchmark.gd",
    ),
}
NATIVE_BENCHMARKS = {
    "render": ("RENDER PERF RESULT:", "tests/render_performance_benchmark.gd"),
    "runtime_frame": (
        "RUNTIME FRAME PERF RESULT:",
        "tests/runtime_frame_performance_benchmark.gd",
    ),
    "reward_animation": (
        "REWARD ANIMATION PERF RESULT:",
        "tests/reward_animation_performance_benchmark.gd",
    ),
}

COMPARISON_METRICS = {
    "render.idle.frame_interval_ms.median": "lower",
    "render.idle.frame_interval_ms.p95": "lower",
    "render.idle.render_setup_cpu_ms.median": "lower",
    "render.idle.viewport_render_cpu_ms.median": "lower",
    "render.idle.viewport_render_gpu_ms.median": "lower",
    "render.idle.frames_over_16_67_ms": "lower",
    "render.idle.draw_calls.median": "lower",
    "render.idle.dynamic_draw_cpu_us_per_phase_frame": "lower",
    "render.interaction.frame_interval_ms.median": "lower",
    "render.interaction.frame_interval_ms.p95": "lower",
    "render.interaction.render_setup_cpu_ms.median": "lower",
    "render.interaction.viewport_render_cpu_ms.median": "lower",
    "render.interaction.viewport_render_gpu_ms.median": "lower",
    "render.interaction.frames_over_16_67_ms": "lower",
    "render.interaction.draw_calls.median": "lower",
    "render.interaction.dynamic_draw_cpu_us_per_phase_frame": "lower",
    "render.movement.frame_interval_ms.median": "lower",
    "render.movement.frame_interval_ms.p95": "lower",
    "render.movement.render_setup_cpu_ms.median": "lower",
    "render.movement.viewport_render_cpu_ms.median": "lower",
    "render.movement.viewport_render_gpu_ms.median": "lower",
    "render.movement.frames_over_16_67_ms": "lower",
    "render.movement.draw_calls.median": "lower",
    "render.movement.dynamic_draw_cpu_us_per_phase_frame": "lower",
    "render.action_heavy.frame_interval_ms.median": "lower",
    "render.action_heavy.frame_interval_ms.p95": "lower",
    "render.action_heavy.render_setup_cpu_ms.median": "lower",
    "render.action_heavy.viewport_render_cpu_ms.median": "lower",
    "render.action_heavy.viewport_render_gpu_ms.median": "lower",
    "render.action_heavy.frames_over_16_67_ms": "lower",
    "render.action_heavy.frames_over_33_33_ms": "lower",
    "render.action_heavy.draw_calls.median": "lower",
    "render.action_heavy.dynamic_draw_cpu_us_per_phase_frame": "lower",
    "render.static_memory_bytes": "lower",
    "runtime_frame.idle.frame_interval_ms.median": "lower",
    "runtime_frame.idle.frame_interval_ms.p95": "lower",
    "runtime_frame.idle.render_setup_cpu_ms.median": "lower",
    "runtime_frame.idle.viewport_render_cpu_ms.median": "lower",
    "runtime_frame.idle.viewport_render_gpu_ms.median": "lower",
    "runtime_frame.idle.frames_over_16_67_ms": "lower",
    "runtime_frame.cold_interaction.card_click_handler.duration_ms.median": "lower",
    "runtime_frame.cold_interaction.card_click_handler.duration_ms.p95": "lower",
    "runtime_frame.cold_interaction.preview_hover_handler.duration_ms.median": "lower",
    "runtime_frame.cold_interaction.preview_hover_handler.duration_ms.p95": "lower",
    "runtime_frame.cold_interaction.rendered_frames.frame_interval_ms.p95": "lower",
    "runtime_frame.cold_interaction.rendered_frames.frames_over_16_67_ms": "lower",
    "runtime_frame.card_click_handler.duration_ms.median": "lower",
    "runtime_frame.card_click_handler.duration_ms.p95": "lower",
    "runtime_frame.card_click_frame_completion.duration_ms.p95": "lower",
    "runtime_frame.cold_preview_hover_handler.duration_ms.median": "lower",
    "runtime_frame.cold_preview_hover_handler.duration_ms.p95": "lower",
    "runtime_frame.cold_preview_hover_frame_completion.duration_ms.p95": "lower",
    "runtime_frame.cold_preview_canvas_pipeline_compilations": "lower",
    "runtime_frame.preview_hover_handler.duration_ms.median": "lower",
    "runtime_frame.preview_hover_handler.duration_ms.p95": "lower",
    "runtime_frame.preview_hover_frame_completion.duration_ms.p95": "lower",
    "runtime_frame.warm_preview_canvas_pipeline_compilations": "lower",
    "runtime_frame.target_step_completion.duration_ms.p95": "lower",
    "runtime_frame.action_completion.duration_ms.p95": "lower",
    "runtime_frame.action_play.frame_interval_ms.median": "lower",
    "runtime_frame.action_play.frame_interval_ms.p95": "lower",
    "runtime_frame.action_play.render_setup_cpu_ms.median": "lower",
    "runtime_frame.action_play.viewport_render_cpu_ms.median": "lower",
    "runtime_frame.action_play.viewport_render_gpu_ms.median": "lower",
    "runtime_frame.action_play.frames_over_16_67_ms": "lower",
    "runtime_frame.action_play.frames_over_33_33_ms": "lower",
    "runtime_frame.enemy_round_matrix.specialists.total_ms": "lower",
    "runtime_frame.enemy_round_matrix.specialists.viewport_render_cpu_ms.median": "lower",
    "runtime_frame.enemy_round_matrix.specialists.viewport_render_gpu_ms.median": "lower",
    "runtime_frame.enemy_round_matrix.split_swarm.total_ms": "lower",
    "runtime_frame.enemy_round_matrix.split_swarm.viewport_render_cpu_ms.median": "lower",
    "runtime_frame.enemy_round_matrix.split_swarm.viewport_render_gpu_ms.median": "lower",
    "runtime_frame.enemy_round_matrix.dragon_support.total_ms": "lower",
    "runtime_frame.enemy_round_matrix.dragon_support.viewport_render_cpu_ms.median": "lower",
    "runtime_frame.enemy_round_matrix.dragon_support.viewport_render_gpu_ms.median": "lower",
    "runtime_frame.static_memory_bytes": "lower",
    "reward_animation.idle.frame_interval_ms.median": "lower",
    "reward_animation.idle.frame_interval_ms.p95": "lower",
    "reward_animation.idle.frames_over_16_67_ms": "lower",
    "reward_animation.victory.frame_interval_ms.median": "lower",
    "reward_animation.victory.frame_interval_ms.p95": "lower",
    "reward_animation.victory.frames_over_16_67_ms": "lower",
    "reward_animation.victory.frames_over_33_33_ms": "lower",
    "reward_animation.per_card_flips.card_1.frame_interval_ms.p95": "lower",
    "reward_animation.per_card_flips.card_2.frame_interval_ms.p95": "lower",
    "reward_animation.per_card_flips.card_3.frame_interval_ms.p95": "lower",
    "reward_animation.reward_reveal.frame_interval_ms.median": "lower",
    "reward_animation.reward_reveal.frame_interval_ms.p95": "lower",
    "reward_animation.reward_reveal.frames_over_16_67_ms": "lower",
    "reward_animation.reward_reveal.frames_over_33_33_ms": "lower",
    "reward_animation.static_memory_bytes": "lower",
    "simulation.board_submission_us_per_call": "lower",
    "simulation.enemy_forecast_us_per_call": "lower",
    "simulation.presentation_cached_us_per_call": "lower",
    "runtime_integration.full_ui_cached_us_per_refresh": "lower",
    "trap_idle.lookup_us_per_call.median": "lower",
    "trap_idle.lookup_us_per_call.p95": "lower",
    "combat_board_submission.identical_submission_usec.median": "lower",
    "combat_board_submission.effect_progress_submission_usec.median": "lower",
    "combat_board_submission.effect_progress_submission_usec.p95": "lower",
    "combat_board_submission.movement_submission_usec.median": "lower",
    "combat_board_submission.movement_submission_usec.p95": "lower",
}

# Enemy rounds contain long authored animations; completion duration cannot
# substitute for the frame tails or synchronous input cost within that interval.
COMPARISON_METRICS.update({
    f"runtime_frame.enemy_round_matrix.{composition}.{metric}": "lower"
    for composition in ("specialists", "split_swarm", "dragon_support")
    for metric in (
        "input_handler_ms", "frame_interval_ms.median", "frame_interval_ms.p95",
        "frame_interval_ms.p99", "frame_interval_ms.max",
        "frames_over_16_67_ms", "frames_over_33_33_ms",
    )
})

COMPATIBILITY_FIELDS = {
    "report schema": ("schema_version",),
    "platform": ("environment", "platform"),
    "machine": ("environment", "machine"),
    "Godot version": ("environment", "godot"),
    "simulation schema": ("benchmarks", "simulation", "result", "schema_version"),
    "enemy forecast digest": ("benchmarks", "simulation", "result", "enemy_forecast_digest"),
    "enemy forecast steps": ("benchmarks", "simulation", "result", "enemy_forecast_step_count"),
    "render schema": ("benchmarks", "render", "result", "schema_version"),
    "render workload": ("benchmarks", "render", "result", "workload_id"),
    "viewport": ("benchmarks", "render", "result", "viewport"),
    "renderer": ("benchmarks", "render", "result", "renderer"),
    "rendering method": ("benchmarks", "render", "result", "rendering_method"),
    "warmup frames": ("benchmarks", "render", "result", "warmup_frames"),
    "phase frames": ("benchmarks", "render", "result", "phase_frames"),
    "ambient particle count": ("benchmarks", "render", "result", "ambient_particle_count"),
    "runtime frame schema": ("benchmarks", "runtime_frame", "result", "schema_version"),
    "enemy round semantics": ("benchmarks", "runtime_frame", "result", "enemy_round_digests"),
    "runtime frame workload": ("benchmarks", "runtime_frame", "result", "workload_id"),
    "runtime frame viewport": ("benchmarks", "runtime_frame", "result", "viewport"),
    "runtime frame renderer": ("benchmarks", "runtime_frame", "result", "renderer"),
    "runtime frame rendering method": ("benchmarks", "runtime_frame", "result", "rendering_method"),
    "runtime frame warmup": ("benchmarks", "runtime_frame", "result", "warmup_frames"),
    "runtime frame low processor mode": ("benchmarks", "runtime_frame", "result", "probe_low_processor_usage_mode"),
    "runtime frame low processor sleep": ("benchmarks", "runtime_frame", "result", "probe_low_processor_usage_mode_sleep_usec"),
    "runtime frame foreground window": ("benchmarks", "runtime_frame", "result", "probe_foreground_window"),
    "runtime frame window mode": ("benchmarks", "runtime_frame", "result", "probe_window_mode"),
    "runtime frame render pulse": ("benchmarks", "runtime_frame", "result", "probe_render_pulse"),
    "runtime frame throttle threshold": ("benchmarks", "runtime_frame", "result", "probe_throttle_threshold_ms"),
    "reward animation schema": ("benchmarks", "reward_animation", "result", "schema_version"),
    "reward animation workload": ("benchmarks", "reward_animation", "result", "workload_id"),
    "reward animation viewport": ("benchmarks", "reward_animation", "result", "viewport"),
    "reward animation renderer": ("benchmarks", "reward_animation", "result", "renderer"),
    "reward animation rendering method": ("benchmarks", "reward_animation", "result", "rendering_method"),
    "reward animation low processor mode": ("benchmarks", "reward_animation", "result", "probe_low_processor_usage_mode"),
    "reward animation low processor sleep": ("benchmarks", "reward_animation", "result", "probe_low_processor_usage_mode_sleep_usec"),
    "reward animation foreground window": ("benchmarks", "reward_animation", "result", "probe_foreground_window"),
    "reward animation window mode": ("benchmarks", "reward_animation", "result", "probe_window_mode"),
    "reward animation render pulse": ("benchmarks", "reward_animation", "result", "probe_render_pulse"),
    "reward animation throttle threshold": ("benchmarks", "reward_animation", "result", "probe_throttle_threshold_ms"),
    "combat board submission schema": ("benchmarks", "combat_board_submission", "result", "schema_version"),
    "combat board submission workload": ("benchmarks", "combat_board_submission", "result", "workload_id"),
    "combat board submission retained layers": ("benchmarks", "combat_board_submission", "result", "retained_layer_count"),
    "combat board submission samples": ("benchmarks", "combat_board_submission", "result", "animation_samples"),
}


def _command_output(command: list[str], cwd: Path, timeout: int) -> tuple[int, str, float]:
    started = time.monotonic()
    process = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
    return process.returncode, process.stdout, time.monotonic() - started


def _extract_json(output: str, marker: str) -> dict[str, Any]:
    for line in reversed(output.splitlines()):
        if marker not in line or f"{marker} FAIL" in line:
            continue
        payload = line.split(marker, 1)[1].strip()
        value = json.loads(payload)
        if not isinstance(value, dict):
            raise ValueError(f"{marker} payload was not a JSON object")
        return value
    raise ValueError(f"missing successful result marker: {marker}")


def _run_benchmark(
    name: str,
    marker: str,
    script: str,
    task_id: str,
    native: bool,
    timeout: int,
) -> dict[str, Any]:
    if native:
        command = [
            sys.executable,
            "tools/visual_probe_runner.py",
            script,
            "--task-id",
            task_id,
            "--no-headless",
            "--display-driver",
            (
                "macos"
                if sys.platform == "darwin"
                else "windows" if sys.platform == "win32" else "x11"
            ),
            "--audio-driver",
            "Dummy",
            "--timeout",
            str(timeout),
            "--startup-timeout",
            "12",
            "--min-images",
            "1",
            "--expect-size",
            "1920x1080",
        ]
    else:
        command = [
            sys.executable,
            "tools/godot_task_runner.py",
            "--task-id",
            task_id,
            "--timeout",
            str(timeout),
            "--",
            "godot",
            "--headless",
            "--path",
            ".",
            "--audio-driver",
            "Dummy",
            "--script",
            f"res://{script}",
        ]
    returncode, output, duration = _command_output(command, ROOT, timeout + 30)
    if returncode != 0:
        tail = "\n".join(output.splitlines()[-80:])
        raise RuntimeError(f"{name} failed with exit code {returncode}:\n{tail}")
    result = _extract_json(output, marker)
    semantic_errors = result.get("semantic_errors", [])
    if semantic_errors:
        raise RuntimeError(f"{name} reported semantic errors: {semantic_errors}")
    print(f"PASS {name} ({duration:.2f}s)")
    return {"duration_seconds": duration, "result": result}


def _godot_version() -> str:
    try:
        result = subprocess.run(
            ["godot", "--version"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=10,
            check=False,
        )
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def _git_metadata() -> dict[str, Any]:
    def read(*arguments: str) -> str:
        result = subprocess.run(
            ["git", *arguments],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=10,
            check=False,
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"

    return {
        "revision": read("rev-parse", "HEAD"),
        "branch": read("branch", "--show-current"),
        "dirty": bool(read("status", "--porcelain")),
    }


def command_run(args: argparse.Namespace) -> int:
    report: dict[str, Any] = {
        "schema_version": 1,
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "environment": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "python": platform.python_version(),
            "godot": _godot_version(),
            "git": _git_metadata(),
        },
        "benchmarks": {},
    }
    for name, (marker, script) in HEADLESS_BENCHMARKS.items():
        report["benchmarks"][name] = _run_benchmark(
            name, marker, script, args.task_id, False, args.timeout
        )
    if args.native:
        for name, (marker, script) in NATIVE_BENCHMARKS.items():
            report["benchmarks"][name] = _run_benchmark(
                name, marker, script, args.task_id, True, args.timeout
            )
    output_path = Path(args.output).expanduser().resolve() if args.output else Path(
        f"/tmp/labyrinth-performance-{dt.datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(output_path)
    return 0


def _metric_value(report: dict[str, Any], metric_path: str) -> float | None:
    parts = metric_path.split(".")
    benchmark = report.get("benchmarks", {}).get(parts[0], {})
    value: Any = benchmark.get("result", {})
    for part in parts[1:]:
        if not isinstance(value, dict) or part not in value:
            return None
        if part == "viewport_render_gpu_ms" and not value.get("viewport_render_gpu_timing_available", False):
            return None
        value = value[part]
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    return None


def _nested_value(report: dict[str, Any], path: tuple[str, ...]) -> Any:
    value: Any = report
    for part in path:
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value


def _compatibility_problems(
    baseline: dict[str, Any], candidate: dict[str, Any]
) -> list[str]:
    problems: list[str] = []
    for label, path in COMPATIBILITY_FIELDS.items():
        before = _nested_value(baseline, path)
        after = _nested_value(candidate, path)
        if before is None and after is None:
            continue
        if before is None or after is None:
            problems.append(f"{label} metadata missing (baseline={before!r}, candidate={after!r})")
        elif before != after:
            problems.append(f"{label} differs (baseline={before!r}, candidate={after!r})")
    return problems


def command_compare(args: argparse.Namespace) -> int:
    baseline = json.loads(Path(args.baseline).read_text(encoding="utf-8"))
    candidate = json.loads(Path(args.candidate).read_text(encoding="utf-8"))
    compatibility_problems = _compatibility_problems(baseline, candidate)
    if compatibility_problems:
        details = "\n".join(f"- {problem}" for problem in compatibility_problems)
        if not args.allow_incompatible:
            raise RuntimeError(
                "reports are not safely comparable; rerun matching captures or pass "
                f"--allow-incompatible to print a clearly qualified table:\n{details}"
            )
        print(f"WARNING: comparing incompatible reports:\n{details}", file=sys.stderr)
    rows: list[tuple[str, float, float, float]] = []
    for metric in COMPARISON_METRICS:
        before = _metric_value(baseline, metric)
        after = _metric_value(candidate, metric)
        if before is None or after is None:
            continue
        change = 0.0 if before == 0.0 and after == 0.0 else ((after - before) / before * 100.0 if before else float("inf"))
        rows.append((metric, before, after, change))
    if not rows:
        raise RuntimeError("the reports had no comparable metrics")
    print("| Metric | Baseline | Candidate | Change |")
    print("|---|---:|---:|---:|")
    for metric, before, after, change in rows:
        change_text = "n/a" if change == float("inf") else f"{change:+.1f}%"
        print(f"| `{metric}` | {before:.3f} | {after:.3f} | {change_text} |")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    run_parser = subparsers.add_parser("run", help="capture a structured performance report")
    run_parser.add_argument("--task-id", required=True)
    run_parser.add_argument("--native", action="store_true", help="include the native 1920x1080 render probe")
    run_parser.add_argument("--timeout", type=int, default=120)
    run_parser.add_argument("--output")
    run_parser.set_defaults(func=command_run)
    compare_parser = subparsers.add_parser("compare", help="print a baseline-vs-candidate metric table")
    compare_parser.add_argument("baseline")
    compare_parser.add_argument("candidate")
    compare_parser.add_argument(
        "--allow-incompatible",
        action="store_true",
        help="print a qualified table even when environment or workload metadata differs",
    )
    compare_parser.set_defaults(func=command_compare)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        return int(args.func(args))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
