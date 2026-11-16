#!/usr/bin/env python3
"""atk-08 hit receipts: driver and classifier (proof tool, stdlib only).

Runs seeded run-hunts through the real RunScene playback (tools/atk08/receipts.gd),
one headless Godot at a time, then pairs every hero Health/Block/Stoneskin loss
(the engine truth) with what the presentation layer drew, and classifies it.
Never in the default test groups.

  python3 tools/atk08/receipts.py run --label before --config normal:0 --seeds 201 202 --health 0
  python3 tools/atk08/receipts.py report --label before
  python3 tools/atk08/receipts.py table --before before --after after
  python3 tools/atk08/receipts.py --root /private/tmp/labyrinth_codex/atk-10/receipts compare --before before --after after

atk-10 added --root/--task-prefix, the rail state at each foe hit (on the acting
foe / nobody / another foe) and enemy-round durations to the summary, and the
compare table.
"""
from __future__ import annotations

import argparse
import bisect
from collections import Counter, defaultdict
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]
ROOT = Path(os.environ.get("ATK08_RECEIPTS_ROOT", "/private/tmp/labyrinth_codex/atk-08/receipts"))
TASK_PREFIX = "atk-08"
NUMBER = re.compile(r"^-(\d+)( B| S)?$")
FIELDS = {None: "hp", " B": "block", " S": "stoneskin"}
# floating_combat_text.gd: ANIMATION_DURATION_SECONDS and the fade starts. A number
# reads while its alpha is at least one half: progress 0.82 (0.86 reduced motion).
DURATION = 0.48
READABLE_PROGRESS = {False: 0.64 + 0.36 * 0.5, True: 0.72 + 0.28 * 0.5}
OVERLAP_FRACTION = 0.15
OCCLUDER_FRACTION = 0.30
OCCLUDER_ALPHA = 0.5
SOURCE_LOOKBACK = 0.6
CATEGORY_NAMES = {
    "first": "Foe's first move this round", "repeat": "Same foe acting again", "arrived": "Foe that arrived this round",
    "rule_beat": "Battlefield rule beat", "bleed": "Bleed, paid as you move or attack", "surface": "Surface or trap",
    "self": "Self: card/Empower costs, own blasts", "fatigue": "Fatigue (deck reshuffle)",
    "turn_start": "Turn start (other)", "turn_end": "Turn end (other)",
}
ORDER = list(CATEGORY_NAMES)
KINDS = ["clear", "wrong_amount", "merged_or_covered", "too_brief", "no_visible_source"]


def run(args: argparse.Namespace) -> None:
    project = Path(args.project) if args.project else PROJECT
    for config in args.config:
        speed, reduced = config.split(":")
        for seed in args.seeds:
            directory = ROOT / args.label / config.replace(":", "-") / f"seed-{seed}-hp{args.health}"
            if (directory / "receipts.jsonl").exists() and not args.force:
                print(f"skip {directory} (exists)")
                continue
            directory.mkdir(parents=True, exist_ok=True)
            command = [sys.executable, str(project / "tools/godot_task_runner.py"), "--project", str(project), "--task-id", f"{TASK_PREFIX}-receipts-{args.label}-{speed}-{reduced}-{seed}",
                       "--timeout", str(args.timeout), "--stream", "--", "godot", "--headless", "--path", ".", "--script", "res://tools/atk08/receipts.gd", "--",
                       "--seed", str(seed), "--output-dir", str(directory), "--no-embrace", "true", "--health", str(args.health)]
            if args.stop_after:
                command += ["--stop-after", str(args.stop_after)]
            env = dict(os.environ, ATK08_SPEED=speed, ATK08_REDUCED=reduced, ATK08_TIME_SCALE=str(args.time_scale), ATK08_PREFER=args.prefer, ATK08_REPRO_AT=args.repro_at, ATK08_EMPOWER="1" if args.empower else "0")
            started = time.time()
            with open(directory / "godot.log", "w") as log:
                code = subprocess.call(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, env=env)
            print(f"{config} seed {seed}: exit {code} in {time.time() - started:.0f}s")


