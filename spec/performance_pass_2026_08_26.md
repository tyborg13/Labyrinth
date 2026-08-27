# Steam Deck action-rendering follow-up — 2026-08-26

## Finding and scope

The remaining sustained animation cost was not primarily the number of actors or game-rule calculations. Retained CanvasItem draw lists avoid rerunning GDScript, but their many individual draws still get submitted on every rendered frame. The unchanged board floor and the disabled card fan therefore remained expensive during unrelated action animations. Umbra circles also rebuilt thousands of identical ring vertices, and ambient particles repeatedly derived immutable seed/texture/size data.

This follow-up is against `af82241f7243ba50176653413e462c81f25c14c7` on `codex/steam-deck-animation-performance-pass`. The preceding wall-clock fix and submission optimizations are already in that baseline. No gameplay, authored animation duration, particle count, update cadence, texture resolution, input route, or reward behavior is intentionally changed here.

## Target-hardware evidence and limits

The available main-app Steam report is `/private/tmp/steam-deck-animation-performance-pass-steam-main.json`: app **4530510**, requested dates **2026-08-24 through 2026-08-26**, exact prefix **perf_v1_linux_steamdeck**, 4 sessions, 63 windows, 204,305 frame samples. Positive denominators validate actual uploaded evidence; missing stat objects are not interpreted as zeros.

| Deck cohort | Samples | >20 ms | >33.33 ms | >50 ms |
| --- | ---: | ---: | ---: | ---: |
| Combat animation | 3,159 | 3,021 (95.63%) | 2,800 (88.64%) | 2,383 (75.44%) |
| Combat idle | 127,696 | 33,927 (26.57%) | 7,286 (5.71%) | 1,349 (1.06%) |
| Density 5+ | 48,795 | 31,520 (64.60%) | 6,307 (12.93%) | 2,077 (4.26%) |
| Reward | 1,850 | 1,176 (63.57%) | 582 (31.46%) | 315 (17.03%) |

Overall >16.67 ms: 57,184/204,305 (27.99%). Window-mean draw calls: 95,385/63 = 1,514.05. This supports prioritizing animation rendering rather than assuming a static callback microbenchmark represents the problem.

This is a re-read of the available raw report, not a fresh candidate-vs-baseline Deck experiment. Its history contains multiple sessions/build exposures and cannot attribute changes to this candidate. A new authenticated pull was not obtained in this follow-up: no publisher key was available to the report process, and the browser attempt did not produce a safe credential handoff. No credentials were printed, persisted, or requested in chat. No Playtest-app figures are blended in. The candidate still needs measurement after actual Deck exposure.

## Changes tied to evidence

- **Static board raster cache:** capture floor/depth/moss/outlines only when their inputs change. Dynamic units, terrain, particles, previews, and feedback remain separate live layers. The raster has actual screen-pixel dimensions, uses the already-resolved board geometry, and refreshes for room/layout/zoom/pan/viewport/backdrop changes.
- **Locked hand raster cache:** only while card/enemy actions have already disabled the fan, capture its unchanged appearance once. The real controls are preserved and restored before every hand refresh or action completion. The helper is isolated in `scripts/locked_hand_render_cache.gd`; it does not rasterize playable hover/focus/selection UI.
- **Retained Umbra circle geometry:** reuse a unit-circle mesh with per-instance transforms/colors. Keep mixed polygon/line/circle ordering. Match the prior ArrayMesh UNORM8 color truncation; otherwise accumulated translucent layers visibly change density.
- **Ambient particle descriptors:** cache deterministic hashes, texture variants, sizes, origins, and constant speed parameters. Evaluate the same time-dependent movement, alpha, blur, and fire-flicker formulas at the original cadence for all five elements.
- **Probe correctness:** persist isolated windowed/100% settings and wait for the native window size to remain stable. A late macOS fullscreen transition previously changed actual rendering size after the initial request; those mislabelled earlier full-scene figures are excluded. Copy only the shader-cache directory skeleton when switching task-local user directories, never compiled shader binaries.
- **Visual proof correctness:** capture an actual non-preview fire effect by presentation state rather than a fixed post-confirmation frame offset, which could still show only the card flyout. Screenshot readback stays in an untimed replay.
- **Retained shadow resource ownership:** the broader impact capture reproduced a native null-mesh error, also present in baseline benchmark logs. Clearing the shared shadow cache released resources still referenced by unchanged CanvasItems. Each layer now holds its submitted shadow meshes until its next redraw, with a focused cache-clear/lifetime regression check.

