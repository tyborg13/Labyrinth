# perf-03 — Combat frame spikes: hovering the board and a knock into a trap

## Header
- **Owner report (2026-10-22):** "a huge frame hitch knocking an enemy into a trap", and a feeling that recent changes
  introduced performance regressions.
- **Evidence the director collected:**
  - The owner's Steam telemetry: frames over 50 ms in combat ran at 1.9 per minute on 10-22, against 0.6 on 10-08. The
    10-22 figure is partly contaminated by background jobs.
  - The exact event, from analytics (combat 9, air biome): Pale Spark knocked an enemy onto a lightning trap (8 damage).
    The enemy died, and its death caused a collision. That minute contains a 150 ms frame.
  - Native director probe (`spec/peer_benchmark/director_tools/frame_attribution_probe.gd`; the
    `spx07_frame_benchmark` cases, each run twice in one process): during the board-hover sweep with no card selected,
    the worst frames are ordinary 42 ms (about 20 frames of 38-42 ms in 6 s), air_t2 30-35 ms and lightning_t3 68-70 ms
    (a burst of 44→60→69→35 ms).
    - Zero pipeline compilations during the sweeps, and the warm second pass is no better, so this is not shader work.
    - The same numbers at de6f5c0b3 (before spx-06), so spx-06 didn't cause it.
    - The game's instrumented script phases explain only about 12-27 ms of the worst frames. The board's dynamic draw
      peaks around 15 ms.
- **Base:** `codex/peer-benchmark`. **Risk tier:** standard.
- **Owned:** new `tests/perf/combat_frame_scenarios.gd` (+ runner and registration if it becomes a test), performance
  fixes in whichever files the profile points to.
  - `scripts/run_scene.gd` changes are allowed but must shrink or stay net-neutral; another unit (perf-02) touches its
    PASS-preview code, so stay out of that area.
  - List every file you change.

## Rule that matters most
Nothing a player sees changes: the same visuals, previews, timings and rules. Every optimisation needs an equivalence
check (same draw commands or same state/preview output) like spx-07's.

## Step 1: measure and attribute (report before optimising anything large)
1. **Headless full-frame harness** (`tests/perf/combat_frame_scenarios.gd`): run real frames (process + the board's
   and HUD's `_draw` work + deferred layout) for:
   - **A. hover sweep:** the three `spx07_frame_benchmark` fixtures, the same pointer path and no card selected;
   - **B. trap knock:** an ordinary fight where Pale Spark's knockback pushes an enemy onto a lightning trap. The
     8-damage trap kills it, and the death resolves a collision. Record every frame from the card commit until the
     board is idle again. Variants: a fire trap, and a trap hit that doesn't kill.
   - Per frame, record the total, the time in each instrumented phase, and the time NOT covered by instrumentation.
     Find what the uncovered time is (text shaping/layout, tooltip or label construction, Control minimum-size passes,
     resource loads, signal storms, GC of large dictionaries, etc.), using finer instrumentation or Godot's profiler
     API where needed.
   - If headless can't reproduce the native spike sizes for A, say so, and give the director a windowed command for the
     same harness that records the same attribution.
2. **Baseline comparison:** run scenario A's ordinary fixture and scenario B at `816f5e68a` (master on 2026-10-08) in a
   throwaway detached worktree (adapt the harness to the old API if needed; remove the worktree after). Report what got
   slower since then, and which commit range did it, if you can bisect cheaply.
3. Write `output/perf-03/attribution.md` (untracked) with tables: per scenario, worst frames and their breakdown, plus
   the 10-08 comparison.

## Step 2: fix
- **Targets (headless full frame, M5 Pro):** scenario A worst ≤ 16 ms and p95 ≤ 10 ms on all three fixtures; scenario B
  every frame ≤ 20 ms.
- Fix the biggest attributed costs first: caching, avoiding repeated rebuilds of unchanged UI/text, deferring
  non-visible work, batching. No threads unless the work is pure data and provably isolated.
- If a target needs a design change (anything visible), stop and report it with the numbers instead.
- Keep spx-07's caches sound: content keys plus full equality, deep-copied hits.

## Proof
- The harness numbers before and after for A and B, plus equivalence checks for every optimisation.
- Mutations for each new cache (stale key → visible difference caught).
- Focused suites: warband_ui, warband_wind_lock, card_keywords, full_scene_controls_program, the combat feel/pacing
  suites if they touch timing, and `tests/spx07_hover_benchmark.gd --fresh`. No full suites.
- Under "Proof for the design owner", give the windowed commands for the director's native check of A and B.

## Out of scope
Shader cache or export settings (separate unit), the PASS-preview prewarm (perf-02), visual changes.
