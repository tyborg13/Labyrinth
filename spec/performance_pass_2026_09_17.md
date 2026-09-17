# Combat performance pass — 17 September 2026

This pass targets the main Escape the Umbra app, especially combat on Steam Deck. It removes repeated CPU work and reduces live cutout data without changing rules, animation cadence, lighting, particles, texture resolution, or antialiasing. Steam Deck hardware was not available: these are **Mac measurements, not Deck FPS claims**.

The most repeatable improvements are actor construction, duplicate-actor memory, board submission, and save checkpoints. In one matched native gameplay pair, the three enemy-turn scenarios produced 81 → 56 frames over 16.67 ms across 5,541 → 5,554 frames. Frames over 33.33 ms remained 6 → 6. Significant transition spikes remain and need further work.

## Source and measurement conditions

- Base: local `master`, `2c1eab7ce6e0d694d0bbd89a56a6b097ea15525a`.
- Candidate branch: `codex/thorough-steam-deck-performance-pass-across-varied-gameplay-and-animatio`.
- Machine: Apple M5 Pro, macOS 26.3.1 arm64; Godot 4.6.1, Metal/mobile renderer, production 4× 2D MSAA.
- Native proof: 1920×1080, 100% UI scale. Foreground tests ran serially after unlocking the display, without simultaneous CPU benchmarks. Accepted reports have zero unfocused observations and empty semantic-error lists.
- Gameplay uses the production hand cap. The animation matrix separately runs uncapped to expose rendering capacity; do not compare its absolute intervals to the vsynced gameplay benchmark.
- GPU timers were unavailable on this renderer. Zero readings are not zero GPU cost. Render submission CPU time, synchronous handler latency, rendered frame intervals, and awaited action completion remain separate metrics.
- Baseline production code is unchanged. Updated benchmark fixtures and instrumentation were copied identically into the baseline worktree. Reports were captured before committing; the [manifest](proofs/performance-2026-09-17/manifest.json) binds changed source files to SHA-256 hashes. Report Git metadata therefore records the base revision plus a dirty candidate, not an invented measured commit.
- CPU construction/submission runs were repeated in both orders, followed by a final matched pair. Native gameplay timings are one accepted full pair; small tail differences and individual maxima should not be treated as repeatable speedups.

The [measurement summary](proofs/performance-2026-09-17/measurements.json) retains scenario-level results. Adjacent `.json.gz` files contain complete raw reports, including individual frame samples and section diagnostics. Failed probes are retained separately as `.log.gz` files and excluded from accepted timing claims.

## Changes and their evidence

### Shared cutout data and fewer skeleton updates

`scripts/protagonist_cutout/rig_data.gd` shares parsed layouts and validated packed mesh arrays among live instances of the same rig source. Each actor still owns independent bones and canvas nodes. Weak references release the large data when the final actor leaves; modified source timestamps invalidate live cache entries. Mesh identity uses source position, not optional display names. Geometry remains copy-on-write.

Nineteen rig implementations now submit each final bone transform once, skipping exact unchanged transforms instead of resetting to rest and setting several transform properties. Existing visibility and draw-order behavior is retained. The equivalence test compares 12,400 poses / 221,800 bone samples against the original setter sequence: **zero nonidentical transforms, maximum error 0.0**. Independent actor poses, geometry ownership, source lifetime, duplicate mesh names, and inherited Scavenger/Graftwright/Wisp loading pass focused tests.

The CPU benchmark constructs front and rear rigs, with five samples per group. It warms textures first, so these are synchronous rig/data costs, not cold disk-loading times. Final-pair medians:

| Group | Construction, base → candidate | Godot live static-heap delta, base → candidate |
| --- | ---: | ---: |
| Two Crawlers + Warden | 75.88 → 46.54 ms | 51.77 → 34.46 MiB |
| Ooze + three Droplets | 126.47 → 47.22 ms | 72.61 → 29.46 MiB |
| Roc + two Fledglings | 106.29 → 71.08 ms | 76.47 → 55.07 MiB |
| Four different casters | 50.35 → 46.74 ms | 34.19 → 34.26 MiB |
| Dragon + two supports | 67.72 → 62.16 ms | 45.19 → 45.25 MiB |
| Four different specialists | 86.70 → 79.76 ms | 58.88 → 58.97 MiB |

Repeated-creature savings held across all three pairs: approximately 39–40%, 62–64%, and 33% less construction time respectively. Distinct-family groups retain a small cache-metadata overhead. Native matrix installation also improves, but its single construction per case is less robust than the CPU repetitions.

