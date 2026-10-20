# cap-01 feedback 3

This supersedes feedback 2's phase matching for looping clips and its fatal
aggregate performance target. Capture writers, frame storage, renderer bindings,
canonical gates, thresholds and existing capture evidence are unchanged. The
director-approved encoder remains lossless WebP. Changes are uncommitted.

## Requirements and implementation

1. `capture_production.py` reads each compiled clip's `loop` flag. Looping clips
   require identical nonempty sets of distinct renderer `pixels_sha256` values
   per capture view. Frame order, phase and sample frequency do not affect that
   comparison. When the flag is absent, `idle` uses the looping rule; an explicit
   `loop: false` retains phase matching. The report includes both pose sets and
   frame counts for every view. Non-looping clips retain occurrence-preserving
   phase matching, identical matched hashes, the two-unmatched-per-side limit
   across views, and the full list of unmatched frames. Missing hashes or empty
   loop captures fail.
2. `capture_director.py` writes and prints per-run seconds, decimal GB and an
   advisory target result, plus each rig's aggregate seconds and GB. The
   existing 480-second and 1-GB targets apply separately to each production run.
   Mortar's two runs are not evaluated as a single run. Performance misses do
   not change the exit status of a valid `after` capture. Capture/manifest errors
   remain fatal, and gate failures remain comparable evidence.
3. The existing `/tmp/cap01-proof/before` and `/tmp/cap01-proof/after-r2` captures
   are readable in this sandbox. The command below compares them without
   recapturing. No windowed command, benchmark, full suite, peer review, commit
   or publication was run in this round.

## Focused proof

```sh
python3 -m unittest discover -s tests -p 'test_capture*.py' -v
```

Observed: `Ran 35 tests in 7.478s` / `OK`.
Log: `/tmp/cap01-feedback3-focused.log`.

Loop regressions cover reordered/resampled identical poses, missing/extra/changed
poses, per-view equality rather than union equality, explicit loop flags, idle
fallback, explicit non-looping idle, empty captures and missing hashes. Existing
non-looping hash/phase/count regressions still pass. Performance regressions cover
rig totals, independent per-run checks, advisory size misses and `after` returning
zero after a validated capture exceeds the time target.

Stored director timings were passed through the new reporting helper into a
separate folder, preserving the original performance file. This is a report of
existing measurements, not a new benchmark:

| Production capture | Seconds | GB | Advisory per-run target |
| --- | ---: | ---: | --- |
| Seer front | 255.563 | 0.577917 | PASS |
| Mortar front | 274.511 | 0.648592 | PASS |
| Mortar rear | 277.700 | 0.679159 | PASS |
| Mortar aggregate (two runs) | 552.211 | 1.327751 | Informational |

Observed: `STORED PERFORMANCE REPORT: PASS; /tmp/cap01-feedback3-performance/capture_performance.json`.
Log: `/tmp/cap01-feedback3-performance.log`.

## Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/cap-01`:

```sh
python3 tools/capture_director.py compare --before /tmp/cap01-proof/before --after /tmp/cap01-proof/after-r2 --output /tmp/cap01-proof/equivalence-r3.json
```

Observed: `CAPTURE EQUIVALENCE: PASS` (exit 0).
Report: `/tmp/cap01-proof/equivalence-r3.json`.
Log: `/tmp/cap01-feedback3-compare.log`.

All 20 artifact checks pass: 11 gate/diagnostic/exit JSON records, five native
capture comparisons and four reels with exact decoded frames and no tolerance.
Both production comparisons also pass, including all 4,320 non-looping matched
renderer hashes (1,390 Seer, 2,930 Mortar), with zero unmatched frames on either
side. Seer front, Mortar front and Mortar rear idle each have the same three
distinct pose hashes before and after, sampled 50 times per view in both runs.

Existing canonical failures remain identical: Seer native has 31 errors and
exit 1; Mortar production has one `rear: missing production walk samples` error
and exit 1. Seer production and Mortar native have no errors and exit 0. These
are retained gate evidence, not new cap-01 failures.

No recapture or inspection fixture is required for these tool-only changes.

## Files and design boundaries

- `tools/capture_production.py`: looping pose-set comparison.
- `tools/capture_director.py`: advisory per-run and aggregate reporting.
- `tests/test_capture_production.py`: looping regressions.
- `tests/test_capture_director.py`: performance reporting and exit regressions.
- `spec/peer_benchmark/humanoid_cutout_rig.md`: proof paragraph updated.
- `tests/maquette_cutout/cap01_feedback3_proof.md`: this handoff.

TODO_DESIGN placeholders: none. Chosen defaults: none; the named performance
constants preserve the existing thresholds. Added fixture values are test-only.
Open issues: no new issues; the unchanged canonical gate failures above remain.
