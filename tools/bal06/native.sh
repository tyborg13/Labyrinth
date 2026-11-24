#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
export LABYRINTH_CEL_LOOK=all GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1
exec python3 - "$@" <<'PY'
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

CANDIDATE = "23152865ae25efdea3a915fc7bb56fe2a10e18fd"
CANDIDATE_PATHS = (
    "project.godot", "addons", "assets", "data", "experiments", "fonts",
    "scenes", "scripts", "shaders", "spec", "tests", "themes", "tools",
)
CACHE_FILES = ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg")
NATIVE_TIMEOUT_SECONDS = "300"
CAPTURE_SIZE = "1920x1080"


def stage_candidate(root, stage, candidate_cache):
    # Source and imports use the same resource paths in both data snapshots.
    archive = stage / "candidate.tar"
    subprocess.run(["git", "archive", "--format=tar", f"--output={archive}",
                    CANDIDATE, *CANDIDATE_PATHS], check=True)
    subprocess.run(["tar", "-xf", archive, "-C", stage], check=True)
    archive.unlink()
    cache = stage / ".godot"
    cache.mkdir()
    for name in CACHE_FILES:
        subprocess.run(["cp", "-cRp", candidate_cache / name, cache / name], check=True)
    subprocess.run(["cp", "-cRp", root / "cel_look_variants", stage / "cel_look_variants"], check=True)
    probe_dir = stage / "tools/bal06"
    probe_dir.mkdir()
    subprocess.run(["cp", "-p", root / "tools/bal06/probe.gd",
                    root / "tools/bal06/probe.gd.uid", probe_dir], check=True)


def capture_phase(root, project, phase, folder, dry_run):
    folder.mkdir()
    script = project / "tools/bal06/probe.gd"
    user_args = ["--out", folder]
    if phase == "after":
        user_args.append("--after")
    if dry_run:
        command = ["python3", "tools/godot_task_runner.py", "--task-id", "bal-06",
                   "--stream", "--", "godot", "--headless", "--path", project,
                   "--script", script, "--", "--dry-run", *user_args]
    else:
        command = ["python3", "tools/visual_probe_runner.py", script, "--project", project,
                   "--task-id", "bal-06", "--no-headless", "--display-driver", "macos",
                   "--audio-driver", "CoreAudio", "--timeout", NATIVE_TIMEOUT_SECONDS,
                   "--expect-size", CAPTURE_SIZE,
                   "--proof-contract", root / "tools/bal06/proof.json",
                   "--result-manifest", folder / "manifest.json", "--", *user_args]
    subprocess.run(command, check=True)


def main():
    parser = argparse.ArgumentParser(prog="native.sh")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    root = Path.cwd()
    output = Path(os.environ.get("BAL06_OUTPUT_ROOT", "/private/tmp/labyrinth_codex/bal-06"))
    if not output.is_absolute():
        parser.error("BAL06_OUTPUT_ROOT must be an absolute path")
    candidate_cache = Path(os.environ.get("BAL06_CANDIDATE_CACHE", root / ".godot"))
    output.mkdir(parents=True, exist_ok=True)
    prefix = "headless." if args.dry_run else "native."
    captures = Path(tempfile.mkdtemp(prefix=prefix, dir=output))
    print(f"BAL-06 output: {captures}", flush=True)
    with tempfile.TemporaryDirectory(prefix="bal06-base.", dir=root / ".godot") as directory:
        stage = Path(directory)
        stage_candidate(root, stage, candidate_cache)
        capture_phase(root, stage, "before", captures / "before", args.dry_run)
        capture_phase(root, root, "after", captures / "after", args.dry_run)
    if args.dry_run:
        print(f"BAL-06 NATIVE DRY RUN PASS — {captures}", flush=True)


try:
    main()
except subprocess.CalledProcessError as error:
    sys.exit(error.returncode)
PY
