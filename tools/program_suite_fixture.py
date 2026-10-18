#!/usr/bin/env python3
"""Prepare serial package/capture fixtures inside one program scheduler slot."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

PACK_TIMEOUT_SECONDS = 30
CAPTURE_VIDEO_QUALITY = 1.0


def fixture_stages(root: Path, program: dict, directory: Path) -> list[tuple[Path, str, list[str]]]:
    path = program["path"]
    mode = program.get("mode", "script")
    if mode in ("cutout_pack", "roster_pack"):
        pack = directory / "fixture.pck"
        if mode == "roster_pack":
            # Source-package build; the separate export-template smoke is not
            # replaced by a source-tree run pretending to be an export.
            return [(root, path, [str(pack)])]
        empty = directory / "empty"
        empty.mkdir()
        (empty / "project.godot").write_text('config_version=5\n', encoding="utf-8")
        return [(root, path, ["build", str(pack)]), (empty, str(root / path), ["verify", str(pack)])]
    if mode == "capture_settings":
        staged = directory / "capture"
        staged.mkdir()
        (staged / "project.godot").write_text('config_version=5\n', encoding="utf-8")
        for relative in (path, "tools/demo_clips/capture_settings.gd",
                         "tools/demo_clips/demo_clip.gd", "tests/sfx_sync_sources.gd"):
            target = staged / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        (staged / "override.cfg").write_text(
            "[editor]\nmovie_writer/mjpeg_quality=%s\nmovie_writer/video_quality=%s\n" %
            (CAPTURE_VIDEO_QUALITY, CAPTURE_VIDEO_QUALITY), encoding="utf-8")
        return [(staged, path, ["--verify-movie-guard"])]
    if mode != "script":
        raise ValueError("Unknown program fixture mode: " + mode)
    return [(root, path, program.get("args", []))]


def main(argv=None) -> int:
    # Import only for execution; the audit also uses fixture_stages without
    # loading a scheduler or a second copy of its manifest.
    from program_suite_runner import SUPPLEMENTAL_BY_NAME, task_command, write_child_bootstrap

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--suite", required=True)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--timeout", type=float, required=True)
    args = parser.parse_args(argv)
    started = time.monotonic()
    root, directory = args.project.resolve(), args.directory.resolve()
    program = SUPPLEMENTAL_BY_NAME[args.suite]
    workspace = Path(tempfile.mkdtemp(prefix="fixture-", dir=directory))
    stages = fixture_stages(root, program, workspace)
    for index, (project, script, user_args) in enumerate(stages):
        stage_directory = directory if index == 0 else directory / ("stage-%d" % index)
        stage_directory.mkdir(parents=True, exist_ok=True)
        bootstrap = stage_directory / (Path(script).stem + ".gd")
        target = str(Path(script)) if Path(script).is_absolute() else str(project / script)
        # Inside the repository project the class is registered at its res:// path; an absolute
        # path there declares ParallelRuntime twice. Only foreign stage projects need the file path.
        runtime = ("res://scripts/parallel_runtime.gd" if project.resolve() == root
                   else str(root / "scripts/parallel_runtime.gd"))
        write_child_bootstrap(bootstrap, args.suite, target=target, parallel_runtime=runtime)
        remaining = args.timeout - (time.monotonic() - started)
        if remaining <= 0:
            return 124
        timeout = min(remaining, PACK_TIMEOUT_SECONDS) if program["mode"].endswith("pack") else remaining
        command = task_command(project, args.task_id + "-stage-%d" % index, timeout, [
            args.godot, "--log-file", str(stage_directory / "godot.log"),
            "--headless", "--path", str(project), "--script", str(bootstrap), "--", *user_args])
        result = subprocess.run(command, cwd=root)
        if result.returncode:
            return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
