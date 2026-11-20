#!/usr/bin/env python3
"""Refresh map texture imports and run the before/after map proof."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

from resize_textures import ART, MASTERS, ROOT, sha256, source_rows

RUNNER = [sys.executable, "tools/godot_task_runner.py", "--task-id", "perf-155", "--stream"]
PROBE = "tools/perf155/map_probe.gd"
CACHE = ROOT / ".godot"


def refresh_imports(names: list[str]) -> None:
    """Import at production res:// paths without scanning the task worktree."""
    CACHE.mkdir(exist_ok=True)
    (CACHE / "imported").mkdir(exist_ok=True)
    with TemporaryDirectory(prefix="perf155-import-", dir=CACHE) as scratch:
        project = Path(scratch)
        (project / "project.godot").write_text("config_version=5\n")
        for name in names:
            source = ART / name
            target = project / source.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            shutil.copyfile(source.with_suffix(".png.import"), target.with_suffix(".png.import"))
        subprocess.run([
            *RUNNER, "--project", scratch, "--", "godot", "--headless", "--path", ".", "--import",
        ], cwd=ROOT, check=True)
        artifacts = []
        for name in names:
            sidecar = (ART / name).with_suffix(".png.import")
            if (project / sidecar.relative_to(ROOT)).read_bytes() != sidecar.read_bytes():
                raise RuntimeError(f"Godot rewrote the import sidecar for {name}")
            artifact = Path(re.search(r'^path="res://([^"]+)"', sidecar.read_text(), re.M)[1])
            artifacts.extend([artifact, artifact.with_suffix(".md5")])
        for artifact in artifacts:
            (project / artifact).replace(ROOT / artifact)
    print(f"PERF155 IMPORT: {len(names)} refreshed texture caches, sidecars match byte-for-byte", flush=True)


def run_capture(phase: str, result_manifest: Path | None) -> None:
    env = os.environ.copy()
    env["LABYRINTH_CEL_LOOK"] = "off"
    env["LABYRINTH_PERF155_BASELINE"] = "1" if phase == "before" else "0"
    args = [*RUNNER, "--", "godot", "--headless", "--path", ".", "--script", PROBE]
    if result_manifest is not None:
        args = [
            sys.executable, "tools/visual_probe_runner.py", "--no-headless",
            "--display-driver", "macos", "--audio-driver", "Dummy", "--task-id", "perf-155",
            "--proof-contract", "tools/perf155/visual_proof.json",
            "--result-manifest", str(result_manifest.resolve()), PROBE,
        ]
    subprocess.run(args, cwd=ROOT, env=env, check=True)


def run_benchmark() -> None:
    env = os.environ.copy()
    env["LABYRINTH_CEL_LOOK"] = "off"
    args = [*RUNNER, "--", "godot", "--headless", "--path", ".",
            "--script", "tools/perf155/texture_load.gd"]
    subprocess.run(args, cwd=ROOT, env=env, check=True)
    subprocess.run(["taskpolicy", "-c", "background", *args], cwd=ROOT, env=env, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["before", "after"])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--result-manifest", type=Path)
    mode.add_argument("--headless-geometry", action="store_true")
    mode.add_argument("--import-only", action="store_true")
    mode.add_argument("--benchmark", action="store_true")
    args = parser.parse_args()
    rows = source_rows()
    names = list(rows)

    def run_phase() -> None:
        refresh_imports(names)
        if args.benchmark:
            run_benchmark()
        elif not args.import_only:
            run_capture(args.phase, args.result_manifest)

    if args.phase == "after":
        run_phase()
        return
    if args.import_only:
        parser.error("--import-only requires after")
    candidates = {name: (ART / name).read_bytes() for name in rows}
    for name, row in rows.items():
        if sha256(MASTERS / name) != row["master_sha256"]:
            raise ValueError(f"Master SHA-256 mismatch: {name}")
    try:
        for name in names:
            shutil.copyfile(MASTERS / name, ART / name)
        run_phase()
    finally:
        for name, data in candidates.items():
            (ART / name).write_bytes(data)
        refresh_imports(names)


if __name__ == "__main__":
    main()
