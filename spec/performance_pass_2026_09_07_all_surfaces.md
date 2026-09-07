# All-surface performance and behavior follow-up — 2026-09-07

**Artifact stage: completed measurements and behavior checks.** This report records the tested source snapshots and their limitations. The post-commit [inspection bundle](/tmp/labyrinth-deep-wide-third-proof/inspection-bundle.json) and [inspection guide](/tmp/labyrinth-deep-wide-third-proof/INSPECT.md) are the separate records for exact HEAD, peer-review disposition and verified fixtures. They are generated after commit; this report alone does not establish a reviewed commit or publication approval.

## Scope and comparison boundary

This third pass extends the [surface pass](performance_pass_2026_09_07.md) and [shop/reward/action follow-up](performance_pass_2026_09_07_flows.md). Its baseline is the existing local branch commit `89743fb0d471df0773171efc2e1e6dba79c5c303`, with the shared instrumentation and corrected workloads overlaid in `/tmp/deep-wide-third-pass-base`. The candidate is the continued task branch `codex/deep-wide-frame-pacing-performance-pass`. Earlier surface planning, generated card art, analytics batching and retained shop/hand gains are already in this baseline and are not counted again here.

Evidence is under `/tmp/labyrinth-deep-wide-third-proof` (abbreviated `P` below). Native captures use Apple M5 Pro, macOS 26.3.1, Godot 4.6.1 `14d19694e`, Metal Mobile, foreground 1920×1080 and 100% UI scale. Completed-draw intervals, synchronous input handlers, diagnostic CPU sections and total awaited completion are distinct measures. PNG capture and untimed reference/setup work sit outside sampled phases. GPU timestamps are unavailable; the stale Godot process monitor is not used as a substitute for measured gameplay CPU time. Inclusive sections overlap; only exclusive sections partition measured CPU work.

This is Mac evidence. The previous report calibrated process-local `taskpolicy -c background` to roughly 3.5–4× public-preview CPU cost; that is a limited scheduling stress condition, not Steam Deck hardware emulation. The targeted background combat pair and both complete background flow pairs are documented below. Actual Steam Deck/Linux/Windows, sustained GPU/thermal limits and fleet telemetry remain unmeasured.

The optimization contract preserves artwork, textures, effects, draw order, resolution, animation duration/cadence, legal actions and supported input routes. The pass corrects three exposed behavior bugs: distant floating-hit placement, victory-bank loss on settled resume, and Grimoire Clear retaining visible results.

Coverage includes 123 character/Grimoire/travel phases, 54 shop/reward/map phases, 35 remaining interaction/lifecycle phases, the complete normal combat matrix, public New/Continue startup and focused rendering/lifetime checks. Existing explicit regression tests cover dialogue progression, settings changes/default restoration, guided tutorial gates/reload/modal recovery, controller routing and menu replacement/cancellation. All major public screen families were audited; smaller paths have behavior coverage rather than a native timing for every possible interaction. The old card-upgrade route redirects to Skills, and the hidden legacy Burn pile is not exposed as a public control.

## Additional implementation and causal proof

