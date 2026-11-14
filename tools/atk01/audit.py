#!/usr/bin/env python3
"""atk-01 forecast truth audit driver and report (proof tool, stdlib only).

Runs seeded audit hunts one Godot process at a time (headless), then measures
how often each forecast the UI shows disagrees with the real resolution. Never in
the default test groups.

  python3 tools/atk01/audit.py run --seeds 101 102 --health 9999 --label before
  python3 tools/atk01/audit.py report --label before
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
import os
from pathlib import Path
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]
ROOT = Path("/private/tmp/labyrinth_codex/atk-01/audit")
MEASURES = ("hp", "block", "stoneskin", "death", "tile", "sources")


def run(args: argparse.Namespace) -> None:
    out = ROOT / args.label
    out.mkdir(parents=True, exist_ok=True)
    for seed in args.seeds:
        directory = out / (f"seed-{seed}-hp{args.health}" + (f"-warband-{args.warband.replace(':', '-')}" if args.warband else ""))
        if (directory / "samples.jsonl").exists() and not args.force:
            print(f"skip {directory} (exists)")
            continue
        directory.mkdir(parents=True, exist_ok=True)
        project = Path(args.project) if args.project else PROJECT
        command = [sys.executable, str(project / "tools/godot_task_runner.py"), "--project", str(project), "--task-id", f"atk-01-audit-{args.label}-{seed}", "--timeout", str(args.timeout), "--",
                   "godot", "--headless", "--path", ".", "--script", "res://tools/atk01/audit.gd", "--",
                   "--seed", str(seed), "--output-dir", str(directory), "--no-embrace", "true", "--health", str(args.health)]
        if args.stop_after:
            command += ["--stop-after", str(args.stop_after)]
        started = time.time()
        env = dict(os.environ, ATK01_WARBAND=args.warband) if args.warband else None
        with open(directory / "godot.log", "w") as log:
            code = subprocess.call(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, env=env)
        print(f"seed {seed} health {args.health}: exit {code} in {time.time() - started:.0f}s")


def load(label: str) -> tuple[list[dict], list[dict], list[dict]]:
    checks, flags, totals = [], [], []
    for path in sorted((ROOT / label).glob("seed-*/samples.jsonl")):
        for line in path.read_text().splitlines():
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue  # a run still writing its last line
            row["_run"] = path.parent.name
            kind = row.get("kind")
            if kind == "check":
                checks.append(row)
            elif kind == "flags":
                flags.append(row)
            elif kind == "audit_totals":
                totals.append(row)
    return checks, flags, totals


def mismatched(row: dict) -> list[str]:
    return [m for m in MEASURES if row["mismatch"].get(m)]


def first_divergence(row: dict) -> dict:
    """Walk the real activations in order beside the forecast's own simulation."""
    forecast = {(s["actor"], s["n"]): s for s in row["forecast_sim"]["slices"]}
    for s in row["actual"]["slices"]:
        f = forecast.get((s["actor"], s["n"]))
        if f is None:
            if s["hp"] or s["block"] or s["stoneskin"] or s["moved"]:
                return {"actor": s["actor"], "n": s["n"], "why": "not_simulated", "actual": s}
            continue
        if (f["hp"], f["block"], f["stoneskin"], f["to"]) != (s["hp"], s["block"], s["stoneskin"], s["to"]):
            return {"actor": s["actor"], "n": s["n"], "why": "differs", "actual": s, "forecast": f}
    return {"actor": "", "n": 0, "why": "accounting"}


