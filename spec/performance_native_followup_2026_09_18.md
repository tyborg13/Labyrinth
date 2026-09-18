# Native combat performance follow-up — 18 September 2026

This records the completed unlocked-display validation and additional rendering work for the [CPU follow-up](performance_followup_2026_09_17.md), continuing from the first reviewed checkpoint `c17c2106e9f16a587a371753be055814bcd77162`. The candidate materially reduces combat action stalls in ordinary encounters and in the larger animation/state matrix. It preserves gameplay outcomes, authored animation timings, rendering quality, input availability, and persistence boundaries.

**Checkpoint status: native proof is complete for the main optimization set (1259/e608). The subsequent tracker-only cleanup (2cda) passes code review and the full regression suite, but its final native rerun is pending an unlocked display.** The measured acceptance criterion is material improvement, not a guarantee of zero hitches. Mac native frame delivery is now verified; Steam Deck frame rates are not. Brief action-boundary spikes remain, and the large overlapping-fire case still exceeds a 16.67 ms frame budget during part of its effect. Those limits are included below instead of being hidden by averages.

The rendering/forecast changes are recorded at `1259e2a46bf70a33134f5acdeece8858d940bbac`; harness commit `e60836732228902fa30596d91d0acc824cb94a1b` fixes reduced-motion screenshot validation and strengthens representative enemy-outcome comparison. Final production commit `2cda7ee8e998c1476850020679754558e7efbdf8` additionally removes duplicate tracker construction and unused one-action damage simulation. The twelve accepted native runs below precede that tracker cleanup; they must not be described as timings of 2cda. Its first rerun was rejected because the Mac had locked again. The separately captured spell and hand-cache equivalence sources are unchanged by the tracker cleanup. The [proof manifest](proofs/performance-2026-09-17/native-followup/manifest.json) contains raw reports, logs, complete per-run source hashes, visual evidence, rejected-run reasons, and the [machine-readable comparison](proofs/performance-2026-09-17/native-followup/sept18-native-acceptance-analysis.json).

## What changed after the CPU checkpoint

- **Forecast and hand preparation:** Quick Wits and Encore use the existing optional hand-preparation path. After preparing hand entries, a job advances one revealed-enemy forecast activation per process frame during the existing animation. Callers never wait for it. Adoption requires an exactly equal complete combat input; partial jobs use the synchronous path. Cancellation, replacement, detachment, freeing, nested ownership, and real damaging enemy activations have explicit tests. A one-entry exact-source forecast cache retains an owned summary across selection-only invalidation.
- **Pointer presentation:** Board hover input changes immediately, while redundant visual refreshes in the same input batch coalesce. A click that starts an animation can supersede the queued hover presentation. Generation and tree guards reject stale deferred callbacks; ordinary hover, click, drag, dialogue, and controller-related regression coverage remains active.
- **Locked hand rendering:** One exact-size disabled render target is retained between captures instead of allocating MSAA attachments on every click. Each capture clears and redraws current content with unchanged pixel transforms, filtering, oversampling, and MSAA. Active card animations bypass the cache. Restore, overlapping captures, replacement hosts, scene teardown, and changed card content have native lifecycle/pixel checks. This trades about 11 MiB of reported video memory for fewer allocation stalls; it is bounded, not a growing pool.
- **Spell rendering:** Immutable ribbon topology and taper data have a bounded cache; geometry arrays are pre-sized and invariant fire hashes are hoisted. Fire sprites share an atlas without resampling. Batches preserve painter order and flush before intervening ribbons/lines; rear and front layers remain separate. Texture regeneration rebuilds the atlas and drops stale RID mappings. The exact pre-change effect implementation is frozen in a visual equivalence fixture.
- **Action startup:** Card commits build their action tracker once before the first render boundary, instead of twice. Single-action cards no longer simulate damage into an unused multi-step resolution cache. Immediate helper callers and dialogue-suppressed choice UI retain their old behavior. Metadata, damage text, locked position, multi-step progression, and locked input have regression checks.
- **Attribution and workload coverage:** The harness now includes ordinary early/middle encounters, exact enemy-outcome checks, hand-capture cost, finer board-layer timings, reduced-motion static-impact capture, and memory counters. Instrumentation remains opt-in and bounded.

