# perf-04 — Board hover back to October speed

## Header
- **Why.** The owner asked to root out performance regressions. perf-03's harness, measured headless on an idle
  machine (min of three runs), shows hovering the board in an ordinary fight peaks at **3.4 ms on 2026-10-08**
  (`816f5e68a`) against **7.7 ms now**. Air T2 peaks at 9.8 ms and lightning T3 at 11.2 ms; those fixtures don't exist
  on 10-08.
- **What the profile shows in the current worst hover frames:**
  - `submission:hud_build_units` 1.0-1.5 ms;
  - `draw_section:foreground_torch_motes` about 1 ms (once 10.8);
  - `submission:retained_sync` about 0.9 ms;
  - `draw_section:damage_preview_overlays` 0.7-0.8 ms;
  - `stage_preview_presentation_total` about 0.65 ms;
  - `draw_section:tile_overlays` about 0.6 ms;
  - `submission:assign_and_assets` 0.4-1.4 ms.
  On 10-08 the whole frame was mostly pointer dispatch.
- **The 10-08 checkout:** the director provides `/private/tmp/labyrinth_codex/oct08-baseline` at `816f5e68a`, a
  detached checkout in your writable tmp. Adapt `tests/perf/combat_frame_scenarios.gd` (scenario A, ordinary) to it as
  perf-03 did. Don't commit there; the director removes it afterwards.
- **Base:** `codex/peer-benchmark`. **Risk tier:** standard.
- **Owned:** the board/HUD submission and draw code the profile points to (`scripts/combat_board_view.gd`, HUD unit
  builders, the board's retained layers), and the perf harness under `tests/perf/`. `scripts/run_scene.gd` may only
  shrink or stay net-neutral.

## Rule that matters most
Nothing a player sees changes. Every optimisation needs an equivalence check (same draw commands, same retained layer
content), as perf-03 did.

## Steps
1. **Find what regressed.** Bisect `816f5e68a..HEAD` on the ordinary hover worst frame (min of three runs, headless).
   If a full bisect isn't feasible because the harness can't run on older commits, compare per-phase costs on 10-08 vs
   now and name the code paths that grew (e.g. HUD unit chips rebuilt per hover, torch motes redrawn per hover
   instead of on their own cadence, preview overlays rebuilt for unchanged content). Report a table: phase, 10-08 ms,
   now ms, the responsible change.
2. **Fix the biggest regressions** with caching, skipping unchanged rebuilds, or moving per-hover work to change
   events. Never on a timer that lags visuals.
3. **Targets** (headless, idle, min of three runs): ordinary hover max ≤ 5 ms; air T2 and lightning T3 hover max ≤
   8 ms; p95 unchanged or better; trap scenarios no worse than today (≤ 19.5 ms).

## Proof
Harness before/after for scenario A and B, equivalence checks with a mutation per new cache, and focused suites
(warband_ui, card_keywords, full_scene_controls_program, combat feel/pacing, `tests/spx07_hover_benchmark.gd --fresh`).
No full suites. The director measures natively.

## Out of scope
Card targeting (perf-02), shaders/caches (shader-01), visual changes.
