# anim-01 — round 6 (peer review of 17424aa19: CHANGES REQUESTED)

Work on top of 17424aa19. Do not commit. Evidence and probes: scratchpad/review_anim01/ (jitter_probe.gd,
scheduler_probe.gd, sync_cost.gd, facing_probe.gd, leak_probe.gd).

## Required
1. **M1 — stagger breaks under timestamp jitter**: lane deadlines sit exactly on 60 Hz frame boundaries, so ±0.5 ms jitter
   produces 291/1200 frames above ceil(n/5) (up to 6 ticks). Use `phase = (lane + 0.5) * STEP_SECONDS / TICK_LANES`;
   update the "Resumed actor keeps its absolute tick lane" assertion accordingly. Add a jittered-delta test (±0.5 ms and
   ±2 ms, 59.94 Hz) asserting ≤ ceil(n/5) ticks per frame.
2. **M2 — `sync()` rebuilds every actor record on each `set_combat_state`** (86 µs/call; RunScene calls it every action
   frame) and lanes re-derive from the sorted keys (a summon moved 10/12 actors: double ticks and 9-frame holds).
   Update actor dicts in place (reset only on pause/type change); skip the re-sort when the key set is unchanged;
   **sticky lanes**: existing actors keep their lane, new actors take the least-loaded lane (glow first); if a lane must
   change, shift its deadline by the smallest phase difference. Test: summon and death mid-combat keep every survivor's
   cadence at exactly 5 frames (60 Hz). Measure sync+scheduler per action frame (target ≤ 100 µs for 12 enemies).
3. **M3 — test gap**: a mutant that ignores glow changes when deciding redraws passes everything (it would freeze
   storm_capacitor and all glow pulses). In `_test_board` assert `tile_redraws` increases whenever the stepped sample
   changes (glow included) for ember_tick and storm_capacitor, and the next layer draw submits the accent mesh with the
   new tint. Add this and the cache-bound mutant to `static_enemy_idle_mutation_test.py`.

## Also do
4. L2: don't clear `_sources` in `_exit_tree` (or reset `_unit_assets_loaded` with it). L3: `draw_body` returns false when
   `board._art_treatment == null`; `push_error` if a `lighting_shader()` anchor fails to match.
5. L4: move `BOB_TOP_SHADOW_WIDTH` and `STEP_SECONDS` into `data/static_enemy_idle.json`; replace the four
   `"storm_capacitor"` literals with a data-driven check (idle-handled and not `StaticEnemyFacing.handles`).
6. L5: remove test-only/dead runtime code (`row_geometry`, `accent_threshold`, `_byte_threshold` if test-only; unused
   `source["profile"]`/`["threshold"]`; unused `advance()` return; the non-load-bearing new-actor lead bump) and move
   benchmark instrumentation (`measure_builds`, `frame_*` arrays, `record_body`, the `_draw_unit_body` wrapper) out of
   production code into the test harness (subclass or hook).
7. L6: tests for the `combat_board_view.gd` changes beyond plumbing (texture/shadow source reorder with the capacitor
   path, cutout-renderer skips, `veil_body_drawn`).
8. L7: clamp the glow tint so saturated accent channels keep their hue (scale toward white in luminance, not per-channel
   ×1.3 clipping).
9. L8 benchmark: the director accepts asset preparation up to **+30 ms** (one-time load) — encode it as the gate;
   alternate pair order; add a jittered-delta variant; gate cold-cycle p99/max instead of `new_state_draw_ms`.
10. Nit: integer tick counter instead of float idle time (no epsilons). Document that at combat speed 1.5/2× the idle runs
    at 12 Hz in game time.

Proof: idle tests, scheduler tests (incl. jitter and roster changes), mutation runner, full suite; list the native
benchmark and probe commands.