The complete gameplay probe ends at the same 5,048 nodes on both builds and zero orphans. Static heap falls from 415.4 to 357.3 MiB (58.1 MiB); ObjectDB counts increase from 13,587 to 13,633 because shared data/weak-reference objects are explicit. This metric is Godot static heap, not OS RSS or VRAM.

### Selective animation submission

`CombatBoardView.set_combat_state` refreshes the full cutout roster for actor/visibility/death/reduced-motion changes, and otherwise updates only families with changed motion. Other persistent renderers continue their own idle processing. The reference test forces the original complete-roster route and compares renderer lifetimes, clips, facings, activity, and bone poses through movement, action-to-idle transitions, visibility changes, in-place commits, reduced motion, and death.

Final matched CPU submission medians:

| Submission | Base | Candidate |
| --- | ---: | ---: |
| Identical snapshot | 325.06 µs | 265.54 µs |
| Movement update | 598.32 µs | 534.66 µs |
| Effect progression | 417.78 µs | 357.41 µs |

The native matrix covers all 31 combat enemy actor IDs separately plus six small combinations. Each runs idle, walk, attack, and reduced-motion phases, 96 measured frames per phase, with four directions and assertions that intended clips and changing/frozen poses are actually exercised. Five mixed groups have real torch lighting. Player, illusions, surface effects, Umbra, and UI combinations are additionally covered by the gameplay probes. Screenshot replay occurs after all matrix timing.

Uncapped steady-frame results are mixed and do **not** establish a general FPS improvement. For example, specialist attack median/p95 changes 6.11/8.04 → 6.02/7.98 ms, while Roc-group attack p95 changes 6.02 → 8.32 ms. Both remain below 16.67 ms in those sampled phases. No quality setting was reduced to obtain construction or CPU gains.

### Save inspection and hand refreshes

Each save transaction decodes the existing live/backup files once, then shares that inspection between migration archival and recovery decisions. There is no cache across transactions. Temporary-file readback, archive copy/hash verification, crash recovery, and committed analytics boundaries remain intact. A 230,124-byte canonical save benchmark improves checkpoint cost 4.14 → 3.39 ms. Load cost changes 0.99 → 1.07 ms; load code is unchanged and no load-speed improvement is claimed.

Hand interaction updates previously triggered repeated hover-driven board/turn-order/tutorial refreshes while individual overlapping cards changed input state. Hover identity still updates immediately; expensive visual refreshes are coalesced until the hand reaches its final state. Animation-lock behavior remains preserved. Routed card selection, drag/cancel, card/board hover, abilities, targeting, and the trap/card-removal regression all pass native checks.

## Native combat results

These are rendered frame intervals in milliseconds, measured at `RenderingServer.frame_post_draw`. Each row is a full enemy turn with authored animations, not a synchronous simulation-only loop. Final state digests match the reference simulation and each other.

| Enemy turn | Median base → candidate | p95 | p99 | Max | >16.67 ms | >33.33 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Specialists | 8.35 → 8.36 | 9.03 → 8.59 | 17.97 → 16.81 | 51.90 → 48.17 | 29 → 21 | 2 → 2 |
| Split swarm | 8.36 → 8.36 | 9.07 → 9.23 | 17.90 → 16.66 | 55.17 → 51.21 | 33 → 22 | 2 → 2 |
| Dragon/support | 8.36 → 8.37 | 12.78 → 13.16 | 17.63 → 16.68 | 44.83 → 42.63 | 19 → 13 | 2 → 2 |

Idle median/p95 is effectively unchanged, 8.353/8.529 → 8.374/8.542 ms, with no frames over 16.67 ms. Enemy-turn median draw counts remain 1,024 / 1,084 / 945 respectively. The optimization removes CPU/data work rather than visible content or draw calls.

Coverage also includes seven routed card actions, six abilities, movement-pool use, twelve interaction groups (including zoom/pan and overlays), clear/pressing/eclipse Umbra states, elemental previews/chain paths/sparse feedback, and cold plus repeated dragon dissolves. Action results are mixed: Shadow Step max improves 78.02 → 71.16 ms, but Makeshift Tool max changes 38.27 → 41.93 ms. Do not describe all actions as faster. Repeated death p95 changes 9.024 → 8.872 ms with every authored dissolve update submitted and bounded nodes.

## Visual and regression proof

Fresh 1920×1080 images were inspected for populated idle gameplay, selected targeting, live fire impact, the post-trap hand, small mixed groups, and maximum-content effects. Actor/alpha order, shadows, effect density, health/status HUDs, card emphasis, controls, and edge placement remain intact.

