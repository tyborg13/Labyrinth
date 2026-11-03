# fix-07 — Petrify reads as one keyword: the icon and its range, nothing doubled

## Header
- **Owner note (2026-10-22):** the Petrify card doubles itself: it shows the Petrify keyword icon, whose tooltip explains
  the effect, and then explains the same effect again in words. "Choose one or the other, not both." If the icon stands
  for Petrify, the card should read Petrify and the range.
- **Today** (`scripts/action_icon_library.gd` ~1523-1538): the card face is [Petrify icon] [range 3] "skips turn"
  "foe gains" [Block 5]. The glossary and grimoire already define Petrify (skip the next turn, still paying its Time;
  gains Block; dragons immune), and Petrified is a real status: the turn-order bar marks it and the
  `death_status_spread` relic (`scripts/surface_variety_relic_rules.gd` ~170) spreads it. So Petrify stays a keyword.
- **Base:** `codex/peer-benchmark`. **Risk tier:** low.
- **Owned:** `scripts/action_icon_library.gd` (the `petrify` case only), `scripts/maneuver_rules.gd` (petrify section),
  `scripts/surface_variety_relic_rules.gd` (the petrify spread line), `data/cards.json` (the `petrify` card only),
  `data/glossary.json` (`petrify` entry), `data/grimoire.json` (`combat:petrify` entry), tests listed below. Don't touch
  `scripts/run_scene.gd`.

## Decisions
1. **Petrify always means the same thing, wherever it comes from:** the enemy turns to stone, skips its next turn
   (the skipped turn still costs its Time), and gains **5 Block** that lasts through your next turn. Dragons are immune.
   The Block is part of the keyword, so the card no longer prints it.
   - One constant `PETRIFY_BLOCK := 5` in `scripts/maneuver_rules.gd`. Remove `"block": 5` from the card's action in
     `data/cards.json` (`apply_petrify` uses the constant). Every Petrify source goes through one helper that sets the
     status, adds the Block and records the existing `petrified` event.
   - The `death_status_spread` relic's Petrify now goes through that helper, so a spread Petrify also grants the 5 Block
     (today it gives none). Its event gains the relic as `source` (additive field; check `spec/analytics.md` mentions of
     the `petrified` event and update it if they list fields).
2. **Card face:** exactly two tokens: [Petrify icon] [range 3]. Remove the "skips turn" text token, the "foe gains"
   marker and the foe Block token.
3. **Text** (exact):
   - Petrify icon tooltip on the card: `Petrify\nThe enemy turns to stone: it skips its next turn (the skipped turn
     still costs its Time) and gains 5 Block, which lasts through your next turn. Dragons are immune.` Build the number
     from `PETRIFY_BLOCK`.
   - Glossary definition: `Turns an enemy to stone: it skips its next turn, still paying its Time, and gains 5 Block
     that lasts through your next turn. Dragons are immune.`
   - Grimoire second paragraph: `Petrify also gives the enemy 5 Block, which lasts through your next turn. It is not
     Freeze: there is no damage multiplier and no Chill interaction. Dragons cannot be Petrified.` (first paragraph
     unchanged)
   - Card `description`: `Petrify an enemy within range 3 (not a dragon). It skips its next turn and gains 5 Block.`
4. **Balance:** unchanged for the card (still skip + 5 Block). Run `tools/card_heuristic.py` for `petrify` and report
   the score before and after (must be equal). The relic gains a small drawback; report it, no retune.

## Tests
- Card rows: `rows_for_card(petrify)` yields exactly the Petrify icon and range 3; no text tokens; the tooltip stack shows
  one Petrify entry with the exact text above.
- Rules: casting Petrify gives the target 5 Block and the status; the relic spread gives the adjacent enemy the status
  and 5 Block and records one `petrified` event with the relic as source; dragons stay immune on both paths; existing
  petrify turn-skip and Block-retention tests still pass.
- Glossary/grimoire consistency tests (`tests/suites/tooltip_consistency_suite.gd` via `tests/glossary_test.gd`, and any
  grimoire test) pass with the new text.
- Mutations (report): restore the "skips turn" token → the card-rows test fails; skip the helper in the relic path →
  the spread-Block test fails.

## Proof
Focused: `tests/glossary_test.gd`, the maneuver/petrify suite(s), the surface-variety relic suite, `card_keywords_test`,
`python3 tests/test_ui_identity_lint.py`, `python3 tools/card_heuristic.py` for petrify. No full suites. Under "Proof for
the design owner", give the windowed command that captures the Petrify card in hand with its focus tooltip stack at
1920x1080, 100% UI scale.

## Out of scope
The Petrify icon art, the turn-order badge, other keywords.
