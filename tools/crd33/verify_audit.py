#!/usr/bin/env python3
"""Compare crd-32's complete audit and the current live card exports."""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess

from claims import audit, variants

GENERIC = "Deal {amount} damage to a target within Range and line of sight."
CHANGES = {
    "stoke": {2: "Deal 2 damage to each enemy you can see.", 3: "On Fire: +3 damage."},
    "white_silence": {8: "Deal 8 damage to each enemy you can see on Ice."},
    "sleet_squall": {3: "Deal 3 damage to the target."},
}
HOVER_FIELDS = {"tooltip", "card_tooltip", "damage_target_tooltip", "card_keyword"}


def finding_key(entry, witness):
    return (
        entry["card"], entry["variant"], entry["claim"],
        entry.get("subject", entry.get("clause", "")), witness,
    )


def false_findings(ledger):
    return {
        finding_key(entry, entry["witness"]["key"])
        for entries in ledger.values() for entry in entries if entry["verdict"] == "False"
    }


def face_data(value):
    if isinstance(value, list):
        return [face_data(item) for item in value]
    if isinstance(value, dict):
        return {
            key: face_data(item) for key, item in value.items()
            if key not in HOVER_FIELDS and key not in {"panels", "native"}
        }
    return value


def verify_surfaces(before, after):
    changed = {card for card in before if before[card] != after[card]}
    assert changed == CHANGES.keys(), changed
    for card in changed:
        phrases = {GENERIC.format(amount=n): text for n, text in CHANGES[card].items()}
        old_views, new_views = dict(variants(before[card])), dict(variants(after[card]))
        assert old_views.keys() == new_views.keys(), card
        for mode, old in old_views.items():
            new = new_views[mode]
            assert face_data(old) == face_data(new), (card, mode)
            expected_native = [
                {**panel, "text": "Ranged\n" + phrases[panel["text"].split("\n", 1)[1]]}
                if panel["text"].startswith("Ranged\n") and panel["text"].split("\n", 1)[1] in phrases
                else panel for panel in old["native"]
            ]
            assert expected_native == new["native"], (card, mode, "native")
            # Compare the complete panel models, including the original selector,
            # ground, Stagger and Range definitions.
            expected_panel = {
                "icon": "all_enemies",
                "term": "all_enemies",
                "title": "Sweeping Strike",
                "text": next(iter(phrases.values())),
                "display": next(iter(phrases.values())),
            }
            if card == "sleet_squall":
                expected_panels = [
                    {key: phrases.get(value, value) if key in {"text", "display"} else value
                     for key, value in panel.items()}
                    for panel in old["panels"]
                ]
            else:
                index = 1 if card == "stoke" else 2
                expected_panels = old["panels"][:index] + [expected_panel] + old["panels"][index:]
            assert expected_panels == new["panels"], (card, mode, "keyword")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("runtime", type=Path)
    args = parser.parse_args()

    before, after, runtime = (json.loads(path.read_text()) for path in (args.before, args.after, args.runtime))
    assert before["sources"] == after["sources"]
    population = set().union(*map(set, after["sources"].values()))
    assert population == before["cards"].keys() == after["cards"].keys() == runtime["cards"].keys()
    verify_surfaces(before["cards"], after["cards"])
    baseline = false_findings(audit(before["cards"], runtime))
    ledger = audit(after["cards"], runtime)
    final = false_findings(ledger)
    frozen = json.loads(subprocess.check_output(["git", "show", "codex/crd-32:tools/crd32/false.json"]))
    assert baseline == {finding_key(entry, entry["witness"]) for entry in frozen}
    fixed = {
        (card, "base", GENERIC.format(amount=amount), "", card)
        for card, damage in CHANGES.items() for amount in damage
    }
    assert baseline - final == fixed and not final - baseline, (baseline - final, final - baseline)
    for card, texts in CHANGES.items():
        for text in texts.values():
            hits = [entry for entry in ledger[card] if entry["claim"] == text]
            surfaces = {entry["surface"] for entry in hits}
            expected = {"Native hover"} if text.startswith("On Fire:") else {"Native hover", "Keyword hover"}
            assert surfaces == expected and all(entry["verdict"] == "True" for entry in hits), hits
            print(f"CRD33 TRUE {card} | {text} | {', '.join(sorted(surfaces))}")
    counts = Counter(entry["verdict"] for entries in ledger.values() for entry in entries)
    print(f"CRD33 AUDIT: {len(population)} IDs, {len(baseline)} -> {len(final)} distinct False rows, 0 new False")
    print(f"CRD33 CLAIM INSTANCES: {counts['True']} True, {counts['False']} False, {counts['UNTESTED']} UNTESTED")
    print(f"CRD33 DIFF: only {', '.join(sorted(CHANGES))} hover wording changed")


if __name__ == "__main__":
    main()