- [Idle gameplay](proofs/performance-2026-09-17/images/runtime-native-candidate/dense_idle.png)
- [Selected targeting](proofs/performance-2026-09-17/images/runtime-native-candidate/wildfire_halo_preview.png)
- [Live fire impact](proofs/performance-2026-09-17/images/runtime-native-candidate/live_fire_impact.png)
- [Post-trap hand](proofs/performance-2026-09-17/images/runtime-native-candidate/ranged_trap_hand.png)
- [Mixed casters](proofs/performance-2026-09-17/images/matrix-native-candidate/mixed_casters.png)
- [Maximum-content effects](proofs/performance-2026-09-17/images/render-native-candidate/action_heavy.png)

The unlit melee matrix image is pixel-identical. Lit images differ in approximately 0.11% of channels around torch ember motes; those motes use `Time.get_ticks_msec()` independently of the fixture's frozen pose/lighting/ambient clocks. The image pairs and pixel measurements are retained, and are not presented as exact full-frame matches. Bone-transform equality is independently exact.

Validation: full Godot suite; pose equivalence; selective/full submission equivalence; shared-rig ownership/lifetime; save byte compatibility and recovery; surface save migration; surface parent review; committed save/resume boundary matrix; card draw/hand flow; eleven Python performance-tool tests. The full suite's ObjectDB-at-exit warning also occurs on the unchanged baseline; accepted native workloads report zero orphan nodes.

## Excluded evidence and remaining work

- Locked/unfocused or incorrectly sized early native attempts are invalid and not used in the comparison.
- A macOS background CPU-policy run hit the benchmark's ≥500 ms delivery-throttle guard despite retaining focus. It is excluded, not treated as a Deck simulation or compared against the normal CPU profile.
- The maximum-content benchmark's static-floor direct/cached spatial gate fails on both base and candidate: maximum channel error 2/255, mean about 0.006/255, changed-channel fraction about 0.0062–0.0064 versus the existing 0.002 gate. No threshold was relaxed and no static-cache production code changed. Freezing the complete child hierarchy fixes unrelated animation contamination; the Umbra ArrayMesh/MultiMesh equivalence then passes. The maximum-content image is inspected proof, but the overall failed report is not accepted performance evidence.
- The older runtime-integration probe fails obsolete legacy shadow/sprite assertions on the unchanged baseline. Its timings are excluded; current routed native combat and focused equivalence tests supply the relevant proof.
- The ordinary save/resume fixture contained pre-migration surface state and compared it to a repaired Continue state. It now starts from the same canonical repair; both baseline and candidate pass. Dedicated legacy-migration cases remain intact. The save microbenchmark likewise measures the current format instead of creating migration archives every iteration.
- Routed card clicks now wait for the visible hand fan and verify the actual GUI hit. The ranged-trap fixture now targets a tile within Pale Spark's current range. These corrections are identical on both measured builds.
- A shader experiment had no convincing matched benefit and was reverted. No shader changes ship.
- Remaining large CPU bursts include card playability/preview work, checkpoint serialization, durable analytics outbox/ack writes, and final UI refresh. This pass keeps those durability boundaries rather than trading away save safety. Their section diagnostics are preserved for follow-up.
- No actual Steam Deck/Linux/Proton run or GPU timing claim is made. Main-app Steam telemetry was not queried because reading its reporting credential lacked explicit authorization; no key was retrieved or persisted.

## Reproduce

Use an unlocked display, keep each native window foreground, and run performance jobs serially. Use a pinned baseline worktree with the same harness files. All Godot launches go through the task/visual runners used by `performance_pass.py`.

```sh
python3 tools/performance_pass.py run --task-id perf-cpu --benchmark cutout_cpu --benchmark combat_board_submission --output /tmp/perf-cpu.json
LABYRINTH_ANIMATION_MATRIX_UNCAPPED=1 python3 tools/performance_pass.py run --task-id perf-matrix --native --benchmark animation_matrix --timeout 300 --output /tmp/perf-matrix.json
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run --task-id perf-gameplay --native --benchmark runtime_frame --timeout 300 --output /tmp/perf-gameplay.json
python3 tools/performance_pass.py run --task-id perf-surfaces --native --benchmark surface_frame --output /tmp/perf-surfaces.json
python3 tools/performance_pass.py run --task-id perf-death --native --benchmark enemy_dissolve --output /tmp/perf-death.json
python3 tools/performance_pass.py compare /tmp/base.json /tmp/candidate.json
python3 tools/godot_task_runner.py --task-id perf-tests --stream -- godot --headless --path . --script tests/run_tests.gd
```

Comparison tooling rejects incompatible cases, workload/schema versions, viewport/backing dimensions, rendering conditions, CPU profiles, sample boundaries, and gameplay digests. Keep raw tails and threshold counts alongside median results.