class Tracks:
    def __init__(self, rows: list[dict]):
        self.series: dict[str, tuple[list[int], list[str]]] = {}
        grouped = defaultdict(list)
        for row in rows:
            grouped[row["name"]].append((row["frame"], row["t"], row["value"]))
        for name, items in grouped.items():
            items.sort()
            self.series[name] = ([t for _, t, _ in items], [v for _, _, v in items])

    def at(self, name: str, t: int) -> str:
        times, values = self.series.get(name, ([], []))
        i = bisect.bisect_right(times, t) - 1
        return values[i] if i >= 0 else ""

    def between(self, name: str, t0: int, t1: int) -> list[str]:
        times, values = self.series.get(name, ([], []))
        i = max(0, bisect.bisect_right(times, t0) - 1)
        out = []
        while i < len(times) and times[i] <= t1:
            out.append(values[i])
            i += 1
        return out


def load_runs(label: str) -> list[dict]:
    runs = []
    for path in sorted((ROOT / label).glob("*/seed-*/receipts.jsonl")):
        rows = []
        for line in path.read_text().splitlines():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
        config = next((r for r in rows if r["kind"] == "config"), {})
        runs.append({"path": path.parent, "config": config, "rows": rows})
    return runs


def parse_number(popup: dict) -> tuple[str, int] | None:
    match = NUMBER.match(popup["text"])
    if not match:
        return None
    return FIELDS[match.group(2)], int(match.group(1))


