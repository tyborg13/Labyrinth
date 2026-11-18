#!/usr/bin/env python3
"""Use the normal certification wrapper with qa-91's private fixture builder."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import inspection_fixture

original_run = inspection_fixture.subprocess.run
original_command_text = inspection_fixture.command_text


def run(command, *args, **kwargs):
    command = list(command)
    if "tools/inspection_fixture.gd" in command:
        command[command.index("tools/inspection_fixture.gd")] = "tools/qa91/fixture.gd"
    return original_run(command, *args, **kwargs)


def command_text(command):
    return original_command_text(command).replace(
        "tools/inspection_fixture.gd", "tools/qa91/fixture.gd"
    ).replace("tools/inspection_fixture.py", "tools/qa91/fixture_task.py")


if __name__ == "__main__":
    inspection_fixture.subprocess.run = run
    inspection_fixture.command_text = command_text
    raise SystemExit(inspection_fixture.main())
