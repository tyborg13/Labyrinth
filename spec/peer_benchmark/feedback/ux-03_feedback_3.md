# ux-03 feedback 3 (director, after peer review of 36db709a4)

Work on top of HEAD. Do not commit.

1. **Inline icon hover** (blocker): `inline_icon_text.gd:77-90` passes the definition as `add_image`'s 12th argument
   (`alt_text` in Godot 4.6); the tooltip slot (9th) still gets the label. Put the glossary definition in the tooltip
   argument, keep `alt_text` = the label. Test via `label.get_tooltip(<point over the image>)` after layout (not by calling
   `_make_custom_tooltip` directly).
2. **Click must not pin** (blocker): stacks stay open on focus only when focus came from keyboard/controller; a mouse click
   that focuses a badge behaves like hover (closes on mouse exit). Probe case: click a badge, move to the board, assert the
   stack is hidden.
3. **Off-screen at 1.25 UI scale** (blocker; director layout decision):
   - Choice screen: after the 3-column and 4-column below-row flows, the final fallback places the flow block **above the
     card row** (bottom 12 px above the cards' top edge, centred on the hovered card, clamped with 24 px margins); covering
     the "Claim your treasure" banner is allowed only in this fallback; never cover the hovered card.
   - Owned tray: clamp vertically; when the single column would cross the bottom margin, flow the glossary panels into a
     second column to the right of the first (12 px gap), top-aligned, then clamp horizontally.
   - Probe and tests at 1920×1080, 1670×1043 (Steam Deck) and 1536×864 (1.25 UI scale): every relic × every position fits.
4. **Controller double panel**: suppress the analog cursor's detail callout (`_controller_candidate_for_control`,
   `run_scene.gd:3044`) for controls that own a glossary stack; probe with `sync_virtual_cursor = true`.
5. **One source of truth**: remove the now-dead `description` copies from `ActionIconLibrary.KEYWORDS` (the glossary
   owns definitions); suites that asserted them (`en02_enemies_suite.gd:391-392`, `en03_enemies_suite.gd:421-422`,
   `turn_clock_copy_suite.gd:51-52`) read the glossary instead; card stack titles use the glossary `name` too. Keep the
   card pixel-identity before/after proof as a one-time artifact for this unit, but do not leave a permanent test that
   pins today's text (`tests/glossary_card_copy_before.json` equality) — ux-04 rewrites the text next.
6. **Missing entries fail loudly**: a test that every keyword/icon used anywhere resolves to a non-empty definition;
   at runtime, a missing definition falls back to the label (never an empty body) and logs once.
7. Small: test the below-row flow anchors to the row bottom (cards of different heights); early-out `_layout_choice` when
   nothing moved; make `InlineIconText.apply_to` script swapping explicit opt-in (no silent swaps); hand-hover
   `hide_stack()` must not close a stack whose owner is still hovered/focused; refresh `tests/glossary_handoff.md`.

Proof: glossary tests, probe logic at the three resolutions, UI lint, icon identity, full suite; list the windowed probe
command (with the 1536×864 and 1670×1043 variants).
