#!/usr/bin/env python3
"""Audit the production Grimoire and source token dump against engine paths."""
import argparse
from collections import Counter
from copy import deepcopy
from functools import cache
import json
from pathlib import Path
import re

from audit_rules import EVIDENCE

ROOT = Path(__file__).resolve().parents[2]
CHANGED = {
    "burrow_grub/erupt": ("Erupt 6 · Push 1 · Rubble · Expose 2 · Self: Expose 2", "Erupt 6 · Push 1 · Rubble · Self: Expose 2"),
    "gust_shrike/dive": ("Move 4 · Melee 4 · Push 1 · Along approach +1", "Move 4 · Melee 4 · Push 1 · Within 1 tile of its path"),
    "last_lamplighter/snuff": ("Summon Wick Shade · Snuff refuge", "Summon Wick Shade · Snuff brazier"),
    "wick_shade/snuff": ("Move 2 · Snuff refuge", "Move 2 · Snuff brazier"),
}
COIL = "noctyrax/night_coil"
DIVE_TOOLTIP = "Hits its path and the tiles next to it."


def verify(before, after):
    assert before["pages"].keys() == after["pages"].keys()
    assert before["swept_path"] == after["swept_path"]
    assert len({key.split("/")[0] for key in after["pages"]}) == 44
    for key, row in after["pages"].items():
        previous = before["pages"][key]
        if key in CHANGED:
            assert (previous["visible"], row["visible"]) == CHANGED[key], key
        elif key == COIL:
            assert previous["summary"] == row["summary"], key
            assert row == renamed(previous), key
        else:
            assert previous == row, key
    assert before["live"].keys() == after["live"].keys()
    assert CHANGED.keys() <= after["live"].keys()
    for key, row in after["live"].items():
        previous = before["live"][key]
        if key in CHANGED:
            assert (previous["known_moves"], row["known_moves"]) == CHANGED[key], key
            if key == "burrow_grub/erupt":
                assert [t["text"] for t in row["combat_tokens"]] == ["Erupt 6", "Push 1", "Rubble", "Self:", "Expose 2"]
                assert previous["combat_tokens"][:3] == row["combat_tokens"][:3]
                assert previous["combat_tokens"][-1] == row["combat_tokens"][-1]
                assert previous["combat_tooltip"] == row["combat_tooltip"]
            elif key == "gust_shrike/dive":
                assert row["combat_tooltip"].endswith(DIVE_TOOLTIP)
                assert row["combat_tokens"][-1]["text"] == "Within 1 tile of its path"
            else:
                assert row["combat_tokens"] == renamed(previous)["combat_tokens"]
                assert previous["combat_tooltip"] == row["combat_tooltip"]
        elif key == COIL:
            assert row == renamed(previous), key
        else:
            assert previous == row, key
    print(f"TXT38 DIFF: PASS ({len(after['pages'])} rows, 4 changed page strings, 133 unchanged, 7 live controls)")


def renamed(row):
    expected = deepcopy(row)
    tokens = next(expected[field] for field in ("tokens", "combat_tokens") if field in expected)
    for token in tokens:
        if token["text"] == "Snuff refuge":
            token["text"] = "Snuff brazier"
            token["value"] = token["value"].replace("Snuff refuge", "Snuff brazier")
    return expected