def classify_run(run: dict) -> list[dict]:
    rows = run["rows"]
    reduced = bool(run["config"].get("reduced_motion", False))
    tracks = Tracks([r for r in rows if r["kind"] == "track"])
    hero_popups = [p for p in rows if p["kind"] == "popup"]
    numbers = [p for p in hero_popups if parse_number(p) and (p["reaction"] == "player" or p["at_hero"])]
    cues = [p for p in hero_popups if not parse_number(p)]
    # Block that expires as the hero's turn starts, or that a turn-end effect
    # converts into the same Stoneskin, is not a hit.
    def converted(r: dict) -> bool:
        return r["field"] == "block" and r["hero_after"]["stoneskin"] - r["hero_before"]["stoneskin"] >= r["amount"]
    losses = [r for r in rows if r["kind"] == "loss" and r["category"] != "block_expiry" and not converted(r)]
    claimed: set[str] = set()
    round_starts = {(r["fight"], r["round"]): r["frame"] for r in rows if r["kind"] == "round" and r.get("edge") == "begin"}

    def window(loss: dict) -> tuple[int, int]:
        # Older observers timestamped turn-end losses from round start but
        # accidentally set both frame bounds to the first enemy slice. The
        # existing begin row recovers the matching window without editing logs.
        first = loss["frame0"]
        if loss["path"] == "finish_player_activation":
            first = round_starts.get((loss["fight"], loss["round"]), first)
        return first, loss["frame1"] + 1

    def candidates(loss: dict) -> list[dict]:
        lo, hi = window(loss)
        return [p for p in numbers if p["fight"] == loss["fight"] and lo <= p["first_frame"] <= hi and parse_number(p)[0] == loss["field"] and p["key"] not in claimed]

    matched: dict[int, dict] = {}
    # Pass 1: exact amounts. Bleed prefers its own iconed number.
    for index, loss in enumerate(losses):
        exact = [p for p in candidates(loss) if parse_number(p)[1] == loss["amount"]]
        if exact:
            exact.sort(key=lambda p: (not ((p["icon"] == "bleed") == (loss["category"] == "bleed")), p["first_frame"]))
            matched[index] = {"popup": exact[0], "how": "exact"}
            claimed.add(exact[0]["key"])
    # Pass 2: one number carrying several losses of one window.
    by_window = defaultdict(list)
    for index, loss in enumerate(losses):
        by_window[(loss["fight"], loss["frame0"], loss["frame1"], loss["field"])].append(index)
    for index, loss in enumerate(losses):
        if index in matched:
            continue
        group = [i for i in by_window[(loss["fight"], loss["frame0"], loss["frame1"], loss["field"])] if i not in matched or matched[i]["how"] == "merged"]
        total = sum(losses[i]["amount"] for i in group)
        merged = [p for p in numbers if p["fight"] == loss["fight"] and window(loss)[0] <= p["first_frame"] <= window(loss)[1] and parse_number(p)[0] == loss["field"] and parse_number(p)[1] == total and len(group) > 1]
        if merged:
            matched[index] = {"popup": merged[0], "how": "merged", "with": [losses[i]["category"] for i in group if i != index]}
            claimed.add(merged[0]["key"])
    # Pass 3: a number in the window with another amount.
    for index, loss in enumerate(losses):
        if index in matched:
            continue
        other = candidates(loss)
        if other:
            matched[index] = {"popup": other[0], "how": "wrong"}
            claimed.add(other[0]["key"])

    # atk-12: hero numbers no loss claimed (a duplicate or stray number).
    run["unclaimed_numbers"] = [p for p in numbers if p["key"] not in claimed and p["reaction"] == "player" and not p["text"].endswith((" B", " S"))]
    results = []
    cumulative = defaultdict(int)
    for index, loss in enumerate(losses):
        result = {"loss": loss, "kind": "clear", "why": [], "flags": [], "source": [], "popup": None}
        match = matched.get(index)
        if match is None:
            result["kind"] = "wrong_amount"
            result["why"].append("missing")
            results.append(result)
            continue
        popup = match["popup"]
        result["popup"] = popup
        result["how"] = match["how"]
        if match["how"] == "merged":
            result["kind"] = "merged_or_covered"
            result["why"].append("merged with " + "+".join(match["with"]))
        elif match["how"] == "wrong":
            result["kind"] = "wrong_amount"
            result["why"].append(f"shows {popup['text']} for {loss['amount']}")
        if not popup["at_hero"]:
            result["why"].append("not at hero tile")
            if result["kind"] == "clear":
                result["kind"] = "wrong_amount"
        overlaps = [o for o in popup["overlaps"] if o["fraction"] >= OVERLAP_FRACTION]
        occluders = [o for o in popup["occluders"] + popup.get("occluders_mid", []) if o["fraction"] >= OCCLUDER_FRACTION and o["alpha"] >= OCCLUDER_ALPHA]
        if overlaps:
            result["why"].append("overlaps " + ", ".join(f"{o['text']}@{o['tile']}({o['fraction']})" for o in overlaps))
        if occluders:
            result["why"].append("under " + ", ".join(f"{o['path'].split('/')[-1]}:{o['paints']}({o['fraction']},a{o['alpha']})" for o in occluders))
        if (overlaps or occluders) and result["kind"] == "clear":
            result["kind"] = "merged_or_covered"
        # Readable time, in the number's own animation progress (presentation
        # time at that speed): first drawn frame to the last frame at half alpha
        # or more. Headless frames are coarse (a frame is 0.04-0.1 of a number's
        # life), so each end may be one frame off; flag only losses beyond that:
        # vanished before its fade, first drawn after a fifth of its life, or
        # readable for 0.2 of its life (about 0.1 s) less than intended.
        start, last, readable = popup["first_progress"], popup["last_progress"], popup["last_readable_progress"]
        if start >= 0 and readable >= 0:
            samples = popup.get("samples", [])
            jumps = [b[1] - a[1] for a, b in zip(samples, samples[1:])]
            step = max(jumps) if jumps else 0.1
            # Born before the previous sampled frame by more than 60 ms: it was
            # alive but undrawn (a long headless frame alone does not count).
            late = start > 0.2 and start * DURATION > popup.get("first_dt", 0) / 1e6 + 0.06
            # Each end is within one of this number's frames of the truth.
            span = min(1.0, readable + step) - (start if late else 0.0)
            cut = last + step < READABLE_PROGRESS[reduced]
            short = span < READABLE_PROGRESS[reduced] - 0.12
        else:
            span = (popup["last_readable_t"] - popup["first_t"]) / 1e6 / DURATION
            cut, late, short = False, False, span < READABLE_PROGRESS[reduced] - 0.25
        result["readable_seconds"] = round(max(0.0, span) * DURATION, 3)
        if cut or late or short:
            result["why"].append(("vanished early" if cut else "first drawn late" if late else "short") + f": readable {result['readable_seconds']}s, drawn {start:.2f}..{last:.2f}")
            if result["kind"] == "clear":
                result["kind"] = "too_brief"
        source = source_cues(loss, popup, cues, tracks)
        result["source"] = source
        if not source:
            result["why"].append("no visible source" + (" (hidden by the Umbra)" if loss.get("hidden") else ""))
            if result["kind"] == "clear":
                result["kind"] = "no_visible_source"
        rail = tracks.at("rail", popup["first_t"])
        if loss["category"] in ("first", "repeat", "arrived") and rail.startswith("enemy_") and rail != loss["actor"]:
            result["flags"].append(f"rail on {rail}")
        # The rail's active entry as the foe's number is first drawn (atk-10).
        if loss["category"] in ("first", "repeat", "arrived") and str(loss.get("actor", "")).startswith("enemy_"):
            result["rail_state"] = "right" if rail == loss["actor"] else "wrong" if rail.startswith("enemy_") else "nobody"
            result["rail_active"] = rail
        if loss["field"] == "hp":
            key = (loss["fight"], loss["frame0"], loss["frame1"])
            before = loss["hero_before"]["hp"] - cumulative[key]
            cumulative[key] += loss["amount"]
            ghost_hp, ghost_top = popup["ghost_hp"], popup["ghost_top"]
            if ghost_hp > before - loss["amount"] + 0.01:
                result["flags"].append(f"bar not dropped ({ghost_hp:g} vs {before - loss['amount']})")
            elif ghost_top - ghost_hp < loss["amount"] - 0.01:
                result["flags"].append(f"ghost short ({ghost_top:g}->{ghost_hp:g} for {loss['amount']})")
        results.append(result)
    return results


