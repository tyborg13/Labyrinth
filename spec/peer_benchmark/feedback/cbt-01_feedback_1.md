# cbt-01 feedback 1 — peer review CHANGES on 5e20c1099

Full review: `spec/peer_benchmark/feedback/cbt-01_review_5e20c1099.md` (integration branch).

1. **Keyboard focus is lost every frame (review #1).** `run_scene.gd:2086` clears controller focus every physics frame
   in keyboard mode, so the hero-tile cursor and its targeting arrow disappear while Enter still commits Stay.
   - Preserve the keyboard focus, and its arrow, across frames during movement targeting.
   - Add a regression that moves onto the hero tile, awaits several physics frames, asserts that the rendered
     focus/hover is on (4,3), and only then confirms.
2. **Renderer proof (review #2).** Done by the director. My windowed run of `tests/cbt_01_probe.gd` passed, and its
   captures are at `output/cbt-01/director_r0/`. I reviewed them: the Stay chip, the hero-tile highlight and the Block
   preview read correctly, and Immolation previews 40→37 on the adjacent enemy.
   - After fixing #1, extend the probe with a keyboard-mode capture, `guarded_step_stay_keyboard.png`, taken after
     ≥ 10 frames on the hero tile.
   - Also make the probe place the real mouse cursor on the hovered tile. Today the drag arrow runs from the card to
     the screen's top-left corner.
   - I re-run the probe myself.
3. **Successive-Stay analytics (review #3).** Add two successive Stay card plays and assert both `stayed` payloads,
   including replay from a serialized snapshot. The reviewer's mutation (resetting the sequence to 1 on every Stay)
   must fail.

Do not let `run_scene.gd` grow beyond the fix. Re-run the focused suites, then the full Godot and Python suites, and
report the full-suite time.
