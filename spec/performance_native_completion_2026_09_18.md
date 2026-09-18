# Completed native combat validation — 18 September 2026

The previously pending native test has now run on the final runtime sources at `bfbbb2695600fc73b50075c4c47a39fed6c88f3a`. This phase continues from `365dc25bd28385a80e20b7925f96a115024b3f7f`, whose production is the earlier tracker cleanup. It adds measured reductions in enemy-route allocation, locked-hand capture/restore, repeated card-tree setup, procedural effect calculations, and profiler attribution work. All fourteen final native runs complete with zero focus violations and zero semantic errors.

**This does not establish hitch-free play or Steam Deck frame rates.** The tables below include the remaining isolated spikes and measurements that did not improve. The earlier pass made the larger action-latency gains; this follow-up closes the missing native validation and reduces several remaining costs, with mixed whole-frame results. No renderer resolution, MSAA, effect population, authored animation duration, persistence boundary, or input contract was reduced.

This report supersedes the pending-test status in the [earlier native checkpoint](performance_native_followup_2026_09_18.md). That report remains historical evidence for its own commits. The [new proof manifest](proofs/performance-2026-09-17/native-completion/manifest.json) binds accepted reports to the final runtime using recursive source hashes and archives raw distributions, logs, comparison output, images, and source guards. Candidate measurements were captured before committing and therefore retain HEAD 365dc25 plus dirty status; they are linked to this commit by content hashes, not by relabeling their recorded HEAD.

## Changes and isolated measurements

- Enemy route queries compute nearest footprint distance directly and reuse one owned hypothetical enemy dictionary during a search. They preserve route order, tie breaks, arbitrary footprints, sentinel behavior, RNG and state ownership. The isolated native enemy matrix reduced future-search CPU by 32–39%; maximum simulation slices fell from 12.75/19.84/16.73 ms to 11.37/15.44/13.83 ms across dragon support, specialists and swarm. Whole-frame tails did not consistently improve in that component pair.
- Locked-hand caching moves only the renderer canvas item to the retained target. Controls keep their actual parents, themes, and layout. This removes tree/theme work during capture and restore. In the isolated native pair, capture fell from 2.48–2.94 ms to 0.92–0.94 ms; restore from 2.92–3.28 ms to 0.58–0.67 ms. Pending fan layout is settled before capturing. Geometry, visibility, hierarchy, appearance and lifetime changes restore live rendering; animated cards and unsupported ancestor composition bypass caching.
- The existing two-card proxy pool retains hidden disabled controls in their stable combat FX host. Reuse restores geometry and state without tree re-entry. Mounting explicitly restores fresh launch sibling order, including equal-z overlapping cards leased from the LIFO pool. Other hosts and noncombat leases retain the previous detach behavior.
- Procedural FX retain exact float64 seed values in a fixed 8 KiB cache, reuse bounded seed-only rock coefficients for authored spell seeds, and hoist invariant bolt length. Arbitrary rubble seeds retain the original inline allocation path. The hash microbenchmark is faster, but the hash-only combat pair did not establish a meaningful whole-action improvement. Fire-pose caching experiments were reverted because the measured benefit was negligible.
- Surface abilities prepare optional hand/playability and forecast queries during their existing animation, then adopt them only after the original commit/save boundary and exact full-state equality. Partial or changed-state jobs use the synchronous fallback; the animation never waits for preparation. This targets the repeated Prismatic Instinct completion spike found by the final3 repetition. Removing proxy retention did not remove that spike in a separate isolation run.
- The phase partitioner detects properly nested intervals in one sorted scan and skips its general crossed-interval machinery in that case. The original general path remains for crossing spans. Frozen-reference comparisons cover complete outputs for 4,800 cases; nested microbenchmarks were about 19% faster. Instrumentation cadence and attribution semantics remain unchanged.

Component pairs are archived as diagnostics with their own intermediate source snapshots. Their numbers explain the specific work removed; the final-build frame results are only the final4 pairs below.

## Measurement conditions

Apple M5 Pro, macOS 26.3.1 arm64, Godot 4.6.1, Metal/mobile, production 4× MSAA, actual native 1920×1080 and 100% UI scale. Tests run serially in the foreground, without concurrent CPU regression suites. Frame intervals end at frame_post_draw. Each pair has matching workload, harness, instrumentation, warmup, motion setting and dimensions. GPU timers return zero and the texture-memory monitor returns an overflow sentinel; neither is interpreted as a real measurement.

