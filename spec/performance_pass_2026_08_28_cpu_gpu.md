# CPU planning and granular telemetry pass — 2026-08-28

## Status and scope

CPU optimization and matched native verification are complete after the Mac was unlocked. The full regression suite passes. Failed, unfocused, and semantically incomplete benchmark runs are excluded from performance claims. Independent review and a verified inspection fixture are required before handoff; publication still requires explicit user approval.

The user requested an optimization pass beyond rendering, with finer telemetry where needed. No gameplay rules, route ranking, inputs, animations, graphics presets, or visual content are intentionally changed. No native C++ dependency is introduced.

## Reproducible bottleneck

The simulation benchmark schedules two revealed enemies before the player and forecasts six steps. A diagnostic capture attributed about 53 ms of a 59 ms forecast to intent planning, with roughly 51 ms in future-route planning. A temporary deeper probe measured 26.8 ms in repeated blocker normalization/scanning across 88 previously unseen anchors. Top-level forecast state copies accounted for only about 0.1 ms in the final profile.

The candidate indexes living blocking enemy entries by occupied tile once per planning call. It caches target-independent anchor facts across neighboring edges and target searches. The cache dies with that call, so a changed turn, position, trap, terrain object, or actor target cannot reuse stale entries. Distinct enemy array entries remain distinct blockers; a multi-cell blocker counts once per candidate footprint. Candidate reach checks use the moved enemy argument and unchanged grid/actor targets instead of cloning the entire combat state at every anchor. Existing route priorities and tie breaks are retained.

Temporary per-anchor timing was removed. Retained timers separate forecast preparation, enemy-turn setup, intent planning, action preparation/resolution/presentation, and turn completion. Nested inclusive sections use `_total` and are excluded from Steam section sums.

## Matched CPU results

Machine: Apple M5 Pro, macOS 26.3.1 arm64, Godot 4.6.1 `14d19694e`. Headless results measure synchronous CPU work, not renderer cost or player-visible frame intervals.

Both sides use the new benchmark and telemetry sources. For the baseline, only `scripts/combat_engine.gd` was temporarily replaced with the file from `15569d54a819c5e5ed1a3aa195c46620499b70fa`, then the candidate was restored in a `finally` block. Consequently both raw reports record that base HEAD and a dirty tree; they are not claims of two clean checkout revisions. The benchmark runs seven batches of eight forecast calls, with profiling measured separately from the timed batches.

| Forecast CPU per call | Base | Final candidate | Change |
| --- | ---: | ---: | ---: |
| Median batch average | 60.749 ms | 9.352 ms | -84.6% |
| p95 batch average | 60.946 ms | 9.496 ms | -84.4% |
| Minimum batch average | 60.673 ms | 9.228 ms | -84.8% |

These percentiles are over batch averages, not individual frame tails. Both results have digest `1912791714`, six steps, an unchanged caller state, and no semantic errors. Instrumented and uninstrumented candidate forecasts also compare equal.

The final diagnostic forecast records 3.734 ms in intent planning, including 0.608 ms building the two route contexts and 1.375 ms searching them. Action presentation is now a larger remaining component (2.315 ms across four actions) and is a candidate for the next measured pass. Timings from nested parent sections must not be added to their children.

Other headless checks remained close: full cached UI refresh 12.959 → 12.897 ms, cached presentation 1.809 → 1.785 ms, identical board submission 14.383 → 14.767 microseconds. No improvement is claimed for these unaffected paths. Cached UI node samples remained `[1047, 1047, 1047, 1047, 1047]`, and the final count remained 1058 on both sides. Native memory measurements are recorded below; bounded node counts alone do not establish leak freedom.

Raw reports outside source control:

- `/tmp/labyrinth-cpu-gpu-proof/base.json`
- `/tmp/labyrinth-cpu-gpu-proof/candidate.json` (first candidate capture)
- `/tmp/labyrinth-cpu-gpu-proof/candidate-final.json` (final source capture)
- Deep profile: `/private/tmp/labyrinth-godot-home/cpu-gpu-enemy-plan-deep-profile-1787943484607760000-57405/godot.log`
- Blocker profile: `/private/tmp/labyrinth-godot-home/cpu-gpu-enemy-anchor-detail-profile-1787943771033965000-57730/godot.log`

Reproduce with `python3 tools/performance_pass.py run --task-id <unique-id> --output /tmp/<report>.json`, then `python3 tools/performance_pass.py compare <base-report> <candidate-report>`. Use identical benchmark sources on both sides. The comparison now rejects differing forecast digests or step counts.

## Telemetry and measurement limits