- Board visual readers access the relevant authored scalar fields without expanding full enemy/NPC display definitions. Draw-tile indexing narrows per-tile unit lookup; body geometry is reused only while its texture, type and footprint agree. Changes to unit membership and draw-tile overrides rebuild the index. `metadata-{base,candidate}.log` covers 77 authored/legacy/missing-definition fixtures, seven batches of ten complete fixture sweeps, unchanged source catalogs and an identical semantic digest (`3392773`). Median CPU time per complete sweep falls **6.8918 → 0.3307 ms**. This is a batch-average CPU measure, not a frame percentile.
- Initial board assets are prepared in yielded slices before scene attachment. Ambient atlas packing reuses parent image readbacks, and retained layers share the prepared atlas/UV data. The transition waits for presentation readiness before reveal, restores input and owns detached-destination cleanup when cancelled. Reapplying unchanged window geometry avoids redundant native resize/reposition requests. Early `startup-base3.json` / `startup-candidate1.json` attribution records ambient packing **42.045 → 13.569 ms**; moving construction out of `_ready` alone is not a total-time saving claim. The later startup table measures the entire public route.
- `startup-assets3.json` checks all **56** source regions from **six** parent images, eight door frames and the native packed output against the original source pixels. The atlas SHA-256 is `a74efe1140574354c6e8139751a681711cd7b60bb42d90302522346fd9dbb55b`. `manifest-base-final.json` and `manifest-candidate-final.json` have exactly equal initial and full-roster manifests: 49 keys in each, including generated dimensions, pixels, atlas regions and frame metadata. Presented slices are **2 → 7**, with no semantic errors. The final manifest also verifies repeated preparation performs no extra slices and `_ready` retains exact generated-object identity. `board-submission-candidate-final.json` passes 157 retained layers and 180 presentation samples, including changed/removed/restored units, large footprints, shared depths and cleared draw-tile overrides. Retained layers share the owner’s exact atlas and matching region maps.
- The hand requests a playability summary when it needs only payable/playable and targeting flags, leaving complete previews for selection, hover and committed presentation. Summary and full-preview caches remain separate. Movement existence queries stop only after a target passes the required predicate; full plans still enumerate their complete legal routes. Committed Umbra knowledge, affordability, health costs, followups and multi-cell units retain their rules. The focused suite checks all authored cards in representative states, Flurry at 1/4/10/20 actions, hidden targets after Vision, Rubble budgets, safe targets after earlier rejected candidates, mutation isolation and invalidation. Existing Flurry shortcut timings are not a new gain in this pass.
- Grimoire retains an owned, query-independent normalized index while its unlocked catalog is unchanged, then returns independently mutable result entries. The result cache owns its arrays so Clear cannot empty a cached result. Typed result ordering remains exact. Skills retains its existing tree when changing character tabs, preserves authored navigation topology, rebinds external focus targets and avoids duplicate focus refreshes. Completion feasibility validates only until the same first authored priority/filler choice is known; the focused completion-equivalence suite retains the original algorithm as an oracle.
- Terrain placement computes articulation points once per placement round for connected floor graphs, instead of copying the blocker map and flood-filling once for every candidate. Disconnected and nonpassable-start inputs retain the original flood-fill predicate. Candidate iteration, score calls and RNG consumption remain in the original order. `focused-terrain-final.log` passes the independent original-predicate oracle across 470 complete layouts, 20 equipment/pre-battle contexts and 1,024 small graphs; complete room dictionaries and final RNG states match. Two separate static reviews found no remaining algorithm or portability issues. Final native pre-battle measurements follow below.
- Merchant stock partitions the same sorted authored catalogs once per operation. Shelf focus wiring reads the displayed offer rows instead of generating all stock again. The entire `stock-base.json` and `stock-candidate.json` reports are equal across **220** cases, including duplicates, partial/empty stocks, reservations and generated offers. The final normal routes and inspected native shop/reward captures are recorded below.

## Latest matched normal combat

Sources: `core-base-latest.json` and `core-candidate-latest.json`, workload `depth_13_live_run_interaction_matrix_v14`, schema 3. Both use the legal seven-card hand, depth 13, 16 relics and the same interaction matrix. Enemy outcome digests agree, semantic errors and unfocused observations are empty/zero, and no authored enemy frame is skipped. Final and repeated-install nodes are **4,041 on both sides**, with zero orphans. Static memory is **232,657,854 → 234,619,669 bytes** (+0.84%).

All frame times are milliseconds; threshold cells are count/sample count. This normal core pair precedes the later Skills-completion and terrain-generation edits. Those paths run outside its measured combat actions; the final full suite and separate final native route/background workloads cover the completed source. This pair is retained as combat evidence, not presented as a measurement of the later room-generation change.

| Workload | Median | p95 | p99 | Maximum | >16.67 ms | >33.33 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Populated idle | 8.378 → 8.368 | 8.619 → 8.557 | 8.664 → 8.614 | 8.700 → 8.673 | 0/150 → 0/150 | 0/150 → 0/150 |
| Seven card actions | 8.352 → 8.351 | 11.810 → 8.942 | 35.004 → 20.110 | 66.442 → 56.931 | 36/1537 → 19/1560 | 16/1537 → 10/1560 |
| Specialist enemy round | 8.367 → 8.375 | 8.639 → 8.591 | 16.031 → 12.286 | 42.131 → 34.500 | 14/1974 → 9/1978 | 2/1974 → 1/1978 |
| Swarm enemy round | 8.345 → 8.364 | 10.912 → 8.666 | 18.868 → 14.195 | 49.384 → 36.297 | 33/2397 → 14/2397 | 5/2397 → 1/2397 |
| Dragon/support round | 8.370 → 8.382 | 8.624 → 8.613 | 13.631 → 10.681 | 32.478 → 30.316 | 8/1103 → 4/1103 | 0/1103 → 0/1103 |

All seven card-action maxima improve in this pair, but several still exceed 33.33 ms:

