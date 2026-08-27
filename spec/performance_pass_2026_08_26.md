# Steam Deck action-rendering follow-up — 2026-08-26

## Review correction and final native validation — 2026-08-27

Independent review rejected `b9739b82`: an interaction-disabled hand can still contain pulsing intensity glows and animated time-cost clocks. Freezing the entire fan paused those visuals. The corrective implementation now bypasses raster caching for any visible active card animation, running pose/ready-wave tween, interactive card, or processing-driven descendant. It leaves the real hand and original blending/overlap completely untouched in those cases. Static board, Umbra, ambient-particle and mesh-lifetime improvements remain enabled.

**All comparison figures below come from fresh matched runs of the corrected implementation.** The high-intensity workload keeps the hand live. The rejected implementation's earlier 68.6% submission reduction is withdrawn; the corrected candidate reduces median action draw calls by **32.6%** and action-frame p95 by **38.3%**. Runtime changes are at `0a82b94ba8dce35b0e2ec96c27d31cb6aa727667`; the subsequent final-proof commit changes only this report and the benchmark's post-action geometry assertion.

After the Mac was unlocked, the new native animation proof **passed**. Three visible glows advance without raster freezing; the clock advances 12.21 simulated seconds across the half-second wait. Original phases, parenting and overlap remain untouched. Static-hand cache mean channel error is 0.17943/255, only 0.00286% of channels differ by more than two levels, and restoration is pixel-identical. All nine native 1920×1080 screenshots were inspected. The corrected full headless suite **passed**, including eligibility regressions for active glows, running clocks, future processing-driven details, hidden details, and interactive cards.

