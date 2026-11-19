#!/usr/bin/env python3
"""Run the qa-101 hunt with the qa-111 SFX tap and a two-engine limit."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_hunt

shared_command = run_hunt.command_for


def command_for(seed, directory, args):
    command = shared_command(seed, directory, args)
    command[command.index("--task-id") + 1] = "qa-111"
    return command


if __name__ == "__main__":
    run_hunt.MAX_PROCESSES = 2
    run_hunt.command_for = command_for
    raise SystemExit(run_hunt.main())