| Card | p95 | p99 | Maximum | >33.33 ms |
| --- | ---: | ---: | ---: | ---: |
| Gust Step | 12.372 → 8.631 | 44.280 → 36.998 | 55.718 → 41.713 | 3/279 → 3/286 |
| Pale Spark | 8.744 → 8.582 | 43.786 → 32.853 | 47.266 → 44.068 | 2/165 → 1/165 |
| Shadow Step | 9.619 → 8.663 | 36.581 → 26.564 | 59.429 → 55.812 | 3/189 → 1/194 |
| Sidestep Slash | 11.751 → 8.629 | 37.616 → 28.216 | 53.339 → 44.025 | 2/197 → 1/195 |
| Threaded Path | 9.491 → 8.633 | 27.921 → 20.110 | 50.934 → 45.723 | 2/253 → 1/257 |
| Thunderline | 11.223 → 8.694 | 40.255 → 34.594 | 45.482 → 39.728 | 2/156 → 2/155 |
| Wildfire Halo | 14.972 → 11.266 | 29.016 → 17.451 | 66.442 → 56.931 | 2/298 → 1/308 |

Warm hover completion over 166 targets improves p95 **20.910 → 17.542 ms**, p99 **24.831 → 19.520 ms**, maximum **26.099 → 19.840 ms**. Cold hover p95 is **23.047 → 19.421 ms**, maximum **28.546 → 22.752 ms**. Seven initial selections remain expensive: median **29.123 → 27.600 ms**, maximum **43.263 → 42.151 ms**.

All six manual abilities complete their live choices and restore hand input. Candidate maxima are 27.433 ms Carry the Guard, 49.372 ms Encore, 30.194 ms Makeshift Tool, 47.217 ms Prismatic Instinct, 52.324 ms Quick Wits and 26.334 ms Rehearsed Escape. Makeshift Tool increases from **29.139 to 30.194 ms** in a five-frame sample; Prismatic Instinct has **4/51 → 5/52** frames above 16.67 ms despite its lower p95 and maximum. These mixed details preclude a universal per-action pacing claim. Specialists/swarm/dragon retain **54/38/48** authored frames, all rendered. Live-save Blink remains unavailable because no live save was supplied.

## Final targeted background scheduling comparison

The full normal matrix remains the broad frame-pacing proof. Longer background attempts lost focus, and one reduced attempt hit the existing ≥500 ms delivery-validity guard while measuring Shadow Step hovers. A separate enemy-only attempt also hit the guard in its always-run dense Blink preview setup. Those logs remain diagnostic records and are excluded from accepted comparisons; there is no accepted new background enemy-round pair. No guard was weakened. The final targeted pair uses the existing card/ability filters for **Shadow Step, Wildfire Halo, Quick Wits and Prismatic Instinct**, with the same seven-card hand, room and 16 relics on both sides. It therefore includes the card that triggered the failed attempt. Workload filters and process-local `taskpolicy -c background` are retained in each `*-command.json` receipt.

`targeted-actions-{base,candidate}-background-short.json` both pass with zero unfocused observations, pauses, throttle signatures and orphans. Both final/repeated node counts are **3,569**; static memory is **199,809,611 → 200,094,350 bytes** (+0.14%). They are a scheduling stress condition on the Mac, not Steam Deck results. Different presentation sample counts reflect the number of drawn frames during the same authored actions. Shadow Step renders all six authored frames on both sides. Under this scheduling stress, Wildfire renders **35 → 63 of 96** authored frames (skips **61 → 33**), with its unchanged 1,440 ms authored duration observed at **1,478.282 → 1,465.112 ms**. The improvement does not eliminate dropped effect frames on this host condition.

| Workload | Median interval ms | p95 ms | p99 ms | Maximum ms | >33.33 ms / samples |
| --- | ---: | ---: | ---: | ---: | ---: |
| Shadow Step | 34.059 → 10.967 | 144.149 → 31.352 | 256.252 → 115.762 | 256.252 → 232.063 | 25/47 → 5/123 |
| Wildfire Halo | 40.955 → 17.726 | 135.079 → 52.242 | 289.727 → 182.418 | 289.727 → 217.554 | 39/62 → 16/144 |
| Prismatic Instinct | 41.070 → 25.720 | 240.647 → 89.235 | 240.647 → 182.623 | 240.647 → 182.623 | 10/16 → 6/25 |
| Quick Wits | 48.111 → 16.272 | 247.771 → 128.940 | 247.771 → 218.517 | 247.771 → 218.517 | 11/16 → 7/31 |

Populated idle p95/maximum improves **35.532/41.378 → 21.887/26.266 ms** over 150 frames each. The same 61 warm hover operations have p95 **113.996 → 80.362 ms**, maximum **126.779 → 85.966 ms**. The remaining action maxima above 200 ms are material; this condition does not meet a 60 fps target despite its lower repeated work and frame tails.

## Final character, Grimoire and travel routes

