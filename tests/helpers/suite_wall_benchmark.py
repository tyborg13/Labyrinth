#!/usr/bin/env python3
"""Scratch-only test-06 timing and executed-assertion evidence.

Snapshot before editing. Interleave three ordinary before/after runs per changed
program; trace assertions separately so tracing overhead never enters medians.
Inventory every program and the main body in both snapshots. Compare counts,
message multisets, and unchanged assertion expressions. All engines use the task
runner. Nothing in a source snapshot is imported through an editor scan. The
registry order uses the measured baseline durations, longest first.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time

from slow_program_benchmark import (
    PROFILE, PROFILE_SOURCE, ROOT, assertion_calls, assertion_equivalence,
    code_only, instrument, prepare,
)
from slow_program_mutations import clone_snapshot

TASK_ID = "test-06"
REPEATS = 3
TIMEOUT_SECONDS = 900
INVENTORY_JOBS = 5
PROGRAMS = ("enc04_forecast_test", "event_feedback_test", "warband_test")
MUTATIONS = (
    ("lob-callout", "enc04_forecast_test", "scripts/enemy_mechanics/lob_view.gd",
     'if Rules.is_lob(action): return Icons.lob_text(Rules.presentation_action(_preview_engine, state, enemy, action))',
     'if Rules.is_lob(action): return Icons.lob_text(Rules.presentation_action(_preview_engine, state, enemy, action)) + " test06 fault"',
     ": aiming copy counts what commits"),
    ("preview-receipt", "event_feedback_test", "scripts/event_reward_preview.gd",
     'stage.set_meta("preview_line", line.duplicate(true))',
     'stage.set_meta("preview_line", {})',
     "Hover shows first concrete line: card"),
    ("command-bonus", "warband_test", "scripts/warband_combat_rules.gd",
     'return Data.fixed_point_amount(command["damage_bonus"]) if Paths.manhattan(enemy["pos"], leader["pos"]) <= int(command["radius"]) else 0',
     'return Data.fixed_point_amount(command["damage_bonus"]) + 1 if Paths.manhattan(enemy["pos"], leader["pos"]) <= int(command["radius"]) else 0',
     "Composite Command at hit position"),
)


def read_trace(path: Path) -> dict:
    source = path.read_text()
    # Godot emits \v and raw control characters for intentionally malformed
    # tokens. Decode those without changing any character in the messages.
    while True:
        try:
            return json.loads(source, strict=False)
        except json.JSONDecodeError as error:
            if source[error.pos:error.pos + 2] != "\\v":
                raise
            source = source[:error.pos] + "\\u000b" + source[error.pos + 2:]


def trace_source(source: str, name: str) -> str:
    result = instrument(source, name)
    masked = code_only(result)
    callbacks = list(re.finditer(r"\b(check|proof_expect)\.call\(", masked))
    for match in reversed(callbacks):
        result = result[:match.start()] + PROFILE + ".forward(" + match[1] + ", " + result[match.end():]
    # The earlier profiler covered _expect/_assert and expect.call. Other
    # programs use equally small bool/message sinks named check or _check.
    pattern = r"^(\s*)(?:static )?func (?:_assert|_expect|_check|check|expect)\((\w+): bool,\s*(\w+): String\) -> void:\s*$"
    lines = result.splitlines(keepends=True)
    masked = code_only(result).splitlines(keepends=True)
    output = []
    for index, (line, clean) in enumerate(zip(lines, masked)):
        output.append(line)
        match = re.match(pattern, clean)
        already_recorded = index + 1 < len(lines) and PROFILE + ".record(" in lines[index + 1]
        if match and not already_recorded:
            output.append(f"{match[1]}\t{PROFILE}.record({match[2]}, {match[3]})\n")
        if re.match(r"^(?:static )?func battle\(", clean):
            output.append(f'\tvar __test06_scope: RefCounted = {PROFILE}.scope({json.dumps(name + ":battle")})\n')
    return "".join(output)


def snapshot(directory: Path) -> None:
    ordinary, traced = directory / "ordinary", directory / "traced"
    prepare(ordinary, ROOT / "tests", profile=False)
    prepare(traced, ROOT / "tests", profile=False)
    # The draw-origin contract reads HEAD. Share the existing read-only Git
    # pointer rather than inventing metadata or changing any checkout.
    for project in (ordinary, traced):
        (project / ".git").symlink_to(ROOT / ".git")
    for path in (traced / "tests").rglob("*.gd"):
        path.write_text(trace_source(path.read_text(), str(path.relative_to(traced))))
    (traced / "tests/helpers/slow_program_profile.gd").write_text(PROFILE_SOURCE)
    # Inventory the main body's own checks independently of its child pool.
    # Ordinary timing/full-suite runs always retain the original orchestration.
    path = traced / "tests/run_tests.gd"
    source = path.read_text().replace(
        "var program_suites: Dictionary = ProgramSuiteRunner.start()",
        "var program_suites: Dictionary = {}")
    source = re.sub(r"\tawait ProgramSuiteRunner.finish\([^\n]+\)\n", "", source)
    path.write_text(source)
    (directory / "registry.json").write_bytes((ROOT / "tests/headless_test_programs.json").read_bytes())


def run(directory: Path, program: str, label: str, *, traced: bool) -> dict:
    project = directory / ("traced" if traced else "ordinary")
    slug = program.replace("/", "-")
    log = directory / f"{slug}-{label}.log"
    profile = directory / f"{slug}-{label}.json"
    registry = {entry["path"]: entry for entry in json.loads((directory / "registry.json").read_text())}
    entry = "res://tests/" + program + ".gd"
    env = os.environ.copy()
    if traced:
        env["TEST05_PROFILE_OUTPUT"] = str(profile)
        bootstrap = log.with_suffix(".gd")
        bootstrap.write_text(f'extends "{entry}"\nfunc _initialize() -> void:\n\troot.add_child({PROFILE}.new())\n\tpreload("res://scripts/parallel_runtime.gd").apply_from_environment()\n\tsuper._initialize()\n')
        entry = str(bootstrap)
    reports = directory / "placement-reports"
    reports.mkdir(exist_ok=True)
    command = ["python3", str(ROOT / "tools/godot_task_runner.py"),
               "--task-id", TASK_ID, "--timeout", str(TIMEOUT_SECONDS), "--stream",
               "--", "godot", "--headless", "--path", str(project), "--script", entry, "--"]
    if program.startswith("suites/encounter_"):
        command.append("--placement-report-directory=" + str(reports))
    command.extend(registry.get("tests/" + program + ".gd", {}).get("args", []))
    started = time.monotonic()
    load = os.getloadavg() if hasattr(os, "getloadavg") else None
    with log.open("w") as output:
        completed = subprocess.run(command, cwd=project, env=env, stdout=output, stderr=subprocess.STDOUT)
    result = {"wall_seconds": time.monotonic() - started, "exit_code": completed.returncode,
              "load_before": load, "log": str(log)}
    log.with_suffix(".result.json").write_text(json.dumps(result, indent=2) + "\n")
    if traced:
        if not profile.exists():
            raise RuntimeError("Missing assertion trace: " + str(log))
        result["profile"] = read_trace(profile)
    print(f"{directory.name} {program} {label}: {result['wall_seconds']:.3f}s exit={completed.returncode}", flush=True)
    return result


def measure(output: Path, programs: list[str]) -> None:
    summary = {}
    for program in programs:
        rows = {phase: [] for phase in ("before", "after")}
        # Alternate the first snapshot too, to distribute drift under host load.
        for repeat in range(REPEATS):
            for phase in (("before", "after") if repeat % 2 == 0 else ("after", "before")):
                row = run(output / phase, program, f"run-{repeat}", traced=False)
                rows[phase].append(row)
                if row["exit_code"]:
                    raise RuntimeError("Ordinary measurement failed: " + row["log"])
        traces = {phase: run(output / phase, program, "trace", traced=True) for phase in rows}
        equivalence = assertion_equivalence(traces["before"]["profile"], traces["after"]["profile"])
        assert equivalence["before_count"] == equivalence["after_count"], equivalence
        assert equivalence["same_message_frequencies"], equivalence
        assert all(not row["profile"]["failures"] and row["exit_code"] == 0 for row in traces.values()), traces
        summary[program] = {"runs": rows, "traces": traces, "equivalence": equivalence,
                            "medians": {phase: statistics.median(row["wall_seconds"] for row in runs)
                                        for phase, runs in rows.items()}}
        (output / "measurements.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(f"ASSERTION EQUIVALENCE {program}: PASS ({equivalence['before_count']} assertions; identical message frequencies)", flush=True)
    source_checks = {}
    for old in (output / "before/ordinary/tests").rglob("*.gd"):
        new = output / "after/ordinary/tests" / old.relative_to(output / "before/ordinary/tests")
        if new.exists() and old.read_bytes() != new.read_bytes():
            source_checks[str(old.relative_to(output / "before/ordinary"))] = assertion_calls(old.read_text()) == assertion_calls(new.read_text())
    (output / "assertion-expressions.json").write_text(json.dumps(source_checks, indent=2) + "\n")
    assert all(source_checks.values()), source_checks


def inventory(output: Path, phase: str = "before") -> None:
    registry = json.loads((output / phase / "registry.json").read_text())
    programs = [entry["path"].removeprefix("tests/").removesuffix(".gd")
                for entry in registry if not entry.get("on_demand") and entry.get("group") != "perf"]
    summary_path = output / ("inventory.json" if phase == "before" else "after-inventory.json")
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    with ThreadPoolExecutor(max_workers=INVENTORY_JOBS) as pool:
        pending = {program: pool.submit(run, output / phase, program, "inventory", traced=True)
                   for program in ["run_tests"] + programs if program not in summary}
        for program, future in pending.items():
            summary[program] = future.result()
            summary_path.write_text(json.dumps(summary, indent=2) + "\n")


def compare_inventories(output: Path) -> None:
    before = json.loads((output / "inventory.json").read_text())
    after = json.loads((output / "after-inventory.json").read_text())
    assert before.keys() == after.keys()
    report = {program: assertion_equivalence(before[program]["profile"], after[program]["profile"])
              for program in before}
    totals = {phase: sum(row["profile"]["assertion_count"] for row in rows.values())
              for phase, rows in (("before", before), ("after", after))}
    result = {"programs": report, "totals_excluding_scheduler": totals,
              # Some suites deliberately capture rejected-input callbacks.
              # Their false values are trace data; the runner's exit verdict
              # and failure-marker scan remain the actual test result.
              "all_runs_passed": all(row["exit_code"] == 0
                                     for rows in (before, after) for row in rows.values())}
    (output / "inventory-equivalence.json").write_text(json.dumps(result, indent=2) + "\n")
    mismatches = [name for name, row in report.items()
                  if row["before_count"] != row["after_count"] or not row["same_message_frequencies"]]
    print(f"FULL ASSERTION INVENTORY: {totals['before']} -> {totals['after']}; diagnostic differences={mismatches}")
    # The director's test-06 feedback accepts variable frame-sampled counts
    # and live diagnostics in untouched programs. Changed programs retain the
    # exact count/message-frequency gate; real engine failures always fail.
    assert set(PROGRAMS).issubset(report), "Changed-program inventory is incomplete"
    changed_mismatches = [name for name in PROGRAMS if name in mismatches]
    assert not changed_mismatches, "Changed-program assertions differ: " + str(changed_mismatches)
    print("CHANGED PROGRAM ASSERTION GATE: PASS", flush=True)
    assert result["all_runs_passed"], "Inspect inventory logs"


def mutations(output: Path) -> None:
    summary = {}
    for name, program, filename, old, new, assertion in MUTATIONS:
        rows = {}
        for phase in ("before", "after"):
            directory = output / "mutations" / (name + "-" + phase)
            clone_snapshot(output / phase / "traced", directory / "traced")
            (directory / "registry.json").write_bytes((output / phase / "registry.json").read_bytes())
            path = directory / "traced" / filename
            source = path.read_text()
            assert source.count(old) == 1, filename
            changed = source.replace(old, new)
            assert sum(a != b for a, b in zip(source.splitlines(), changed.splitlines())) == 1
            path.write_text(changed)
            row = run(directory, program, "fault", traced=True)
            assert row["exit_code"] != 0, name
            assert any(assertion in message for message in row["profile"]["failures"]), row
            rows[phase] = row
        before = rows["before"]["profile"]["failures"]
        after = rows["after"]["profile"]["failures"]
        assert sorted(before) == sorted(after), (name, before, after)
        summary[name] = {"path": filename, "old": old, "new": new, "evidence": rows}
        (output / "mutations.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(f"MUTATION PRESERVED {name}: PASS (identical failing assertions before/after)", flush=True)


def full_report(output: Path, phase: str) -> dict:
    """Retain the scheduler report and actual launch timeline before cleanup."""
    log = (output / (phase + "-full.log")).read_text()
    report_path = Path(re.search(r"^PROGRAM SUITE REPORT: (.+)$", log, re.M)[1])
    report = json.loads(report_path.read_text())
    shutil.copyfile(report_path, output / (phase + "-programs.json"))
    births = {row["name"]: Path(row["attempts"][0]["log_path"]).stat().st_birthtime
              for row in report["results"]}
    start = min(births.values())
    timeline = [{"name": row["name"], "start": births[row["name"]] - start,
                 "end": births[row["name"]] - start + row["seconds"], "seconds": row["seconds"]}
                for row in report["results"]]
    timeline.sort(key=lambda row: row["start"])
    (output / (phase + "-timeline.json")).write_text(json.dumps(timeline, indent=2) + "\n")
    result = {"main_seconds": float(re.search(r"MAIN BODY RUNTIME: ([\d.]+)", log)[1]),
              "main_assertions": int(re.search(r"MAIN BODY ASSERTIONS: (\d+)", log)[1]),
              "suite_seconds": float(re.search(r"FULL SUITE RUNTIME: ([\d.]+)", log)[1]),
              "pool_seconds": report["seconds"], "program_seconds": sum(row["seconds"] for row in report["results"]),
              "programs": len(timeline), "last_launch": max(row["start"] for row in timeline),
              "longest": max(timeline, key=lambda row: row["seconds"]),
              "failed_programs": [row["name"] for row in report["results"] if row["returncode"]],
              "retries": report["retries"]}
    (output / (phase + "-analysis.json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--snapshot", choices=("before", "after"))
    parser.add_argument("--measure", action="store_true")
    parser.add_argument("--inventory", action="store_true")
    parser.add_argument("--inventory-phase", choices=("before", "after"), default="before")
    parser.add_argument("--compare-inventories", action="store_true")
    parser.add_argument("--trace-before", action="store_true")
    parser.add_argument("--mutations", action="store_true")
    parser.add_argument("--full-report", choices=("before", "after"))
    parser.add_argument("--program", action="append")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if args.snapshot:
        snapshot(output / args.snapshot)
    if args.measure:
        measure(output, args.program or list(PROGRAMS))
    if args.inventory:
        inventory(output, args.inventory_phase)
    if args.trace_before:
        for program in args.program or PROGRAMS:
            run(output / "before", program, "diagnostic", traced=True)
    if args.mutations:
        mutations(output)
    if args.full_report:
        full_report(output, args.full_report)
    if args.compare_inventories:
        compare_inventories(output)


if __name__ == "__main__":
    main()
