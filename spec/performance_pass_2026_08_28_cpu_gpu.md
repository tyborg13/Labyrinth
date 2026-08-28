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
- `tests/test_performance_pass.py`: PASS, three tests covering unavailable GPU values, forecast semantic mismatch, and native enemy-round semantic mismatch.
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

Environment: the same Apple M5 Pro and Godot 4.6.1, Metal/mobile, a foreground **1920×1080** window at **100% UI scale**, identical high-quality content and authored animation timing. The native runtime workload is `depth_13_live_run_interaction_matrix_v12`, with `LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1` to respect the seven-card cap. Both sides use identical benchmark/telemetry source. As in the CPU comparison, the baseline replaces only `combat_engine.gd` with `15569d54`; the candidate is restored in `finally`. The containing worktree was at `c8395571` with the benchmark follow-up uncommitted, not two clean native checkout revisions. The assembled reports record this provenance and the shared benchmark SHA-256.

The existing benchmark had stale fixtures: Pilgrim Boots no longer changes Shadow Step's definition, an Encore choice could be outside its scroll viewport, and edge targets could be covered by the hand/HUD. The repaired checks use the real Tailwind Fletching/Gust Step modifier, scroll the actual choice into view, and choose an unobscured central legal target. Capped-hand Flurry checks now explicitly install their card instead of timing index -1.

Granular telemetry also exposed that the old “enemy round” cases could advance straight back to the player. The new fixture schedules every enemy before the next player, routes a real click through the visible Pass button, and requires the complete resulting combat state to equal an untimed engine oracle with the same commit-time analytics/movement normalization. Stable fixture analytics IDs allow cross-process result comparison. Base and candidate match all reference digests, 10/10/5 enemy activations, and 110/111/55 presentation/commit steps for specialists/swarm/dragon. The comparison tool rejects different enemy-round digests or step counts. No production UI or gameplay changes were needed for these harness repairs.

### Frame pacing

Each entry is base → candidate. Times are milliseconds; misses retain their sample denominators.

| Phase | Median | p95 | p99 | Maximum | >16.67 ms / samples | >33.33 ms / samples |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Dense idle | 8.245 → 8.243 | 9.579 → 9.680 | 9.793 → 9.798 | 9.899 → 9.905 | 0/150 → 0/150 | 0/150 → 0/150 |
| Seven card actions | 8.327 → 8.325 | 14.281 → 14.752 | 29.745 → 30.166 | 110.910 → 117.333 | 68/1910 → 73/1910 | 18/1910 → 19/1910 |
| Specialist enemy round | 8.303 → 8.303 | 10.131 → 9.973 | 35.631 → 34.355 | **429.953 → 280.877** | 45/3088 → 45/3086 | 32/3088 → 31/3086 |
| Swarm enemy round | 8.309 → 8.309 | 11.316 → 11.737 | 41.030 → 39.444 | **420.785 → 295.505** | 58/3466 → 55/3467 | 39/3466 → 37/3467 |
| Dragon enemy round | 8.296 → 8.308 | 9.437 → 9.576 | 25.398 → 25.367 | 202.551 → 187.295 | 22/1683 → 20/1692 | 13/1683 → 14/1692 |

Cold interaction's four-frame p95/max is 27.451 → 27.779 ms. Root viewport idle render CPU median is 0.301 → 0.306 ms, with GPU timing correctly unavailable on Metal. Idle and ordinary action pacing are effectively unchanged; action-tail and missed-frame noise is reported rather than described as a win. All listed p95 changes are below 5%. The meaningful native improvement is smaller worst enemy-round stalls, about 35% for specialists and 30% for the swarm, not a general FPS uplift. These maxima are individual-run observations, not a guaranteed bound. A separate passing candidate capture before stabilizing the analytics ID saw maxima of 280.411/281.842/175.026 ms, supporting the reduction without claiming a repeated matched baseline experiment.

The live Pass forecast section measured 96.527 → 32.839 ms for specialists, 79.752 → 48.283 ms for swarm, and 42.171 → 22.604 ms for dragon (one measured call each). That corroborates the repeated headless CPU result. Remaining roughly 280–296 ms worst frames are still too slow. Broader turn/checkpoint/presentation work remains worth profiling; the results do not establish that GDScript itself or GPU throughput is the remaining bottleneck.

