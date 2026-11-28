#!/usr/bin/env python3
"""Replay and compare the qa-143 enemy-round save boundaries."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
FIXED_FPS = 120
TIMEOUT_SECONDS = 240
REPLAY_WORKERS = 2
PRIMARY = (141010, 30, False)
STATUS = (141002, 236, True)
PHASE_EVENTS = {"enemy_action_resolved", "enemy_status_tick", "player_turn_started"}
SURFACE_EVENTS = {"surface_event", "battlefield_rule_fired", "battlefield_rule_switched", "snare_pressure"}
IDENTITY_FIELDS = ("run_id", "combat_id", "install_id", "session_id")
ACTION = "enemy_action_resolved"


def read_jsonl(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def run_lane(output, fixture, stage, reuse_completed):
    seed, decision, demo = fixture
    directory = output / f"seed-{seed}-d{decision}-{stage}"
    if reuse_completed and (directory / "summary.json").is_file():
        return read_lane(output, fixture, stage)
    directory.mkdir(parents=True)
    env = {
        "QA143_DECISION": str(decision), "QA143_STAGE": stage,
        "LABYRINTH_CEL_LOOK": "off", "LABYRINTH_DEMO": str(int(demo)),
    }
    command = [
        sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-143",
        "--timeout", str(TIMEOUT_SECONDS), "--stream", "--", "godot",
        "--headless", "--fixed-fps", str(FIXED_FPS), "--path", ".",
        "--script", "tools/qa143/replay.gd", "--", "--seed", str(seed),
        "--demo", str(demo).lower(), "--no-embrace", "true", "--output-dir", str(directory),
    ]
    (directory / "command.json").write_text(json.dumps({"argv": command, "env": env, "cwd": str(ROOT)}, indent=2))
    log = directory / "godot.log"
    with log.open("w") as stream:
        result = subprocess.run(command, env={**os.environ, **env}, cwd=ROOT,
                                stdout=stream, stderr=subprocess.STDOUT, check=False)
    if result.returncode:
        raise RuntimeError(f"{directory.name} exited {result.returncode}. See {log}")
    return read_lane(output, fixture, stage)


def read_lane(output, fixture, stage):
    seed, decision, _ = fixture
    directory = output / f"seed-{seed}-d{decision}-{stage}"
    trace = read_jsonl(directory / "trace.jsonl")
    [receipt] = [row["data"] for row in trace if row["event"] == "qa143_result"]
    saves = [row["data"] for row in trace if row["event"] == "qa143_save"]
    events = [row for path in sorted((directory / "analytics").glob("*.jsonl"))
              for row in read_jsonl(path)]
    assert len(events) == receipt["event_count"], directory

    def round_rows(rows):
        return [row for row in rows if row["combat_id"] == receipt["combat_id"]
                and (row["event_type"] in PHASE_EVENTS and row["turn"] == receipt["state"]["turn"]
                     or row["event_type"] in SURFACE_EVENTS and row["surface_revision"] > receipt["surface_start"])]

    prefix = []
    if stage == "none":
        assert not saves, saves
    else:
        [saved] = saves
        assert saved["stage"] == stage and saved["pending"] == (stage != "written"), saved
        assert saved["state"]["turn"] == receipt["state"]["turn"] - int(stage != "written"), saved
        prefix = round_rows(events[:saved["event_count"]])
    return receipt["state"], events, round_rows(events), prefix


def comparable(rows, *, full_stream=False):
    # Preserve the relationships between generated IDs, including their use
    # in idempotency keys and payloads. Only the full stream shares sequencing.
    ids = {}
    for field in IDENTITY_FIELDS:
        seen = list(dict.fromkeys(row[field] for row in rows if row[field]))
        ids.update({value: f"<{field}:{index}>" for index, value in enumerate(seen)})
    masked = {"event_id", "timestamp_utc"}
    if not full_stream:
        masked |= {"sequence", "session_id"}
    comparable_rows = []
    for row in rows:
        encoded = json.dumps({field: value for field, value in row.items() if field not in masked}, sort_keys=True)
        for value in sorted(ids, key=len, reverse=True):
            encoded = encoded.replace(value, ids[value])
        comparable_rows.append(json.loads(encoded))
    return comparable_rows


def phase_rows(rows):
    return [row for row in rows if row["event_type"] in PHASE_EVENTS]


def surface_rows(rows):
    # The existing resume saves can emit surface receipts at intermediate
    # checkpoints. Compare their causal payloads and order.
    return [(row["event_type"], row["surface_revision"], row["payload"])
            for row in rows if row["event_type"] in SURFACE_EVENTS]


def duplicate_count(rows):
    ids = [row["event_id"] for row in rows]
    keys = [row["idempotency_key"] for row in rows if row["idempotency_key"]]
    return len(ids) - len(set(ids)) + len(keys) - len(set(keys))


def compare(output, fixture, stages, release_output, reuse_completed):
    seed, decision, _ = fixture
    state, live, uninterrupted, _ = run_lane(output, fixture, "none", reuse_completed)
    counts = Counter(row["event_type"] for row in uninterrupted)
    if fixture == PRIMARY:
        assert counts[ACTION] == 7 and state["player"] == ["(4, 5)", 9992], (counts, state)
        assert state["turn"] == 3 and state["room"] == "(1, -1)", state
        assert any(row["event_type"] == ACTION and row["payload"]["intent_id"] == "skitter_strike"
                   and any(loss["hp_loss"] == 7 for loss in row["payload"]["target_losses"])
                   for row in uninterrupted)
    else:
        assert counts[ACTION] > 0 and counts["enemy_status_tick"] > 0 and counts["player_turn_started"] > 0, counts

    if release_output is not None:
        prior_state, prior_live, _, _ = read_lane(release_output, fixture, "none")
        assert state == prior_state
        assert comparable(live, full_stream=True) == comparable(prior_live, full_stream=True), (seed, decision)
        print(f"QA143 LIVE seed={seed} d={decision} rows={len(live)} PASS", flush=True)

    for stage in stages:
        resumed_state, _, resumed, before_continue = run_lane(output, fixture, stage, reuse_completed)
        n_actions = sum(row["event_type"] == ACTION for row in resumed)
        dupes = duplicate_count(resumed)
        expected_phase = comparable(phase_rows(uninterrupted))
        actual_phase = comparable(phase_rows(resumed))
        if stage == "written":
            # The rows are already on disk at Save & Quit. Continue must
            # append none of the selected round's phase or surface events.
            rows_ok = resumed == before_continue and actual_phase == expected_phase
        elif release_output is None:
            rows_ok = not phase_rows(before_continue) and not actual_phase
        else:
            rows_ok = (not phase_rows(before_continue) and actual_phase == expected_phase
                       and surface_rows(resumed) == surface_rows(uninterrupted))
        passed = resumed_state == state and dupes == 0 and rows_ok
        prefix = "QA143 RELEASE" if release_output is None else "QA143 ROUND"
        print(f"{prefix} seed={seed} d={decision} save={stage} uninterrupted={counts[ACTION]} "
              f"resumed={n_actions} dupes={dupes} {'PASS' if passed else 'FAIL'}", flush=True)
        if not passed:
            details = {"expected_state": state, "actual_state": resumed_state, "expected_phase": expected_phase,
                       "actual_phase": actual_phase, "before_continue": before_continue}
            diff_path = output / f"diff-{seed}-d{decision}-{stage}.json"
            diff_path.write_text(json.dumps(details, indent=2) + "\n")
            raise AssertionError(f"See {diff_path}")
        if stage == "written":
            print(f"QA143 CHECKPOINT seed={seed} d={decision} written={len(phase_rows(before_continue))} "
                  "appended_on_continue=0 PASS", flush=True)
        if release_output is not None and fixture == STATUS:
            print(f"QA143 PHASE status={counts['enemy_status_tick']} "
                  f"turn_start={counts['player_turn_started']} PASS", flush=True)
    return len(stages)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reuse-completed", action="store_true", help="Recheck completed replays and run the remaining lanes")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--release", action="store_true", help="Run against the untouched release code")
    mode.add_argument("--release-output", type=Path, help="Check the complete uninterrupted stream against release")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    release_output = args.release_output.resolve() if args.release_output else None
    with ThreadPoolExecutor(max_workers=REPLAY_WORKERS) as workers:
        primary = workers.submit(compare, output, PRIMARY, ("before", "mid", "after", "written"),
                                 release_output, args.reuse_completed)
        status = workers.submit(compare, output, STATUS, ("mid",), release_output, args.reuse_completed)
        rounds = primary.result() + status.result()
    if not args.release:
        print(f"QA143 ANALYTICS RESUME PASS rounds={rounds}", flush=True)


if __name__ == "__main__":
    main()