def category(row: dict) -> str:
    if not row.get("replica_matches_ui", True):
        return "stale_or_cached_summary"
    if not row.get("resolved", True):
        return "movement_not_committed"
    div = first_divergence(row)
    # atk-03: an undisclosed mismatch the Umbra information filter caused is
    # unseen ground first, whichever slice (or the panel sum) shows it.
    if not row["disclosed"] and row.get("umbra_filter_changed_forecast") and row.get("omniscient_matches_actual"):
        return "umbra_unseen_board"
    if div["why"] == "accounting":
        walk = next((s for s in row["actual"]["slices"] if s["actor"] == "move"), None)
        if walk and (walk["block"] or walk["stoneskin"]) and row["mismatch"]["hp"] is False:
            return "walk_defence_not_counted"
        return "panel_accounting"
    if div["n"] >= 2 and div["actor"].startswith("enemy_"):
        # atk-03: a repeat the forecast simulated (counted) but got wrong vs. one it left unknown.
        if div["actor"] in {c["key"] for c in row.get("counted", [])}:
            return "second_activation_differs"
        return "second_activation_hidden"
    # Undisclosed divergence caused by the Umbra information filter: the same
    # simulation on the full board differs (runs before this field existed were
    # checked by replaying their saves; see the report).
    if not row["disclosed"] and row.get("umbra_filter_changed_forecast", row.get("omniscient_matches_actual", row["context"].get("umbra_limited"))):
        return "umbra_unseen_board"
    known = {e["key"] for e in row["context"]["enemies"]}
    if div["actor"].startswith("enemy_") and div["actor"] not in known:
        return "new_arrival_hidden"
    if div["actor"] == "turn_start" and row["umbra_unknown"]:
        return "umbra_terminal_unknown"
    if div["why"] == "not_simulated":
        if div["actual"].get("spawn"):
            return "reinforcement_spawn"
        hidden = {e["key"] for e in row["context"]["enemies"] if not e["visible"]}
        if div["actor"] in hidden:
            return "umbra_hidden_actor"
        return "actor_not_simulated"
    if div["actor"] == "turn_start" and row["context"].get("battlefield_rule") and not row["disclosed"]:
        return "half_health_switch_not_forecast"
    if div["actor"] == "turn_start":
        return "turn_start"
    if div["actor"] == "turn_end":
        return "turn_end"
    return "enemy_activation_differs"


def flag_reason(f: dict, p: dict, context: dict) -> str:
    slices = p["actual"]["slices"]
    if not f["danger"]:
        if not f["hit_first"]:
            return "grey_hit_by_hidden_second_move"
        if f["icon"] in ("move", "block", "heal", "") and context.get("battlefield_rule"):
            return "grey_hit_by_rule_beat_on_its_turn"
        return "grey_hit_planned_alone"
    if f["activations"] == 0:
        return "red_never_acted"
    keys = [s["actor"] for s in slices]
    index = keys.index(f["key"])
    if any(s["moved"] for s in slices[:index]):
        return "red_hero_moved_first"
    if index == len(slices) - 1 and p["actual"]["outcome"]:
        return "red_fight_ended_on_its_turn"
    return "red_acted_but_missed"


def pct(n: int, d: int) -> str:
    return f"{100.0 * n / d:.2f}%" if d else "n/a"


