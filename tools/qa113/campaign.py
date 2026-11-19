#!/usr/bin/env python3
"""Run the QA-101 route policy with QA-110's settled-state receipts."""

import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "qa110"))
import campaign_base

FIXED_STEP_FPS = 120


def command_for(seed, directory, args):
    command = campaign_base.command_for(seed, directory, args)
    command[command.index("--task-id") + 1] = "qa-113"
    if os.environ.get("QA113_FIXED_STEP") == "1":
        index = command.index("--headless") + 1
        command[index:index] = ["--fixed-fps", str(FIXED_STEP_FPS)]
    return command


def write_json(path, data):
    if path.name == "command.json":
        for key in ("QA113_FIXED_STEP", "QA113_RED_WITNESS"):
            data["env"][key] = os.environ.get(key, "")
    campaign_base.write_json(path, data)


if __name__ == "__main__":
    hunt = campaign_base.run_hunt
    hunt.MAX_PROCESSES = 2
    hunt.command_for = command_for
    hunt.write_json = write_json
    if "--script" not in sys.argv:
        sys.argv.extend(("--script", "tools/qa113/whole_run.gd"))
    raise SystemExit(hunt.main())
