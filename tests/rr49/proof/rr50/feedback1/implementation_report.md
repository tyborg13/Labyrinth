# rr-50 feedback 1: immutable timing and provenance guards

Approved/runtime HEAD: `c78b9f7f68cc52880a6e74d805983a698999c1b6`.
All changes remain uncommitted. No preflight, commit, peer review, queue edit,
publication, editor/import scan or windowed run was performed. No full suite
was run this round, as directed. All engine invocations use the existing task
runners; production runtime bytes remain at the approved revision.

## 1. Independent optimized reference

The frozen fixture `tests/rr49/fixtures/optimized_c78b9f7f6/` contains exact Git
copies of the approved `stable_paint.gd` and `stable_skin.gd`. Its `motion.gd`
contains only the approved Git `motion.point` function under a RefCounted header;
that helper is idle-only and never runs in this motion benchmark. It closes the
reference's import graph without loading any live production helper. No source
rewrite or live optimized implementation supplies the reference.

`reference_submission.gd` independently pins all three fixture SHA-256 hashes.
The Python fixture guard also compares each with its immutable Git source or
exact function extraction from the same approved revision. The editable fixture
manifest does not confer approval. Frozen source inputs have a scoped `.gdignore`;
the loader's explicit script preloads work headless and need no editor scan.

`paired_cost.gd` interleaves production, its live generic fallback, and frozen
paint+skin at each identical motion pose, with every cache disabled. Reversing
and rotating the three positions balances execution order across three rounds.
Each view measures 1,071 matched poses per implementation (7 clips x 51 poses x
3 rounds); authored pose work is outside every submission timing window.
The production/fallback speedup must remain >=1.6. Production must remain
within 1.3x the frozen reference at P90 of the same-pose ratios. Both thresholds
are independent of the unchanged 2.0 absolute timing headroom. Median factors
and raw median costs remain in each JSON row for inspection.

The first implementation used a median reference ratio and exposed the exact
boundary problem during negative controls: the 30% mutation passed at
1.29545 / 1.29510. Those failed results remain in `python-focused/`. P90 is the
named proof-only choice that checks slower submissions without making one
scheduler interruption decisive; it changes no production tuning or threshold.
`python-focused-final/` records the succeeding P90 trial. `python-final/` is the
final validation after making the reference import graph fully self-contained.

All three exact reviewer timing patches are applied only to isolated temporary
projects: proportional 30% delay, partial fast-path removal, and disabled fast
paths. Each must fail a specific relevant guard component in both views, not
just fail because of a parser error or unrelated timing budget. New controls
require the immutable-reference rejection for the first two patches and the
fallback rejection for the third. Reviewer patches/results are retained in
`reviewer/`; originals are unchanged.

## 2. Immutable approved after-hashes

`runtime_provenance.py` computes every after-hash from
`git show c78b9f7f6:<path>` and requires the editable manifest's after-hash to
match it before checking live bytes and serialized poses. Existing before-hash
binding to `6135c6ec6` and the complete historical rest-report seal remain intact.
Neither runtime file nor the existing provenance manifest changes this round.

The new test in `test_rr41_feedback3.ForgedManifestTests` drives the actual
rest-seal call site with freshly exported Godot poses. For each protected runtime
file separately, a temporary copy receives a comment and a manifest after-hash
matching that modified source. The test verifies that the fresh pose document
really names the modified source, then requires `Forged rr-50 approved binding`.
It also verifies the complete clean historical report still normalizes exactly.
No live runtime file is temporarily modified.

The in-memory negative control in `approval-guard-disabled.log` restores the
old vulnerable helper from the approved Git revision. Both attacks then survive
and the new real-call-site test fails twice with `ValueError not raised` and
zero errors. The driver exits 0 only for those exact expected failures. This
proves the test catches removal of the new after-binding check at the real hook.

## Focused proof and results

- `provenance-focused.log`: `Ran 4 tests in 30.458s`, `OK`; both actual forged-after
  controls, clean historical normalization, existing fix-18 membership control,
  exact runtime pins and immutable fixture binding pass.
- `approval-guard-disabled.log`: `RR50 APPROVAL-GUARD MUTATION: PASS` (old helper
  survives both attacks; new assertions fail twice, zero errors).
