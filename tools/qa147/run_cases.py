#!/usr/bin/env python3
"""Exercise won checkpoints through the task runner, then count physical JSONL rows."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PROBE = "res://tools/qa147/probe.gd"
FIXED_FPS = "120"
PROCESS_TIMEOUT = "90"
KILLED_EXIT = 247
CASES = {
    "card_control": ("card", "control"),
    "card_save_victory": ("card", "save_victory"),
    "card_save_intro": ("card", "save_intro"),
    "card_save_ready": ("card", "save_ready"),
    "card_close_victory": ("card", "close_victory"),
    "card_close_intro": ("card", "close_intro"),
    "card_close_ready": ("card", "close_ready"),
    "card_kill_after_write": ("card", "kill_after_write"),
    "fire_kill_after_write": ("fire", "kill_after_write"),
    "fire_kill_before_write": ("fire", "kill_before_write"),
    "burst_kill_before_write": ("burst", "kill_before_write"),
    "turn_start_save_victory": ("turn_start", "save_victory"),
    "guardian_close_ready": ("guardian", "close_ready"),
    "dragon_save_victory": ("dragon", "save_victory"),
    "final_dragon_save_victory": ("final_dragon", "save_victory"),
    "continue_twice": ("card", "close_victory"),
    "save_twice": ("card", "save_victory"),
}


def launch(directory, kind, cut, label, save_again=False):
    env = dict(os.environ, QA147_OUTPUT=str(directory), QA147_KIND=kind, QA147_CUT=cut,
               QA147_SAVE_AGAIN="1" if save_again else "0", LABYRINTH_DEMO="0" if kind == "dragon" else "1")
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-147",
               "--timeout", PROCESS_TIMEOUT, "--stream", "--", "godot", "--headless",
               "--fixed-fps", FIXED_FPS, "--path", ".", "--script", PROBE]
    (directory / f"{label}-command.json").write_text(json.dumps({
        "command": command, "env": {key: env[key] for key in env
                                    if key.startswith("QA147_") or key == "LABYRINTH_DEMO"},
    }, indent=2) + "\n")
    with (directory / f"{label}.log").open("w") as log:
        return subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                              stderr=subprocess.STDOUT, check=False).returncode


def run_case(output, name):
    directory = output / name
    directory.mkdir()
    kind, cut = CASES[name]
    killed = cut.startswith("kill_")
    valid = launch(directory, kind, cut, "initial", name == "save_twice") == (KILLED_EXIT if killed else 0)
    if cut != "control":
        valid &= (directory / "cut.txt").is_file()
    if valid and (killed or cut.startswith("close_")):
        checkpoint = directory / "run.save"
        if checkpoint.is_file():
            shutil.copyfile(checkpoint, directory / "interrupted.save")
        if name == "continue_twice":
            original = directory / "before-close.save"
            valid &= original.is_file()
            if valid:
                shutil.copyfile(original, checkpoint)
        if valid:
            valid &= launch(directory, kind, "continue", "continue-1") == 0
        if name == "continue_twice" and valid:
            valid &= (directory / "ready.txt").is_file()
            if valid:
                shutil.copyfile(original, checkpoint)
                (directory / "ready.txt").rename(directory / "first-ready.txt")
                valid &= launch(directory, kind, "continue", "continue-2") == 0
    expected = {"guardian": "guardian", "dragon": "dragon", "final_dragon": "final_dragon"}.get(kind, "combat")
    ready = directory / "ready.txt"
    valid &= ready.is_file() and ready.read_text().strip() == expected
    if name == "save_twice":
        valid &= (directory / "saved_again.txt").is_file()
    combat_id_file = directory / "combat_id.txt"
    combat_id = combat_id_file.read_text().strip() if combat_id_file.is_file() else ""
    rows = []
    if combat_id:
        for path in (directory / "analytics").glob("*.jsonl"):
            for line in path.read_text().splitlines():
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("combat_id") == combat_id and row.get("event_type") in ("combat_ended", "reward_offered"):
                    rows.append(row)
    types = [row["event_type"] for row in rows]
    counts = [types.count(event) for event in ("combat_ended", "reward_offered")]
    passed = valid and types == ["combat_ended", "reward_offered"]
    (directory / "result.json").write_text(json.dumps({
        "boundary_verified": valid, "combat_id": combat_id, "rows": rows,
    }, indent=2) + "\n")
    return passed, f"QA147 {name} combat_ended={counts[0]} reward_offered={counts[1]} {'PASS' if passed else 'FAIL'}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--only", action="append", choices=CASES)
    parser.add_argument("--jobs", default=2, type=int)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True)
    names = args.only or CASES
    with ThreadPoolExecutor(max_workers=args.jobs) as workers:
        results = list(workers.map(lambda name: run_case(output, name), names))
    for _, line in results:
        print(line)
    passed = all(case_passed for case_passed, _ in results)
    print(f"QA147 {'PASS' if passed else 'FAIL'} cases={len(results)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
