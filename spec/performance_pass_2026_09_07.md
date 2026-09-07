# Surface and frame-pacing performance pass — 2026-09-07

## Scope and result

The later [shop, reward and action follow-up](performance_pass_2026_09_07_flows.md) continues this pass from its reviewed commit, with additional cold-path and UI work plus a calibrated Mac CPU stress condition.

This pass addresses the request for substantially less hitching on weaker machines without sacrificing the game's appearance or behavior. The reproducible new bottlenecks were surface/Chain preview planning and board-wide redraws for small surface updates. Both are reduced substantially. The pass also covers ordinary card actions, enemy rounds, abilities, rewards, enemy dissolves, rendering, simulation, repeated installation, and generated shadow data.

The measurements below are **Apple M5 Pro / macOS 26.3.1 / Godot 4.6.1 `14d19694e` / Metal Mobile**, in a foreground **1920×1080 window at 100% UI scale**. They establish local reductions in CPU work and completed-draw frame intervals. They are not Steam Deck FPS, battery-life, compositor-presentation, or GPU-completion measurements. GPU timestamps are unavailable on this Metal backend and are excluded from the comparison. Steam fleet telemetry could not be retrieved through the available secure credential path during this pass.

The candidate preserves graphics settings, textures, particle density, transparency/depth order, authored animation duration/cadence, normal/reduced-motion behavior, legal targets, rules, and input routes. There are no gameplay balance changes. Remaining transition costs are listed below rather than treating this as a guarantee that all hardware now meets a frame budget.

## Implementation and rationale

- `GameData.relic_effects` reads authored effect definitions directly instead of copying and formatting the entire display definition for every rules lookup. Every returned effect remains an independently mutable deep copy. All 60 relic definitions are checked against the old expansion behavior.
- Board-attack planning builds visibility once per immutable plan and reuses it for actors and conductive ground. Chain searches prefilter eligible actors and retain connected components per origin. Lightning target enumeration shares component membership only when traversal is symmetric; blocked origins retain their own result. Actor order, relay ranking, tie breaks, hidden information, terrain, and multi-tile footprints remain unchanged.
- Hover previews retain final state and route metadata without copying the entire combat state after every hit. Committed presentation still captures every intermediate hit state. Damage, ground feedback, and turn risk share one immutable resolution where their information scopes agree. Filtered Umbra information retains the previous distinction between prevalidated damage and validated surface feedback. Cache keys include source/action/selection identities, and automatic followups cannot mutate the single-action result.
- `BoardSurfaceRenderDependencies` finds the union of old and new tile owners for preview events, feedback, and floor-projected Chain paths. Drawing and invalidation share the exact floor-segment ownership calculation. Clearing or moving feedback redraws its previous owners as well as its new owners. Friendly damage chips invalidate their actual HUD owner.
- Static Rubble no longer requests continuous surface redraws. Elemental surfaces retain their existing animation cadence. The animated tile list is refreshed when submitted surface content changes, including in-place state changes detected by the existing submission diff.
- The generated unit-shadow cache is rebuilt for current source art. Its generator extracts geometry from the same raw source bytes whose hashes it records, avoiding a stale imported image being stamped with a current source hash. Runtime validation checks all shipped source fingerprints and requires warm shadow lookup to avoid fallback extraction.
- Additive local phase timers distinguish surface preview, board-attack planning, conduction, hit resolution, and finishing. Inclusive timers use `_total` and are excluded from Steam's summed leaf counters; see [performance telemetry](performance_telemetry.md).

## Matched surface measurements

Baseline: a detached worktree at local `master` commit `672de6095e9d23d975cd9a74485dc64b088a9512`, with only the shared benchmark/tooling corrections copied in. Candidate: `codex/deep-wide-frame-pacing-performance-pass`, based on that same commit. Surface measurements were captured before committing, so those reports deliberately show dirty trees; the artifact manifest records source hashes. The final v14 full-runtime candidate was measured on clean implementation commit `529857f0ff9197aaa95a5d83fc5586d3107e2379`. No baseline production code was replaced with candidate implementations.

`surface_input_and_retained_rendering_v2` uses live card clicks and pointer-hover routing with a legal seven-card hand, a populated depth-13 board, 16 relics, and 25 connected conductive tiles. Cold runs visit each target once; warm runs make three sweeps. The same target tiles, committed-state digests, and preview-presentation digests must match before the comparison tool prints an accepted table. Only the per-process analytics combat ID is removed from the committed-state digest; rules, queues, RNG, events, and all other state remain included. Timed loops exclude PNG capture.

All times below are milliseconds. The p95 values are over the actual sampled completed-draw intervals, including each routed handler and its next draw. Updraft has three legal target tiles (nine warm samples); the other cards have twelve (36 warm samples).

