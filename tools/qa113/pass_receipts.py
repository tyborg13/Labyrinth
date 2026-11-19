#!/usr/bin/env python3
"""Summarize published Pass comparisons alongside QA-110 decision coverage."""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "qa110"))
from collect import analyze, read_rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lanes", type=Path, nargs="+")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    receipt = analyze(args.lanes, [])
    counts = Counter()
    mismatches = []
    for lane in args.lanes:
        for path in sorted(lane.glob("seed-*/trace.jsonl")):
            for row in read_rows(path):
                if row["event"] == "decision" and row["data"]["kind"] == "pass":
                    counts["inputs"] += 1
                if row["event"] != "qa113_pass":
                    continue
                data = row["data"]
                counts["sampled"] += 1
                counts["fully_disclosed"] += not data["unknown"] and not data["missing_forecast"]
                counts["uncertain"] += bool(data["unknown"])
                counts["missing_forecast"] += data["missing_forecast"]
                counts["totals_mismatch"] += bool(data["fields"])
                # Manual Pass may return to a Frozen hero; the driver does
                # not force another input just to match the projected span.
                live_unavailable = data["live_hp"] is None and bool(data["resolved_outcome"])
                live_matches = (data["live_hp"] == data["resolved_hp"] or
                                (data["skipped_turns"] > 0 and data["live_hp"] == data["first_phase_hp"]))
                counts["live_unavailable_terminal"] += live_unavailable
                live_mismatch = not live_matches and not live_unavailable
                counts["live_health_mismatch"] += live_mismatch
                if data["fields"] or data["missing_forecast"] or live_mismatch:
                    mismatches.append(data)
    receipt["pass"] = {"counts": counts, "mismatches": mismatches}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("QA113 WHOLE RUNS: "
          f"complete={sum(run.get('whole_run', False) for run in receipt['runs'])}/{len(receipt['runs'])} "
          f"decisions={sum(run['decisions'] for run in receipt['runs'])} "
          f"settled={sum(run['samples'] for run in receipt['runs'])}")
    print("QA113 PASS: " + " ".join(f"{key}={value}" for key, value in counts.items()))


if __name__ == "__main__":
    main()