## Measurement contract

Apple M5 Pro, macOS 26.3.1 arm64, Godot 4.6.1. All acceptance runs used the foreground native renderer at actual 1920×1080, 100% UI scale, Metal/mobile, production 4× MSAA. Frame intervals end at `RenderingServer.frame_post_draw`. Each run has zero unfocused observations and zero semantic errors. Heavy regression tests did not run alongside graphics captures.

Twelve runs form six matched pairs: full detailed instrumentation; focused normal-motion repeats in both candidate/base and base/candidate order; reduced motion; early combat; middle combat. Baseline and candidate share identical harnesses and environment within each pair, and before/after source snapshots reject mutation during a run. Both builds use matching harnesses within each accepted pair. The first six runs use the earlier normal-motion harness; the reduced/ordinary pairs use the corrected capture gate. Candidate production is identical across those accepted runs. The pending tracker rerun must retain the same matching requirements.

The ordinary profiles use authored enemy HP: depth 2 has five cards and three enemies with no skill/relic loadout; depth 7 has six cards, five enemies, three relics, four skills, an illusion, surfaces, a trap, loot, and props. The larger depth-13 workload uses the real seven-card hand cap and varied specialist, dragon-support, and split-swarm groups, with heavier skills, relics, statuses, illusions, terrain, and overlapping effects. It is explicitly a heavy case, not a claim about a typical room. Live viewport input covers previews, every fixture card, abilities, independent movement, enemy rounds, and input after actions.

GPU-time counters return zero and are unavailable. The texture-memory monitor returns a signed-64 maximum sentinel and is excluded from memory comparisons. `Performance.TIME_PROCESS` is not used as a per-frame delivery measurement. Headless CPU results and locked/background/window-size-invalid attempts are not treated as native performance evidence.

## Native action results

Lower is better. These figures compare against the already optimized `c17` checkpoint, not the original pre-pass game. p95 and missed-frame counts are retained even when they do not improve.

### Ordinary early combat

| Action | Worst frame, before → after (ms) | p95, before → after (ms) | Frames >16.67 ms, before → after |
| --- | ---: | ---: | ---: |
| Glowstone Ward | 31.91 → 17.27 | 8.72 → 8.72 | 2 → 2 |
| Gust Step | 25.89 → 18.81 | 8.69 → 8.68 | 3 → 2 |
| Pale Spark | 38.30 → 31.06 | 8.73 → 8.70 | 2 → 2 |
| Sidestep Slash | 25.57 → 18.16 | 8.51 → 8.45 | 3 → 3 |
| Wildfire Halo | 44.36 → 27.23 | 8.70 → 8.69 | 2 → 2 |

### Ordinary middle combat

| Action | Worst frame, before → after (ms) | p95, before → after (ms) | Frames >16.67 ms, before → after |
| --- | ---: | ---: | ---: |
| Glowstone Ward | 51.51 → 19.82 | 8.47 → 8.46 | 2 → 2 |
| Gust Step | 48.57 → 22.16 | 8.48 → 8.48 | 5 → 3 |
| Pale Spark | 52.91 → 37.82 | 8.47 → 8.46 | 2 → 2 |
| Shadow Step | 51.46 → 21.28 | 9.04 → 8.51 | 4 → 3 |
| Sidestep Slash | 42.70 → 22.18 | 8.62 → 9.57 | 3 → 3 |
| Wildfire Halo | 60.39 → 34.40 | 11.75 → 8.86 | 3 → 2 |
| Encore | 43.91 → 29.76 | 18.48 → 13.59 | 4 → 3 |
| Quick Wits | 42.65 → 30.25 | 15.04 → 13.68 | 4 → 2 |

### Larger combat matrix

