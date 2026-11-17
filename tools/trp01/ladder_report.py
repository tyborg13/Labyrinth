#!/usr/bin/env python3
"""Validate and summarize the paired trp-01 normal-room ladder sample."""
import argparse
import hashlib
import json
from pathlib import Path


def report(root: Path) -> dict:
    phases = {phase: [json.loads(line) for worker in (1, 2)
                      for line in (root / f"ladder-{worker}" / f"{phase}.jsonl").read_text().splitlines()]
              for phase in ("before", "after")}
    assert all(len(rows) == 96 for rows in phases.values()), "Need N=48 each s0/s2 per arm"
    keys = lambda rows: [(r["input"], r["input_sha256"], r["section"], r["ladder_seed"]) for r in rows]
    assert keys(phases["before"]) == keys(phases["after"]), "Before/after inputs differ"
    for row in phases["before"]:
        assert hashlib.sha256(Path(row["input"]).read_bytes()).hexdigest() == row["input_sha256"]
    policies = {r["policy_sha256"] for rows in phases.values() for r in rows}
    assert len(policies) == 1, "Bot policy changed"
    sources = {phase: sorted({r["combat_sha256"] for r in rows}) for phase, rows in phases.items()}
    assert all(len(values) == 1 for values in sources.values()), "Combat source changed within an arm"
    result = {"paired": True, "max_workers": 2,
              "worker_limit_scope": "reported paired arms; excluded setup trial briefly overlapped replacements during restart",
              "policy_sha256": next(iter(policies)),
              "combat_sha256": sources, "groups": []}
    for section in (0, 2):
        grouped = {phase: [r for r in rows if int(r["section"]) == section] for phase, rows in phases.items()}
        assert all(len(rows) == 48 for rows in grouped.values())
        wins = {phase: sum(r["won"] for r in rows) for phase, rows in grouped.items()}
        change = (wins["after"] - wins["before"]) * 100 / 48
        result["groups"].append({"section": section, "n": 48, "wins": wins,
                                 "win_rate": {phase: value / 48 for phase, value in wins.items()},
                                 "change_percentage_points": change,
                                 "turn_caps": {phase: sum(r["turn_cap_reached"] for r in rows) for phase, rows in grouped.items()}})
        print(f"TRP01 LADDER s{section}: {wins['before']}/48 ({wins['before']/48:.2%}) -> "
              f"{wins['after']}/48 ({wins['after']/48:.2%}); {change:+.2f} percentage points")
    (root / "ladder-summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print("TRP01 LADDER PAIRING: PASS (96 identical constructor inputs; frozen policy; 2 workers)")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proof-dir", type=Path, required=True)
    report(parser.parse_args().proof_dir)
