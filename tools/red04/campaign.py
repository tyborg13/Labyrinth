#!/usr/bin/env python3
"""Run the QA-110 policy and emit paired red-assembly receipts."""

import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_hunt

TASK_ID = os.environ.get("LABYRINTH_RED04_TASK_ID", "red-04")
DRIVER = "tools/red04/campaign.gd"
FIXED_FPS = "60"
shared_command = run_hunt.command_for
shared_write = run_hunt.write_json


def command_for(seed, directory, args):
    command = shared_command(seed, directory, args)
    command[command.index("--task-id") + 1] = TASK_ID
    if os.environ.get("LABYRINTH_RED04_FIXED_FPS") == "1":
        path_arg = command.index("--path")
        command[path_arg:path_arg] = ["--fixed-fps", FIXED_FPS]
    return command


def write_json(path, data):
    if path.name == "command.json":
        for key in ("LABYRINTH_CEL_LOOK", "LABYRINTH_GROUND_FX", "LABYRINTH_DEMO", "LABYRINTH_RED04_FIXED_FPS"):
            data["env"][key] = os.environ.get(key, "")
    shared_write(path, data)


if __name__ == "__main__":
    run_hunt.MAX_PROCESSES = 1
    run_hunt.command_for = command_for
    run_hunt.write_json = write_json
    sys.argv.extend(("--script", DRIVER))
    raise SystemExit(run_hunt.main())