class Move:
    def __init__(self, key, row):
        self.key = key
        self.row = row
        self.actions = row["actions"]
        self.types = {a["type"] for a in self.actions}
        self.shape = next((a.get("committed_shape", a.get("guardian_shape")) for a in self.actions
                           if "committed_shape" in a or "guardian_shape" in a), "")

    def claims(self):
        yield "Time", self.row["time"], "clock"
        for token in self.row["tokens"]:
            face, hover = self.token_codes(token)
            yield "Token", token["text"][1:] if token["text"].startswith(" ") else token["text"], face
            tooltip = token["tooltip"]
            sentences = re.split(r"(?<=\.)\s+|\n", tooltip)
            # Standalone glossary titles and inline diagram markup carry no
            # prose claim. Keep captions that encode a real condition.
            sentences = [s for s in sentences if s and (s.endswith((".", ":")) or len(s.split()) > 2)]
            if len(hover) == 1:
                hover = hover * len(sentences)
            if len(hover) != len(sentences):
                raise ValueError((self.key, token["text"], tooltip, hover, sentences))
            for statement, evidence in zip(sentences, hover):
                if isinstance(evidence, tuple):
                    for fragment, code in evidence:
                        assert fragment in statement, (self.key, fragment, statement)
                        yield "Tooltip", fragment, code
                else:
                    yield "Tooltip", statement, evidence
        for text, code in SUMMARY_CLAIMS.get(self.key, []):
            yield "Summary", text, code

    def token_codes(self, token):
        text, icon = token["text"], token["icon"]
        parts = self.key.split("/")
        if token["kind"] == "aoe_pattern":
            code = {"hoarfrost_seer": "area_icefall", "slag_mortar": "area_lob", "glacial_mirror": "area_mirror"}.get(parts[0])
            return code or ("area_ring" if self.shape == "ring" else "area_committed" if self.shape else "area"), []
        if icon in ("move", "retreat", "heal"):
            return icon, [icon]
        if icon == "block":
            return "block", [(('Block absorbs damage', 'block_damage'), ("until the start of the holder's next turn", 'block_end'))]
        if icon == "stoneskin":
            return "stoneskin", ["stoneskin"]
        if icon in ("melee", "ranged", "aoe"):
            return self.attack(token)
        if icon == "range":
            if self.shape == "connector":
                return "connector_range", ["connector_range"]
            if self.shape:
                return "range_shape", ["range_ring_tip" if self.shape == "ring" else "razor" if parts[1] == "razor_dive" else "range_shape_tip"]
            code = "icefall_range" if "icefall_mark" in self.types else "relay" if self.uses_relay() else "range"
            return ("range" if code == "relay" else code), [code]
        if token["kind"] == "surface_condition":
            code = "conducted" if icon == "surface_electrified" else "icefall_condition" if "icefall_land" in self.types else "ice_condition"
            return code, [code]
        if icon.startswith("surface_") and icon != "surface_consume":
            return self.ground(icon, token)
        if icon in ("push", "pull"):
            code = "force_erupt" if "erupt" in self.types else "force_gust" if "call_wind" in self.types else "force_direction" if self.shape in ("line", "sweep") else "force"
            return ("gust_count" if code == "force_gust" else "force"), [code]
        if icon == "expose":
            return self.self_code() if any("self_expose" in a for a in self.actions) else "expose", ["expose_effect"]
        if icon == "shock":
            return "shock", ["shock_effect"]
        if icon == "immobilize":
            return "immobilize", ["immobilize"]
        if icon == "stagger":
            return "stagger", ["stagger"]
        if icon == "pierce":
            return "pierce", [(("ignores Block", "pierce"), ("and Stoneskin", "pierce"))]
        if icon == "marked":
            code = {"thornwall": "mark_bramble", "groundsplit": "mark_crag", "lob_slag": "mark_next"}.get(parts[1], "marked")
            return "mark_next" if code == "mark_next" else "upheaval" if code == "mark_bramble" else "marked", [code]
        if icon == "surface_consume":
            code = "expend_ally" if "guard_ally" in self.types else "expend_self"
            return "block" if code == "expend_ally" else code, [code]
        if icon == "summon_minions":
            code = "summon_guardian" if parts[0] in ("last_lamplighter", "storm_cantor") else "summon"
            return code, [code]
        if icon == "icefall":
            return "icefall", ["icefall"]
        if icon == "burst":
            code = "kindle" if "kindle" in self.types else "worldspine"
            return code, ["kindle" if code == "kindle" else "burst_definition"]
        if not icon:
            return self.text_token(text)
        return SPECIAL[icon]

    def uses_relay(self):
        return any(a.get("element") == "lightning" and a["type"] == "ranged" for a in self.actions)

    def self_code(self):
        return "self_grub" if "erupt" in self.types else "self_reaver"

    def attack(self, token):
        icon = token["icon"]
        if token["value"] is None:
            return ("placement" if icon == "ranged" else "area_ring"), []
        if icon == "ranged":
            code = "ranged_committed" if self.shape and any("committed_shape" in a for a in self.actions) or self.types & {"cinder_marks", "lightning_strikes", "umbra_eclipse"} else "ranged_guardian" if self.shape else "relay" if self.uses_relay() else "ranged"
        elif icon == "melee":
            code = {"dive": "melee_dive", "razor_dive": "melee_dive", "groundsplit": "melee_crag", "refraction": "melee_mirror"}.get(self.key.split("/")[1], "melee_area" if "aoe" in self.types else "melee")
            if self.key == "vaeloryx/eye_of_storm" and int(token["value"]) == 4:
                code = "melee"
        else:
            return "lob_hit", [(("5 damage on the central tile", "lob_hit"), ("3 damage on each adjacent tile", "lob_hit"))]
        # The raw damage is valid even when the default card tooltip describes
        # the wrong delivery. Separate the verb/amount from the reach claim.
        detail = token["tooltip"].splitlines()[-1]
        match = re.match(r"(Deal \d+ damage) (.+)", detail)
        assert match, (self.key, detail)
        return "attack", [((match[1], "attack"), (match[2], code))]

    def ground(self, icon, token):
        ground = icon.removeprefix("surface_")
        name = "move_trail" if self.key == "rimejaw/rime_trail" else "lane_end" if self.key == "rime_spitter/needle" else "erupt_rubble" if "erupt" in self.types else "lob_fire" if "lob_mark" in self.types else "icefall" if "icefall_land" in self.types else "layout_ground" if "surface" in self.types and "Leaves this ground" not in token["tooltip"] else "ground"
        if ground == "fire":
            effects = (("entering Fire takes 2 damage", "fire"), ("starting on Fire takes 3", "fire"))
        elif ground == "ice":
            effects = (("entering Ice", "ice"), ("starting a turn on Ice gains Expose 2", "ice"))
        else:
            effects = ground
        return name, [effects, "ground"] if "Leaves this ground" in token["tooltip"] else [effects]

    def text_token(self, text):
        if text == "Self:":
            return self.self_code(), []
        if text in ("Lightning Wisp", "Wick Shade", "Veilbound Acolyte"):
            return "summon", []
        if text == "Trail":
            return "move_trail", []
        if text == "At lane end":
            return "lane_end", []
        if text.startswith("Each Outcrop"):
            return "crag_area", ["crag_area"]
        if text == "each Worldspine":
            return "worldspine", ["worldspine"]
        if text.endswith("linked tiles"):
            return "connector_count", ["connector_existing"]
        if text.startswith("Within "):
            return "dive", ["dive_every"]
        if text.startswith("Along approach"):
            return "razor", ["razor"]
        if text == "Mantle fuels range":
            return "mantle_range", ["mantle_range", (("Break layers to shrink the warning", "mantle_warning"), ("Shatterstorm spends the rest", "mantle_range"))]
        if text == "Snuff brazier":
            code = {"wick_shade": "snuff_wick", "last_lamplighter": "snuff_guardian", "noctyrax": "snuff_coil"}[self.key.split("/")[0]]
            return code, {"snuff_wick": ["brazier_relight"], "snuff_coil": [code, "brazier_relight"]}.get(code, [code])
        raise ValueError((self.key, text))


