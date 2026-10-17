# fix-05 — Section map revision 5 can freeze New Game (unbounded type-assignment search)

## Header
- A peer review found that seed `1792271957` keeps the revision 5 generator in Section II type assignment
  (`scripts/section_map_graph.gd:287`) for more than 300 s: 671,000+ search nodes. Revision 4 generated the same run
  in 1.74 s. Generation runs synchronously at New Game, so the game would hang.
  - Trace: `/private/tmp/flow-01-review-seed-trace.log`.
  - Review: `spec/peer_benchmark/feedback/flow-01_review_63c1f11ba.md`, finding 1.
- map-02's tests covered seeds 1–200, but real runs use 32-bit seeds.
- Base `codex/peer-benchmark`; map-02 is merged at dd4e67d43. Owned: `scripts/section_map_graph.gd` (revision 5 path
  only), `tools/section_map_variety.gd`, the section-map tests and suites, and a new performance regression.

## Change
1. **Root cause.** Instrument the search on this seed. Report node counts, the constraint causing the blow-up, and why
   the structural pre-checks don't prune it.
2. **Bound the search, deterministically.**
   - Give each topology attempt a type-assignment node budget, chosen so one attempt stays well under 50 ms on this
     machine.
   - Improve pruning: most-constrained-first variable ordering, forward checking of per-route and section counts, and
     memoising failed partial assignments.
   - On budget exhaustion, re-roll the topology. Re-rolls count toward the existing 50-attempt cap and the logged
     fallback.
   - Same seed, same graph.
3. **Keep everything else.**
   - Revisions 3 and 4 stay byte-identical.
   - Revision 5 may produce different graphs for some seeds, but the map-02 acceptance metrics must still pass on
     seeds 1–200 (fallback ≤ 1%, distinct topologies ≥ 95%, median routes 12–40, the ≥ 4-node row and long divergence,
     type frequencies ±3 points, and all route/section constraints at 100%).
   - Regenerate the metrics fixture and report the before/after table.
4. **Performance regression.** Over 2,000 random 32-bit seeds (fixed list, committed) × 6 sections, including
   `1792271957`:
   - every section generates in ≤ 250 ms;
   - every full run's map generation takes ≤ 1.0 s on this machine;
   - the fallback is used in ≤ 1% of sections.

   Put the 2,000-seed sweep in a tool or program. Put `1792271957` plus the 20 slowest seeds from the sweep into the
   committed suite as a fast regression.

## Proof
- The sweep table: max, p99 and mean ms per section; fallback rate.
- The map-02 metrics re-run.
- The full Godot suite (parallel runner) and the Python suite.
