# chr-02 feedback 2 (director, after peer review of 636adaa8b)

Work on top of HEAD. Do not commit.

1. **Save bloat** (blocker): `deck_card_definitions` (`chronicle_rules.gd:145-153`) snapshots every card because
   `card_def_for_progression(id, state)` adds combat tags (`_card_element`, `_card_action_types`). Compare against
   `GameData.card_def_for_progression(id, {})` (or strip `_card_*` tags before comparing) so only run-specific changes are
   stored, and never store internal tags. Test: a relic-free, upgrade-free `build_record` produces `{}`; an upgraded card
   produces exactly its delta.
2. **Boot time** (blocker): `chronicle_panel.gd` must not preload `run_scene.gd` (main menu now compiles the run scene,
   +~1.2 s boot). Build the card/gear/relic previews without subclassing RunScene — move the three preview builders into
   a small shared script (e.g. `scripts/item_preview_builders.gd`) used by both, or build from `card_widget.tscn`
   directly. Measure `main_menu.tscn` load time before/after (headless) and report it; it must be within +50 ms of the
   parent commit.
3. **Focus tooltip placement**: keyboard/controller tooltips never cover their tile: place below when it fits, otherwise
   above, otherwise beside (right, then left); test that the tooltip rect never intersects its tile.
4. **Hover/focus visibility** (director decision): card tiles keep the design system's socket hover/focus treatment —
   the ember glow — plus a 2 px gold outer ring on focus outside the element edge, so hover/focus is obvious on every
   element colour.
5. **Layout (director decision)** so RELICS is never cut off at rest: move FEATS to the right of THE PATH (top-aligned
   with the PATH header, right column x = 1450 at 1920×1080, same style); put GEAR and RELICS on one row (GEAR first,
   40 px gap, RELICS wraps within the remaining width); SPELLS full width below them. Verify with the overflow record plus
   a 5-section path at 1920×1080 that every section is fully visible without scrolling.
6. **Deleted card ids** in old records: tile shows the card-back art (if no card back asset exists, the neutral socket
   with a dim "?" glyph in the design system's muted text style) and the tooltip shows the id in Title Case with no rules
   text. Never show a TODO string to players.
7. Small: link path icons into focus when a record has no gear/spells/relics; use `is_instance_valid` for
   `_tooltip_host`; downscale card art to the tile size once with a high-quality filter (cached) instead of minifying
   without mipmaps; add a windowed capture with a visible ×N badge.

Proof: chronicle tests (incl. new ones), save-size and normalize-time numbers before/after, main menu load time,
UI lint, full suite; list the windowed probe command.