def report(args: argparse.Namespace) -> None:
    checks, flags, totals = load(args.label)
    fights = {r["context"]["fight"] for r in checks}
    points = {(r["_run"], r["point"]) for r in checks}
    by_mode = Counter(r["mode"] for r in checks)
    print(f"label {args.label}: {len(totals)} runs, {len(fights)} fights, {len(points)} decision points, {len(checks)} checks {dict(by_mode)}")
    print("sections", sorted(Counter(r["context"]["section"] for r in checks).items()))
    print("room kinds", dict(Counter(r["context"]["room_kind"] for r in checks)))
    print("biomes", dict(Counter(r["context"]["biome"] for r in checks)))
    print("audit seconds", sum(t.get("audit_seconds", 0) for t in totals))
    usec = sorted(r["ui_usec"] for r in checks)
    if usec:
        print(f"ui forecast usec median {usec[len(usec)//2]} p95 {usec[int(len(usec)*0.95)]} max {usec[-1]}")
    rows = []
    for mode in ("pass", "move", "stay"):
        subset = [r for r in checks if r["mode"] == mode and r.get("resolved", True)]
        for measure in MEASURES:
            bad = [r for r in subset if r["mismatch"][measure]]
            hidden = [r for r in bad if not r["disclosed"]]
            rows.append((mode, measure, len(subset), len(bad), len(hidden)))
    print("\nmode measure checks mismatches (rate) undisclosed (rate)")
    for mode, measure, n, bad, hidden in rows:
        print(f"{mode:5} {measure:9} {n:6} {bad:5} ({pct(bad, n)}) {hidden:5} ({pct(hidden, n)})")
    flag_rows = [f for row in flags for f in row["flags"]]
    cm = Counter((f["danger"], f["hit_any"]) for f in flag_rows)
    print(f"\nflags {len(flag_rows)}: red&hit {cm[(True, True)]} red&miss {cm[(True, False)]} grey&hit {cm[(False, True)]} grey&miss {cm[(False, False)]}")
    if any("marks_ready_before" in row for row in flags):
        print(f"disc marks ready before the audit asked: {sum(1 for row in flags if row.get('marks_ready_before'))}/{len(flags)}; discs still stale when read: {sum(1 for row in flags if row.get('discs_stale'))}")
    grey_hit = [f for f in flag_rows if not f["danger"] and f["hit_any"]]
    print("grey&hit by first-activation:", Counter(f["hit_first"] for f in grey_hit), "by acting:", Counter(f["acting"] for f in grey_hit))
    print("grey&hit by type:", Counter(f["type"] for f in grey_hit).most_common(20))
    print("red&miss by type:", Counter(f["type"] for f in flag_rows if f["danger"] and not f["hit_any"]).most_common(20))
    passes_by_point = {(r["_run"], r["point"]): r for r in checks if r["mode"] == "pass"}
    reasons = Counter()
    flag_examples = defaultdict(list)
    for row in flags:
        p = passes_by_point.get((row["_run"], row["point"]))
        for f in row["flags"]:
            if f["danger"] == f["hit_any"] or p is None:
                continue
            reason = flag_reason(f, p, row["context"])
            reasons[reason] += 1
            flag_examples[reason].append((row["point"], f["type"], row.get("repro", "")))
    print("flag mismatch reasons:", dict(reasons))
    for reason, items in flag_examples.items():
        print("  ", reason, items[:4])
    cats = defaultdict(list)
    for r in checks:
        if mismatched(r):
            cats[(category(r), r["disclosed"])].append(r)
    print("\ncategories (category, disclosed): count, measures")
    for key, items in sorted(cats.items(), key=lambda kv: -len(kv[1])):
        measures = Counter(m for r in items for m in mismatched(r))
        actors = Counter(_actor_type(r) for r in items).most_common(6)
        print(key, len(items), dict(measures), actors)
    # Second activations: how often a hidden second move lands, and what the panel said.
    passes = [r for r in checks if r["mode"] == "pass"]
    twice = [r for r in passes if any(n >= 2 for n in r["actual"]["activations"].values())]
    hidden_hit = [r for r in twice if any(s["n"] >= 2 and s["actor"].startswith("enemy_") and (s["hp"] or s["block"] or s["stoneskin"]) for s in r["actual"]["slices"])]
    hidden_dmg = [sum(s["hp"] + s["block"] + s["stoneskin"] for s in r["actual"]["slices"] if s["n"] >= 2 and s["actor"].startswith("enemy_")) for r in hidden_hit]
    said = Counter("DEFEAT" if r["shown"]["defeat"] else "UNKNOWN" if r["unrevealed"] and (r["shown"]["hp"] + r["shown"]["block"] + r["shown"]["stoneskin"]) == 0 else "LOSS + ? 2ND MOVE" if r["repeated"] else "COUNTED x2" if r.get("counted") else "other" for r in hidden_hit)
    # atk-03: of those, how often the panel's numbers were exactly right.
    exact = sum(1 for r in hidden_hit if not mismatched(r))
    print(f"\nsecond moves: {len(twice)}/{len(passes)} PASS points have a foe acting twice; hidden move lands in {len(hidden_hit)} (mean {sum(hidden_dmg)/max(1,len(hidden_dmg)):.1f}, max {max(hidden_dmg or [0])}); panel said {dict(said)}; panel exact in {exact}")
    restarts = sum(1 for r in checks if r.get("restarted"))
    print(f"deferred-roll restarts: {restarts}/{len(checks)} checks")
    summary = {"label": args.label, "runs": len(totals), "fights": len(fights), "decision_points": len(points), "checks": dict(by_mode),
               "sections": sorted({r["context"]["section"] for r in checks}), "room_kinds": dict(Counter(r["context"]["room_kind"] for r in checks)), "biomes": dict(Counter(r["context"]["biome"] for r in checks)),
               "rates": [{"mode": m, "measure": me, "checks": n, "mismatches": b, "undisclosed": h} for m, me, n, b, h in rows],
               "flag_reasons": dict(reasons),
               "flags": {"total": len(flag_rows), "red_hit": cm[(True, True)], "red_miss": cm[(True, False)], "grey_hit": cm[(False, True)], "grey_miss": cm[(False, False)], "grey_hit_first_activation": sum(1 for f in grey_hit if f["hit_first"])},
               "categories": {f"{k[0]}|{'disclosed' if k[1] else 'undisclosed'}": len(v) for k, v in cats.items()},
               "second_moves": {"pass_points": len(passes), "acts_twice": len(twice), "hidden_lands": len(hidden_hit), "panel_said": dict(said), "panel_exact": exact},
               "restarts": restarts,
               "ui_usec": {"median": usec[len(usec)//2] if usec else 0, "p95": usec[int(len(usec)*0.95)] if usec else 0}}
    (ROOT / args.label / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    if args.examples:
        for key, items in cats.items():
            if key[1] and not args.disclosed:
                continue
            print("\n==", key)
            for r in items[: args.examples]:
                c = r["context"]
                print(json.dumps({"run": r["_run"], "point": r["point"], "mode": r["mode"], "tile": r["tile"], "section": c["section"], "kind": c["room_kind"], "turn": c["turn"], "hero": c["hero_tile"], "shown": r["shown"], "actual": {k: r["actual"][k] for k in ("hp", "block", "stoneskin", "tile", "outcome", "sources")}, "fc": {k: r["forecast_sim"][k] for k in ("hp", "block", "stoneskin", "tile", "sources")}, "div": first_divergence(r), "repro": r.get("repro", ""), "enemies": [(e["key"], e["type"], e["pos"], e["intent"]) for e in c["enemies"]]}))


def _actor_type(row: dict) -> str:
    div = first_divergence(row)
    for enemy in row["context"]["enemies"]:
        if enemy["key"] == div["actor"]:
            return enemy["type"]
    return div["actor"]


def table(args: argparse.Namespace) -> None:
    """Compact markdown before -> after table from two report summaries."""
    before = json.loads((ROOT / args.before / "summary.json").read_text())
    after = json.loads((ROOT / args.after / "summary.json").read_text())
    names = {"hp": "Health lost", "block": "Block lost", "stoneskin": "Stoneskin lost", "death": "Death", "tile": "Hero's final tile", "sources": "Which foes hit you"}
    b = {(r["mode"], r["measure"]): r for r in before["rates"]}
    a = {(r["mode"], r["measure"]): r for r in after["rates"]}
    print("| Measure | PASS now: said nothing | Move, then end: said nothing | Stay put: said nothing | All forecasts: wrong but flagged |")
    print("|---|---|---|---|---|")
    for measure, label in names.items():
        cells = []
        for mode in ("pass", "move", "stay"):
            rb, ra = b[(mode, measure)], a[(mode, measure)]
            cells.append(f"{pct(rb['undisclosed'], rb['checks'])} → {pct(ra['undisclosed'], ra['checks'])}")
        def flagged(data: dict) -> str:
            rows = [r for r in data.values() if r["measure"] == measure]
            return pct(sum(r["mismatches"] - r["undisclosed"] for r in rows), sum(r["checks"] for r in rows))
        print(f"| {label} | {' | '.join(cells)} | {flagged(b)} → {flagged(a)} |")
    for label, data in (("before", before), ("after", after)):
        print(f"\n{label}: flags {data['flags']} reasons {data.get('flag_reasons')} categories {data['categories']} second_moves {data['second_moves']} ui_usec {data['ui_usec']}")


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
    r.add_argument("--warband", default="", help="biome:tier; enter a production-built Warband room first")
    r.add_argument("--project", default="", help="project directory (e.g. an unmodified baseline copy)")
    p = sub.add_parser("report")
    p.add_argument("--label", default="before")
    p.add_argument("--examples", type=int, default=0)
    p.add_argument("--disclosed", action="store_true")
    t = sub.add_parser("table")
    t.add_argument("--before", default="before")
    t.add_argument("--after", default="after")
    args = parser.parse_args()
    {"run": run, "report": report, "table": table}[args.command](args)


if __name__ == "__main__":
    main()
