#!/usr/bin/env python3
"""Matched bos-02 observations through the unchanged meas-02 sampler/policy."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

from encounter_bot import BOSS_IDS, compress_report, read_report, summarize
from encounter_sweep import cell, run_engine

DEFAULT_WORKERS = 6
DEFAULT_RUNS = 50


def measure(output: Path, runs: int, workers: int, bosses=BOSS_IDS) -> None:
    output.mkdir(parents=True, exist_ok=True)
    def one(boss: str) -> None:
        destination = output / f"{boss}.json"
        run_engine("tools/dragon_rule_measurement.gd", ["--revision", "7", "--tier", "3", "--cohort", "boss", "--boss-id", boss, "--runs", str(runs), "--seed", "1", "--output", str(destination)], output / f"{boss}.log", task_id="bos-02")
        compress_report(destination, output / f"{boss}.json.gz")
    with ThreadPoolExecutor(max_workers=workers) as pool:
        list(pool.map(one, bosses))


SAMPLE_FIELDS = ("seed", "revision", "tier", "deck_tier", "coord", "travel_dir",
                 "room_type", "room_tier", "cohort", "boss_id", "guardian_id",
                 "special_type", "special_variant", "objective", "biome",
                 "section_index", "policy_version")


def validate_matched(reference: dict, candidate: dict) -> None:
    """Reject changed samples, decks or policy when comparing a tuning rung."""
    for key in ("cohort", "decks", "defaults", "revision"):
        if reference[key] != candidate[key]:
            raise ValueError(f"Unmatched measurement setup: {key}")
    signatures = []
    for report in (reference, candidate):
        rows = report["results"]
        if len(rows) != DEFAULT_RUNS:
            raise ValueError("A director tuning rung requires 50 runs")
        values = [json.dumps({key: row[key] for key in SAMPLE_FIELDS}, sort_keys=True)
                  for row in rows]
        if len(set(values)) != len(values):
            raise ValueError("Duplicate tuning samples")
        signatures.append(sorted(values))
    if signatures[0] != signatures[1]:
        raise ValueError("Unmatched tuning samples")


def summarize_report(raw: dict) -> dict:
    rows = raw["results"]
    totals = {key: sum(row["dragon_metrics"][key] for row in rows)
              for key in rows[0]["dragon_metrics"]}
    return {**summarize(rows), **totals}


def ladder_report(manifest_path: Path, destination: Path) -> None:
    manifest = json.loads(manifest_path.read_text())
    lines = ["# bos-02 feedback 1 — director tuning ladders", "",
             "50 matched revision-7 samples per rung; tier-3 deck; frozen policy v2. "
             "Turns and HP lost are median (P10–P90). Beat, damage, switch and lieutenant columns are totals across 50 fights.", ""]
    header = "| Rung | Cumulative change | Win rate | Turns | HP lost | Beats | Beat → hero | Beat → enemies | Half switches | Lieutenant kills |"
    divider = "|---|---|---:|---|---|---:|---:|---:|---:|---:|"
    summaries = {}
    for boss, ladder in manifest["dragons"].items():
        reference = read_report(manifest_path.parent / ladder["before"])
        low, high = ladder["band"]
        summaries[boss] = []
        if boss != "iskaldra": lines.extend(["## " + boss, "", header, divider])
        for index, rung in enumerate(ladder["rungs"]):
            if rung["rung"] != index: raise ValueError("Non-consecutive ladder: " + boss)
            raw = read_report(manifest_path.parent / rung["report"])
            validate_matched(reference, raw)
            summary = summarize_report(raw)
            inside = low <= summary["win_rate"] <= high
            if index > 0 and index < len(ladder["rungs"]) - 1 and inside:
                raise ValueError("Ladder continued past its first in-band rung: " + boss)
            summaries[boss].append({**summary, "rung":index, "inside_band":inside})
            if boss != "iskaldra":
                lines.append(f'| {index} | {rung["change"]} | {summary["win_rate"]:.0%} | {cell(summary["turns"])} | {cell(summary["hp_lost"])} | {summary["beats_fired"]} | {summary["damage_to_player"]} | {summary["damage_to_enemies"]} | {summary["half_health_switches"]} | {summary["lieutenant_kills"]} |')
        final = summaries[boss][-1]
        if ladder["selected_rung"] != final["rung"]: raise ValueError("Selected rung is not the final attempt: " + boss)
        if boss != "iskaldra" and not final["inside_band"] and final["rung"] != ladder["maximum_rung"]:
            raise ValueError("Out-of-band ladder stopped early: " + boss)
        if boss != "iskaldra": lines.extend(["", f'Retained rung {final["rung"]}: ' + ("inside band." if final["inside_band"] else "OUTSIDE band after the last authorized rung."), ""])
    lines.extend(["## Final before → after", "", "| Dragon | Stage | Win rate | Turns | HP lost | Beats | Beat → hero | Beat → enemies | Half switches | Lieutenant kills | Band |", "|---|---|---:|---|---|---:|---:|---:|---:|---:|---|"])
    for boss, stages in summaries.items():
        for label, summary in [("before", stages[0]), ("after", stages[-1])]:
            lines.append(f'| {boss} | {label} | {summary["win_rate"]:.0%} | {cell(summary["turns"])} | {cell(summary["hp_lost"])} | {summary["beats_fired"]} | {summary["damage_to_player"]} | {summary["damage_to_enemies"]} | {summary["half_health_switches"]} | {summary["lieutenant_kills"]} | ' + ("within" if summary["inside_band"] else "OUTSIDE") + " |")
    destination.write_text("\n".join(lines) + "\n")
    destination.with_suffix(".json").write_text(json.dumps(summaries, indent=2) + "\n")


def report(before: Path, after: Path, destination: Path) -> None:
    lines = ["# bos-02 dragon measurements", "", "Revision 7; committed policy v2; tier-3 deck, 24 HP, seeds 1–50 per dragon. All outcomes included. Turns and HP lost are median (P10–P90); beat, damage, switch and lieutenant columns are totals across 50 fights. No tuning applied.", "", "| Dragon | Stage | N | Win rate | Turns | HP lost | Beats | Beat → hero | Beat → enemies | Half switches | Lieutenant kills | Band |", "|---|---|---:|---:|---|---|---:|---:|---:|---:|---:|---|"]
    summaries = {}
    for boss in BOSS_IDS:
        summaries[boss] = {}
        for stage, folder in [("before", before), ("after", after)]:
            raw = read_report(folder / f"{boss}.json.gz")
            rows = raw["results"]
            summary = summarize(rows)
            totals = {key: sum(row["dragon_metrics"][key] for row in rows) for key in rows[0]["dragon_metrics"]}
            low, high = (.15, .40) if boss == "noctyrax" else (.30, .60)
            band = "within" if low <= summary["win_rate"] <= high else "OUTSIDE"
            summaries[boss][stage] = {**summary, **totals, "band": band, "policy_sha256": hashlib.sha256((Path(__file__).parent / "encounter_bot.gd").read_bytes()).hexdigest()}
            lines.append(f'| {boss} | {stage} | {summary["n"]} | {summary["win_rate"]:.0%} | {cell(summary["turns"])} | {cell(summary["hp_lost"])} | {totals["beats_fired"]} | {totals["damage_to_player"]} | {totals["damage_to_enemies"]} | {totals["half_health_switches"]} | {totals["lieutenant_kills"]} | {band} |')
    destination.write_text("\n".join(lines) + "\n")
    destination.with_suffix(".json").write_text(json.dumps(summaries, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--runs", type=int, default=DEFAULT_RUNS)
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    parser.add_argument("--boss-id", action="append", choices=BOSS_IDS)
    parser.add_argument("--before", type=Path)
    parser.add_argument("--after", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--ladder-manifest", type=Path)
    args = parser.parse_args()
    if args.output_dir: measure(args.output_dir.resolve(), args.runs, args.workers, args.boss_id or BOSS_IDS)
    if args.report:
        if args.ladder_manifest: ladder_report(args.ladder_manifest, args.report)
        else: report(args.before, args.after, args.report)