### Reward transition repeatability

Reward reveal remained steady: median 8.350 → 8.303 ms, p95 9.041 → 9.107 ms, and zero >16.67 ms frames out of 253 on both sides. A second pair measured p95 9.323 → 8.999 ms with the same zero misses. The short victory animation's first p95 was 9.460 → 15.944 ms (103/101 frames), so that apparent regression was explicitly repeated: p95 then reversed to 16.361 → 9.759 ms (102/101 frames). Median stayed near 8.3 ms in all four runs; >16.67 ms counts were 1/103 → 2/101, then 2/102 → 2/101. This is unstable tail sampling around a display interval, not evidence of a repeatable win or regression. Reward-idle p95 also ranged 16.972–18.257 ms across the two pairs. No transition-performance improvement is claimed.

The repeated pair passed focus, semantics, and visual-runner checks. Raw repeat reports and manifests are `/tmp/labyrinth-cpu-gpu-proof/unlocked-reward-repeat-base.json`, `unlocked-reward-repeat-candidate.json`, and the corresponding `-manifest.json` files. All runs are retained; no noisy successful run was discarded.

### Stability and proof artifacts

Both full native runtime runs passed all seven card actions, six manual abilities, movement, previews, overlays, all three actual enemy rounds, reference equivalence, focus, and delivery-throttle checks. No observed frame lost focus, and no throttle-signature sample was filtered. Fresh native screenshots were inspected for dense idle, movement/blink/line targeting, ranged trap aftermath, and the untimed committed Wildfire presentation. Reward screenshots cover active victory, mid-flip, and settled cards. Assets, ordering, input routes, and animation code are unchanged; these are visual inspections, not pixel-identical captures of animation phases.

Runtime static memory is 199,063,635 → 199,398,351 bytes (**+0.17%**). Settled nodes are 3778 → 3777, and repeating the same fixture remains 3778/3777 respectively. Objects are 12281 → 12280. Both sides start and finish with exactly two existing orphan nodes: `CardPlayMeterSlot` and its `CardPlayMeterSpacer` child from `RunScene._setup_play_meter`. This is an explicit pre-existing exception to the zero-orphan ideal, not a leak-free claim. Both native runtime exits retain four resources; both reward exits retain one.

The final full regression run passes with verbose shutdown diagnostics: `/tmp/labyrinth-cpu-gpu-proof/unlocked-final-full-tests.log`. This time it retains 21 resources, matching the earlier baseline count, so the prior one-extra-resource observation did not reproduce. The verbose list consists of the combat board script, retained unit/terrain textures, and menu-audio resources. The pre-existing shutdown warnings remain a separate cleanup issue.

Primary raw evidence:

- Runtime baseline: `/tmp/labyrinth-cpu-gpu-proof/unlocked-v12-base-final-runtime.json` and `unlocked-v12-base-final-manifest.json`.
- Matched runtime candidate: `/tmp/labyrinth-cpu-gpu-proof/unlocked-v12-candidate-matched-runtime.json` and `unlocked-v12-candidate-matched-runtime-manifest.json`.
- Reward baseline/candidate: `/tmp/labyrinth-cpu-gpu-proof/unlocked-v11-base-reward.json` and `unlocked-v12-candidate-matched-reward.json`. Their reward workload/source is identical despite the filename prefixes.
- Assembled native reports: `/tmp/labyrinth-cpu-gpu-proof/native-base.json`, `native-candidate.json`; compatibility-checked table: `native-comparison.md`.

Reproduce the runtime phase with `LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd --task-id <unique-id> --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --startup-timeout 12 --min-images 1 --expect-size 1920x1080 --result-manifest /tmp/<manifest>.json` from the task worktree. The expanded workload includes roughly a minute of real enemy animations, so its 300-second timeout is intentional. The pure render microbenchmark's earlier retained-HUD assertion failures are not used as successful evidence; the passing live runtime workload supplies native interaction/action/render coverage.