The detailed full matrix includes the seven-card cap, varied specialist/dragon/swarm encounters, preview and hover interactions, all fixture cards, abilities, movement, enemy rounds, turn unlock, surfaces and overlapping effects. Focused normal-motion repeats reverse baseline/candidate order. A second reduced-motion pair also reverses order to investigate the first pair’s mixed tails. Reduced motion retains its authored static impact. Early depth-2 combat has five cards and three enemies; middle depth-7 combat has six cards, five enemies, relics, skills, illusion, surfaces, trap, loot and props. These smaller scenarios complement the heavy matrix. They are manually constructed performance fixtures, not complete generated playthroughs. In particular, the middle fixture injects four skills to exercise those combat paths; its Encore selection omits skill-tree prerequisites and is not a legal level-5 character build. Its enemy HP and the five/six-card workloads remain representative, but the loadout must not be interpreted as an exact naturally progressed character.

## Final native frame results

Values are milliseconds, before → after relative to the already optimized 365dc25 checkpoint. The comparison JSON retains medians, p95, p99, maximum, threshold misses, action duration, animation contracts, memory and node totals. Maxima are isolated samples and vary between repetitions; improvement in one subsystem does not imply every frame statistic improves.

### Early combat fixture

| Action / encounter | Worst frame (ms) | p95 (ms) | Frames >16.67 ms |
| --- | ---: | ---: | ---: |
| Glowstone Ward | 17.31 → 22.14 | 8.77 → 8.78 | 2 → 2 |
| Gust Step | 18.92 → 19.47 | 8.73 → 8.70 | 2 → 3 |
| Pale Spark | 27.17 → 26.02 | 8.71 → 8.69 | 1 → 2 |
| Sidestep Slash | 18.06 → 23.42 | 8.51 → 8.49 | 2 → 2 |
| Wildfire Halo | 27.61 → 24.57 | 8.73 → 8.65 | 1 → 2 |
| Specialists | 27.49 → 30.08 | 8.63 → 8.57 | 2 → 5 |

### Middle combat fixture

| Action / encounter | Worst frame (ms) | p95 (ms) | Frames >16.67 ms |
| --- | ---: | ---: | ---: |
| Glowstone Ward | 22.09 → 18.20 | 8.47 → 8.53 | 2 → 2 |
| Gust Step | 22.79 → 19.84 | 8.49 → 8.60 | 3 → 3 |
| Pale Spark | 36.44 → 32.05 | 8.46 → 8.52 | 2 → 1 |
| Shadow Step | 23.62 → 21.13 | 8.61 → 8.59 | 3 → 2 |
| Sidestep Slash | 23.80 → 18.76 | 9.99 → 9.46 | 3 → 2 |
| Wildfire Halo | 36.40 → 31.62 | 8.93 → 8.87 | 2 → 1 |
| Encore | 28.01 → 26.98 | 14.15 → 14.87 | 3 → 3 |
| Quick Wits | 41.10 → 39.82 | 16.41 → 15.02 | 4 → 4 |
| Specialists | 26.84 → 25.80 | 8.77 → 8.79 | 4 → 4 |

### Full matrix, detailed instrumentation

| Action / encounter | Worst frame (ms) | p95 (ms) | Frames >16.67 ms |
| --- | ---: | ---: | ---: |
| Gust Step | 26.24 → 21.05 | 8.57 → 10.90 | 3 → 4 |
| Pale Spark | 30.05 → 21.74 | 8.53 → 8.54 | 2 → 2 |
| Shadow Step | 35.85 → 30.99 | 8.59 → 8.58 | 2 → 2 |
| Sidestep Slash | 26.66 → 25.25 | 8.59 → 10.67 | 3 → 3 |
| Threaded Path | 36.33 → 31.64 | 11.75 → 12.52 | 3 → 3 |
| Thunderline | 30.83 → 22.86 | 8.70 → 8.59 | 2 → 2 |
| Wildfire Halo | 32.09 → 27.05 | 18.95 → 18.78 | 17 → 19 |
| Carry The Guard | 25.27 → 24.58 | 15.38 → 15.97 | 1 → 1 |
| Encore | 33.05 → 36.25 | 15.33 → 15.29 | 3 → 3 |
| Makeshift Tool | 24.23 → 24.26 | 18.77 → 19.00 | 2 → 2 |
| Prismatic Instinct | 37.83 → 32.10 | 15.53 → 15.02 | 2 → 1 |
| Quick Wits | 33.59 → 36.59 | 16.71 → 19.25 | 5 → 6 |
| Rehearsed Escape | 24.91 → 28.73 | 19.59 → 16.92 | 2 → 2 |
| Dragon Support | 36.13 → 35.12 | 12.42 → 12.48 | 7 → 6 |
| Specialists | 41.26 → 41.01 | 8.58 → 8.60 | 14 → 16 |
| Split Swarm | 41.80 → 41.92 | 8.57 → 8.57 | 12 → 11 |

