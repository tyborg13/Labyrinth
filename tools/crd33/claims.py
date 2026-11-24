"""Compare rendered claims to committed combat receipts."""
from collections import defaultdict
import re


def variants(card):
    yield "base", card["catalog"]
    if card["hand"]:
        yield "hand", card["hand"]
    if card["legacy"]:
        yield "legacy", card["legacy"]


def clauses(text):
    text = " ".join(text.split())
    return re.split(r"(?<=\.) (?=[A-Z0-9+])", text) if text else []


def sentence_text(segments):
    parts = []
    for segment in segments:
        if "text" in segment:
            parts.append(segment["text"])
        elif "pattern" in segment:
            parts.append(f"[{segment['pattern']} diagram]")
        elif "damage" in segment:
            parts.append(f"[{segment['damage'].capitalize()} {segment['display']}]")
        elif "duration" in segment:
            parts.append(segment.get("display", str(int(segment["duration"]))))
        elif "term" in segment:
            display = segment.get("display", "")
            parts.append(segment["word"] + (f" {display}" if display else ""))
    return "".join(parts)


def render_claims(card, variant, view):
    def claim(surface, text, kind, **fields):
        return dict(card=card, variant=variant, surface=surface, claim=text, kind=kind, **fields)

    yield claim("Time badge", f"Time {int(view['time'])}", "stat", stat="time", amount=int(view["time"]))
    yield claim("Time hover", view["time_hover"].removeprefix("Time\n"), "panel")
    for row in view["rows"]:
        for token in row:
            text = token["audit_display"]
            if "pattern" in token:
                yield claim("Diagram", text or "Area", "pattern", offsets=token["pattern"],
                            origin=token.get("show_origin", False), segment=token.get("keyword_segment", ""))
            elif token.get("kind") == "rules_text":
                for clause in clauses(text):
                    yield claim("Face sentence", clause, "sentence")
            elif text and text not in (":", "/", "→"):
                yield claim("Face token", text, "stat", amount=token.get("value"),
                            stat=token.get("icon", ""), field=token.get("field", ""),
                            segment=token.get("keyword_segment", ""), numeric=token.get("kind", "") != "text")
    if view["sentence"]:
        segments = view["sentence"]["sentence"]
        for clause in clauses(sentence_text(segments)):
            yield claim("Face sentence", clause, "sentence")
        chip = view["sentence"].get("chip")
        if chip:
            yield claim("Target chip", f"{chip['word']} · Range {chip['display']}", "chip")
        for segment in segments:
            if "offsets" in segment:
                yield claim("Diagram", f"{segment['pattern']} diagram", "pattern",
                            offsets=segment["offsets"], origin=segment["show_origin"], segment="")
            if "damage" in segment and segment.get("display", "").isdigit():
                yield claim("Face sentence numeral", f"[{segment['damage'].capitalize()} {segment['display']}]",
                            "stat", amount=int(segment["display"]), stat=segment["damage"], field="damage")
    for clause in clauses(view.get("empower", "").removeprefix("Empower\n")):
        yield claim("Empower seal hover", clause, "panel")
    for clause in clauses(view["plain_face"]):
        yield claim("Face sentence", clause, "sentence")
    panels = {
        ("Keyword hover", panel["text"]) for panel in view["panels"]
    } | {
        ("Keyword hover diagram", panel["display"]) for panel in view["panels"]
        if panel["text"] != panel["display"]
    } | {
        ("Native hover", panel["text"]) for panel in view["native"]
    }
    # Native token children often expose the identical tooltip. Count the
    # printed statement once for each route, regardless of which child owns it.
    for surface, text in sorted(panels):
        if surface == "Native hover" and "\n" in text:
            text = text.split("\n", 1)[1]
        for clause in clauses(text):
            if clause == "Spend 1 Card Play per card, refilling each turn and gaining 1 per kill.":
                parts = [
                    "Spend 1 Card Play per card", "refilling each turn", "gaining 1 per kill.",
                ]
                for part in parts:
                    yield claim(surface, clause, "panel", subject=part)
            elif clause:
                yield claim(surface, clause, "panel")


def outcome(claim, verdict, reason, witness=None):
    return dict(claim, verdict=verdict, reason=reason, witness=witness)


def delta(step, key):
    return step["after"][key] - step["before"][key]


def hp_loss(step):
    return [
        (before["pos"], before["hp"] - after["hp"])
        for before, after in zip(step["before"]["enemies"], step["after"]["enemies"])
        if before["hp"] > after["hp"] > 0 and not before["block"] and not before["stoneskin"]
        and not before["expose"]
    ]


