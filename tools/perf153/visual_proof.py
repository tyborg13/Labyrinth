#!/usr/bin/env python3
"""Capture both proof profiles, with the original PNGs temporarily installed for before."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

from resize_textures import ART, MASTERS, ROOT, SIZES

GODOT_RUNNER = ["tools/godot_task_runner.py", "--task-id", "perf-153", "--stream"]


def refresh_imports() -> None:
    # Import just the six textures at their production res:// paths.
    cache = ROOT / ".godot"
    cache.mkdir(exist_ok=True)
    (cache / "imported").mkdir(exist_ok=True)
    with TemporaryDirectory(prefix="perf153-import-", dir=cache) as scratch:
        project = Path(scratch)
        (project / "project.godot").write_text("config_version=5\n")
        for path in SIZES:
            source = ART / path
            target = project / source.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            shutil.copyfile(source.with_suffix(".png.import"), target.with_suffix(".png.import"))
        subprocess.run([
            sys.executable, *GODOT_RUNNER, "--project", scratch, "--",
            "godot", "--headless", "--path", ".", "--import",
        ], cwd=ROOT, check=True)
        for path in SIZES:
            sidecar = (ART / path).with_suffix(".png.import")
            cached_sidecar = project / sidecar.relative_to(ROOT)
            if cached_sidecar.read_bytes() != sidecar.read_bytes():
                raise RuntimeError(f"Godot rewrote the import sidecar for {path}")
            artifact = re.search(r'^path="res://([^"]+)"', sidecar.read_text(), re.M)[1]
            for relative in (artifact, str(Path(artifact).with_suffix(".md5"))):
                (project / relative).replace(ROOT / relative)
    print("PERF153 IMPORT: 6 refreshed texture caches; all 6 original import sidecars match byte-for-byte", flush=True)


def run_capture(phase: str, result_manifest: Path | None) -> int:
    env = os.environ.copy()
    env["LABYRINTH_CEL_LOOK"] = "off"
    env["LABYRINTH_PERF153_BASELINE"] = "1" if phase == "before" else "0"
    if result_manifest is None:
        return subprocess.call([
            sys.executable, *GODOT_RUNNER, "--", "godot", "--headless", "--path", ".",
            "--script", "tools/perf153/ui_probe.gd",
        ], cwd=ROOT, env=env)
    return subprocess.call([
        sys.executable, "tools/visual_probe_runner.py",
        "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
        "--task-id", "perf-153", "--proof-contract", "tools/perf153/ui_proof.json",
        "--result-manifest", str(result_manifest.resolve()), "tools/perf153/ui_probe.gd",
    ], cwd=ROOT, env=env)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["before", "after"])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--result-manifest", type=Path)
    mode.add_argument("--headless-semantics", action="store_true")
    args = parser.parse_args()
    if args.phase == "after":
        refresh_imports()
        return run_capture(args.phase, args.result_manifest)
    # Read every candidate and master before changing any production source.
    candidates = {path: (ART / path).read_bytes() for path in SIZES}
    masters = {path: (MASTERS / path).read_bytes() for path in SIZES}
    try:
        for path, data in masters.items():
            (ART / path).write_bytes(data)
        refresh_imports()
        return run_capture(args.phase, args.result_manifest)
    finally:
        for path, data in candidates.items():
            (ART / path).write_bytes(data)
        refresh_imports()


if __name__ == "__main__":
    sys.exit(main())