| Action | Worst frame, before → after (ms) | p95, before → after (ms) | Frames >16.67 ms, before → after |
| --- | ---: | ---: | ---: |
| Gust Step | 46.48 → 29.72 | 11.07 → 10.80 | 3 → 4 |
| Pale Spark | 46.36 → 29.14 | 8.55 → 8.55 | 3 → 2 |
| Shadow Step | 70.91 → 40.67 | 8.58 → 8.59 | 3 → 3 |
| Sidestep Slash | 46.03 → 26.57 | 8.62 → 10.51 | 3 → 3 |
| Threaded Path | 74.30 → 37.07 | 9.71 → 12.23 | 4 → 4 |
| Thunderline | 45.51 → 33.58 | 8.89 → 8.57 | 3 → 2 |
| Wildfire Halo | 53.82 → 28.59 | 20.95 → 18.82 | 18 → 18 |
| Carry The Guard | 38.92 → 24.25 | 20.21 → 16.67 | 3 → 2 |
| Encore | 69.79 → 37.00 | 19.88 → 18.23 | 4 → 4 |
| Makeshift Tool | 37.69 → 24.11 | 16.96 → 19.47 | 2 → 2 |
| Prismatic Instinct | 70.21 → 37.40 | 19.95 → 14.43 | 6 → 1 |
| Quick Wits | 66.12 → 37.85 | 19.88 → 18.76 | 6 → 5 |
| Rehearsed Escape | 37.64 → 24.74 | 16.59 → 19.58 | 1 → 2 |

Full-matrix enemy rounds: dragon support: worst 36.39→29.84 ms, frames over 16.67 ms 7→6; specialists: worst 43.11→29.63 ms, frames over 16.67 ms 22→13; split swarm: worst 42.06→35.68 ms, frames over 16.67 ms 23→11. Reference final-state digests, step counts, and activation counts match exactly.

### Repeated worst cases and reduced motion

| Normal-motion action | Baseline worst frames, two orders (ms) | Candidate worst frames, two orders (ms) |
| --- | ---: | ---: |
| Gust Step | 55.71, 51.95 | 25.28, 25.32 |
| Shadow Step | 80.98, 77.82 | 33.88, 39.25 |
| Wildfire Halo | 55.81, 55.86 | 26.41, 26.49 |
| Encore | 68.55, 68.93 | 36.52, 39.57 |
| Prismatic Instinct | 78.89, 76.09 | 35.63, 36.06 |
| Quick Wits | 67.16, 68.92 | 35.39, 35.92 |

Wildfire Halo's repeat p95 changes 20.82/20.15→18.69/18.42 ms; frames above 16.67 ms change 20/19→17/19. The candidate still exceeds the 60 Hz budget in part of this heavy overlapping effect. Other rows also have occasional p95 or threshold-count regressions despite lower maxima; no claim is made that every statistic improves.

Reduced-motion worst frames change 43.91→36.62 ms (Gust Step), 73.68→42.88 ms (Shadow Step), 51.85→34.53 ms (Wildfire Halo), 64.37→36.25 ms (Encore), 66.76→44.91 ms (Prismatic Instinct), 70.60→34.54 ms (Quick Wits). The static impact at authored progress 1.0 was captured and inspected. A prior screenshot gate incorrectly awaited an animated middle phase; that rejected run is excluded and the entire pair was rerun after correcting the gate.

Whole-action and enemy-round completion durations are retained in the comparison alongside frame tails, so work moved between frames remains visible. In the instrumented clock samples, authored animation durations, authored frame counts, and run counts match. Animation skipped-frame differences are full/enemy_round_matrix.dragon_support: 4→3; full/enemy_round_matrix.specialists: 7→6; other paired skip counts match. No animation duration, effect population, renderer resolution, or visual-quality setting was reduced.

## Tail attribution and memory

The remaining large isolated intervals are concentrated at action startup/finish, where UI work, forecasts, hand capture/restore, and durable checkpoint/analytics work meet. A separate pre-cleanup middle-combat Pale Spark diagnostic records a worst frame of 41.65 ms and p95 of 8.45 ms with detailed instrumentation. The trace that motivated the last tracker cleanup exposed duplicate construction and unused single-action simulation; those were subsequently removed in 2cda and need native remeasurement. Attribution is retained separately from matched acceptance and does not establish that all remaining delay belongs to any one subsystem.

The heavy Wildfire effect's sustained tail is rendering/board-submission work during overlapping effects, distinct from the isolated action-boundary costs. Further optimization should continue from those attributed cases and actual Deck captures. The current evidence supports a substantially smoother candidate, not an assertion that a Mac's results guarantee smoothness on the Deck.

