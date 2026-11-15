#!/usr/bin/env python3
"""atk-06 rest red-tile audit driver and report (proof tool, stdlib only).

Runs tools/atk06/audit.gd (the atk-01 walk plus the board's red tiles) one
headless Godot at a time, then reports how the red tiles at rest agree with the
forecast for staying (PASS) and for every movement destination. Never in the
default test groups.

  python3 tools/atk06/audit.py run --seeds 101 102 --health 9999 --label before
  python3 tools/atk06/audit.py run --seeds 201 202 203 204 205 206 207 208 --health 0 --label before
  python3 tools/atk06/audit.py run --seeds 301 --health 9999 --warband air:2 --stop-after 220 --label before
  python3 tools/atk06/audit.py report --label before [--examples 2]
  python3 tools/atk06/audit.py table --before before --after after
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
# atk-09: later audits write beside their own task (ATK06_AUDIT_ROOT); a label
# under another root reads as <root>:<label> (for example the atk-06 "after" run).
ROOT = Path(os.environ.get("ATK06_AUDIT_ROOT", "/private/tmp/labyrinth_codex/atk-06/audit"))


def label_dir(label: str) -> Path:
    if ":" in label:
        root, name = label.rsplit(":", 1)
        return Path(root) / name
    return ROOT / label


def run(args: argparse.Namespace) -> None:
    out = label_dir(args.label)
    out.mkdir(parents=True, exist_ok=True)
    project = Path(args.project) if args.project else PROJECT
    for seed in args.seeds:
        directory = out / (f"seed-{seed}-hp{args.health}" + (f"-warband-{args.warband.replace(':', '-')}" if args.warband else ""))
        if (directory / "samples.jsonl").exists() and not args.force:
            print(f"skip {directory} (exists)")
            continue
        directory.mkdir(parents=True, exist_ok=True)
        command = [sys.executable, str(project / "tools/godot_task_runner.py"), "--project", str(project), "--task-id", f"{os.environ.get('ATK06_TASK', 'atk-06')}-audit-{out.name}-{seed}", "--timeout", str(args.timeout), "--",
                   "godot", "--headless", "--path", ".", "--script", args.script, "--",
                   "--seed", str(seed), "--output-dir", str(directory), "--no-embrace", "true", "--health", str(args.health)]
        if args.stop_after:
            command += ["--stop-after", str(args.stop_after)]
        started = time.time()
        env = dict(os.environ, ATK01_WARBAND=args.warband) if args.warband else None
        with open(directory / "godot.log", "w") as log:
            code = subprocess.call(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, env=env)
        print(f"seed {seed} health {args.health}: exit {code} in {time.time() - started:.0f}s", flush=True)


def load(label: str) -> tuple[list[dict], dict, list[dict]]:
    checks, points, totals = [], {}, []
    for path in sorted(label_dir(label).glob("seed-*/samples.jsonl")):
        for line in path.read_text().splitlines():
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue  # a run still writing its last line
            row["_run"] = path.parent.name
            kind = row.get("kind")
            if kind == "check" and "red" in row:
                checks.append(row)
            elif kind == "red_point":
                points[(row["_run"], row["point"])] = row
            elif kind == "audit_totals":
                totals.append(row)
    for row in checks:
        row["_point"] = points.get((row["_run"], row["point"]), {})
    return checks, points, totals


# --- what the forecast says happens on a tile ---------------------------------------

def loss(s: dict) -> int:
    # Block that simply expires at the start of the hero's turn is not a loss to anything.
    block = 0 if s["actor"] == "turn_start" else int(s.get("block", 0))
    return int(s.get("hp", 0)) + block + int(s.get("stoneskin", 0))


def hurts(s: dict) -> bool:
    """A slice that costs the hero Health, Block or Stoneskin, or moves it (not its own walk)."""
    return loss(s) > 0 or bool(s.get("moved") and s["actor"] != "move")


def forecast_hit(row: dict) -> bool:
    """The forecast (its replica matches the panel) says the hero is hurt or moved before its next turn."""
    return bool(row["shown"]["defeat"]) or any(hurts(s) for s in row["forecast_sim"]["slices"])


def actual_hit(row: dict) -> bool:
    return row["actual"]["outcome"] == "defeat" or any(hurts(s) for s in row["actual"]["slices"])


def resolved(s: dict) -> bool:
    """The forecast resolved this activation (it skips unknown ones under a '?')."""
    return bool(s.get("step_kinds"))


def own_effect(s: dict) -> bool:
    """Did the foe's own action hurt the hero (a rule beat in the same turn replayed away)?"""
    return bool(s["hurts_without_rule"]) if "hurts_without_rule" in s else hurts(s)


def uncertain(row: dict) -> bool:
    return bool(row.get("unrevealed") or row.get("umbra_unknown") or row.get("limit") or row.get("unseen") or row.get("new_arrival"))


# --- root causes ------------------------------------------------------------------------

