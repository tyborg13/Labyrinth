#!/usr/bin/env python3
"""Audit txt-43's observed enemy strings and compare the card-widget exports."""

import argparse
from collections import Counter, defaultdict
import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.txt41.audit import EnemyMove, claims, deltas, literal, status as previous_status
from audit import line_number
from tools.txt43.wording_sweep import wording_report

RANGE = ("Maximum distance to the target in tiles, counted without diagonals.",
         "How far this attack reaches in tiles, counted without diagonals.")
SHOCK = ("Shocked units can only Move or Blink on their next turn.",
         "Shocked units can't attack on their next turn.")
MARKED = ("Marked tiles show where this enemy acts on its next turn.",
          "Marked tiles show where this enemy will act.")
BURROW = "You can't choose a Burrowed enemy as a target, and Gust doesn't move a Burrowed enemy."
FADE = ("This enemy Blinks behind you, or to an empty tile adjacent to you, "
        "then Ambushes on this enemy's next turn.")
GUST = "On each Gust beat, each unit is Pushed downwind."
GALE = "This enemy damages you and your Illusions on Marked tiles, then Pushes you 1 tile away."
CHOIR = "Lays Electrified tiles toward this enemy's target."
BRACE = "Removes Fire, Ice and Electrified under the guarded unit."
LANCER = "frostglass_lancer/refract_guard"
ERUPT = "burrow_grub/erupt"
ERUPT_PUSH = "Pushes each unit adjacent to this enemy 1 tile away and moves any unit on its tile aside."
KINDLE = "This enemy's Burst deals {amount} more damage."
MANTLE = "Each Crystal Mantle layer prevents damage from 1 direct hit, then breaks."
CHARGE = "At 3 Charge, this enemy's next attack is Arc Lash."
COIL = "Puts out the Marked brazier."
SECOND_PERSON = re.compile(r"\b(?:you|your|yourself)\b", re.IGNORECASE)
DIVE = "Hits each Marked tile."
SKY = "This enemy hits each Marked tile."
RELAY = ("to a target within Range and line of sight, or to a target on Electrified "
         "tiles connected to one in Range and line of sight.")