Schema 2 adds physics process time, RenderingServer setup CPU, and root-viewport render CPU/GPU mean/max values to existing local/HTTP summaries. It preserves the existing 676 Steam stat definitions. Positive-value availability flags prevent zero GPU timestamps from being treated as free rendering. The benchmark comparison skips unavailable GPU metrics.

Godot 4.6.1 Metal returns zero GPU timestamps, verified against the [backend implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/drivers/metal/rendering_device_driver_metal.mm). Root-viewport timing excludes separately rendered cached subviewports; it is partial attribution, not total CPU/GPU occupancy. See [the telemetry specification](performance_telemetry.md) for scope and transport details.

The final isolated headless overhead benchmark measured 2.835 microseconds per sampled frame (p95 2.858), and 2.164 ms per summary flush plus fake Steam transport (p95 2.244). Native backend timing overhead is not established by a headless benchmark. No Steam Deck run of this candidate has occurred, so no Deck FPS, battery-life, or preset recommendation is inferred from the CPU speedup.

## Proof

- `tests/performance_telemetry_test.gd`: PASS for the final sampler, timing fields, availability flags, and nested section aggregation.
- `tests/performance_telemetry_overhead_benchmark.gd`: PASS with empty semantic errors; final log at `/private/tmp/labyrinth-godot-home/cpu-gpu-final-overhead-1787951062243166000-60530/godot.log`.
- `tests/test_performance_pass.py`: PASS, four tests covering unavailable GPU values, forecast semantic mismatch, native enemy-round semantic mismatch, and incompatible process-clock/post-draw reports.
- `tests/test_steam_performance_stats_schema.py`: PASS, all 676 existing stats.
- Matched wrapper: simulation, runtime integration, trap idle, and combat board submission all PASS.
- Focused pathfinding and enemy intent preview tests: PASS. New regression cases compare cached/uncached occupancy over 100 anchors with large footprints, overlapping blockers, dead enemies, terrain, traps, and illusions; reach checks compare original versus moved-state clones for six action types.
- Full Godot suite: PASS on the pre-review candidate tree. Log: `/private/tmp/labyrinth-godot-home/cpu-gpu-final-full-regression-1787951112724841000-60598/godot.log`. The process exited 0 after the PASS marker but reported shutdown leaks (149 CanvasItem RIDs, 380 dummy textures, 22 resources, and ObjectDB instances). See the review follow-up for the baseline comparison; no blanket leak-free claim is made.
- Native Metal pathfinding visual probe: PASS at 1920×1080. All four images were inspected: safe route, multi-segment movement, forced trap route, and player-bent route. Output directory: `/private/tmp/labyrinth-godot-home/cpu-gpu-enemy-path-visual-1787950474255535000-59939-enemy_pathfinding_probe-1/Library/Application Support/Escape the Umbra Visual Probe cpu-gpu-enemy-path-visual-1787950474255535000-59939-enemy_pathfinding_probe-1/probes/enemy_pathfinding`.

## Inspection and publication

The benchmark focus and delivery-throttle assertions remain enabled; no failing samples were filtered into a successful result. The task requires independent peer review and a verified pre-action combat fixture before user handoff. Publication requires the user's explicit approval; this branch has not been merged or pushed.

## Review follow-up

Independent review of `a9ad31ba` returned `REQUEST_CHANGES`: missing native proof and double-counted nested trap timings. The latter is corrected by marking enemy action-resolution timers `_total`. The existing forced-choke pathfinding regression now resolves an actual enemy trap activation with instrumentation both off and on, compares the results, and verifies that Steam retains the trap leaf counters while excluding the parent action timers. The focused suite passes. This timer naming correction does not change the routing implementation.

The post-review headless wrapper also passes all four benchmarks: `/tmp/labyrinth-cpu-gpu-proof/candidate-reviewed.json`. Forecast median/p95 batch averages are 9.002/9.050 ms, with the same digest, six steps, and unchanged source state. Unaffected benchmarks also ran somewhat faster in this later capture, so this is repeatability evidence for the large forecast gain, not evidence of additional optimization from renaming a timer. Across the three candidate captures, the forecast median is 9.0–9.6 ms versus the 60.7 ms baseline.

A baseline full-suite check replaced all seven changed GDScript files with their original `15569d54` versions and restored the candidate in `finally`. It passed and emitted the same 149 CanvasItem and 380 dummy-texture counts, plus ObjectDB warnings and 21 retained resources. Thus the bulk shutdown warnings also occur on the baseline; the candidate's extra retained resource is not yet explained. Baseline log: `/private/tmp/labyrinth-godot-home/cpu-gpu-baseline-full-regression-1787951525878520000-61343/godot.log`. Native runtime memory stability was still open at that checkpoint; the unlocked follow-up below resolves the matched runtime proof gap.

