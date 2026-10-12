# itb-02 — Undo free movement until a card commits

## Header
- Goal: like Into the Breach's Undo Move, the player can take back free-movement steps (the 2-movement pool) until they
  commit a card, as long as the step revealed or triggered nothing. Positioning becomes exploratory instead of
  punishing, with no information leak.
- Base: `codex/peer-benchmark`. Depends on: nothing. Runs beside ev-01, map-01, feel-01 (feel-01 also edits
  `run_scene.gd` enemy-phase pacing; keep your run_scene edits to input/HUD wiring and put logic in new files).
- Docs (sections): spec/card_targeting.md (cancel conventions), spec/turn_clock.md (activation), spec/analytics.md
  (player turn events), spec/forced_movement.md (none expected), the Umbra paragraphs in combat_engine.gd 53–78/207–232.
- Owned files: new `scripts/movement_undo_rules.gd`, new `scripts/movement_undo_button.gd`, new
  `tests/suites/movement_undo_suite.gd` + `tests/movement_undo_test.gd`, new `tests/movement_undo_probe.gd`;
  modify `scripts/combat_engine.gd` (only: a pure "was this walk reversible" report from `apply_player_movement`, no
  rule changes), `scripts/run_scene.gd` (wiring ≤ 60 lines), `scripts/input_router.gd` (one action),
  `scripts/controller_prompt_bar.gd` (prompt), `data/grimoire.json` (one controls line), `spec/analytics.md`,
  `spec/movement_undo.md` (new).
- Rules: rules/state of everything except the undo itself unchanged; Windows typed-array rule; no new art;
  `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier standard→high (combat state). Acceptance: (1) a reversible walk can be undone, restoring the exact
  pre-walk combat state; (2) any walk that revealed, triggered, picked up, damaged, or changed anything is committed and
  cannot be undone; (3) committing a card, passing, or ending the activation clears undo; (4) mouse, keyboard and
  controller paths; (5) analytics. Proof: suite + probe + full suite.

## Change (numbered, testable)
1. **Reversibility.** A free-movement walk (one `walk`/move order, possibly several tiles) is *reversible* iff, comparing
   the combat state before and after it, the only differences are: player position, player facing, the movement pool,
   path/visual bookkeeping fields, and fields you list explicitly in `MovementUndoRules.IGNORED_FIELDS` with a one-line
   reason each. In particular NOT reversible when the walk: changed any tile's Umbra visibility or revealed an enemy;
   triggered a trap; picked up loot/items/Embers; entered or left a surface that dealt damage or applied a status
   (Fire, Ice/Chilled, Electrified, Rubble cost counts as a change only via the pool, which is fine); took any damage
   (Bleed etc.); caused an enemy reaction (Retaliate, guard, etc.); changed the turn clock; changed any RNG state;
   emitted any analytics/death/reward/surface event. Implement as a generic deep diff with an allowlist, not a list of
   special cases, so future mechanics default to "not reversible".
2. **History.** Keep a stack of pre-walk snapshots for the current activation, only while every walk on it was
   reversible. A non-reversible walk clears the stack (it and everything before it are committed). Committing a card
   (from the moment the card's resolution starts), Pass, ending the activation, or any enemy action clears the stack.
   Selecting/aiming/cancelling a card does not.
3. **Undo action.** Restores the latest snapshot exactly (state hash equal to the pre-walk state), returns the hero
   presentation to the old tile instantly with a 0.12 s fade-back of the hero sprite (no walk animation; reduced motion:
   instant), and plays the existing soft UI cancel sound. Several undos step back one walk each.
4. **Inputs.** Keyboard `Z` and `Ctrl/Cmd+Z`; mouse: an "Undo move" button (see 5); controller: left trigger if it is not
   already bound in combat, otherwise left stick click — report which. Controller prompt bar shows "Undo move" with the
   device glyph only while undo is available.
5. **Button.** A compact HUD button directly below the existing "2 / 2 movement" chip in the left dock, same width as
   that chip, compact button skin (`UiSkin.VARIANT_COMPACT`), label "Undo move" plus the key glyph `Z` in TEXT_3 like
   the Intents button; visible only while undo is available (no reserved empty space when hidden: the dock does not
   shift because the button sits below the last chip). Tooltip: "Take back your last move. Moves that revealed or
   triggered something can't be undone."
6. **Feedback when blocked.** If the player presses undo when nothing is undoable but the last walk was committed
   because it was not reversible, show the existing short floating notice style at the hero: "Can't undo — something
   changed." (exact text). Otherwise the key does nothing.
7. **Analytics.** Additive `player_move_undone {tiles, activation_seq}` through the existing combat analytics path;
   document in spec/analytics.md.
8. **Grimoire.** Add one line to the existing controls/combat basics entry: "Undo move (Z) takes back free movement
   until you play a card, unless the move revealed or triggered something."
9. **Spec.** spec/movement_undo.md: the rule, the allowlist, inputs, analytics.

## Keep
- Move-and-attack card approach paths (those are card resolutions, never undoable), tutorial gating (undo is disabled
  while the guided tutorial hard gate is active), Pass forecast, turn-clock previews (they must refresh after undo),
  saves (undo history is NOT saved; loading mid-activation has an empty stack).

## Proof
- Suite: reversible walk round-trip hash equality; each non-reversible cause clears history (Umbra reveal, trap,
  pickup, damaging surface, Bleed, Retaliate if applicable); card commit/pass/enemy action clear; multi-step undo;
  tutorial gate; save/load empty stack; deep-diff defaults to non-reversible for an unknown new field.
- Probe (windowed, director runs): states — after a walk with the button visible; after undo; a committed walk with the
  notice; controller prompt bar. 1920x1080.
- Keep green: full suite.

## Out of scope
- Undo of card plays, a full turn rewind, rules changes.
