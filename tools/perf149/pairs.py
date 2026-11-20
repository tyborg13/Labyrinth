#!/usr/bin/env python3
"""Run matched Pass measurements against the worktree's prepared base."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]
CHANGED_RUNTIME = ("run_scene.gd", "player_turn_analytics.gd", "retained_hand_refresh.gd")
ORDER = ("A1", "B1", "B2", "A2", "A3", "B3")
FIXED_FPS = 60
ORIGINAL_BASE = "e3d3aba7f"
PROBE = ROOT / "tools/perf149/probe.gd"


def baseline_project(directory, base):
    directory.mkdir()
    for path in ROOT.iterdir():
        if path.name not in {".git", "scripts", "output"}:
            (directory / path.name).symlink_to(path, target_is_directory=path.is_dir())
    scripts = directory / "scripts"
    scripts.mkdir()
    for path in (ROOT / "scripts").iterdir():
        target = scripts / path.name
        if path.name in CHANGED_RUNTIME:
            target.write_bytes(subprocess.check_output(
                ["git", "show", f"{base}:scripts/{path.name}"], cwd=ROOT,
            ))
        else:
            target.symlink_to(path, target_is_directory=path.is_dir())
    return directory


def take(project, script, fixtures, output, *, detail=False, native=False):
    command = [
        sys.executable, str(ROOT / "tools/godot_task_runner.py"),
        "--task-id", "perf-149", "--stream", "--", "godot",
        *([] if native else ["--headless", "--fixed-fps", str(FIXED_FPS)]),
        "--path", str(project), "--script", script,
        "--", f"--fixtures={fixtures}", f"--output={output}", "--load=1",
    ]
    if detail:
        command.append("--detail")
    env = dict(os.environ, LABYRINTH_HITCH_TRACE="1", SteamDeck="1", LABYRINTH_CEL_LOOK="all")
    with output.with_suffix(".log").open("w") as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    for row in output.with_suffix(".log").read_text().splitlines():
        if row.startswith(("PERF-", "error:")):
            print(f"{output.name} {row}", flush=True)
    result.check_returncode()


def capture(project, kind, fixtures, output, capture_root):
    output.mkdir()
    with TemporaryDirectory(prefix=f"{output.name}-movie-", dir=capture_root) as temporary:
        env = dict(os.environ, SteamDeck="1", LABYRINTH_CEL_LOOK="all",
                   PERF134_CAPTURE_MOVIE=str(Path(temporary) / "clock.avi"))
        command = [
            sys.executable, str(ROOT / "tools/visual_probe_runner.py"), str(PROBE),
            "--task-id", "perf-149", "--project", str(project),
            "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--godot", str(ROOT / "tools/perf134/capture_godot.sh"),
            "--rendering-method", "mobile", "--rendering-driver", "metal",
            "--timeout", "180", "--expect-size", "1920x1080",
            "--proof-contract", str(PROBE.with_name("proof.json")),
            "--result-manifest", str(output / "images.json"),
            "--", f"--capture={kind}", f"--fixtures={fixtures}", f"--output={output}",
        ]
        subprocess.run(command, cwd=ROOT, env=env, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--base", default=ORIGINAL_BASE)
    parser.add_argument("--only", choices=("pairs", "detail", "identity", "captures"), default="pairs")
    parser.add_argument("--native", action="store_true", help="Use a real renderer for timing pairs.")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True)
    baseline = baseline_project(output / "baseline-project", args.base)
    if args.only == "captures":
        for arm, project in (("A", baseline), ("B", ROOT)):
            for kind in ("normal", "tharokh"):
                capture(project, kind, args.fixtures.resolve(), output / f"{arm}-{kind}", output)
        return
    cases = ORDER if args.only == "pairs" else ("A1", "B1")
    for name in cases:
        project = baseline if name.startswith("A") else ROOT
        script = f"tools/{'perf140' if args.only == 'identity' else 'perf149'}/probe.gd"
        take(project, script, args.fixtures.resolve(), output / name, detail=args.only == "detail", native=args.native)


if __name__ == "__main__":
    main()
