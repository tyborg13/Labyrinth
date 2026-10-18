# purge-01 — Purge screen redesign (playtest 10)

## Header
- **Owner, playtest 10 (2026-10-18), seen at the Scavenger:** "the new purge interface is well below our visual
  standards ... Text not fitting within buttons, huge amounts of dead space, just really far below the rest of our
  experience."
- **Cause:** deck-01 reused the Character menu's 420 px text column (`Menu.column`) inside a large dialog
  (`scripts/magic_purge_overlay.gd`), with a separate confirmation (`scripts/magic_purge_confirmation.gd`), and no
  director mockup. The Scavenger and the Campfire open the same overlay.
- **Direction (director):** purge from the real cards, in the visual language of the combat pile viewer
  (`run_scene.gd` `_build_pile_overlay`, `PILE_DIALOG_CARD_SIZE` 196 × 276): pick a card from a grid, confirm with that
  card shown full size. Visual design system: `spec/visual_design_system.md`; UI skill
  `.codex/skills/create-labyrinth-ui`; UI identity gate `spec/ui_identity_gate.md`.
- **Base:** `codex/peer-benchmark`. **Owned:** `scripts/magic_purge_overlay.gd`, `scripts/magic_purge_confirmation.gd`,
  a shared dialog/grid helper extracted from the pile viewer if you reuse it (the pile viewer must render
  byte-identically), the purge hooks in `run_scene.gd`/`scavenger_shop_view.gd` only where needed, the magic deck tests
  and probes.

## Baseline and mockup
- Director baseline captures (real renderer, 1920x1080): `spec/peer_benchmark/staged/purge-01/baseline_sheet.png`.
  The Scavenger's bottom-bar "Purge" service crams "Purge / Remove a spell from your deck. / 50 Embers" into one plate
  (the label runs off its top edge); the list is 11 thin rows in the top-left of a mostly empty dialog.
- Director layout mockup (true sizes over the real shop capture; card faces are placeholders):
  `spec/peer_benchmark/staged/purge-01/mockup_grid.png`. Dialog 1532 × 722 at (194, 179) for 11 identities.

## Layout (1920x1080, 100% UI scale; all values exact)
0. **Scavenger service button** (`scavenger_shop_view.gd` bottom bar): one line, "Purge a spell", in the same plate
   size and type as "Sell from pack". The price moves to the Scavenger's existing parchment price tag
   (`scavenger_price_tag.gd`, the tag used under the wares) pinned to the plate's top-right corner, with its existing
   unaffordable treatment. "Remove a spell from your deck." becomes the plate's tooltip. Nothing else in the bar moves.
1. **Backdrop:** full-screen scrim `Color(0.02, 0.02, 0.02, 0.72)` over the shop or campfire.
2. **Dialog:** the pile viewer's dialog chrome (same stylebox, 14 px radius, shadow 12, `apply_outer_panel_frame`
   `SURFACE_DIALOG`). Margins: 32 left/right, 24 top, 28 bottom. Centered.
   - Width fits the columns used: `cols × 196 + (cols − 1) × 16 + 64`, with `cols = min(identities, 7)`; minimum 760.
   - Height: header 64 + 16 gap + grid viewport + top/bottom margins. The viewport shows up to 2 rows:
     `rows × 276 + (rows − 1) × 20 + 18` (18 px headroom for the time-watch crown), `rows = min(ceil(identities/7), 2)`.
     More than 14 identities scroll vertically (pile viewer scrollbar style); the dialog never exceeds 1080 − 2×24.
3. **Header row (64 px):**
   - Left: `UiSectionHeader` with title "PURGE A SPELL" and count "<n> spells" (gold eyebrow, count, fading rule).
   - Right, Scavenger only: a `UiStatChip` with the Ember icon, value = the purge price, caption "PRICE". When the
     player can't afford it, the value colour is `Palette.DANGER`.
   - Far right: the pile viewer's 40 × 40 `VARIANT_ICON` close button ("X"), same behaviour as Cancel.
4. **Grid:** one real `CardWidget` per spell identity at the pile viewer's 196 × 276 cell, sorted like the Character
   magic list. Gaps: 16 horizontal, 20 vertical; a last partial row is centred. Duplicates use the pile viewer's stack
   treatment (`PILE_STACK_OFFSET` 6,7, up to 3 layers) and its ×N count. Hover and focus use the card's existing lift
   and gold focus; nothing else is drawn per card. Clicking, or Enter/A on a focused card, opens the confirm step.
5. **Confirm step** (inside the same overlay; the grid dialog stays visible at 35% modulate behind it):
   - Heading "Purge this spell?" (UI font, `SIZE_TITLE`, `GOLD_BRIGHT`, outline 3), centred 24 px above the card.
   - The selected card at full size (250 × 352) centred at screen centre (y offset −40), over a soft crimson glow
     (`Palette.DANGER` at 30% alpha, 48 px blur radius) behind it.
   - Buttons 28 px below the card, centred, 16 px apart, height 52, width fitted to the text with 28 px side padding and
     a 200 px minimum:
     - "Purge" — `VARIANT_DESTRUCTIVE`. At the Scavenger it reads "Purge for <price> Embers".
     - "Back" — `VARIANT_STANDARD`; default focus (the safe choice).
   - Scavenger, can't afford: "Purge for <price> Embers" disabled, and one line 12 px under the buttons in
     `Palette.DANGER`, body font 16 px: "You have <held> Embers."
6. **On confirm:** play the existing card exhaust effect and `card.exhaust` cue on the confirm-stage card (the probe
   already counts this cue), then close; the Scavenger shows its existing "Purged <Card>." notice; the Campfire
   continues as today.
7. **Campfire:** identical without the price chip; the button reads "Purge".
8. **Text fit:** every label inside a button or chip fits its control at 100% UI scale, with no clipping or ellipsis.
   Add a regression that walks every Button/Label in the overlay and fails on clipped text.

## Input
- Pointer, keyboard and controller: arrow/D-pad moves between cards (rows wrap), up from the first row reaches the
  close button; Escape/B/back closes the confirm step, then the overlay. In the confirm step left/right moves between
  Purge and Back. Keep every existing purge input and analytics event (`purge` with source and price).

## Proof
- Headless: magic deck tests, input test and mutation test updated; the text-fit regression; UI identity lint
  (`python3 tests/test_ui_identity_lint.py`, never raise the baseline).
- Windowed, run by the director: `tests/magic_deck_ui_probe.gd` at 1920x1080 / 100% captures — Scavenger grid with 14
  spells incl. duplicates; grid with 4 spells; keyboard focus on a card; confirm (affordable); confirm (can't afford);
  Campfire grid; Campfire confirm; a 20-spell grid scrolled; reduced motion. Give the exact command.
- Don't run the full suites; the director runs them at merge.

## Out of scope
Purge rules and prices, the Character magic panel, the Scavenger room, other overlays.
