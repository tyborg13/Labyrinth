#!/usr/bin/env python3
"""Run isolated native Godot takes through the visual probe runner."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from native_report import attribution, compare, take

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parents[1]
sys.path.insert(0, str(CANDIDATE / "tools"))
from visual_probe_runner import decode_png  # noqa: E402

PAIR_COUNT = 5
PROFILES = ("normal", "background")
CAPTURES = ("title", "loading_cover", "first_fight")
RUN_TIMEOUT_SECONDS = 145
STARTUP_TIMEOUT_SECONDS = 15


def command(project: Path, output: Path, profile: str, renderer: str, mode: str) -> list[str]:
    result = ["/usr/sbin/taskpolicy", "-c", "background"] if profile == "background" else []
    result += [
        sys.executable, str(CANDIDATE / "tools/visual_probe_runner.py"),
        "--project", str(project), "--task-id", "perf-165", "--no-headless",
        "--display-driver", "macos", "--audio-driver", "Dummy",
        "--rendering-method", "mobile", "--rendering-driver", renderer,
        "--timeout", str(RUN_TIMEOUT_SECONDS),
        "--startup-timeout", str(STARTUP_TIMEOUT_SECONDS),
        "--result-manifest", str(output / "manifest.json"),
    ]
    if mode == "pixels":
        # Only pixels mode emits PNGs; the runner checks --expect-size even with --min-images 0.
        result += ["--expect-size", "1920x1080", "--proof-contract", str(HERE / "proof.json")]
    else:
        result += ["--min-images", "0"]
    return result + [str(HERE / "probe.gd"), "--", f"--mode={mode}", f"--output={output}"]


def run(project: Path, output: Path, profile: str, renderer: str, mode: str) -> None:
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all", LABYRINTH_DEMO="1", SteamDeck="1", LABYRINTH_PROBE_WINDOW="1")
    args = command(project, output, profile, renderer, mode)
    print(f"perf-165 {profile} {mode}: {project} → {output}", flush=True)
    with (output / "runner.log").open("w") as log:
        result = subprocess.run(args, cwd=CANDIDATE, env=env, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"Visual runner exited {result.returncode}: {output / 'runner.log'}")


def strict_pixels(base: Path, candidate: Path, output: Path) -> bool:
    results = []
    for name in CAPTURES:
        left, right = (decode_png(directory / f"{name}.png") for directory in (base, candidate))
        same_format = all(left[key] == right[key] for key in ("width", "height", "color_type", "channels"))
        if not same_format:
            results.append(f"{name}: FAIL (decoded image formats differ)")
            continue
        channels = left["channels"]
        changed = sum(
            a[x:x + channels] != b[x:x + channels]
            for a, b in zip(left["rows"], right["rows"])
            if a != b
            for x in range(0, len(a), channels)
        )
        results.append(f"{name}: {'PASS' if changed == 0 else 'FAIL'} ({changed} changed pixels)")
    text = "\n".join(results) + "\n"
    output.write_text(text)
    print(text, end="")
    return all(": PASS " in line for line in results)


def check_cache(directory: Path, renderer: str) -> bool:
    data, frames = take(directory, "cache")
    switch = data["cache_switch"]
    before, after = Path(switch["before"]), Path(switch["after"])
    folders = ("shader_cache", "vulkan", "metal")
    shared = all(
        switch["folders"][folder]["linked"] and switch["folders"][folder]["shared"]
        and (before / folder).samefile(after / folder)
        for folder in folders
    )
    files = data["idle_cache_files"]
    new_files = sorted(set(files["after"]) - set(files["before"]))
    persisted = [name for name in new_files if (before / name).is_file() and (before / name).samefile(after / name)]
    canvas_deltas = [
        row for row in frames
        if row["stage"] == "title_new_idle" and row["compilations"]["canvas"] > 0
        and any("CanvasPipelinePrewarm" in item["node"] for item in row["new_since_previous_draw"])
    ]
    rd_files = sorted(path.name for path in (before / "vulkan").glob("pipelines.*.cache") if path.stat().st_size)
    saved_log = (directory / "runner.log").read_text()
    save_error = "_save_to_cache" in saved_log
    passed = shared and bool(persisted) and bool(canvas_deltas) and not save_error
    if renderer == "vulkan":
        passed &= bool(rd_files)
    result = {
        "shared_cache_paths": shared, "new_shared_shader_files_at_title_idle": persisted,
        "idle_offscreen_canvas_compilation_frames": [row["frame"] for row in canvas_deltas],
        "rd_pipeline_cache_files": rd_files, "renderer": renderer, "cache_save_error": save_error, "passed": passed,
    }
    (directory / "cache.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PERF165 NATIVE CACHE: {'PASS' if passed else 'REVIEW'} ({directory / 'cache.json'})")
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("attribution", "pairs", "pixels", "cache"))
    parser.add_argument("--base", type=Path, help="Prepared, clean codex/release worktree")
    parser.add_argument("--output", type=Path, required=True, help="Fresh directory for all take artifacts")
    parser.add_argument("--renderer", default="metal", choices=("metal", "vulkan"))
    args = parser.parse_args()
    output = args.output.resolve()
    if args.mode == "cache":
        run(CANDIDATE, output, "normal", args.renderer, "cache")
        attribution(output, "cache")
        return 0 if check_cache(output, args.renderer) else 1
    if args.base is None:
        parser.error("--base is required for base/candidate comparisons")
    base = args.base.resolve()
    if base == CANDIDATE or not (base / "project.godot").is_file():
        parser.error("--base must be a distinct prepared Labyrinth worktree")
    output.mkdir(parents=True, exist_ok=False)
    projects = {"base": base, "candidate": CANDIDATE}
    if args.mode == "pixels":
        for side, project in projects.items():
            run(project, output / side, "normal", args.renderer, "pixels")
        return 0 if strict_pixels(output / "base", output / "candidate", output / "pixels.txt") else 1
    passed = True
    for profile in PROFILES:
        if args.mode == "attribution":
            for side, project in projects.items():
                take = output / profile / side
                run(project, take, profile, args.renderer, "attribution")
                attribution(take)
        else:
            pairs = []
            for index in range(PAIR_COUNT):
                pair_dir = output / profile / f"pair-{index + 1:02d}"
                sides = list(projects) if index % 2 == 0 else list(reversed(projects))
                for side in sides:
                    run(projects[side], pair_dir / side, profile, args.renderer, "timing")
                pairs.append((pair_dir / "base", pair_dir / "candidate"))
            passed &= compare(pairs, profile, output / f"{profile}.md")
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as exc:
        sys.exit(f"perf-165: {exc}")
