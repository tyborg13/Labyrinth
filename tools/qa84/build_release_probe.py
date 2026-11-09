#!/usr/bin/env python3
"""Build a disposable release app with the quit probe as its packed main scene.

Official release templates reject external --script/--path overrides. Keep all
product code and assets byte-identical; change only this copy's entry scene.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / "tools"))
from export_smoke import STAGING_EXCLUDES


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args(argv)
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    staged = output / "project"
    if staged.exists():
        parser.error("use a fresh output directory; refusing to replace an existing project")
    # The wrapper validates the sanitized copy against the source cel manifest.
    code = subprocess.run([sys.executable, str(PROJECT / "tools/cel_look.py"),
                           "build", "--if-stale"], cwd=PROJECT).returncode
    if code:
        return code

    def ignore(directory, names):
        excluded = set(STAGING_EXCLUDES) if Path(directory) == PROJECT else set()
        return (excluded | {".DS_Store", "__pycache__"}).intersection(names)

    shutil.copytree(PROJECT, staged, ignore=ignore)
    probe = staged / "__qa84__"
    probe.mkdir()
    shutil.copy2(PROJECT / "tools/qa84/quit_probe.gd", probe / "quit_probe.gd")
    (probe / "quit.tscn").write_text(
        '[gd_scene load_steps=2 format=3]\n'
        '[ext_resource type="Script" path="res://__qa84__/quit_probe.gd" id="1"]\n'
        '[node name="QA84QuitProbe" type="Node"]\nscript = ExtResource("1")\n')
    config_path = staged / "project.godot"
    config, count = re.subn(r'^run/main_scene=.*$', 'run/main_scene="res://__qa84__/quit.tscn"',
                            config_path.read_text(), flags=re.M)
    if count != 1:
        raise ValueError("expected exactly one application main scene")
    config_path.write_text(config)
    app = output / "Escape the Umbra Demo.app"
    command = [sys.executable, str(PROJECT / "tools/export_game.py"),
               "--task-id", "qa-84", "--preset", "Steam Demo macOS",
               "--godot", args.godot, "--project", str(staged), "--output", str(app)]
    (output / "build.json").write_text(json.dumps(dict(command=command, app=str(app),
        instrumentation=["__qa84__/quit_probe.gd", "__qa84__/quit.tscn", "project.godot:run/main_scene"]), indent=2) + "\n")
    return subprocess.run(command, cwd=PROJECT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
