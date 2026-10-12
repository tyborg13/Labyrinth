# feel-02 — Health-bar damage ghost

## Header
- Goal: when a unit loses Health, the lost part of its bar lingers as a pale "ghost" segment, then drains to the new
  value (Slay the Spire's 1.2 s damage ghost, tuned faster for our pacing). It makes every hit legible at a glance.
- Base: `codex/peer-benchmark`. Runs beside feel-01 (which owns shake/hit-stop/pacing in combat_board_view.gd and
  run_scene.gd): keep your edits to the bar drawing and the HP-change plumbing only.
- Owned files: `scripts/segmented_health_bar.gd`, new `scripts/health_ghost_tracker.gd`, the board unit-bar drawing
  call site(s) in `scripts/combat_board_view.gd` (bar drawing only), the hero HUD health meter and boss health overlay
  call sites in `scripts/run_scene.gd` (≤ 30 lines), new `tests/suites/health_ghost_suite.gd` +
  `tests/health_ghost_test.gd`, new `tests/health_ghost_probe.gd`, `spec/visual_design_system.md` (one bullet).
- Rules: presentation only; Windows typed-array rule; no new art; `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier standard. Acceptance: (1) ghost on every HP bar (enemies, hero on board, hero HUD meter, boss
  bar); (2) timings/colours per spec; (3) heals snap; (4) reduced motion; (5) no rule/state change.

## Change
1. **Tracker** (`health_ghost_tracker.gd`): per bar key (unit id / "player" / boss id), remember the last displayed HP.
   When HP decreases, start (or extend) a ghost from the previous displayed value to the new value: hold 0.55 s,
   then drain to the new value over 0.35 s (ease-in quad). Further damage during hold restarts the hold and keeps the
   ghost's top at the highest pre-damage value; during drain it continues from the current ghost position.
   Healing: no ghost; the fill snaps to the new value and the healed part flashes brighter (fill colour lightened 35%)
   for 0.2 s, fading out. Death (HP 0): the ghost still plays, then the bar fades with the unit as today.
2. **Drawing** (`segmented_health_bar.gd` `draw_bar` gains an optional ghost range): the ghost occupies the segments
   between the new value and the ghost value, drawn ABOVE the background and BELOW the fill: enemy bars ghost colour
   `#f2c3a6` at 85% alpha (warm pale), hero/ally bars `#d9f2e6` at 80% alpha; keep segment separators drawn over the
   ghost; no glow.
3. **Wiring**: board enemy and hero bars, the hero HUD health meter, the boss health overlay. Ghost timing runs on
   real presentation time and respects the Combat speed setting if feel-01 has landed (use `Engine.time_scale`
   naturally — no special-casing); hit-stop pauses it (time_scale 0) which is correct.
4. **Reduced motion**: no hold/drain — the ghost shows for 0.4 s then disappears in one step (no animation).
5. **Spec**: one bullet in visual_design_system.md "Combat composition".

## Keep
- Segment counts, colours of fills, block/stoneskin badges, lethal preview marks, boss bar layout.

## Proof
- Suite: tracker timings (hold, drain, re-hit during hold and drain, heal snap + flash, death), reduced motion.
- Probe (windowed, director runs) at 1920×1080: an enemy hit for 6 captured at 0.1 s / 0.5 s / 0.75 s / 1.0 s after
  the hit; the hero hit for 5 (board bar + HUD meter) at 0.1 s; a heal at 0.05 s.
- Keep green: health bar theme probe tests, full suite.

## Out of scope
- Damage numbers, shake, hit-stop, sounds.