SPECIAL = {
    "upheaval": ("upheaval", ["upheaval"]),
    "burrow": ("burrow", ["burrow", "burrow_target"]),
    "erupt": ("erupt_damage", ["erupt"]),
    "wind": ("gust_count", ["gust_each"]),
    "blink": ("fade", [(('Blinks behind you, or to another adjacent tile', 'fade_absolute'), ('then Ambushes on this enemy’s next turn', 'ambush'))]),
    "retaliate": ("retaliate", [(('Until your next turn', 'retaliate'), ('each enemy that hits you in melee takes 3 damage', 'retaliate_victim'))]),
    "frost_armor": ("mantle_gain", ["mantle_gain", (("Each direct damaging hit breaks one layer and prevents its damage", "mantle_hit"), ("ground and damage over time bypass it", "mantle_bypass"))]),
    "eclipse": ("eclipse_duration", [(('hits you and your illusions on Marked tiles', 'eclipse_damage'), ('then starts Eclipse for 2 turns', 'eclipse_order'))]),
    "lob": ("lob_hit", [(("5 damage on the central tile", "lob_hit"), ("3 damage on each adjacent tile", "lob_hit"), ("then leave Fire", "lob_fire"))]),
    "charge": ("cap_gain", ["cap_threshold", "cap_shock"]),
    "chain": ("cap_lash", [(("hits the nearest target within 4 tiles for 6 damage", "cap_lash"), ("hits up to 3 more, each adjacent to the prior target and taking 1 less damage", "cap_lash"))]),
    "gale_force": ("area_damage", [(("damages each unit within 2 tiles", "gale_unit"), ("Pushes each unit hit 1 tile", "gale_push"))]),
    "cinder_marks": ("cinder_size", ["cinder_hit"]),
    "detonate_cinders": ("cinder_burst", ["cinder_burst"]),
    "lightning_strikes": ("sky_count", ["sky_random"]),
}