In the isolated action-heavy board probe, ambient simulation total fell from 108,599 µs to 56,367 µs in the descriptor-only experiment (150 rendered phase frames). Umbra total in the final isolated proof is about 52 ms versus 373 ms in the baseline phase, without removing lobes or lines. These are narrow attribution measurements, not whole-game FPS.

Attribution logs:
- `/private/tmp/labyrinth-godot-home/steam-deck-action-hotspot-base-1787795454502878000-98495-render_performance_bench-1/godot.log`
- `/private/tmp/labyrinth-godot-home/steam-deck-ambient-template-candidat-1787796316433802000-99636-render_performance_bench-1/godot.log`

## Matched live action benchmark

Godot **4.6.1**, **Apple M5 Pro**, native **Metal / Mobile**, **1920×1080**, **100% UI scale**, foreground/windowed, uncapped engine FPS with the same display/compositor. These are Mac frame intervals, **not Steam Deck FPS**.

Baseline checkout: `/private/tmp/labyrinth-action-base.yxLMJ5`, detached at `af82241f`. It received only the equivalent benchmark timing/window configuration and task shader-directory setup, not candidate game rendering changes. Baseline and candidate share imported assets, workload, warmup, renderer, and UI settings. No heavy tests ran concurrently with the matched action timings.

The fixture exercises a dense depth-13 room, all-element ambience, pressing Umbra, a ten-card hand, relics, varied actors/terrain, public card/target input, movement, Blink, ranged/area/line attacks, and an enemy round. Completion and state-change assertions ensure actions really execute. Cold/warm preview, dense Blink, and ranged-trap input regression paths also run. Native focus remains true and neither report contains the rejected >=500 ms delivery-throttle signature.

All cells below are **baseline → candidate**. Frame times are milliseconds; long-frame cells preserve their denominators.

| Action | Median | p95 | p99 | Max | >16.67 ms / N | >33.33 ms / N | Median draw calls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bone_dart | 8.06 → 8.32 | 18.00 → 11.24 | 24.95 → 23.17 | 108.82 → 106.12 | 27/208 → 4/222 | 2/208 → 2/222 | 1827 → 571 |
| shadow_step | 8.14 → 8.29 | 23.92 → 13.59 | 57.13 → 41.98 | 175.61 → 182.22 | 38/237 → 7/258 | 3/237 → 3/258 | 1787 → 539 |
| threaded_path | 6.31 → 8.33 | 24.09 → 14.08 | 36.28 → 24.79 | 112.14 → 112.01 | 106/400 → 6/433 | 6/400 → 4/433 | 2026 → 778 |
| thunderline | 8.11 → 8.34 | 21.78 → 14.63 | 52.05 → 48.88 | 101.36 → 103.72 | 26/130 → 2/140 | 2/130 → 2/140 | 1823 → 592 |
| wildfire_halo | 10.34 → 9.36 | 26.50 → 17.38 | 44.98 → 45.42 | 176.67 → 168.70 | 71/227 → 29/266 | 3/227 → 3/266 | 1816 → 626 |

Combined actions: median **8.12 → 8.36 ms**, p95 **23.53 → 14.99 ms**, p99 **49.50 → 35.15 ms**. >16.67 ms **268/1,202 (22.30%) → 48/1,319 (3.64%)**. >33.33 ms **16/1,202 (1.33%) → 14/1,319 (1.06%)**. Median draw calls **1,818 → 571** (68.6% fewer).

Enemy-round median **7.95 → 8.34 ms**, p95 **18.22 → 10.29 ms**, max **21.14 → 17.20 ms**, median draw calls **1,798 → 479**. Settled idle p95 **18.05 → 9.23 ms**, >16.67 ms **33/150 → 0/150**. Idle keeps the interactive hand live, so its median draw calls remain **1,798 → 1,227**, higher than locked action frames.

The median can increase toward the display's roughly 8.3 ms delivery rhythm while long-frame frequency falls. Do not claim every percentile improved or divide authored action completion time into an FPS. Two earlier candidate runs before the final shadow-ownership guard showed the same large draw-call reduction; small interval and draw-count differences vary with animated content and scheduling.

### Remaining hitches and memory

The large sustained-rendering reduction does **not** remove transition hitches: maximum action frame intervals remain about **102–182 ms**, and >33 ms counts improve only slightly. Wildfire still has more sustained long frames than the other actions. The next attribution target is the cold/transition path, not a claim that all Deck chugging is solved.

