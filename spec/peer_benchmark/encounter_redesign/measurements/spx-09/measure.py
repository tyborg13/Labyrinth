#!/usr/bin/env python3
"""spx-09 measurement: Ember Hoarder beside the Warband and Umbral Snare (revision 7).

Runs the meas-02 bot (tools/encounter_measurement_bot.gd, frozen policy v2) for
each cohort/tier through the task runner, then writes gzipped raw records,
summary.json and report.md beside this script. Numbers only; no tuning.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sys.path.insert(0, str(ROOT / "tools"))
from encounter_sweep import distribution  # noqa: E402  (nearest-rank P10/P90, as meas-02)

COHORTS = ("ember_hoarder", "warband", "umbral_snare")
TIERS = (1, 2, 3)


def run_group(task_id: str, cohort: str, tier: int, runs: int, seed: int, work: Path) -> dict:
    output = work / f"bot-t{tier}-{cohort}.json"
    log = work / f"bot-t{tier}-{cohort}.log"
    command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", task_id, "--timeout", "7200", "--stream", "--",
               "godot", "--headless", "--path", str(ROOT), "--script", "tools/encounter_measurement_bot.gd", "--",
               "--revision", "7", "--cohort", cohort, "--tier", str(tier), "--runs", str(runs), "--seed", str(seed), "--output", str(output)]
    started = time.monotonic()
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"{cohort} tier {tier} failed; see {log}")
    print(f"{cohort} tier {tier}: {time.monotonic() - started:.0f}s", flush=True)
    return {"cohort": cohort, "tier": tier, "path": output, "elapsed": round(time.monotonic() - started, 1)}


def summarize(records: list[dict]) -> dict:
    won = [r for r in records if r["won"]]
    summary = {"n": len(records), "win_rate": len(won) / len(records), "turns": distribution([r["turns"] for r in records]),
               "hp_lost": distribution([r["hp_lost"] for r in records]), "turn_caps": sum(bool(r["turn_cap_reached"]) for r in records),
               "objective": sorted({r["objective"] for r in records})}
    if records and "hoarder_result" in records[0]:
        caught = [r for r in records if r["hoarder_result"] == "caught"]
        summary["catch_rate"] = len(caught) / len(records)
        summary["escape_rate"] = sum(r["hoarder_result"] == "escaped" for r in records) / len(records)
        summary["caught_turn"] = distribution([r["hoarder_caught_turn"] for r in caught])
        summary["win_rate_after_escape"] = (sum(r["won"] for r in records if r["hoarder_result"] == "escaped") /
                                            max(1, sum(r["hoarder_result"] == "escaped" for r in records)))
    return summary


def cell(value: dict) -> str:
    if not value["n"]:
        return "—"
    return f'{value["median"]:g} ({value["p10"]}–{value["p90"]})'


def report(summary: dict) -> str:
    lines = ["# spx-09 measurement: Ember Hoarder beside the Warband and Umbral Snare", "",
             f'Revision 7, meas-02 bot (policy v2, `policy_sha256={summary["policy_sha256"]}`), {summary["runs"]} runs per cohort/tier, '
             f'first seed {summary["seed"]}, source HEAD `{summary["head"]}` plus the uncommitted int-09 integration (both specials enabled). Values are median '
             '(nearest-rank P10–P90), including losses and capped runs. HP lost is cumulative damage_received. Numbers only; tuning is the director\'s.', "",
             "| Tier | Cohort | Objective | N | Win rate | Turns | HP lost | Turn caps | Catch rate | Caught turn | Escapes (won after) |",
             "|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for group in summary["groups"]:
        s = group["summary"]
        hoarder = "catch_rate" in s
        lines.append(f'| {group["tier"]} | {group["cohort"]} | {"/".join(s["objective"])} | {s["n"]} | {s["win_rate"]:.1%} | {cell(s["turns"])} | {cell(s["hp_lost"])} | {s["turn_caps"]} | '
                     + (f'{s["catch_rate"]:.1%} | {cell(s["caught_turn"])} | {s["escape_rate"]:.1%} ({s["win_rate_after_escape"]:.1%}) |' if hoarder else "— | — | — |"))
    lines += ["", "The Hoarder's objective is recorded as the room's starting objective (kill_leader); after it slips away the same fight continues as Defeat All. "
              "Catch rate counts fights where the Hoarder died; caught turn is the hero turn of the catch (catches only). Escapes count fights where it slipped away; "
              "the bracket is the share of those still won as Defeat All.", "",
              "Reproduce: `python3 spec/peer_benchmark/encounter_redesign/measurements/spx-09/measure.py --task-id int-09 --workers 2` from the task worktree."]
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-id", default="int-09")
    parser.add_argument("--runs", type=int, default=150)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--work", type=Path, default=Path("/private/tmp/labyrinth_codex/int-09/hoarder-measurement"))
    parser.add_argument("--report-only", action="store_true")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    groups = [(cohort, tier) for tier in TIERS for cohort in COHORTS]
    if not args.report_only:
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            list(executor.map(lambda g: run_group(args.task_id, g[0], g[1], args.runs, args.seed, args.work), groups))
    summary = {"runs": args.runs, "seed": args.seed, "workers": args.workers, "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "policy_sha256": hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest(), "groups": []}
    for cohort, tier in groups:
        raw = (args.work / f"bot-t{tier}-{cohort}.json").read_bytes()
        records = json.loads(raw)["results"]
        assert len(records) == args.runs, (cohort, tier, len(records))
        target = HERE / f"bot-t{tier}-{cohort}.json.gz"
        target.write_bytes(gzip.compress(raw, mtime=0))
        summary["groups"].append({"cohort": cohort, "tier": tier, "file": target.name, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "summary": summarize(records)})
    (HERE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    (HERE / "report.md").write_text(report(summary))
    print(report(summary))


if __name__ == "__main__":
    main()
