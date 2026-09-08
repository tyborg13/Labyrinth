# Shop, reward and action outlier follow-up — 2026-09-07

## Scope and measurement contract

This continues the [first pass](performance_pass_2026_09_07.md) after the request to include reward flows, the shop, previews, action animations, card plays, and a way to exercise weaker CPU conditions on the Mac. The follow-up baseline is the already reviewed first-pass commit `cd6dc8636c74653f6eaae23802445e95f9570584`, not the original master baseline. Improvements in this report are additional to the first pass.

Measurements use Apple M5 Pro, macOS 26.3.1, Godot 4.6.1 `14d19694e`, Metal Mobile, foreground 1920×1080 at 100% UI scale. Completed-draw frame intervals, synchronous input handlers and awaited animation completion are separate measures. GPU timestamps are unavailable here. No resolution, artwork, effects, animation cadence/duration, legal targets, rules or supported input path was reduced.

The new `live_shop_reward_map_v1` workload routes real viewport clicks, pointer motion and M/Escape keys through the live UI. Three cycles cover cold/warm merchant resume, four ware details, gear purchase, pack sale, leaving/reopening, map, victory/reward reveal, card hover/claim and healing. Currency, inventory, reward state, mode and HP are checked against untimed engine oracles. Resume is explicitly a saved-room load, not a measured map-travel transition. Every phase starts at a fresh completed draw after setup/reference work. PNG captures are outside measured phases. The two warm-cycle node counts are checked for equality after measurement; one-time cold setup can add nodes before the first warm cycle.

The full runtime matrix retains seven legal hand cards, six manual abilities and their choices, movement, Flurry, ranged-trap hand recovery, three enemy compositions with complete turn oracles, pile/character interactions and repeated scene installation. Live-save Blink remains skipped because no live save was supplied. The baseline received the identical shared harness/tooling plus the additive surface-flush timer only; its runtime optimizations remain at `cd6dc863`. Native source hashes and all raw reports are in `/tmp/labyrinth-deep-wide-followup-proof`. The final pairs are `base-final-{normal,background}-core.json` and `candidate-final-{normal,background}-core.json`. Export populated local imported resources; the same import files and sidecars were installed on both sides before these comparisons. Earlier pre-import core reports remain as intermediate evidence and are superseded here. This prevents faster imported music loading from being attributed to code changes.

## Changes and focused evidence

- Card elemental frames and role emblems previously ran pixel-by-pixel transforms on first display. A versioned generated resource stores 35 lossless raw PNG results plus 30 distinct imported frame variants, lazily decoding only the requested GPU texture. CardWidget fingerprints the actual source image, including dimensions, format, mipmaps and pixels, to select the exact matching variant. Source hashes and transform signatures reject stale local entries; missing/invalid artifacts or unknown import processing use the original algorithm. All 35 raw output dimensions and pixel digests match the unmodified baseline; the equivalence test checks every raw and imported output byte against fallback. Cold frame CPU median falls **26.929 → 1.891 ms**, maximum **32.628 → 5.771 ms**; emblem median **8.115 → 1.611 ms**, maximum **10.189 → 2.023 ms**. These are one first-use call per variant, not frame pacing percentiles; the first call includes resource loading. The generated compressed resource is **10,193,328 bytes (9.72 MiB)**. Regenerate with `tools/generate_card_presentation_cache.gd` after changing art or the transform; bump the documented algorithm signature for formula changes.
- Shop configure retains unchanged shelves, sell pages and identical detail cards. Affordability, exact missing-Ember tooltips, price/actions and focus still update. Removed offers retire their tweens; enabling reduced motion cancels emphasis on retained controls immediately. The dedicated retention test verifies paging, same-control identity, controller focus, affordability changes, reduced motion and bounded tween ownership.
- Hand refresh retains matching plain card subtrees in the live fan rather than detaching and reattaching every card after play/draw. Duplicate IDs are matched independently, and indices, display definitions and interaction pose are refreshed. Skill selection keeps its existing wrapper path. Tests cover reorder, draw, remove and duplicate cards without tree exits for retained slots.
- Relic icons remain mounted when only ability readiness changes. The utility controls and analytics reconciliation still refresh at their existing boundaries.
- A four-entry, owned-copy shortcut cache reuses identical hover/selection inputs. It includes committed knowledge, preview state/action/targets and other policy inputs; committed revisions clear it. Tests cover same-revision A/B/A changes, status/HP changes, hidden information, mutation isolation and capacity. A focused pre-import Sidestep Slash selection records six → three exact move simulations (18.2 → 9.8 ms cumulative), with its synchronous handler 19.407 → 7.761 ms; Shadow Step and Threaded Path also record equivalent-input hits.
- Noncombat visibility cleanup no longer recursively performs another entire UI refresh while already inside that refresh. Drag cancellation and hand recovery retain their public behavior.
- Surface analytics derives shared context once and appends the ordered batch at the same synchronous durable boundary. Stable event keys retain prefix-failure/retry deduplication, and the cursor advances only after success. A 49-event workload across seven trials falls from roughly **23 ms to 1.9 ms**, reducing **343 context derivations/single writes to seven derivations/batches**. Event order, tile payloads, rules versions, append-only storage and recovery semantics are unchanged; see [analytics](analytics.md).

