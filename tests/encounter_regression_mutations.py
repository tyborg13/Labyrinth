#!/usr/bin/env python3
"""Opt-in spx-01 mutation proof; temporarily edit sources, then restore exact bytes.

Godot always runs through the task runner. Per-process logs stay outside the repo.
This is not an automatic discovery test: it intentionally mutates runtime sources.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TASK_ID = "spx-01"
DEFAULT_LOG_DIR = Path("/private/tmp/spx-01-feedback-2/mutations")
ANALYTICS = "tests/encounter_analytics_test.gd"
LEGACY = "tests/combat_analytics_context_equivalence_test.gd"
MEASUREMENT = "tests/encounter_measurement_test.gd"
PROGRAMS = (ANALYTICS, LEGACY, MEASUREMENT)
HELPER = "scripts/encounter_analytics_context.gd"
HEADLESS = "tools/headless_playtest.gd"
UI = "scripts/run_scene.gd"
SAVE = "scripts/progression_store.gd"
MUTATIONS = (
    ("blank_room_type", HELPER,
     '"room_type": str(combat.get("room_type", room.get("type", "")))', '"room_type": ""',
     ((ANALYTICS, "metadata.room_type"), (LEGACY, "Guardian context preserves independent legacy room fields"))),
    ("blank_guardian_id", HELPER,
     '"guardian_id": str(combat.get("guardian_id", room.get("guardian_id", "")))', '"guardian_id": ""',
     ((ANALYTICS, "metadata.guardian_id"), (LEGACY, "Guardian context preserves independent legacy room fields"))),
    ("remove_headless_merge", HEADLESS,
     '\tcontext.merge(preload("res://scripts/encounter_analytics_context.gd").fields(_run_state, combat_state, room), true)\n', '',
     ((ANALYTICS, "headless combat combat_started metadata.room_type"),)),
    ("remove_ui_merge", UI,
     '\tcontext.merge(preload("res://scripts/encounter_analytics_context.gd").fields(run_state, combat_state, room_meta), true)\n', '',
     ((ANALYTICS, "UI combat combat_started metadata.encounter_id"),)),
    # A nonempty dictionary passes the writer's read-back validation. Only the
    # complete state equality check detects this truncated but decodable save.
    ("corrupt_save_writer", SAVE, 'file.store_var(run_state, false)',
     'file.store_var({"corrupted_save_writer": true}, false)',
     ((MEASUREMENT, "ProgressionStore restores complete run state"),)),
)


def run_program(log_dir: Path, phase: str, program: str) -> tuple[dict, str]:
    directory = log_dir / phase
    directory.mkdir(parents=True, exist_ok=True)
    log = directory / (Path(program).stem + ".log")
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", TASK_ID,
               "--stream", "--", "godot", "--headless", "--path", ".", "--script", program]
    with log.open("w") as stream:
        process = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    output = log.read_text()
    record = {"phase": phase, "program": program, "command": command,
              "returncode": process.returncode, "log": str(log),
              "result_lines": [line for line in output.splitlines()
                               if (line.startswith("ENCOUNTER ") and " PATH:" not in line)
                               or line.startswith("TEST RESULT:")]}
    return record, output


def controls(log_dir: Path, phase: str, results: list[dict]) -> None:
    for program in PROGRAMS:
        record, _ = run_program(log_dir, phase, program)
        results.append(record)
        if record["returncode"] != 0 or not any(": PASS" in line for line in record["result_lines"]):
            raise RuntimeError(f"Positive control failed: {record['log']}")
        print(f"MUTATION CONTROL: PASS ({phase}; {program})", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log-dir", type=Path, default=DEFAULT_LOG_DIR)
    args = parser.parse_args()
    log_dir = args.log_dir.resolve()
    if log_dir == ROOT or ROOT in log_dir.parents:
        parser.error("Mutation logs must be outside the worktree")
    log_dir.mkdir(parents=True, exist_ok=True)
    originals = {name: (ROOT / name).read_bytes() for name in {mutation[1] for mutation in MUTATIONS}}
    results: list[dict] = []
    killed: list[str] = []
    try:
        controls(log_dir, "before", results)
        for name, source, old, new, programs in MUTATIONS:
            path = ROOT / source
            original = originals[source]
            if original.decode().count(old) != 1:
                raise RuntimeError(f"Mutation anchor must occur once: {name}")
            try:
                path.write_bytes(original.replace(old.encode(), new.encode(), 1))
                for program, diagnostic in programs:
                    record, output = run_program(log_dir, name, program)
                    results.append(record)
                    semantic_failure = any(": FAIL" in line for line in record["result_lines"])
                    failure = next((line for line in output.splitlines()
                                    if diagnostic in line and (line.startswith("FAIL:") or line.startswith("ERROR:"))), "")
                    if record["returncode"] == 0 or not semantic_failure or not failure:
                        raise RuntimeError(f"Mutation survived or failed without its expected assertion: {record['log']}")
                    record["expected_assertion"] = failure
            finally:
                path.write_bytes(original)
            killed.append(name)
            print(f"MUTATION KILLED: {name}", flush=True)
        controls(log_dir, "restored", results)
    finally:
        for name, original in originals.items():
            (ROOT / name).write_bytes(original)
        summary = {"task_id": TASK_ID, "killed": killed, "expected_mutations": len(MUTATIONS),
                   "results": results, "restored_sha256": {
                       name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(originals)}}
        (log_dir / "results.json").write_text(json.dumps(summary, indent=2) + "\n")
    assert all((ROOT / name).read_bytes() == original for name, original in originals.items())
    print(f"ENCOUNTER REGRESSION MUTATIONS: PASS ({len(killed)}/{len(MUTATIONS)} killed; restored controls pass)")


if __name__ == "__main__":
    main()
