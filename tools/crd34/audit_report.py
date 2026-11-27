#!/usr/bin/env python3
"""Verify the exact widget-export changes against crd-32's combat audit."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "crd33"))
from claims import audit  # noqa: E402
from verify_audit import face_data, false_findings, finding_key  # noqa: E402


SURFACES = {
    "revealing_glare": "illuminate",
    "searing_light": "illuminate",
    "white_silence": "surface_ice",
}
LIGHT = "An enemy starting a turn in Light gains Expose 2."
OLD_LIGHT_INLINE = "Each Enemy in Light\nHit each visible enemy in Light."
SWEEPS = {"stoke", "white_silence"}
SWEEP_COPY = "Hit each visible enemy that meets the named condition."
HUSK_BEFORE = "Any of your illusions on the board."
HUSK_AFTER = "Any of your visible Illusions on the board."
GROUNDSPLIT = "This enemy damages you if you stand within 2 tiles of an Outcrop this enemy raised."
VIEWS = ("catalog", "hand", "legacy")
TEMPLATE_MARKER = re.compile(r"\bX\b|\{[^{}\n]+\}")


def verify_exports(before, after, glossary):
    expected_ids = SURFACES.keys() | SWEEPS | {"empty_husk"}
    observed_ids = {card_id for card_id in before if before[card_id] != after[card_id]}
    assert expected_ids == observed_ids, observed_ids
    for card_id in sorted(observed_ids):
        for mode in VIEWS:
            old, new = before[card_id][mode], after[card_id][mode]
            assert face_data(old) == face_data(new), (card_id, mode, "face")
            if not old:
                continue
            expected_panels = []
            for panel in old["panels"]:
                term, sentence = panel["term"], panel["text"]
                if card_id in SWEEPS and term == "all_enemies" and sentence == SWEEP_COPY:
                    continue
                if SURFACES.get(card_id) == term:
                    definition = LIGHT if term == "illuminate" else glossary[term]
                    panel = {**panel, "text": definition, "display": definition}
                expected_panels.append(panel)
            assert new["panels"] == expected_panels, (card_id, mode, "keyword")
            substitutions = {HUSK_BEFORE: HUSK_AFTER} if card_id == "empty_husk" else {}
            if SURFACES.get(card_id) == "illuminate":
                substitutions[OLD_LIGHT_INLINE] = LIGHT
            expected_native = [{**panel, "text": substitutions.get(panel["text"], panel["text"])}
                               for panel in old["native"]]
            assert new["native"] == expected_native, (card_id, mode, "native")
    return observed_ids


def verify_templates(cards):
    count = 0
    inline = set()
    for card_id, card in cards.items():
        for mode in VIEWS:
            view = card[mode]
            if not view:
                continue
            for panel in view["panels"]:
                assert not any(TEMPLATE_MARKER.search(panel[key]) for key in ("text", "display")), (card_id, mode, panel)
                count += 1
            condition_icons = {token["icon"] for row in view["rows"] for token in row
                               if token.get("kind") == "surface_condition"}
            for panel in view["native"]:
                if panel["term"] in condition_icons and TEMPLATE_MARKER.search(panel["text"]):
                    inline.add((card_id, panel["term"]))
    print(f"CRD34 TEMPLATES: {count} keyword panels checked, 0 unfilled markers")
    for card_id, term in sorted(inline):
        print(f"CRD34 LEGACY CONDITION ICON: {card_id} | {term} | unfilled glossary X")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proof_dir", type=Path)
    args = parser.parse_args()
    before, after, runtime = (
        json.loads((args.proof_dir / path).read_text())
        for path in ("before.json", "after.json", "runtime.json")
    )
    assert before["sources"] == after["sources"]
    population = set().union(*map(set, after["sources"].values()))
    assert population == before["cards"].keys() == after["cards"].keys() == runtime["cards"].keys()
    glossary = {entry["id"]: entry["definition"] for entry in json.loads(Path("data/glossary.json").read_text())}
    changed = verify_exports(before["cards"], after["cards"], glossary)

    frozen = json.loads(subprocess.check_output(["git", "show", "codex/crd-32:tools/crd32/false.json"]))
    frozen_false = {finding_key(entry, entry["witness"]) for entry in frozen}
    baseline = false_findings(audit(before["cards"], runtime))
    ledger = audit(after["cards"], runtime)
    final = false_findings(ledger)
    assert baseline <= frozen_false and final <= baseline, (baseline - frozen_false, final - baseline)
    assert baseline - final == {("empty_husk", "base", HUSK_BEFORE, "", "empty_husk")}
    print(f"CRD34 AUDIT: {len(population)} IDs, {len(baseline)} -> {len(final)} distinct False rows, 0 new False")
    print(f"CRD34 DIFF: only {', '.join(sorted(changed))} hover copy changed")
    verify_templates(after["cards"])

    husk = runtime["witnesses"]["empty_husk"]
    assert husk["hidden"] and not husk["legal_while_hidden"] and husk["hidden_rejection"]
    assert husk["hero_after_visible_click"] == husk["clicked"]
    assert any(panel["text"] == HUSK_AFTER for panel in after["cards"]["empty_husk"]["catalog"]["native"])
    print(f"CRD34 TRUE empty_husk | {HUSK_AFTER} | Native hover")

    groundsplit = (args.proof_dir / "groundsplit.log").read_text().splitlines()
    assert f"TXT37 GROUNDSPLIT GLOSSARY: {GROUNDSPLIT}" in groundsplit
    assert "TXT37 GROUNDSPLIT: PASS (7 live resolutions)" in groundsplit
    witnesses = (args.proof_dir / "rules-witness.log").read_text().splitlines()
    light = next(json.loads(line.split(": ", 1)[1]) for line in witnesses if line.startswith("CRD34 LIGHT WITNESS: "))
    assert (light["before"], light["after"], light["unlit_control"]) == (0, 2, 0)
    units = next(json.loads(line.split(": ", 1)[1]) for line in witnesses if line.startswith("CRD34 GROUNDSPLIT UNITS: "))
    assert (units["hero_damage"], units["enemy_damage"], units["illusion_damage"]) == (7, 0, 7)
    grimoire = json.loads(Path("data/grimoire.json").read_text())
    topic = next(entry for entry in grimoire["entries"] if entry["id"] == "keyword:terrain_burst")
    assert topic["body"] == [GROUNDSPLIT]
    print(f"CRD34 TRUE light | {LIGHT} | Keyword and inline condition")
    print(f"CRD34 TRUE groundsplit | {GROUNDSPLIT} | Glossary")


if __name__ == "__main__":
    main()