def miss_cause(row: dict, hovered: bool = False) -> str:
    """Why a clear tile is hit: the first slice that hurts the hero, walk and ticks last.
    hovered: the tile was clear with the hero planned standing on it (the hover set)."""
    slices = [s for s in row["forecast_sim"]["slices"] if hurts(s)]
    if not slices:
        # The panel shows a loss the slices do not (it never happened in these runs).
        return "panel_only"
    if hovered and row.get("tile_seen") is False and any(s["actor"].startswith("enemy_") for s in slices):
        return "destination_unseen"
    known = {e["key"]: e for e in row["context"]["enemies"]}
    order = row["forecast_sim"]["slices"]
    for s in slices:
        actor = s["actor"]
        if actor == "move":
            continue
        if actor in ("turn_start", "turn_end"):
            continue
        if not actor.startswith("enemy_"):
            return "rule_beat"
        if actor not in known:
            return "new_arrival"
        if not known[actor]["visible"]:
            return "hidden_foe"
        if s["n"] >= 2:
            return "second_activation"
        index = order.index(s)
        if any(p.get("moved") and p["actor"] not in ("move",) for p in order[:index]):
            return "pushed_or_pulled_first"
        if s.get("plan") == "ok" and not s.get("covers"):
            if s.get("beat") and not own_effect(s):
                return "rule_beat_on_its_turn"
            if not s.get("alive_after", True):
                return "died_and_burst_on_its_turn"
            if not s.get("visible"):
                # Visible from the hero's tile, out of sight from where it will stand:
                # the plan for that position came back empty (atk-06 fix 1).
                return "out_of_sight_from_there"
            return "plan_misses_resolution"
        if row["mode"] == "move" and not hovered and row.get("red_hover"):
            return "replan_after_hero_moves"
        if row["mode"] == "move" and not hovered:
            return "replan_and_board_changed"
        # The foe's plan covers the hero when it acts, yet the rest set left the tile clear.
        point = row.get("_point", {})
        owned = any(actor in owners for owners in point.get("rest", {}).values())
        badge = point.get("badges", {}).get(actor)
        if not owned and badge is not None:
            if not badge["acting"]:
                return "rest_says_not_acting"
            if badge["cancelled"]:
                return "rest_says_cancelled"
            if badge["family"] != "attack":
                return "rest_non_attack_intent"
        if any(p["actor"] == "turn_end" and p.get("beat") for p in order[:index]):
            return "rule_beat_after_your_turn_moved_things"
        return "board_changed_first"
    for s in slices:
        if s["actor"] == "turn_end":
            return "rule_beat_after_your_turn" if s.get("beat") else "turn_end_effect"
        if s["actor"] == "turn_start":
            if row["shown"].get("fatigue", 0) > 0:
                return "fatigue"
            if any(k in row.get("_point", {}).get("hero_status", {}) for k in ("bleed", "burn", "burning")):
                return "status_tick"
            if any(p.get("plan") == "ok" and "surface" in p.get("acts", []) and p.get("covers") for p in order):
                return "foe_surface_under_you"
            if any(p["actor"] == "move" and loss(p) for p in order):
                return "own_walk"
            return "turn_start_effect"
    return "own_walk"


def alarm_cause(row: dict, hovered: bool = False) -> str:
    """Why a red tile is safe, by the first owner that explains it."""
    owners = row.get("hover_owners" if hovered else "red_owners", [])
    slices = row["forecast_sim"]["slices"]
    reasons = []
    for owner in owners:
        if owner.startswith("lob:"):
            reasons.append("lob_mark")
            continue
        if owner == "died_first":
            reasons.append("owner_died_on_its_turn")
            continue
        if owner.startswith("later:"):
            # atk-09: a later activation's tiles, from the forecast that left the hero unhurt.
            later = [s for s in slices if s["actor"] == owner[len("later:"):] and s["n"] >= 2]
            first = later[0] if later else {}
            if not later:
                reasons.append("later_owner_never_acted")
            elif any(p.get("moved") and p["actor"] != "move" for p in slices[:slices.index(first)]):
                reasons.append("later_hero_moved_first")
            elif first.get("plan") == "ok" and first.get("covers"):
                reasons.append("later_plan_hits_resolution_misses")
            else:
                reasons.append("later_board_changed")
            continue
        if owner in ("battlefield_rule", "snare_pressure"):
            reasons.append(owner + "_missed")
            continue
        acts = [s for s in slices if s["actor"] == owner]
        if not acts:
            reasons.append("owner_never_acted" if not row["forecast_sim"]["outcome"] else "fight_ended_first")
            continue
        first = acts[0]
        if first.get("plan") == "ok" and not resolved(first):
            reasons.append("forecast_left_it_unknown")
            continue
        if first.get("plan") == "ok" and first.get("covers"):
            if not first.get("alive_after", True):
                reasons.append("owner_died_on_its_turn")
            elif any(a in ("lob_mark", "icefall_mark", "upheaval_mark", "cinder_marks", "burrow") for a in first.get("acts", [])):
                reasons.append("telegraph_lands_later")
            else:
                reasons.append("plan_hits_resolution_misses")
            continue
        index = slices.index(first)
        if any(p.get("moved") and p["actor"] != "move" for p in slices[:index]):
            reasons.append("hero_moved_first")
        elif any(p["actor"] == "turn_end" and p.get("beat") for p in slices[:index]):
            reasons.append("rule_beat_after_your_turn_moved_things")
        elif row["mode"] == "move" and not hovered and not row.get("red_hover"):
            reasons.append("replan_after_hero_moves")
        else:
            reasons.append("board_changed_first")
    order = ["later_plan_hits_resolution_misses", "later_hero_moved_first", "later_board_changed", "later_owner_never_acted",
             "plan_hits_resolution_misses", "telegraph_lands_later", "lob_mark", "battlefield_rule_missed", "snare_pressure_missed",
             "owner_died_on_its_turn", "hero_moved_first", "rule_beat_after_your_turn_moved_things", "fight_ended_first", "owner_never_acted", "replan_after_hero_moves", "board_changed_first"]
    for reason in order:
        if reason in reasons:
            return reason
    return reasons[0] if reasons else "no_owner"