Fresh exact-`a9ad31ba` native visual proof is recorded in `/tmp/labyrinth-cpu-gpu-proof/final-visual-manifest.json`; all four images were inspected. Its actual local schema-2 output reported positive viewport CPU timing with `viewport_render_cpu_timing_available=true`, and zero GPU timestamps with `viewport_render_gpu_timing_available=false`. It validates telemetry integration and availability, not frame pacing. The runtime window was not a valid foreground timing environment.


## Unlocked native verification

Environment: the same Apple M5 Pro and Godot 4.6.1, Metal/mobile, a foreground **1920×1080** window at **100% UI scale**, identical high-quality content and authored animation timing. The native runtime workload is `depth_13_live_run_interaction_matrix_v13`, with `LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1` to respect the seven-card cap. Both sides use identical benchmark/telemetry source. As in the CPU comparison, the baseline replaces only `combat_engine.gd` with `15569d54`; the candidate is restored in `finally`. The containing worktree was at `bfd4f2fe` with the sampling follow-up uncommitted, not two clean native checkout revisions. The assembled reports record this provenance and the shared benchmark SHA-256.

The existing benchmark had stale fixtures: Pilgrim Boots no longer changes Shadow Step's definition, an Encore choice could be outside its scroll viewport, and edge targets could be covered by the hand/HUD. The repaired checks use the real Tailwind Fletching/Gust Step modifier, scroll the actual choice into view, and choose an unobscured central legal target. Capped-hand Flurry checks now explicitly install their card instead of timing index -1.

Granular telemetry also exposed that the old “enemy round” cases could advance straight back to the player. The new fixture schedules every enemy before the next player, routes a real click through the visible Pass button, and requires the complete resulting combat state to equal an untimed engine oracle with the same commit-time analytics/movement normalization. Stable fixture analytics IDs allow cross-process result comparison. Base and candidate match all reference digests, 10/10/5 enemy activations, and 110/111/55 presentation/commit steps for specialists/swarm/dragon. The comparison tool rejects different enemy-round digests or step counts. No production UI or gameplay changes were needed for these harness repairs.

### Sampling correction from independent review

Review of `bfd4f2fe` found that the old runtime and reward samplers timestamped `_process` callbacks even though surrounding loops awaited rendered frames. The earlier `unlocked-*` and `native-*` reports therefore do **not** establish rendered-frame pacing; their previously reported frame-tail reductions are superseded. They remain useful for CPU-handler, semantic, and stability diagnostics only.

Both samplers now timestamp `RenderingServer.frame_post_draw`, retain the preceding completed-draw timestamp when beginning a phase, and disconnect their signal on tree exit. An imperceptible render pulse continues during production animation coroutines. Focus is checked on every sampled draw. Reward victory, flips, and reveal await their final redraw before sampling ends, while coroutine-completion duration is retained separately from render-completion duration. `sample_boundary=RenderingServer.frame_post_draw_v1` and bumped workload IDs reject comparisons with the former process clock. These are Godot draw-completion intervals, not hardware GPU-completion or compositor-presentation timestamps.

### Accepted post-draw frame pacing

The following replacement capture uses the corrected sampler on **both** sides. Times are milliseconds; all raw reports retain sample denominators and no focus/throttle failures were filtered.

| Phase | Median | p95 | p99 | Maximum | >16.67 ms / samples | >33.33 ms / samples |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Dense idle | 8.284 → 8.254 | 9.669 → 9.609 | 9.758 → 9.770 | 9.938 → 9.817 | 0/150 → 0/150 | 0/150 → 0/150 |
| Seven card actions | 8.306 → 8.294 | 13.147 → 13.420 | 25.176 → 26.476 | 113.131 → 114.406 | 63/1912 → 66/1911 | 15/1912 → 17/1911 |
| Specialist enemy round | 8.286 → 8.323 | 10.026 → 9.484 | 34.561 → 31.546 | 429.180 → 285.120 | 46/3082 → 43/3097 | 32/3082 → 30/3097 |
| Swarm enemy round | 8.296 → 8.321 | 11.384 → 10.520 | 39.069 → 37.758 | 423.495 → 288.795 | 53/3466 → 53/3476 | 38/3466 → 35/3476 |
| Dragon enemy round | 8.297 → 8.299 | 9.423 → 9.399 | 26.901 → 25.958 | 210.118 → 183.300 | 21/1690 → 20/1696 | 13/1690 → 12/1696 |
| Reward idle | 8.372 → 8.358 | 11.889 → 11.274 | 12.819 → 14.688 | 16.665 → 14.829 | 0/120 → 0/120 | 0/120 → 0/120 |
| Victory animation | 8.342 → 8.359 | 8.804 → 8.759 | 9.520 → 9.867 | 33.056 → 36.441 | 1/101 → 1/101 | 0/101 → 1/101 |
| Reward reveal | 8.317 → 8.300 | 8.815 → 8.844 | 8.932 → 9.094 | 8.978 → 17.290 | 0/254 → 1/252 | 0/254 → 0/252 |

