#!/usr/bin/env python3
"""atk-07 frozen-turn audit driver and report (proof tool, stdlib only).

Runs tools/atk07/audit.gd (the atk-01 audit whose real resolution continues
through any hero turn Freeze skips) one Godot process at a time, then reports
the decision points whose real span skipped a turn, beside all checks.

  python3 tools/atk07/audit.py run --seeds 101 --health 9999 --label before
  python3 tools/atk07/audit.py report --label before
  python3 tools/atk07/audit.py compare --before before --after after
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]
ROOT = Path("/private/tmp/labyrinth_codex/atk-07/audit")
MEASURES = ("hp", "block", "stoneskin", "death", "tile", "sources")


def run(args: argparse.Namespace) -> None:
    out = ROOT / args.label
    out.mkdir(parents=True, exist_ok=True)
    project = Path(args.project) if args.project else PROJECT
    for seed in args.seeds:
        directory = out / (f"seed-{seed}-hp{args.health}" + (f"-warband-{args.warband.replace(':', '-')}" if args.warband else ""))
        if (directory / "samples.jsonl").exists() and not args.force:
            print(f"skip {directory} (exists)")
            continue
        directory.mkdir(parents=True, exist_ok=True)
        command = [sys.executable, str(project / "tools/godot_task_runner.py"), "--project", str(project), "--task-id", f"atk-07-audit-{args.label}-{seed}", "--timeout", str(args.timeout), "--",
                   "godot", "--headless", "--path", ".", "--script", "res://tools/atk07/audit.gd", "--",
                   "--seed", str(seed), "--output-dir", str(directory), "--no-embrace", "true", "--health", str(args.health)]
        if args.stop_after:
            command += ["--stop-after", str(args.stop_after)]
        started = time.time()
        env = dict(os.environ, ATK01_WARBAND=args.warband) if args.warband else None
        with open(directory / "godot.log", "w") as log:
            code = subprocess.call(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, env=env)
        print(f"seed {seed} health {args.health}: exit {code} in {time.time() - started:.0f}s")


def load(label: str) -> tuple[list[dict], list[dict]]:
    checks, flags = [], []
    for path in sorted((ROOT / label).glob("seed-*/samples.jsonl")):
        for line in path.read_text().splitlines():
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            row["_run"] = path.parent.name
            if row.get("kind") == "check":
                checks.append(row)
            elif row.get("kind") == "flags":
                flags.append(row)
    return checks, flags


def pct(n: int, d: int) -> str:
    return f"{100.0 * n / d:.1f}%" if d else "n/a"


def stats(checks: list[dict], flags: list[dict]) -> dict:
    frozen = [r for r in checks if r.get("frozen_actual", 0) > 0]
    skipped = [r for r in checks if r.get("skipped_forecast", 0) > 0]
    rows = {}
    for mode in ("pass", "move", "stay", "all"):
        subset = [r for r in frozen if (mode == "all" or r["mode"] == mode) and r.get("resolved", True)]
        rows[mode] = {"checks": len(subset)}
        for measure in MEASURES:
            bad = [r for r in subset if r["mismatch"][measure]]
            rows[mode][measure] = {"mismatches": len(bad), "undisclosed": sum(1 for r in bad if not r["disclosed"])}
    # What the panel said against the whole span (Health row incl. Fatigue, and death).
    under = [r["actual"]["hp"] - r["shown"]["hp"] for r in frozen if r["actual"]["hp"] > r["shown"]["hp"]]
    deaths = [r for r in frozen if r["actual"]["outcome"] == "defeat"]
    pass_points = {(r["_run"], r["point"]): r for r in checks if r["mode"] == "pass"}
    disc_rows = []
    for row in flags:
        p = pass_points.get((row["_run"], row["point"]))
        if p is None or p.get("frozen_actual", 0) <= 0:
            continue
        applied = {d["key"]: d for d in p.get("discs", [])}
        # Hits only after the skipped turn: the foe's slices after the first turn_start.
        slices = p["actual"]["slices"]
        first_start = next((i for i, s in enumerate(slices) if s["actor"] == "turn_start"), len(slices))
        for f in row["flags"]:
            key = f["key"]
            early = sum(s["hp"] + s["block"] + s["stoneskin"] for s in slices[:first_start] if s["actor"] == key)
            late = sum(s["hp"] + s["block"] + s["stoneskin"] for s in slices[first_start:] if s["actor"] == key)
            d = applied.get(key, {})
            disc_rows.append({"key": key, "type": f["type"], "danger": d.get("danger", f["danger"]), "repeats": d.get("repeats", 0), "acts": f["activations"], "early_hit": early > 0, "late_only_hit": early == 0 and late > 0, "point": p["point"]})
    usec = sorted(r["ui_usec"] for r in checks)
    return {
        "checks": len(checks), "frozen_checks": len(frozen), "frozen_points": len({(r["_run"], r["point"]) for r in frozen}),
        "frozen_by_mode": dict(Counter(r["mode"] for r in frozen)), "skipped_forecast_checks": len(skipped),
        "skipped_vs_actual": dict(Counter(f"{r.get('skipped_forecast', 0)}/{r.get('frozen_actual', 0)}" for r in checks if r.get("frozen_actual", 0) or r.get("skipped_forecast", 0))),
        "rates": rows, "panel_under_by": {"count": len(under), "mean": round(sum(under) / len(under), 1) if under else 0, "max": max(under or [0])},
        "deaths_in_span": len(deaths), "death_shown": sum(1 for r in deaths if r["shown"]["defeat"]),
        "discs": {"total": len(disc_rows), "late_only_hit": sum(1 for d in disc_rows if d["late_only_hit"]), "late_only_hit_red": sum(1 for d in disc_rows if d["late_only_hit"] and d["danger"]),
                  "red_and_hit": sum(1 for d in disc_rows if d["danger"] and (d["early_hit"] or d["late_only_hit"])), "grey_and_hit": sum(1 for d in disc_rows if not d["danger"] and (d["early_hit"] or d["late_only_hit"])),
                  "red_no_hit": sum(1 for d in disc_rows if d["danger"] and not d["early_hit"] and not d["late_only_hit"]), "pips": dict(Counter(f"{d['repeats']}/{d['acts']}" for d in disc_rows))},
        "ui_usec": {"median": usec[len(usec) // 2] if usec else 0, "p95": usec[int(len(usec) * 0.95)] if usec else 0},
        "examples": [{"run": r["_run"], "point": r["point"], "mode": r["mode"], "tile": r["tile"], "room": r["context"]["room"], "kind": r["context"]["room_kind"], "turn": r["context"]["turn"], "hero": r["context"]["hero_tile"],
                      "shown": {k: r["shown"][k] for k in ("hp", "block", "defeat")}, "actual": {k: r["actual"][k] for k in ("hp", "block", "outcome")}, "skipped": r.get("skipped_forecast", 0), "frozen": r.get("frozen_actual", 0), "disclosed": r["disclosed"], "repro": r.get("repro", "")}
                     for r in frozen if r["mode"] == "pass"][:12],
    }


def report(args: argparse.Namespace) -> None:
    checks, flags = load(args.label)
    data = stats(checks, flags)
    print(json.dumps(data, indent=2))
    (ROOT / args.label / "frozen_summary.json").write_text(json.dumps(data, indent=2) + "\n")


def compare(args: argparse.Namespace) -> None:
    b = stats(*load(args.before))
    a = stats(*load(args.after))
    print(f"frozen-turn checks: {b['frozen_checks']} ({b['frozen_points']} points) -> {a['frozen_checks']} ({a['frozen_points']} points)")
    print("| Mode | Checks | Health wrong (undisclosed) | Death wrong (undisclosed) | Block wrong | Final tile wrong | Foes that hit wrong |")
    print("|---|---|---|---|---|---|---|")
    for mode in ("pass", "move", "stay", "all"):
        rb, ra = b["rates"][mode], a["rates"][mode]
        def cell(r: dict, m: str) -> str:
            return f"{r[m]['mismatches']} ({r[m]['undisclosed']})"
        print(f"| {mode} | {rb['checks']} → {ra['checks']} | {cell(rb, 'hp')} → {cell(ra, 'hp')} | {cell(rb, 'death')} → {cell(ra, 'death')} | {cell(rb, 'block')} → {cell(ra, 'block')} | {cell(rb, 'tile')} → {cell(ra, 'tile')} | {cell(rb, 'sources')} → {cell(ra, 'sources')} |")
    for name, d in (("before", b), ("after", a)):
        print(f"{name}: panel under by {d['panel_under_by']}, deaths in span {d['deaths_in_span']} (panel said death {d['death_shown']}), skipped/actual {d['skipped_vs_actual']}, discs {d['discs']}, ui_usec {d['ui_usec']}")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    r = sub.add_parser("run")
    r.add_argument("--seeds", type=int, nargs="+", required=True)
    r.add_argument("--health", type=int, default=9999)
    r.add_argument("--label", default="before")
    r.add_argument("--stop-after", type=int, default=0)
    r.add_argument("--timeout", type=float, default=5400)
    r.add_argument("--force", action="store_true")
    r.add_argument("--warband", default="")
    r.add_argument("--project", default="")
    p = sub.add_parser("report")
    p.add_argument("--label", default="before")
    c = sub.add_parser("compare")
    c.add_argument("--before", default="before")
    c.add_argument("--after", default="after")
    args = parser.parse_args()
    {"run": run, "report": report, "compare": compare}[args.command](args)


if __name__ == "__main__":
    main()
