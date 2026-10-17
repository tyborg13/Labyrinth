Reviewed HEAD `95b6dad2f609e06bd52aafa99b35bb1eb7fb2055` and the specified unit diff.

1. **Medium — structural retries are unbounded.** [section_map_graph.gd:194](/private/tmp/labyrinth_codex/review/map-02-95b6dad2f/scripts/section_map_graph.gd:194) uses `while true`, preventing the outer 50-attempt fallback from advancing when structural sampling cannot succeed. Forcing structural rejection timed out after five seconds without logging fallback; the trailing `return {}` is unreachable. **Fix:** cap structural proposals, handle exhaustion explicitly, and add a forced-rejection regression. [Reproduction log](/private/tmp/map-02-review-structural_rejection.log).

2. **Medium — required visual proof cannot be inspected.** [map_02_results.md:130](/private/tmp/labyrinth_codex/review/map-02-95b6dad2f/tests/map_02_results.md:130) leaves captures outstanding. The later director manifest reports success, but **all nine referenced PNGs are missing** here. **Fix:** preserve the nine captures and provide the independent UI judge result for this revision.

3. **Low — compatibility tests bypass revision dispatch.** [section_map_v5_suite.gd:51](/private/tmp/labyrinth_codex/review/map-02-95b6dad2f/tests/suites/section_map_v5_suite.gd:51) calls private legacy initializers directly. Forcing `initialize()` to ignore recorded revisions survives those hash checks. My independent dispatcher check catches it; the current dispatcher works. **Fix:** add explicit public-dispatch regressions for recorded revisions 3 and 4.

Fresh verification passed:

- Revision 3 and 4 hashes: 200 seeds each; revision-5 determinism and fog/Scout checks.
- Independent traversal of all 1,200 sections: route, type, section, fork, door, row and Graftwright constraints hold.
- Metrics exactly match the fixture: median 17 routes; 200 distinct canonical edge signatures per section index.
- Layout: zero ordinary or boss gap violations across 200 seeds × six sections.
- Nine-case probe setup, fail-fast guards, UI lint, and the formerly failing art-replay test.

Mutation results:

| Mutation | Outcome |
|---|---|
| Remove panel readiness guard, boss reservation, or final-column jitter guard | Caught |
| Remove jitter clamps | Focused contract survived; 200-seed layout caught 3,649 violations |
| Remove Scavenger/Graftwright eligibility guards | Caught |
| Remove Guardian-row pruning | 180-second timeout; assertion result inconclusive |
| Ignore recorded revision | Existing hash check survived; independent dispatcher check caught |
| Remove all probe readiness waits | Caught with clear setup error |
| Remove only probe defer/ready wait | Survived; two frame waits still provide readiness |
| Force type solver unsatisfiable | Exactly 50 failures, one logged fallback |

The map suite took **57.54 seconds at HEAD versus 56.60 seconds with base graph/suites**; both passed. The historical full Godot log reports 818.289 seconds against the 900-second budget. I did not rerun both complete suites or execute Windows.

Legacy assertions retain their breadth. No unsafe new typed-array reassignment, unrelated tunable, scope creep, or stray file was found. Every mutation was restored; the checkout is clean.

CHANGES REQUESTED