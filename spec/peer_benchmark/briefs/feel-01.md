# feel-01 — Hit-stop, impact weight and enemy-turn pacing (+ Combat speed setting)

## Header
- Goal: hits feel heavy and the enemy phase moves briskly. Today a 4-enemy round takes ~10.3 s (≈2.3 s per enemy,
  measured from `output/peer-benchmark-2026-10-12/clips/b_enemy_turn`), there is no hit-stop, and shake is a flat
  3 px / 5.5 px. Target: per enemy ≤ 1.4 s for walk+attack at Normal speed, crunchy hits, and a player-selectable
  Combat speed.
- Base: `codex/peer-benchmark`. Depends on: nothing.
- Docs (sections): spec/visual_design_system.md "Combat composition"; spec/turn_clock.md "Presentation";
  spec/actor_presentation.md (hit reactions); spec/contextual_cutout_animations.md timing table; settings in
  spec/premium_visual_polish.md if present (settings panel rows).
- Owned files/dirs: new `scripts/combat_hit_stop.gd`, new `scripts/combat_pacing.gd`, new
  `tests/suites/combat_feel_suite.gd` + `tests/combat_feel_test.gd`, new probe `tests/combat_feel_probe.gd`;
  modify `scripts/combat_board_view.gd` (shake amplitude call sites + hit-stop triggers only), `scripts/run_scene.gd`
  (enemy-phase delays/caption timing only, ≤ 60 changed lines; extract helpers into combat_pacing.gd),
  `scripts/settings_store.gd`, `scripts/settings_panel.gd` (one new row), `spec/visual_design_system.md` (Combat
  composition bullets), `spec/combat_feel.md` (new).
- Rules: presentation only — rules/state/RNG must be byte-identical (existing state-hash suites unchanged); reduced
  motion keeps its current behaviour (no shake) but hit-stop still applies at half duration; Windows typed-array
  rule; no new art/audio; `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier standard (presentation, settings). Acceptance: (1) hit-stop durations per table; (2) shake
  amplitudes per table; (3) measured enemy-round timeline meets the budgets at Normal; (4) Combat speed setting
  persists and scales enemy-phase and card-resolution presentation; (5) no rules/state change. Proof: feel suite,
  existing combat_motion_timing suite, full suite; director windowed probe + clip.

## Change (numbered, testable)
1. **Hit-stop** (`CombatHitStop`, an autoload-free helper owned by the run scene): when a damage event is presented
   (the moment the floating damage number spawns / the hit reaction starts), freeze game time with
   `Engine.time_scale = 0` for a real-time duration (use `Time.get_ticks_usec`, not scaled timers), then restore the
   previous time scale. Durations (ms): damage ≤ 3 → 40; 4–7 → 65; 8–11 → 85; ≥ 12 → 110; the hit kills its target →
   max(table, 100); the hero is the target → table + 20. Several hits within 120 ms (area attacks, chains,
   collisions) merge into ONE stop of the largest applicable duration, starting at the first. Block-only hits (no HP
   lost) use 35. Never stop during card drag/aim, menus, the map, or while the game is paused. Reduced motion: half
   duration. Combat speed (Change 5) does not shorten hit-stop.
2. **Shake scale.** Replace the flat board kick with damage-scaled amplitudes (px at 1080p, board layer only, as
   today): ≤ 3 → 2.0; 4–7 → 3.5; 8–11 → 5.0; ≥ 12 or kill → 6.5; add +1.5 when the hero is hit; duration 0.18 s +
   0.02 s per px, exponential decay; merged hits use the largest. Reduced motion: none (as today).
3. **White impact flash.** Verify the existing impact flash on the struck unit; it must peak at the first frame after
   hit-stop ends (not during the freeze) and fade over 140 ms ease-out, at 85% peak opacity on enemies and 60% on the
   hero. If it already behaves this way, leave it; report what you found.
4. **Enemy-phase pacing.** Instrument the enemy phase (debug timeline, off by default, printable by the probe) into
   phases per actor: pre-action delay, caption, walk (per tile), wind-up, impact, post-action settle, hand-off gap;
   plus banner. Then set timing so that, at Normal speed:
   - hand-off gap between consecutive enemy actors ≤ 0.12 s; pre-action delay ≤ 0.10 s;
   - walking ≤ 0.20 s per tile (hero walking unchanged);
   - post-action settle ≤ 0.25 s after the last hit reaction/damage number of an action;
   - the action caption ("<Enemy>: <Intent>") appears at action start and does not add time;
   - the ENEMY TURN banner keeps its existing rules but the first enemy may start acting 0.35 s after the banner
     appears (overlap the banner's hold/out).
   - Death dissolves, surface spawns and forced-movement slides keep their durations but must overlap the next actor's
     pre-action instead of blocking it, unless that actor is the one dying or its target tile depends on it.
   Report before/after timelines for the staged 4-enemy round (`tools/trailer_director/shots/b_enemy_turn.gd` layout
   reproduced in your probe: crawler skitter_strike, acolyte dust_bolt, frostglass_lancer glass_lunge, harrier pelt).
   Budget: that round ≤ 6.0 s from Pass press to the hero's next turn banner at Normal speed.
5. **Combat speed setting.** Settings row "Combat speed" with options Normal / Fast / Fastest = presentation time scale
   1.0 / 1.5 / 2.0, default Normal, persisted in `settings_store` (key `combat_speed`), applied as `Engine.time_scale`
   ONLY while enemies act and while a committed card's resolution plays (from commit to the hand being interactive
   again); planning, hover, menus, map and rewards always run at 1.0. Audio is unaffected. Hit-stop composes with it
   (stop → 0, then restore to the current speed).
6. **Spec.** New spec/combat_feel.md with the tables above and the measured timeline; update the visual design system
   "Combat composition" bullets.

## Keep (must not break)
- All combat rules and seeds; turn banners' rules (ENEMY TURN only when an enemy acts before the next hero turn);
  reduced motion; controller/keyboard input; trailer director determinism (it sets `time_scale` for slow motion — keep
  its slow-mo working: when an external time_scale ≠ 1 is set by the trailer tool, multiply rather than overwrite).

## Proof
- Feel suite (headless): duration tables, merge window, block-only, reduced-motion halving, speed mapping and
  persistence, time_scale restored after every stop (including when combat ends mid-stop).
- `tests/combat_feel_probe.gd` (windowed, director runs): stage the 4-enemy round, print the per-phase timeline at
  Normal/Fast/Fastest, save frames at 1920x1080 around one heavy hit (5 frames: −1, 0, +1, +4, +8 frames from impact).
- Keep green: combat_motion_timing suite, floating_combat_text suite, enemy_strike_trail suite, full suite.
- For me (windowed): exact probe command; and the trailer capture command for `b_enemy_turn` and `b_quick_strike`
  (`tools/trailer_director/capture.py` exists only in the director's capture worktree — just state that the director
  will capture clips).

## Out of scope
- New VFX/SFX, new animations, card hand animations, rules changes, turn banner redesign.