## Matched normal shop/reward frames

Every cell is baseline → final candidate. Sparse transitions need maxima and threshold counts: a single hitch among idle animation frames may not move p95.

| Workload | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms / frames | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold/shop_resume | 8.356 → 8.323 | 8.606 → 8.919 | 147.109 → 92.543 | 147.109 → 92.543 | 2/45 → 1/45 | 1/45 → 1/45 |
| cold/shop_buy | 8.328 → 8.372 | 8.693 → 8.991 | 8.827 → 9.179 | 67.433 → 41.442 | 1/100 → 1/100 | 1/100 → 1/100 |
| cold/shop_sell | 8.320 → 8.359 | 8.767 → 8.814 | 63.423 → 33.175 | 63.423 → 33.175 | 1/80 → 1/80 | 1/80 → 0/80 |
| cold/shop_reopen | 8.358 → 8.347 | 10.372 → 8.671 | 66.408 → 38.100 | 66.408 → 38.100 | 1/24 → 1/24 | 1/24 → 1/24 |
| cold/reward_resume_reveal | 8.339 → 8.353 | 8.725 → 8.750 | 14.425 → 12.729 | 116.641 → 60.078 | 3/360 → 3/360 | 2/360 → 2/360 |
| cold/reward_claim | 8.341 → 8.316 | 8.699 → 8.744 | 11.962 → 13.130 | 38.625 → 39.276 | 1/165 → 1/167 | 1/165 → 1/167 |
| warm_2/shop_resume | 8.369 → 8.349 | 8.633 → 8.893 | 106.172 → 72.791 | 106.172 → 72.791 | 1/45 → 1/45 | 1/45 → 1/45 |
| warm_2/shop_buy | 8.329 → 8.340 | 8.716 → 8.607 | 8.796 → 8.869 | 60.037 → 36.636 | 1/100 → 1/100 | 1/100 → 1/100 |
| warm_2/shop_reopen | 8.313 → 8.369 | 8.624 → 8.759 | 71.111 → 46.477 | 71.111 → 46.477 | 1/24 → 1/24 | 1/24 → 1/24 |
| warm_2/reward_resume_reveal | 8.315 → 8.328 | 8.716 → 8.660 | 8.986 → 8.844 | 46.036 → 44.206 | 2/360 → 2/360 | 2/360 → 2/360 |

All 54 phases and their full tails are in `final-normal-all-flow-table.md`. Flow oracles pass with zero unfocused observations and zero orphans. Repeated-cycle nodes are **[3499, 3500, 3500] → [3500, 3500, 3500]**. Static memory is **238,112,013 → 252,991,069 bytes** (+14.88 MB, about 6.2%); combat similarly adds 15.22 MB. This is the measured cost of the bounded image and preview caches, not a memory reduction.

Cold saved-shop resume remains above a frame budget. The final candidate records 2.7 ms for music loading and 55.4 ms for the complete synchronous resume handler. It is a saved-room load, not a measured map-travel transition.

## Matched normal combat frames