def stat_observation(claim, receipt, all_claims):
    if "blocked" in receipt:
        return None
    stat, amount = claim["stat"], claim["amount"]
    if claim.get("segment") or not isinstance(amount, (int, float)):
        return None
    steps = receipt["steps"]
    if stat == "time":
        if claim["surface"] != "Time badge":
            return None
        return delta(receipt, "time"), {"clicks": receipt["targets"], "time_before": receipt["before"]["time"],
                                         "time_after": receipt["after"]["time"]}
    if claim.get("field") == "damage":
        base_numbers = [c for c in all_claims if c.get("field") == "damage" and not c.get("segment")]
        attacks = [s for s in steps if s["action"] in {"melee", "ranged", "aoe"}]
        if len(base_numbers) != 1 or len(attacks) != 1 or receipt["layout"] != "clear board":
            return None
        step = attacks[0]
        if step["conditional_amount"] or step["secondary_damage"] or step["secondary"]:
            return None
        hits = hp_loss(step)
        if len({amount for _, amount in hits}) == 1:
            return hits[0][1], {"clicks": receipt["targets"], "enemy_damage": hits}
        return None
    if stat in {"block", "stoneskin", "heal", "draw", "card_play"} and claim.get("field") == "amount":
        if receipt["layout"] != "clear board":
            return None
        actions = [s for s in steps if s["action"] == stat and not s["secondary"]]
        if len(actions) != 1:
            return None
        step = actions[0]
        if step["conditional_amount"]:
            return None
        if stat in {"block", "stoneskin", "heal"}:
            key = "hp" if stat == "heal" else stat
            before, after = (step[mark]["player"][key] for mark in ("before", "after"))
        else:
            key = "hand_size" if stat == "draw" else "plays_bonus"
            before, after = (step[mark][key] for mark in ("before", "after"))
        return after - before, {"clicks": receipt["targets"], "attribute": key, "before": before, "after": after}
    return None


def xy(tile):
    if isinstance(tile, list):
        return tuple(tile)
    x, y = tile.strip("()").split(", ")
    return int(x), int(y)


def pattern_observation(claim, probe, all_claims):
    if claim["segment"] or not probe:
        return None
    if sum(c["kind"] == "pattern" for c in all_claims) != 1:
        return None
    offsets = {xy(p) for p in claim["offsets"]}
    if not offsets:
        return None
    center = xy(probe["center"])
    affected = {xy(p) for p in probe["affected"]}
    sampled = {xy(p) for p in probe["sampled"]}
    if not affected <= sampled:
        return None
    hero = xy(probe["hero"])
    allowed = []
    for _ in range(4):
        printed = {(center[0] + x, center[1] + y) for x, y in offsets}
        unsampled = printed - sampled
        if unsampled <= {hero} and printed & sampled:
            allowed.append(printed & sampled)
        offsets = {(-y, x) for x, y in offsets}
    if not allowed:
        return None
    if affected in allowed:
        return "True", probe
    # Pattern uses the same palette for attacks, picked fuel, and ground. An
    # unmatched sample can have different semantics. It needs a named scenario.
    return None


