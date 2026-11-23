#!/usr/bin/env python3
"""Verify txt-28 copy against the owner's edits and txt-25 face inventory."""

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
EXPEND = "Remove the named ground to use this effect."
METEOR_AIM = "Aim within Range and line of sight."
LEAK = re.compile(r"@(?:kw|term|icon|pattern)\(|[{}]|\[/?(?:color|img|b|url)(?:=|\])")


def load(path):
    return json.loads(Path(path).read_text())


def texts(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for entry in value:
            yield from texts(entry)
    elif isinstance(value, dict):
        for entry in value.values():
            yield from texts(entry)


def panel_texts(surface, term):
    return [panel["text"] for panel in surface["panels"] if panel["term"] == term]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inventory", type=Path)
    args = parser.parse_args()
    inventory = load(args.inventory)
    cards = inventory["cards"]
    before = load(ROOT / "tools/txt25/inventory.json")["cards"]
    edits = load(ROOT / "spec/peer_benchmark/staged/txt-28/text_edits.json")
    edited_cards = []
    old_sentences = []
    for edit in edits:
        if edit["file"] == "data/cards.json":
            old, new = json.loads(edit["old"]), json.loads(edit["new"])
            card_id, = [id for id, row in before.items() if row["card"]["description"] == old]
            old_sentences.append(old)
            edited_cards.append(card_id)
            row = cards[card_id]
            for surface in ("catalog", "hand"):
                if surface in row:
                    assert row[surface]["inspection"]["text"] == new, (card_id, surface)
            if card_id in inventory["articles"]:
                assert inventory["articles"][card_id]["text"].splitlines()[0] == new, card_id
        else:
            source = (ROOT / edit["file"]).read_text()
            assert edit["new"] in source and edit["old"] not in source, edit["file"]
    old_sentences.extend([
        "Remove the named ground from the target's tile to use this effect.",
        "Mark tiles within Range and line of sight.",
        "Consume tile.",
    ])

    for card_id, row in cards.items():
        for variant, surface in row.items():
            if variant == "card":
                continue
            for text in texts(surface):
                assert not LEAK.search(text), (card_id, variant, text)
                if card_id in edited_cards or card_id in {"grounding", "spike_mantle", "caltrops"}:
                    assert not any(old in text for old in old_sentences), (card_id, variant, text)

    for card_id, damage in (("skybolt", 8), ("thunderstone", 5)):
        assert panel_texts(cards[card_id]["catalog"], "ranged") == [
            f"Deal {damage} damage to a visible target within Range."
        ], card_id
    for card_id in ("grounding", "spike_mantle"):
        assert panel_texts(cards[card_id]["catalog"], "surface_consume") == [EXPEND], card_id
    assert inventory["glossary"]["expend_article"]["text"].splitlines()[0] == EXPEND
    meteor = cards["meteorfall"]["catalog"]
    assert not panel_texts(meteor, "ranged")
    assert panel_texts(meteor, "range") == [METEOR_AIM]
    assert meteor["face"] == before["meteorfall"]["catalog"]["face"]
    assert panel_texts(cards["powder_keg"]["catalog"], "range") == [
        "Place the Powder Keg within Range."
    ]
    old_face = before["caltrops"]["catalog"]["face"]
    new_face = cards["caltrops"]["catalog"]["face"]
    assert new_face == [line.replace("Consume tile.", "Consume.") for line in old_face]
    assert new_face != old_face and new_face[0] == "Tile [range] 2"
    for variant in ("catalog", "hand"):
        if variant in cards["caltrops"]:
            assert cards["caltrops"][variant]["face"] == new_face
    print("CALTROPS BEFORE:", " / ".join(old_face))
    print("CALTROPS AFTER: ", " / ".join(new_face))
    articles = sum(card_id in inventory["articles"] for card_id in edited_cards)
    print(f"TXT28 COPY: PASS ({len(edits)} director edits, {articles} card articles, "
          f"{len(cards)} cards scanned, both new panel templates)")


if __name__ == "__main__":
    main()