RELAY_ROWS = {
    "arc_thrall/arc_bolt", "bell_tender/staff_bolt", "lightning_wisp/blinding_arc",
    "lightning_wisp/static_lash", "zekarion/call_wisps", "zekarion/storm_claw",
    "zekarion/tempest_breath",
}
FORCE_ROWS = {
    "ashen_reaver/hooked_sweep", "gallows_roc/hookwind",
    "gallows_roc/razor_pinion", "last_lamplighter/mourning_hook",
}
GROUNDSPLIT = "craghide/groundsplit"
RAZOR = "vaeloryx/razor_dive"
MIRROR = "glacial_mirror/refraction"
ENGINE = "scripts/combat_engine.gd"
GUARDIAN = "scripts/guardian_combat_rules.gd"
AREAS = "scripts/boss_area_rules.gd"
EVIDENCE = {
    "range_reach": ("True", ENGINE, "func _enemy_action_reaches_tile", "Range is a Manhattan limit measured from the source tile."),
    "raking_reach": ("True", GUARDIAN, "static func shape_tiles", "Four tiles forward in a broken line."),
    "relay_los": ("True", ENGINE, "func _enemy_lightning_component_impact", "The Electrified entry tile must be in Range and line of sight. Enemy relays use the shared Electrified-only default, including when the hero holds Stormcoal."),
    "force_action": ("True", ENGINE, "func _resolved_force_direction", "Actual displacement follows a cardinal source-relative line. Pull stops when it draws level with the source."),
    "force_single_lane": ("True", GUARDIAN, "static func shape_tiles", "Mourning Hook hits a single lane. Its on-axis victim moved one tile toward the source. The off-axis tile was outside the attack."),
    "fixed_force": ("True", ENGINE, "func _action_force_direction", "An explicit direction takes precedence. Singular distances use the existing tile formatter."),
    "marked_present": ("True", AREAS, "static func announced_tiles", "Marked names the displayed footprint. The sentence makes no next-turn promise."),
    "groundsplit_held": ("True", GUARDIAN, "static func live_tiles", "Groundsplit hit all 22 held Marked tiles after an Outcrop died."),
    "shock_attack_gate": ("True", ENGINE, "func player_action_can_resolve", "Hero and enemy witnesses skipped damaging actions while Shocked."),
    "burrow_choice": ("True", "scripts/enemy_mechanics/burrow.gd", "static func targetable", "Direct action menus exclude the Grub while Burrowed."),
    "burrow_gust": ("True", "scripts/battlefield_rules/gust.gd", "static func actors", "Gust excludes Burrowed actors."),
    "choir_lays": ("True", GUARDIAN, "static func connector_tiles", "The connector can place Electrified without an existing component."),
    "shrike_impact": ("True", "scripts/committed_pattern_shapes.gd", "static func swept_shape", "Open and blocked forecasts matched impact."),
    "razor_impact": ("True", AREAS, "static func strike_tiles", "The interrupted Razor Dive used the same held footprint as its preview."),
    "sky_impact": ("True", ENGINE, "func _enemy_lightning_strikes", "Skybreak hits its held marks."),
    "gale_marked": ("True", "scripts/board_attack_rules.gd", 'bool(hit_action.get("radial_force",false))', "The ring hits the hero and Illusions. Only the hero receives the Push."),
    "gust_eligible": ("True", "scripts/battlefield_rules/gust.gd", "static func actors", "Each eligible unit is Pushed downwind. R10 puts the exceptions in [Anchored](../../data/glossary.json#L367) and [Burrowed](../../scripts/action_icon_library.gd#L353). [R10](../../spec/card_text_style.md#rules-templates)"),
    "expend_enemy": ("True", ENGINE, 'if action.has("clear_surface") and action_type != "guard_ally"', "Self-clear removes the named ground under the enemy's footprint. The hero's ground is untouched."),
    "expend_wrong_subject": ("False", ENGINE, 'if action.has("clear_surface") and action_type != "guard_ally"', "Second person refers to the hero. The resolver removes ground under the acting enemy."),
    "field_brace": ("True", ENGINE, "var guard_target_index: int = _enemy_support_target_index", "The guard removes Fire, Ice and Electrified under the guarded unit. Rubble persists."),
    "fade_room": ("True", "scripts/enemy_mechanics/stalker.gd", "static func destination", "The destination prefers behind, tries an adjacent fallback, and stays put when boxed."),
    "mirror_line": ("True", "scripts/enemy_mechanics/reflect.gd", "static func line", "The glyph contains the four authored forward offsets."),
}