Sources: `all-surface-base-final.json` and `all-surface-candidate-final.json`, workload `routed_character_grimoire_travel_campfire_treasure_v1`. Both contain the same **123** named phases and final workload source, including Skills reset-edge routes. They record zero semantic errors, unfocused observations and orphans. The baseline separately records six instances where Clear empties the input but retains visible results; the candidate has none. Clear is correctness coverage, not a same-output speed comparison.

The 49 typed-query phases cover exact, prefix, fuzzy/misspelled and no-result searches. Every typed result-ID list matches. Scoring CPU summed over those phases falls **449.539 → 127.467 ms**. The routed text-input handler mostly schedules later work and is not used as the scorer measurement.

| Workload | Median frame | p95 | p99 | Maximum | >16.67 / >20 / >33.33 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 49 typed-query phases, 294 frames each | 8.306 → 8.316 | 16.425 → 9.044 | 24.818 → 17.576 | 37.287 → 34.078 | 14/6/1 → 4/1/1 |
| Five repeated Skills openings, 120 frames each | 8.324 → 8.347 | 8.616 → 9.159 | 31.079 → 16.724 | 33.390 → 17.034 | 5/5/1 → 2/0/0 |

First Skills opening has handler **48.161 → 30.156 ms** and maximum **65.614 → 43.372 ms** over 24 frames. The five repeated handlers have median **14.280 → 7.097 ms**. Right-edge selection drops from **15.325 → 3.739 ms** in the handler and **22.426 → 9.008 ms** in the maximum drawn interval. Learning drops from **35.795 → 11.700 ms** in the handler and **43.687 → 19.576 ms** maximum; reset confirmation maximum is **17.856 → 14.115 ms**. Focus routes cover down/up between the selected tab and grid, the right edge, Reset and its disabled state. The cold opening still misses 33.33 ms, and two repeated-opening frames still miss 16.67 ms.

Travel uses live map input, staged room entry, equipment and Begin Battle. This final pair includes the terrain-connectivity optimization:

| Route | Handler ms | p99 frame ms | Maximum frame ms | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: |
| Combat room entry | 34.077 → 9.482 | 40.869 → 16.237 | 130.698 → 99.909 | 2/160 → 1/160 |
| Begin Battle | 70.049 → 41.570 | 15.490 → 17.296 | 131.429 → 88.995 | 1/289 → 1/290 |
| Equip weapon before battle | 67.168 → 37.220 | 82.004 → 51.443 | 82.004 → 51.443 | 1/90 → 1/90 |
| Campfire entry | 8.948 → 10.105 | 16.883 → 17.802 | 60.622 → 59.445 | 1/160 → 1/160 |
| Scavenger entry | 12.124 → 13.338 | 22.296 → 22.188 | 58.362 → 58.636 | 1/160 → 1/160 |
| Treasure entry | 13.867 → 13.263 | 21.070 → 18.844 | 38.630 → 38.313 | 1/160 → 1/160 |

Treasure claim maximum grows **22.411 → 25.001 ms**; campfire Strength maximum improves **48.365 → 40.745 ms**. Across all 123 phases, static memory is **280,233,932 → 291,675,328 bytes** (+4.08%), with zero orphans on both sides; this is a larger working set, not a memory-saving claim. Across 2,792 frames each, p99 improves **22.411 → 17.034 ms**, maximum **131.429 → 99.909 ms**, and counts above 16.67/20/33.33 ms fall **44/33/13 → 29/17/10**. Several sparse transitions remain much slower than a 16.67 ms frame budget.

The subsequent final focused pair (`prebattle-base-final.json`, `prebattle-candidate-final.json`) includes the terrain-connectivity implementation and identical source workloads. Engine preview CPU falls **48.207 → 20.113 ms** for entry and **43.359 → 16.615 ms** after equipment change. Entry handler drops **32.431 → 8.582 ms**, equip handler **65.734 → 39.963 ms**, and Begin handler **70.837 → 48.585 ms**. Their respective maximum completed-draw intervals are **137.170 → 121.318 ms**, **80.111 → 54.724 ms**, and **131.521 → 96.001 ms**. All focused semantic checks pass on both sides. These are substantial reductions in actual work, while first overlay construction and combat attachment still cause transition hitches.

## Final normal shop and reward routes

`flow-base-latest.json` and `flow-candidate-final.json` contain the same 54 routed phases and identical interaction semantics. Both pass with zero unfocused observations and orphans; repeated node counts are exactly `[3499, 3500, 3500]` on both sides. Final static memory is **204,245,393 → 204,464,496 bytes** (+0.11%). The final native shop-after-trades and revealed-reward captures were inspected at 1920×1080.

