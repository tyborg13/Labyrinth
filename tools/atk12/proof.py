#!/usr/bin/env python3
"""atk-12 proof recipes; stdlib only, no game content or permanent tests.

prepare copies real atk-10 saves and reconstructs Iskaldra's recorded inputs.
receipts replays those inputs headless through the atk-08 observer.
native-commands prints windowed commands for the design owner's machine.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = Path("/private/tmp/labyrinth_codex/atk-12/current")
ATK10 = Path("/private/tmp/labyrinth_codex/atk-10/receipts")
CASES = {
    "zekarion": (102, "after/normal-0/seed-102-hp9999/repro/102-555"),
    "iskaldra": (101, "after/normal-0/seed-101-hp9999/repro/101-635"),
    "vyraketh": (101, "before-saves/normal-0/seed-101-hp9999/repro/101-257"),
    "room_frostbite": (101, str(OUTPUT / "after/normal-0/seed-101-hp9999/repro/101-651")),
}
# Proof-only budgets: Iskaldra replays 13 inputs before the final captured pass.
REPLAY_TIMEOUT_SECONDS = 300
NATIVE_TIMEOUT_SECONDS = 300
STRIP_SECONDS = 20
STRIP_INTERVAL_SECONDS = 1 / 30
STRIP_REQUIRED_LIFE_PROGRESS = 0.8


def variant(value):
    if isinstance(value, str) and re.fullmatch(r"\(-?\d+, -?\d+\)", value):
        return "Vector2i" + value
    if isinstance(value, list):
        return "[" + ", ".join(variant(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(json.dumps(k) + ": " + variant(v) for k, v in value.items()) + "}"
    return json.dumps(value)


def prepare(root: Path):
    for name, (_, relative) in CASES.items():
        target = root / "saves" / name
        target.mkdir(parents=True, exist_ok=True)
        for filename in ("run.save", "progression.json", "combat_state.txt", "decisions.txt"):
            shutil.copyfile(ATK10 / relative / filename, target / filename)
        if name == "iskaldra":
            trace = ATK10 / "after/normal-0/seed-101-hp9999/trace.jsonl"
            decisions = []
            for line in trace.read_text().splitlines():
                row = json.loads(line)
                data = row["data"]
                if row["event"] == "decision" and 635 <= data["decision"] <= 648:
                    decisions.append({k: data[k] for k in ("kind", "method", "args", "tile", "card_id") if k in data})
            assert len(decisions) == 14 and decisions[-1]["kind"] == "pass"
            (target / "decisions.txt").write_text(variant(decisions) + "\n")
        (target / "origin.json").write_text(json.dumps({"source": str(ATK10 / relative), "trace_range": [635, 648] if name == "iskaldra" else None}, indent=2) + "\n")
        print("Prepared", target)


def receipt_commands(root: Path, cases: list[str], phases: list[str]):
    for name in cases:
        seed, _ = CASES[name]
        speed = "fastest" if name == "vyraketh" else "normal"
        for phase in phases:
            directory = root / f"target-{phase}" / f"{speed}-0" / f"seed-{seed}-{name}-hp9999"
            command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "atk-12", "--stream", "--timeout", str(REPLAY_TIMEOUT_SECONDS), "--", "godot", "--headless", "--path", ".", "--script", "tools/atk12/replay.gd", "--", "--seed", str(seed), "--health", "9999", "--output-dir", str(directory)]
            env = dict(os.environ, ATK12_SAVE_DIR=str(root / "saves" / name), ATK12_EXPECT_ACTOR="" if name == "room_frostbite" else name, ATK12_BEFORE="1" if phase == "before" else "0", ATK08_SPEED=speed, ATK08_REDUCED="0", ATK08_TIME_SCALE="6")
            print(name, phase, flush=True)
            directory.mkdir(parents=True, exist_ok=True)
            with (directory / "runner.log").open("w") as log:
                result = subprocess.run(command, cwd=PROJECT, env=env, stdout=log, stderr=subprocess.STDOUT)
            print("\n".join(line for line in (directory / "runner.log").read_text().splitlines() if "ATK12 REPLAY:" in line or "SCRIPT ERROR" in line), flush=True)
            if result.returncode:
                raise SystemExit(f"Replay failed ({result.returncode}); see {directory / 'runner.log'}")


def native_commands(root: Path, cases: list[str], phases: list[str]):
    for name in cases:
        for phase in phases:
            # Required normal-speed strips for all cases; Vyraketh also needs
            # fastest to resolve the original sampling/early-removal question.
            for speed in (["normal", "fastest"] if name == "vyraketh" else ["normal"]):
                out = root / "native" / name / phase / speed
                command = ["python3", "tools/visual_probe_runner.py", "tools/atk08/strip.gd", "--task-id", "atk-12", "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--godot", str(PROJECT / "tools/atk08/strip_movie.sh"), "--timeout", str(NATIVE_TIMEOUT_SECONDS), "--expect-size", "1920x1080", "--proof-contract", "tools/atk12/strip_contract.json", "--result-manifest", str(out / "proof.json"), "--", "--save-dir", str(root / "saves" / name), "--out-dir", str(out), "--seconds", str(STRIP_SECONDS), "--every", str(STRIP_INTERVAL_SECONDS), "--speed", speed, "--reduced", "0", "--before", "1" if phase == "before" else "0"]
                if phase == "after" or name == "vyraketh":
                    command += ["--require-number", {"zekarion": "-5", "iskaldra": "-3", "vyraketh": "-6", "room_frostbite": "-3"}[name]]
                    if name != "room_frostbite":
                        command += ["--require-actor", name]
                if name == "vyraketh":
                    command += ["--require-progress", str(STRIP_REQUIRED_LIFE_PROGRESS)]
                print(f"cd {shlex.quote(str(PROJECT))} && {shlex.join(command)}")


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("action", choices=["prepare", "receipts", "native-commands"])
    parser.add_argument("--root", type=Path, default=OUTPUT)
    parser.add_argument("--cases", nargs="+", choices=CASES, default=list(CASES))
    parser.add_argument("--phases", nargs="+", choices=["before", "after"], default=["before", "after"])
    args = parser.parse_args()
    if args.action == "prepare":
        prepare(args.root)
    elif args.action == "receipts":
        receipt_commands(args.root, args.cases, args.phases)
    else:
        native_commands(args.root, args.cases, args.phases)


if __name__ == "__main__":
    main()