class Txt43Move(EnemyMove):
    def token_codes(self, token):
        text, icon, detail = (token[key] for key in ("text", "icon", "tooltip"))
        sentence = detail.splitlines()[-1] if detail else ""
        if icon == "range" and sentence == RANGE[1]:
            return "range", ["range_reach"]
        if self.key == "ashen_reaver/raking_flame" and icon == "range":
            assert sentence == "How far this attack reaches, in tiles, counted without diagonals."
            return "range_shape", ["raking_reach"]
        if icon in ("push", "pull") and self.key in FORCE_ROWS:
            amount = int(token["value"])
            noun = "tile" if amount == 1 else "tiles"
            direction = "away from" if icon == "push" else "toward"
            assert sentence == f"Move the target {amount} {noun} straight {direction} the source, causing a Collision if blocked."
            code = "force_single_lane" if self.key == "last_lamplighter/mourning_hook" else "force_action"
            return "force", [code]
        if self.key == "noctyrax/night_coil" and icon == "pull":
            assert sentence == "Move each unit hit 1 tile back toward where this attack started, causing a Collision if blocked."
        if icon == "marked":
            assert sentence == MARKED[1], (self.key, detail)
            face, _ = super().token_codes(token)
            return face, ["marked_present"]
        if icon == "shock":
            assert sentence == SHOCK[1], (self.key, detail)
            return "shock", ["shock_attack_gate"]
        if icon == "burrow":
            assert sentence == BURROW, (self.key, detail)
            return "burrow", [(("You can't choose a Burrowed enemy as a target", "burrow_choice"),
                               ("Gust doesn't move a Burrowed enemy.", "burrow_gust"))]
        if icon == "wind":
            assert sentence == GUST, (self.key, detail)
            return "gust_count", ["gust_eligible"]
        if icon == "blink" and self.key == "gloam_stalker/fade":
            assert sentence == FADE, detail
            return "fade_room", ["fade_room"]
        if icon == "gale_force":
            assert sentence == GALE, (self.key, detail)
            return "area_damage", ["gale_marked"]
        if icon == "lightning_strikes":
            assert sentence == SKY, (self.key, detail)
            return "sky_cap", ["sky_impact"]
        if icon == "surface_consume":
            if self.key == "grave_surgeon/field_brace":
                assert sentence == BRACE, detail
                return "block", ["field_brace"]
            surfaces = {action["clear_surface"].capitalize() for action in self.actions
                        if "clear_surface" in action and action["type"] != "guard_ally"}
            if surfaces:
                if SECOND_PERSON.search(sentence):
                    return "expend_self", ["expend_wrong_subject"]
                assert sentence in {f"Removes {ground} under this enemy." for ground in surfaces}, detail
                return "expend_self", ["expend_enemy"]
        if self.key == ERUPT and icon == "push":
            assert sentence == ERUPT_PUSH, detail
            return "force", ["erupt_direction"]
        if icon == "burst" and "kindle" in self.types:
            assert sentence == KINDLE.format(amount=str(text).rsplit("+", 1)[-1]), detail
            return "kindle", ["kindle"]
        if icon == "frost_armor":
            assert sentence == MANTLE, detail
            return "mantle_gain", ["mantle_hit"]
        if icon == "charge":
            assert sentence == CHARGE, detail
            return "cap_gain", ["cap_threshold"]
        if self.key == "noctyrax/night_coil" and not icon and text == "Snuff brazier":
            assert sentence == COIL, detail
            return "snuff_coil", ["snuff_coil"]
        if not icon and text.startswith("Within ") and self.key == GROUNDSPLIT:
            assert sentence == DIVE, detail
            return "crag_owned_area", ["groundsplit_held"]
        if not icon and text.startswith("Up to ") and self.key == "storm_cantor/lay_the_choir":
            assert sentence == CHOIR, detail
            return "connector_cap", ["choir_lays"]
        if not icon and text.startswith("Within ") and self.key == "gust_shrike/dive":
            assert text == "Within 1 tile of this enemy's path" and sentence == DIVE, (text, detail)
            return "dive", ["shrike_impact"]
        if token["kind"] == "aoe_pattern" and self.key == MIRROR:
            assert token["pattern"] == [[1, 0], [2, 0], [3, 0], [4, 0]], token
            return "mirror_line", []
        return super().token_codes(token)

    def attack(self, token):
        face, hover = super().attack(token)
        if self.key not in RELAY_ROWS or token["icon"] != "ranged" or token["value"] is None:
            return face, hover
        damage, (delivery, _) = hover[0]
        assert delivery == RELAY, (self.key, delivery)
        return face, [(damage, (delivery, "relay_los"))]

    def claims(self):
        for surface, text, code in super().claims():
            if self.key == RAZOR and surface == "Summary":
                assert DIVE in self.row["summary"], self.row["summary"]
                text, code = DIVE, "razor_impact"
            yield surface, text, code


def status(code):
    return EVIDENCE[code][0] if code in EVIDENCE else previous_status(code)


def read(directory, name):
    return json.loads((directory / f"{name}.json").read_bytes())


