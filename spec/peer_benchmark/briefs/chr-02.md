# chr-02 — Chronicle: spells as card tiles, tooltips on every tile

## Header
- Owner, playtest 7 (2026-10-15): "the new Chronicle looks really cool ... it does give like a bunch of text for, I think,
  the cards or relics ... a bunch of just names of things where I think we need to display that a little more visually."
  Baseline (`tests/chronicle_probe.gd`, `chronicle.png` / `spells_overflow.png`): GEAR and RELICS are icon tiles; SPELLS
  is a dot-separated list of card names that overflows into "+10 more".
- Base: `codex/peer-benchmark`. Owned files: `scripts/chronicle_panel.gd`, `scripts/chronicle_rules.gd` (only if the
  record lacks a field the tiles need — additive, backward compatible with saved chronicles), a small new
  `scripts/chronicle_card_tile.gd` if it keeps the panel readable, `tests/chronicle_test.gd`, `tests/chronicle_probe.gd`
  (+ contract). Read-only: card/relic/gear tooltip and preview code (reuse it).
- Rules: build from the visual design system and existing components (`ui_socket.gd` sockets, `ui_tooltip_panel.gd`,
  the existing card preview used in-run, palette tokens, `ui_typography.gd`); UI identity lint must not rise
  (`python3 tests/test_ui_identity_lint.py`); mouse, keyboard and controller focus all work; Windows typed-array rule;
  1920×1080 at 100% UI scale.

## Layout (director decisions)
Detail area below THE PATH, top to bottom:
1. **Row A**: GEAR tiles (left, unchanged) and FEATS (right, unchanged text list, same x as today's FEATS column).
2. **Row B — SPELLS** (moved out of the middle column to its own full-width row, header style unchanged): one **card
   tile** per distinct card in the run's final deck, in the chronicle's recorded deck order.
   - Tile: 48×64 px portrait socket in the same socket style as the gear/relic tiles; inside, the card's own art
     centre-cropped to fill; a 2 px inner edge in the card's element accent (`ElementData.accent`), neutral edge for
     element-less cards; the upgraded state uses the in-run card's upgraded marker if one exists (do not invent one).
   - Duplicates: one tile with a count badge `×N` (N ≥ 2) at the bottom-right corner: palette-token pill, body font at
     14 px, the badge overlapping the socket edge by 4 px.
   - Spacing 8 px; wrap to the detail area's width; **at most 2 rows**. If more distinct cards remain, the last tile is a
     same-size socket showing `+N` centred (N = distinct cards not shown); hovering/focusing it shows a tooltip listing
     the remaining card names with their counts, one per line.
3. **Row C — RELICS** (unchanged tiles), below SPELLS.
4. All rows keep the current left edge (x = 670 at 1920×1080) and section header style; vertical gaps between rows 28 px.

## Tooltips (every tile explains itself)
- Spell tile: hover/focus shows the same full card preview used in the run (name, cost, rules text, element), placed
  with the existing tooltip placement rules.
- Gear and relic tiles: hover/focus shows the same tooltip as in-run gear/relic tooltips (if ux-03's relic glossary
  stack has landed by merge time, the relic tiles use it automatically through the shared relic tooltip function).
- Path node icons: keep any existing tooltip; if none exists, show the room type name only (from the existing room type
  display names; do not invent text).

## Proof
- Tests: tile count/grouping/order from a fixture run (duplicates, upgraded card, element-less card, 45 distinct cards →
  2 rows + `+N`), focus order (gear → spells → relics, left-to-right, row by row), save compatibility with chronicle
  records written before this change, UI identity lint, full suite.
- Windowed (list the commands; the director runs them): the chronicle probe at 1920×1080 capturing the default record,
  the overflow record (`spells_overflow`), a hovered spell tile, a hovered `+N` tile, a hovered relic tile and controller
  focus on a spell tile.

## Out of scope
Chronicle list/left column, the PATH row, feats wording, run-end recap screen.
