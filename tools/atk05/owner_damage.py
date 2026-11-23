#!/usr/bin/env python3
"""atk-05: where does the hero lose Health in real play? (proof tool, stdlib only)

Reads local analytics JSONL (copies only; never the live profile) and attributes
every hero Health loss to one source category. Not in any default test group.

  python3 tools/atk05/owner_damage.py /private/tmp/labyrinth_codex/atk-05/data
  python3 tools/atk05/owner_damage.py DATA --spot-ranks 1,4,10   # raw sequences
  python3 tools/atk05/owner_damage.py DATA --json out.json       # every loss row

DATA holds one folder per profile (any depth) of events-*.jsonl files. Folders
whose path contains "Visual Probe" are skipped (bots). Output carries no install,
session, run or combat ids: dates, fight names and counts only. Report:
spec/peer_benchmark/readability/atk05_owner_damage.md.

How a loss is found. Every event envelope carries the hero's Health. A card's
envelope is taken before the card resolves (its payload adds player_hp_delta);
every event of one enemy round carries the Health after the whole round. So:
- a hero turn's losses are card deltas plus drops between hero events;
- an enemy round's loss is the Health before it minus the Health after it,
  apportioned by the round's own records (enemy target_losses on the hero,
  battlefield damage_to_player, Fire under the hero at turn start). A foe's
  second or later activation before the hero's next turn is a "repeat".
- No event records Bleed or Fatigue. A reshuffle (the draw pile grows instead
  of shrinking) explains a drop as Fatigue; a drop on the hero's own move or
  attack after a Bleed-applying hit in the round before is Bleed.
Whatever the records do not cover is "unknown". Log quirks handled: the round
that ends a fight is written after its combat id is cleared; Oct/early-Nov
turn-end receipts could arrive in a later batch; the first July builds logged
no enemy actions; builds to 27 Jul stored ten units per Health (divided here).
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime
import json
from pathlib import Path
import re
import sys

CATEGORIES = [
    ("first", "Foe's first move this round"),
    ("repeat", "Same foe acting again before your turn"),
    ("new_foe", "Foe that arrived this round (summon, split)"),
    ("rule", "Battlefield rule beat"),
    ("status", "Hero status (Bleed paid as you act, ticks)"),
    ("surface", "Surface or trap"),
    ("self", "Self-inflicted (card costs, own blasts)"),
    ("fatigue", "Fatigue (deck reshuffle)"),
    ("unknown", "Unknown"),
]
LABEL = dict(CATEGORIES)
SKIP_TYPES = {"card_became_playable", "chronicle_opened"}
ROUND_TYPES = {"enemy_action_resolved", "enemy_status_tick", "battlefield_rule_fired",
               "battlefield_rule_switched", "snare_pressure", "player_turn_started"}
HERO_TYPES = {"card_played", "player_moved", "player_move_undone", "player_turn_ended",
              "empower_toggled", "player_movement_interrupted", "item_equipped", "item_picked_up",
              "defiance_triggered"}
START_TYPES = {"combat_started", "combat_resumed", "run_resumed"}
END_REASONS = [
    ("pass", "PASS button"),
    ("wait", "PASS with plays left (a Wait)"),
    ("auto_card", "Turn ended by its last card"),
    ("auto_move", "Turn ended by its last move"),
    ("auto_other", "Turn ended by itself, other"),
    ("frozen", "Frozen (turn skipped)"),
    ("unrecorded", "Not recorded (before 22 Oct)"),
    ("hero_turn", "Your own turn (no enemy round)"),
]
MOVE_ACTIONS = {"move"}
PROJECT = Path(__file__).resolve().parents[2]


# Base catalog before the pla-07 cut. Older logs may omit intent ids.
LEGACY_BLEED_SOURCES = {
    "skitter_strike": "Tunnel Crawler",
    "pelt": "Bone Harrier",
    "razor_dive": "Vaeloryx, the Hollow Gale",
    "grave_dive": "Gallows Roc",
    "lash_of_thorns": "Briar Weaver",
    "talon_rake": "Gust Shrike",
}
LEGACY_BLEED_FOES = frozenset(LEGACY_BLEED_SOURCES.values())


def _spawned_types() -> tuple[set[str], set[str]]:
    """Foe types (and names) that only enter mid-fight: split products and summoned minions."""
    types: set[str] = set()
    try:
        enemies = json.loads((PROJECT / "data" / "enemies.json").read_text())
    except (OSError, ValueError):
        return {"cinder_droplet"}, {"Cinder Droplet"}
    if not isinstance(enemies, dict):
        return types, set()
    for enemy in enemies.values():
        if not isinstance(enemy, dict):
            continue
        spawn = enemy.get("death_spawn", {}) or {}
        if spawn.get("enemy_type"):
            types.add(str(spawn["enemy_type"]))
        for intent in enemy.get("intents", []) or []:
            for action in intent.get("actions", []) or []:
                if action.get("minion_type"):
                    types.add(str(action["minion_type"]))
                for minion in action.get("minion_types", []) or []:
                    types.add(str(minion))
    names = {str(enemies[t].get("name", "")) for t in types if isinstance(enemies.get(t), dict)}
    return types, names


SPAWNED_TYPES, SPAWNED_NAMES = _spawned_types()


def local_dt(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()


def load(data_dir: Path) -> dict[str, list[dict]]:
    profiles: dict[str, list[dict]] = defaultdict(list)
    files = sorted(p for p in data_dir.rglob("*.jsonl") if "Visual Probe" not in str(p))
    for path in sorted(files, key=lambda p: (str(p.parent), p.name)):
        profile = str(path.parent.relative_to(data_dir)) or "."
        with path.open() as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(event, dict):
                    profiles[profile].append(event)
    return profiles


def scale_of(event: dict) -> int:
    # Pre-v5 rules stored ten units per Health (a 360-Health hero).
    return 10 if int(event.get("player_max_hp", 0) or 0) >= 100 else 1


def hp_of(event: dict) -> float | None:
    hp = event.get("player_hp")
    if hp is None or int(hp) < 0:
        return None
    return int(hp) / scale_of(event)


def max_hp_of(event: dict) -> float | None:
    hp = event.get("player_max_hp")
    if hp is None or int(hp) <= 0:
        return None
    return int(hp) / scale_of(event)


def actor_id(key: str) -> int:
    try:
        return int(str(key).split("_")[-1])
    except ValueError:
        return -1


def hero_losses(payload: dict) -> list[dict]:
    return [loss for loss in payload.get("target_losses", []) or []
            if str(loss.get("key", "")) == "player" or str(loss.get("kind", "")) == "player"]


class Combat:
    def __init__(self, profile: str):
        self.profile = profile
        self.events: list[dict] = []
        self.windows: list[dict] = []
        self.name = ""
        self.started = None
        self.outcome = ""


def fight_name(events: list[dict]) -> str:
    start = next((e for e in events if e.get("event_type") == "combat_started"), None)
    env = start or events[0]
    boss = str(env.get("boss_id") or "")
    guardian = str(env.get("guardian_id") or "")
    encounter = str(env.get("encounter_id") or "")
    room = str((start or {}).get("payload", {}).get("room_name", "") or "")
    section = env.get("section_index")
    where = f"s{int(section) + 1}" if isinstance(section, int) and section >= 0 else ""
    if boss:
        names = [e["payload"].get("actor_name", "") for e in events
                 if e.get("event_type") == "enemy_action_resolved" and e["payload"].get("enemy_type") == boss]
        label = (names[0].split(",")[0] if names and names[0] else boss.title()) + " (dragon)"
    elif guardian:
        label = guardian.replace("_", " ") + " (Guardian)"
    elif encounter:
        label = re.sub(r"^t\d+_", "", encounter).replace("_", " ")
    elif room:
        label = room
    else:
        label = str(env.get("room_type") or "fight")
    special = str(env.get("special_type") or "")
    if special:
        label += f" [{special}]"
    return f"{label} {where}".strip()


def group_combats(profiles: dict[str, list[dict]]) -> list[Combat]:
    combats: dict[tuple[str, str], Combat] = {}
    order: list[Combat] = []
    for profile, events in profiles.items():
        last: Combat | None = None
        for event in events:
            cid = str(event.get("combat_id") or "")
            etype = event.get("event_type")
            if etype in SKIP_TYPES:
                continue
            if not cid:
                # The round that ends a fight is logged after the combat context is
                # cleared (no combat id, turn 0). Keep it with the fight it ends.
                if last is not None and etype in ROUND_TYPES and last.events:
                    gap = (local_dt(event["timestamp_utc"]) - local_dt(last.events[-1]["timestamp_utc"])).total_seconds()
                    if 0 <= gap <= 120:
                        patched = dict(event)
                        patched["_attached"] = True
                        patched["turn"] = last.events[-1].get("turn", 0)
                        last.events.append(patched)
                continue
            key = (profile, cid)
            if key not in combats:
                combats[key] = Combat(profile)
                order.append(combats[key])
            combats[key].events.append(event)
            last = combats[key]
    for combat in order:
        combat.events = reorder_late_turn_ends(combat.events)
        mark_reshuffles(combat.events)
    for combat in order:
        combat.name = fight_name(combat.events)
        combat.started = local_dt(combat.events[0]["timestamp_utc"])
        ended = [e for e in combat.events if e.get("event_type") == "combat_ended"]
        combat.outcome = str(ended[-1]["payload"].get("outcome", "")) if ended else "unfinished"
    return order


def mark_reshuffles(events: list[dict]) -> None:
    """Flag draws that needed a reshuffle: the draw pile grew instead of shrinking.

    Each reshuffle costs Fatigue (2 Health, +1 per earlier reshuffle this fight),
    which no event records directly.
    """
    previous: int | None = None
    cycles = 0
    for event in events:
        if event.get("event_type") != "card_drawn":
            continue
        payload = event.get("payload", {})
        size = int(payload.get("draw_pile_size", 0) or 0)
        if str(payload.get("reason", "")) != "opening_hand" and previous is not None and size >= previous:
            cycles += 1
            event["_reshuffle"] = cycles
        previous = size


def reorder_late_turn_ends(events: list[dict]) -> list[dict]:
    """Put late-delivered player_turn_ended receipts back at their hero turn's end.

    Before the activation-end outbox woke the analytics queue (Oct/early Nov
    builds), turn-end receipts could reach the JSONL file in a later batch,
    even after the fight ended. Their own envelope keeps the original turn.
    """
    late: list[dict] = []
    kept: list[dict] = []
    max_turn = 0
    ended = False
    for event in events:
        etype = event.get("event_type")
        turn = int(event.get("turn", 0) or 0)
        if etype == "player_turn_ended" and (ended or max_turn > turn):
            late.append(event)
            continue
        kept.append(event)
        if etype == "combat_ended":
            ended = True
        elif not event.get("_attached"):
            max_turn = max(max_turn, turn)
    for event in late:
        turn = int(event.get("turn", 0) or 0)
        index = len(kept)
        for i, other in enumerate(kept):
            other_turn = int(other.get("turn", 0) or 0)
            if (other_turn > turn or other.get("_attached") or other.get("event_type") == "combat_ended"
                    or (other_turn == turn and str(other.get("current_actor_kind", "")) in ("enemy", "transition"))):
                index = i
                break
        event = dict(event)
        event["_late"] = True
        kept.insert(index, event)
    return kept


def classify_end_reason(turn_end: dict | None, last_hero_action: str) -> str:
    if turn_end is None:
        return "unrecorded"
    payload = turn_end.get("payload", {})
    reason = str(payload.get("end_reason", ""))
    if reason == "pass":
        waited = int(payload.get("base_plays_waited", 0) or 0) > 0 or int(payload.get("wait_time", 0) or 0) > 0
        return "wait" if waited else "pass"
    if reason == "auto":
        return {"card_played": "auto_card", "player_moved": "auto_move"}.get(last_hero_action, "auto_other")
    if reason == "frozen":
        return "frozen"
    return "auto_other"


def segment(combat: Combat) -> None:
    """Split a combat into hero turns and enemy rounds with HP before/after.

    Enemy-round events carry the turn number of the hero turn that follows them.
    Logs before 22 Oct have no turn-end record and the earliest July logs have no
    enemy records at all; a hero event whose turn number jumps therefore implies
    an unlogged enemy round in between, kept as an empty round for its HP drop.
    """
    windows: list[dict] = []
    cur: dict | None = None
    hero_after: float | None = None
    pending_end: dict | None = None  # player_turn_ended not yet followed by a round
    last_hero_action = ""
    pending_move: dict | None = None
    recent_surface: list[dict] = []
    prev_surface: list[dict] = []
    last_hero_turn = 0
    has_turn_records = any(e.get("event_type") == "player_turn_ended" for e in combat.events)

    def open_window(kind: str, turn: int, hp_before: float | None, first: dict) -> dict:
        window = {"kind": kind, "turn": turn, "events": [], "hp_before": hp_before, "hp_after": hp_before,
                  "max_hp": max_hp_of(first), "losses": [], "end_reason": "hero_turn",
                  "when": local_dt(first["timestamp_utc"]), "turn_end": None, "pending_move": None}
        windows.append(window)
        return window

    def open_round(turn: int, first: dict) -> dict:
        nonlocal pending_end, pending_move
        window = open_window("round", turn, hero_after, first)
        # The hero turn this round follows (a fight-ending round keeps that turn's number).
        window["after_turn"] = last_hero_turn if last_hero_turn else max(turn - 1, 0)
        if pending_end is not None:
            window["end_reason"] = classify_end_reason(pending_end, last_hero_action)
            window["turn_end"] = pending_end
        else:
            window["end_reason"] = "unrecorded" if not has_turn_records else "auto_other"
        window["pending_move"] = pending_move
        pending_end = None
        pending_move = None
        return window

    for event in combat.events:
        etype = event.get("event_type")
        hp = None if event.get("_late") else hp_of(event)
        turn = int(event.get("turn", 0) or 0)
        payload = event.get("payload", {})
        if etype == "card_drawn":
            # Neutral: a turn's opening draws belong to the round before it (its
            # Fatigue is part of that round's drop); a card's draws precede the card.
            if str(payload.get("reason", "")) == "card_effect" and cur is not None and cur["kind"] == "hero":
                recent_surface.append(event)
            elif windows:
                windows[-1]["events"].append(event)
            continue
        is_round = etype in ROUND_TYPES
        if etype == "surface_event":
            is_round = (
                (cur is not None and cur["kind"] == "round")
                or str(event.get("current_actor_kind", "")) == "transition"
                or (cur is not None and cur["kind"] == "hero" and turn > cur["turn"])
                or pending_end is not None
            )
        if etype == "combat_ended" and str(payload.get("reason", "")) == "enemy_round":
            is_round = True
        if etype in START_TYPES:
            cur = open_window("hero", turn, hp, event)
            last_hero_turn = turn
            hero_after = hp
            pending_end = None
            pending_move = None
            cur["events"].append(event)
            continue
        if is_round:
            if cur is None or cur["kind"] != "round":
                cur = open_round(turn, event)
            cur["events"].append(event)
            # Rule beats are flushed at the hero's turn end, before the enemies act.
            if hp is not None and not (etype in ("battlefield_rule_fired", "battlefield_rule_switched")
                                       or str(event.get("current_actor_kind", "")) == "transition"):
                cur["hp_after"] = hp
            if etype == "player_turn_started":
                hero_after = cur["hp_after"]
                cur = None
            continue
        # Hero-phase or bookkeeping event.
        if cur is not None and cur["kind"] == "round":
            hero_after = cur["hp_after"]
            cur = None
        if cur is not None and cur["kind"] == "hero" and turn > cur["turn"] and etype != "combat_ended":
            # The turn advanced with no enemy records: an unlogged enemy round.
            empty = open_round(turn, event)
            empty["empty"] = True
            empty["hp_after"] = hp if hp is not None else hero_after
            hero_after = empty["hp_after"]
            cur = None
        if cur is None:
            cur = open_window("hero", turn, hero_after, event)
            recent_surface = []
            prev_surface = []
        if etype in HERO_TYPES:
            last_hero_turn = turn
        cur["events"].append(event)
        if etype == "surface_event":
            recent_surface.append(event)
            continue
        if hp is not None and hero_after is not None and hp < hero_after - 1e-9:
            # A drop between hero events: the previous hero action caused it.
            cur["losses"].append({"amount": hero_after - hp, "category": None, "detail": "between",
                                  "after_move": pending_move, "event": event,
                                  "surface": prev_surface + recent_surface})
        if hp is not None:
            hero_after = hp
        if etype == "card_played":
            delta = float(payload.get("player_hp_delta", 0) or 0) / scale_of(event)
            empower = payload.get("empower_cost") if bool(payload.get("empowered", False)) else None
            cost = (float(payload.get("printed_health_cost", 0) or 0)
                    + (float(empower.get("health", 0) or 0) if isinstance(empower, dict) else 0.0)) / scale_of(event)
            if delta < 0 or cost > 0:
                cur["losses"].append({"amount": max(-delta, 0.0), "cost": cost, "category": None,
                                      "detail": "card", "event": event, "surface": list(recent_surface)})
            if hero_after is not None:
                hero_after = hero_after + delta
            last_hero_action = "card_played"
            pending_move = None
        elif etype == "player_moved":
            last_hero_action = "player_moved"
            pending_move = event
        elif etype == "player_turn_ended":
            pending_end = event
        elif etype == "combat_ended":
            pending_move = None
        prev_surface = recent_surface
        recent_surface = []
        cur["hp_after"] = hero_after
    combat.windows = windows


def attribute(combat: Combat) -> None:
    seen_keys: set[str] = set()
    initial_count = 0
    start = next((e for e in combat.events if e.get("event_type") == "combat_started"), None)
    if start is not None:
        initial_count = int(start.get("payload", {}).get("objective_initial_enemy_count", 0) or 0)
    previous_round: dict | None = None
    for window in combat.windows:
        if window["kind"] == "hero":
            attribute_hero(window, previous_round)
            continue
        acts: list[dict] = []  # activation segmentation
        by_actor: Counter = Counter()
        new_keys: set[str] = set()
        explicit = 0.0
        last = None  # (actor, intent, saw_non_move)
        for event in window["events"]:
            etype = event.get("event_type")
            payload = event.get("payload", {})
            if etype == "enemy_status_tick" and str(payload.get("trigger", "")) == "turn_start":
                key = str(payload.get("actor_key", ""))
                if key and by_actor[key] > 0 and last is not None and last[0] == key and last[3] > 0:
                    last = None  # a turn-start tick opens a fresh activation of the same foe
                if key and (last is None or last[0] != key):
                    by_actor[key] += 1
                    last = [key, None, False, 0]
                    acts.append({"actor": key, "n": by_actor[key], "events": []})
                if key:
                    acts[-1]["events"].append(event)
                continue
            if etype != "enemy_action_resolved":
                continue
            key = str(payload.get("actor_key", ""))
            intent = str(payload.get("intent_id", "") or "")
            action = str(payload.get("action_type", "") or "")
            is_move = action in MOVE_ACTIONS
            new_act = (
                last is None or last[0] != key
                or (intent and last[1] and intent != last[1])
                or (is_move and last[2] and intent != "crownfire")
            )
            if new_act:
                by_actor[key] += 1
                last = [key, intent or None, False, 0]
                acts.append({"actor": key, "n": by_actor[key], "events": []})
            if intent and not last[1]:
                last[1] = intent
            if not is_move and action not in ("status", "") and not payload.get("no_action_reason"):
                last[2] = True
            last[3] += 1
            acts[-1]["events"].append(event)
            if key not in seen_keys and key not in new_keys:
                # Arrived this round: a split product or summoned minion, or (when the
                # start record gives the roster size) any id beyond the opening roster.
                ident = actor_id(key)
                arrived = (str(payload.get("enemy_type", "")) in SPAWNED_TYPES
                           or str(payload.get("actor_name", "")) in SPAWNED_NAMES
                           or (initial_count > 0 and ident > initial_count))
                if arrived:
                    new_keys.add(key)
            for loss in hero_losses(payload):
                amount = float(loss.get("hp_loss", 0) or 0) / scale_of(event)
                if amount <= 0:
                    continue
                if key in new_keys:
                    category = "new_foe"
                elif by_actor[key] >= 2:
                    category = "repeat"
                else:
                    category = "first"
                window["losses"].append({"amount": amount, "category": category, "actor": key,
                                         "enemy": payload.get("actor_name") or payload.get("enemy_type") or key,
                                         "intent": intent, "action": action, "activation": by_actor[key],
                                         "detail": action, "event": event})
                explicit += amount
        for event in window["events"]:
            etype = event.get("event_type")
            payload = event.get("payload", {})
            if etype == "battlefield_rule_fired":
                amount = float(payload.get("damage_to_player", 0) or 0) / scale_of(event)
                if amount > 0:
                    window["losses"].append({"amount": amount, "category": "rule", "detail": str(payload.get("rule", "")),
                                             "enemy": str(payload.get("source_type", "") or "room"), "event": event})
                    explicit += amount
            elif etype == "surface_event" and str(payload.get("kind", "")) == "surface_damage" and str(payload.get("actor_key", "")) == "player":
                phase = str(payload.get("source", {}).get("phase", ""))
                if phase == "activation_start":
                    amount = float(payload.get("health_lost", payload.get("amount", 0)) or 0) / scale_of(event)
                    if amount > 0:
                        window["losses"].append({"amount": amount, "category": "surface",
                                                 "detail": f"{payload.get('surface', 'fire')} under you at turn start",
                                                 "enemy": "", "event": event})
                        explicit += amount
            elif etype == "enemy_status_tick" and payload.get("target_losses"):
                for loss in hero_losses(payload):
                    amount = float(loss.get("hp_loss", 0) or 0) / scale_of(event)
                    if amount > 0:
                        window["losses"].append({"amount": amount, "category": "surface",
                                                 "detail": f"{payload.get('action_type', '')} chain reaction",
                                                 "enemy": payload.get("actor_name", ""), "event": event})
                        explicit += amount
        before, after = window["hp_before"], window["hp_after"]
        drop = (before - after) if (before is not None and after is not None) else 0.0
        window["drop"] = drop
        window["activations"] = len(acts)
        window["acts"] = acts
        residual = drop - explicit
        if window.get("pending_move") is not None and residual > 1e-9:
            # Old logs (no turn-end record): the hero's last move ended the turn, so
            # its own hazard damage folds into this round's drop.
            surf = [e for e in window["events"] if e.get("event_type") == "surface_event"
                    and str(e["payload"].get("actor_key", "")) == "player" and str(e["payload"].get("kind", "")) == "surface_damage"]
            for event in surf:
                amount = min(residual, float(event["payload"].get("health_lost", 0) or 0) / scale_of(event))
                if amount > 0:
                    window["losses"].append({"amount": amount, "category": "surface", "detail": "walked into fire",
                                             "enemy": "", "event": event})
                    residual -= amount
        for event in window["events"]:
            cycle = event.get("_reshuffle")
            if residual > 1e-9 and cycle and str(event["payload"].get("reason", "")) == "turn_draw":
                amount = min(residual, 2.0 + cycle - 1)
                window["losses"].append({"amount": amount, "category": "fatigue", "detail": "reshuffle at turn start",
                                         "enemy": "", "event": event})
                residual -= amount
        if residual > 1e-9:
            window["losses"].append({"amount": residual, "category": "unknown", "detail": unknown_reason(window),
                                     "enemy": "", "event": window["events"][-1] if window["events"] else None})
        window["masked_heal"] = max(0.0, -residual) if residual < -1e-9 else 0.0
        for act in acts:
            seen_keys.add(act["actor"])
        previous_round = window


def unknown_reason(window: dict) -> str:
    if window.get("empty"):
        return "enemy round left no events"
    actors = sorted({e["payload"].get("actor_name", "") for e in window["events"]
                     if e.get("event_type") == "enemy_action_resolved"})
    era = "old" if all(e.get("rules_version") is None for e in window["events"]) else "v5"
    if era == "old":
        return "old log: no record covers it"
    return "no record covers it (acting: %s)" % (", ".join(a for a in actors if a) or "nobody")


def attribute_hero(window: dict, previous_round: dict | None) -> None:
    bleed_source = bleed_hit(previous_round)
    resolved: list[dict] = []
    for loss in window["losses"]:
        event = loss["event"]
        surf = loss.get("surface", [])
        if loss["detail"] == "card":
            cost = loss.get("cost", 0.0)
            card = str(event.get("card_id", ""))
            if cost > 0:
                resolved.append({**loss, "amount": cost, "category": "self", "detail": "card or Empower Health cost",
                                 "enemy": "", "card": card})
            # A heal in the same card can hide part of the cost from the net delta.
            rest = loss["amount"] - cost
            if rest > 1e-9:
                category, detail = hero_card_rest(event, surf, bleed_source)
                resolved.append({**loss, "amount": rest, "category": category, "detail": detail, "enemy": "",
                                 "card": card})
            continue
        move = loss.get("after_move")
        hazard = [e for e in surf if str(e["payload"].get("actor_key", "")) == "player"
                  and str(e["payload"].get("kind", "")) == "surface_damage"]
        if hazard:
            category, detail = "surface", f"walked into {hazard[0]['payload'].get('surface', 'fire')}"
        elif move is not None and any(str(e["payload"].get("kind", "")) == "trap_triggered" for e in surf):
            category, detail = "surface", "walked onto a trap"
        elif move is not None and bleed_source:
            category, detail = "status", "Bleed paid as you move"
        elif move is not None:
            category, detail = "unknown", "lost while moving, nothing recorded"
        else:
            category, detail = "unknown", "hero turn, between events"
        resolved.append({**loss, "category": category, "detail": detail, "enemy": ""})
    window["losses"] = [loss for loss in resolved if loss["amount"] > 1e-9]
    before, after = window["hp_before"], window["hp_after"]
    window["drop"] = (before - after) if (before is not None and after is not None) else 0.0
    window["masked_heal"] = 0.0


def bleed_hit(round_window: dict | None) -> str:
    """A foe whose attack applies Bleed hit the hero in the round before this turn."""
    if round_window is None:
        return ""
    for event in round_window["events"]:
        if event.get("event_type") != "enemy_action_resolved":
            continue
        payload = event.get("payload", {})
        if payload.get("status_riders_retired") or not any(float(l.get("amount", 0) or 0) > 0 for l in hero_losses(payload)):
            continue
        intent = str(payload.get("intent_id", "") or "")
        if intent:
            if intent in LEGACY_BLEED_SOURCES:
                return str(payload.get("actor_name", ""))
        elif str(payload.get("actor_name", "")) in LEGACY_BLEED_FOES:
            return str(payload.get("actor_name", ""))
    return ""


def hero_card_rest(event: dict, surf: list[dict], bleed_source: str) -> tuple[str, str]:
    payload = event.get("payload", {})
    applied = payload.get("player_status_applied", {}) or {}
    kinds = Counter(str(e["payload"].get("kind", "")) for e in surf if e.get("event_type") == "surface_event" and (
        str(e["payload"].get("actor_key", "")) == "player" or str(e["payload"].get("target_kind", "")) == "player"))
    if any(e.get("_reshuffle") for e in surf if e.get("event_type") == "card_drawn"):
        return "fatigue", "reshuffle while drawing from a card"
    if kinds.get("retaliate_triggered"):
        return "self", "Retaliate from the foe you struck"
    if kinds.get("surface_damage"):
        return "surface", "walked into a hazard during a card"
    if any(int(v or 0) > 0 for k, v in applied.items() if k != "chilled") or int(payload.get("traps_triggered", 0) or 0) > 0 and (
            float(payload.get("player_hp_delta", 0) or 0) / scale_of(event) <= -3):
        return "self", "your own card hit you (blast, trap or chain)"
    if bleed_source:
        return "status", "Bleed paid as you act"
    return "unknown", "lost on your own card, nothing recorded"


def losses_of(combats: list[Combat]):
    for combat in combats:
        for index, window in enumerate(combat.windows):
            for loss in window["losses"]:
                yield combat, index, window, loss


def fmt(value: float) -> str:
    return f"{value:.1f}".rstrip("0").rstrip(".") if abs(value - round(value)) > 1e-9 else str(int(round(value)))


def window_end_state(window: dict) -> str:
    after, max_hp = window["hp_after"], window["max_hp"]
    if after is None or not max_hp:
        return ""
    if after <= 0:
        return "death"
    if after <= 0.25 * max_hp:
        return "near"
    return ""


def table(rows: list[list[str]], header: list[str]) -> str:
    out = ["| " + " | ".join(header) + " |", "|" + "|".join("---:" if i else "---" for i in range(len(header))) + "|"]
    out += ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(out)


def category_stats(combats: list[Combat], keep=lambda window: True) -> dict:
    total = Counter()
    biggest: dict[str, float] = {}
    rounds: dict[str, set] = defaultdict(set)
    deaths: dict[str, set] = defaultdict(set)
    nears: dict[str, set] = defaultdict(set)
    for combat, index, window, loss in losses_of(combats):
        if not keep(window):
            continue
        cat = loss["category"]
        total[cat] += loss["amount"]
        biggest[cat] = max(biggest.get(cat, 0.0), loss["amount"])
        ident = (id(combat), index)
        rounds[cat].add(ident)
        state = window_end_state(window)
        if state == "death":
            deaths[cat].add(ident)
        elif state == "near":
            nears[cat].add(ident)
    return {"total": total, "biggest": biggest, "rounds": rounds, "deaths": deaths, "nears": nears,
            "grand": sum(total.values())}


def category_table(combats: list[Combat], keep=lambda window: True, recent_from: datetime | None = None) -> tuple[str, float]:
    """Health lost per source; with recent_from, add the share from that date on."""
    stats = category_stats(combats, keep)
    recent = category_stats(combats, lambda w: keep(w) and w["when"] >= recent_from) if recent_from else None
    grand = stats["grand"]
    rows = []
    union = lambda groups: str(len(set().union(*groups.values())) if groups else 0)
    for key, label in CATEGORIES:
        total = stats["total"].get(key, 0.0)
        row = [label, fmt(total), f"{100 * total / grand:.0f}%" if grand else "-",
               fmt(stats["biggest"][key]) if key in stats["biggest"] else "-",
               str(len(stats["rounds"][key])), str(len(stats["deaths"][key])), str(len(stats["nears"][key]))]
        if recent is not None:
            part = recent["total"].get(key, 0.0)
            row += [fmt(part), f"{100 * part / recent['grand']:.0f}%" if recent["grand"] else "-"]
        rows.append(row)
    row = ["All", fmt(grand), "100%" if grand else "-", fmt(max(stats["biggest"].values()) if stats["biggest"] else 0),
           union(stats["rounds"]), union(stats["deaths"]), union(stats["nears"])]
    header = ["Source", "Health lost", "Share", "Largest hit", "Turns/rounds", "Deaths", "Near-deaths"]
    if recent is not None:
        row += [fmt(recent["grand"]), "100%" if recent["grand"] else "-"]
        header += [f"From {recent_from:%d %b}", "Share"]
    rows.append(row)
    return table(rows, header), grand


def end_reason_table(combats: list[Combat]) -> str:
    total = Counter()
    rounds = Counter()
    hit_rounds = Counter()
    by_cat: dict[str, Counter] = defaultdict(Counter)
    for combat in combats:
        for window in combat.windows:
            if window["kind"] != "round":
                continue
            reason = window["end_reason"]
            rounds[reason] += 1
            lost = sum(l["amount"] for l in window["losses"])
            if lost > 0:
                hit_rounds[reason] += 1
            total[reason] += lost
            for loss in window["losses"]:
                by_cat[reason][loss["category"]] += loss["amount"]
    for combat in combats:
        for window in combat.windows:
            if window["kind"] == "hero":
                lost = sum(l["amount"] for l in window["losses"])
                if lost > 0:
                    rounds["hero_turn"] += 1
                    hit_rounds["hero_turn"] += 1
                    total["hero_turn"] += lost
                    for loss in window["losses"]:
                        by_cat["hero_turn"][loss["category"]] += loss["amount"]
    grand = sum(total.values())
    rows = []
    for key, label in END_REASONS:
        if not rounds.get(key):
            continue
        mix = ", ".join(f"{LABEL[c].split(' (')[0].lower()} {fmt(v)}" for c, v in by_cat[key].most_common(3))
        rows.append([label, str(rounds[key]) if key != "hero_turn" else "-", str(hit_rounds[key]), fmt(total[key]),
                     f"{100 * total[key] / grand:.0f}%" if grand else "-", mix])
    return table(rows, ["How the turn ended", "Enemy rounds", "Rounds that hurt", "Health lost", "Share", "Main sources"])


def big_rounds(combats: list[Combat], count: int) -> list[tuple]:
    rows = []
    for combat in combats:
        for index, window in enumerate(combat.windows):
            if window["kind"] != "round":
                continue
            lost = sum(l["amount"] for l in window["losses"])
            if lost <= 0:
                continue
            rows.append((lost, combat, index, window))
    rows.sort(key=lambda r: (-r[0], r[3]["when"]))
    return rows[:count]


def big_round_table(combats: list[Combat], count: int) -> str:
    rows = []
    for lost, combat, index, window in big_rounds(combats, count):
        enemies = Counter()
        cats = Counter()
        for loss in window["losses"]:
            name = str(loss.get("enemy") or "")
            if name:
                enemies[name.split(",")[0]] += loss["amount"]
            cats[loss["category"]] += loss["amount"]
        state = window_end_state(window)
        hp = f"{fmt(window['hp_before'])}→{fmt(window['hp_after'])}/{fmt(window['max_hp'])}"
        rows.append([window["when"].strftime("%d %b"), combat.name, str(window.get("after_turn", window["turn"])), fmt(lost), hp,
                     ", ".join(f"{n} {fmt(v)}" for n, v in enemies.most_common()) or "-",
                     ", ".join(f"{c} {fmt(v)}" for c, v in cats.most_common()),
                     dict(END_REASONS)[window["end_reason"]].split(" (")[0] + (" · " + state if state else "")])
    return table(rows, ["Date", "Fight", "After turn", "Lost", "Health", "Enemies", "Categories", "Turn ended by"])


def deaths_table(combats: list[Combat]) -> str:
    rows = []
    for combat in combats:
        for index, window in enumerate(combat.windows):
            state = window_end_state(window)
            if state != "death" or not window["losses"]:
                continue
            cats = Counter()
            enemies = Counter()
            for loss in window["losses"]:
                cats[loss["category"]] += loss["amount"]
                if loss.get("enemy"):
                    enemies[str(loss["enemy"]).split(",")[0] + (" (" + str(loss.get("intent")) + ")" if loss.get("intent") else "")] += loss["amount"]
                elif loss.get("card"):
                    enemies[str(loss["card"])] += loss["amount"]
            rows.append([window["when"].strftime("%d %b"), combat.name, f"{fmt(window['hp_before'])}→0/{fmt(window['max_hp'])}",
                         ", ".join(f"{c} {fmt(v)}" for c, v in cats.most_common()),
                         ", ".join(f"{n} {fmt(v)}" for n, v in enemies.most_common()) or "-",
                         "your turn" if window["kind"] == "hero" else dict(END_REASONS)[window["end_reason"]].split(" (")[0]])
    return table(rows, ["Date", "Fight", "Health", "Categories", "By", "Turn ended by"])


def detail_table(combats: list[Combat]) -> str:
    detail = Counter()
    for _combat, _index, _window, loss in losses_of(combats):
        detail[(loss["category"], str(loss.get("detail", "")))] += loss["amount"]
    rows = [[LABEL[c], d, fmt(v)] for (c, d), v in sorted(detail.items(), key=lambda kv: (-kv[1], kv[0]))]
    return table(rows, ["Source", "Detail", "Health lost"])


def coverage(combats: list[Combat], profiles: dict[str, list[dict]]) -> str:
    lines = []
    for profile, events in sorted(profiles.items()):
        if not events:
            continue
        days = sorted({local_dt(e["timestamp_utc"]).date() for e in events if e.get("timestamp_utc")})
        fights = [c for c in combats if c.profile == profile]
        rounds = sum(1 for c in fights for w in c.windows if w["kind"] == "round")
        deaths = sum(1 for c in fights if c.outcome == "defeat")
        lines.append(f"- {profile}: {len(events)} events, {days[0]:%d %b} to {days[-1]:%d %b} ({len(days)} days), "
                     f"{len(fights)} fights, {rounds} enemy rounds, {deaths} deaths")
    return "\n".join(lines)


def checks(combats: list[Combat]) -> str:
    out = []
    seg_ok = seg_n = 0
    for combat in combats:
        for window in combat.windows:
            end = window.get("turn_end")
            if window["kind"] != "round" or end is None:
                continue
            expected = int(end["payload"].get("enemy_activations_before_next_turn", 0) or 0)
            seg_n += 1
            seg_ok += int(expected == window.get("activations", 0))
    out.append(f"- activation split matches enemy_activations_before_next_turn in {seg_ok}/{seg_n} recorded rounds")
    explicit = sum(l["amount"] for _c, _i, _w, l in losses_of(combats) if l["category"] != "unknown")
    unknown = sum(l["amount"] for _c, _i, _w, l in losses_of(combats) if l["category"] == "unknown")
    drops = sum(max(w.get("drop", 0.0), 0.0) for c in combats for w in c.windows)
    masked = sum(w.get("masked_heal", 0.0) for c in combats for w in c.windows)
    out.append(f"- attributed {fmt(explicit)} + unknown {fmt(unknown)}; net window drops {fmt(drops)}; "
               f"heals inside enemy rounds hid {fmt(masked)}")
    hidden = sum(int(e["payload"].get("umbra_hidden_attack_damage_received", 0) or 0) for c in combats
                 for e in c.events if e.get("event_type") == "combat_ended")
    out.append(f"- combat_ended umbra_hidden_attack_damage_received total: {hidden}")
    return "\n".join(out)


def spot(combats: list[Combat], ranks: list[int]) -> str:
    out = []
    ranked = big_rounds(combats, max(ranks) if ranks else 0)
    for rank in ranks:
        if rank < 1 or rank > len(ranked):
            continue
        lost, combat, index, window = ranked[rank - 1]
        out.append(f"#{rank}")
        prev = combat.windows[index - 1] if index else None
        out.append(f"### {window['when']:%d %b %H:%M} {combat.name}, enemy round after hero turn {window.get('after_turn')}: "
                   f"lost {fmt(lost)} ({fmt(window['hp_before'])} -> {fmt(window['hp_after'])})")
        events = (prev["events"][-3:] if prev else []) + window["events"]
        for event in events:
            p = event.get("payload", {})
            etype = event.get("event_type")
            line = f"  {event.get('sequence')} t{event.get('turn')} hp={fmt(hp_of(event) or 0)} {etype}"
            if etype == "enemy_action_resolved":
                line += (f" {p.get('actor_key')} {p.get('actor_name')} intent={p.get('intent_id')} {p.get('action_type')} "
                         f"from={tile(p.get('from'))} to={tile(p.get('to'))} hero_losses="
                         f"{[(l.get('hp_loss'), l.get('block_loss'), l.get('stoneskin_loss')) for l in hero_losses(p)]}")
            elif etype == "player_turn_ended":
                line += (f" end_reason={p.get('end_reason')} activations={p.get('enemy_activations_before_next_turn')} "
                         f"plays={p.get('plays_made')} waited={p.get('base_plays_waited')}")
            elif etype == "card_played":
                line += f" {event.get('card_id')} hp_delta={p.get('player_hp_delta')} cost={p.get('printed_health_cost')}"
            elif etype == "player_moved":
                line += f" {tile(p.get('origin'))}->{tile(p.get('destination'))}"
            elif etype == "enemy_status_tick":
                line += f" {p.get('actor_key')} {p.get('label')} {p.get('amount')} {p.get('trigger')}"
            elif etype == "battlefield_rule_fired":
                line += f" {p.get('rule')} damage_to_player={p.get('damage_to_player')}"
            elif etype == "surface_event":
                line += f" {p.get('kind')} {p.get('surface', '')} actor={p.get('actor_key', '')} tile={tile(p.get('tile'))}"
            out.append(line)
        out.append("  attributed: " + "; ".join(
            f"{fmt(l['amount'])} {l['category']} ({l.get('enemy') or ''} {l.get('intent') or l.get('detail') or ''}"
            f"{' activation ' + str(l['activation']) if l.get('activation') else ''})" for l in window["losses"]))
    return "\n".join(out)


def tile(value) -> str:
    if isinstance(value, dict):
        return f"({value.get('x')},{value.get('y')})"
    return str(value)


def export(combats: list[Combat], path: Path) -> None:
    rows = []
    for combat, index, window, loss in losses_of(combats):
        rows.append({"date": window["when"].isoformat(timespec="minutes"), "fight": combat.name, "outcome": combat.outcome,
                     "window": window["kind"], "turn": window["turn"], "end_reason": window["end_reason"],
                     "amount": loss["amount"], "category": loss["category"], "detail": str(loss.get("detail", "")),
                     "enemy": str(loss.get("enemy") or ""), "intent": str(loss.get("intent") or ""),
                     "activation": loss.get("activation"), "hp_before": window["hp_before"], "hp_after": window["hp_after"],
                     "max_hp": window["max_hp"], "end_state": window_end_state(window)})
    path.write_text(json.dumps(rows, indent=1) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("--cutoff", default="2026-11-14", help="local date (or ISO time) atk-01..04 shipped")
    parser.add_argument("--top", type=int, default=15)
    parser.add_argument("--recent", default="2026-10-01", help="also report the share from this local date on (\"\" to skip)")
    parser.add_argument("--spot", type=int, default=0, help="print raw events of the N biggest enemy rounds")
    parser.add_argument("--spot-ranks", default="", help="comma-separated ranks among the biggest rounds, e.g. 1,4,10")
    parser.add_argument("--json", type=Path, help="write every attributed loss row (no ids) here")
    args = parser.parse_args()
    profiles = load(args.data_dir)
    if not profiles:
        print(f"no events-*.jsonl under {args.data_dir}", file=sys.stderr)
        return 1
    combats = group_combats(profiles)
    for combat in combats:
        segment(combat)
        attribute(combat)
    cutoff = datetime.fromisoformat(args.cutoff)
    if cutoff.tzinfo is None:
        cutoff = cutoff.astimezone()
    print("## Coverage\n" + coverage(combats, profiles) + "\n")
    print("## Checks\n" + checks(combats) + "\n")
    recent = datetime.fromisoformat(args.recent).astimezone() if args.recent else None
    text, _grand = category_table(combats, recent_from=recent)
    print("## Health lost by source (all fights)\n" + text + "\n")
    print("## How the turn before the loss ended\n" + end_reason_table(combats) + "\n")
    print(f"## {args.top} biggest enemy rounds\n" + big_round_table(combats, args.top) + "\n")
    print("## Deaths\n" + deaths_table(combats) + "\n")
    before, _ = category_table(combats, lambda w: w["when"] < cutoff)
    after, after_total = category_table(combats, lambda w: w["when"] >= cutoff)
    print(f"## Before {cutoff:%Y-%m-%d %H:%M %Z}\n" + before + "\n")
    print(f"## From {cutoff:%Y-%m-%d %H:%M %Z}" + (" (no data)" if not after_total else "") + "\n" + after + "\n")
    print("## Detail\n" + detail_table(combats) + "\n")
    if args.spot or args.spot_ranks:
        ranks = [int(r) for r in args.spot_ranks.split(",")] if args.spot_ranks else list(range(1, args.spot + 1))
        print("## Spot checks\n" + spot(combats, ranks))
    if args.json:
        export(combats, args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