def named_finding(claim, receipts):
    card, text = claim["card"], claim["claim"]
    subject = claim.get("subject", "")
    key, reason = "", ""
    if subject == "gaining 1 per kill.":
        key = "kill_card_play"
        r = receipts[key]
        if r["ordinary_hp_after"] == r["summoned_hp_after"] == 0 and r["summoned_reward"] != 1:
            reason = (f"Quick Stab killed a summoned enemy at {r['clicked']} for "
                      f"{r['summoned_reward']} bonus Card Plays. The ordinary enemy control gave {r['ordinary_reward']}.")
    elif (match := re.fullmatch(r"Your next card this turn costs (\d+) less Time\.", text)):
        key = f"quicken/{card}"
        r = receipts.get(key, {})
        if "quickened_time" in r and r["normal_time"] - r["quickened_time"] < int(match[1]):
            reason = (f"The next card, Brace, cost {r['normal_time']} Time normally and "
                      f"{r['quickened_time']} Time after this card.")
    elif (match := re.fullmatch(r"Delay the target's next turn by (\d+) Time\.", text)):
        key = f"stagger/{card}"
        r = receipts.get(key, {})
        if r.get("ordinary_delta") == int(match[1]) and r["pre_delayed_by"] == r["delay_now"]:
            reason = (f"The same play added {r['ordinary_delta']} Time in the control. After Petrify, "
                      f"the surviving enemy's delay stayed at {r['delay_now']} Time.")
    elif card == "empty_husk" and text in {"any illusion", "Any of your illusions on the board."}:
        key = "empty_husk"
        r = receipts[key]
        if r["hidden"] and not r["legal_while_hidden"] and r["hero_after_visible_click"] == r["clicked"]:
            reason = f"The illusion at {r['clicked']} could be clicked when visible. The engine rejected that target while hidden."
    elif card == "skybolt" and text == "Shock each enemy hit, including Chain and conducted hits.":
        key = "skybolt"
        r = receipts[key]
        if r["damage"][1] > 0 and r["shock"] == [1, 0]:
            reason = f"The conducted hit dealt {r['damage'][1]} damage to Zekarion and applied Shock {r['shock'][1]}."
    elif "damage to a target within Range and line of sight." in text:
        key = card
        r = receipts.get(key, {})
        if card == "sleet_squall" and r.get("distance_at_hit", 0) > 3 and r["damage"] == 3:
            reason = (f"The initial click was at {r['clicked']}. The follow-up dealt {r['damage']} at "
                      f"{r['enemy_after_push']}, {r['distance_at_hit']} tiles from the hero.")
        if card == "white_silence" and r.get("line_of_sight") is False and r["damage"] == 8:
            reason = f"The visible enemy at {r['enemy']} took {r['damage']} through the wall at {r['blocking_wall']}."
        if card == "stoke" and r.get("line_of_sight") == [False, False] and r["damage"] == [2, 5]:
            reason = "Stoke dealt 2 to the enemy off Fire and 5 to the enemy on Fire. Both were behind walls."
    return (reason, key, receipts[key]) if reason else None


def named_match(claim, receipts):
    card, text, surface = claim["card"], claim["claim"], claim["surface"]
    if surface in {"Native hover", "Keyword hover"}:
        r = receipts.get(card, {})
        control = r.get("selector_control", {})
        if card == "stoke" and r.get("damage") == [2, 5] and r.get("line_of_sight") == [False, False]:
            if text == "Deal 2 damage to each enemy you can see." and control.get("visible") == [True, False] and control.get("damage") == [2, 0]:
                return "True", "Both visible enemies took base damage through walls. The hidden control took zero.", card
            if text == "On Fire: +3 damage." and r.get("fire") == [r["enemies"][1]]:
                return "True", "Only the enemy on Fire took the extra 3 damage.", card
        if card == "white_silence" and text == "Deal 8 damage to each enemy you can see on Ice.":
            if r.get("damage") == 8 and r.get("line_of_sight") is False and control.get("visible") == [True, True, False] and control.get("damage") == [8, 0, 0]:
                return "True", "The visible enemy on Ice took 8 through a wall. The off-Ice and hidden controls took zero.", card
        if card == "sleet_squall" and text == "Deal 3 damage to the target.":
            if r.get("damage") == 3 and r.get("distance_at_hit", 0) > 3 and r["clicked"] != r["enemy_after_push"]:
                return "True", "The pushed target took 3 after moving past the first action's Range.", card
    if "gains Expose 2" in text and text.startswith("A unit entering Ice or starting a turn on Ice"):
        r = receipts["ice_rule"]
        if r["expose_before_activation"] == 0 and r["expose_after_activation"] == 2 and r["entry_result"].get("expose") == 2:
            return "True", "An enemy gained Expose 2 both on Ice entry and at an activation starting on Ice.", "ice_rule"
    if text == "Spending Time makes your next turn come later." and surface == "Time hover":
        r = receipts["time_rule"]
        if r["more_time"] > r["less_time"] and r["later_turn"] > r["earlier_turn"]:
            return "True", "With one Card Play in both cases, the higher Time cost scheduled a later activation.", "time_rule"
    if text in {
        "Block absorbs damage until the start of the holder's next turn.",
        "Stoneskin absorbs damage after Block and stays until used up.",
    }:
        r = receipts["defense_rule"]
        before = r["before"]
        hit = r["after_hit"]
        start = r["after_activation"]
        if hit["block"] == start["block"] == 0 and 0 < hit["stoneskin"] < before["stoneskin"] == start["stoneskin"] and hit["hp"] == before["hp"]:
            return "True", "The first hit drained Block before Stoneskin. At the next activation only Block expired.", "defense_rule"
    if card == "cinder_trail" and text in {"This turn, Fire doesn't damage you.", "Fire doesn't damage you this turn."}:
        r = receipts[card]
        if r["fire_entry_without_protection"] >= 0 and r["fire_entry_with_protection"] > r["fire_entry_without_protection"]:
            return "True", "Cinder Trail prevented the Fire-ground entry damage seen with Guarded Step.", card
    if card == "salamander_heart" and text == "You ignore Fire damage.":
        r = receipts[card]
        if r["fire_entry_with_rite"] > r["fire_entry_without_rite"]:
            return "True", "The Rite prevented the Fire-ground entry hit seen in the control.", card
    if card == "frost_circuit" and "each connected Ice tile" in text:
        r = receipts["frost_circuit"]
        if set(r["ice_before"]) == set(r["ground_after"]["electrified"]):
            return "True", "All connected Ice converted in the visibility-boundary fixture.", "frost_circuit"
    if card in {"skybolt", "thunderstone"} and "ignoring Range and line of sight." in text:
        key = f"infinite_range/{card}"
        r = receipts[key]
        if r["visible"] and not r["line_of_sight"] and r["damage"] > 0:
            return "True", "The visible enemy behind a wall was a legal target and took damage.", key
    if card == "immolation" and "sparing you." in text and surface == "Face sentence":
        r = receipts[card]
        if not r["hero_damage"] and r["enemy_damage"] > 0 and not r["fuel_after"]:
            return "UNTESTED", "The near Fire Burst spared the hero. Other fuel layouts in this sentence lack a fixture.", card
    return None


