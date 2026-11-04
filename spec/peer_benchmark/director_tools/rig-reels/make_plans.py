#!/usr/bin/env python3
"""Reel plans: every clip front then rear along one board row (+x front, -x rear)."""
import json
from pathlib import Path

WORK = Path(__file__).resolve().parents[1] / "work"


def plan(rig_type, line, attacks, caption_position=(560, 14), mouse=(1910, 1070), keep_others=False, walk=(1, 4, 7), walk_override=None, shift=None):
    """Actors share board row `line`: +x faces front, -x faces rear (the x-axis facings are the mirrored art)."""
    seg = []
    tile = lambda along: [along, line]
    def add(name, caption, kind, front, rear, front_extra=None, rear_extra=None, **extra):
        for view, (enemy, hero), more in (("front", front, front_extra), ("rear", rear, rear_extra)):
            row = {"name": f"{name}_{view}", "caption": f"{caption}, {view}", "kind": kind, "enemy": tile(enemy), "hero": tile(hero)}
            row.update(extra)
            row.update(more or {})
            seg.append(row)
    add("idle", "Idle", "idle", (3, 5), (5, 3), seconds=2.52)
    start, stop, far = walk
    walk_front, walk_rear = (walk_override or ({}, {}))
    add("walk", "Walk", "move", (start, far), (far, start), walk_front, walk_rear, range=stop - start)
    for intent, caption, hero_front, hero_rear, *more in attacks:
        options = more[0] if more else {}
        add(intent, caption, "intent", (options.get("enemy_front", 3), hero_front), (options.get("enemy_rear", 5), hero_rear),
            options.get("front"), options.get("rear"), intent=intent)
    # The hero's Pale Spark (range 3) lands the hit from two tiles out, so the hero never covers the enemy.
    add("hit", "Hit", "hit", (3, 5), (5, 3), card="pale_spark")
    add("death", "Death", "death", (3, 5), (5, 3), card="pale_spark")
    if shift:
        # Move a view's enemy outward by `shift` tiles and its hero one tile inward (hero distance stays 2 outside the walk).
        for row in seg:
            view = row["name"].rsplit("_", 1)[1]
            if row["kind"] == "move": continue
            row["enemy"][0] += shift[view]
            row["hero"][0] = 4
    return {"type": rig_type, "caption_position": list(caption_position), "mouse": list(mouse), "keep_others": keep_others,
            "pre": 0.4, "tail": 0.15, "segments": seg}


PLANS = {
    # Snuff turns toward the Wick Shade it raises beside the brazier picked by guardian_cycle (0: brazier 1 at (3,2),
    # Shade at (3,1)). Row 2 puts that Shade and the hero on the same side, so the clip never flips at its end.
    "last_lamplighter": plan("last_lamplighter", 4, [
        # After the snuff only the hero's two-tile sight shows him, so the hero stands two tiles away, level with him on screen.
        ("snuff", "Snuff", 5, 3, {"front": {"enemy": [1, 2], "hero": [2, 1], "guardian_cycle": 0},
                                   "rear": {"enemy": [5, 2], "hero": [4, 3], "guardian_cycle": 0}}),
        # Two tiles out keeps him inside the hero's sight; three tiles out the rear hook played as "Unknown Presence".
        ("mourning_hook", "Mourning Hook", 5, 3),
        ("last_procession", "Last Procession", 4, 4)],
        # The Last Watch hides him outside the hero's two-tile sight and the braziers' light. Column 4 keeps the
        # whole three-tile walk lit (braziers at (3,2) and (3,6), the hero two tiles past the end), unmirrored.
        walk_override=({"enemy": [4, 1], "hero": [4, 6]}, {"enemy": [4, 7], "hero": [4, 2]})),
    "storm_cantor": plan("storm_cantor", 4, [
        # Lay the Choir faces its first new Electrified tile, (2,4) from either side here, so both views stay unflipped.
        ("lay_the_choir", "Lay the Choir", 5, 3),
        ("peal", "Peal", 5, 3),
        ("broken_rhythm", "Broken Rhythm", 5, 3),
        ("call_the_spark", "Call the Spark", 5, 3)],
        # His arena's pillars stand at (4,3) and (4,5): he works from (2,4) and (6,4) with the hero between them at (4,4).
        shift={"front": -1, "rear": 1}),
    "ashen_reaver": plan("ashen_reaver", 4, [
        ("raking_flame", "Raking Flame", 4, 4),
        ("hooked_sweep", "Hooked Sweep", 5, 3),
        ("executioners_fall", "Executioner's Fall", 5, 3)],
        # His arena shows only the hero's three-tile sight: a two-tile walk that stops beside the hero stays in view.
        walk_override=({"enemy": [2, 4], "hero": [5, 4]}, {"enemy": [6, 4], "hero": [3, 4]})),
}

if __name__ == "__main__":
    for name, value in PLANS.items():
        path = WORK / f"{name}_plan.json"
        path.write_text(json.dumps(value, indent=1))
        print(path, len(value["segments"]), "segments")
