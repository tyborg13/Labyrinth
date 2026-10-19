# rr-17 feedback 1 (director)

Good work: exact cut, vent and glow levels, 0 px rest. Three changes; then hand back.

1. **Hit (your TODO_DESIGN_hit_changing_frames).** The director changed the protected hit in
   `spec/peer_benchmark/staged/rr-17/motion_tracks.json` (commit 2e84deb66): seven changes, 40 ms apart (body at
   0.06/0.46, cap at 0.14/0.30/0.38/0.54, glow at 0.06/0.22). Re-import it byte for byte, rebuild, and remove every
   `TODO_DESIGN_hit_changing_frames` marker. The six-changing-frame rule stays strict for every action, hit included.
2. **No creature names in shared death code.** The new `storm_capacitor` branches in `scripts/run_scene.gd`
   (`_enemy_death_frame_count_for_unit`, `_enemy_death_frame_seconds_for_unit`), `scripts/combat_board_view.gd` (the
   dissolve phase) and `scripts/cutout_context.gd` (the death progress) become one data-driven path. The case's
   integration data declares its death timing (the clip's seconds, then the existing dissolve). The shared code reads
   that declaration for any maquette creature that has one. None of those three files names `storm_capacitor`.
   Prove death timing and frames are unchanged for the Seer, Thrall, Grub, Tick, Bloomer and Wisp.
   - The action routing in `run_scene.gd` (the `actions.gd` preloads beside the Seer's) follows the existing pattern
     and can stay.
3. **Idle seed in `scripts/maquette_cutout_runtime/presentation.gd`.** Same rule: the case declares the slot-based
   idle phase seed, and `presentation.gd` reads the declaration rather than the creature name. Only the Capacitor
   declares it, so every other creature's idle is unchanged.

Proof: focused tests, the rr17 headless and production gates (production now PASS), the rr12 runtime regression, the
three SFX sync programs and the registration audit. Then list the windowed commands again. No full suites.