def verify_live(rows):
    expected = {
        "ashen_reaver/raking_flame": ("range", "How far this attack reaches, in tiles, counted without diagonals."),
        "arc_thrall/arc_jab": ("shock", SHOCK[1]),
        "lightning_wisp/blinding_arc": ("shock", SHOCK[1]),
        "briar_weaver/thornwall": ("marked", MARKED[1]),
        GROUNDSPLIT: ("", DIVE),
        "burrow_grub/burrow": ("burrow", BURROW),
        "gale_herald/call_the_wind": ("wind", GUST),
        "gloam_stalker/fade": ("blink", FADE),
        "grave_surgeon/field_brace": ("surface_consume", BRACE),
        LANCER: ("surface_consume", "Removes Ice under this enemy."),
        ERUPT: ("push", ERUPT_PUSH),
        "ember_hoarder/kindle": ("burst", KINDLE.format(amount=2)),
        "ember_tick/kindle": ("burst", KINDLE.format(amount=2)),
        "iskaldra/crystal_mantle": ("frost_armor", MANTLE),
        "storm_capacitor/charge": ("charge", CHARGE),
        "noctyrax/night_coil": ("", COIL),
        "gust_shrike/dive": ("", DIVE),
        "storm_cantor/lay_the_choir": ("", CHOIR),
        RAZOR: ("marked", MARKED[1]),
        "vaeloryx/hollow_gale": ("gale_force", GALE),
        "zekarion/skybreak": ("lightning_strikes", SKY),
    }
    for key, (icon, sentence) in expected.items():
        assert any(token["icon"] == icon and token["tooltip"].splitlines()[-1:] == [sentence]
                   for token in rows[key]["combat_tokens"]), (key, icon, sentence)
    for key in RELAY_ROWS:
        attack = next(token for token in rows[key]["combat_tokens"] if token["icon"] == "ranged")
        assert attack["tooltip"] == f"Ranged\nDeal {int(attack['value'])} damage {RELAY}", key
        assert RELAY in rows[key]["combat_tooltip"], key
    razor = rows[RAZOR]
    assert razor["known"]["text"].endswith(DIVE)
    assert not any(token["icon"] == "range" or token["text"].startswith("Along approach")
                   for token in razor["combat_tokens"])
    chip = next(token for token in rows[MIRROR]["combat_tokens"] if token["kind"] == "aoe_pattern")
    assert chip["pattern"] == [[1, 0], [2, 0], [3, 0], [4, 0]]
    print("TXT43 LIVE COPY: PASS (approved sentences, Razor Dive chips, Refraction offsets)")


def verify_hover(before, after, path, changes):
    if isinstance(before, dict):
        assert before.keys() == after.keys(), path
        for key, value in before.items():
            verify_hover(value, after[key], (*path, key), changes)
    elif isinstance(before, list):
        assert len(before) == len(after), path
        for index, value in enumerate(before):
            verify_hover(value, after[index], (*path, index), changes)
    elif before != after:
        assert path[0] == "cards" and (
            (path[3] in ("native", "panels") and path[-1] in ("text", "display"))
            or (path[3] in ("rows", "sentence") and path[-1] in ("tooltip", "card_tooltip"))
        ), (path, before, after)
        assert isinstance(before, str) and isinstance(after, str), path
        for term, (old, new) in {"Range": RANGE, "Shock": SHOCK, "Marked": MARKED}.items():
            if old in before and before.replace(old, new) == after:
                changes[term].add(path[1])
                return
        raise AssertionError((path, before, after))


