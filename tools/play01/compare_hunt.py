#!/usr/bin/env python3
"""Compare the play-01 hunt's fake Steam stats against local analytics rows."""

import argparse
import collections
import json
from pathlib import Path

PREFIX = "play_v1_"


def read_records(directory):
    seen = set()
    for path in sorted(directory.glob("events-*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            key = row.get("idempotency_key") or row["event_id"]
            if key not in seen:
                seen.add(key)
                yield row


def expected_gameplay_stats(rows):
    counts = collections.Counter()
    bosses = set()
    tutorials = set()
    for row in rows:
        event = row["event_type"]
        payload = row["payload"]
        run_id = row["run_id"]
        if event == "run_started":
            counts["runs_started"] += 1
            counts["p_run_started"] = 1
            if counts["runs_started"] >= 2:
                counts["p_run2"] = 1
            if counts["runs_won"]:
                counts["p_run_after_win"] = 1
        elif event == "run_resumed":
            counts["runs_resumed"] += 1
        elif event == "combat_started":
            fight = payload["fight_number"]
            if fight:
                counts[f"fights_started_{min(fight, 7)}"] += 1
            if fight >= 3:
                counts["p_fight3"] = 1
            if fight >= 5:
                counts["p_fight5"] = 1
            if payload["room_type"] == "guardian":
                counts["p_guardian"] = 1
            elif payload["room_type"] == "boss":
                counts["p_boss"] = 1
                bosses.add(run_id)
        elif event == "combat_ended" and payload["outcome"] == "victory":
            counts["fights_won"] += 1
            counts["p_fight_won"] = 1
        elif event == "guided_tutorial_started":
            tutorials.add(run_id)
            counts["tutorial_started"] += 1
        elif event == "guided_tutorial_dismissed":
            if payload["phase_id"] != "complete" and payload["completed_step_count"] < 15:
                counts["tutorial_left_early"] += 1
            tutorials.discard(run_id)
        elif event == "guided_tutorial_completed" or (
            event == "guided_tutorial_step_completed" and payload["completed_step_count"] >= 15
        ):
            tutorials.discard(run_id)
        elif event == "run_ended":
            if run_id in tutorials:
                counts["tutorial_left_early"] += 1
                tutorials.remove(run_id)
            outcome = payload["outcome"]
            if outcome == "victory":
                counts["runs_won"] += 1
                counts["p_boss_won"] = 1
            elif outcome == "defeat":
                counts["runs_died"] += 1
                counts[f"died_{payload.get('defeat_room_type', 'other')}"] += 1
                if payload.get("defeat_fight_number"):
                    counts[f"died_fight_{min(payload['defeat_fight_number'], 7)}"] += 1
            elif outcome == "embrace":
                counts["runs_withdrew"] += 1
            elif outcome == "abandoned":
                counts["runs_abandoned"] += 1
    counts["runs_reached_boss"] = len(bosses)
    return {key: value for key, value in counts.items() if value}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    snapshot = json.loads((args.directory / "steam.json").read_text(encoding="utf-8"))
    rows = list(read_records(args.directory / "analytics"))
    expected = expected_gameplay_stats(rows)
    actual = {
        key.removeprefix(PREFIX): value for key, value in snapshot["stats"].items()
        if key.removeprefix(PREFIX).startswith((
            "runs_", "fights_", "died_", "tutorial_", "p_run_", "p_fight", "p_boss", "p_guardian", "p_run2",
        ))
    }
    for key in sorted(expected.keys() | actual.keys()):
        print(f"{PREFIX}{key}: JSONL {expected.get(key, 0)}, Steam {actual.get(key, 0)}")
    run_minutes = snapshot["stats"].get("play_v1_run_minutes", 0)
    clock_minutes = snapshot["run_clock_minute"]
    print(f"Run clock full minutes: {clock_minutes}, Steam {run_minutes}")
    passed = (
        expected == actual and expected.get("runs_started") == 1 and clock_minutes == run_minutes
        and any(row["payload"].get("build_kind") == "demo" for row in rows if row["event_type"] == "run_started")
        and not any(key.startswith("perf_") for key in snapshot["stats"])
    )
    print(f"PLAY01 HUNT COMPARISON: {'PASS' if passed else 'FAIL'} ({len(rows)} JSONL rows, {len(expected)} gameplay deltas, {snapshot['store_calls']} StoreStats calls)")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
