# rr-07 feedback 3 — invalid native ties use the ordinary pixel allowance

The director resolved `TODO_DESIGN_native_outer_uv_edge_policy`. A native
pixel that matches no legal in-range tie candidate remains one ordinary
changed pixel under the existing `1 + 0.01 * union_area` allowance. It is
never accepted as a matching out-of-range texel. `native_frame_matches` no
longer returns early for an invalid tie; selection leaves the deterministic
source pixel in place, so the existing difference count includes the mismatch.
No allowance value, frozen-frame check, 1/512 tie band, held-frame consistency
rule, shimmer residual rule, rig or authored motion changed.

## Reporting and retained regressions

Native shimmer reports retain the existing tie occupancy statistics and add:

- `parts[].invalid_ties.total.before/after`: counts for that view/part.
- `parts[].invalid_ties.frames[]`: frame ID and before/after counts for every
  captured frame, including zero counts. The loop-wrap comparison is not counted
  twice.
- `invalid_tie_totals.before/after`: totals over all view/part records.

CPU-only reports use `null` for these native-observation fields.

`tests/maquette_cutout/native_fixtures/rr07_edge_manifest.json` binds the original
Thrall rear/seam_upper_near_fore_near/65 before/after PNGs, source PNG, matrices
and hashes. Before pixel `(193,252)` is transparent and every in-range candidate
is opaque. It remains an invalid tie and counts as exactly one changed pixel;
the frame passes. The after surface matches and has no invalid ties. The
reporting regression replays this fixture and checks the exact per-part/frame
count, including the wrap safeguard.

The rr-05 12×12 row/column erasure still produces 23 invalid ties and 23 changed
pixels, and fails. A 2×2 synthetic part passes with one invalid tie and fails
with two: the unchanged allowance is 1.04, permitting one whole changed pixel.
Existing held-flip, in-range candidate, sub-texel, 0.01-texel rejection and
capture-binding regressions remain in the focused suite.

## Proof for the design owner

After the retained native re-gates pass, both review stages remain director-owned:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-07
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh hoarfrost_seer --from-review
sh experiments/cutouts/hoarfrost_seer/rr07_proof.sh arc_thrall --from-review
python3 tools/process_board_density.py --check
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
```

The existing resume mode performs review MP4, native density rest rebake,
rest recording, density sealing, shadow-cache refresh, native production capture
and production gate. It skips rest/motion sampling and native recapture. Exact
expanded commands remain in `../feedback2/resume_plan.json`; all windowed
commands use the existing visual runner and proof contracts. No windowed run,
MP4 composition, peer review, commit or publication is performed by the worker.

## TODO_DESIGN and chosen defaults

No active TODO_DESIGN for this policy. The original feedback-2 failure/placeholder
is preserved as historical evidence; this director decision supersedes it.
The only new chosen value is test-only `SYNTHETIC_SMALL_PART_SIZE = 2`; its
3×3 destination bounds are derived as size + 1. Allowances and all rendering
values come from the existing approved rule and source/capture data.

## Observed proof

```text
Ran 21 tests in 1.212s
OK
Ran 172 tests in 236.897s
OK (skipped=2)
RR07 NATIVE GATES: PASS (hoarfrost_seer; 0 errors)
RR07 NATIVE GATES: PASS (arc_thrall; 0 errors)
RR07 RUNTIME: PASS (120088 checks, 0 failures; headless logic only)
FULL SUITE RUNTIME: 418.548 seconds (budget 900 seconds)
TEST RESULT: PASS
Ran 839 tests in 737.306s
FAILED (failures=1, skipped=63)
```

`native_summary.json` records Seer invalid ties before/after `0/0` and Thrall
`1/0`; the only nonzero row is rear/seam_upper_near_fore_near/65 before. Both
presented held and boundary residual totals are zero. `verification_after.json`
and each case's `proof/native/verification.json` contain all per-part/frame
counts. Current certificate bindings and all fourteen original manifest/rest
hashes were checked after the gates; native gates also validate captured PNG
hashes. No capture or input manifest was rewritten.

The full Python suite's sole failure is
`test_shipped_derivations_and_manifest_are_current`: the front/rear native rest
records for both rr-07 production rigs remain missing, as expected before the
director's windowed rebake. No assertion was changed to conceal this failure
and no rest record was fabricated. Full logs are retained in this folder and
the Thrall feedback-3 folder. `results.json` maps every feedback requirement to
observed evidence; `files.json` lists this feedback's changes. The final
ownership audit passed after the full suite cleaned up its temporary checkouts.