| Route | Handler ms | Maximum completed-draw interval ms |
| --- | ---: | ---: |
| Cold shop resume | 59.589 → 45.737 | 97.342 → 86.571 |
| Warm shop resume, second repeat | 39.001 → 23.847 | 56.988 → 39.304 |
| Cold armor inspection | 17.379 → 8.715 | 25.882 → 16.894 |
| Cold Grave Mortar inspection | 11.966 → 4.719 | 16.892 → 9.851 |
| Cold Nail Bomb inspection | 14.187 → 4.691 | 17.596 → 8.616 |
| Warm armor inspection, second repeat | 13.495 → 2.224 | 15.613 → 8.497 |
| Warm Grave Mortar inspection, second repeat | 12.330 → 0.673 | 14.885 → 8.462 |
| Cold buy | 22.925 → 19.178 | 35.788 → 28.563 |
| Cold sell | 5.859 → 4.581 | 32.431 → 19.693 |
| Warm buy, second repeat | 18.590 → 14.460 | 29.342 → 19.866 |
| Cold reward reveal | 21.613 → 20.547 | 55.483 → 54.159 |
| Cold reward heal | 10.730 → 12.237 | 25.387 → 30.209 |

The unchanged reward flow has mixed small differences, including the worse cold Heal sample above. Shop Leave also grows **7.273 → 7.348 ms** cold and **8.819 → 11.328 ms** on the second repeat; the first warm reopen maximum grows **26.254 → 28.924 ms**. These are retained in the report, rather than claiming every phase improves. Across 3,785 → 3,789 sampled frames, median stays **8.332 ms**, p95 is **8.786 → 8.726 ms**, p99 **15.150 → 9.851 ms** and maximum **97.342 → 86.571 ms**. Counts above 16.67/20/33.33 ms are **33/29/8 → 30/23/7**.

## Both matched background shop and reward pairs

The first pair is `flow-{base,candidate}-background-short.json`, run baseline then candidate. The reverse-order repeat is `flow-{base,candidate}-background-repeat.json`, run candidate then baseline. Despite the `short` filename, each contains the complete **54-phase** `live_shop_reward_map_v1` workload. All four match the workload/schema, renderer, viewport, scale, sample boundary and background profile. Within both pairs, interaction semantics are identical, semantic errors are empty, unfocused observations and orphan nodes are zero, and repeated live nodes are `[3499, 3499, 3499]`.

Static memory is **203,657,785 → 203,854,705 bytes** (+0.10%) in the first pair and **204,116,489 → 203,832,245 bytes** (−0.14%) in the repeat. Focus observations are 3,864 → 3,849 and 3,878 → 3,868 respectively. The command receipts preserve the same capped hand, flow-only flag and process-local `taskpolicy -c background`; all four exit successfully. A successful validity check does not make the timing result an improvement.

Every cell below is baseline → candidate, in milliseconds. Maximum drawn intervals retain the isolated transition hitches that a low p95 can hide. Warm 1 and Warm 2 are the first and second repeat within each process.

| Route | First pair handler | First pair maximum | Reverse-order handler | Reverse-order maximum |
| --- | ---: | ---: | ---: | ---: |
| Cold shop resume | 153.326 → 189.553 | 289.823 → 373.355 | 174.024 → 136.253 | 290.628 → 262.227 |
| Warm 1 shop resume | 145.860 → 75.357 | 225.424 → 147.859 | 112.438 → 66.493 | 168.246 → 113.482 |
| Warm 2 shop resume | 141.424 → 86.286 | 207.092 → 152.832 | 99.905 → 73.380 | 149.849 → 120.959 |
| Cold armor inspection | 31.413 → 13.447 | 47.270 → 42.569 | 34.826 → 8.468 | 61.237 → 27.886 |
| Warm 2 armor inspection | 35.325 → 13.492 | 46.949 → 17.485 | 27.876 → 4.335 | 33.617 → 10.978 |
| Cold buy | 62.972 → 56.695 | 101.374 → 94.964 | 59.329 → 41.975 | 96.344 → 68.301 |
| Warm 2 buy | 67.577 → 75.795 | 111.029 → 98.537 | 53.758 → 35.000 | 90.772 → 54.869 |
| Cold sell | 13.302 → 13.413 | 66.537 → 64.945 | 13.788 → 11.776 | 82.508 → 49.464 |
| Warm 2 sell | 18.209 → 14.322 | 96.773 → 42.157 | 13.119 → 9.448 | 72.791 → 38.333 |
| Cold shop reopen | 41.507 → 30.923 | 85.506 → 96.019 | 36.675 → 27.984 | 85.181 → 78.272 |
| Warm 2 shop reopen | 56.756 → 26.563 | 127.852 → 86.835 | 40.912 → 22.703 | 91.983 → 57.454 |
| Cold reward reveal | 47.368 → 59.127 | 129.215 → 181.355 | 49.806 → 46.193 | 131.126 → 123.756 |
| Warm 2 reward reveal | 41.702 → 47.134 | 112.755 → 230.567 | 31.970 → 35.877 | 97.760 → 87.761 |
| Cold reward claim | 3.136 → 3.077 | 95.676 → 104.759 | 2.010 → 3.442 | 62.915 → 89.365 |
| Warm 2 reward claim | 3.252 → 23.892 | 104.786 → 157.611 | 2.995 → 2.722 | 76.162 → 73.472 |
| Cold reward heal | 37.707 → 34.589 | 94.324 → 106.976 | 25.231 → 25.274 | 61.143 → 59.287 |
| Warm 2 reward heal | 35.803 → 82.323 | 84.088 → 140.725 | 29.413 → 22.396 | 72.830 → 64.876 |