| Warm hover | Median, base → candidate | p95, base → candidate | Maximum, base → candidate | >33.33 ms / samples |
| --- | ---: | ---: | ---: | ---: |
| Chain Bolt | 72.416 → 22.847 | 147.322 → 31.579 | 147.353 → 32.864 | 36/36 → 0/36 |
| Wildfire Halo | 52.172 → 20.872 | 54.611 → 24.717 | 55.411 → 24.913 | 36/36 → 0/36 |
| Frostbolt | 45.435 → 12.401 | 48.446 → 20.902 | 49.366 → 21.201 | 36/36 → 0/36 |
| Updraft | 38.380 → 12.384 | 39.844 → 21.481 | 39.844 → 21.481 | 9/9 → 0/9 |

This is a 46–79% reduction in warm-hover p95 for these four workloads. The candidate still exceeds 16.67 ms in 23/36, 28/36, 13/36, and 4/9 samples respectively; the result is not a universal 60 FPS claim.

The following explicit presentation submissions isolate redraw routing in the same populated UI. They are rendering workloads, not independently measured player inputs. Each has 90 timed frames.

| Presentation | Median, base → candidate | p95, base → candidate | Tile draw calls | >16.67 ms frames |
| --- | ---: | ---: | ---: | ---: |
| Moving single-tile preview | 13.192 → 8.313 | 17.650 → 8.921 | 13,546 → 395 | 17 → 0 |
| Single-tile animated feedback | 13.067 → 8.318 | 17.941 → 9.890 | 13,553 → 307 | 10 → 0 |
| Bent Chain floor path | 16.082 → 7.670 | 19.858 → 12.900 | 4,809 → 1,128 | 40 → 0 |
| Dense Rubble idle | 8.159 → 8.273 | 12.661 → 8.931 | 876 → 160 | 0 → 0 |
| Dense mixed elemental idle | 5.917 → 6.113 | 18.004 → 17.870 | 869 → 909 | 22 → 23 |

Mixed animated idle is effectively unchanged; its redraw count varies with elapsed animation phases. Rubble's typical frame interval is unchanged while its tail and redundant work shrink. Final live nodes are **4,633 on both sides**, orphan nodes are **zero on both sides**, and static memory is **263,401,405 → 261,431,069 bytes** (about 0.7% lower). Native samples remained foreground throughout.

The headless `surface_relic_and_attack_resolution_v1` measures seven batches of eight calls. These are median batch-average CPU microseconds, not individual frame percentiles. The public validated preview is compared with the committed presentation resolver for identical final state and route.

| Public surface preview | Base µs | Candidate µs | Reduction |
| --- | ---: | ---: | ---: |
| Ranged | 3,416.750 | 1,514.000 | 55.7% |
| Area | 3,522.000 | 1,692.625 | 51.9% |
| Conduction | 19,256.375 | 3,382.375 | 82.4% |
| Chain | 21,303.625 | 4,938.500 | 76.8% |

## Broader runtime coverage

The full runtime harness uses the capped-hand depth-13 interaction matrix, including independent movement, seven card actions, six manual abilities, Flurry scaling, ranged-trap hand recovery, three enemy compositions, repeated scene installation, and synthetic Blink steady/sweep workloads. The optional live-save Blink workload was skipped on both sides because no `LABYRINTH_RUNTIME_PERF_LIVE_SAVE_PATH` was supplied. Enemy-round outcomes must match the complete untimed engine oracle, including every scheduled enemy activation.

Harness repairs were necessary before accepting measurements:

1. The experienced depth-13 fixture now marks the introductory combat tutorial complete. Otherwise the tutorial blocked ordinary ability palette input.
2. Abilities route through the current live controls, including a ground-kind choice and board target where required. The post-ability check verifies that hand input recovers.
3. Cinder Fusillade's repeated-action assertion derives its expected count from its current printed actions instead of assuming an obsolete two-action definition.
4. The rendering fixture calls the current two-argument ambient-count API.
5. Runtime workload **v14** waits for a completed draw after the untimed enemy oracle. Previously, an immediately ready Pass button let the first sampled interval include fixture/reference work. The older 189–305 ms first-frame enemy maxima from this session are excluded; they are not gameplay hitch measurements. The workload ID changes so comparison rejects the old boundary.

The first standalone cold-dissolve trial missed one authored update. A fresh matched baseline/candidate pair passed the original strict assertion with every authored update submitted; the assertion was not relaxed. This remains one observed failed cold trial, not evidence that a specific dissolve fix eliminated it.

### Accepted v14 runtime pair

Both reports pass the comparison tool with identical enemy-round reference digests and no semantic, focus, or orphan failures. Times are completed-draw milliseconds; whole action duration includes authored animation and is not a hitch metric.

