#!/usr/bin/env python3
"""Three matched Guardian ablations with the meas-02 revision-7 policy-v2 harness."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
from encounter_bot import compress_report, read_report, summarize
from encounter_sweep import ROOT, cell, distribution, run_engine

GUARDIANS = ("ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "craghide", "last_lamplighter")
VARIANTS = ("before", "pace_only", "after")
RUNS_PER_TIER = 30
WORKERS = 6
METRICS = ("beats_fired", "beat_damage_to_hero", "beat_damage_to_enemies", "helper_kills", "summons")
DEFAULT_OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bos-03"

def report(output: Path, *, tuning: dict | None = None, feedback_round: int = 1) -> None:
    rows = []
    matched = {}
    for guardian in GUARDIANS:
        for variant in VARIANTS:
            raw = read_report(output / f"{guardian}-{variant}.json.gz")
            records = raw["results"]
            keys = [(r["seed"], r["tier"], r["section_index"], r["coord"], r["travel_dir"]) for r in records]
            if guardian in matched:
                assert keys == matched[guardian], f"Unmatched ablation: {guardian}"
            matched[guardian] = keys
            row = {"guardian":guardian,"variant":variant,**summarize(records),
                   "tiers": {str(tier):sum(r["tier"] == tier for r in records) for tier in (1,2,3)},
                   "metrics": {key:{"total":sum(r["metrics"][key] for r in records),
                                    **distribution([r["metrics"][key] for r in records])} for key in METRICS}}
            row["outside_band"] = not .35 <= row["win_rate"] <= .65
            rows.append(row)
    metadata = {"source_head": subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
                "policy_version":2,"revision":7,"policy_sha256":hashlib.sha256((ROOT/"tools/encounter_bot.gd").read_bytes()).hexdigest(),
                "driver_sha256":hashlib.sha256((ROOT/"tools/guardian_rules_measurement.gd").read_bytes()).hexdigest(),
                "adapter_sha256":hashlib.sha256((ROOT/"tools/guardian_rules_measurement_engine.gd").read_bytes()).hexdigest(),"groups":rows}
    if tuning is not None: metadata["chosen_rungs"] = tuning
    (output/"summary.json").write_text(json.dumps(metadata,indent=2)+"\n")
    lines = ["# bos-03 Guardian ablations", "",f'Parent `{metadata["source_head"]}` plus the uncommitted bos-03 implementation. Revision 7; frozen policy v2 `{metadata["policy_sha256"]}`. '
             'Each variant uses the first 30 natural rooms per Guardian per tier, starting at seed 1 (90 per Guardian, 1,620 total). '
             'Sample keys are asserted identical across variants. Starting HP 24, tier decks, search limits and all other meas-02 defaults are unchanged.', "",
             'Before restores the captured integration definitions and automatic replacements. Pace only changes Cantor 11, Roc 9 and the Bell Tender/Fledgling Guardian overrides to 12. '
             'After uses production bos-03. The before adapter preserves sum-01’s automatic-replacement exclusion. No tuning was performed.', "",
             'Turns and cumulative HP lost include losses and capped runs. Values are median (nearest-rank P10–P90). '
             'Beat/helper/summon columns are totals over all runs. Helper kills count actual actor_death events, excluding departed/outcome-cleared helpers; summons count arrivals, excluding initial helpers. '
             'Beat damage is actual HP lost by team from battlefield_rule_fired events, including collisions and ground contact. '
             'Branch-local event cursors exclude speculative policy transitions.', "",
             '| Guardian | Variant | N | Wins | Turns (P10–P90) | HP lost (P10–P90) | Beats | Beat → hero | Beat → enemies | Helper kills | Summons | 35–65% band |',
             '|---|---|---:|---:|---|---|---:|---:|---:|---:|---:|---|']
    for row in rows:
        lines.append(f'| {row["guardian"]} | {row["variant"]} | {row["n"]} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | '+
                     ' | '.join(str(row["metrics"][key]["total"]) for key in METRICS)+f' | {"OUTSIDE" if row["outside_band"] else "within"} |')
    lines += ["",'Raw gzipped records retain each natural tier, seed, entrance and coordinate. `summary.json` also includes per-run metric distributions and tier counts.',"",
              'Reproduce: `python3 tools/guardian_rules_measurement.py`; rebuild: `python3 tools/guardian_rules_measurement.py --report-only`.',""]
    if tuning is not None:
        lines[0] = f"# bos-03 feedback {feedback_round} — updated three-variant table"
        lines = [line.replace("No tuning was performed.", "After uses the director-selected cumulative rungs: " + ", ".join(f"{guardian} rung {rung}" for guardian, rung in tuning.items()) + ". Before/pace-only and the three unaffected after datasets are retained from accepted round 0; selected after samples come from the measured ladders.") for line in lines]
        lines = [line.replace('Reproduce: `python3 tools/guardian_rules_measurement.py`; rebuild: `python3 tools/guardian_rules_measurement.py --report-only`.', 'Reproduce: `python3 tools/guardian_tuning.py`; rebuild: `python3 tools/guardian_tuning.py --report-only`.') for line in lines]
        if feedback_round==2:
            lines = [line.replace("retained from accepted round 0", "retained from accepted round 1").replace("three unaffected after datasets", "four unaffected after datasets").replace("guardian_tuning.py`", "guardian_tuning.py --round 2`").replace("guardian_tuning.py --report-only", "guardian_tuning.py --round 2 --report-only") for line in lines]
        if feedback_round==3:
            lines = [line.replace("retained from accepted round 0", "retained from accepted round 2").replace("three unaffected after datasets", "five unaffected after datasets").replace("guardian_tuning.py`", "guardian_tuning.py --round 3`").replace("guardian_tuning.py --report-only", "guardian_tuning.py --round 3 --report-only") for line in lines]
            lines += ["", "Cantor after includes the Lay the Choir tile-budget repair; historical before/pace-only rows retain their original connector behavior.", ""]
        lines += ["", "Ordered rung results: [ladders.md](ladders.md).", ""]
    (output/"report.md").write_text("\n".join(lines))
    print(f"GUARDIAN ABLATIONS: PASS ({sum(r['n'] for r in rows)} runs; 18 groups; matched samples)",flush=True)

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir",type=Path,default=DEFAULT_OUTPUT)
    parser.add_argument("--workers",type=int,default=WORKERS)
    parser.add_argument("--runs-per-tier",type=int,default=RUNS_PER_TIER)
    parser.add_argument("--report-only",action="store_true")
    args=parser.parse_args()
    output=args.output_dir.resolve();output.mkdir(parents=True,exist_ok=True)
    logs=ROOT/"output/bos-03/measurement";logs.mkdir(parents=True,exist_ok=True)
    def measure(pair: tuple[str,str]) -> None:
        guardian,variant=pair;stem=f"{guardian}-{variant}"
        dest=output/f"{stem}.json.gz"
        raw=logs/f"{stem}.json"
        run_engine("tools/guardian_rules_measurement.gd",["--guardian",guardian,"--variant",variant,"--runs-per-tier",str(args.runs_per_tier),"--output",str(raw)],logs/f"{stem}.log",task_id="bos-03")
        compress_report(raw,dest)
    if not args.report_only:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            list(pool.map(measure,[(g,v) for g in GUARDIANS for v in VARIANTS]))
    report(output)
if __name__ == "__main__": main()
