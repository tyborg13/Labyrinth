#!/usr/bin/env python3
"""Compare txt-38 inventories and re-audit the changed enemy claims."""

import argparse
from collections import Counter, defaultdict
from difflib import SequenceMatcher
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "txt38"))
from audit import Move, SUMMARY_CLAIMS
from audit_rules import EVIDENCE


AREA_DAMAGE = {
    "melee_area", "melee_crag", "melee_dive", "melee_mirror",
    "ranged_committed", "ranged_guardian",
}
NEW_TRUE = {
    "enemy_adjacent", "enemy_melee_reach", "enemy_area_damage", "enemy_area_reach",
    "fixed_force", "crag_owned_area", "connector_cap", "connector_route",
    "cinder_cap", "sky_cap", "cinder_fire_fuel", "eclipse_first", "gust_downwind",
    "retaliate_adjacent", "mantle_at_mark", "erupt_direction", "dive_marked_impact",
}


class EnemyMove(Move):
    def token_codes(self, token):
        text, icon, detail = (token[key] for key in ("text", "icon", "tooltip"))
        if icon == "range" and detail == "How far this attack reaches, in tiles, counted without diagonals.":
            face, hover = super().token_codes(token)
            assert hover[0] in ("range_shape_tip", "range_ring_tip"), self.key
            return face, ["enemy_area_reach"]
        if icon in ("push", "pull"):
            if self.key == "noctyrax/night_coil" and detail.startswith("Move each unit hit "):
                return "force", ["fixed_force"]
            if self.key == "burrow_grub/erupt" and detail.startswith("Pushes each unit next to this enemy"):
                return "force", ["erupt_direction"]
            if self.key == "gale_herald/call_the_wind" and detail == "Gust Pushes units 1 tile downwind.":
                return "gust_count", ["gust_downwind"]
        if icon == "retaliate" and self.key == "hollow_mimic/echo" and detail.startswith("When you hit this enemy from an adjacent tile"):
            return "retaliate", ["retaliate_adjacent"]
        if icon == "eclipse" and detail.startswith("This enemy starts Eclipse for your next "):
            return "eclipse_duration", ["eclipse_first"]
        if text.startswith("Up to "):
            if icon == "cinder_marks":
                return "cinder_cap", ["cinder_hit"]
            if icon == "lightning_strikes":
                return "sky_cap", ["sky_random"]
            if not icon and self.shape == "connector":
                return "connector_cap", ["connector_route" if self.key == "bell_tender/connector" else "connector_existing"]
        if text == "Within 2 tiles of each Outcrop" and self.key == "craghide/groundsplit":
            return "crag_owned_area", ["crag_owned_area"]
        if text == "Mantle fuels range" and detail.startswith("Range grows by 1 for each Crystal Mantle layer"):
            return "mantle_range", ["mantle_at_mark"]
        if self.key == "vaeloryx/razor_dive" and text.startswith("Along approach") and detail == "Hits the marked tiles along its dive.":
            return "razor", ["dive_marked_impact"]
        return super().token_codes(token)

    def attack(self, token):
        face, hover = super().attack(token)
        if token["value"] is None or token["icon"] not in ("melee", "ranged"):
            return face, hover
        _, (delivery, code) = hover[0]
        if delivery == "in this attack's area.":
            assert code in AREA_DAMAGE, (self.key, code)
            return face, ["enemy_area_damage"]
        if delivery == "to an adjacent target.":
            assert code == "melee", (self.key, code)
            return face, ["enemy_adjacent"]
        if delivery == "to a target within Range.":
            assert code == "melee", (self.key, code)
            return face, ["enemy_melee_reach"]
        if self.key == "vyraketh/kindle_ground" and token["icon"] == "ranged":
            # The only card-style chip left is the separate direct shot.
            return face, [(hover[0][0], (delivery, "ranged"))]
        return face, hover

    def claims(self):
        for surface, text, code in super().claims():
            if surface == "Summary":
                summary = self.row["summary"]
                replacements = {
                    "cinder_size": ("Cinder Marks 7", "Up to 7 Cinder Marks", "cinder_cap"),
                    "sky_count": ("Lightning Strikes 9", "Up to 9 Lightning Strikes", "sky_cap"),
                    "cinder_fuel": ("Each Cinder Mark: Burst 8", "Each Cinder Mark on Fire: Burst 8", "cinder_fire_fuel"),
                }
                if code in replacements:
                    old, new, witness = replacements[code]
                    assert old in text and new in summary, (self.key, summary)
                    text, code = text.replace(old, new), witness
                elif self.key == "vyraketh/cinder_maw" and text == "Move 2 · Melee 8, then Cinder Marks":
                    text = "Move 2 · Melee 8, then Up to 7 Cinder Marks"
            yield surface, text, code


def status(code):
    return "True" if code in NEW_TRUE else EVIDENCE[code][0]


def claims(pages, model):
    return Counter((key, surface, text, code) for key, row in pages.items()
                   for surface, text, code in model(key, row).claims())


