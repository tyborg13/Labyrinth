#!/usr/bin/env python3
"""Capture the five scoped shots with one harness against release and pol-69."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from compare_rects import SHOT_EXCLUSIONS, compare


HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parent.parent
OUTPUT_ROOT = Path("/private/tmp/labyrinth_codex/pol-69")
RELEASE_REV = "93ce8fa7bc68c271010bea3464dcf67d6118fdfd"
SIZE = "1920x1080"
SKILLS = "combat_character_skills"
GAMEPLAY = ("event_open", "event_closed", "hero_fire_peak", "fresh_run")


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def run(command, log_path, env):
    with log_path.open("w") as output:
        result = subprocess.run(command, cwd=WORKTREE, env=env, stdout=output, stderr=subprocess.STDOUT)
    log = log_path.read_text(errors="replace")
    for line in log.splitlines():
        if line.startswith(("POL69 ", "CENSUS RESULT:")):
            print(line, flush=True)
    if result.returncode:
        raise ValueError(f"Exit {result.returncode}. See {log_path}")
    return log


def receipt(log, marker):
    for line in reversed(log.splitlines()):
        if line.startswith(marker + " "):
            return json.loads(line.removeprefix(marker + " "))
    raise ValueError(f"Missing {marker} receipt")


def godot(project, script):
    return [
        sys.executable, "tools/godot_task_runner.py", "--task-id", "pol-69", "--stream",
        "--", "godot", "--headless", "--path", str(project), "--script", str(script),
    ]


def probe(project, script, arguments, target, images, dry_run):
    log_path = target / f"{script.stem}.log"
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all")
    if dry_run:
        command = [*godot(project, script), "--", *arguments, "--dry-run"]
    else:
        contract = target / f"{script.stem}-contract.json"
        required = [{"pattern": name + ".png", "width": w, "height": h} for name, w, h in images]
        write_json(contract, {"min_images": len(required), "expected_sizes": [SIZE], "required_images": required})
        env["POL69_WINDOWED_ENGINE"] = "1"
        command = [
            sys.executable, "tools/visual_probe_runner.py", str(script), "--project", str(project),
            "--task-id", "pol-69", "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--godot", str(HERE / "native.sh"), "--proof-contract", str(contract),
            "--result-manifest", str(target / f"{script.stem}-native.json"),
            "--", *arguments,
        ]
    return run(command, log_path, env)


def collect(project, target, dry_run, expected_enemy_icon=False):
    target.mkdir()
    plan = json.loads((project / "tools/scn01/shots.json").read_text())
    shot = next(item for item in plan["shots"] if item["shot"] == SKILLS)
    seed = shot.get("seed", plan["default_seed"])
    fixture_args = ["--scenario", shot["scenario"], "--seed", str(seed), *plan["fixture_sets"][shot["fixture"]]]
    fixture = receipt(run(
        [*godot(project, "tools/inspection_fixture.gd"), "--", *fixture_args],
        target / "fixture.log", dict(os.environ, LABYRINTH_CEL_LOOK="off"),
    ), "INSPECTION_FIXTURE_RESULT")
    png = target / f"{SKILLS}.png"
    census_args = [
        "--save", fixture["save_path"], "--profile", fixture["progression_path"],
        "--settings", str(Path(fixture["progression_path"]).with_name("settings.json")),
        "--mode", fixture["mode"], "--size", SIZE, "--png", str(png), "--shot", json.dumps(shot),
    ]
    census = receipt(probe(
        project, HERE / "census_measure.gd", census_args, target, [(SKILLS, 1920, 1080)], dry_run,
    ), "CENSUS_RESULT")
    # Natively the animated backdrop never stops changing pixels, so only headless runs require settling.
    if not census["ok"] or (census["capped"] and dry_run):
        raise ValueError(f"{target}: census did not settle")
    print("CENSUS RESULT: PASS; 1/1 shots succeeded; 0 capped", flush=True)
    gameplay_args = [str(target), fixture["save_path"]]
    if expected_enemy_icon:
        gameplay_args.append("--expect-enemy-icon")
    gameplay = receipt(probe(
        project, HERE / "capture.gd", gameplay_args, target,
        [(name, 1920, 1080) for name in GAMEPLAY] + [("hero_fire_peak_2x", 512, 288)], dry_run,
    ), "POL69_RESULT")
    shots = [dict(census, shot=SKILLS), *gameplay.values()]
    manifest = target / "manifest.json"
    write_json(manifest, {"size": SIZE, "ui_scale": 1.0, "dry_run": dry_run, "shots": shots})
    return manifest


def revision(path, *args):
    return subprocess.check_output(["git", "-C", str(path), *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--release", type=Path, default=WORKTREE.parent / "release")
    args = parser.parse_args()
    release = args.release.resolve()
    if revision(release, "branch", "--show-current") != "codex/release" or revision(release, "rev-parse", "HEAD") != RELEASE_REV:
        parser.error("The before worktree must be codex/release at " + RELEASE_REV)
    if revision(release, "status", "--porcelain"):
        parser.error("The before worktree has local changes")
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    try:
        if args.out is None:
            output = Path(tempfile.mkdtemp(prefix="headless-" if args.dry_run else "native-", dir=OUTPUT_ROOT))
        else:
            output = args.out.resolve()
            output.mkdir()
        print(f"POL69 OUTPUT: {output}", flush=True)
        before = collect(release, output / "before", args.dry_run)
        after = collect(WORKTREE, output / "after", args.dry_run, expected_enemy_icon=True)
        first = json.loads(before.read_text())["shots"][0]
        last = json.loads(after.read_text())["shots"][0]
        if len(first["layout_hits"]) != 4 or last["layout_hits"]:
            raise ValueError("Expected four release branch-header hits and zero updated hits")
        if args.dry_run:
            return int(compare(before, after, set(SHOT_EXCLUSIONS)))
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
