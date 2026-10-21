# spx-07 feedback 2 (director, 2026-10-21): code review of 31380ca38

Checkpoint 31380ca38 (your r1, committed by the director). The native director probe confirms the hover work: sweep max
frame ordinary 32.7 ms, air T2 22.1 ms, lightning T3 21.2 ms (integration 71/72/64). Fix the review's findings
(`/private/tmp/labyrinth_codex/review/spx-07-31380ca38.md`):

1. **Targeting budget: director decision.** I accept the measured floor and log the rest as follow-up perf-02. In
   `tests/spx07_hover_benchmark.gd`, set `TARGET_WORST_BUDGET_MS` to 40 ms; keep the 6 ms median and the 12 ms hover worst
   case. Add a one-line comment naming perf-02. No further targeting optimization in this round.
2. **Cached results share mutable data.** `intent_badges.gd` shallow copies share nested threat plans across focus
   results, and `board_path_draw_cache.gd` returns mutable cache entries. Every cache hit must hand the caller data it
   owns: deep copies, or recursive read-only data that callers never mutate (prove which). Add nested-mutation
   regressions: mutating a returned result, at any depth, never changes a later hit. Check every other cache added in
   this unit (combat_preview_memo, the exact-query, threat and catalog caches, tether_forecast) for the same hazard.
3. **Wind's hash shortcut returns stale previews.** `wind_view.gd` returns the cached forecast when `state.hash()`
   matches, before checking exact inputs. The reviewer reproduced a collision: with locked wind, moving the hero from
   (2,3) to (8,8) returned the earlier displacement path. Hashes are never proof of equality: validate exact, owned
   inputs on every hit (or drop the shortcut), and add the reviewer's collision case as a regression. Search the unit's
   other caches for any hash-only hit.
4. Remove the unused `_legacy_relax` parameter in `warband_room_rules.gd`.

Proof: the new regressions failing before and passing after; the 729-snapshot equivalence; the real-frame benchmark
(must stay within its budget after the copies in item 2); the targeting table under the new budget; warband, wind-lock,
orders, EN02/EN06 and Snare suites. Focused tests only, plus both full suites once at the end.
