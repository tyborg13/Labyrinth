"""Render candidate attribution and compare matched native draws."""

from __future__ import annotations

import json
import math
from pathlib import Path

COUNTERS = ("canvas", "mesh", "surface", "draw", "specialization")
ACTIONS = ("title_new_a", "title_continue_a", "combat_first_a", "combat_pass_y")
CONFIG = ("seed", "cel_look", "viewport", "backing_size", "ui_scale", "edge_smoothing", "renderer", "method",
          "gpu", "api", "cpu", "godot", "input_edges")
DIAGNOSTIC_FRAMES = 12


def take(directory: Path, mode: str) -> tuple[dict, list[dict]]:
    data = json.loads((directory / "probe.json").read_text())
    if (data["mode"] != mode or data["cel_look"] != "all" or data["ui_scale"] != 1.0
            or data["backing_size"] != "(1920, 1080)" or data["method"] != "mobile"):
        raise ValueError(f"Unexpected {mode} configuration in {directory}")
    frames = [json.loads(line) for line in (directory / "frames.jsonl").read_text().splitlines()]
    if not frames or any(set(frame["compilations"]) != set(COUNTERS) for frame in frames):
        raise ValueError(f"Missing native counter data in {directory}")
    return data, frames


def affected_frames(data: dict, frames: list[dict], action: str) -> list[dict]:
    start = data["marks"][action]
    rendered = [frame for frame in frames if frame["frame"] >= start][:data["action_frames"]]
    if len(rendered) != DIAGNOSTIC_FRAMES or rendered[0]["stage"] != action:
        raise ValueError(f"Incomplete draw window for {action}")
    return rendered


def attribution(directory: Path, mode: str = "attribution") -> None:
    data, frames = take(directory, mode)
    lines = [
        "# Visible canvas candidates and pipeline counters", "",
        f"Renderer: {data['method']}/{data['renderer']}. "
        "ms is the post-draw interval less measured observer CPU. Visibility is an "
        "approximation for custom draw, culling, offscreen targets and renderer-generated passes.",
        "RID identifiers are process-local. Inline program hashes are comparable across processes.",
        "Entries present in the previous frame are omitted, while *first* marks first visibility "
        "in this process. Global counter deltas cannot identify a particular RID.", "",
        "| Frame | Stage | ms | Canvas / Mesh / Surface / Draw / Specialization | New visible shaders, materials and canvas types |",
        "|---:|---|---:|---|---|",
    ]
    for frame in frames:
        first = {(item["viewport"], item["kind"], item.get("rid", item.get("canvas_item_type"))) for item in frame["first_seen"]}
        entries = []
        for item in frame["new_since_previous_draw"]:
            kind = item["kind"]
            key = (item["viewport"], kind, item.get("rid", item["canvas_item_type"]))
            label = item.get("name", item["canvas_item_type"]).replace("|", r"\|")
            rid = f" RID {item['rid']}" if "rid" in item else ""
            new = "*first* " if key in first else ""
            entries.append(f"{new}{kind} {label}{rid} at `{item['node']}`")
        counts = " / ".join(str(frame["compilations"][name]) for name in COUNTERS)
        lines.append(f"| {frame['frame']} | {frame['stage']} | {frame['ms']:.3f} | {counts} | {'<br>'.join(entries)} |")
    (directory / "attribution.md").write_text("\n".join(lines) + "\n")


def _stats(values: list[float]) -> tuple[float, float]:
    sorted_values = sorted(values)
    return sorted_values[math.ceil(0.99 * len(sorted_values)) - 1], sorted_values[-1]


def _total(rows: list[dict]) -> int:
    return sum(sum(row["compilations"].values()) for row in rows)


def compare(pairs: list[tuple[Path, Path]], profile: str, output: Path) -> bool:
    lines = [
        f"# Native action timing ({profile})", "",
        "The primary metric is the first native post-draw interval after the controller activation edge, "
        "one draw per take. The twelve-draw context can include work shifted into the cover. "
        "Timing takes disable the CanvasItem scan. p99 uses nearest rank, so with five first "
        "draws it equals max. Focus is required throughout each measured window.", "",
        "| Action | Base → candidate first draw ms, each pair | Base p99 / max | Candidate p99 / max | First-draw pipelines base → candidate | 12-draw pipelines base → candidate | 12-draw base → candidate p99 / max (ms) |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    captures = [(take(base, "timing"), take(candidate, "timing")) for base, candidate in pairs]
    config = tuple(captures[0][0][0][key] for key in CONFIG)
    for pair in captures:
        for metadata, _ in pair:
            if tuple(metadata[key] for key in CONFIG) != config:
                raise ValueError("Mismatched native timing configuration")
    passed = True
    for action in ACTIONS:
        a, b = [], []
        for (a_metadata, a_frames), (b_metadata, b_frames) in captures:
            a.append(affected_frames(a_metadata, a_frames, action))
            b.append(affected_frames(b_metadata, b_frames, action))
        a_context = [row for window in a for row in window]
        b_context = [row for window in b for row in window]
        if not all(frame["focused"] for frame in a_context + b_context):
            raise ValueError(f"Window lost focus during {action}")
        a_first = [window[0] for window in a]
        b_first = [window[0] for window in b]
        base_stats = _stats([row["ms"] for row in a_first])
        candidate_stats = _stats([row["ms"] for row in b_first])
        contexts = ["/".join(f"{v:.3f}" for v in _stats([row["ms"] for row in rows])) for rows in (a_context, b_context)]
        raw_pairs = ", ".join(f"{left['ms']:.3f}→{right['ms']:.3f}" for left, right in zip(a_first, b_first))
        lines.append(
            f"| {action} | {raw_pairs} | {base_stats[0]:.3f} / {base_stats[1]:.3f} | "
            f"{candidate_stats[0]:.3f} / {candidate_stats[1]:.3f} | "
            f"{_total(a_first)} → {_total(b_first)} | {_total(a_context)} → {_total(b_context)} | "
            f"{' → '.join(contexts)} |"
        )
        multiplier = 0.6 if profile == "background" else 1.0
        passed &= all(candidate <= base * multiplier for base, candidate in zip(base_stats, candidate_stats))
        if profile == "background":
            # Follow-up title frames are cover work. Check the full first-action
            # context for combat where all twelve draws are outside the covers.
            passed &= _total(b_first if action.startswith("title_") else b_context) == 0
    lines.extend(["", "| Context | Base | Candidate |", "|---|---:|---:|"])
    for action in ("title_new_a", "title_continue_a"):
        cover_max = []
        for side in (0, 1):
            cover_max.append(max(sum(row["raw_ms"] for row in pair[side][1]
                                     if row["stage"] == action and row["loading_cover"]) for pair in captures))
        lines.append(f"| {action} maximum cover wall time (ms) | {cover_max[0]:.3f} | {cover_max[1]:.3f} |")
    resolution = [_total([row for pair in captures for row in pair[side][1]
                          if row["stage"] == "combat_card_resolution"]) for side in (0, 1)]
    lines.append(f"| First card resolution pipelines | {resolution[0]} | {resolution[1]} |")
    if profile == "background":
        passed &= resolution[1] == 0
    lines.extend(["", f"Automatic thresholds: {'PASS' if passed else 'REVIEW'}",
                  "For remaining compilations, inspect the matching attribution table and record "
                  "the program or renderer variant and the observed reason."])
    output.write_text("\n".join(lines) + "\n")
    return passed