| Workload | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms / frames | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| idle | 8.355 → 8.363 | 8.824 → 8.541 | 8.944 → 8.784 | 8.945 → 8.944 | 0/150 → 0/150 | 0/150 → 0/150 |
| action_play | 8.328 → 8.342 | 12.208 → 12.148 | 28.512 → 31.181 | 66.720 → 62.190 | 34/1555 → 31/1545 | 13/1555 → 12/1545 |
| action_matrix/gust_step | 8.310 → 8.310 | 12.370 → 11.622 | 44.962 → 47.494 | 51.721 → 51.969 | 6/286 → 7/287 | 3/286 → 3/287 |
| action_matrix/pale_spark | 8.314 → 8.366 | 11.333 → 9.218 | 43.510 → 44.656 | 60.582 → 48.298 | 4/166 → 2/164 | 2/166 → 2/164 |
| action_matrix/shadow_step | 8.313 → 8.333 | 10.383 → 13.395 | 28.549 → 32.713 | 66.720 → 61.984 | 4/190 → 5/188 | 1/190 → 1/188 |
| action_matrix/sidestep_slash | 8.328 → 8.314 | 11.818 → 12.722 | 26.838 → 35.152 | 56.421 → 47.613 | 5/196 → 4/195 | 1/196 → 2/195 |
| action_matrix/threaded_path | 8.311 → 8.345 | 11.610 → 9.672 | 28.512 → 31.617 | 60.686 → 57.509 | 5/255 → 4/253 | 2/255 → 1/253 |
| action_matrix/thunderline | 8.338 → 8.326 | 10.298 → 12.766 | 37.114 → 46.656 | 58.487 → 53.722 | 2/160 → 2/157 | 2/160 → 2/157 |
| action_matrix/wildfire_halo | 8.367 → 8.420 | 13.396 → 14.754 | 25.519 → 20.429 | 66.205 → 62.190 | 8/302 → 7/301 | 2/302 → 1/301 |
| enemy_round_matrix/dragon_support | 8.341 → 8.332 | 8.867 → 8.999 | 14.592 → 15.413 | 39.342 → 33.071 | 7/1081 → 10/1104 | 2/1081 → 0/1104 |
| enemy_round_matrix/specialists | 8.334 → 8.329 | 9.763 → 9.881 | 15.414 → 15.131 | 44.276 → 43.516 | 16/1967 → 17/1967 | 2/1967 → 2/1967 |
| enemy_round_matrix/split_swarm | 8.302 → 8.291 | 11.048 → 11.190 | 19.477 → 18.573 | 54.479 → 48.143 | 32/2389 → 28/2386 | 4/2389 → 4/2386 |

Aggregate card-action p95 is **12.208 → 12.148 ms**, p99 **28.512 → 31.181 ms**, maximum **66.720 → 62.190 ms**. Card-action pacing is mixed: aggregate p99 rises about 9.4% while the >33.33 ms count falls 13 → 12. Shadow Step, Sidestep Slash, Thunderline and Wildfire p95 rise as shown above. Individual card maxima rise for gust_step 51.721 → 51.969 ms. These samples do not establish a universal per-card pacing improvement; percentile changes, threshold counts and maxima can move independently with animation phase scheduling.

Warm hover completion p95 is **19.661 → 19.786 ms**, maximum **22.417 → 22.402 ms**. Initial card-selection maximum is **52.113 → 45.028 ms**.

All six abilities complete the same live choices and restore card input:

| Workload | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms / frames | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ability_action_matrix/carry_the_guard | 16.314 → 10.272 | 31.862 → 33.361 | 31.862 → 33.361 | 31.862 → 33.361 | 2/5 → 2/5 | 0/5 → 1/5 |
| ability_action_matrix/encore | 8.341 → 8.396 | 22.378 → 22.044 | 59.059 → 59.426 | 59.059 → 59.426 | 4/45 → 3/46 | 1/45 → 1/46 |
| ability_action_matrix/makeshift_tool | 12.459 → 14.299 | 29.975 → 31.961 | 29.975 → 31.961 | 29.975 → 31.961 | 1/5 → 1/5 | 0/5 → 0/5 |
| ability_action_matrix/prismatic_instinct | 8.325 → 8.314 | 19.422 → 20.743 | 56.317 → 53.326 | 56.317 → 53.326 | 4/51 → 4/50 | 1/51 → 1/50 |
| ability_action_matrix/quick_wits | 8.341 → 8.375 | 17.430 → 16.066 | 62.350 → 52.889 | 62.350 → 52.889 | 5/70 → 3/70 | 2/70 → 2/70 |
| ability_action_matrix/rehearsed_escape | 12.351 → 12.300 | 30.312 → 27.813 | 30.312 → 27.813 | 30.312 → 27.813 | 1/5 → 2/5 | 0/5 → 0/5 |

