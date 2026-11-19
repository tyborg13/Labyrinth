"""Chapter and timing reports for the same native take that supplied the movie."""
from __future__ import annotations

import json
from pathlib import Path

TOP_SECTIONS = 10
CLOCK = "monotonic_process_frame_including_movie_writer"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def summarize(directory: Path) -> dict:
    intervals = read_json(directory / "frame-cohorts.json")
    if intervals["clock"] != CLOCK or intervals["threshold_usec"] != 33_000:
        raise ValueError(f"{directory}: incompatible capture clock or threshold")
    route = read_json(directory / "route.json")
    identity = {
        "clock": intervals["clock"],
        "fps": route["fps"],
        "resolution": route["resolution"],
        "ui_scale": route["ui_scale"],
        "seed": route["seed"],
        "dry_run": route["dry_run"],
    }
    files = sorted((directory / "telemetry").glob("performance-*.jsonl"))
    windows = []
    for path in files:
        for line in path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            if row.get("event_type") == "performance_window":
                windows.append(row)
    if not windows or len({row["session_id"] for row in windows}) != 1:
        raise ValueError(f"{directory}: expected performance windows from one session")

    samples: dict[str, int] = {}
    sections: dict[str, int] = {}
    for window in windows:
        for cohort, timing in window["frame_cohorts"].items():
            samples[cohort] = samples.get(cohort, 0) + timing["frame_interval_ms"]["sample_count"]
        for section, timing in window["sections"].items():
            sections[section] = max(sections.get(section, 0), timing["max_usec"])

    cohorts = intervals["cohorts"]
    if not cohorts or not sections or samples != {name: row["samples"] for name, row in cohorts.items()}:
        raise ValueError(f"{directory}: capture and production samples disagree, or sections are missing")
    device = windows[0]["device"]
    return {
        "identity": identity,
        "device": {key: device.get(key) for key in ("os", "model", "renderer", "rendering_method")},
        "cohorts": cohorts,
        "sections": sections,
        "windows": len(windows),
        "discarded_intervals": intervals["discarded_intervals"],
    }


def _frame_cell(row: dict | None) -> str:
    if row is None:
        return "—"
    count, total = row["over_33_ms"], row["samples"]
    return f"{count} / {total} ({count / total:.1%})"


def _section_cell(usec: int | None) -> str:
    return "—" if usec is None else f"{usec / 1000:.3f}"


def write_timing(directory: Path, compare: Path | None) -> dict:
    current = summarize(directory)
    baseline = summarize(compare) if compare else None
    if baseline and current["identity"] != baseline["identity"]:
        raise ValueError("Comparison must use the same route seed, viewport, FPS, mode and timing clock")

    lines = [
        "# Recording timing",
        "",
        "Frame intervals use the monotonic clock between Godot process frames. "
        "They include Movie Maker capture, disk writes, and scripted input overhead. "
        "Section maxima use the game's own instrumentation.",
        "",
        f"Production performance windows **{current['windows']}**. "
        f"Intervals above the sampler's 2-second limit **{current['discarded_intervals']}**.",
    ]
    if baseline:
        lines += ["", f"Previous recording `{compare}`."]
        if baseline["device"] != current["device"]:
            lines += ["", f"Current renderer and host `{current['device']}`. Previous `{baseline['device']}`."]

    lines += ["", "## Frames over 33 ms", "", "Each row shows the count, sample total, and percentage. "
              "A frame can belong to more than one cohort.", ""]
    baseline_cohorts = baseline["cohorts"] if baseline else {}
    if baseline:
        lines += ["| Cohort | Current | Previous | Change in share |", "| --- | ---: | ---: | ---: |"]
    else:
        lines += ["| Cohort | Current |", "| --- | ---: |"]
    for name in sorted(current["cohorts"].keys() | baseline_cohorts.keys()):
        row, previous = current["cohorts"].get(name), baseline_cohorts.get(name)
        cells = [name, _frame_cell(row)]
        if baseline:
            delta = (
                100 * (row["over_33_ms"] / row["samples"] - previous["over_33_ms"] / previous["samples"])
                if row is not None and previous is not None else None
            )
            cells += [_frame_cell(previous), "—" if delta is None else f"{delta:+.1f} pp"]
        lines.append("| " + " | ".join(cells) + " |")

    lines += ["", "## Top 10 sections by current max", ""]
    if baseline:
        lines += ["| Section | Current max (ms) | Previous max (ms) | Change (ms) |", "| --- | ---: | ---: | ---: |"]
    else:
        lines += ["| Section | Max (ms) |", "| --- | ---: |"]
    ranked = sorted(current["sections"].items(), key=lambda row: (-row[1], row[0]))[:TOP_SECTIONS]
    for name, maximum in ranked:
        cells = [name, _section_cell(maximum)]
        if baseline:
            previous = baseline["sections"].get(name)
            cells += [_section_cell(previous), "—" if previous is None else f"{(maximum - previous) / 1000:+.3f}"]
        lines.append("| " + " | ".join(cells) + " |")
    (directory / "timing.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return current
