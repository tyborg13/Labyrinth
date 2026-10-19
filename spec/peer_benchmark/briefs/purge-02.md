# purge-02 — Purge polish: duplicate badge and larger header (owner note)

## Header
- **Owner, purge-redesign verdict (2026-10-19):** "sooo much better. I think the "x2" for multiple copies should be
  more pronounced. The "purge a spell" header maybe a bit bigger. Otherwise, looking very good."
- **Base:** `codex/peer-benchmark` (purge-01 merged at 3d8b22d4f). **Owned:** `scripts/pile_dialog_view.gd`, the
  Purge overlay header in `scripts/magic_purge_overlay.gd`, the magic deck tests and probe, and the pile viewer probe or
  tests if a badge assertion is needed.
- Visual language: `spec/visual_design_system.md` (Socket: the painted antique-bronze medallion ring,
  `assets/art/ui/visual_pass_4/medallion_ring.png` with geometry in `medallion_ring.json`).

## Change (director values)
1. **Duplicate count badge** (`pile_dialog_view.gd`, `PileCopyCount`; shared by Purge and the combat pile viewer, so
   both get it):
   - the painted medallion ring at **52 × 52 px**, centred on the top card's bottom-right corner, inset 6 px from that
     corner, drawn above the card;
   - inside the ring, a dark centre disc in `Palette.INK_0` at 92% alpha;
   - the text "×N" in the UI font at **22 px**, `Palette.GOLD_BRIGHT`, outline 3 px in `Palette.TEXT_OUTLINE`, centred;
   - no glow or animation; it doesn't take input; it isn't drawn for single copies.
2. **Purge header:** "PURGE A SPELL" moves from the small section eyebrow to letter-spaced caps at
   `UiTypography.SIZE_SECTION_LARGE` (24 px), `GOLD_BRIGHT`, outline 3. The count ("14 spells") goes to `SIZE_BODY_LARGE`
   (18 px) in `TEXT_2`. The fading rule stays. The header row grows from 64 to **72 px**, and the dialog height grows to
   match. Everything else in the layout is unchanged.
3. **Tests:** the text-fit regression covers the badge and the new header; add an assertion that the badge exists only
   for counts above 1 and sits on the top card's corner; the combat pile viewer's duplicate display gets the same check.

## Proof
- Headless: magic deck tests, text-fit, mutations, UI identity lint, the registration audit
  (`tests.test_test_registration_audit`), and the pile viewer tests.
- Windowed, run by the director: `tests/magic_deck_ui_probe.gd` at 1920x1080 (contract unchanged) plus a combat pile
  view capture with duplicates. Give the exact commands. No full suites.

## Out of scope
Anything else in the Purge or pile layouts, card art, rules.
