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
}
NATIVE_BENCHMARK = ("RENDER PERF RESULT:", "tests/render_performance_benchmark.gd")

COMPARISON_METRICS = {
    "render.idle.frame_interval_ms.median": "lower",
    "render.idle.frame_interval_ms.p95": "lower",
    "render.idle.frames_over_16_67_ms": "lower",
    "render.idle.draw_calls.median": "lower",
    "render.idle.dynamic_draw_cpu_us_per_phase_frame": "lower",
    "render.action_heavy.frame_interval_ms.median": "lower",
    "render.action_heavy.frame_interval_ms.p95": "lower",
    "render.action_heavy.frames_over_16_67_ms": "lower",
    "render.action_heavy.frames_over_33_33_ms": "lower",
    "render.action_heavy.draw_calls.median": "lower",
    "render.action_heavy.dynamic_draw_cpu_us_per_phase_frame": "lower",
    "render.static_memory_bytes": "lower",
    "simulation.board_submission_us_per_call": "lower",
    "simulation.presentation_cached_us_per_call": "lower",
    "runtime_integration.full_ui_cached_us_per_refresh": "lower",
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


def command_run(args: argparse.Namespace) -> int:
    report: dict[str, Any] = {
        "schema_version": 1,
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "environment": {
            "platform": platform.platform(),
            "python": platform.python_version(),
            "godot": _godot_version(),
        },
        "benchmarks": {},
    }
    for name, (marker, script) in HEADLESS_BENCHMARKS.items():
        report["benchmarks"][name] = _run_benchmark(
            name, marker, script, args.task_id, False, args.timeout
        )
    if args.native:
        marker, script = NATIVE_BENCHMARK
        report["benchmarks"]["render"] = _run_benchmark(
            "render", marker, script, args.task_id, True, args.timeout
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
        value = value[part]
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    return None


def command_compare(args: argparse.Namespace) -> int:
    baseline = json.loads(Path(args.baseline).read_text(encoding="utf-8"))
    candidate = json.loads(Path(args.candidate).read_text(encoding="utf-8"))
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