### Focused repeats, normal motion

| Action | Baseline worst, two orders (ms) | Candidate worst, two orders (ms) | Baseline p95 | Candidate p95 |
| --- | ---: | ---: | ---: | ---: |
| Gust Step | 33.17, 26.39 | 29.94, 23.50 | 11.18, 10.75 | 10.56, 8.66 |
| Shadow Step | 42.57, 35.06 | 38.11, 30.46 | 8.56, 8.55 | 8.55, 8.58 |
| Wildfire Halo | 33.66, 28.98 | 30.68, 24.83 | 18.74, 19.78 | 18.34, 18.49 |
| Encore | 42.25, 40.07 | 39.01, 37.57 | 30.30, 30.28 | 30.31, 26.82 |
| Prismatic Instinct | 44.55, 36.59 | 38.92, 31.31 | 14.48, 14.48 | 14.95, 13.97 |
| Quick Wits | 37.69, 39.53 | 35.03, 35.59 | 22.36, 22.21 | 19.83, 18.52 |

### Reduced motion

| Action / encounter | Worst frame (ms) | p95 (ms) | Frames >16.67 ms |
| --- | ---: | ---: | ---: |
| Gust Step | 36.22 → 21.78 | 8.61 → 9.22 | 3 → 3 |
| Shadow Step | 42.64 → 34.84 | 8.66 → 8.66 | 4 → 3 |
| Wildfire Halo | 34.32 → 26.74 | 10.54 → 12.27 | 4 → 3 |
| Encore | 36.42 → 42.95 | 31.16 → 31.45 | 4 → 4 |
| Prismatic Instinct | 41.82 → 33.78 | 24.27 → 13.70 | 2 → 1 |
| Quick Wits | 34.52 → 39.27 | 21.06 → 21.87 | 6 → 6 |

### Reduced motion, reverse-order follow-up

| Action / encounter | Worst frame (ms) | p95 (ms) | Frames >16.67 ms |
| --- | ---: | ---: | ---: |
| Gust Step | 26.20 → 24.52 | 8.96 → 8.66 | 3 → 3 |
| Shadow Step | 35.48 → 31.01 | 8.65 → 8.65 | 2 → 2 |
| Wildfire Halo | 30.66 → 24.69 | 10.86 → 12.16 | 3 → 3 |
| Encore | 36.80 → 37.06 | 31.61 → 31.48 | 4 → 4 |
| Prismatic Instinct | 35.46 → 30.88 | 18.38 → 16.26 | 2 → 1 |
| Quick Wits | 34.83 → 37.51 | 20.60 → 19.45 | 6 → 6 |

## Remaining costs and interpretation

Action-completion and turn-transition spikes remain. Detailed traces attribute substantial CPU to hand/playability refresh, board submission and UI layout, plus synchronous durable checkpoint/analytics transactions. The heaviest overlapping Wildfire case also has sustained animation frames above 16.67 ms. These are known costs in the final data, not a promise that Deck play is already smooth. Profiling and optimizing storage further must preserve synchronous durability, recovery and acknowledgement boundaries; this phase does not skip saves or reuse prior-transaction inspections.

The reverse-order reduced-motion check confirms a small Wildfire p95 regression: 10.54/10.86 → 12.27/12.16 ms. It is not dismissed as noise. In those same runs, worst frames fall 34.32/30.66 → 26.74/24.69 ms, total action time falls 909/917 → 898/890 ms, and frames over 16.67 ms are 4/3 → 3/3. The p95 selects the sixth-slowest interval in these roughly 100-frame actions; raw samples place the candidate value at an early/late transition, while the sustained static-effect samples remain around 8–10 ms. This is an explicit tradeoff: lower severe transition peaks and shorter completion, with a 1.3–1.7 ms sub-budget p95 increase. The exact source of that small transition increase is not isolated; GPU counters cannot resolve it on this host. Reduced-motion Quick Wits also retains a worse maximum in both orders despite similar p95 and unchanged budget-miss counts.

