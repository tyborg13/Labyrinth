#!/usr/bin/env python3
"""Run the director's ordered, cumulative bos-03 tuning ladders; never interpolate."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from encounter_bot import compress_report, read_report, summarize
from encounter_sweep import ROOT, cell, distribution, run_engine
import guardian_rules_measurement as measurement

PLAN = ROOT / "spec/peer_benchmark/encounter_redesign/bos_03_feedback_1_ladders.json"
BASELINE = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bos-03"
OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bos-03-feedback-1"
LOGS = ROOT / "output/bos-03-feedback-1/measurement"
WORKERS = 6
RUNS_PER_TIER = 30
BAND = (.35, .65)
EXTENSION_PLAN = ROOT / "spec/peer_benchmark/encounter_redesign/bos_03_feedback_2_ladders.json"
EXTENSION_OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bos-03-feedback-2"
FINAL_PLAN = ROOT / "spec/peer_benchmark/encounter_redesign/bos_03_feedback_3_ladders.json"
FINAL_OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bos-03-feedback-3"


def sample_key(row: dict) -> str:
    return json.dumps([row["seed"], row["tier"], row["section_index"], row["coord"], row["travel_dir"]], sort_keys=True)


def merge_tiers(reports: list[dict], reference: dict) -> dict:
    records = [row for report in reports for row in report["results"]]
    keyed = {sample_key(row): row for row in records}
    order = [sample_key(row) for row in reference["results"]]
    if len(keyed) != len(records) or set(keyed) != set(order):
        raise ValueError("Tuning samples differ from round-0 matched samples")
    if any(report["defaults"] != reference["defaults"] or report["decks"] != reference["decks"] for report in reports):
        raise ValueError("Tuning requires unchanged policy defaults and tier decks")
    result = dict(reports[0])
    result["results"] = [keyed[key] for key in order]
    return result


def summarize_rung(guardian: str, rung: int, label: str, records: list[dict]) -> dict:
    row = {"guardian": guardian, "rung": rung, "label": label, **summarize(records),
           "metrics": {key: {"total": sum(r["metrics"][key] for r in records),
                              **distribution([r["metrics"][key] for r in records])} for key in measurement.METRICS}}
    row["inside_band"] = BAND[0] <= row["win_rate"] <= BAND[1]
    return row


def first_accepted(rows: list[dict]) -> int:
    if not rows:
        raise ValueError("A ladder requires at least one measured rung")
    return next((row["rung"] for row in rows if row["inside_band"]), rows[-1]["rung"])


def write_ladder_report(output: Path, ladders: dict, feedback_round: int = 1) -> None:
    lines = [f"# bos-03 feedback {feedback_round} — director tuning ladders", "",
             "Cumulative rungs in the director's supplied order. Each measured rung has the same 90 revision-7 rooms as round 0, 30 per natural tier. Policy v2, defaults and decks are unchanged. Tier processes are merged back into round-0 sample order. The first inclusive 35–65% win rate stops a ladder; otherwise its last rung is retained.", "",
             "Turns and cumulative HP lost include losses and capped runs; values are median (nearest-rank P10–P90). Beat, damage, helper-kill and summon columns are totals over 90 fights, using the same branch-local committed-event counters as round 0.", ""]
    prior = json.loads((OUTPUT/"ladders.json").read_text())["ladders"] if feedback_round>=2 else {}
    if feedback_round==3:
        for guardian, previous in json.loads((EXTENSION_OUTPUT/"ladders.json").read_text())["ladders"].items():
            prior[guardian] = {**previous, "rows": prior[guardian]["rows"] + previous["rows"][1:]}
        lines += ["Rounds 0–2 are retained evidence. Rimejaw rung 2 and Lamplighter rung 6 are decided. Only Cantor is remeasured; its six-tile Choir budget repair is active throughout rungs 9–12. Historical rows used the prior short-path connector.", ""]
    if feedback_round==2:
        lines += ["Round-0/1 rows are retained evidence. This round begins after Cantor rung 4 and Lamplighter rung 5. Rimejaw is fixed at its accepted rung 2 and is not remeasured.", ""]
    for guardian, ladder in {**prior, **ladders}.items():
        lines += [f"## {guardian}", "",
                  "| Rung | Cumulative addition | Wins | Turns (P10–P90) | HP lost (P10–P90) | Beats | Beat → hero | Beat → enemies | Helper kills | Summons | Band |",
                  "|---:|---|---:|---|---|---:|---:|---:|---:|---:|---|"]
        displayed_rows = prior[guardian]["rows"]+ladder["rows"][1:] if feedback_round>=2 and guardian in ladders else ladder["rows"]
        for row in displayed_rows:
            lines.append(f'| {row["rung"]} | {row["label"]} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | ' +
                         " | ".join(str(row["metrics"][key]["total"]) for key in measurement.METRICS) +
                         f' | {"within" if row["inside_band"] else "OUTSIDE"} |')
        lines += ["", f'Retained rung **{ladder["chosen_rung"]}**. ' +
                  ("First rung inside the band." if ladder["inside_band"] else "No rung reached the band; retained the last rung for the director."), ""]
    lines += ["## Heuristic scope", "",
              "The card heuristic scores intrinsic player cards against a blank draw; it exposes no enemy-intent scoring API. No synthetic card-equivalent scores were assigned to enemy intents. Its Guardian context/specification is updated with the selected enemy values; intrinsic card coefficients are unchanged.", ""]
    (output / "ladders.md").write_text("\n".join(lines))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--round", type=int, choices=(1, 2, 3), default=1)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--report-only", action="store_true")
    args = parser.parse_args()
    feedback_round = args.round
    baseline = {1: BASELINE, 2: OUTPUT, 3: EXTENSION_OUTPUT}[feedback_round]
    plan_path = {1: PLAN, 2: EXTENSION_PLAN, 3: FINAL_PLAN}[feedback_round]
    output = (args.output_dir or {1: OUTPUT, 2: EXTENSION_OUTPUT, 3: FINAL_OUTPUT}[feedback_round]).resolve()
    logs = ROOT / f"output/bos-03-feedback-{feedback_round}/measurement"
    output.mkdir(parents=True, exist_ok=True)
    logs.mkdir(parents=True, exist_ok=True)
    plan = json.loads(plan_path.read_text())
    state_path = output / "ladders.json"
    if args.report_only:
        ladders = json.loads(state_path.read_text())["ladders"]
        write_ladder_report(output, ladders, feedback_round)
        chosen = {g: row["chosen_rung"] for g, row in ladders.items()}
        if feedback_round>=2: chosen["rimejaw"] = 2
        if feedback_round==3: chosen["last_lamplighter"] = 6
        measurement.report(output, tuning=chosen, feedback_round=feedback_round)
        return
    completed = {}
    # Controllers never occupy measurement slots: independent ordered
    # ladders share the meas-02 six-process pool, partitioned by natural tier.
    with ThreadPoolExecutor(max_workers=WORKERS) as measurements:
        def measure_tier(guardian: str, rung: int, tier: int) -> dict:
            stem = f"{guardian}-r{rung}-t{tier}"
            raw = logs / f"{stem}.json"
            run_engine("tools/guardian_rules_measurement.gd", ["--guardian", guardian, "--variant", "after",
                       "--tuning-rung", str(rung), "--tuning-round", str(feedback_round), "--tier", str(tier), "--runs-per-tier", str(RUNS_PER_TIER),
                       "--output", str(raw)], logs / f"{stem}.log", task_id="bos-03")
            return read_report(raw)

        def ladder(guardian: str) -> tuple[str, dict]:
            reference = read_report(baseline / f"{guardian}-after.json.gz")
            start = plan[guardian]["start_rung"] if feedback_round>=2 else 0
            changes = plan[guardian]["rungs"] if feedback_round>=2 else plan[guardian]
            rows = [summarize_rung(guardian, start, f"Accepted round {feedback_round-1}", reference["results"])]
            for rung, change in enumerate(changes, start+1):
                futures = [measurements.submit(measure_tier, guardian, rung, tier) for tier in (1, 2, 3)]
                raw = merge_tiers([future.result() for future in futures], reference)
                path = logs / f"{guardian}-r{rung}.json"
                path.write_text(json.dumps(raw, indent=2) + "\n")
                compress_report(path, output / f"{guardian}-r{rung}.json.gz")
                row = summarize_rung(guardian, rung, change["label"], raw["results"])
                rows.append(row)
                print(f'GUARDIAN TUNING RUNG: {guardian} {rung}; N={row["n"]}; wins={row["win_rate"]:.1%}; {"within" if row["inside_band"] else "outside"}', flush=True)
                if row["inside_band"]:
                    break
            chosen = first_accepted(rows[1:])
            return guardian, {"rows": rows, "chosen_rung": chosen, "inside_band": rows[-1]["inside_band"]}

        with ThreadPoolExecutor(max_workers=len(plan)) as controllers:
            for future in [controllers.submit(ladder, guardian) for guardian in plan]:
                guardian, result = future.result()
                completed[guardian] = result
                state_path.write_text(json.dumps({"plan_sha256": hashlib.sha256(plan_path.read_bytes()).hexdigest(),
                                                 "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                                                 "ladders": completed}, indent=2) + "\n")
                write_ladder_report(output, completed, feedback_round)
    # Preserve accepted evidence; only newly selected after rows change.
    for guardian in measurement.GUARDIANS:
        for variant in measurement.VARIANTS:
            source = (output / f'{guardian}-r{completed[guardian]["chosen_rung"]}.json.gz'
                      if variant == "after" and guardian in completed else baseline / f"{guardian}-{variant}.json.gz")
            shutil.copyfile(source, output / f"{guardian}-{variant}.json.gz")
    chosen = {g: row["chosen_rung"] for g, row in completed.items()}
    if feedback_round>=2: chosen["rimejaw"] = 2
    if feedback_round==3: chosen["last_lamplighter"] = 6
    measurement.report(output, tuning=chosen, feedback_round=feedback_round)
    print(f"GUARDIAN TUNING LADDERS: PASS ({len(completed)} ordered ladders; matched samples)", flush=True)


if __name__ == "__main__":
    main()
