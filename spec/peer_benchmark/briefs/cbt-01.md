# cbt-01 — "Stay" for move-and-block cards + Immolation innate damage (owner playtest 9 notes 4 + 5)

## Header
- Owner:
  - "move and block cards need a way to not move. Should be as intuitive as possible."
  - "immolation should probably have some innate value beyond detonation. Maybe small damage per tile hit."
- Triage §5 (`spec/peer_benchmark/triage_playtest9.md`):
  - The hero's tile is excluded from Move and Blink targets (`combat_engine.gd:1136`).
  - `_current_action_can_skip()` always returns false (`run_scene.gd:22163`), so the old "Skip Step" label is
    unreachable.
  - Hotfoot's conditional reward is attached to its movement action.
- Triage §4: Immolation is Fire, Epic, Time 4, with a single detonate action.
- Base `codex/peer-benchmark`. Owned: movement targeting, preview, confirmation and resolution in `scripts/run_scene.gd`
  and `scripts/combat_engine.gd`; the Immolation entry in `data/cards.json`; the Move/Blink glossary entries; tests;
  and `spec/analytics.md` (additive field). boon-01 is also editing `run_scene.gd` (opening-boon overlay host only),
  so stay out of that region.

## Change A: Stay
1. A card's Move or Blink action offers **Stay** when the same card has at least one non-movement effect: Block, draw,
   a surface, an attack, or a conditional reward such as Hotfoot's. Pure-movement cards do not offer Stay.
2. **Pointer.**
   - The hero's own tile gets the same legal-destination highlight as the other tiles.
   - Hovering it shows the normal board preview with no movement (Block and other effects applied), and the
     destination chip reads `Stay`.
   - Clicking it resolves the movement at zero distance, and the card continues.
3. **Keyboard and controller.** The tile cursor can land on the hero's tile, and confirming there is Stay. The
   cursor's default starting tile is unchanged.
4. **Rules.**
   - Stay is not a move. It does not fire movement triggers: trails (Cinder Trail, Fan the Flames), "after you move"
     or "when you move" relics, enter or leave tile effects, traps, collisions, or Skate.
   - Effects attached to the movement action that depend only on the turn's starting state still apply. Hotfoot's
     "If turn began on Fire: 4 Block and draw 1" grants on Stay.
   - Immobilized behaviour is unchanged.
5. Remove the dead Skip Step path (`_current_action_can_skip`, its label and its handler). Stay replaces it.
6. Glossary: append this exact sentence to the Move and the Blink tooltip text: `Pick your own tile to stay put.`
7. Analytics: the card-play event gets an additive `stayed: true` when a movement action resolves as Stay. Document
   it in `spec/analytics.md`.

## Change B: Immolation (director data, exact)
- `description`: `Deal 3 to each adjacent enemy. Then Detonate 8 on every Fire tile within 1 of you, including yours.
  You take no damage from it. Empower (2 HP): detonate within 2.`
- `actions`, in this order:
  - `{"type": "aoe", "damage": 3, "range": 0, "pattern": [[0,-1],[1,0],[0,1],[-1,0]], "rotate": false, "element": "fire"}`
  - the existing detonate action, unchanged.
- `empower.mods[0].action`: change `0` to `1`, so Empower still widens only the detonation.
- Balance (director-scored with `tools/card_heuristic.py`): 2.24 → 3.00, against an epic median of 2.47 and a p75 of
  3.97. Re-run the scorer and report the value. If it differs from 3.00 by more than 0.05, report it rather than
  changing numbers.
- If a description length or word budget test rejects the text, report the budget under TODO_DESIGN. Don't shorten
  it yourself.

## Proof
- Tests:
  - Stay on Guarded Step, Warded Advance, Trapdoor (Blink) and Hotfoot: no position change, Block and draw applied,
    Hotfoot's conditional granted on Fire.
  - Pure-movement cards do not offer Stay.
  - No trail, trap or "after you move" trigger fires on Stay.
  - Keyboard confirm on the hero tile.
  - Immolation hits adjacent enemies for 3 with no Fire present, and 3 + 8 with Fire.
  - Empower still widens only the detonation.
- Exact windowed commands for the director (real renderer, 1920x1080, 100% UI scale):
  - a capture of the hover on the hero's tile during Guarded Step targeting, with the `Stay` chip and the Block
    preview;
  - a capture of Immolation's preview with no Fire nearby.
- Full Godot and Python suites PASS.