Enemy animation counters: specialists: 54 authored, 0 → 0 skipped; split_swarm: 38 authored, 0 → 0 skipped; dragon_support: 48 authored, 0 → 0 skipped. Authored cadence and duration are unchanged. Normal runs render every authored update. Runtime nodes remain **4041 → 4041**, with zero orphans and zero focus loss. Static memory is **212,545,886 → 227,770,468 bytes**. Full counters are in `final-normal-all-runtime-table.md`.

The remaining action-boundary cost includes hand/card-option previews and synchronous analytics/checkpoint work. Inclusive timers overlap and must not be summed. Independent audit found no safely removable durability save under the existing failure/recovery contract; speculative save removal is not part of this pass.

## Process-local slower CPU condition

`--cpu-profile background` wraps only the benchmark child process with macOS `/usr/sbin/taskpolicy -c background`; it does not alter system power settings or run competing stress processes. `normal` and `utility` are also supported, and comparisons reject mismatched profile metadata. The normal/utility/background calibration was interleaved twice on the unchanged follow-up baseline:

| Public preview CPU ms | Normal trials | Utility trials | Background trials |
| --- | ---: | ---: | ---: |
| Ranged | 1.497 / 1.482 | 1.477 / 1.474 | 5.413 / 6.009 |
| Chain | 4.798 / 4.800 | 4.832 / 4.857 | 18.800 / 17.301 |

Background therefore exposes roughly 3.5–4× CPU costs in these calibration cases; utility provides little useful slowdown here. The final native flow baseline also rises from 147 to 522 ms on cold shop resume and 67 to 195 ms on buying, confirming that foreground operation has not erased the stress condition.