def matrix(rows: list[dict], red_key: str = "red", hit=forecast_hit) -> Counter:
    m = Counter()
    for r in rows:
        m[("red" if r.get(red_key) else "clear", "hit" if hit(r) else "safe")] += 1
    return m


def fmt(m: Counter) -> str:
    total = sum(m.values()) or 1
    cells = [("red", "hit"), ("red", "safe"), ("clear", "hit"), ("clear", "safe")]
    return " | ".join(f"{m[c]} ({100.0 * m[c] / total:.1f}%)" for c in cells)


def pct_list(values: list[int], q: float) -> int:
    values = sorted(values)
    return values[min(len(values) - 1, int(len(values) * q))] if values else 0


def report(args: argparse.Namespace) -> None:
    checks, points, totals = load(args.label)
    stay = [r for r in checks if r["mode"] == "pass"]
    stay_put = {(r["_run"], r["point"]): r for r in checks if r["mode"] == "stay"}
    dests = [r for r in checks if r["mode"] == "move" and r.get("resolved", True)]
    fights = {r["context"]["fight"] for r in checks}
    print(f"label {args.label}: {len(totals)} runs, {len(fights)} fights, {len(points)} points, stay {len(stay)}, destinations {len(dests)}")
    print("sections", sorted(Counter(r["context"]["section"] for r in stay).items()), "rooms", dict(Counter(r["context"]["room_kind"] for r in stay)))
    summary: dict = {"label": args.label, "runs": len(totals), "fights": len(fights), "points": len(points), "stay": len(stay), "destinations": len(dests)}
    print("\nmatrix: red&hit | red&safe (false alarm) | clear&hit (missed) | clear&safe")
    for name, rows in (("stay (PASS)", stay), ("destinations", dests)):
        m = matrix(rows)
        print(f"{name:14} {fmt(m)}")
        summary[name] = {f"{a}_{b}": m[(a, b)] for a, b in m}
        certain = [r for r in rows if not uncertain(r)]
        print(f"{'  no ? shown':14} {fmt(matrix(certain))}")
        summary[name + ", no ?"] = {f"{a}_{b}": n for (a, b), n in matrix(certain).items()}
        hover = [r for r in rows if "red_hover" in r]
        if hover:
            print(f"{'  if hovered':14} {fmt(matrix(hover, 'red_hover'))}")
    # Stay put (movement mode, own tile) against PASS.
    agree = sum(1 for r in stay if (key := (r["_run"], r["point"])) in stay_put and forecast_hit(stay_put[key]) == forecast_hit(r))
    print(f"\nstay-put forecast agrees with PASS on hit: {agree}/{sum(1 for r in stay if (r['_run'], r['point']) in stay_put)}")
    # Cross-check: the forecast reference against real resolution.
    for name, rows in (("stay", stay), ("destinations", dests)):
        same = sum(1 for r in rows if forecast_hit(r) == actual_hit(r))
        sure = [r for r in rows if not uncertain(r)]
        same_sure = sum(1 for r in sure if forecast_hit(r) == actual_hit(r))
        print(f"forecast hit == real hit, {name}: {same}/{len(rows)} ({100.0 * same / max(1, len(rows)):.2f}%); with no '?' shown {same_sure}/{len(sure)}")
    # Root causes.
    summary["causes"] = {}
    for name, rows in (("stay", stay), ("destinations", dests)):
        missed = [r for r in rows if not r["red"] and forecast_hit(r)]
        alarms = [r for r in rows if r["red"] and not forecast_hit(r)]
        mc = Counter(miss_cause(r) for r in missed)
        ac = Counter(alarm_cause(r) for r in alarms)
        print(f"\n{name}: clear & hit by cause {dict(mc.most_common())}")
        print(f"{name}: red & safe by cause {dict(ac.most_common())}")
        summary["causes"][name] = {"missed": dict(mc), "alarms": dict(ac)}
        if args.examples:
            for cause, _ in mc.most_common():
                for r in [r for r in missed if miss_cause(r) == cause][: args.examples]:
                    print("  MISS", cause, example(r))
            for cause, _ in ac.most_common():
                for r in [r for r in alarms if alarm_cause(r) == cause][: args.examples]:
                    print("  ALARM", cause, example(r))
    # With the destination hovered: the board re-plans with the hero standing there.
    hovered_rows = [r for r in dests if "red_hover" in r]
    hm = Counter(miss_cause(r, True) for r in hovered_rows if not r["red_hover"] and forecast_hit(r))
    ha = Counter(alarm_cause(r, True) for r in hovered_rows if r["red_hover"] and not forecast_hit(r))
    print(f"\ndestinations hovered: clear & hit by cause {dict(hm.most_common())}")
    print(f"destinations hovered: red & safe by cause {dict(ha.most_common())}")
    summary["causes"]["hovered"] = {"missed": dict(hm), "alarms": dict(ha)}
    summary["destinations hovered"] = {f"{a}_{b}": n for (a, b), n in matrix(hovered_rows, "red_hover").items()}
    if args.examples:
        for cause, _ in hm.most_common():
            for r in [r for r in hovered_rows if not r["red_hover"] and forecast_hit(r) and miss_cause(r, True) == cause][: args.examples]:
                print("  HOVER MISS", cause, example(r))
        for cause, _ in ha.most_common():
            for r in [r for r in hovered_rows if r["red_hover"] and not forecast_hit(r) and alarm_cause(r, True) == cause][: args.examples]:
                print("  HOVER ALARM", cause, example(r))
    # Plan against its own resolution, every simulated activation of every PASS forecast.
    pc = Counter()
    lies = defaultdict(list)
    for r in checks:
        for s in r["forecast_sim"]["slices"]:
            if s.get("plan") != "ok" or not s.get("visible") or not resolved(s):
                continue
            hit = own_effect(s)
            pc[(r["mode"], bool(s.get("covers")), hit)] += 1
            if bool(s.get("covers")) != hit:
                lies[(s.get("type"), tuple(s.get("acts", [])), bool(s.get("covers")))].append(r)
    print("\nplan covers hero vs activation hurts hero (mode, covers, hurts):", dict(sorted(pc.items())))
    print("plan/resolution disagreements by (type, actions, covers):")
    for key, rows in sorted(lies.items(), key=lambda kv: -len(kv[1]))[:25]:
        print(f"  {len(rows):5}  {key}  e.g. {rows[0]['_run']} {rows[0]['point']} {rows[0]['mode']} {rows[0]['tile']}")
    summary["plan_vs_resolution"] = {f"{m}|{'covers' if c else 'clear'}|{'hurts' if h else 'safe'}": n for (m, c, h), n in pc.items()}
    held = [p for p in points.values() if not p["held_matches"]]
    print(f"\nboard set held at the decision point == fresh rest refresh: {len(points) - len(held)}/{len(points)}")
    for p in held[:5]:
        print("  held differs", p["_run"], p["point"], "held", sorted(p["held"]), "fresh", sorted(p["rest"]))
    summary["held_mismatch"] = len(held)
    options(stay, dests, points, summary)
    (label_dir(args.label) / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")


def example(r: dict) -> str:
    c = r["context"]
    hurt = [(s["actor"], s["n"], loss(s), s.get("moved"), s.get("covers"), s.get("type", "")) for s in r["forecast_sim"]["slices"] if hurts(s)]
    return json.dumps({"run": r["_run"], "point": r["point"], "section": c["section"], "kind": c["room_kind"], "turn": c["turn"], "hero": c["hero_tile"], "tile": r["tile"],
                       "owners": r.get("red_owners"), "hover": r.get("red_hover"), "shown": {k: r["shown"][k] for k in ("hp", "block", "stoneskin", "defeat")}, "hurt": hurt,
                       "actual": {k: r["actual"][k] for k in ("hp", "block", "stoneskin", "tile")}, "repro": r.get("repro", ""),
                       "enemies": [(e["key"], e["type"], e["pos"], e["intent"], e["visible"]) for e in c["enemies"]]})


def options(stay: list[dict], dests: list[dict], points: dict, summary: dict) -> None:
    """What each design option would catch and add, and what it costs per decision point."""
    passes = {(r["_run"], r["point"]): r for r in stay}

    def pass_tiles(key, repeats_only: bool) -> set:
        r = passes.get(key)
        if not r:
            return set()
        return {t for s in r["forecast_sim"]["slices"] if s.get("plan") == "ok" and s.get("visible") and (s["n"] >= 2 or not repeats_only) for t in s.get("plan_tiles", [])}

    def evaluate(name: str, rows: list[dict], red) -> dict:
        caught = sum(1 for r in rows if not r["red"] and forecast_hit(r) and red(r))
        added = sum(1 for r in rows if not r["red"] and not forecast_hit(r) and red(r))
        lost = sum(1 for r in rows if r["red"] and not red(r))
        return {"option": name, "caught": caught, "added_false_alarms": added, "dropped_red": lost}

    def at(r: dict) -> str:
        return r["tile"] if r["mode"] == "move" else r["context"]["hero_tile"]

    results = []
    for label, rows in (("stay", stay), ("destinations", dests)):
        results.append(evaluate(f"second moves from the PASS forecast [{label}]", rows, lambda r: r["red"] or at(r) in pass_tiles((r["_run"], r["point"]), True)))
        results.append(evaluate(f"every simulated activation in context [{label}]", rows, lambda r: r["red"] or at(r) in pass_tiles((r["_run"], r["point"]), False)))
        results.append(evaluate(f"Details [I] attack reach [{label}]", rows, lambda r: r["red"] or r.get("in_reach", False)))
    results.append(evaluate("re-plan for the hero at each destination (hover set) [destinations]", dests, lambda r: r["red"] or r.get("red_hover", False)))
    results.append(evaluate("each destination's own forecast [destinations]", dests, lambda r: r["red"] or forecast_hit(r)))
    print("\noptions (caught missed hits / added false alarms / dropped red):")
    for o in results:
        print(f"  {o['option']}: {o['caught']} / {o['added_false_alarms']} / {o['dropped_red']}")
    # Costs per decision point (µs).
    build = [p["build_usec"] for p in points.values()]
    hover_sum = [sum(p["hover_build_usec"]) for p in points.values() if p["hover_build_usec"]]
    plan_sum = [r.get("plan_usec", 0) for r in stay]
    pass_sim = [max(0, r.get("trace_usec", 0) - r.get("plan_usec", 0)) for r in stay]
    dest_ui = defaultdict(int)
    for r in dests:
        dest_ui[(r["_run"], r["point"])] += r["ui_usec"]
    costs = {
        "rest red set build": build,
        "PASS forecast simulation (already run for the discs)": pass_sim,
        "plans inside the PASS forecast (extra)": plan_sum,
        "red set for every destination (hover builds)": hover_sum,
        "forecast for every destination": list(dest_ui.values()),
    }
    print("costs per decision point, µs (median / p95):")
    for name, values in costs.items():
        print(f"  {name}: {pct_list(values, 0.5)} / {pct_list(values, 0.95)}  (n {len(values)})")
    summary["options"] = results
    summary["costs"] = {name: {"median": pct_list(v, 0.5), "p95": pct_list(v, 0.95), "n": len(v)} for name, v in costs.items()}


def table(args: argparse.Namespace) -> None:
    before = json.loads((label_dir(args.before) / "summary.json").read_text())
    after = json.loads((label_dir(args.after) / "summary.json").read_text())
    print("| | Red & hit | Red & safe (false alarm) | Clear & hit (missed) | Clear & safe |")
    print("|---|---:|---:|---:|---:|")
    for name in ("stay (PASS)", "stay (PASS), no ?", "destinations", "destinations, no ?", "destinations hovered"):
        cells = []
        totals = [sum(data[name].values()) or 1 for data in (before, after)]
        for cell in ("red_hit", "red_safe", "clear_hit", "clear_safe"):
            b, a = before[name].get(cell, 0), after[name].get(cell, 0)
            cells.append(f"{b} ({100.0 * b / totals[0]:.1f}%) → {a} ({100.0 * a / totals[1]:.1f}%)")
        print(f"| {name} ({totals[0]} → {totals[1]}) | {' | '.join(cells)} |")


def block_expiry_only(row: dict) -> bool:
    """The panel's Block row shows only Block that expires at the hero's turn start."""
    if "block_expiry_only" in row:
        return bool(row["block_expiry_only"])
    slices = row["forecast_sim"]["slices"]
    expiring = sum(int(s.get("block", 0)) for s in slices if s["actor"] == "turn_start")
    taken = sum(int(s.get("block", 0)) for s in slices if s["actor"] != "turn_start")
    return row["shown"]["block"] > 0 and expiring > 0 and taken == 0


def compare(args: argparse.Namespace) -> None:
    """atk-09: pair the checks of two runs one to one and report what moved."""
    before, _, _ = load(args.before)
    after, after_points, _ = load(args.after)

    def key(r: dict) -> tuple:
        return (r["_run"], r["point"], r["mode"], r["tile"])

    b = {key(r): r for r in before}
    a = {key(r): r for r in after}
    paired = [k for k in a if k in b]
    print(f"checks: before {len(b)}, after {len(a)}, paired {len(paired)}")
    same_hit = sum(1 for k in paired if forecast_hit(a[k]) == forecast_hit(b[k]))
    print(f"forecast hit unchanged on {same_hit}/{len(paired)} paired checks")

    def kinds(r: dict) -> list:
        if r["mode"] == "pass":
            return [("your tile (PASS)", "red", False)]
        if r["mode"] == "move" and r.get("resolved", True):
            return [("destinations at rest", "red", False), ("destinations hovered", "red_hover", True)]
        return []

    def cell(r: dict, field: str) -> str:
        return ("red" if r.get(field) else "clear") + "&" + ("hit" if forecast_hit(r) else "safe")

    for name in ("your tile (PASS)", "destinations at rest", "destinations hovered"):
        moves = Counter()
        for k in paired:
            for kind, field, _ in kinds(a[k]):
                if kind == name:
                    moves[(cell(b[k], field), cell(a[k], field))] += 1
        print(f"\n{name}: before -> after")
        for (x, y), n in sorted(moves.items()):
            if x != y:
                print(f"  {x:11} -> {y:11} {n}")
    # Root causes before and after, for the rows the change targets.
    for name, rows_of in (("your tile (PASS)", lambda rows: [r for r in rows if r["mode"] == "pass"]),
                          ("destinations at rest", lambda rows: [r for r in rows if r["mode"] == "move" and r.get("resolved", True)])):
        for label, rows in (("before", rows_of(before)), ("after", rows_of(after))):
            mc = Counter(miss_cause(r) for r in rows if not r["red"] and forecast_hit(r))
            ac = Counter(alarm_cause(r) for r in rows if r["red"] and not forecast_hit(r))
            print(f"\n{name} {label}: missed second_activation {mc['second_activation']}, all missed {sum(mc.values())}; "
                  f"alarms owner_died_on_its_turn {ac['owner_died_on_its_turn']}, all alarms {sum(ac.values())} {dict(ac.most_common())}")
    for label, rows in (("before", before), ("after", after)):
        hovered = [r for r in rows if r["mode"] == "move" and r.get("resolved", True) and "red_hover" in r]
        mc = Counter(miss_cause(r, True) for r in hovered if not r["red_hover"] and forecast_hit(r))
        ac = Counter(alarm_cause(r, True) for r in hovered if r["red_hover"] and not forecast_hit(r))
        print(f"\ndestinations hovered {label}: missed second_activation {mc['second_activation']}, all missed {sum(mc.values())} {dict(mc.most_common(8))}; "
              f"alarms owner_died_on_its_turn {ac['owner_died_on_its_turn']}, all alarms {sum(ac.values())} {dict(ac.most_common())}")
    # New false alarms: red & safe after, clear before.
    print("\nnew false alarms (clear & safe before, red & safe after), by cause, one example each:")
    for name in ("your tile (PASS)", "destinations at rest", "destinations hovered"):
        found = defaultdict(list)
        for k in paired:
            for kind, field, hovered in kinds(a[k]):
                if kind == name and a[k].get(field) and not b[k].get(field) and not forecast_hit(a[k]):
                    found[alarm_cause(a[k], hovered)].append(a[k])
        for cause, rows in sorted(found.items(), key=lambda kv: -len(kv[1])):
            shown = next((r for r in rows if r.get("repro")), rows[0])
            print(f"  {name}: {cause} {len(rows)}  e.g. {example(shown)}")
    # Block that only expires (requirement 4).
    for label, rows in (("before", before), ("after", after)):
        print(f"\nBlock row from expiry alone, {label}: {sum(1 for r in rows if block_expiry_only(r))} of {len(rows)} checks;"
              f" panel says Safe {sum(1 for r in rows if r.get('panel_safe'))}")
    # Cost of the rest red set per decision point (µs): the badge build, and the work atk-09 adds.
    build = [p["build_usec"] for p in after_points.values()]
    extra = [p.get("red_extra_usec", 0) for p in after_points.values()]
    total = [p["build_usec"] + p.get("red_extra_usec", 0) for p in after_points.values()]
    print(f"\nrest red-set build per decision point, µs median / p95 (n {len(build)}): before (badge build) {pct_list(build, 0.5)} / {pct_list(build, 0.95)};"
          f" added {pct_list(extra, 0.5)} / {pct_list(extra, 0.95)}; after (sum per point) {pct_list(total, 0.5)} / {pct_list(total, 0.95)}")


def inrun(args: argparse.Namespace) -> None:
    """atk-09: before/after on the same states of one run. "Before" is the pre-atk-09
    red rule the audit rebuilt at each check (red_old, red_hover_old)."""
    checks, points, totals = load(args.label)
    stay = [r for r in checks if r["mode"] == "pass"]
    dests = [r for r in checks if r["mode"] == "move" and r.get("resolved", True)]
    hovered = [r for r in dests if "red_hover" in r]
    print(f"label {args.label}: {len(totals)} runs, {len({r['context']['fight'] for r in checks})} fights, {len(points)} points, stay {len(stay)}, destinations {len(dests)}")

    def as_old(r: dict, hover: bool) -> dict:
        o = dict(r)
        field, owners = ("red_hover", "hover_owners") if hover else ("red", "red_owners")
        o[field] = r.get(field + "_old", r.get(field))
        o[owners] = [w for w in r.get(owners, []) if not w.startswith("later:")]
        if o[field] and not o[owners]:
            # Red before only through a foe the forecast now has die first.
            o[owners] = ["died_first"]
        return o

    print("\n| Checks | Red & hit | Red & safe (false alarm) | Clear & hit (missed) | Clear & safe |")
    print("|---|---:|---:|---:|---:|")
    cells = [("red", "hit"), ("red", "safe"), ("clear", "hit"), ("clear", "safe")]
    summary = {}
    for name, rows, field in (("your tile, PASS", stay, "red"), ("destinations at rest", dests, "red"), ("destinations, hovered", hovered, "red_hover")):
        before = matrix([as_old(r, field == "red_hover") for r in rows], field)
        after = matrix(rows, field)
        print(f"| {name} ({len(rows)}) | " + " | ".join(f"{before[c]} → {after[c]}" for c in cells) + " |")
        summary[name] = {"before": {f"{a}_{b}": before[(a, b)] for a, b in cells}, "after": {f"{a}_{b}": after[(a, b)] for a, b in cells}}
    for name, rows, field in (("your tile, PASS", stay, "red"), ("destinations at rest", dests, "red")):
        sure = [r for r in rows if not uncertain(r)]
        before = matrix([as_old(r, False) for r in sure], field)
        after = matrix(sure, field)
        print(f"| {name}, no ? shown ({len(sure)}) | " + " | ".join(f"{before[c]} → {after[c]}" for c in cells) + " |")
    # The two targeted rows.
    print()
    for name, rows, hover in (("your tile, PASS", stay, False), ("destinations at rest", dests, False), ("destinations, hovered", hovered, True)):
        field = "red_hover" if hover else "red"
        old = [as_old(r, hover) for r in rows]
        mb = Counter(miss_cause(r, hover) for r in old if not r[field] and forecast_hit(r))
        ma = Counter(miss_cause(r, hover) for r in rows if not r[field] and forecast_hit(r))
        ab = Counter(alarm_cause(r, hover) for r in old if r[field] and not forecast_hit(r))
        aa = Counter(alarm_cause(r, hover) for r in rows if r[field] and not forecast_hit(r))
        print(f"{name}: second moves missed {mb['second_activation']} → {ma['second_activation']}; foe dies first (red but safe) {ab['owner_died_on_its_turn']} → {aa['owner_died_on_its_turn']}")
        print(f"   missed by cause after {dict(ma.most_common())}")
        print(f"   false alarms by cause before {dict(ab.most_common())}")
        print(f"   false alarms by cause after  {dict(aa.most_common())}")
        summary[name]["second_moves_missed"] = [mb["second_activation"], ma["second_activation"]]
        summary[name]["dies_first_alarms"] = [ab["owner_died_on_its_turn"], aa["owner_died_on_its_turn"]]
        # New false alarms: clear before, red & safe now.
        fresh = defaultdict(list)
        for r in rows:
            if r[field] and not forecast_hit(r) and not as_old(r, hover)[field]:
                fresh[alarm_cause(r, hover)].append(r)
        for cause, found in sorted(fresh.items(), key=lambda kv: -len(kv[1])):
            shown = next((r for r in found if r.get("repro")), found[0])
            print(f"   NEW false alarm {cause} {len(found)}  e.g. {example(shown)}")
        newly_missed = [r for r in rows if not r[field] and forecast_hit(r) and as_old(r, hover)[field]]
        if newly_missed:
            print(f"   NEW misses (red before, clear now, hit) {len(newly_missed)} e.g. {example(newly_missed[0])}")
        if hover:
            print(f"   hovered forecast ready when the board drew: {sum(1 for r in rows if r.get('hover_forecast_ready'))}/{len(rows)}")
    shown = sum(1 for r in checks if r.get("block_expiry_only"))
    hidden = sum(1 for r in checks if r.get("block_expiry_hidden"))
    print(f"\nBlock row from expiry alone: {hidden} checks the old panel showed as a Block loss now show none; still shown {shown}")
    hidden_rows = [r for r in checks if r.get("block_expiry_hidden")]
    if hidden_rows:
        print("   e.g.", example(next((r for r in hidden_rows if r.get("repro")), hidden_rows[0])))
    print(f"forecast hit == real hit: {sum(1 for r in checks if forecast_hit(r) == actual_hit(r))}/{len(checks)}; held set == fresh rebuild {sum(1 for p in points.values() if p['held_matches'])}/{len(points)}")
    build = [p["build_usec"] for p in points.values()]
    extra = [p.get("red_extra_usec", 0) for p in points.values()]
    total = [b + e for b, e in zip(build, extra)]
    print(f"rest red-set build per decision point, µs median / p95 (n {len(build)}): before {pct_list(build, 0.5)} / {pct_list(build, 0.95)};"
          f" atk-09 work {pct_list(extra, 0.5)} / {pct_list(extra, 0.95)}; after {pct_list(total, 0.5)} / {pct_list(total, 0.95)}")
    summary["costs"] = {"before": [pct_list(build, 0.5), pct_list(build, 0.95)], "added": [pct_list(extra, 0.5), pct_list(extra, 0.95)], "after": [pct_list(total, 0.5), pct_list(total, 0.95)]}
    summary["block_expiry"] = {"hidden": hidden, "still_shown": shown}
    (label_dir(args.label) / "inrun.json").write_text(json.dumps(summary, indent=2) + "\n")


def prewarm(args: argparse.Namespace) -> None:
    """atk-09: hover-prewarm cost per destination forecast and per main-thread step,
    before (the same steps minus the work atk-09 adds) and after, on the same states."""
    forecasts, steps, checked, mismatches = [], [], [0], []
    for path in sorted(label_dir(args.label).glob("seed-*/samples.jsonl")):
        for line in path.read_text().splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("kind") in ("prewarm_probe", "rest_probe"):
                checked[0] += int(row.get("checked", 0))
                mismatches.extend(row.get("mismatches", []))
            if row.get("kind") != "prewarm_probe" or len(row["steps"]) < 2:
                continue
            forecasts.append((sum(s[1] for s in row["steps"]), sum(s[2] for s in row["steps"]), bool(row.get("later"))))
            steps.extend(row["steps"])

    def q(values: list[int], p: float) -> int:
        return pct_list(values, p) if p < 1 else (max(values) if values else 0)

    def line(name: str, before: list[int], after: list[int], points: tuple) -> None:
        cells = " / ".join(f"{q(before, p) / 1000:.2f} → {q(after, p) / 1000:.2f}" for p in points)
        print(f"  {name}: {cells} ms")

    after = [f[0] for f in forecasts]
    before = [f[0] - f[1] for f in forecasts]
    added = [f[1] for f in forecasts]
    print(f"label {args.label}: {len(forecasts)} destination forecasts ({sum(1 for f in forecasts if f[2])} with later tiles), {len(steps)} prewarm steps")
    print("one destination forecast, median / p95 / max (before → after):")
    line("all", before, after, (0.5, 0.95, 1))
    print(f"  added per forecast: median {q(added, 0.5) / 1000:.2f}, p95 {q(added, 0.95) / 1000:.2f}, max {q(added, 1) / 1000:.2f} ms")
    print("longest single prewarm step, p99 / max (before → after):")
    line("all steps", [s[1] - s[2] for s in steps], [s[1] for s in steps], (0.99, 1))
    for phase in ("source", "schedule", "enemy", "summary"):
        rows = [s for s in steps if s[0] == phase]
        line(f"{phase} ({len(rows)})", [s[1] - s[2] for s in rows], [s[1] for s in rows], (0.99, 1))
    worst = max(steps, key=lambda s: s[2]) if steps else ["", 0, 0]
    print(f"  most atk-09 work in one step: {worst[2] / 1000:.2f} ms ({worst[0]} step of {worst[1] / 1000:.2f} ms)")
    enemy_added = [s[2] for s in steps if s[0] == "enemy"]
    print(f"  added per enemy step: p99 {q(enemy_added, 0.99) / 1000:.2f}, p99.9 {q(enemy_added, 0.999) / 1000:.2f}, max {q(enemy_added, 1) / 1000:.2f} ms;"
          f" steps with more than 4 ms added {sum(1 for v in enemy_added if v > 4000)}")
    print(f"attack-only plan == full threat query projected_attack: {checked[0] - len(mismatches)}/{checked[0]} later activations (destinations and at rest)")
    for m in mismatches[:5]:
        print("  MISMATCH", m)


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    r = sub.add_parser("run")
    r.add_argument("--seeds", type=int, nargs="+", required=True)
    r.add_argument("--health", type=int, default=9999)
    r.add_argument("--label", default="before")
    r.add_argument("--stop-after", type=int, default=0)
    r.add_argument("--timeout", type=float, default=7200)
    r.add_argument("--force", action="store_true")
    r.add_argument("--warband", default="", help="biome:tier; enter a production-built Warband room first")
    r.add_argument("--project", default="", help="project directory (e.g. an unmodified baseline copy)")
    r.add_argument("--script", default="res://tools/atk06/audit.gd", help="atk-09: res://tools/atk06/prewarm_probe.gd for the prewarm cost probe")
    p = sub.add_parser("report")
    p.add_argument("--label", default="before")
    p.add_argument("--examples", type=int, default=0)
    t = sub.add_parser("table")
    t.add_argument("--before", default="before")
    t.add_argument("--after", default="after")
    c = sub.add_parser("compare")
    c.add_argument("--before", required=True)
    c.add_argument("--after", required=True)
    w = sub.add_parser("prewarm")
    w.add_argument("--label", required=True)
    i = sub.add_parser("inrun")
    i.add_argument("--label", required=True)
    args = parser.parse_args()
    {"run": run, "report": report, "table": table, "compare": compare, "inrun": inrun, "prewarm": prewarm}[args.command](args)


if __name__ == "__main__":
    main()