Typical idle/action pacing is largely unchanged. The directly affected specialist/swarm rounds show smaller worst stalls (about **34%/32%**) and p95 reductions of about **5%/8%** in this pair. The maxima are individual-run observations, not a guaranteed bound. Ordinary card-action tails and misses are slightly noisier in the candidate and are not claimed as a win; no listed p95 regresses by more than 5%. Reward transitions remain close. These findings support less severe enemy-planning stalls, not a universal FPS or battery-life improvement. Remaining 285–289 ms worst frames are still too slow and warrant further attribution of turn/checkpoint/presentation work.

The separately measured routed input-handler costs were:

| Enemy round | Base handler | Candidate handler | Pass forecast CPU, base → candidate |
| --- | ---: | ---: | ---: |
| specialists | 413.940 ms | 270.117 ms | 96.715 → 33.324 ms |
| split_swarm | 410.381 ms | 262.660 ms | 79.575 → 48.642 ms |
| dragon_support | 162.154 ms | 126.486 ms | 42.347 → 23.093 ms |

The forecast section has one native call per composition; the repeated headless batches remain the stronger evidence for its CPU speedup. Full enemy-round completion includes roughly 15–32 seconds of authored animation and must not be interpreted as a single hitch. The matching reference digests/steps establish identical resolved work. GPU timestamps remain explicitly unavailable on Metal; root viewport CPU timing is partial attribution.

### Stability and proof artifacts

Both corrected native runtime runs passed all seven card actions, six manual abilities, movement, previews, overlays, all three actual enemy rounds, complete-state equivalence, focus, and throttle checks. The matched reward runs also passed. No sampled draw was unfocused, and no >=500 ms delivery-throttle signature was accepted. Fresh 1920×1080 captures cover dense idle, movement/blink/line targeting, ranged-trap aftermath, untimed committed Wildfire presentation, active victory, mid-flip, and settled rewards. The rendering and animation code is unchanged; screenshots are visual inspections rather than pixel-identical captures of moving effects.

Runtime static memory is 199,015,844 → 199,277,858 bytes (**+0.13%**). Both retain 3777 settled nodes, with the same count after repeating the fixture. Object counts are 12281 → 12280. Both start/end with exactly two pre-existing orphan nodes: `CardPlayMeterSlot` and its `CardPlayMeterSpacer` child from unchanged `RunScene._setup_play_meter`. This is a documented exception to the zero-orphan ideal, not a leak-free claim. Both native runtime exits report four retained resources. The baseline reward exit reports one retained resource; the candidate reward exit has no retained-resource diagnostic, but both still report CanvasItem/ObjectDB shutdown warnings.

The final full regression run passes: `/tmp/labyrinth-cpu-gpu-proof/unlocked-final-full-tests.log`. Its verbose shutdown diagnostics retain 21 resources, matching the earlier baseline, so the previous one-extra-resource observation did not reproduce. The list contains the combat board script, unit/terrain textures, and menu-audio resources. Those existing warnings remain a separate cleanup issue. The sampling follow-up changes only benchmark, comparison-test, and documentation files; production source is identical to this full-suite run. Four Python comparison tests and all 676 Steam schema definitions pass.

Accepted raw evidence, all under `/tmp/labyrinth-cpu-gpu-proof/`:

- `postdraw-base-runtime.json` and `postdraw-candidate-runtime.json`.
- `postdraw-base-reward.json` and `postdraw-candidate-reward.json`.
- Each has corresponding `-runner.log` and `-manifest.json` files with validated image paths.
- Assembled provenance reports: `postdraw-native-base.json`, `postdraw-native-candidate.json`; compatibility-checked table: `postdraw-native-comparison.md`.

Reproduce runtime from the task worktree with `LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd --task-id <unique-id> --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --startup-timeout 12 --min-images 1 --expect-size 1920x1080 --result-manifest /tmp/<manifest>.json`. The workload contains roughly a minute of actual enemy animations, so its 300-second timeout is intentional. The earlier pure-render microbenchmark retained-HUD failures are not successful proof; the passing live runtime workload supplies native interaction/action/render coverage. Do not compare the superseded process-clock reports to these post-draw captures.