def check_claim(claim, all_claims, runtime):
    card, variant = claim["card"], claim["variant"]
    mode = "legacy" if variant == "legacy" else "base"
    receipt = runtime["cards"][card][mode]
    if runtime["witnesses"]:
        finding = named_finding(claim, runtime["witnesses"])
        if finding:
            reason, key, details = finding
            return outcome(claim, "False", reason, {"key": key, "receipt": details})
        match = named_match(claim, runtime["witnesses"])
        if match:
            verdict, reason, key = match
            return outcome(claim, verdict, reason, {"key": key, "receipt": runtime["witnesses"][key]})
    if claim["kind"] == "stat":
        observed = stat_observation(claim, receipt, all_claims)
        if observed is not None:
            actual, proof = observed
            expected = int(claim["amount"])
            verdict = "True" if actual == expected else "False"
            return outcome(claim, verdict, f"Displayed {expected}. The committed play measured {actual}.",
                           {"key": f"stat/{card}/{mode}/{claim['stat']}", "receipt": proof})
        if (claim["stat"], receipt.get("after", {}).get("destination")) in {
            ("consume", "consume"), ("exhaust", "burn"), ("rite", "burn"),
        } and not claim.get("segment"):
            return outcome(claim, "True", "The played card went to the named destination.",
                           {"key": f"destination/{card}/{mode}", "receipt": receipt["after"]["destination"]})
    if claim["kind"] == "panel":
        text = claim["claim"]
        stat_patterns = {
            "draw": r"Draw (\d+) cards?\.",
            "heal": r"Restore (\d+) Health\.",
        }
        for stat, pattern in stat_patterns.items():
            match = re.fullmatch(pattern, text)
            if not match:
                continue
            companions = [c for c in all_claims if c.get("stat") == stat and c.get("amount") == int(match[1])]
            if len(companions) != 1:
                continue
            observed = stat_observation(companions[0], receipt, all_claims)
            if observed is not None and observed[0] == int(match[1]):
                return outcome(claim, "True", "The matching effect measured the stated amount.",
                               {"key": f"stat/{card}/{mode}/{stat}", "receipt": observed[1]})
    if claim["kind"] == "pattern":
        probe = runtime["patterns"].get(f"{card}/{mode}")
        matched = pattern_observation(claim, probe, all_claims)
        if matched:
            verdict, proof = matched
            return outcome(claim, verdict, "Affected and control tiles matched the diagram in the sampled orientation.",
                           {"key": f"pattern/{card}/{mode}", "receipt": proof})
    if "blocked" in receipt:
        why = receipt["blocked"]
    else:
        why = {
            "chip": "No fixture tested the full target category and the range boundary.",
            "pattern": "No isolated footprint receipt matched this diagram's anchor, mode, and affected tiles.",
            "sentence": "No receipt measured all of the quantities, conditions or order in this statement.",
            "panel": "No matched rule fixture tested this clause in the state it describes.",
            "stat": "The play did not isolate this token's effect, trigger or range boundary.",
        }[claim["kind"]]
    return outcome(claim, "UNTESTED", why)


def audit(cards, runtime):
    ledger = defaultdict(list)
    for card, presentation in sorted(cards.items()):
        for variant, view in variants(presentation):
            claims = list(render_claims(card, variant, view))
            for claim in claims:
                ledger[card].append(check_claim(claim, claims, runtime))
    return ledger