def token_changes(before, after):
    identify = lambda tokens: [(token["icon"], token["kind"]) for token in tokens]
    aligned = SequenceMatcher(a=identify(before), b=identify(after), autojunk=False)
    for kind, start, end, current, stop in aligned.get_opcodes():
        if kind == "equal":
            for old, new in zip(before[start:end], after[current:stop]):
                for field in ("text", "tooltip", "display_tooltip"):
                    if old[field] != new[field]:
                        yield field, old[field], new[field]
        else:
            for token in before[start:end]:
                for field in ("text", "tooltip", "display_tooltip"):
                    if token[field]:
                        yield field, token[field], ""
            for token in after[current:stop]:
                for field in ("text", "tooltip", "display_tooltip"):
                    if token[field]:
                        yield field, "", token[field]


def deltas(pages_before, pages_after, live_before, live_after):
    groups = defaultdict(set)
    for key, previous in pages_before.items():
        current = pages_after[key]
        assert (previous["name"], previous["time"], previous["actions"]) == (
            current["name"], current["time"], current["actions"]), key
        for field, label in (("visible", "Grimoire text"), ("summary", "Known Move summary model")):
            if previous[field] != current[field]:
                groups[previous[field], current[field]].add(f"{key} ({label})")
        for field, old, new in token_changes(previous["tokens"], current["tokens"]):
            groups[old, new].add(f"{key} (catalog chip {field})")

        previous, current = live_before[key], live_after[key]
        for field in ("text", "tooltip"):
            if previous["known"][field] != current["known"][field]:
                groups[previous["known"][field], current["known"][field]].add(f"{key} (Known Moves {field})")
        for field, old, new in token_changes(previous["combat_tokens"], current["combat_tokens"]):
            groups[old, new].add(f"{key} (combat chip {field})")
        if previous["combat_tooltip"] != current["combat_tooltip"]:
            groups[previous["combat_tooltip"], current["combat_tooltip"]].add(f"{key} (combat intent tooltip)")
    return groups


def literal(value):
    return "`" + value.replace("|", "\\|").replace("\n", "`<br>`") + "`" if value else "—"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="directory containing the before and after exports")
    parser.add_argument("--diff", type=Path, required=True)
    args = parser.parse_args()

    def read(name):
        return json.loads((args.directory / f"{name}.json").read_text())

    before, after = read("before"), read("after")
    pages_before, pages_after = before["pages"], after["pages"]
    live_before, live_after = read("live-before"), read("live-after")
    assert pages_before.keys() == pages_after.keys() == live_before.keys() == live_after.keys()
    assert len(pages_after) == 137 and len({key.split("/")[0] for key in pages_after}) == 44
    old, new = claims(pages_before, Move), claims(pages_after, EnemyMove)
    old_totals = Counter(status(claim[-1]) for claim in old.elements())
    new_totals = Counter(status(claim[-1]) for claim in new.elements())
    assert old_totals == {"True": 999, "False": 100, "UNTESTED": 1}, old_totals
    added = new - old
    assert all(status(claim[-1]) == "True" for claim in added), [
        claim for claim in added if status(claim[-1]) != "True"
    ]
    changed = {key for key in pages_before if pages_before[key] != pages_after[key] or live_before[key] != live_after[key]}
    old_false_on_changed = {key for key, _, _, code in new if status(code) == "False"} & changed
    card_before = (args.directory / "cards-before.json").read_bytes()
    assert card_before == (args.directory / "cards-after.json").read_bytes()
    cards = json.loads(card_before)
    print(f"TXT41 CARDS: PASS ({len(cards['cards'])} catalog IDs, {len(cards['sources'])} source lists, byte-identical)")
    print(f"TXT41 AUDIT: {len(pages_after)} rows, {new_totals['False']} False, {new_totals['UNTESTED']} UNTESTED, {new_totals['True']} True claims")
    print(f"TXT41 AUDIT DELTA: PASS ({sum(added.values())} added claims True, 0 new False, {len(old_false_on_changed)} edited rows with earlier False claims)")
    groups = deltas(pages_before, pages_after, live_before, live_after)
    print(f"TXT41 DIFF: PASS ({len(changed)} changed rows, {len(groups)} unique before/after string pairs)")
    lines = ["## Before and after", "", "| Surfaces | Before | After |", "| --- | --- | --- |"]
    for (previous, current), locations in groups.items():
        lines.append(f"| {'<br>'.join(sorted(locations))} | {literal(previous)} | {literal(current)} |")
    lines += ["", "## Deferred glossary and diagram rows", ""]
    for name, codes in (
        ("Lightning relay", {"relay"}), ("Shock", {"shock", "shock_effect"}),
        ("Burrow", {"burrow", "burrow_target"}),
        ("Marked", {"marked", "mark_bramble", "mark_crag", "mark_next"}),
        ("Gust’s each-unit sentence", {"gust_each"}),
    ):
        rows = sorted({key for key, _, _, code in old if code in codes})
        lines.append(f"- {name} · " + ", ".join(literal(key) for key in rows))
    diagrams = sorted(key for key, row in pages_before.items() if any(token["kind"] == "aoe_pattern" for token in row["tokens"]))
    lines.append("- Diagram-only labels · " + ", ".join(literal(key) for key in diagrams))
    lines += ["", "Edited rows carrying earlier False claims · " + ", ".join(literal(key) for key in sorted(old_false_on_changed)), ""]
    args.diff.write_text("\n".join(lines))


if __name__ == "__main__":
    main()