| All 54 phases pooled | First pair | Reverse-order repeat |
| --- | ---: | ---: |
| Sampled frames | 3756 → 3741 | 3770 → 3760 |
| Median interval ms | 8.328 → 8.326 | 8.327 → 8.336 |
| p95 interval ms | 9.402 → 11.399 | 8.943 → 8.914 |
| p99 interval ms | 41.833 → 58.303 | 35.791 → 16.267 |
| Maximum interval ms | 289.823 → 373.355 | 290.628 → 262.227 |
| >16.67 / >20 / >33.33 ms frames | 57 / 50 / 40 → 113 / 89 / 57 | 46 / 42 / 40 → 36 / 33 / 29 |

The first candidate is materially worse overall: cold shop-resume handler grows **23.6%**, its maximum **28.8%**, and the count above 33.33 ms rises **40 → 57**. Its Warm 2 shop-resume p95 also grows **9.283 → 60.086 ms** despite the lower handler and maximum; Warm 2 heal has **1/30 → 4/30** frames above 33.33 ms. The reverse-order repeat improves the aggregate tail and cold resume, while both runs improve the warm shop-resume handlers and maxima. These differing results do not identify the cause of the first regression and do not justify discarding it or claiming a consistent cold-start improvement under this scheduling condition.

Cold reward claim remains a specific concern: its maximum worsens in both pairs. In the reverse-order pair its p99 grows **19.431 → 72.253 ms**, and frames above 33.33 ms increase **1/165 → 2/154**. The handler accounts for only a small part of that action boundary. Cold shop Leave also worsens in both pairs (**63.383 → 85.800 ms**, then **52.486 → 61.285 ms** maximum). These regressions remain part of the result; repeat-run variability alone is not causal proof or a resolution.

A focused attribution audit does not isolate a new CPU cause for the reward-claim tail. Normal cold-claim maximum is **29.549 → 27.534 ms**. In the background repeat, the candidate's 89.365 ms maximum is the first sampled interval, with no instrumented refresh and a 3.442 ms input handler; the later commit draw is **62.915 → 72.253 ms**, with measured CPU **19.990 → 22.815 ms**. All six cold-claim phases have zero pipeline compilations and viewport CPU below 1 ms; GPU timing is unavailable. The reward claim and refresh handlers are unchanged. This remains an unresolved background frame-delivery tail. The separate startup Metal stack sample does not explain the reward result.

## Public startup and the remaining ready-idle tail

The final matched normal pairs are `startup-{base,candidate}-new-final.json` and `startup-{base,candidate}-continue-final.json`. Both public menu routes check deterministic run/progression state, input lock/recovery and presentation readiness. Every run has zero semantic errors, unfocused observations and orphans. The measured startup begins at loading `main_menu.tscn`; the earlier Maker’s Seal splash has lifecycle/input coverage, not this timing measurement.

| New Run route | Baseline | Candidate |
| --- | ---: | ---: |
| Total completion | 2719.330 ms | 2051.761 ms |
| Sampled frames | 141 | 310 |
| Median / p95 / p99 interval | 8.312 / 9.303 / 558.728 ms | 3.783 / 9.307 / 39.019 ms |
| Maximum interval | 1001.790 ms | 303.348 ms |
| >16.67 / >20 / >33.33 ms frames | 3 / 2 / 2 | 6 / 5 / 4 |
| Scene attachment plus `_ready` | 388.224 ms | 167.811 ms |
| Separate yielded asset preparation | not staged | 278.560 ms |
| Ready-idle p95 / maximum, 90 frames | 8.723 / 8.890 ms | 31.016 / 33.523 ms |

