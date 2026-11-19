#!/usr/bin/env python3
"""Run the shared hunt with qa-101 runner isolation."""

import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_hunt

shared_command = run_hunt.command_for
shared_write = run_hunt.write_json


def command_for(seed, directory, args):
    command = shared_command(seed, directory, args)
    command[command.index("--task-id") + 1] = "qa-101"
    return command


def write_json(path, data):
    if path.name == "command.json":
        data["env"]["LABYRINTH_GROUND_FX"] = os.environ.get("LABYRINTH_GROUND_FX", "")
        data["env"].setdefault("LABYRINTH_DEMO", os.environ.get("LABYRINTH_DEMO", ""))
    shared_write(path, data)


if __name__ == "__main__":
    run_hunt.MAX_PROCESSES = 2
    run_hunt.command_for = command_for
    run_hunt.write_json = write_json
    raise SystemExit(run_hunt.main())