def source_cues(loss: dict, popup: dict, cues: list[dict], tracks: Tracks) -> list[str]:
    t = popup["first_t"]
    t0 = t - int(SOURCE_LOOKBACK * 1e6)
    found = []
    category = loss["category"]
    actor = loss.get("actor", "")
    if category in ("first", "repeat", "arrived", "rule_beat", "turn_start", "turn_end") and actor.startswith("enemy_"):
        if any(actor in value.split(",") for value in tracks.between("animating", t0, t + 50000)):
            found.append("actor animating")
        if tracks.at("rail", t) == actor:
            found.append("rail highlight")
        if tracks.at("banner", t) and tracks.at("pacing", t).split("|")[0] == actor:
            found.append("banner (hidden presence)" if loss.get("hidden") else "banner")
    if category == "rule_beat" or (category in ("turn_start", "turn_end") and not actor.startswith("enemy_")):
        if tracks.at("banner", t):
            found.append("banner")
    if category == "bleed" and popup["icon"] == "bleed":
        found.append("Bleed icon on the number")
    if category == "fatigue":
        for cue in cues:
            if cue["fight"] == popup["fight"] and "fatigue" in cue["text"].lower() and cue["first_t"] <= popup["last_t"] and cue["last_t"] >= t:
                found.append(f"'{cue['text']}' text")
                break
    if category == "surface":
        hero = popup["hero_tile"]
        flashes = [tile for value in tracks.between("surface", t0, t + 50000) for tile in value.split(";") if tile]
        if hero in flashes:
            found.append("surface flash")
        elif flashes:
            found.append("surface flash on the path")
        if popup["icon"]:
            found.append(f"{popup['icon']} icon on the number")
    if category == "self":
        if any(value not in ("-1", "") for value in tracks.between("hand_animating", t - int(1.5e6), t + 50000)):
            found.append("played card in motion")
        if popup["icon"]:
            found.append(f"{popup['icon']} icon on the number")
    return found


