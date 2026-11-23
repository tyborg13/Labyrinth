#!/usr/bin/env python3
"""Check the six export filters and mount the effects candidate pack."""

import argparse
import configparser
import json
from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT = Path(__file__).resolve().parents[2]
SOURCE_TIPS = ("a0094c780", "ba6f5ac47", "7520d815f", "2f23a3376")
sys.path.insert(0, str(PROJECT / "tools/mrg14"))
from pck_check import PROBE, inventory


def filters(contents):
    presets = configparser.ConfigParser(interpolation=None)
    presets.read_string(contents)
    return {
        presets[section]["name"].strip('"'): set(
            presets[section]["include_filter"].strip('"').split(",")
        )
        for section in presets.sections()
        if "include_filter" in presets[section]
    }


def check_filters(expected):
    current = filters((PROJECT / "export_presets.cfg").read_text())
    sources = [filters(subprocess.check_output(
        ["git", "show", f"{tip}:export_presets.cfg"], cwd=PROJECT, text=True
    )) for tip in SOURCE_TIPS]
    required_data = {path.removeprefix("res://") for path in expected}
    required_data.remove("data/controls.json")  # Already exported by Godot as a resource.
    assert len(current) == 6
    for name, patterns in current.items():
        required = required_data.union(*(presets[name] for presets in sources))
        if missing := required - patterns:
            raise ValueError(f"{name} omits {', '.join(sorted(missing))}")
        print(f"MRG-15 EXPORT FILTER {name}: PASS ({len(patterns)} patterns)")
    print("MRG-15 EXPORT FILTERS: PASS (6/6 presets)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", nargs="?", type=Path)
    args = parser.parse_args()
    expected = inventory()
    check_filters(expected)
    if args.pack is None:
        return 0
    pack = args.pack.resolve()
    if not pack.is_file():
        parser.error(f"Pack does not exist: {pack}")
    with tempfile.TemporaryDirectory(prefix="mrg15-pck-") as directory:
        project = Path(directory)
        (project / "project.godot").write_text("config_version=5\n")
        script = project / "probe.gd"
        script.write_text(PROBE.replace("MRG-14", "MRG-15"))
        manifest = project / "expected.json"
        manifest.write_text(json.dumps(expected))
        return subprocess.run([
            sys.executable, str(PROJECT / "tools/godot_task_runner.py"),
            "--task-id", "mrg-15", "--stream", "--project", str(project), "--", "godot",
            "--headless", "--path", str(project), "--script", str(script), "--",
            str(pack), str(manifest),
        ], cwd=PROJECT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