| Runtime workload | Median, base → candidate | p95 | p99 | Maximum | >16.67 ms / samples | >33.33 ms / samples |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Populated idle | 8.377 → 8.382 | 8.698 → 8.654 | 8.750 → 8.738 | 8.774 → 8.772 | 0/150 → 0/150 | 0/150 → 0/150 |
| Seven card actions | 8.348 → 8.336 | 15.413 → 12.368 | 41.341 → 29.196 | 75.971 → 76.106 | 62/1,499 → 31/1,537 | 16/1,499 → 15/1,537 |
| Specialist enemy round | 8.347 → 8.346 | 9.248 → 9.128 | 18.412 → 15.211 | 51.698 → 44.337 | 29/1,932 → 17/1,968 | 2/1,932 → 2/1,968 |
| Swarm enemy round | 8.313 → 8.321 | 10.753 → 10.172 | 20.445 → 20.342 | 53.703 → 53.683 | 36/2,382 → 35/2,389 | 8/2,382 → 5/2,389 |
| Dragon/support round | 8.362 → 8.359 | 8.806 → 8.924 | 17.318 → 13.306 | 51.988 → 37.727 | 11/1,075 → 5/1,078 | 2/1,075 → 2/1,078 |

The ordinary seven-card warm-hover sweep improves completed-draw p95 **37.289 → 19.088 ms**, maximum **39.901 → 23.017 ms**. Initial card-selection p95 remains **67.230 → 58.617 ms** across seven samples. All six manual abilities complete their live choices and restore hand input; their individual maximum frame intervals fall from **43–81 ms to 30–59 ms**.

Aggregate action p95/p99 improve by about 20%/29%, and the number of frames above 16.67 ms halves. The worst card-action frame is effectively unchanged at **76 ms**, and 15 frames still exceed 33.33 ms. In Wildfire Halo, that maximum occurs near unlock (sample 295/298); the profile records 43.2 ms for UI refresh, including 13.6 ms hand refresh and 16.9 ms relic-bar refresh with analytics reconciliation. These inclusive sections overlap and must not be summed. This is an unresolved transition bottleneck, not a demonstrated win. Swarm maximum is also unchanged; dragon p95 varies upward by 0.118 ms while p99 and maximum improve.

Individual card tails are mixed. Shadow Step p95 rises **10.128 → 13.833 ms (+36.6%)**, while p99 falls **43.832 → 33.827 ms** and maximum **74.896 → 64.847 ms**; >16.67/>33.33 counts remain **4/2** across 192 → 191 samples. Threaded Path p95 rises **10.938 → 11.518 ms (+5.3%)**, while p99 falls **31.381 → 26.819 ms**, maximum **69.614 → 54.724 ms**, and >16.67 counts fall **5 → 4** across 253 frames on each side. Both medians also improve slightly. These sub-budget p95 regressions are retained explicitly; phase scheduling and a small tail sample can move the percentile independently of worst-case or total work. They do not establish a universal per-card pacing improvement and should be checked on target hardware.

Enemy animation clocks retain exactly **54/38/48 authored frames** for specialist/swarm/dragon, with **zero skipped frames** on both sides. Full-runtime nodes rise from 3,066 while initially warming different compositions to 4,041, then remain **4,041 across repeated installation and final capture** on both sides. Orphans remain **zero**; static memory is **246,435,774 → 242,909,444 bytes** (about 1.4% lower).

### Rendering, rewards, and dissolves

| Other native workload | Median, base → candidate | p95 | Maximum | >33.33 ms frames |
| --- | ---: | ---: | ---: | ---: |
| Board-only idle | 8.332 → 8.339 | 10.664 → 9.417 | 23.417 → 10.460 | 0 → 0 |
| Board-only interaction | 8.333 → 8.319 | 10.197 → 9.474 | 10.666 → 9.773 | 0 → 0 |
| Board-only movement | 8.320 → 8.313 | 9.840 → 9.420 | 10.095 → 12.637 | 0 → 0 |
| Board-only action effects | 8.272 → 8.228 | 10.703 → 10.756 | 20.092 → 20.627 | 0 → 0 |
| Reward idle | 8.304 → 8.269 | 9.192 → 10.103 | 13.481 → 12.042 | 0 → 0 |
| Victory animation | 8.267 → 8.286 | 9.016 → 8.885 | 25.578 → 26.553 | 0 → 0 |
| Reward reveal | 8.404 → 8.339 | 9.013 → 8.903 | 9.261 → 9.157 | 0 → 0 |
| Cold enemy dissolve | 8.336 → 8.306 | 10.202 → 8.934 | 24.420 → 22.481 | 0 → 0 |
| Four repeated dissolves | 8.359 → 8.313 | 10.112 → 8.943 | 19.905 → 18.451 | 0 → 0 |

