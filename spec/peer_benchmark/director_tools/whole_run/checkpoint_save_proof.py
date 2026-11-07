#!/usr/bin/env python3
"""Interleave baseline/candidate save-boundary microbenchmarks without Git writes."""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import statistics
import subprocess
import sys

ROOT = Path("/Users/borgerding/workspace/Labyrinth.worktrees/perf-65")


def source_at(ref: str, path: str) -> str:
    return subprocess.check_output(["git", "show", f"{ref}:{path}"], cwd=ROOT, text=True)


def baseline_store(source: str) -> str:
    # Diagnostic-only split of store_var into its identical encode_variant(false)
    # payload and uint32-length write, matching Godot 4.6's implementation.
    # The baseline retains its original duplicate/queue/flush policy.
    source = re.sub(r"^class_name .*\n", "", source, flags=re.M)
    source = source.replace("static var _session_umbra_depth:",
                            "static var _run_transaction_probe: Callable\n"
                            "static var _perf65_timings: Dictionary = {}\n"
                            "static var _perf65_duplicate_usec: int = 0\n\n"
                            "static var _session_umbra_depth:")
    source = source.replace('var request: Dictionary = {"state": run_state.duplicate(true),',
                            'var duplicate_started: int = Time.get_ticks_usec()\n'
                            '\tvar snapshot: Dictionary = run_state.duplicate(true)\n'
                            '\t_perf65_duplicate_usec = Time.get_ticks_usec() - duplicate_started\n'
                            '\tvar request: Dictionary = {"state": snapshot,')
    source = source.replace('_save_run_state_at(path, request["state"])',
                            '_save_run_state_at(path, request["state"], _run_transaction_probe)')
    start = source.index("static func _save_run_state_at(")
    end = source.index("\nstatic func clear_saved_run", start)
    transaction = source[start:end]
    transaction = transaction.replace("\tfile.store_var(run_state, false)\n",
        '\t_perf65_timings = {"duplicate_usec": _perf65_duplicate_usec}\n'
        '\tvar phase_started: int = Time.get_ticks_usec()\n'
        '\tvar bytes: PackedByteArray = var_to_bytes(run_state)\n'
        '\t_perf65_timings["serialize_usec"] = Time.get_ticks_usec() - phase_started\n'
        '\tphase_started = Time.get_ticks_usec()\n'
        '\tfile.store_32(bytes.size())\n\tfile.store_buffer(bytes)\n')
    transaction = transaction.replace("\tfile.close()\n",
        '\tfile.close()\n\t_perf65_timings["write_usec"] = Time.get_ticks_usec() - phase_started\n', 1)
    transaction = transaction.replace('\tvar live_path: String =',
        '\tphase_started = Time.get_ticks_usec()\n\tvar live_path: String =', 1)
    transaction = transaction.replace('\t_remove_run_file_if_present(backup_path)\n\treturn true',
        '\t_remove_run_file_if_present(backup_path)\n'
        '\t_perf65_timings["rename_usec"] = Time.get_ticks_usec() - phase_started\n\treturn true')
    if "file.store_var(run_state" in transaction or 'timings["rename_usec"]' not in transaction:
        raise ValueError("Baseline transaction no longer matches the audited instrumentation patch")
    return source[:start] + transaction + source[end:]


def median_iqr(values: list[float]) -> str:
    quartiles = statistics.quantiles(values, n=4, method="inclusive")
    return f"{statistics.median(values):.3f} [{quartiles[0]:.3f}, {quartiles[2]:.3f}]"


def report(data: dict, ref: str) -> str:
    groups = defaultdict(lambda: defaultdict(list))
    for sample in data["samples"]:
        groups[sample["boundary"]][sample["candidate"]].append(sample)
    lines = [f"Baseline {ref}; {data['cpu']}; Godot {data['godot']['string']}; headless.",
             "Boundary microbenchmarks with fresh run data for seeds 83/84217; these are not whole runs.",
             "24 AB/BA pairs per boundary per seed. Values: median [Q1, Q3] ms.",
             "Baseline diagnostic instrumentation splits store_var into the same codec and uint32-length write.",
             "Byte-oracle reads run separately, outside timed samples. Main total includes dispatch/collection.", "",
             "| Boundary | Count/side | Main before | Main after | Duplicate before | Duplicate after |",
             "|---|---:|---:|---:|---:|---:|"]
    for boundary, sides in groups.items():
        def metric(side, name):
            return median_iqr([s[name] / 1000 for s in sides[side]])
        lines.append(f"| {boundary} | {len(sides[False])} | {metric(False, 'main_total_usec')} | "
                     f"{metric(True, 'main_total_usec')} | {metric(False, 'duplicate_usec')} | "
                     f"{metric(True, 'duplicate_usec')} |")
    lines.extend(["", "| Boundary | Serialize before → after | Write before → after | Rename before → after | Candidate location |",
                  "|---|---:|---:|---:|---|"])
    for boundary, sides in groups.items():
        cells = [median_iqr([s[key] / 1000 for s in sides[False]]) + " → " +
                 median_iqr([s[key] / 1000 for s in sides[True]])
                 for key in ("serialize_usec", "write_usec", "rename_usec")]
        location = "worker (0 main ms for these phases)" if sides[True][0]["queued"] else "main; durable barrier"
        lines.append(f"| {boundary} | {' | '.join(cells)} | {location} |")
    lines.extend(["", "Counts above are benchmark boundary invocations, not gameplay frequency.",
                  "Whole-run boundary frequency, frame counts >33.3 ms, and whole-run RNG/analytics differences remain pending the approved real-HP driver.",
                  f"Semantic/byte failures: {len(data['errors'])}.", ""])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ref", default="HEAD")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    directory = args.output_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    (directory / ".gdignore").touch()
    store_path = directory / "baseline_store.gd"
    lifecycle_path = directory / "baseline_lifecycle.gd"
    store_path.write_text(baseline_store(source_at(args.baseline_ref, "scripts/progression_store.gd")))
    lifecycle_source = source_at(args.baseline_ref, "scripts/run_persistence.gd")
    lifecycle_path.write_text(lifecycle_source.replace('"res://scripts/progression_store.gd"', json.dumps(str(store_path))))
    ref = subprocess.check_output(["git", "rev-parse", args.baseline_ref], cwd=ROOT, text=True).strip()
    (directory / "baseline-ref.txt").write_text(ref + "\n")
    command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", "perf-65",
               "--stream", "--", "godot", "--headless", "--path", str(ROOT), "--script",
               "tests/perf/checkpoint_save_benchmark.gd", "--", str(store_path), str(lifecycle_path), str(directory)]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (directory / "benchmark.log").write_text(result.stdout)
    print(result.stdout, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    data = json.loads((directory / "samples.json").read_text())
    (directory / "report.md").write_text(report(data, ref))
    print(f"PERF65 TABLES: {directory / 'report.md'}")


if __name__ == "__main__":
    main()