Native animation proof: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787805779687295000-15455-runtime_frame_performanc-1/godot.log` (semantic errors empty). Fresh action runs exposed a benchmark assumption, also reproduced on baseline: a legitimate restored 1.28× hover pose was incorrectly labelled pooled-card stretching. The shared assertion now checks the authored emphasis scale, unchanged native card/slot dimensions, and the corresponding rotated envelope. It does not remove the geometry regression check. Timing runs that failed this assertion or lost foreground focus are excluded from the final comparison.

Corrective headless log: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pass-1787803715188674000-14971/godot.log` (runner exit 0 / TEST RESULT PASS; shutdown still reports 151 CanvasItem RIDs, 380 dummy textures, and 21 resources in use, versus 19 resources in the pre-correction run). Rejected native launch: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787803607341695000-14873-runtime_frame_performanc-1/godot.log` (no native proof or timing results collected).

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
- **Locked hand raster cache:** only while card/enemy actions have disabled the fan **and every visible card detail is static**, capture its unchanged appearance once. Active intensity glows, clocks and other animations keep the entire hand live. The real controls are preserved and restored before every hand refresh or action completion. The helper is isolated in `scripts/locked_hand_render_cache.gd`; it does not rasterize playable hover/focus/selection UI.
- **Retained Umbra circle geometry:** reuse a unit-circle mesh with per-instance transforms/colors. Keep mixed polygon/line/circle ordering. Match the prior ArrayMesh UNORM8 color truncation; otherwise accumulated translucent layers visibly change density.
- **Ambient particle descriptors:** cache deterministic hashes, texture variants, sizes, origins, and constant speed parameters. Evaluate the same time-dependent movement, alpha, blur, and fire-flicker formulas at the original cadence for all five elements.
- **Probe correctness:** persist isolated windowed/100% settings and wait for the native window size to remain stable. A late macOS fullscreen transition previously changed actual rendering size after the initial request; those mislabelled earlier full-scene figures are excluded. Copy only the shader-cache directory skeleton when switching task-local user directories, never compiled shader binaries.
- **Visual proof correctness:** capture an actual non-preview fire effect by presentation state rather than a fixed post-confirmation frame offset, which could still show only the card flyout. Screenshot readback stays in an untimed replay.
- **Retained shadow resource ownership:** the broader impact capture reproduced a native null-mesh error, also present in baseline benchmark logs. Clearing the shared shadow cache released resources still referenced by unchanged CanvasItems. Each layer now holds its submitted shadow meshes until its next redraw, with a focused cache-clear/lifetime regression check.

In the isolated action-heavy board probe, ambient simulation total fell from 108,599 µs to 56,367 µs in the descriptor-only experiment (150 rendered phase frames). Umbra total in the final isolated proof is about 52 ms versus 373 ms in the baseline phase, without removing lobes or lines. These are narrow attribution measurements, not whole-game FPS.

Attribution logs:
- `/private/tmp/labyrinth-godot-home/steam-deck-action-hotspot-base-1787795454502878000-98495-render_performance_bench-1/godot.log`
- `/private/tmp/labyrinth-godot-home/steam-deck-ambient-template-candidat-1787796316433802000-99636-render_performance_bench-1/godot.log`

## Final matched live action benchmark

Godot **4.6.1**, **Apple M5 Pro**, native **Metal / Mobile**, **1920×1080**, **100% UI scale**, foreground/windowed, uncapped engine FPS with the same display/compositor. These are Mac frame intervals, **not Steam Deck FPS**.

Baseline checkout: `/private/tmp/labyrinth-action-base.yxLMJ5`, detached at `af82241f`. It received only the equivalent benchmark timing/window configuration and task shader-directory setup, not candidate game rendering changes. Baseline and candidate share imported assets, workload, warmup, renderer, and UI settings. No heavy tests ran concurrently with the matched action timings.

The fixture exercises a dense depth-13 room, all-element ambience, pressing Umbra, a ten-card hand, relics, varied actors/terrain, public card/target input, movement, Blink, ranged/area/line attacks, and an enemy round. Completion and state-change assertions ensure actions really execute. Cold/warm preview, dense Blink, and ranged-trap input regression paths also run. Both runs report empty semantic errors, zero unfocused observations, actual 1920×1080 window/render-target sizes, and no >=500 ms delivery-throttle signature. The high-intensity hand remains live throughout; the untimed fire-impact capture explicitly reports `locked_hand_cache_active: false`.

All cells below are **baseline → candidate**. Frame times are milliseconds; long-frame cells preserve their denominators.

| Action | Median | p95 | p99 | Max | >16.67 ms / N | >33.33 ms / N | Median draw calls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bone_dart | 7.56 → 8.31 | 19.08 → 11.17 | 28.50 → 19.52 | 109.24 → 107.84 | 26/205 → 3/212 | 2/205 → 2/212 | 1859 → 1256 |
| shadow_step | 8.08 → 8.29 | 24.01 → 13.93 | 57.77 → 45.88 | 175.97 → 173.56 | 37/235 → 4/254 | 4/235 → 3/254 | 1819 → 1226 |
| threaded_path | 6.71 → 8.35 | 24.03 → 14.26 | 51.92 → 22.15 | 114.69 → 108.72 | 105/393 → 6/431 | 5/393 → 4/431 | 2057 → 1458 |
| thunderline | 8.18 → 8.35 | 19.77 → 10.48 | 52.08 → 51.74 | 102.60 → 102.43 | 24/132 → 2/137 | 2/132 → 2/137 | 1855 → 1252 |
| wildfire_halo | 10.42 → 9.50 | 27.24 → 17.76 | 63.14 → 44.20 | 161.97 → 159.30 | 68/231 → 31/257 | 3/231 → 3/257 | 1848 → 1249 |

Combined actions: median **8.095 → 8.364 ms**, p95 **23.835 → 14.701 ms**, p99 **57.765 → 44.202 ms**, max **175.965 → 173.562 ms**. >16.67 ms **260/1,196 (21.74%) → 46/1,291 (3.56%)**. >33.33 ms **16/1,196 (1.34%) → 14/1,291 (1.08%)**. Median draw calls **1,851 → 1,248** (32.6% fewer); median rendered objects **9,816 → 9,213**, median primitives **137,236 → 133,229**. The gain is in sustained submission/geometry work and tail pacing, not removal of visible content.

Enemy-round median **8.122 → 8.306 ms**, p95 **17.975 → 9.439 ms**, max **21.445 → 17.632 ms**, >16.67 ms **21/86 → 2/90**, >33.33 ms **0/86 → 0/90**, median draw calls **1,826 → 1,227**. Settled idle median **7.345 → 8.225 ms**, p95 **18.246 → 9.388 ms**, p99 **19.617 → 9.798 ms**, max **19.964 → 9.799 ms**, >16.67 ms **34/150 → 0/150**, >33.33 ms **0/150 → 0/150**, median draw calls **1,830 → 1,227**. Both idle and high-intensity actions keep the hand live.

The median increases toward the display's roughly 8.3 ms delivery rhythm while long-frame frequency falls. This is consistent with presentation quantization, not proof that every frame's CPU work is below that interval. Do not claim every percentile improved or divide authored action completion time into an FPS. These are one matched baseline/candidate pair, not confidence intervals; scheduling and animated content can affect small differences. Godot's periodically updated process monitor is retained in raw diagnostics, but is not interpreted as an exact per-frame CPU timer.

### Remaining hitches and memory

The sustained-rendering reduction does **not** remove transition hitches: maximum action frame intervals remain about **102–174 ms**, and >33 ms counts improve only slightly. Wildfire still has more sustained long frames than the other actions. The next attribution target is the cold/transition path, not a claim that all Deck chugging is solved.

Candidate static CPU memory: **177,462,422 bytes**, baseline **173,876,455**, delta **3,585,967 bytes (~3.42 MiB)**. This monitor does not include all GPU render-target memory; the new full-pixel caches trade bounded GPU storage for fewer submissions. Settled node counts are **3,577 → 3,580**; repeating installation stays at 3,580. Full-scene orphan count is a pre-existing **2 → 2** in both baseline and candidate, not zero. The isolated board probe asserts and reports **zero** orphan nodes. Native null-mesh errors recur in the final baseline log; the final candidate action matrix and live-cache proof contain no native ERROR lines after the ownership guard. The native full-scene runs still report two CanvasItem RIDs at shutdown. Full-suite shutdown also prints its known dummy-renderer RID/resource cleanup warnings; the runner and suite finish successfully.

## Final equivalence and regression proof

- Full Godot suite: **PASS** on the current runtime implementation, including animation-cache eligibility tests for active glows, running clocks, processing descendants, hidden descendants, and interactive cards. Subsequent changes affect only benchmark geometry validation and this report.
- Native board probe: semantic errors empty; static floor direct/cache max channel delta **2/255**, mean **0.000613/255**. Umbra legacy mesh/instanced max delta **1/255**, mean **0.000000121/255**.
- Ambient descriptor check: **5 elements, 60 particles, 180 motion samples**, full-precision hashes, texture/soft/glow variants, size, cycle, offset, and rotation checked against the original formulas.
- Native live RunScene A/B: board mean delta **0.004263/255**, max **6/255**; genuinely static locked hand mean **0.179429/255**, max **14/255**, only **0.002864%** of RGB channels differ by more than two levels. Original parent, children and geometry restore; the restored static hand is pixel-identical. A real hand refresh invalidates the cache.
- Time-separated native animation proof: all three active glows bypass the cache and advance their existing phase (0.25522 cycles during the authored wait and proof capture); the retained-hover clock advances **12.2085 simulated seconds** across its half-second wait. Early/late image differences confirm motion while original parenting and overlap remain unchanged. The glow proof's diagnostic elapsed field excludes prior screenshot readback, so it is not an exact wall-clock cadence measurement.
- Fresh **1920×1080 / 100%** screenshots inspected: nine live board/hand direct-cache-restored/glow/clock images and seven final candidate idle/targeting/dense Blink/post-trap/actual fire-impact images, plus the matched baseline fire impact. The untimed fire replay captures non-preview fire AoE at progress **0.5625**, action committed, with hand cache **inactive**. Particle density, fog alpha order, terrain/actor depth, card typography, selection/focus, and HUD placement remain intact. The lower-right action-choice panel during impact also exists in the baseline; it is not a new cache artifact.
- No card/enemy/relic/ability identities or balance data changed; no new Steam stat definitions require publication.

UI rubric handoff: the surface is the combat board and card fan; the player's question remains which action/target to choose and what its consequences are. Board targets, actionable cards, resources and combat feedback keep their existing hierarchy. Mouse, keyboard and controller routes are unchanged. The shared CardWidget/HandFanContainer components retain their layouts and live animated details. Applicable rubric gates pass in the inspected default, selected, active-impact and maximum-content states; there are no new identities, copy or icon assets.

### Raw proof paths

- Matched baseline: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787806149502918000-15864-runtime_frame_performanc-1/godot.log`
- Corrected candidate: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787806221465495000-15914-runtime_frame_performanc-1/godot.log`
- Corrected full suite: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pass-1787803715188674000-14971/godot.log`
- Native particle/static/Umbra equivalence and retained-shadow lifetime: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787802859577033000-13654-render_performance_bench-1/godot.log`
- Live hand/board A/B, restoration, invalidation and time-separated glow/clock proof: `/private/tmp/labyrinth-godot-home/steam-deck-animation-performance-pas-1787805779687295000-15455-runtime_frame_performanc-1/godot.log`
- Verified live fire impact: the corrected candidate log above, after all timed samplers finish.

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

The performance/UI skill's equivalence gate caused rejection of reordered fog lines, differently sized cached card text, and (through independent review) frozen card glows. Fresh native validation is now complete. Handoff still requires independent exact-HEAD review and a verified pre-action inspection fixture; publication requires explicit user approval.