SUMMARY_CLAIMS = {
    "tharokh/faultline": [("Each Worldspine: Burst 8, then Ranged 4 · Range 4", "worldspine")],
    "vyraketh/kindle_ground": [("Cinder Marks 7", "cinder_size"), ("Ranged 4 · Fire, then Ranged 4 · Range 4", "cinder_hit")],
    "vyraketh/cinder_maw": [("Move 2 · Melee 8, then Cinder Marks", "cinder_hit"), ("Cinder Marks 7", "cinder_size"), ("Ranged 3 · Fire", "cinder_hit")],
    "vyraketh/crownfire": [("Each Cinder Mark: Burst 8", "cinder_fuel"), ("then Move 2 · Melee 6", "cinder_burst")],
    "vaeloryx/razor_dive": [("Range 1 of the dive trail behind this enemy", "razor")],
    "vaeloryx/hollow_gale": [("Melee 6 · Range 2 · Push 1 · [diagram]", "area_ring")],
    "vaeloryx/eye_of_storm": [("Retreat 3 · Melee 8 · Range 5 · [diagram]", "area_ring"), ("then Melee 4", "attack")],
    "iskaldra/shatterstorm": [("Range 1, +1 per Crystal Mantle", "mantle_range"), ("removes all Crystal Mantle", "mantle_range")],
    COIL: [("puts out the nearest brazier", "snuff_coil")],
    "noctyrax/last_eclipse": [("Marked: Ranged 8", "eclipse_damage"), ("Eclipse 2", "eclipse_duration"), ("then Summon Veilbound Acolyte", "summon")],
    "zekarion/skybreak": [("Lightning Strikes 9", "sky_count"), ("Ranged 5 · Electrified", "sky_hit")],
    "slag_mortar/lob_slag": [("Marks tiles on your tile", "lob_mark"), ("On this enemy's next turn", "mark_next"), ("5 damage on the central tile", "lob_hit"), ("3 damage on each adjacent tile", "lob_hit"), ("then leave Fire", "lob_fire")],
    "slag_mortar/slag_lands": [("5 damage on the central tile", "lob_hit"), ("3 damage on each adjacent tile", "lob_hit"), ("then leave Fire", "lob_fire")],
    "last_lamplighter/snuff": [("You gain +1 Card Play next turn. (live combat tooltip)", "summon_reward")],
}


@cache
def line_number(path, sample):
    for index, line in enumerate((ROOT / path).read_text().splitlines(), 1):
        if sample in line:
            return index
    raise ValueError((path, sample))


def inline(text):
    return f"`{text.replace('|', '&#124;')}`"


