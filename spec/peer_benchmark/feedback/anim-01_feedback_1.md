# anim-01 feedback 1 (director, after peer review of 68b09c450)

The deformation and state logic are correct (the review confirmed pixel-identity at rest on Metal, anchored feet, no
seams, correct suspension). Work on top of HEAD 68b09c450 (it includes director changes: raised amplitudes in
`data/static_enemy_idle.json`, the probe strip-format fix, the shrike bob test reading its amplitude). Do not commit.

## Blocking (performance)
1. **Pixel-art cadence (director decision):** the idle clock advances in steps of 1/12 s (12 Hz), like hand-animated
   pixel art; all components (breathe, sway, bob, glow) sample the stepped time. Geometry and glow can therefore change
   at most 12 times per second per unit.
2. **Cache by quantized state:** meshes are cached per (texture, facing/mirror, profile, rect size, bob px, breathe
   level, sway level) — keys built from those integers, not by recomputing and comparing row geometry. One loop through
   the cycle fills the cache; afterwards no rebuilds. Merge consecutive rows with the same offset into one quad.
   Skip the accent split entirely for profiles without glow.
3. **Redraw only on change:** queue the tile-layer redraw for a unit only when its quantized geometry or glow value
   changes.
4. **No first-draw scans:** precompute source runs/accent masks during asset preparation (next to
   `_queue_unit_shadow_texture`), scanning `get_data()` bytes, skipping alpha-0 pixels, and only for profiles that use
   glow; mirrored/rear variants are prepared with their texture.
5. **Budgets (measure with the reviewer's method: 8 different static enemy types on the 1920×1080 board, raised
   amplitudes):** idle total ≤ 1.0 ms main-thread per frame on average and ≤ 2.0 ms on any frame; combat-start first
   frame within +10 ms of the parent commit 847a2d750; first rear/mirrored facing within +3 ms. Add a benchmark script
   (`tests/static_enemy_idle_benchmark.gd`) that prints these numbers; report them.

## Also fix
6. **Board-level wiring test** (the review's surviving mutants): drive `combat_board_view` `_process` for a few frames and
   assert the actor clock advances, a non-veiled unit has nonzero offsets at a non-rest time, reduced motion yields rest
   geometry, a mirrored facing negates sway, and the shrike's shadow width is < 1 at the top of the bob. Remove the two
   assertions that can never fail (test lines ~80 and ~202) or make them meaningful.
7. Register `static_enemy_idle_test` in `tests/static_facing_program_suites.gd` `SUITES` so the full suite runs it.
8. **Veil (director decision):** while a unit is veiled, the idle deformation is suspended (glow too) so the rim always
   matches the body; it resumes from rest when the veil ends.
9. **Only plain static art:** `validate_data` rejects enemies that are not static directional stills drawn from plain
   textures (no cutout/ViewportTexture, no AtlasTexture idle sheets), and `draw_body` returns false for non-plain
   textures as a guard.
10. **Pivot** is measured from the lowest opaque row of the sprite, not the texture bottom (sprites have transparent rows
    below the feet).
11. Release `_sources` entries with their board/textures (no unbounded strong references).

Proof: idle test, board wiring test, static facing test, the benchmark numbers vs budgets, full suite. The director will
rerun the windowed strip probe.
