#!/usr/bin/env python3
"""Count paired QA-110 settled floor changes, with per-decision receipts."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

SEEDS = set(range(101001, 101009)) | {101013, 101014}
TERMINAL = {"embrace", "victory", "defeat"}


def source_matches(path):
    with path.open() as trace:
        row = json.loads(trace.readline())
    if row["event"] != "red04_sources":
        return False
    return all(hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest
               for name, digest in row["data"].items() if name.startswith("scripts/"))


def count_run(path):
    counts = Counter()
    changes = Counter()
    receipts = []
    terminal = None
    for line in path.open():
        event = json.loads(line)
        data = event["data"]
        if event["event"] == "finish":
            terminal = data.get("outcome")
        if event["event"] == "qa110_unsettled":
            counts["unsettled"] += 1
        if event["event"] != "qa110_sample":
            continue
        counts["settled"] += 1
        row = data.get("red04")
        if not row:
            continue
        counts["scored_red"] += 1
        counts["later_rows"] += row["later_rows"]
        counts["first_stamp_mismatches"] += row["shifted_or_omitted"]
        counts["before_first_stamp_mismatches"] += row["legacy_shifted"] or row["legacy_omitted"]
        if row["at_rest"]:
            counts["at_rest"] += 1
            counts["at_rest_mismatches"] += row["shifted_or_omitted"]
            counts["before_at_rest_mismatches"] += row["legacy_shifted"] or row["legacy_omitted"]
        if row["selected"]:
            counts["selected"] += 1
            counts["selected_mismatches"] += row["shifted_or_omitted"]
        counts["pass_issues"] += len(data["checks"].get("pass", []))
        if row["board_changed"]:
            counts["changed"] += 1
            counts["changed_at_rest"] += row["at_rest"]
            changes.update(row["kinds"] or ["unattributed"])
            receipts.append({"context": data["context"], **row})
    return terminal, counts, changes, receipts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lanes", nargs="+", type=Path, help="Campaign output directories")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    combined = Counter()
    kinds = Counter()
    receipts = []
    runs = {}
    for directory in args.lanes:
        manifest = json.loads((directory / "campaign.json").read_text())
        for run in manifest["runs"]:
            seed = run["seed"]
            path = directory / f"seed-{seed}/trace.jsonl"
            if not source_matches(path):
                continue
            if seed in runs or run["returncode"]:
                raise SystemExit(f"Duplicate or failed seed {seed} in {directory}")
            terminal, counts, changes, delta = count_run(path)
            if terminal not in TERMINAL:
                raise SystemExit(f"Missing natural terminal event in {path}")
            combined.update(counts)
            kinds.update(changes)
            receipts.extend(delta)
            runs[seed] = {
                "terminal": terminal, "counts": counts, "changes": changes, "trace": str(path)
            }
    if runs.keys() != SEEDS:
        raise SystemExit(f"Expected QA-110's ten seeds, got {sorted(runs)}")
    result = {"runs": runs, "totals": combined, "change_kinds": kinds, "receipts": receipts}
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(
        f"RED04 CAMPAIGN: runs={len(runs)}/10 settled={combined['settled']} "
        f"scored_red={combined['scored_red']} changed={combined['changed']} "
        f"first_stamp_mismatches={combined['before_first_stamp_mismatches']}->{combined['first_stamp_mismatches']} "
        f"at_rest={combined['before_at_rest_mismatches']}->{combined['at_rest_mismatches']}"
    )
    print(f"RED04 CHANGE KINDS: {dict(kinds)}")
    print(f"RED04 PASS ISSUES: {combined['pass_issues']}")
    print(f"RED04 LATER-ATTACK ROWS: {combined['later_rows']}")
    return int(bool(combined["first_stamp_mismatches"] or combined["later_rows"] or kinds["unattributed"]))


if __name__ == "__main__":
    raise SystemExit(main())
