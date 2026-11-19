#!/usr/bin/env python3
"""Summarize campaign and interruption receipts and render diagnostic stills."""

import argparse
from collections import Counter, defaultdict
from html import escape
import json
from pathlib import Path
import re

TERMINAL = {"victory", "defeat", "embrace"}
PATH_PREFIX = "QA110 PATH "
TILE = re.compile(r"\((-?\d+), (-?\d+)\)")
STILL_WIDTH = 1920
STILL_HEIGHT = 1080


def read_rows(path, prefix=""):
    with path.open() as stream:
        for line in stream:
            if not line.startswith(prefix):
                continue
            try:
                yield json.loads(line[len(prefix):])
            except json.JSONDecodeError:
                # The active writer may leave a partial final line.
                continue


def diagnostic_still(path, witness):
    """Render a labelled scene-state diagram from a Godot headless receipt."""
    context, issue = witness["context"], witness["issue"]
    subtitle = " · ".join(str(context[key]) for key in ("seed", "decision", "room_kind", "path") if key in context)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{STILL_WIDTH}" height="{STILL_HEIGHT}">',
        '<rect width="100%" height="100%" fill="#131820"/>',
        '<text x="70" y="85" fill="#fff" font-size="46" font-family="sans-serif">QA-110 · headless scene state</text>',
        f'<text x="70" y="140" fill="#ccd8e3" font-size="30" font-family="sans-serif">{escape(subtitle)}</text>',
    ]
    if issue.get("kind") == "tile_set":
        parts.extend(tile_diagram(issue))
    elif issue.get("kind") == "drag_survived_focus_loss" and issue.get("proxy_visible"):
        x, y, w, h = issue["proxy_rect"]
        parts.extend([
            '<text x="1240" y="215" fill="#fff" font-size="27" font-family="sans-serif">Held card proxy bounds</text>',
            '<rect x="1210" y="265" width="640" height="360" fill="none" stroke="#697684"/>',
            f'<rect x="{1210 + x / 3}" y="{265 + y / 3}" width="{w / 3}" height="{h / 3}" fill="#f36969"/>',
        ])
    fields = {
        "issue": issue,
        "ownership": {k: v for k, v in witness.get("ui", {}).items() if k != "alpha_exclusions"},
    }
    for idx, line in enumerate(json.dumps(fields, ensure_ascii=False, indent=2).splitlines()[:28]):
        parts.append(f'<text x="70" y="{220 + 27 * idx}" fill="#ccd8e3" font-size="21" font-family="monospace">{escape(line[:140])}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts) + "\n")


def tile_diagram(issue):
    result = ['<text x="1240" y="215" fill="#fff" font-size="27" font-family="sans-serif">Red tile comparison</text>']
    actual = set(issue.get("actual", {}))
    missing = set(issue.get("missing", []))
    extra = set(issue.get("extra", []))
    for tile in sorted(actual | missing):
        match = TILE.fullmatch(tile)
        if not match:
            continue
        x, y = (int(v) for v in match.groups())
        left, top = 1240 + x * 49, 265 + y * 49
        fill = "#ffe276" if tile in missing else "#f36969" if tile in extra else "#91333c"
        result.append(f'<rect x="{left}" y="{top}" width="44" height="44" fill="{fill}"/>')
    result.append('<text x="1240" y="1000" fill="#fff" font-size="20" font-family="sans-serif">Yellow missing · bright red extra · dark red both</text>')
    return result


def signature(invariant, issue):
    detail = issue["kind"]
    if invariant == "alpha":
        detail += "/" + issue["node"].rsplit("/", 1)[-1].split("@")[0]
    return f"{invariant}/{detail}"


def analyze(lanes, logs):
    result = {"runs": [], "paths": [], "checks": {}, "issues": {}, "room_growth": {}, "exclusions": {}}
    counts = defaultdict(Counter)
    by_room = defaultdict(list)

    def sample(row, lane):
        for name, check in row.get("checks", {}).items():
            counts[name]["sampled"] += 1
            counts[name]["flagged_boundaries"] += bool(check)
            counts[name]["flags"] += len(check)
            for issue in check:
                key = signature(name, issue)
                source_still = row.get("stills", {}).get(f"{name}/{issue['kind']}")
                record = result["issues"].setdefault(
                    key, {"count": 0, "first": {"context": row["context"], "issue": issue, "lane": lane}}
                )
                record["count"] += 1
                if "still" not in record:
                    if source_still and Path(source_still).is_file():
                        raw = json.loads(Path(source_still).read_text())
                        if signature(name, raw["issue"]) == key:
                            record["still"] = source_still
                    record.setdefault("witness", {"context": row["context"], "issue": issue, "ui": row.get("ui", {})})
        result["exclusions"].update(row.get("alpha_exclusions", {}))
        room = row.get("room_end")
        if room and lane != "interruptions":
            start, end = room["entry"]["count"], room["next"]
            before, after = room["entry"]["context"], room["next_context"]
            if start["scene"] == end["scene"]:
                by_room[before["room_kind"]].append({
                    "tree_delta": end["tree"] - start["tree"],
                    "orphan_delta": end["orphans"] - start["orphans"],
                    "before": before, "after": after,
                })

    for lane in lanes:
        for trace in sorted(lane.glob("seed-*/trace.jsonl")):
            run = {"lane": lane.name, "samples": 0, "unsettled": 0, "decisions": 0, "rooms": 0, "trace": str(trace)}
            for event in read_rows(trace):
                data = event["data"]
                kind = event["event"]
                if kind == "qa110_driver":
                    run["driver"] = data
                elif kind == "qa110_sample":
                    run["samples"] += 1
                    sample(data, lane.name)
                elif kind == "qa110_unsettled":
                    run["unsettled"] += 1
                elif kind == "decision":
                    run["decisions"] += 1
                elif kind == "room":
                    run["rooms"] += 1
                elif kind == "finish":
                    run.update(seed=data["seed"], outcome=data["outcome"], whole_run=data["outcome"] in TERMINAL)
            evidence = trace.with_name("evidence.json")
            if evidence.exists():
                run["runner_exit"] = json.loads(evidence.read_text())["returncode"]
            result["runs"].append(run)
    latest_paths = {}
    for log in logs:
        for row in read_rows(log, PATH_PREFIX):
            latest_paths[row["path"]] = (log, row)
    for log, row in latest_paths.values():
        sample(row, "interruptions")
        path_result = {key: row[key] for key in ("path", "status", "context", "before", "interruption") if key in row}
        path_result["source_log"] = str(log)
        result["paths"].append(path_result)
    result["checks"] = counts
    result["room_growth"] = by_room
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lane", action="append", type=Path, default=[])
    parser.add_argument("--interruptions", action="append", type=Path, default=[])
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    receipt = analyze(args.lane, args.interruptions)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, issue in receipt["issues"].items():
        witness = issue.pop("witness", issue["first"])
        if "still" in issue:
            witness = json.loads(Path(issue["still"]).read_text())
        path = args.out / (name.replace("/", "-") + ".svg")
        diagnostic_still(path, witness)
        issue["diagram"] = str(path)
    (args.out / "coverage.json").write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n")
    whole = sum(run.get("whole_run", False) for run in receipt["runs"])
    decisions = sum(run["decisions"] for run in receipt["runs"])
    settled = sum(run["samples"] for run in receipt["runs"])
    triggered = sum(row.get("interruption", {}).get("triggered", False) for row in receipt["paths"])
    print(f"QA110 COVERAGE whole_runs={whole}/{len(receipt['runs'])} decisions={decisions} settled={settled} interruption_triggers={triggered}/{len(receipt['paths'])}")


if __name__ == "__main__":
    main()