Candidate static CPU memory: **177,295,982 bytes**, baseline **173,832,402**, delta **3,463,580 bytes (~3.30 MiB)**. This monitor does not include all GPU render-target memory; the new full-pixel caches trade bounded GPU storage for fewer submissions. Settled node counts are **3,577 → 3,580**; repeating installation stays at 3,580. Full-scene orphan count is a pre-existing **2 → 2** in both baseline and candidate, not zero. The isolated board probe asserts and reports **zero** orphan nodes. Native null-mesh errors occurred in both the baseline and pre-guard candidate logs; the final action matrix and focused impact replay contain no native ERROR lines after the ownership guard. Full-suite shutdown still prints its known dummy-renderer RID/resource cleanup warnings; the runner and suite finish successfully.

## Equivalence and regression proof

- Full Godot suite: **PASS**, including the final rerun after the shadow-ownership fix.
- Native board probe: semantic errors empty; static floor direct/cache max channel delta **2/255**, mean **0.000613/255**. Umbra legacy mesh/instanced max delta **1/255**, mean **0.000000121/255**.
- Ambient descriptor check: **5 elements, 60 particles, 180 motion samples**, full-precision hashes, texture/soft/glow variants, size, cycle, offset, and rotation checked against the original formulas.
- Native live RunScene A/B: board mean delta **0.00451/255**; locked hand mean **0.18823/255** (mostly one-level RGBA8 rounding), only **0.00265%** of RGB channels differ by more than two levels. Original parent, children, geometry and appearance restore, and a real hand refresh invalidates the frozen cache.
- Fresh 1920×1080 screenshots inspected for populated idle, targeting, actual fire impact, dense isolated effects, and direct/cached board and hand composition. Particle density, fog alpha order, terrain/actor depth, card typography, and HUD placement remain intact.
- No card/enemy/relic/ability identities or balance data changed; no new Steam stat definitions require publication.

### Raw proof paths

- Matched baseline: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787800813921658000-5004-runtime_frame_performanc-1/godot.log`
- Final candidate: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787802779912190000-13585-runtime_frame_performanc-1/godot.log`
- Final full suite: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pass-1787802856314150000-13644/godot.log`
- Native particle/static/Umbra equivalence and retained-shadow lifetime: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787802859577033000-13654-render_performance_bench-1/godot.log`
- Live hand/board cache A/B and invalidation: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787801427093475000-5617-runtime_frame_performanc-1/godot.log`
- Verified live fire impact after the shadow-ownership fix (non-preview fire AoE at progress 0.5625, hand cache active, action committed, no native null-mesh errors): `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787802726068693000-13533-runtime_frame_performanc-1/godot.log`

Images live under each native run's printed `Library/Application Support/Escape the Umbra Visual Probe …/performance/` directory. These temporary paths are local evidence, not shipped assets.

## Reproduction

From the candidate worktree:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/steam-deck-animation-performance-pass && LABYRINTH_RUNTIME_PERF_FOCUSED=1 LABYRINTH_RUNTIME_PERF_FOCUSED_ACTIONS=1 LABYRINTH_RUNTIME_PERF_FOCUSED_ENEMY_ROUNDS=1 LABYRINTH_RUNTIME_PERF_CARD_FILTER=bone_dart,wildfire_halo,threaded_path,thunderline,shadow_step LABYRINTH_RUNTIME_PERF_ABILITY_FILTER=none LABYRINTH_RUNTIME_PERF_COMPOSITION_FILTER=specialists python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd --task-id steam-deck-animation-performance-pass-actions --timeout 180
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/steam-deck-animation-performance-pass && LABYRINTH_RUNTIME_PERF_CACHE_VISUAL_ONLY=1 python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd --task-id steam-deck-animation-performance-pass-cache --timeout 60
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/steam-deck-animation-performance-pass && LABYRINTH_RUNTIME_PERF_ACTION_VISUAL_ONLY=1 python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd --task-id steam-deck-animation-performance-pass-impact --timeout 60
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/steam-deck-animation-performance-pass && python3 tools/visual_probe_runner.py tests/render_performance_benchmark.gd --task-id steam-deck-animation-performance-pass-render --timeout 60
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/steam-deck-animation-performance-pass && python3 tools/godot_task_runner.py --task-id steam-deck-animation-performance-pass --timeout 300 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The performance/UI skill's equivalence gate caused rejection of reordered fog lines and differently sized cached card text. Publication still requires independent exact-HEAD review and a verified pre-action inspection fixture, followed by explicit user approval.