Continue completes in **2764.546 → 1970.382 ms**, maximum interval **1004.470 → 305.592 ms**, p99 **567.929 → 19.325 ms** and 142 → 314 sampled frames. Its counts above 16.67/20/33.33 ms are **4/3/3 → 6/3/3**. Ready-idle p95/maximum changes from **8.798/8.998 → 24.093/32.877 ms**. Candidate preparation is 277.105 ms plus 166.327 ms scene attachment; those costs must not be omitted when interpreting `_ready`.

Total startup and the worst freeze improve, but the candidate has more individual budget misses and a worse ready-idle tail. Both final candidate ready-idle profiles again record no gameplay refresh work. The brief near-32 ms presentation waits occur before intervals settle near 8.33 ms; they remain a recorded regression, not a solved hitch.

The separate native `startup-ready.sample.txt` diagnostic finds **377 of 753** main-thread samples waiting for `CAMetalLayer nextDrawable` through its semaphore wait. Ready-idle instrumentation reports no gameplay refresh work or texture readbacks. PNG encoding in that stack sample belongs to the end screenshot outside the idle measurement. The diagnostic includes an intentional pause before timing and is excluded from matched performance claims. This supports a native presentation-wait explanation for the sampled tail; it neither measures GPU completion nor establishes that all ready-idle hitches are solved. The final public-route and asset-lifetime checks pass, while this presentation tail remains a platform-specific limitation.

## Behavior, rendering and broader surface coverage

Floating-hit placement now searches exact side-clearance lanes within one label width and caps vertical displacement near the struck actor (48 px solo, 96 px for a stack). Neighboring health bars therefore cannot push a hit onto an actor much farther below it. Candidate offsets remain cached throughout the animation. Normal arc scale/trajectory, reduced-motion stacking and text content retain their authored behavior. Repeated/clamped candidate lanes are evaluated only once.

`floating-base.log` demonstrates why the previous probe's PASS was insufficient: it checked existing animation behavior without the new target-proximity assertion. The current `floating-damage-portability-final.log` and `floating-collision-portability-final.log` pass the strengthened coverage, validating **19 damage and 20 collision captures**, all 1920×1080. `floating-final-geometry.json` records final glyph/target/offset geometry; the [capture manifest](/tmp/labyrinth-deep-wide-third-proof/final-capture-manifest.json) identifies the final PNGs and inspection receipts. Inspected examples include `enemy_arc_impact.png`, `reduced_motion_stack.png` and `loaded_toss_attack_draw_overlap.png`: damage remains associated with its actor, neighboring health stays legible, and overlapping draw/attack labels remain readable. Additional latest native captures were inspected for core Fire impact, Skills, Grimoire Fire search, prebattle equipment, large gear/magic inventories and the victory recap; their layouts and art scale remain coherent. Verified interactive fixture records belong to the post-commit [inspection bundle](/tmp/labyrinth-deep-wide-third-proof/inspection-bundle.json).

`remaining-candidate-source-final.json` passes **35** interaction and lifecycle phases: inventory equip/attunement drag and scrolling, pile open/close, settings/back/menu close, Curator claim/reservation, Embrace, victory and defeat, title returns and fresh runs. It checks persisted state and returns a valid final scene, **913** live nodes and zero orphans. Two terminal-resume phases call `_load_run_state` directly; the others use the exposed interaction controls and scene routes. This is candidate behavior coverage. The baseline `remaining-base-latest.log` exposes victory progression becoming **0 instead of the expected 94 Embers**, including repeated settled resumes. It is a failing baseline and cannot establish a valid whole-workload timing comparison.

Victory settlement now obtains its Ember amount before replacing the terminal result model and preserves already-banked progression on a settled resume. `recap-source-final.log` passes retry/resume, exactly-once result and discovery coverage. `main-menu-source-final.log` passes New/Continue/replacement and cancellation/input recovery, including normal and reduced motion. These standalone logs retain shutdown diagnostics: ObjectDB warnings, plus two resources in the recap process. They are distinct from the full-suite ownership result below. The affected additive local analytics semantics are documented in [analytics](analytics.md). No claim depends on silently ignoring the baseline bank-loss failure.

`focused-terrain-final.log` passes the summary, floating-text, Skills and terrain-equivalence suites; `focused-portability-final.log` passes the final focused check after the typed-array correction. `python-performance-final.log` passes all ten performance-comparison schema tests. The complete current-source and fresh baseline suites both pass (`full-source-final-verbose.log`, `full-base-final-verbose.log`). Their verbose comparison located 27 unchanged tests that never free their owned, detached board fixtures. Both retained the same 27 Controls and 14 named resources; preparing one combined image and 56 regions on seven of those boards exactly explained the candidate's extra seven dummy textures and 392 AtlasTextures.