def report(data):
    rows = [(Move(key, row), list(Move(key, row).claims())) for key, row in data["pages"].items()]
    counts = Counter(EVIDENCE[code][0] for _, claims in rows for _, _, code in claims)
    groups = {status: [] for status in ("False", "UNTESTED", "True")}
    for move, claims in rows:
        statuses = {EVIDENCE[code][0] for _, _, code in claims}
        groups[next(status for status in groups if status in statuses)].append((move, claims))
    result = ["# Creature move claim audit", "", "44 creature pages. "
              f"{len(rows)} move rows and {sum(counts.values())} claims. "
              + ", ".join(f"{counts[s]} {s}" for s in groups) + ".", "",
              "The production Grimoire supplied each rendered line. The same builder supplied the token and tooltip inventory. "
              "A generated token tooltip is listed even when an authored summary replaces it or the ordinary combat panel suppresses the default damage tooltip. "
              "Figures are catalog base values. Engine evidence describes ordinary eligible targets, default rules and unmodified base damage unless a claim explicitly promises more. "
              "The live Erupt panel uses its dedicated emergence sentence. Headless combat receipts cover the changed moves and three comparison moves.", "",
              "[Wording inventory](#wording-inventory) · [Evidence key](#evidence-key)", ""]
    used = {}
    for group, section in groups.items():
        result += [f"## {group} rows ({len(section)})", ""]
        for move, claims in section:
            enemy, intent = move.key.split("/")
            anchor = line_number("data/enemies.json", f'  "{enemy}": {{')
            actions = ", ".join(a["type"] for a in move.actions)
            row = move.row
            result += [f"### {enemy} / {row['name']}", "", f"{inline(row['summary'])} · {row['time']}", "",
                       f"Catalog `{intent}`. Actions in order: {inline(actions)}. [Enemy data](../../data/enemies.json#L{anchor})", ""]
            for surface, text, code in claims:
                used[code] = None
                status = EVIDENCE[code][0]
                result.append(f"- {surface} {inline(text)} — **{status}** [{code}](#evidence-{code.replace('_', '-')}).")
            result.append("")
    result += ["## Wording inventory", "", "Current rows", "",
               "- Razor Dive uses `Range 1 of the dive trail behind this enemy` and the generated `Along approach +1`. Both describe a translated footprint with invented path language.",
               "- Shatterstorm has `Mantle fuels range` in the generated token. Its diagram uses `Ring` internally. The Grimoire displays the authored range wording.",
               "- Whiteout Lance has `Cross 3` as the generated diagram label. Hollow Gale and Eye of the Storm have generated `Ring 1–2` and `Ring 2–5` diagram labels. The Grimoire displays diagrams.",
               "- Groundsplit uses `Each Outcrop · within 2`, with no unit after `2`. Rime Needle uses `At lane end`. Rime Trail uses `Trail`.",
               "- Join the Choir and Lay the Choir use `linked tiles` and `Extends existing Electrified toward its target`. Field Brace has `Shape Ground`. Arc Lash uses `extra hits` as a compact label for its jumps.",
               "- Other wording outside the style table includes `card’s Range` on enemy Melee, `each enemy that hits you` on enemy Retaliate, and the titleless `Its Burst deals 2 more` in Kindle.",
               "- The three specified word changes remove `Along approach +1` from Gust Shrike and `Snuff refuge` from the brazier chip. `Dive wake`, `Shadow sweep`, `Spire pulse`, `Connected network` and `Marked tiles · Expended` remain in formatter branches with no matching current catalog row. They were not exercised as saved intents.", "",
               "## Evidence key", ""]
    for code in sorted(used):
        verdict, explanation, path, sample = EVIDENCE[code]
        anchor = code.replace("_", "-")
        line = line_number(path, sample)
        result += [f"### Evidence {anchor}", "", f"**{verdict}.** {explanation} [Engine path](../../{path}#L{line})", ""]
    print(f"TXT38 AUDIT: {len(rows)} rows, " + ", ".join(f"{counts[s]} {s}" for s in groups) + " claims")
    return "\n".join(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("ROWS.md"))
    args = parser.parse_args()
    before, after = (json.loads(path.read_text()) for path in (args.before, args.after))
    verify(before, after)
    args.output.write_text(report(after), encoding="utf-8")


if __name__ == "__main__":
    main()
