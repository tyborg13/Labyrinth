#!/usr/bin/env python3
"""Run disjoint seed shards and the known controls through the task runner."""

from argparse import ArgumentParser
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
SEED_START = 12001
SEED_COUNT = 32
SHARDS = 4
SEED_SHARD_TIMEOUT = 900
CONTROL_TIMEOUT = 180
SECONDARY_KINDS = ("controller_rotate_rb", "mouse_retarget", "controller_aim_dpad", "details_key_i",
                   "controller_stick", "mouse_board_click", "mouse_hover_pass")


def run(directory, timeout, *options):
    directory.mkdir()
    command = [
        sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-120",
        "--timeout", str(timeout), "--stream", "--", "godot", "--headless", "--path", ".",
        "--script", "tools/qa120/campaign.gd", "--", f"--out={directory}", *options,
    ]
    with (directory / "runner.log").open("w") as log:
        process = subprocess.run(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, check=False)
    report = directory / "summary.json"
    data = json.loads(report.read_text()) if report.is_file() else {"counts": {}, "errors": ["Summary missing."]}
    data.update(returncode=process.returncode, command=command, directory=str(directory))
    print(f"QA120 SHARD {directory.name}: exit={process.returncode} {data['counts']}", flush=True)
    return data


def gaps_and_actions(results):
    accepted = Counter()
    for result in results:
        trace = Path(result["directory"]) / "trace.jsonl"
        if not trace.is_file():
            continue
        with trace.open() as stream:
            for line in stream:
                checkpoint = json.loads(line)
                sequence = checkpoint.get("sequence", [])
                if checkpoint["event"] != "window" or len(sequence) != 2:
                    continue
                first, second = sequence
                if first.get("accepted") or first.get("changed"):
                    accepted[f"accepted-gap-{checkpoint['gap']}"] += 1
                    accepted["accepted-first:" + first["kind"]] += 1
                    if second.get("changed"):
                        accepted["accepted-second:" + second["kind"]] += 1
    return accepted


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=SEED_START)
    parser.add_argument("--count", type=int, default=SEED_COUNT)
    parser.add_argument("--shards", type=int, choices=range(1, SHARDS + 1), default=SHARDS)
    parser.add_argument("--control-fixture", type=Path)
    args = parser.parse_args()
    if args.count < 30:
        parser.error("--count must be at least 30 for a soak; use campaign.gd for a smaller focused run")
    directory = args.out.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    controls = ["--case=all"]
    if args.control_fixture:
        controls.append(f"--fixture={args.control_fixture.resolve(strict=True)}")
    with ThreadPoolExecutor(max_workers=args.shards) as pool:
        jobs = []
        for index in range(args.shards):
            low = args.seed + index * args.count // args.shards
            high = args.seed + (index + 1) * args.count // args.shards
            jobs.append(pool.submit(run, directory / f"seeds-{low}-{high - 1}",
                                    SEED_SHARD_TIMEOUT, f"--seed={low}", f"--count={high - low}"))
        matrix = pool.submit(run, directory / "input-matrix", CONTROL_TIMEOUT, "--case=coverage", *controls[1:])
        control = pool.submit(run, directory / "controls", CONTROL_TIMEOUT, *controls)
        results = [job.result() for job in jobs]
        control_result = control.result()
        matrix_result = matrix.result()
    coverage = Counter()
    for result in results:
        coverage.update(result["counts"])
    coverage.update(gaps_and_actions([*results, matrix_result]))
    required = ["section-1", "section-2", "section-3", "guardian", "boss", "ordinary_speed_seed",
                "mouse_select_accepted", "controller_select_accepted", "worker_pending_at_first",
                "pass_input:controller", "pass_input:mouse", "pass_replay_vs_live", "pass_exact_total",
                "pass_visible_rows", "hand_card_values", "rail", "board_red", "board_intents", "details",
                "card_damage_and_status"]
    required.extend(f"accepted-gap-{gap}" for gap in range(7))
    required.extend(f"accepted-first:{kind}" for kind in SECONDARY_KINDS if kind != "mouse_board_click")
    required.extend(f"accepted-second:{kind}" for kind in SECONDARY_KINDS)
    gaps = [key for key in required if coverage[key] == 0]
    if coverage["seeds"] < args.count:
        gaps.append(f"expected {args.count} completed seed visits")
    if coverage["pass_input:mouse"] + coverage["pass_input:controller"] != coverage["pass_exact_total"] + coverage["pass_disclosed_minimum"]:
        gaps.append("a dispatched Pass did not produce an outcome receipt")
    if coverage["pass_live_receipt_unavailable"]:
        gaps.append(f"{coverage['pass_live_receipt_unavailable']} Passes lack live handoff or terminal receipts")
    fails = [item["directory"] for item in [*results, control_result, matrix_result] if item["returncode"] or item["errors"]]
    (directory / "campaign.json").write_text(json.dumps({
        "coverage": dict(sorted(coverage.items())), "coverage_gaps": gaps, "failed_runs": fails,
        "shards": results, "controls": control_result, "input_matrix": matrix_result,
    }, indent=2) + "\n")
    passed = not gaps and not fails
    print(f"QA120 SOAK {'PASS' if passed else 'FAIL'}: {coverage['seeds']} seeds, "
          f"sections {[coverage[f'section-{i}'] for i in range(1, 4)]}, {coverage['guardian']} Guardian, "
          f"{coverage['boss']} dragon, {len(gaps)} coverage gaps, {len(fails)} failed runs", flush=True)
    if gaps:
        print("QA120 COVERAGE GAPS " + ", ".join(gaps), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