Board-only phases each contain 150 frames; reward idle/victory/reveal contain 120/102/107 frames. Dissolve counts are 124 → 125 cold and 501 → 502 repeated frames, with the same 28 cold and 112 repeated authored updates and zero skips/canvas compilations. These background/animation workloads are generally close; the pass does not claim a rendering-quality tradeoff or a universal improvement in their individual maxima.

Reward-idle p95 rises **9.192 → 10.103 ms (+9.9%)** despite a slightly lower median and maximum, with zero missed 16.67 ms budgets on both sides. This is a small absolute mixed-tail regression, not a claimed win. The headless board-submission medians also rise: identical **14.078 → 16.000 µs**, effect-progress **98.261 → 105.428 µs**, movement **232.917 → 249.339 µs**. Extra dependency analysis runs at submission so that subsequent native drawing does much less work; the accepted surface frame measurements above include both costs. These microsecond increases are an explicit tradeoff for eliminating thousands of tile redraws, with unchanged semantics and node counts.

A follow-up reward pair was attempted to check that small idle-tail change. Its candidate lost window focus and failed the existing foreground assertion, so that pair is excluded from performance claims; it does not replace the accepted table above.

## Correctness and appearance proof

- `surface_preview_equivalence_test.gd`: 72 combinations, 1,337 legal targets, three Umbra stages, connected/island/conductive-Fire networks, eight action types, hidden traps, and multi-cell bodies. All baseline/candidate case digests match. Additional technique cases cover Faultline, Chain endpoint exchange, Worldroot, terrain-blocked conductors, invalid public targets without payment, retained committed hit snapshots, repeated cache hits, same-revision A/B/A source changes, and automatic followups. Both versions report no semantic errors.
- `surface_redraw_equivalence_probe.gd`: 30 first-frame selective-versus-full redraw comparisons across normal/reduced motion, moved/removed feedback, diagonal/bent/branched Chain, HUD status additions, and clearing. The accepted capture is byte-identical in all 30 cases. The probe allows at most 32 channel samples differing by at most 3/255 for native boundary rounding; an earlier trial observed four such pixels when clearing the HUD.
- `board_surface_cache_equivalence_probe.gd`: fresh normal/reduced and multiple-phase native comparisons differ only at 87–95 RGB channel samples by at most 2/255 across a full 1920×1080 image. External PNG analysis is retained in `cache/pixel_analysis.json`. Retained Fire phase alignment, pinned Ice width/seed changes, and twelve ground replacement/removal cycles pass; retained board nodes stay at 2,357.
- Native full-UI Chain hover, dense elemental ground, normal/reduced Chain paths, and friendly damage/status captures were inspected at 1920×1080. Hand geometry, surfaces, characters, lighting, feedback depth, and target presentation remain intact.
- The full Godot regression suite passes on the unchanged baseline and the candidate. Both emit the same 27 CanvasItem, 338 dummy-texture, ObjectDB, and one-resource shutdown warnings. Logs are retained with the proof artifacts. Native workloads independently assert zero orphan nodes.
- `python3 tests/test_performance_pass.py` passes seven tests. The comparison tool rejects changed input targets, preview/CPU route semantics, incompatible workload boundaries, missing timing availability, and native selection without `--native`.

## Reproduction and artifacts

Raw reports, comparison tables, logs, inspected PNGs, and source hashes are retained under `/tmp/labyrinth-deep-wide-proof`. This is local inspection evidence, not a packaged game asset. Benchmark/probe sources are committed so the checks can be repeated on a Steam Deck or other target machine.

Run matched surface and full native passes serially, with no concurrent Godot workloads:

```bash
python3 tools/performance_pass.py run --task-id surface-proof --native \
  --benchmark surface_cpu --benchmark surface_frame --output /tmp/surface-proof.json
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run \
  --task-id full-performance-proof --native --output /tmp/full-performance-proof.json
python3 tools/performance_pass.py compare /tmp/base.json /tmp/candidate.json
```

The surface entry point explicitly uses the supported hand cap. For full runtime captures, retain the capped-hand environment variable on both sides. Real-renderer probes use `tools/visual_probe_runner.py`; all Godot work runs through the task runner. Do not compare reports from different workload versions or treat zero GPU timestamps as free rendering.

## Remaining target-hardware work

The largest confirmed hover bottlenecks are reduced, but some action boundaries still exceed a 16.67 or 33.33 ms budget. Hand reconstruction, card-option planning, save/checkpoint work, analytics reconciliation, and initial hand-cache capture remain visible in the broader profiles. Their cost must be evaluated with the corrected runtime boundary and on weaker hardware before setting a shipping frame-time target.

A Steam Deck/Linux capture remains necessary to establish its actual CPU/GPU balance and sustained frame budget. Preserve the same artwork, animation cadence, input semantics, and workload on that device. Windows execution was not available locally; new typed-array assignments use typed temporaries, and no platform-specific renderer workaround is introduced.