The final test harness now frees each of those 27 owned boards at the end of its individual fixture. `full-clean-final-verbose.log` passes with **zero leaked Controls, textures, images, CanvasItem RIDs or named resources**. It retains only the pre-existing shutdown warning for three suspended function states, two tweens and two timers; no orphan sweep or production cleanup was added to hide leaked ownership. New summary fixtures also free all five scenes. Native lifecycle and repeated interaction probes separately assert zero orphans.

## Reproduction and artifact binding

Run native jobs serially through `tools/visual_probe_runner.py`; it invokes the task runner and isolates save/settings/screenshot storage. The commands below reproduce the named workload types; measured values vary with the host and scheduling. Preserve equal harness sources, imported resources, foreground state and CPU profile on both sides.

```bash
LABYRINTH_PERF_CPU_PROFILE=normal LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 \
  python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd \
  --project . --task-id third-core-normal --no-headless --display-driver macos \
  --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 \
  --timeout 300

LABYRINTH_PERF_CPU_PROFILE=normal LABYRINTH_RUNTIME_PERF_ALL_SURFACES_ONLY=1 \
  python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd \
  --project . --task-id third-all-surfaces --no-headless --display-driver macos \
  --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 \
  --timeout 120

LABYRINTH_PERF_CPU_PROFILE=normal LABYRINTH_RUNTIME_PERF_STARTUP_ONLY=1 \
  LABYRINTH_RUNTIME_PERF_STARTUP_MODE=new \
  python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd \
  --project . --task-id third-startup-new --no-headless --display-driver macos \
  --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 \
  --timeout 60

python3 tools/godot_task_runner.py --task-id third-metadata --stream -- \
  godot --headless --path . --script res://tests/board_visual_metadata_performance_benchmark.gd
```

Use `LABYRINTH_RUNTIME_PERF_FLOW_ONLY=1`, `LABYRINTH_RUNTIME_PERF_REMAINING_SURFACES_ONLY=1` or startup mode `continue` for the other routed workloads, in separate processes. Asset/manifest and floating probes use their named test scripts through the visual runner. JSON results are emitted on labeled result lines in each retained log; native PNG locations are recorded there. Background flow receipts use the following command shape, preserving their longer measured startup budget:

```bash
LABYRINTH_PERF_CPU_PROFILE=background LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 \
  LABYRINTH_RUNTIME_PERF_FLOW_ONLY=1 /usr/sbin/taskpolicy -c background \
  python3 tools/visual_probe_runner.py tests/runtime_frame_performance_benchmark.gd \
  --task-id third-flow-background --timeout 300 --expect-size 1920x1080 \
  --startup-timeout 48
```

The artifact assembly uses [final-harness-hashes.json](/tmp/labyrinth-deep-wide-third-proof/final-harness-hashes.json) for **33** final source hashes and **seven** identical final workload sources, [final-evidence-manifest.json](/tmp/labyrinth-deep-wide-third-proof/final-evidence-manifest.json) for **11** accepted pairs and **15** other checks with command receipts, [final-import-provenance.json](/tmp/labyrinth-deep-wide-third-proof/final-import-provenance.json) for **4,032 byte-identical imported files** in separate nonsymlink directories, and [final-capture-manifest.json](/tmp/labyrinth-deep-wide-third-proof/final-capture-manifest.json) for **73** validated 1920×1080 PNGs. The capture manifest marks **12 selected final images inspected again during closeout**; it does not claim that all 73 received that final visual inspection. Other representative renders were inspected during their runs. These records distinguish earlier causal measurements from the final source checks and preserve the excluded attempts.

The [inspection bundle](/tmp/labyrinth-deep-wide-third-proof/inspection-bundle.json) is generated after commit to bind the exact implementation HEAD, separate peer-review decision, source/evidence manifests and verified fixture receipts. [INSPECT.md](/tmp/labyrinth-deep-wide-third-proof/INSPECT.md) provides the corresponding interactive inspection steps. Until those records contain a reviewed HEAD and successful fixture verification, the measurement report must not be treated as that signoff. Publication requires the user's explicit approval of the reviewed commit; nothing in these performance results grants that approval.

Earlier failed/incomplete files remain diagnostic records only: `all-surface-base1.json`, `all-surface-candidate4.log`, `remaining-candidate.json`, `remaining-candidate2.json`, `flow-base-invalid-shadow-change.log`, and the failing remaining-surfaces baseline are excluded from accepted performance pairs. Older 116-phase all-surface reports are superseded by the current matching 123-phase pair even though the workload ID did not change.