This is a scheduling stress condition, not a hardware emulator. Apple documents that QoS affects scheduling and processor placement, and can also affect other resources/timers; see [Apple's performance guidance](https://developer.apple.com/documentation/apple-silicon/tuning-your-code-s-performance-for-apple-silicon) and [Apple silicon performance talk](https://developer.apple.com/videos/play/tech-talks/110147/). Inference: this can expose CPU-sensitive paths, but it cannot reproduce the Deck's x86 cores, GPU, memory bandwidth, drivers or thermal limits. This M5 Pro reports five Super and ten Performance cores, so it is not an “efficiency-cores-only” test.

Both complete final background reports pass compatibility and semantic checks. This is a separate pair under the same QoS profile and asset import state:

| Workload | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms / frames | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold/shop_resume | 8.354 → 8.393 | 9.118 → 14.234 | 522.402 → 343.943 | 522.402 → 343.943 | 2/45 → 2/45 | 1/45 → 1/45 |
| cold/shop_buy | 8.306 → 8.335 | 8.969 → 9.019 | 12.206 → 10.219 | 194.860 → 132.047 | 1/100 → 1/100 | 1/100 → 1/100 |
| cold/shop_sell | 8.351 → 8.403 | 9.047 → 9.088 | 147.417 → 96.545 | 147.417 → 96.545 | 2/80 → 2/80 | 1/80 → 1/80 |
| cold/shop_reopen | 8.321 → 8.340 | 11.434 → 18.548 | 185.267 → 108.750 | 185.267 → 108.750 | 1/24 → 2/24 | 1/24 → 1/24 |
| cold/reward_resume_reveal | 8.358 → 8.313 | 8.944 → 8.897 | 15.972 → 18.194 | 316.335 → 150.364 | 3/360 → 5/360 | 2/360 → 2/360 |
| cold/reward_claim | 8.305 → 8.333 | 9.242 → 9.339 | 28.412 → 18.729 | 83.483 → 89.418 | 3/159 → 4/160 | 1/159 → 1/160 |
| warm_2/shop_resume | 8.331 → 8.296 | 9.054 → 12.700 | 340.479 → 211.808 | 340.479 → 211.808 | 2/45 → 2/45 | 1/45 → 1/45 |
| warm_2/shop_buy | 8.319 → 8.338 | 9.148 → 9.202 | 12.384 → 10.536 | 169.262 → 128.908 | 1/100 → 1/100 | 1/100 → 1/100 |
| warm_2/shop_reopen | 8.189 → 8.273 | 18.905 → 18.511 | 168.303 → 113.768 | 168.303 → 113.768 | 2/24 → 2/24 | 1/24 → 1/24 |
| warm_2/reward_resume_reveal | 8.324 → 8.308 | 8.956 → 8.983 | 15.644 → 15.754 | 106.254 → 103.005 | 3/360 → 3/360 | 2/360 → 2/360 |

All 54 phases and their full tails are in `final-background-all-flow-table.md`. Flow oracles pass with zero unfocused observations and zero orphans. Repeated-cycle nodes are **[3500, 3502, 3502] → [3500, 3502, 3502]**. Static memory is **238,698,782 → 253,047,510 bytes**.

Cold saved-shop resume remains above a frame budget. The final candidate records 5.6 ms for music loading and 190.9 ms for the complete synchronous resume handler. It is a saved-room load, not a measured map-travel transition.

| Workload | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms / frames | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| idle | 17.027 → 9.549 | 32.944 → 28.554 | 35.714 → 34.730 | 39.212 → 34.947 | 77/150 → 58/150 | 7/150 → 3/150 |
| action_play | 24.107 → 23.402 | 72.223 → 69.754 | 177.886 → 185.442 | 268.295 → 230.346 | 393/572 → 387/584 | 155/572 → 158/584 |
| action_matrix/gust_step | 24.361 → 25.230 | 99.711 → 69.754 | 189.119 → 158.628 | 189.119 → 230.346 | 65/95 → 70/101 | 33/95 → 39/101 |
| action_matrix/pale_spark | 21.043 → 19.636 | 58.013 → 45.737 | 177.886 → 203.675 | 177.886 → 203.675 | 48/76 → 43/74 | 9/76 → 11/74 |
| action_matrix/shadow_step | 23.204 → 24.572 | 78.717 → 66.246 | 195.297 → 199.460 | 195.297 → 199.460 | 52/72 → 48/70 | 17/72 → 25/70 |
| action_matrix/sidestep_slash | 23.963 → 24.473 | 64.550 → 64.551 | 200.454 → 156.611 | 200.454 → 156.611 | 50/78 → 50/71 | 21/78 → 18/71 |
| action_matrix/threaded_path | 22.193 → 20.991 | 43.893 → 56.421 | 165.293 → 140.413 | 177.891 → 185.442 | 66/103 → 64/107 | 20/103 → 17/107 |
| action_matrix/thunderline | 24.303 → 18.842 | 84.731 → 59.625 | 177.310 → 186.832 | 177.310 → 186.832 | 41/57 → 38/67 | 22/57 → 16/67 |
| action_matrix/wildfire_halo | 27.750 → 28.517 | 79.829 → 75.499 | 268.295 → 193.557 | 268.295 → 193.557 | 71/91 → 74/94 | 33/91 → 32/94 |
| enemy_round_matrix/dragon_support | 11.475 → 10.098 | 33.898 → 29.897 | 73.113 → 65.513 | 142.528 → 141.965 | 275/636 → 263/699 | 34/636 → 21/699 |
| enemy_round_matrix/specialists | 15.671 → 14.257 | 38.610 → 40.088 | 78.589 → 76.722 | 169.915 → 147.510 | 466/971 → 466/1013 | 80/971 → 88/1013 |
| enemy_round_matrix/split_swarm | 25.241 → 24.293 | 68.232 → 65.878 | 117.963 → 102.357 | 175.758 → 150.545 | 554/823 → 551/852 | 230/823 → 228/852 |

Aggregate card-action p95 is **72.223 → 69.754 ms**, p99 **177.886 → 185.442 ms**, maximum **268.295 → 230.346 ms**. The complete table retains every card and ability, including regressions. Individual card maxima rise for gust_step 189.119 → 230.346 ms, pale_spark 177.886 → 203.675 ms, shadow_step 195.297 → 199.460 ms, threaded_path 177.891 → 185.442 ms, thunderline 177.310 → 186.832 ms. These samples do not establish a universal per-card pacing improvement; percentile changes, threshold counts and maxima can move independently with animation phase scheduling.

Warm hover completion p95 is **86.558 → 88.806 ms**, maximum **108.151 → 161.200 ms**. This is a material hover-tail regression in the stress pair, alongside the lower initial-selection maximum. Initial card-selection maximum is **243.635 → 185.074 ms**.

All six abilities complete the same live choices and restore card input:

| Workload | Median ms | p95 ms | p99 ms | Max ms | >16.67 ms / frames | >33.33 ms / frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ability_action_matrix/carry_the_guard | 46.333 → 49.102 | 120.557 → 141.653 | 120.557 → 141.653 | 120.557 → 141.653 | 5/5 → 5/5 | 4/5 → 3/5 |
| ability_action_matrix/encore | 21.999 → 26.463 | 145.718 → 131.124 | 165.213 → 169.044 | 165.213 → 169.044 | 13/20 → 13/21 | 7/20 → 7/21 |
| ability_action_matrix/makeshift_tool | 69.319 → 48.638 | 112.310 → 141.717 | 112.310 → 141.717 | 112.310 → 141.717 | 5/5 → 5/5 | 4/5 → 4/5 |
| ability_action_matrix/prismatic_instinct | 35.371 → 32.321 | 220.999 → 84.078 | 220.999 → 139.611 | 220.999 → 139.611 | 17/17 → 17/20 | 12/17 → 9/20 |
| ability_action_matrix/quick_wits | 26.071 → 20.084 | 173.744 → 148.905 | 185.610 → 176.544 | 185.610 → 176.544 | 19/28 → 18/32 | 8/28 → 6/32 |
| ability_action_matrix/rehearsed_escape | 55.311 → 46.626 | 122.382 → 123.361 | 122.382 → 123.361 | 122.382 → 123.361 | 5/5 → 5/5 | 4/5 → 3/5 |

Enemy animation counters: specialists: 54 authored, 21 → 22 skipped; split_swarm: 38 authored, 8 → 8 skipped; dragon_support: 48 authored, 18 → 15 skipped. Authored cadence and duration are unchanged. Both versions overload under this scheduling pressure; skipped updates are an observed limitation, not an intentional animation change. Runtime nodes remain **4041 → 4041**, with zero orphans and zero focus loss. Static memory is **211,376,675 → 226,445,734 bytes**. Full counters are in `final-background-all-runtime-table.md`.

## Broader checks, export and visual proof

The earlier normal pair, captured before the final imported-image cache extension, passes all nine other benchmark categories: surface CPU, simulation, runtime integration, trap idle, board submission, populated surface input, board-only rendering, reward animation and enemy dissolve. Complete compatible comparisons are in `normal-other-comparison.txt`.

| Native workload | Median ms | p95 ms | Max ms | >33.33 ms frames |
| --- | ---: | ---: | ---: | ---: |
| render/idle | 8.329 → 8.289 | 11.093 → 9.464 | 13.851 → 13.332 | 0 → 0 |
| render/interaction | 8.335 → 8.279 | 10.313 → 9.445 | 10.803 → 9.543 | 0 → 0 |
| render/movement | 8.291 → 8.308 | 9.632 → 9.391 | 17.497 → 12.919 | 0 → 0 |
| render/action_heavy | 8.302 → 8.297 | 12.147 → 10.761 | 20.423 → 20.619 | 0 → 0 |
| reward_animation/idle | 8.344 → 8.301 | 9.673 → 9.215 | 13.054 → 17.723 | 0 → 0 |
| reward_animation/victory | 8.338 → 8.367 | 8.748 → 8.903 | 25.037 → 27.111 | 0 → 0 |
| reward_animation/reward_reveal | 8.364 → 8.330 | 9.074 → 9.270 | 9.220 → 10.465 | 0 → 0 |
| enemy_dissolve/cold_death | 8.356 → 8.359 | 9.190 → 9.241 | 23.472 → 24.192 | 0 → 0 |
| enemy_dissolve/repeated_death | 8.352 → 8.362 | 9.245 → 9.513 | 16.870 → 19.789 | 0 → 0 |

These animation/render phases are largely unchanged, with some mixed maxima. In particular reward idle has one >16.67 ms frame in the candidate (maximum 17.723 ms versus 13.054 ms); no listed phase exceeds 33.33 ms. Cold/repeated dissolve retains all 28/112 authored updates without skips. Warm surface hover p95 remains close to the first-pass baseline: Chain 32.672 → 31.955 ms, Frostbolt 21.737 → 21.219 ms, Wildfire 25.106 → 25.292 ms, Updraft 21.295 → 21.326 ms. Updraft's nine-sample median shifts 13.569 → 20.419 ms; its unchanged p95/maximum and small sample do not support a further hover-pacing improvement. This follow-up primarily targets transition construction and selected-card/action work.

Additional matched CPU checks pass on both branches:

| Check | Baseline → candidate | Meaning |
| --- | ---: | --- |
| 165-room unchanged map submission | 350.37 → 344.87 µs | Same geometry/reachability and copy isolation |
| Stationary controller tick | 7.05 → 7.60 µs | No redundant stage refresh or dynamic redraw |
| Representative checkpoint | 5,471.12 → 5,477.29 µs | Byte-compatible transactional save, recovery and caller isolation |
| Representative save reload | 1,007.44 → 1,004.79 µs | Latest checkpoint and isolated copies |
| Button skin apply | 13.88 → 14.25 µs | 42 shared applied styles on both sides |
| Unchanged Grimoire sync | 1,957.0 → 1,915.4 µs | 192 entries and identical semantic digest |
| Telemetry sample median | 2.888 → 2.880 µs/frame | Append/flush and instrumentation checks |

These small CPU differences are effectively flat; no improvement claim depends on them. The Grimoire candidate counts and digest match; cursor and UI-style counters show bounded work. Telemetry flush with fake Steam stats remains about 2.1 ms. Real Steam fleet telemetry was not retrieved.

The final full Godot suite and focused cache, analytics, hand and shop regression checks pass; comparison tooling passes ten Python tests. The headless suite still reports 338 dummy-texture allocations and 14 resources held at shutdown after imports are populated; native workloads independently report zero orphan nodes and stable repeated-install counts. Fresh normal 1920×1080 captures have been inspected: shop after trades, revealed reward choices, dense idle, four card previews, dense Blink preview, ranged-trap hand recovery and active Fire impact. Cached art, selected lifts, targeting overlays, hand geometry, depth/transparency, HUD placement and feedback remain intact.

The native shop probe also passes controller focus, three granted-card pages, purchase, sale, pack pagination, reopening, affordability and reduced motion (13 captures). The hand-flow probe passes opening draws, overlapping draw animation, staged and authoritative handoff, reduced motion and next-turn unlock (17 captures). Inspected captures include controller focus, third gear card, unaffordable focus, reduced motion, opening hand, staged/authoritative/reduced-motion handoffs and restored next-turn input.

A full `Steam macOS` export-pack succeeds. An isolated empty-project process mounts that PCK after startup and verifies all 35 cached outputs against the actual packaged texture fallback, plus all 35 actual CardWidget frame/emblem paths. This caught Godot's alpha-edge import processing; the final cache supports both exact variants. It tests exported resources, not standalone application boot: the earlier `--main-pack` boot in an empty directory failed because the native GodotSteam library was outside the PCK. A complete platform app/Steam launch remains untested. Export-generated sidecars were restored to their pre-export contents; no source art was changed.

## Reproduction and limitations

Run matched processes serially with the same profile:

```bash
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run \
  --task-id followup-normal --native --benchmark ui_flow --benchmark runtime_frame \
  --cpu-profile normal --timeout 300 --output /tmp/followup-normal.json
LABYRINTH_RUNTIME_PERF_CAPPED_HAND=1 python3 tools/performance_pass.py run \
  --task-id followup-background --native --benchmark surface_cpu --benchmark ui_flow \
  --benchmark surface_frame --benchmark runtime_frame --cpu-profile background \
  --timeout 600 --output /tmp/followup-background.json
python3 tools/performance_pass.py compare /tmp/base.json /tmp/candidate.json
```

The background startup budget is separately 48 seconds, based on the measured approximately 4× CPU slowdown; the normal startup budget remains 12 seconds. The wrapper still uses the standard Godot/visual runners and task-local save namespaces.

Actual Steam Deck/Linux/Windows execution, sustained GPU limits, battery/thermal behavior and fleet telemetry remain unmeasured here. The Mac stress condition cannot certify performance on those platforms. The pass is prepared for user inspection; publication requires approval of the final reviewed commit.
