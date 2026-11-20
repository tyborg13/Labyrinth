#!/usr/bin/env python3
"""Run perf-158's paired native timing, exact-pixel proof or headless replay."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from report import WINDOWS, timing_report

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools" / "hitch_census"))
from census import SOURCE_FOLDERS, clone, write_window_override

TASK = "perf-158"
BASE_HEAD = "fab6afc2a040416b79d2607e153f67cec730e909"
PAIR_COUNT = 5
FOCUS_RETRIES = 3
RUN_TIMEOUT_SECONDS = 210
PROFILES = ("normal", "background")
REPLAY = "res://tools/perf158/replay.gd"
DECK_ENV = {
    "LABYRINTH_CEL_LOOK": "all",
    "LABYRINTH_DEMO": "1",
    "LABYRINTH_DISABLE_STEAM": "1",
    "LABYRINTH_PROBE_WINDOW": "1",
    "SteamDeck": "1",
}


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def stage_project(destination, *, baseline):
    """Restore pinned blobs in a disposable project with a private import cache."""
    source_names = (*SOURCE_FOLDERS, "project.godot", "cel_look_variants")
    changes = {}
    if baseline:
        diff = git("diff", "--name-status", "--no-renames", "-z", BASE_HEAD, "--", *source_names).decode()
        pairs = diff.rstrip("\0").split("\0")
        changes = {Path(name): state for state, name in zip(pairs[::2], pairs[1::2])}
        untracked = git("ls-files", "--others", "--exclude-standard", "-z", "--", *source_names)
        for name in untracked.decode().split("\0"):
            if name:
                changes.setdefault(Path(name), "A")
    # Both projects get the same standalone replay and UID, including on base.
    for filename in ("replay.gd", "replay.gd.uid"):
        changes[Path("tools/perf158") / filename] = "probe"
    ancestors = {parent for path in changes for parent in path.parents}

    def stage(relative):
        target = destination / relative
        source = ROOT / relative
        status = changes.get(relative)
        if status == "probe":
            shutil.copyfile(source, target)
        elif status == "A":
            return
        elif status:
            target.write_bytes(git("show", f"{BASE_HEAD}:{relative.as_posix()}"))
        elif relative in ancestors:
            target.mkdir()
            children = {entry.name for entry in source.iterdir()} if source.is_dir() else set()
            children.update(path.name for path in (changes.keys() | ancestors) if path.parent == relative)
            for name in sorted(children):
                stage(relative / name)
        elif source.exists():
            target.symlink_to(source, target_is_directory=source.is_dir())

    destination.mkdir(parents=True)
    for name in source_names:
        stage(Path(name))
    clone(ROOT / ".godot", destination / ".godot")
    write_window_override(destination)
    return destination


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def run_take(project, take, mode, profile):
    take.mkdir()
    native = mode != "smoke"
    capture = mode == "visual"
    settings = {**DECK_ENV, "LABYRINTH_HITCH_TRACE": "0" if capture else "1"}
    if capture:
        command = [
            sys.executable, str(ROOT / "tools/visual_probe_runner.py"), "--project", str(project),
            "--task-id", TASK, "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--rendering-method", "mobile", "--rendering-driver", "metal", "--timeout", str(RUN_TIMEOUT_SECONDS),
            "--expect-size", "1920x1080", "--proof-contract", str(HERE / "proof.json"),
            "--result-manifest", str(take / "images.json"), REPLAY, "--", "--capture",
        ]
    else:
        qos = ["/usr/sbin/taskpolicy", "-c", "background"] if profile == "background" else []
        display = ["--headless"] if not native else [
            "--display-driver", "macos", "--rendering-method", "mobile", "--rendering-driver", "metal",
            "--audio-driver", "Dummy", "--windowed", "--resolution", "1280x800", "--position", "24,24",
        ]
        command = [
            *qos, sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--project", str(project),
            "--task-id", TASK, "--timeout", str(RUN_TIMEOUT_SECONDS), "--stream", "--",
            "godot", *display, "--path", str(project), "--script", REPLAY, "--",
        ]
        if not native:
            command.extend(["--headless-smoke", "--capture-geometry-smoke"])
    command.append(f"--output={take}")
    write_json(take / "command.json", {"command": command, "env": settings})
    with (take / "godot.log").open("w") as log:
        result = subprocess.run(command, cwd=ROOT, env={**os.environ, **settings},
                                stdout=log, stderr=subprocess.STDOUT)
    path = take / "receipt.json"
    receipt = json.loads(path.read_text()) if path.is_file() else {}
    unfocused = receipt.get("trace", {}).get("unfocused_frames", 0)
    if native and (unfocused or receipt.get("outcome") == "focus_lost"):
        return unfocused
    if (result.returncode or receipt.get("outcome") != "first_pre_battle" or receipt.get("errors")
            or not (take / "windows.json").is_file()):
        raise RuntimeError(f"Replay failed. See {take / 'godot.log'}")
    print(f"PERF158 PASS {take}", flush=True)
    return None


def focused_take(project, target, mode, profile, audit):
    for retry in range(FOCUS_RETRIES + 1):
        attempt = target if retry == 0 else target.with_name(f"{target.name}-retry-{retry}")
        unfocused = run_take(project, attempt, mode, profile)
        if unfocused is None:
            audit["accepted"][target.name] = str(attempt)
            return attempt
        audit["discarded"].append({"take": target.name, "path": str(attempt), "unfocused_frames": unfocused})
        print(f"PERF158 DISCARD focus_lost unfocused_frames={unfocused} {attempt}", flush=True)
    raise RuntimeError(f"Focus retries exhausted for {target.name}")


def compare_pixels(paths):
    receipts = {key: json.loads((path / "windows.json").read_text()) for key, path in paths.items()}
    success = True
    for name in WINDOWS:
        before, after = receipts["base"][name], receipts["candidate"][name]
        fields = ("pixel_sha256", "room", "mode", "destination", "preview")
        same = bool(before.get("pixel_sha256")) and all(before.get(field) == after.get(field) for field in fields)
        print(f"PERF158 PIXELS {name}: {'IDENTICAL' if same else 'DIFFERENT'} "
              f"{before.get('pixel_sha256')} → {after.get('pixel_sha256')}")
        success &= same
    return success


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("timing", "visual", "smoke"))
    parser.add_argument("--profile", choices=PROFILES, default="normal")
    parser.add_argument("--pairs", type=int, default=PAIR_COUNT)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.mode == "timing" and args.pairs < PAIR_COUNT:
        parser.error("native timing requires at least five matched pairs")
    if args.mode != "timing" and args.profile != "normal":
        parser.error("background QoS applies to native timing")
    if not (ROOT / ".godot/imported").is_dir() or not (ROOT / "cel_look_variants/manifest.json").is_file():
        parser.error("the comparison requires warm import and cel caches")
    output = args.output.resolve()
    if output.is_relative_to(ROOT / ".godot"):
        parser.error("choose an output outside the import cache")
    output.mkdir(parents=True)
    projects = {role: stage_project(output / "projects" / role, baseline=(role == "base"))
                for role in ("base", "candidate")}
    order = ("base", "candidate")
    pairs = args.pairs if args.mode == "timing" else 1
    write_json(output / "inputs.json", {
        "base": BASE_HEAD,
        "candidate_head": git("rev-parse", "HEAD").decode().strip(),
        "candidate_source": str(ROOT),
        "profile": args.profile,
        "arm_order": "".join("A" if role == "base" else "B"
                             for pair in range(pairs) for role in (order if pair % 2 == 0 else order[::-1])),
    })
    audit = {"discarded": [], "accepted": {}}
    takes = []
    try:
        for pair in range(1, pairs + 1):
            paths = {role: focused_take(projects[role], output / f"{pair:02d}-{role}", args.mode, args.profile, audit)
                     for role in (order if pair % 2 else order[::-1])}
            if args.mode == "visual":
                return 0 if compare_pixels(paths) else 1
            takes.append((pair, paths["base"], paths["candidate"]))
    finally:
        write_json(output / "focus.json", audit)
    report = output / "timing.md"
    accepted = timing_report(takes, report, args.profile, args.mode == "timing")
    print(f"PERF158 {'NATIVE' if args.mode == 'timing' else 'HEADLESS'} REPORT {report}")
    return 0 if accepted else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as error:
        sys.exit(str(error))