The final comparison must be assessed alongside the earlier pass rather than treated as another across-the-board reduction. Several p95 values, missed-frame counts and maxima are flat or worse; all are retained above. A real Steam Deck foreground capture remains necessary to establish its frame budget, thermal behavior and GPU costs. The native Mac result closes the delayed validation, but cannot substitute for target-hardware evidence.

## Memory and lifecycle

- `render_buffer_memory_bytes`: 17,098,052 → 17,203,424 bytes (+105,372).
- `render_video_memory_bytes`: 639,401,984 → 645,054,464 bytes (+5,652,480).
- `static_memory_bytes`: 377,585,307 → 377,370,601 bytes (-214,706).
- `initial_nodes`: 4170 → 4170.
- `final_nodes`: 5049 → 5050.
- `repeated_install_nodes`: 5049 → 5050.
- `final_orphan_nodes`: 0 → 0.

The hand target remains one retained target per host; the proxy pool remains limited to two instances; procedural hash storage is fixed at 8 KiB and rock coefficients at 32 entries. Reported whole-process memory includes unrelated engine caches and differs between runs; it is not an isolated allocation cost. Host replacement, active/pending capture, hierarchy removal and scene teardown have explicit checks.

## Correctness and rendering proof

- Full Godot regression suite and fifteen focused checks pass on source-bound final files. Focused coverage includes route allocation, phase partitioning, FX hashes/cache bounds, proxy reuse/order, committed hand queries, hover coalescing, combat boundaries, forced movement, analytics context, profile normalization, save/resume recovery, surface analytics, surface presentation and card draw/hand flow.
- The actual surface-ability coroutine passes normal, reduced-motion and cancelled-preparation cases. Normal and reduced modes adopt seven prepared cards and one forecast; cancellation adopts nothing and uses the synchronous path. The old committed state is checked on every suspended animation frame. Disk state is checked immediately after scheduling and at completion; the final live and saved combat state match the complete engine result with existing analytics cursor staging. The guard checks termination; native action-duration evidence is separate.
- Route equivalence covers 13,800 comparisons, 990 plans and 495 complete turns across all 31 enemy types and authored intent variants. Complete state, RNG, logs, steps and ownership match a frozen reference. Some dense/large-footprint stress cases deliberately overlap actors; the full suite supplies coherent authored pathfinding and combat checks as well.
- Sixteen native image pairs cover all five elements, ground/impact/rear/front/release/travel, eight progress values, full/reduced motion, fractional positions/scales, ribbon edge cases, and rock seeds across negative/large and cache-boundary values. Twelve pairs are byte-identical; the remaining four differ by a single 8-bit step in at most two channels across 1920×1080. All 32 images are retained.
- Fresh native hand-cache proof covers content changes, three retained-target captures, fractional transforms, alpha-ancestor fallback, card tint/ancestor opacity, nested visibility, geometry changes, input locking, pending layout, overlapping captures, active and pending host deletion, hand detach/reattach, live animation bypass and scene teardown. Mutations restore before drawing. The cached snapshot contract covers current CardWidget refresh paths; arbitrary future nested renderer-only material/tint changes must participate in invalidation or bypass.
- The native card-flow probe covers opening and overlapping draws, settled authoritative handoff, reduced motion and real next-turn unlock. Representative images were inspected at 1920×1080; automated semantic checks accompany them.
- Enemy reference digests, step counts and activation counts match in every paired scenario. Authored animation durations/frame counts/run counts match wherever instrumented; actual skipped-frame counts remain in the comparison.

The first full suite in this phase caught three FX-cleanup failures. Nonproxy leftovers now detach synchronously; the motion regression counts an FX proxy as retired only when it belongs to the bounded pool, is hidden and has processing disabled. Unowned, visible or active ghosts still fail. The full suite was rerun after these corrections.
Pre-existing ObjectDB-at-exit warnings in scene-based probes and deliberate corrupt-save/failed-write messages in recovery tests are retained in logs. Invalid focus runs and superseded experiments are separately classified and excluded from final timing tables.

## Reproduce and inspect

The proof archive includes the exact serial run drivers and analysis. Invoke repository runners from the isolated task worktree. `run_final4_native.py` documents all environment settings; its local paths must be adjusted when reproduced elsewhere. `tools/performance_pass.py compare BASE CANDIDATE` checks pair compatibility.

The inspection fixture regenerates and verifies a separate pre-action combat save with ooze/droplets/gaoler, seven movement/attack cards and fire/ice/electrified surfaces. Its self-healing launcher is recorded in the final handoff. The branch remains local and unpublished pending user inspection and explicit publication approval.
