#!/usr/bin/env python3
"""Materialize the pinned QA-129 harness in the QA-131 evidence directory."""

import argparse
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = Path("/private/tmp/labyrinth_codex/qa-131")
HARNESS = "3335b1852"
FILES = ("audit.gd", "evidence.py", "fixtures.gd", "release_controls.gd", "targets.py", "whole_run.gd")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--windowed-census", action="store_true")
    args = parser.parse_args()
    destination = OUTPUT / ("native-harness" if args.windowed_census else "harness")
    destination.mkdir(parents=True, exist_ok=True)
    if args.windowed_census:
        # Use an isolated driver copy for the GPU census. The normal hunt keeps
        # its headless guard and the renderer's frame boundary stays unmocked.
        base = (PROJECT / "tools/run_hunt.gd").read_text()
        guard_start = base.index('\tif DisplayServer.get_name() != "headless":')
        guard_end = base.index("\tDirAccess.make_dir_recursive_absolute", guard_start)
        base = base[:guard_start] + base[guard_end:]
        base = base.replace("\tprocess_frame.connect(_headless_draw_boundary)",
                            '\tif DisplayServer.get_name() == "headless":\n'
                            '\t\tprocess_frame.connect(_headless_draw_boundary)')
        (destination / "run_hunt.gd").write_text(base)
    for name in FILES:
        source = subprocess.check_output(
            ["git", "show", f"{HARNESS}:tools/qa129/{name}"], cwd=PROJECT, text=True
        )
        if name == "targets.py":
            source = source.replace("ROOT = Path(__file__).resolve().parents[2]",
                                    "ROOT = Path.cwd()")
            source = source.replace('TASK_ID = "qa-129"', 'TASK_ID = "qa-131"')
            source = source.replace('"tools/qa129/whole_run.gd"',
                                    'str(Path(__file__).with_name("campaign.gd"))')
            source = source.replace("choices=(1, 2, 3), default=3",
                                    "choices=(1, 2), default=2")
        if name == "whole_run.gd" and args.windowed_census:
            source = source.replace('extends "res://tools/run_hunt.gd"',
                                    f'extends "{destination / "run_hunt.gd"}"')
        (destination / name).write_text(source)
    (destination / "campaign.gd").write_text(
        Path(__file__).with_name("campaign.gd.in").read_text().replace(
            'extends "whole_run.gd"', f'extends "{destination / "whole_run.gd"}"'
        )
    )
    print(f"QA131 HARNESS: QA-129 {HARNESS} at {destination}")


if __name__ == "__main__":
    main()
