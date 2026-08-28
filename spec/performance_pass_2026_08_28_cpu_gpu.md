# CPU planning and granular telemetry pass — 2026-08-28

## Status and scope

CPU candidate implemented and measured. Native frame-pacing acceptance is **pending**: the runtime benchmark could not acquire desktop focus, and the Computer Use service timed out. Failed/unfocused runs are excluded from performance claims. This pass is not yet ready for publication or user-inspection signoff.

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

Other headless checks remained close: full cached UI refresh 12.959 → 12.897 ms, cached presentation 1.809 → 1.785 ms, identical board submission 14.383 → 14.767 microseconds. No improvement is claimed for these unaffected paths. Cached UI node samples remained `[1047, 1047, 1047, 1047, 1047]`, and the final count remained 1058 on both sides. Persistent allocation and native memory proof remain pending; bounded node counts alone do not establish leak freedom.

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
- `tests/test_performance_pass.py`: PASS, two tests covering unavailable GPU values and forecast semantic mismatch.
- `tests/test_steam_performance_stats_schema.py`: PASS, all 676 existing stats.
- Matched wrapper: simulation, runtime integration, trap idle, and combat board submission all PASS.
- Focused pathfinding and enemy intent preview tests: PASS. New regression cases compare cached/uncached occupancy over 100 anchors with large footprints, overlapping blockers, dead enemies, terrain, traps, and illusions; reach checks compare original versus moved-state clones for six action types.
- Full Godot suite: PASS on the pre-review candidate tree. Log: `/private/tmp/labyrinth-godot-home/cpu-gpu-final-full-regression-1787951112724841000-60598/godot.log`. The process exited 0 after the PASS marker but reported shutdown leaks (149 CanvasItem RIDs, 380 dummy textures, 22 resources, and ObjectDB instances). See the review follow-up for the baseline comparison; no blanket leak-free claim is made.
- Native Metal pathfinding visual probe: PASS at 1920×1080. All four images were inspected: safe route, multi-segment movement, forced trap route, and player-bent route. Output directory: `/private/tmp/labyrinth-godot-home/cpu-gpu-enemy-path-visual-1787950474255535000-59939-enemy_pathfinding_probe-1/Library/Application Support/Escape the Umbra Visual Probe cpu-gpu-enemy-path-visual-1787950474255535000-59939-enemy_pathfinding_probe-1/probes/enemy_pathfinding`.

## Remaining acceptance work

Obtain matched, foreground native captures at 1920×1080 covering idle, interaction, action/animation, and transition phases. Compare frame median/p95/p99/max, budget misses, renderer statistics, and memory/node/orphan behavior. The benchmark's focus and delivery-throttle assertions remain enabled; no failing samples were filtered into a successful result. Then obtain independent peer review and generate the verified pre-action dense-combat inspection fixture. Publication requires the user's explicit approval.

## Review follow-up

Independent review of `a9ad31ba` returned `REQUEST_CHANGES`: missing native proof and double-counted nested trap timings. The latter is corrected by marking enemy action-resolution timers `_total`. The existing forced-choke pathfinding regression now resolves an actual enemy trap activation with instrumentation both off and on, compares the results, and verifies that Steam retains the trap leaf counters while excluding the parent action timers. The focused suite passes. This timer naming correction does not change the routing implementation.

The post-review headless wrapper also passes all four benchmarks: `/tmp/labyrinth-cpu-gpu-proof/candidate-reviewed.json`. Forecast median/p95 batch averages are 9.002/9.050 ms, with the same digest, six steps, and unchanged source state. Unaffected benchmarks also ran somewhat faster in this later capture, so this is repeatability evidence for the large forecast gain, not evidence of additional optimization from renaming a timer. Across the three candidate captures, the forecast median is 9.0–9.6 ms versus the 60.7 ms baseline.

A baseline full-suite check replaced all seven changed GDScript files with their original `15569d54` versions and restored the candidate in `finally`. It passed and emitted the same 149 CanvasItem and 380 dummy-texture counts, plus ObjectDB warnings and 21 retained resources. Thus the bulk shutdown warnings also occur on the baseline; the candidate's extra retained resource is not yet explained. Baseline log: `/private/tmp/labyrinth-godot-home/cpu-gpu-baseline-full-regression-1787951525878520000-61343/godot.log`. Native runtime memory stability remains an open acceptance item.

Fresh exact-`a9ad31ba` native visual proof is recorded in `/tmp/labyrinth-cpu-gpu-proof/final-visual-manifest.json`; all four images were inspected. Its actual local schema-2 output reported positive viewport CPU timing with `viewport_render_cpu_timing_available=true`, and zero GPU timestamps with `viewport_render_gpu_timing_available=false`. It validates telemetry integration and availability, not frame pacing. The runtime window was not a valid foreground timing environment.
