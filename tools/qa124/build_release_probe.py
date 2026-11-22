#!/usr/bin/env python3
"""Package the quit probe in a disposable Steam macOS release build."""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from export_smoke import STAGING_EXCLUDES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output / ".gdignore").touch()
    staged = output / "project"

    def ignore(directory, names):
        excluded = STAGING_EXCLUDES if Path(directory) == ROOT else set()
        return (excluded | {".DS_Store", "__pycache__"}).intersection(names)

    shutil.copytree(ROOT, staged, ignore=ignore)
    # Official release templates disable --script. Only this disposable pack
    # gets a different entry scene. Production scripts and assets are copied.
    probe = staged / "__qa124__"
    probe.mkdir()
    shutil.copy2(ROOT / "tools/qa124/quit_probe.gd", probe / "quit_probe.gd")
    (probe / "quit.tscn").write_text(
        '[gd_scene load_steps=2 format=3]\n'
        '[ext_resource type="Script" path="res://__qa124__/quit_probe.gd" id="1"]\n'
        '[node name="QA124QuitProbe" type="Node"]\nscript = ExtResource("1")\n'
    )
    config = staged / "project.godot"
    contents, count = re.subn(r"^run/main_scene=.*$", 'run/main_scene="res://__qa124__/quit.tscn"',
                              config.read_text(), flags=re.M)
    if count != 1:
        raise ValueError("Expected exactly one main scene setting")
    config.write_text(contents)
    command = [sys.executable, "tools/export_game.py", "--task-id", "qa-124",
               "--preset", "Steam macOS", "--project", str(staged),
               "--output", str(output / "QA124 Quit Probe.app")]
    return subprocess.run(command, cwd=ROOT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