- `timing-mutations-p90.log`: `Ran 1 test in 93.835s`, `OK`, covering all three
  timing negative controls with P90 before the parse-only dependency seal.
- `isolation-audit.log`: `ISOLATION AUDIT: 263 modules`, exit 0. No new Python
  test module or shared write resource was introduced. The existing Gaoler and
  Lancer declarations still cover their respective tests; mutations write only
  private temporary projects/manifests.
- `registration-audit.log`: `TEST REGISTRATION AUDIT: PASS (916 scripts; full suite=549, quarantined=29, windowed probe=338)`.
- Final focused parallel-runner result (`python-final/`):

```text
Ran 9 tests in 246.016s
OK
RR50 CLEAN TIMING: PASS (5/5 paired and absolute guards under task runner)
```

Clean P90 production/reference factors were 1.01770–1.05728 against the 1.3
cap; fallback speedups were 1.97815–2.16095 against the 1.6 floor. All 18
clip/view budgets, idle caches and three-rig repeat-hit checks pass.
Fresh identity again passes: 8,364 poses / 304,685 actual buffers, with the
changed-vertex mutation caught. Capacity 128, cache disable and legacy scalar
negative controls remain rejected; reload and immutable-fixture guards pass.

| Timing mutation | Front reference P90 | Rear reference P90 | Observed rejection |
| --- | ---: | ---: | --- |
| slowdown30 | 1.34964 | 1.34686 | Independent reference in both views |
| partial-fast-path | 1.35396 | 1.33680 | Independent reference in both views |
| disabled-fast-path | 2.21034 | 2.05826 | Both guards in both views |

The partial-removal fallback ratios are
1.65692 / 1.63953:
the old fallback floor alone would accept both. The 30% patch also retains
fallback ratios above 2.1. Both now fail the independent reference guard.
`results.json` retains all ten clean rows and six mutation rows.

Final registration remains `TEST REGISTRATION AUDIT: PASS (916 scripts; full suite=549, quarantined=29, windowed probe=338)`.
`git diff --check` passes. Exact Git/runtime equality is verified again after
all checks, and every copied reviewer input remains identical to its original.
The final code/fixture hashes and file inventory are in `results.json` and
`changed_files.txt`. There are no unresolved implementation failures.

The focused parallel command uses four configured shards and one selected test
module (one populated shard), rather than running either complete suite:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && python3 tools/run_python_suite.py --shards 4 --pattern test_rr49_submission.py --output-dir tests/rr49/proof/rr50/feedback1/python-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && python3 -m unittest tests.test_rr41_feedback3.ForgedManifestTests tests.test_rr49_submission.SubmissionTests.test_optimized_reference_is_immutable tests.test_rr49_submission.SubmissionTests.test_rr50_runtime_pins_are_exact_and_reject_mutations -v
```

## Scope, defaults and handoff

Changed code: the paired benchmark, submission timing harness, reference loader,
provenance helper, submission Python tests and real-rest forgery test. Added data:
the approved optimized fixture and feedback proof records. No production code,
rig input, geometry, art, motion, audio, save, analytics or gameplay value changed.
No dependencies were added. The exact file inventory and runtime/fixture/source
hashes are recorded with the final results.

No `TODO_DESIGN_*` placeholders or player-facing choices. New proof-only default:
`REFERENCE_FACTOR_PERCENTILE = 0.9`. Three rounds/warmup poses and runner timeout
are inherited; 1.6, 1.3 and five clean trials are prescribed. A named comment
mutation is used only in temporary source fixtures. See `chosen_defaults.json`.

No new captures or windowed commands are required by this guards-only round.
The director's ongoing native/production proof at c78b9f7f6 remains bound to the
same runtime bytes; the previous `proof_for_design_owner.md` commands remain
unchanged. The director owns commits, full-suite merge checks and publication.

## Concurrent owner proof outputs

The following unrelated proof reports appeared while the director's windowed
proof was running. This worker did not write or restore them; they are excluded
from the worker source binding and file inventory:

- `experiments/cutouts/chainbound_gaoler/rr44/proof/gates_summary.json`
- `experiments/cutouts/chainbound_gaoler/rr44/proof/rr44_native_gates.json`