def card_delta(directory, since_round):
    before_bytes = (directory / "cards-before.json").read_bytes()
    after_bytes = (directory / "cards-after.json").read_bytes()
    changes = defaultdict(set)
    before, after = json.loads(before_bytes), json.loads(after_bytes)
    assert len(before["cards"]) == 309 and len(before["sources"]) == 9
    if since_round:
        assert before_bytes == after_bytes, f"Unexpected card-widget delta since round {since_round}"
        print(f"TXT43 CARDS ROUND {since_round + 1}: PASS "
              f"(309 catalog IDs, 9 source lists, byte-identical to the before export)")
        return changes
    verify_hover(before, after, (), changes)
    # Keep the engine's original serialization, including number formatting.
    normalized = after_bytes
    for old, new in (RANGE, SHOCK, MARKED):
        new_bytes = new.encode()
        assert new_bytes not in before_bytes
        normalized = normalized.replace(new_bytes, old.encode())
    assert normalized == before_bytes, "Unexpected difference in card widget export bytes"
    total = len(set().union(*changes.values()))
    print(f"TXT43 CARDS: PASS (309 catalog IDs, 9 source lists, byte-identical outside glossary hovers on {total} cards)")
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--diff", required=True, type=Path)
    baseline = parser.add_mutually_exclusive_group()
    baseline.add_argument("--since-round-one", action="store_const", const=1, dest="since_round")
    baseline.add_argument("--since-round-two", action="store_const", const=2, dest="since_round",
                          help="compare with the merged round 3 baseline")
    args = parser.parse_args()
    before = read(args.directory, "before")["pages"]
    after_export = read(args.directory, "after")
    after = after_export["pages"]
    live_before = read(args.directory, "live-before")
    live_after = read(args.directory, "live-after")
    assert before.keys() == after.keys() == live_before.keys() == live_after.keys()
    assert len(after) == 137 and len({key.split("/")[0] for key in after}) == 44
    new = claims(after, Txt43Move)
    totals = Counter(status(row[-1]) for row in new.elements())
    print(f"TXT43 AUDIT: {len(after)} rows, {totals['False']} False, {totals['UNTESTED']} UNTESTED")
    if args.since_round == 2:
        move = Txt43Move(LANCER, before[LANCER])
        old_expend = next(token for token in move.row["tokens"] if token["icon"] == "surface_consume")
        assert move.token_codes(old_expend) == ("expend_self", ["expend_wrong_subject"])
        print(f"TXT43 AUDIT BASELINE: {len(before)} merged rows, Lancer Expend misattribution confirmed")
    elif args.since_round == 1:
        assert any(token["tooltip"].endswith("Clears the ground under the guarded unit.")
                   for token in before["grave_surgeon/field_brace"]["tokens"])
        print(f"TXT43 AUDIT BASELINE: {len(before)} rows from round 1")
    else:
        old = claims(before, EnemyMove)
        old_counts = Counter(previous_status(row[-1]) for row in old.elements())
        assert (old_counts["False"], old_counts["UNTESTED"]) == (34, 1), old_counts
        print(f"TXT43 AUDIT BASELINE: {len(before)} rows, {old_counts['False']} False, {old_counts['UNTESTED']} UNTESTED")
    verify_live(live_after)
    changed = card_delta(args.directory, args.since_round)
    lines = ["# Enemy move string differences", "", "| Surfaces | Before | After |", "| --- | --- | --- |"]
    for (old_text, new_text), locations in deltas(before, after, live_before, live_after).items():
        lines.append(f"| {'<br>'.join(sorted(locations))} | {literal(old_text)} | {literal(new_text)} |")
    lines += ["", "## Changed claims and evidence", "", "| Move and surface | Claim | Verdict | Evidence |",
              "| --- | --- | --- | --- |"]
    for key, surface, text, code in sorted(new):
        if code not in EVIDENCE:
            continue
        verdict, path, sample, explanation = EVIDENCE[code]
        line = line_number(path, sample)
        lines.append(f"| {key} ({surface}) | {literal(text)} | {verdict} | "
                     f"[{path}:{line}](../../{path}#L{line}) · {explanation} |")
    lines += ["", "## Card hovers", ""]
    for term in ("Range", "Shock", "Marked"):
        ids = sorted(changed[term])
        lines.append(f"- {term} ({len(ids)}) · " + (", ".join(f"`{id_}`" for id_ in ids) or "None"))
    if args.since_round == 2:
        lines += ["", *wording_report(ROOT, after_export, live_after)]
    args.diff.write_text("\n".join(lines) + "\n")
    return int(bool(totals["False"] or totals["UNTESTED"]))


if __name__ == "__main__":
    raise SystemExit(main())
