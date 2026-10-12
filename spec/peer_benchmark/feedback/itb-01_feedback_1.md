# itb-01 feedback 1 (director)

Good structure. Decisions for every TODO_DESIGN, plus two fixes. Replace each `TODO_DESIGN_*` constant with the named
value below (rename the constants to plain names), update spec/threats_at_rest.md to state them.

## Decisions
1. **Pill padding**: 8 px horizontal on both sides of the content. When the order disc is present, add 4 px more on
   the left (the disc overlaps the plate's left edge by 4 px). Vertical: content centred in the 26 px plate.
2. **Content gaps**: 4 px between the primary icon and the primary number; 7 px between the primary number (or
   icon, when there is no number) and the secondary icon; 3 px between the secondary icon and its number.
3. **Secondary priority** (show the first present, max one): Push/Pull distance → Immobilize → Freeze/Chilled →
   Shock → Bleed → Expose → Stagger. A secondary with no number shows its icon alone.
4. **Stack overflow**: stacking levels are base, +30 px, +60 px (the brief's "max 2 levels" above the base). If a pill
   still overlaps at +60 px, keep it at +60 px and shift it right by the overlap width + 6 px (clamped inside the board
   viewport, then shift left instead if clamped). Never hide a pill. Drop the `overlap_unresolved` flag.
5. **Boss pill anchor** (bosses whose health shows in the global header): centre the pill horizontally on the boss
   unit's rendered visual bounds and place its bottom 8 px above the top of those bounds; clamp the pill top to at
   least 8 px below the bottom of the global boss header. Draw it (do not skip bosses).
6. **Callout easing**: reuse the existing combat status-text popup motion (the same rise distance and curves the
   current floating status/damage popups use; see the envelope near combat_board_view.gd:12580) with a 0.9 s
   duration. If those popups have no shared helper, use: rise 28 px with ease-out cubic over the full 0.9 s; alpha 1.0
   until 0.45 s, then ease-in quad to 0 at 0.9 s. Reduced motion: no rise, same alpha.

## Fixes
7. **Native capture**: the windowed probe failed 8× "Capture must be native 1920x1080" — `root.get_texture()` is not
   native on this display. Render the scene into a 1920×1080 `SubViewport` (UPDATE_ALWAYS) and capture its texture,
   exactly like `tests/movement_undo_probe.gd` (lines 16–35, 132–134) does on the integration branch. Keep the 100% UI
   scale assertion.
8. **Stale full-suite assertion**: update `tests/run_tests.gd:10928` to the new toggle label (the "Details [I]" button
   wording in its on state) — an adaptation, not a weakening; keep the same check of on/off state.

## Proof wanted
- Focused suite + full suite PASS; the probe parser check; list the exact windowed command again (I run it).
