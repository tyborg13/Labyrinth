#!/usr/bin/env python3
"""Log and compare boss-header geometry from a pol-65 census dry run."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import sys


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scn01"))
sys.dont_write_bytecode = True
import census


TASK = "pol-65"
CONFIGURATIONS = (("1280x800", "1.00"), ("1920x1080", "1.00"), ("1920x1080", "1.15"))
CLEARANCE = 24
NAME_SIDE_PADDING = 18
PIXEL_TOLERANCE = 0.02
RECTS = ("overlay", "name", "frame")


def measure(job, output, *, feedback=False):
    phase, (size, scale), shot = job
    project = census.PROJECT if phase == "after" else census.PROJECT.parent / "scn-02"
    fixture_log = Path(shot["fixture_log"]).read_text(encoding="utf-8")
    fixture = census.payload_line(fixture_log, "INSPECTION_FIXTURE_RESULT")
    profile = Path(fixture["progression_path"])
    log = output / f"{phase}-{size}-{scale}-{shot['shot']}.log"
    command = [
        sys.executable, "tools/godot_task_runner.py", "--task-id", TASK, "--stream",
        "--timeout", str(census.ENGINE_TIMEOUT), "--", "godot", "--headless",
        "--path", str(project), "--script", str(HERE / "measure.gd"), "--",
        fixture["save_path"], str(profile), str(profile.with_name("settings.json")), size, scale,
    ]
    if feedback:
        command.append("--feedback")
    status, text = census.capture_log(command, dict(os.environ, LABYRINTH_CEL_LOOK="all"), log)
    result = census.payload_line(text, "CENSUS_RESULT")
    if status or not result.get("ok") or any(error in text for error in census.SCRIPT_ERRORS):
        raise ValueError(f"Measurement failed. See {log}")
    return result


def compare(config, before, after):
    for key in ("stats_left", "buttons", "name_width", "name_text", "name_font_size", "viewport_size"):
        if before[key] != after[key]:
            raise ValueError(f"{key} changed between worktrees: {before[key]} → {after[key]}")
    if before["line_count"] != 1 or after["line_count"] != 1:
        raise ValueError("Boss name must remain one line")
    free = after["stats_left"] - after["title_right"] - 2 * CLEARANCE
    needed = after["name_width"] + 2 * NAME_SIDE_PADDING * after["pixel_scale"]
    prior_free = before["stats_left"] - before["title_right"] - 2 * CLEARANCE
    title_hidden = not after["title_children"]["RoomTitle"]["visible"]
    if title_hidden != (prior_free < needed):
        raise ValueError("Room title visibility does not match the span with the title present")
    if not title_hidden and before["title_right"] != after["title_right"]:
        raise ValueError("Visible title edge changed")
    stopped = free < needed
    authored = config == ("1920x1080", "1.00")
    if stopped or authored:
        if any(before[key] != after[key] for key in RECTS):
            raise ValueError("Expected the three legacy rects to remain identical")
    if stopped:
        return free, needed, "Stop"

    left, _, width, _ = after["overlay"]
    gap_left = left - after["title_right"]
    gap_right = after["stats_left"] - (left + width)
    if min(gap_left, gap_right) < CLEARANCE - PIXEL_TOLERANCE:
        raise ValueError(f"Expected {CLEARANCE}px clearance, got {gap_left:.2f}px and {gap_right:.2f}px")
    if not authored and abs(gap_left - gap_right) > PIXEL_TOLERANCE:
        raise ValueError(f"Expected a centered overlay, got gaps {gap_left:.2f}px and {gap_right:.2f}px")
    if abs(width - min(free, before["overlay"][2])) > PIXEL_TOLERANCE:
        raise ValueError(f"Unexpected overlay width {width:.2f}px")
    if after["name"][2] + PIXEL_TOLERANCE < after["name_width"]:
        raise ValueError("The boss name does not fit inside its label")
    return free, needed, "Preserved" if authored else "Fit"


def table(config, names, results):
    size, scale = config
    yield f"### {size.replace('x', '×')} · {round(float(scale) * 100)}%"
    yield ""
    yield "| Shot | Title hidden | Title right | Readout left | First button left | Overlay rect | Name rect | Frame rect | Free / needed | Result |"
    yield "| --- | --- | ---: | ---: | ---: | --- | --- | --- | ---: | --- |"

    def pair(first, second, formatter):
        return f"{formatter(first)} → {formatter(second)}"

    def number(value):
        return f"{value:.2f}"

    def rect(values):
        return "(" + ", ".join(map(number, values)) + ")"

    for name in names:
        before = results["before", config, name]
        after = results["after", config, name]
        try:
            free, needed, verdict = compare(config, before, after)
        except ValueError as error:
            raise ValueError(f"{name} at {size} and {scale}: {error}") from error
        cells = [
            f"`{name}`",
            "No" if after["title_children"]["RoomTitle"]["visible"] else "Yes",
            *[pair(before[key], after[key], number) for key in ("title_right", "stats_left")],
            pair(min(before["buttons"].values()), min(after["buttons"].values()), number),
            *[pair(before[key], after[key], rect) for key in RECTS],
            f"{free:.2f} / {needed:.2f}",
            verdict,
        ]
        yield "| " + " | ".join(cells) + " |"
    yield ""


def fixture_rows(manifest):
    value = json.loads(manifest.read_text(encoding="utf-8"))
    rows = value["shots"]
    if not value["dry_run"] or len(rows) != 7 or not all(row["ok"] for row in rows):
        raise ValueError(f"Expected seven successful dry-run shots in {manifest}")
    return rows


def measure_feedback(shots, output):
    output.mkdir(parents=True, exist_ok=True)
    jobs = [("after", config, shot) for config in CONFIGURATIONS for shot in shots]
    with ThreadPoolExecutor(max_workers=census.DRY_RUN_JOBS) as pool:
        rows = list(pool.map(lambda job: measure(job, output, feedback=True), jobs))
    report = output / "rects.json"
    census.write_json(report, [
        dict(size=config[0], scale=config[1], shot=shot["shot"], **row)
        for (_, config, shot), row in zip(jobs, rows)
    ])
    print(f"POL-65 FEEDBACK PROBE: {len(rows)}/{len(jobs)} captures recorded")
    print(f"Feedback measurements: {report}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("census_output", type=Path, help="Parent folder printed by native.sh --dry-run")
    parser.add_argument("--feedback-output", type=Path, help="Measure idle, restore and budget order in the current worktree")
    args = parser.parse_args()
    census_dir = args.census_output.resolve()
    if args.feedback_output is not None:
        measure_feedback(fixture_rows(census_dir / "after-1280x800" / "manifest.json"), args.feedback_output.resolve())
        return
    output = census_dir / "measurements"
    output.mkdir(exist_ok=True)
    fixtures = {
        phase: fixture_rows(census_dir / f"{phase}-1280x800" / "manifest.json")
        for phase in ("before", "after")
    }
    names = [shot["shot"] for shot in fixtures["before"]]
    jobs = [
        (phase, config, shot)
        for phase, shots in fixtures.items()
        for config in CONFIGURATIONS
        for shot in shots
    ]
    with ThreadPoolExecutor(max_workers=census.DRY_RUN_JOBS) as pool:
        rows = list(pool.map(lambda job: measure(job, output), jobs))
    results = {(phase, config, shot["shot"]): row for (phase, config, shot), row in zip(jobs, rows)}
    census.write_json(output / "rects.json", [
        dict(phase=phase, size=config[0], ui_scale=float(config[1]), shot=shot, **row)
        for (phase, config, shot), row in results.items()
    ])
    report = output / "rects.md"
    report.write_text(
        "\n".join(line for config in CONFIGURATIONS for line in table(config, names, results)),
        encoding="utf-8",
    )
    print(f"POL-65 RECT PROOF: PASS ({len(rows)} measurements, {len(rows) // 2} matched cases)")
    print(f"Rect table: {report}")


if __name__ == "__main__":
    main()