In the full matched pair, reported video memory is 623,640,576→635,207,680 bytes (+11,567,104 bytes, about +11.03 MiB). Static CPU memory is 377,049,352→376,747,072 bytes. Initial node counts are equal; final and repeated-install counts stabilize at 5,048→5,049, with zero orphan nodes in both. The retained hand target explains one persistent scene-owned node; native lifecycle checks show it is freed with its host. The invalid texture-memory counter is not interpreted as allocation usage.

## Correctness and visual evidence

- The full Godot suite and all ten focused checks pass on the final production sources: 7,347 combat-boundary comparisons, 6,260 forced-movement comparisons, 42 analytics-context comparisons, 93 hand/forecast lifecycle assertions, board-hover coalescing, profile normalization, save/resume failure recovery, surface analytics append recovery, board surface presentation, and card draw/hand flow.
- Fifteen Python tool checks pass, including rejection of mismatched representative enemy outcomes, instrumentation modes, fixture compositions, and reduced-motion metadata.
- The native hand-cache lifecycle probe verifies three content-changing captures/restores, overlapping capture generations, host replacement/freeing, scene teardown, and bypass for live card animation. Strict pixel comparisons validate the hand region; unrelated moving board effects are tested separately.
- Sixteen native fixed-pose effect comparisons cover five elements, ground/impact/rear/front/release/travel drawing, varied fractional sizes/positions, eight phases, both motion settings, and ribbon edge cases. Twelve pairs are byte-identical. The remaining four differ by only one 8-bit step in one or two color channels across the entire 1920×1080 image, inside the strict rounding gate (maximum one step, at most twenty changed channels). All 32 reference/candidate images are retained. No broad image-difference tolerance hides missing effects.
- Accepted native normal/reduced fire impacts, ordinary early/middle combat, and hand-cache output were inspected. The earlier 19-rig numerical and 31-enemy animation/composition proof remains linked from the [initial pass](performance_pass_2026_09_17.md).

The full-suite pre-existing ObjectDB-at-exit warning remains unchanged; deliberate failed-write/corrupt-save errors are expected recovery assertions. Rejected test attempts are retained with the fixes they prompted, rather than counted as passing evidence.

## Reproduce and inspect

Run from the isolated task worktree using the repository's runners. Native graphics runs must be serial with an unlocked foreground display; a locked run is invalid rather than a slow result.

```sh
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run --task-id combat-full --native --benchmark runtime_frame --timeout 300 --output /tmp/combat-full.json
LABYRINTH_COMBAT_PROFILE=early LABYRINTH_RUNTIME_PERF_SECTIONS=0 python3 tools/performance_pass.py run --task-id combat-early --native --benchmark representative_combat --timeout 300 --output /tmp/combat-early.json
LABYRINTH_COMBAT_PROFILE=middle LABYRINTH_RUNTIME_PERF_SECTIONS=0 python3 tools/performance_pass.py run --task-id combat-middle --native --benchmark representative_combat --timeout 300 --output /tmp/combat-middle.json
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 LABYRINTH_RUNTIME_PERF_SECTIONS=0 LABYRINTH_RUNTIME_PERF_FOCUSED=1 LABYRINTH_RUNTIME_PERF_FOCUSED_ACTIONS=1 LABYRINTH_RUNTIME_PERF_CARD_FILTER=gust_step,shadow_step,wildfire_halo LABYRINTH_RUNTIME_PERF_ABILITY_FILTER=quick_wits,encore,prismatic_instinct LABYRINTH_RUNTIME_PERF_REDUCED_MOTION=1 python3 tools/performance_pass.py run --task-id combat-reduced --native --benchmark runtime_frame --timeout 300 --output /tmp/combat-reduced.json
python3 tools/visual_probe_runner.py tests/elemental_spell_geometry_equivalence_probe.gd --task-id combat-geometry --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 32 --expect-size 1920x1080
```

The separate inspection fixture uses ooze/droplet/gaoler combat, seven movement/attack cards, and fire/ice/electrified surfaces before the first action. Its launcher regenerates a verified isolated save/profile on each launch. The current 2cda code has independent code-review signoff and a refreshed verified fixture. Final performance signoff remains pending its native rerun; the source-bound regression and fixture logs are in the proof manifest's tracker-cleanup directory. Publication remains subject to user inspection and explicit approval under the development workflow.
