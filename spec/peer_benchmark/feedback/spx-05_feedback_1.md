# spx-05 feedback 1 (director)

The rules work: door roles, seal timing, Sealbinders, the Gaoler and hunters all read correctly in the native captures
(`/Users/borgerding/workspace/Labyrinth/output/spx-05-2026-10-21/`). This round answers the three TODO_DESIGN items and
fixes four visual problems. Do not merge the integration branch; the director syncs it.

## Decisions (replace every TODO_DESIGN placeholder)

1. **TODO_DESIGN_DARK_SEAL_TINT.** A sealed door's texture (and its opening texture, if one is drawn) is modulated by the
   Umbra token at 60% brightness: `Color(UMBRA.r * 0.6, UMBRA.g * 0.6, UMBRA.b * 0.6, 1.0)`, derived from
   `UiPaletteTokens.UMBRA` (no new colour literal). Name the constant for what it is (e.g. `SNARE_SEALED_DOOR_MODULATE`).
   It applies to the door only, never to its destination medallion (finding C). Reference mock: option D in
   `output/spx-05-2026-10-21/seal_tint_options.png`.
2. **TODO_DESIGN_SNARE_LEGEND_LAYOUT.** Follow spx-02's legend rule: one row while the gaps can shrink from 40 px to
   12 px; otherwise a second row, centred. Update the gate to assert that rule instead of a fixed ten concepts in one
   row, so later special types don't need another gate edit.
3. **TODO_DESIGN_FIRST_TURN_ESCAPE_POLICY.** Allowed. The 5-tile minimum stops free movement from escaping on turn 1;
   an escape that spends cards on turn 1 is earned. Write that sentence in `spec/encounters.md` and keep a test
   showing that free movement alone cannot reach any exit on turn 1.

## Findings

A. **The Seals chip has no HUD plate.** The captures show bare white text with an outline. Find out why the
   `SURFACE_HUD` panel doesn't draw (for example the plain `Node` holder, the theme, or the draw order under the board)
   and fix that cause. The chip must show the same plate, fill, border, padding and title font size as the Wind chip
   (`wind_view.gd`), minus its icon and arrow. Add a regression check that fails today: the chip's panel draws a
   non-empty stylebox.
B. **The chip covers the door's destination medallion.** Every exit draws a round destination medallion above its door
   (the `_draw_door_icon` path), and the chip text currently sits on top of it. Centre the chip horizontally on the
   medallion, with its bottom edge 6 px above the medallion's top edge at the default 1920×1080 board zoom, scaled with
   the board like the medallion. Reuse the medallion's rect computation; don't duplicate it.
C. **A sealed door leaves a black disc.** `first_seal.png` shows the destination medallion painted black at about
   (1283, 455), because the seal tint also went to `_draw_door_icon`. A sealed door draws no destination medallion: no
   icon, no ring, no "?" placeholder.
D. **The Seal intent needs its rules text.** Hovering a Sealbinder shows its intent `Seal · N` with no description.
   Add this exact description line to the existing intent tooltip body, with N being the turns left and 6 coming from
   `embers_per_open_door`:
   - `Seals its door in N turns. Kill it to keep the door open. When you escape, each open door pays 6 Embers.`
   - When N is 1, use `in 1 turn`.

## Proof

Run focused checks only: `tests/snare_test.gd`, `tests/snare_ui_test.gd`, the map legend gate test,
`python3 tests/test_ui_identity_lint.py`, and the Python tests you touch. No full suites this round.

Extend the native probe and the contract with two more frames. List the exact command; the director runs it.
- `sealbinder_tooltip.png`: the `first_turn` state with the pointer over the left Sealbinder, so its tooltip shows.
- `escape_reward.png`: the `escape` case after the escape resolves, on the reward screen showing the Ember total.

Also list the exact command for a 1920×1080 map capture with the Snare enabled, so the director can judge the legend
row (reuse spx-02's map probe).