def report(args: argparse.Namespace) -> dict:
    runs = load_runs(args.label)
    by_config = defaultdict(list)
    for run in runs:
        c = run["config"]
        by_config[f"{c.get('speed')}{'+reduced' if c.get('reduced_motion') else ''}"].extend((run, r) for r in classify_run(run))
    summary = {"label": args.label, "configs": {}}
    for config, items in sorted(by_config.items()):
        fights = {r["loss"]["fight"] for _, r in items}
        print(f"\n## {args.label} / {config}: {len(items)} losses in {len(fights)} fights, {sum(r['loss']['amount'] for _, r in items if r['loss']['field'] == 'hp')} Health")
        table = defaultdict(Counter)
        health = defaultdict(Counter)
        flags = Counter()
        for _, r in items:
            category = r["loss"]["category"]
            table[category][r["kind"]] += 1
            if r["loss"]["field"] == "hp":
                health[category][r["kind"]] += r["loss"]["amount"]
            for flag in r["flags"]:
                flags[flag.split(" (")[0].split(" on ")[0]] += 1
        print("| Source | Losses | Health | " + " | ".join(KINDS) + " |")
        print("|---|---:|---:|" + "---:|" * len(KINDS))
        for category in ORDER + sorted(set(table) - set(ORDER)):
            if category not in table:
                continue
            counts = table[category]
            print(f"| {CATEGORY_NAMES.get(category, category)} | {sum(counts.values())} | {sum(health[category].values())} | " + " | ".join(str(counts[k]) for k in KINDS) + " |")
        totals = Counter()
        for counts in table.values():
            totals.update(counts)
        print(f"| All | {sum(totals.values())} | {sum(sum(h.values()) for h in health.values())} | " + " | ".join(str(totals[k]) for k in KINDS) + " |")
        print("flags:", dict(flags))
        why = Counter()
        for _, r in items:
            for w in r["why"]:
                why[re.sub(r"[-\d.]+|\(.*", "", w).strip()] += 1
        print("reasons:", dict(why.most_common()))
        print("sources:", dict(Counter(s for _, r in items for s in r["source"]).most_common()))
        rail = Counter(r["rail_state"] for _, r in items if r.get("rail_state"))
        print("rail at foe hits:", dict(rail))
        runs_here = {id(run): run for run, _ in items}
        rounds = round_durations(list(runs_here.values()))
        print("enemy rounds:", rounds)
        delays = text_delays(list(runs_here.values()))
        print("late-number clock offsets:", delays)
        missing = Counter(r["loss"]["category"] for _, r in items if "missing" in r["why"])
        missing_by_source = Counter(
            f"{r['loss'].get('actor_type') or r['loss']['category']}:{r['loss']['path']}:{r['loss']['field']}"
            for _, r in items if "missing" in r["why"]
        )
        print("missing numbers by source:", dict(missing))
        print("missing numbers by actor/path/resource:", dict(missing_by_source))
        unclaimed = sum(len(run.get("unclaimed_numbers", [])) for run in runs_here.values())
        print("hero Health numbers no loss claimed:", unclaimed)
        examples = {}
        for run, r in items:
            keys = [r["kind"]] if r["kind"] != "clear" else []
            keys += [f"flag:{f.split(' (')[0].split(' on ')[0]}" for f in r["flags"]]
            for key in keys:
                examples.setdefault((key, r["loss"]["category"]), (run, r))
        if args.examples:
            for (key, category), (run, r) in sorted(examples.items()):
                loss = r["loss"]
                print(f"  {key} [{category}] seed {loss['seed']} fight {loss['fight']} turn {loss['turn']} round {loss['round']} path {loss['path']} actor {loss.get('actor')}/{loss.get('actor_type', '')} n{loss.get('n', '')} {loss['field']} -{loss['amount']}"
                      f" | popup {r['popup']['text'] if r['popup'] else None} | {'; '.join(r['why'] + r['flags'])} | src {r['source']} | {run['path'].name}")
        summary["configs"][config] = {"losses": len(items), "fights": len(fights), "table": {k: dict(v) for k, v in table.items()}, "health": {k: dict(v) for k, v in health.items()},
                                      "flags": dict(flags), "examples": {f"{k}|{c}": example_row(run, r) for (k, c), (run, r) in examples.items()},
                                      "rail": dict(rail), "rail_examples": rail_examples(items), "rounds": rounds, "text_delays": delays,
                                      "missing": dict(missing), "missing_by_source": dict(missing_by_source), "unclaimed_numbers": unclaimed,
                                      "missing_examples": [example_row(run, r) for run, r in items if "missing" in r["why"]]}
    (ROOT / args.label / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def round_durations(runs: list[dict]) -> dict:
    """Enemy-round time on the presentation clock (game seconds; at normal speed
    one game second is one second, faster speeds divide it by 1.5 or 2), from
    each _resolve_enemy_round call to its return: per round and summed per fight."""
    per_round: list[float] = []
    per_fight: dict[str, float] = defaultdict(float)
    for run in runs:
        begins = {}
        for row in run["rows"]:
            if row["kind"] != "round":
                continue
            key = (row["fight"], row["round"])
            if row["edge"] == "begin":
                begins[key] = row["t"]
            elif key in begins:
                seconds = (row["t"] - begins.pop(key)) / 1e6
                per_round.append(seconds)
                per_fight[f"{run['path'].name}|{row['fight']}"] += seconds
    def stats(values: list[float]) -> dict:
        if not values:
            return {"n": 0}
        ordered = sorted(values)
        return {"n": len(ordered), "median": round(ordered[len(ordered) // 2] if len(ordered) % 2 else (ordered[len(ordered) // 2 - 1] + ordered[len(ordered) // 2]) / 2, 3),
                "max": round(ordered[-1], 3), "total": round(sum(ordered), 2)}
    return {"round": stats(per_round), "fight": stats(list(per_fight.values())), "fights": {k: round(v, 3) for k, v in per_fight.items()}}


def text_delays(runs: list[dict]) -> dict:
    """atk-10: each attack whose numbers were first drawn after contact starts
    their clock that much later, so its feedback can wait that much longer."""
    values = [row["seconds"] for run in runs for row in run["rows"] if row["kind"] == "text_delay"]
    per_fight: dict[str, float] = defaultdict(float)
    for run in runs:
        for row in run["rows"]:
            if row["kind"] == "text_delay":
                per_fight[f"{run['path'].name}|{row['fight']}"] += row["seconds"]
    fights = sorted(per_fight.values())
    return {"n": len(values), "total": round(sum(values), 3), "max": round(max(values), 3) if values else 0.0,
            "per_fight_max": round(fights[-1], 3) if fights else 0.0, "fights_with_any": len(fights)}


def rail_examples(items: list) -> list[dict]:
    out = []
    for run, r in items:
        if r.get("rail_state") in ("nobody", "wrong"):
            loss = r["loss"]
            out.append({"state": r["rail_state"], "rail": r.get("rail_active", ""), "seed": loss["seed"], "fight": loss["fight"], "turn": loss["turn"], "round": loss["round"],
                        "actor": loss.get("actor"), "actor_type": loss.get("actor_type", ""), "n": loss.get("n"), "amount": loss["amount"], "t": r["popup"]["first_t"] if r["popup"] else None,
                        "anchor_decision": loss.get("anchor_decision"), "replay_decisions": loss.get("replay_decisions"), "repro": loss.get("repro"), "run": str(run["path"])})
    return out


def compare(args: argparse.Namespace) -> None:
    """The atk-10 table: per setting, the rail at foe hits, "too brief" and the
    enemy-round time per fight, before -> after."""
    before = json.loads((ROOT / args.before / "summary.json").read_text())["configs"]
    after = json.loads((ROOT / args.after / "summary.json").read_text())["configs"]
    print("| Setting | Foe hits | Rail on the acting foe | Nobody | Another foe | Too brief (all receipts) | Round s per fight, median | max | Round s, median | max |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for config in sorted(set(before) | set(after)):
        b, a = before.get(config, {}), after.get(config, {})
        def rail(c: dict, k: str) -> int:
            return int(c.get("rail", {}).get(k, 0))
        def brief(c: dict) -> int:
            return sum(v.get("too_brief", 0) for v in c.get("table", {}).values())
        def dur(c: dict, scope: str, k: str) -> str:
            return f"{c.get('rounds', {}).get(scope, {}).get(k, 0):.2f}"
        cells = [f"{sum(b.get('rail', {}).values())} → {sum(a.get('rail', {}).values())}"]
        cells += [f"{rail(b, k)} → {rail(a, k)}" for k in ("right", "nobody", "wrong")]
        cells.append(f"{brief(b)} → {brief(a)}")
        cells += [f"{dur(b, 'fight', 'median')} → {dur(a, 'fight', 'median')}", f"{dur(b, 'fight', 'max')} → {dur(a, 'fight', 'max')}",
                  f"{dur(b, 'round', 'median')} → {dur(a, 'round', 'median')}", f"{dur(b, 'round', 'max')} → {dur(a, 'round', 'max')}"]
        print(f"| {config} | " + " | ".join(cells) + " |")
    # The same fights in both passes (same seed, run and room), round time paired.
    print()
    for config in sorted(set(before) & set(after)):
        fb = before[config].get("rounds", {}).get("fights", {})
        fa = after[config].get("rounds", {}).get("fights", {})
        shared = sorted(set(fb) & set(fa))
        if not shared:
            continue
        deltas = sorted(fa[k] - fb[k] for k in shared)
        print(f"{config}: {len(shared)} fights in both passes; round time per fight after - before: median {deltas[len(deltas) // 2]:+.2f} s, min {deltas[0]:+.2f}, max {deltas[-1]:+.2f}")
    print()
    print("| Setting | Missing numbers (source: before → after) | Hero numbers no loss claimed |")
    print("|---|---|---:|")
    for config in sorted(set(before) | set(after)):
        b, a = before.get(config, {}).get("missing", {}), after.get(config, {}).get("missing", {})
        cells = ", ".join(f"{CATEGORY_NAMES.get(k, k)} {b.get(k, 0)} → {a.get(k, 0)}" for k in sorted(set(b) | set(a))) or "none"
        print(f"| {config} | {cells} (all: {sum(b.values())} → {sum(a.values())}) | {before.get(config, {}).get('unclaimed_numbers', '-')} → {after.get(config, {}).get('unclaimed_numbers', '-')} |")
    print()
    for config in sorted(after):
        d = after[config].get("text_delays", {})
        if d:
            print(f"{config}: late-number clock offsets in the after pass: {d.get('n', 0)} attacks, {d.get('total', 0):.2f} s in all, at most {d.get('max', 0):.3f} s per attack and {d.get('per_fight_max', 0):.2f} s per fight")


def example_row(run: dict, r: dict) -> dict:
    loss = r["loss"]
    return {"seed": loss["seed"], "fight": loss["fight"], "turn": loss["turn"], "round": loss["round"], "path": loss["path"], "actor": loss.get("actor"), "actor_type": loss.get("actor_type", ""),
            "n": loss.get("n"), "field": loss["field"], "amount": loss["amount"], "popup": r["popup"]["text"] if r["popup"] else None, "why": r["why"], "flags": r["flags"], "source": r["source"],
            "t0": loss["t0"], "run": str(run["path"])}


def events(args: argparse.Namespace) -> None:
    """Real saves (repro dirs) for the native frame strips: a foe hitting the
    hero twice in one enemy round, a hero move that pays Bleed, a reshuffle
    that costs Fatigue."""
    for run in load_runs(args.label):
        losses = [r for r in run["rows"] if r["kind"] == "loss" and r.get("repro")]
        firsts = {(r["fight"], r["round"], r["actor"]): r for r in losses if r["category"] == "first" and r["field"] == "hp"}
        for r in losses:
            kind = ""
            if r["category"] == "repeat" and r["field"] == "hp" and (r["fight"], r["round"], r["actor"]) in firsts:
                kind = "double_hit"
            elif r["category"] == "bleed" and r.get("actions") == ["move:move"]:
                kind = "bleed_move"
            elif r["category"] == "fatigue" and r["path"] == "fatigue_beat":
                kind = "fatigue"
            if kind and (not args.kind or kind == args.kind):
                print(f"{kind:10} {r['repro']} fight {r['fight']} turn {r['turn']} round {r['round']} {r.get('actor_type', '')} -{r['amount']} decisions {r['replay_decisions']}")


def table(args: argparse.Namespace) -> None:
    """Markdown tables for the report: per source for one setting, then totals per setting."""
    before = json.loads((ROOT / args.before / "summary.json").read_text())["configs"]
    after = json.loads((ROOT / args.after / "summary.json").read_text())["configs"]
    extra = [json.loads((ROOT / label / "summary.json").read_text())["configs"] for label in args.extra_before], [json.loads((ROOT / label / "summary.json").read_text())["configs"] for label in args.extra_after]
    def merged(configs: dict, more: list[dict], config: str) -> tuple[dict, dict]:
        table, health = defaultdict(Counter), defaultdict(Counter)
        for source in [configs] + more:
            for category, counts in source.get(config, {}).get("table", {}).items():
                table[category].update(counts)
            for category, counts in source.get(config, {}).get("health", {}).items():
                health[category].update(counts)
        return table, health
    b, bh = merged(before, extra[0], args.config)
    a, ah = merged(after, extra[1], args.config)
    print("| Source | Receipts | Health | Clear | Wrong or missing | Merged or covered | Too brief | No source |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|")
    for category in ORDER:
        if category not in b and category not in a:
            continue
        cells = [f"{sum(b.get(category, {}).values())} → {sum(a.get(category, {}).values())}", f"{sum(bh.get(category, {}).values())} → {sum(ah.get(category, {}).values())}"]
        cells += [f"{b.get(category, {}).get(k, 0)} → {a.get(category, {}).get(k, 0)}" for k in KINDS]
        print(f"| {CATEGORY_NAMES[category]} | " + " | ".join(cells) + " |")
    print()
    print("| Setting | Fights | Receipts | Clear | Wrong or missing | Merged or covered | Too brief | No source |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|")
    for config in sorted(set(before) | set(after)):
        cells = [f"{before.get(config, {}).get('fights', 0)} → {after.get(config, {}).get('fights', 0)}", f"{before.get(config, {}).get('losses', 0)} → {after.get(config, {}).get('losses', 0)}"]
        for k in KINDS:
            tb = sum(c.get(k, 0) for c in before.get(config, {}).get("table", {}).values())
            ta = sum(c.get(k, 0) for c in after.get(config, {}).get("table", {}).values())
            cells.append(f"{tb} → {ta}")
        print(f"| {config} | " + " | ".join(cells) + " |")


def main() -> None:
    global ROOT, TASK_PREFIX
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="", help="receipt directory (default: atk-08's, or $ATK08_RECEIPTS_ROOT)")
    parser.add_argument("--task-prefix", default="atk-08", help="godot_task_runner task-id prefix")
    sub = parser.add_subparsers(dest="command", required=True)
    r = sub.add_parser("run")
    r.add_argument("--label", default="before")
    r.add_argument("--config", nargs="+", default=["normal:0"], help="speed:reduced, e.g. normal:0 fastest:1")
    r.add_argument("--seeds", type=int, nargs="+", required=True)
    r.add_argument("--health", type=int, default=0, help="0 keeps production starting Health")
    r.add_argument("--stop-after", type=int, default=0)
    r.add_argument("--time-scale", type=float, default=6.0)
    r.add_argument("--timeout", type=float, default=5400)
    r.add_argument("--force", action="store_true")
    r.add_argument("--project", default="")
    r.add_argument("--prefer", default="", help="card ids the bot plays whenever offered (self-cost coverage)")
    r.add_argument("--empower", action="store_true", help="Empower a selected card whenever the scene offers it (Empower cost coverage)")
    r.add_argument("--repro-at", default="", help="comma-separated clean decisions whose real save to keep for strips")
    p = sub.add_parser("report")
    p.add_argument("--label", default="before")
    p.add_argument("--examples", action="store_true")
    e = sub.add_parser("events")
    e.add_argument("--label", default="before")
    e.add_argument("--kind", default="")
    t = sub.add_parser("table")
    t.add_argument("--before", default="before")
    t.add_argument("--after", default="after")
    t.add_argument("--config", default="normal")
    t.add_argument("--extra-before", nargs="*", default=[], help="labels merged into the per-source table (e.g. empower)")
    t.add_argument("--extra-after", nargs="*", default=[])
    c = sub.add_parser("compare")
    c.add_argument("--before", default="before")
    c.add_argument("--after", default="after")
    args = parser.parse_args()
    if args.root:
        ROOT = Path(args.root)
    TASK_PREFIX = args.task_prefix
    {"run": run, "report": report, "table": table, "events": events, "compare": compare}[args.command](args)


if __name__ == "__main__":
    main()
