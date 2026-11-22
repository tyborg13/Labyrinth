#!/usr/bin/env python3
"""Read QA122 headless receipts and check literal claims against state changes.

Run with the evidence directory. Candidate output needs source review where
defenses, optional actions, or terrain can account for a numeric difference.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re

INTEGER = re.compile(r"^[+−-]?\d+$")
PLACEMENT_COPY = re.compile(r"\b(?:Leave (?:Fire|Ice) on|Raise Outcrops on|Mark) (\d+) tiles within range (\d+)")
QUICKEN_COPY = re.compile(r"costs (\d+) less Time")
FROSTBITE_NUMBER = re.compile(r"Frostbite hits everyone on Ice for (\d+)")
EVENT_NUMBER = re.compile(r"^(Heal|Lose|Gain|Pay) (\d+) (?:@icon\(health\)|Embers)")
ATTACKS = {"melee", "ranged", "aoe", "all_enemies"}
DIRECT_CAPTION = {"melee", "ranged", "aoe"}
DAMAGE = {"melee", "ranged", "aoe", "pierce", "all_enemies"}
STATUS = {"bleed", "expose", "shock", "stagger", "retaliate"}
SELF = {"block", "stoneskin", "heal", "draw", "card_play"}
FAMILIES = ("cards", "enemies", "events", "omens", "relics", "battlefields", "status")


def value(token):
    number = token["value"]
    return int(number.replace("−", "-")) if INTEGER.fullmatch(number) else None


def pair(changes, key, fallback=None):
    return changes.get(key, (fallback, fallback))


def difference(changes, key):
    old, new = pair(changes, key, 0)
    return (new or 0) - (old or 0)


def field_difference(changes, key, field):
    old, new = pair(changes, key, {})
    return (new.get(field, 0) or 0) - (old.get(field, 0) or 0)


def distance(left, right):
    return sum(abs(a - b) for a, b in zip(left, right))


def test(out, counter, field, expected, actual, text):
    counter[field] += 1
    if expected != actual:
        out.append({"claim": field, "shown": expected, "observed": actual, "context": text})


def cards(row, out, counter):
    finish = row["finish"]
    if row["complete"]:
        test(out, counter, "card time", int(row["time"]),
             difference(finish, "player_turn_time_spent"), row["face"])
        cost = row["tokens"][0] if row["tokens"] else []
        exhaust = any(t["icon"] == "exhaust" and t["tooltip"] for t in cost)
        consume = any(t["icon"] == "consume" for t in cost)
        pay_rows = cost + [token for group in row["tokens"] for token in group
                           if row["mode"] == "empower" and "Empower cost:" in token["tooltip"]]
        health = sum(abs(value(token) or 0) for token in pay_rows if token["icon"] == "health_cost")
        if health:
            test(out, counter, "card Health payment", health, -field_difference(finish, "hero", "hp"), row["face"])
        rite = any(t["icon"] == "rite" for t in cost) and any(s["type"] == "rite" for s in row["steps"])
        flurry = any(t["icon"] == "flurry" for t in cost)
        empowered = (t for group in row["tokens"] for t in group
                     if row["mode"] == "empower" and t["icon"] == "exhaust"
                     and "Empower" in t["tooltip"])
        if consume or exhaust or rite or any(empowered):
            want = "consume" if consume else "burn"
            test(out, counter, "card destination", want, finish["last_card_destination"][1], row["face"])
        test(out, counter, "card plays spent", 3 if flurry else 1,
             difference(finish, "cards_played_this_turn"), row["face"])
    for index, step in enumerate(row["steps"]):
        counter["eligible action" if step["eligible"] else "ineligible action"] += 1
        if not step["eligible"]:
            continue
        check_card_action(row, step, index, out, counter)


def check_card_action(row, step, index, out, counter):
    change = step["delta"]
    action = step["type"]
    before, after = pair(change, "enemies", {})
    local = f"{row['face']} / action {index + 1}, {action}, aim {step['target']}"
    plain = row["profile"] in {"neutral", "far"} and not row["mods"] and row["mode"] == "play"
    target_ids = [actor_id for actor_id, actor in before.items() if actor["pos"] == step["target"]]
    check_ground_shape(step, local, out, counter)
    for token in step["tokens"]:
        icon, expected = token["icon"], value(token)
        if expected is None or expected < 0:
            continue
        if icon == "range" and step["legal"] and action in {"melee", "ranged", "surface", "outcrop"}:
            longest = max(distance(step["hero_pos"], p) for p in step["legal"])
            test(out, counter, "printed range upper bound", True, longest <= expected, local)
        if action == icon and icon in {"move", "blink"} and "hero" in change:
            _, new = change["hero"]
            moved = distance(step["hero_pos"], new["pos"])
            test(out, counter, "movement upper bound", True, moved <= expected, local)
        if icon in SELF and icon == action and (plain or icon != "block"):
            if icon == "draw":
                actual = field_difference(change, "piles", "hand")
            elif icon == "card_play":
                actual = difference(change, "card_play_bonus_this_turn")
            else:
                actual = field_difference(change, "hero", "hp" if icon == "heal" else icon)
            test(out, counter, f"card {icon}", expected, actual, local)
        collision = any(event.get("kind") == "force_collision" for event in step.get("events", []))
        if icon in DAMAGE and plain and action in ATTACKS and len(target_ids) == 1 and not collision:
            actor_id = target_ids[0]
            a, b = before[actor_id], after[actor_id]
            if not any(a.get(key) for key in ("freeze", "chilled", "expose", "block", "stoneskin")):
                test(out, counter, "card primary loss", expected, a["hp"] - b["hp"], local)
        if icon in STATUS and action in {"melee", "ranged"} and len(target_ids) == 1 and plain:
            actor_id = target_ids[0]
            if icon == "stagger":
                counter["stagger needs schedule review"] += 1
                continue
            actual = after[actor_id].get(icon, 0) - before[actor_id].get(icon, 0)
            test(out, counter, "card status " + icon, expected, actual, local)


def translation_key(points):
    minimum_x = min(p[0] for p in points)
    minimum_y = min(p[1] for p in points)
    return sorted((x - minimum_x, y - minimum_y) for x, y in points)


def check_ground_shape(step, local, out, counter):
    if step["type"] != "surface":
        return
    pattern = next((t["pattern"] for t in step["tokens"] if t.get("pattern")), [])
    actual = [e["tile"] for e in step["events"] if e["kind"] in {"surface_created", "surface_replaced"}]
    if not pattern or len(pattern) != len(actual):
        return  # The fixture can clip the diagram at a wall or pre-existing ground.
    reference = translation_key(actual)
    candidates = []
    for _ in range(4):
        candidates.append(translation_key(pattern))
        pattern = [(-y, x) for x, y in pattern]
    test(out, counter, "ground diagram footprint up to rotation", True, reference in candidates, local)


def placement_claim(row, claims, out, counter):
    match = claims.get(row["id"])
    if not match or row["mods"]:
        return
    reach, text = match
    for step in row["steps"]:
        affected = []
        for event in step["events"]:
            if event["kind"] in {"surface_created", "terrain_created"}:
                affected.append(event["tile"])
            if event["kind"] == "meteor_marked":
                affected.extend(event["tiles"])
        if affected:
            maximum = max(distance(step["hero_pos"], tile) for tile in affected)
            counter["prose placement range"] += 1
            if maximum > reach:
                out.append({"claim": "prose placement range", "shown": reach, "observed": maximum, "context": text})


def enemies(row, out, counter):
    test(out, counter, "enemy time", row["shown_time"], row["time"], row["panel"])
    badge = row["badge"]
    if badge and not badge.get("cancelled"):
        counter["visible enemy badge"] += 1
    for step in row["captions"]:
        if step.get("label") or step.get("text"):
            counter["enemy caption collected"] += 1
    attacks = [step for step in row["captions"] if step.get("kind") in DIRECT_CAPTION
               and step.get("target_key") == "player" and step.get("amount", 0) > 0]
    if len(attacks) == 1 and badge.get("icon") in {"melee", "ranged", "aoe"}:
        number = badge.get("number", "")
        if INTEGER.fullmatch(number) and not badge.get("cancelled"):
            test(out, counter, "enemy direct badge versus caption", int(number), attacks[0]["amount"], row["panel"])
    if len(attacks) == 1 and len(row["captions"]) == 2 and badge.get("secondary_icon") not in {"push", "pull"}:
        observed = -field_difference(row["delta"], "hero", "hp")
        test(out, counter, "enemy direct caption versus Health loss", attacks[0]["amount"], observed, row["panel"])


def events(row, out, counter):
    if row["blocked"]:
        counter["blocked event choice"] += 1
        return
    counter["committed event choice"] += 1
    if len(row["preview"]) != len(row["outcomes"]):
        return
    for shown, actual in zip(row["preview"], row["outcomes"]):
        match = EVENT_NUMBER.match(shown["text"])
        if match and actual["type"] in {"hp", "heal", "embers"}:
            polarity = -1 if match[1] in {"Lose", "Pay"} else 1
            test(out, counter, "event amount", polarity * int(match[2]), actual["amount"], shown["text"])
        if actual["type"] == "card_choice":
            test(out, counter, "event pending offer", actual["cards"],
                 row["pending_reward"].get("cards", []), shown["text"])
        if actual["type"] in {"item", "card", "relic", "equipment", "omen", "lose_item"} and shown["ids"]:
            test(out, counter, "event reward identity", shown["ids"], [actual["id"]], shown["text"])


def battlefield(row, out, counter):
    if "escape" in row:
        test(out, counter, "hoarder escapes on last displayed turn", True,
             row["escape"] == [False] * (len(row["escape"]) - 1) + [True], row["text"])
        return
    test(out, counter, "battlefield cadence", [0] * (len(row["beats"]) - 1) + [1],
         row["beats"], row["text"])
    test(out, counter, "battlefield wrong trigger", 0, row["wrong_trigger_beats"], row["text"])
    match = FROSTBITE_NUMBER.search(row["text"])
    if match:
        actual = -field_difference(row["delta"], "hero", "hp")
        test(out, counter, "Frostbite printed loss on Chilled Hero", int(match[1]), actual, row["text"])


def omen(row, out, counter):
    test(out, counter, "omen fight countdown", list(range(row["fights"], 0, -1)),
         row["countdown"], row["text"])
    if "dark_stage" in row:
        old, new = row["dark_stage"]
        test(out, counter, "omen deeper Umbra at natural cap", True, old != new, row["text"])
    match = re.search(r"Enemies drop (\d+)% (more|fewer) Embers", row["text"])
    if match:
        percent = int(match[1]) * (1 if match[2] == "more" else -1)
        expected = (row["drop_base"] * (100 + percent) + 50) // 100
        test(out, counter, "omen Ember drop", expected, row["drop"], row["text"])


def status(row, out, counter):
    counter[f"status / {row['surface']} records"] += 1
    if row["id"] == "quicken_floor":
        match = QUICKEN_COPY.search(row["text"])
        if match:
            expected = int(match[1])
            observed = row["printed_next"] - row["paid_next"]
            test(out, counter, "Quicken printed discount", expected, observed, row["text"])
    if row["id"] == "wait_bonus":
        test(out, counter, "Wait on unused bonus plays", min(row["available"], 2) * 5, row["wait"],
             "Wait glossary / bonus-plays test")
    if row["id"] == "petrify_repeat":
        test(out, counter, "Petrify Block stacks on legal reapplication", 5,
             row["repeat"]["block"] - row["first"]["block"], "Petrify card tooltip / repeat test")
    if row["id"] == "shock_cleanse":
        test(out, counter, "Shock move-only exception", False, row["cleanse_allowed"],
             "Shock glossary / cleanse test")
    if row["id"] == "kill_card_play":
        actual = row["true"]["death_bonus_card_plays_this_turn"]
        test(out, counter, "kill Card Play excludes summons", 1, actual,
             "Card Play glossary / summoned kill")


def relics(row, out, counter):
    counter["relic card trials"] += len(row["cards"])
    if row["id"] == "hobnail_cleats":
        witness = row["special"]
        if witness["without"]["freeze"] > witness["with"]["freeze"]:
            test(out, counter, "Hobnail Frostbite immunity disclosed", True,
                 "freez" in row["text"].lower(), row["text"])


CHECKS = {"cards": cards, "enemies": enemies, "events": events,
          "battlefields": battlefield, "omens": omen, "status": status, "relics": relics}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipts", type=Path)
    parser.add_argument("--candidates", type=Path)
    args = parser.parse_args()
    if args.candidates:
        with args.candidates.open("w") as output:
            compare(args.receipts, output)
    else:
        compare(args.receipts, None)


def placement_claims(path):
    claims = {}
    with path.open() as source:
        for row in map(json.loads, source):
            if row["surface"] != "grimoire":
                continue
            for line in row["text"]:
                match = PLACEMENT_COPY.search(line)
                if match:
                    claims[row["id"].split(":")[-1]] = (int(match[2]), line)
    return claims


def compare(receipts, output):
    claims = placement_claims(receipts / "status.jsonl")
    counts = Counter()
    failures = Counter()
    for family in FAMILIES:
        path = receipts / (family + ".jsonl")
        with path.open() as source:
            for line_number, line in enumerate(source, 1):
                row = json.loads(line)
                if not row:
                    raise ValueError(f"Empty receipt at {path}:{line_number}")
                counts[f"{family} receipts"] += 1
                if family not in CHECKS:
                    continue
                candidates = []
                CHECKS[family](row, candidates, counts)
                if family == "cards":
                    placement_claim(row, claims, candidates, counts)
                for candidate in candidates:
                    failures[candidate["claim"]] += 1
                    if output is not None:
                        identification = {k: row[k] for k in ("id", "enemy", "choice", "seed", "pos", "profile", "mode", "mods", "half", "tier") if k in row}
                        print(json.dumps({"family": family, "line": line_number, **identification, **candidate}, ensure_ascii=False), file=output)
    for key, count in sorted(counts.items()):
        print(f"QA122 {key}: {count}")
    for key, count in sorted(failures.items()):
        print(f"QA122 candidates / {key}: {count}")
    print(f"QA122 candidates: {sum(failures.values())}")


if __name__ == "__main__":
    main()
