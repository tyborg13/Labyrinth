#!/usr/bin/env python3
"""Import three validated native combat-feel runs into the owning specification."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics

SPEEDS = ("normal", "fast", "fastest")
CAPTURES = (
    "heavy_hit_minus_1.png", "heavy_hit_0.png", "heavy_hit_plus_1.png",
    "heavy_hit_plus_4.png", "heavy_hit_plus_8.png", "heavy_hit_post_stop_peak.png",
    "reduced_motion_hit.png", "combat_speed_settings.png",
)
START = "<!-- qa-01-native-measurements:start -->"
END = "<!-- qa-01-native-measurements:end -->"


def collect_runs(manifests: list[Path]) -> list[dict]:
    if len(manifests) != 3:
        raise ValueError("Three consecutive successful native manifests are required")
    runs = []
    namespaces = set()
    for path in manifests:
        manifest = json.loads(path.read_text())
        attempts = manifest.get("attempts", [])
        if (manifest.get("ok") is not True or len(attempts) != 1
                or attempts[0].get("accepted") is not True or attempts[0].get("returncode") != 0):
            raise ValueError(f"{path}: expected one accepted, successful attempt")
        if "--headless" in manifest.get("command", []) or manifest.get("script") != "tests/combat_feel_probe.gd":
            raise ValueError(f"{path}: not a native combat-feel probe")
        namespace = manifest.get("namespace")
        if not namespace or namespace in namespaces:
            raise ValueError("Native runs must have distinct namespaces")
        namespaces.add(namespace)
        images = {Path(item["path"]).name: item for item in manifest.get("images", [])}
        parents = set()
        for filename in CAPTURES:
            item = images.get(filename, {})
            image_path = Path(item.get("path", ""))
            if item.get("width") != 1920 or item.get("height") != 1080 or not image_path.is_file():
                raise ValueError(f"{path}: missing validated 1920x1080 capture {filename}")
            parents.add(image_path.parent)
        if len(parents) != 1:
            raise ValueError(f"{path}: captures must belong to the same run directory")
        directory = parents.pop()
        trace = json.loads((directory / "heavy_hit_trace.json").read_text())
        if trace.get("headless_scheduling") is not False or trace.get("captured_offsets") != [0, 1, 4, 8]:
            raise ValueError(f"{path}: missing native exact-offset trace")
        values = {}
        for speed in SPEEDS:
            timeline = json.loads((directory / f"timeline_{speed}.json").read_text())
            seconds = timeline.get("pass_to_hero_banner_seconds")
            if (timeline.get("renderer") is not True or timeline.get("speed") != speed
                    or not isinstance(seconds, (float, int)) or isinstance(seconds, bool)
                    or not math.isfinite(seconds) or seconds <= 0):
                raise ValueError(f"{path}: invalid native {speed} timeline")
            values[speed] = seconds
        runs.append({"manifest": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                     "namespace": namespace, "directory": str(directory), "seconds": values})
    return runs


def measurement_text(runs: list[dict]) -> str:
    lines = ["Native qa-01 measurements from three consecutive validated windowed runs",
             "at 1920×1080 / 100% UI scale, Pass to YOUR TURN:", "",
             "| Speed | Run 1 | Run 2 | Run 3 | Median |", "| --- | ---: | ---: | ---: | ---: |"]
    for speed in SPEEDS:
        samples = [run["seconds"][speed] for run in runs]
        cells = " | ".join(f"{seconds:.3f} s" for seconds in (*samples, statistics.median(samples)))
        lines.append(f"| {speed.capitalize()} | {cells} |")
    lines.extend(["", "All three probes passed the frame-offset, post-stop peak, resolver state/RNG",
                  "and Normal-round budget assertions. Source manifests (SHA256):", ""])
    for run in runs:
        lines.append(f'- `{run["manifest"]}` — `{run["sha256"]}`; captures/timelines: `{run["directory"]}`')
    return "\n".join(lines)


def update_spec(spec: Path, runs: list[dict]) -> None:
    content = spec.read_text()
    if content.count(START) != 1 or content.count(END) != 1:
        raise ValueError("Native measurement markers must occur exactly once")
    before, remaining = content.split(START)
    _, after = remaining.split(END)
    spec.write_text(before + START + "\n" + measurement_text(runs) + "\n" + END + after)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifests", nargs=3, type=Path, required=True)
    parser.add_argument("--spec", type=Path, default=Path(__file__).resolve().parents[1] / "spec/combat_feel.md")
    args = parser.parse_args()
    try:
        runs = collect_runs(args.manifests)
        update_spec(args.spec, runs)
    except (ValueError, OSError, KeyError) as exc:
        parser.exit(1, f"error: {exc}\n")
    print(measurement_text(runs))
    print("NATIVE COMBAT FEEL MEASUREMENTS: recorded three validated runs")


if __name__ == "__main__":
    main()
