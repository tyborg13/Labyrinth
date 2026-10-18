# qa-08 feedback 4: review fixes and deterministic map budgets

Implemented on `db2a234fe87e54cc44455caa718debadde638b59`, with all changes
uncommitted. The director's runtime-path fix is retained. No quarantine entry,
partition, scheduler cap/concurrency, production script, approved asset or seed
fixture changed. The current manifest has 115 supplemental entries after the
director quarantined `owned_cpu_asset_preparation_test` under `bug-02`; the full
scheduler still has 165 children. This feedback does not restore that test.

## Requirements and mutations

| Item | Implementation and regression | Observed mutation result |
| --- | --- | --- |
| 1. Function-local aliases | The call reader separates class tokens from function bodies. Resolution combines inherited class aliases with only the invoked method's local aliases. Nested resource aliases use class scope. Regressions cover both `var` and `const` with suite A in `_initialize()` and suite B in an uncalled method using the same local name; B remains orphaned. Additional checks cover a shadowed class constant and nested aliases. | Collecting aliases across functions and removing local resolution is rejected: **2 assertion failures**. |
| 2. Strings and comments | `tools/gdscript_test_calls.py` emits atomic string tokens and discards comments. Call discovery visits identifier tokens. Literal paths and deferred method names are read only in their argument positions. Regressions cover quoted inline and alias calls, local/deferred/Callable text, escaped quotes, single quotes and multiline triple quotes. Callback references remain separate from direct calls so wrappers retain their existing assertion checks. | Scanning string contents as code is rejected: **20 assertion failures**. |
| 3. Inferred aliases | The alias reader accepts `=`, `: Variant =` and `:=` for both `var ... load(...)` and `const ... preload(...)`, in function and class scope (12 combinations). | Dropping inferred aliases is rejected: **4 assertion failures**; typed and untyped cases remain covered. |
| 4. Exact fixture modes | An independent `REQUIRED_FIXTURE_MODES` table pins every special fixture; all other supplemental entries require `script`. Existing path, existence and recognized-mode assertions are retained. | Changing each of the **115** supplemental modes is rejected, including Bile Bloomer from `cutout_pack` to `script`. |
| 5. Runtime preload path | The unit test executes the fixture bootstrap writer with repository and foreign project stages, then checks both generated files for the exact required path and absence of the other form. `tools/program_suite_fixture.py` itself is unchanged. | Forcing absolute runtime preloads everywhere is rejected by the repository-project assertion. |
| 6. Deterministic map regression | The committed child checks the existing **40-node type-assignment budget** and **1% fallback limit**. Wall time remains diagnostic output. All other checks are retained. The standalone 2,000-seed sweep tool still enforces **250 ms/section**, **1,000 ms/run**, and its existing attempt calibration. | All **6,378 checks** pass both focused and under full concurrent load. |

Mutation checks are part of the focused tests, not edits left in production.
The [audit log](../output/qa-08/feedback-4/audit-tests.log) records the first
three rejection counts. The [runner log](../output/qa-08/feedback-4/runner-tests.log)
records fixture-mode and bootstrap-path rejections.

The map suite retains all 23 non-wall assertion call sites verbatim. Replacing
the conditional propagation of benchmark failures with an explicit fallback
predicate adds one executed passing check (6,377 → 6,378). The existing node
budget predicate is unchanged. [Preservation evidence](../output/qa-08/feedback-4/preservation.json)
also hashes 38 unchanged contract, partition, seed-fixture and sweep files.

## Tests and concurrent proof

| Check | Exact result / timing |
| --- | --- |
| Focused audit tests | `Ran 32 tests in 3.401s`; `OK` |
| Focused runner tests | `Ran 28 tests in 19.790s`; `OK` |
| Completeness guard | `TEST REGISTRATION AUDIT: PASS (739 scripts; full suite=390, quarantined=34, windowed probe=315)` |
| Focused map child | `SECTION MAP PERFORMANCE PROGRAM RESULT: PASS (6378 checks, 0 failures)`; child 12.576 s; scheduler 12.605 s |
| Full Godot, alongside full Python | `FULL SUITE RUNTIME: 425.495 seconds (budget 900 seconds)`; final `TEST RESULT: PASS`; command wall **430.45 s** |
| Full Python, alongside full Godot | `Ran 745 tests in 648.971s`; `OK (skipped=63)`; command wall **649.47 s** |
| Source freeze | `FROZEN SOURCE: PASS (4499 files unchanged; HEAD unchanged)` |
| Whitespace / output isolation | `git diff --check` exits 0; `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)` |

Both complete commands started together, without an intervening source edit.
Python remained active throughout Godot's run. Before/after hashes cover 4,499
source/data files, including the new call reader. The five-worker scheduler
retains its 180-second child and 900-second total caps. All 165 children passed;
none timed out. Every child is below 110 seconds, and Godot wall time is below
600 seconds.

| Largest children in this loaded run | Seconds |
| --- | ---: |
| `suites/forced_movement_query_dense_program` | 73.817 |
| `suites/full_scene_interaction_program` | 72.773 |
| `suites/encounter_placement_0_program` | 57.236 |
| `suites/encounter_placement_1_program` | 55.757 |
| `suites/encounter_placement_summary_program` | 54.894 |

Map performance took 19.236 s; map v5 took 17.937 s; EN06 took 9.445 s.
The complete [per-child timing table](../output/qa-08/feedback-4/per-child-times.md)
and [CSV](../output/qa-08/feedback-4/per-child-times.csv) include every child.
The [scheduler report](../output/qa-08/feedback-4/full-programs.json) links copied
per-child logs; its [original report](../output/qa-08/feedback-4/full-programs-original.json)
retains original task-local paths. Also retained: [full Godot log](../output/qa-08/feedback-4/full-godot.log),
[full Python log](../output/qa-08/feedback-4/full-python.log),
[summary](../output/qa-08/feedback-4/summary.json),
[source before](../output/qa-08/feedback-4/source-before.json) and
[source after](../output/qa-08/feedback-4/source-after.json).

## Committed-seed node maxima

These are the maximum nodes consumed by any individual type-assignment attempt
across each seed's six sections. Focused and loaded results are identical.
The global maximum is **40/40 nodes**, with **0/126 fallback sections**.
[Machine-readable maxima](../output/qa-08/feedback-4/node-maxima.json).

| Seed | Maximum nodes |
| --- | ---: |
| 1792271957 | 32 |
| 4204307422 | 40 |
| 3910467943 | 40 |
| 2426260977 | 40 |
| 569927926 | 40 |
| 40729275 | 40 |
| 958190991 | 40 |
| 604986807 | 40 |
| 2462276153 | 40 |
| 269513162 | 40 |
| 2299794004 | 40 |
| 3327006184 | 40 |
| 4006337457 | 40 |
| 3649162996 | 40 |
| 1197025418 | 40 |
| 920871697 | 40 |
| 2140372402 | 40 |
| 1874976787 | 40 |
| 307044377 | 40 |
| 2247661876 | 40 |
| 2144603346 | 40 |

## Proof for the design owner

The two full commands below were launched concurrently. No windowed probe or
inspection fixture is applicable to these workflow and headless-test changes;
none was attempted. The separate 2,000-seed timing sweep and slow quarantine
recheck were not requested for this feedback and were not rerun. Bug-02 remains
quarantined as instructed.

```sh
python3 -m unittest discover -s tests -p 'test_test_registration_audit.py' -v
python3 -m unittest discover -s tests -p 'test_program_suite_runner.py' -v
python3 tools/test_registration_audit.py
python3 tools/program_suite_runner.py --project . --task-id qa-08 --godot godot --result-file output/qa-08/feedback-4/map-focused.json --suite suites/section_map_performance_program
/usr/bin/time -p python3 tools/godot_task_runner.py --task-id qa-08 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
LABYRINTH_TASK_ID=qa-08 /usr/bin/time -p python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/output_gdignore.py --check
git diff --check
```

## Files changed

- `tools/gdscript_test_calls.py`: focused token, scope, alias and dispatch reader.
- `tools/test_registration_audit.py`: use the reader for execution and wrapper coverage.
- `tests/test_test_registration_audit.py`: scope/string/assignment regressions and three mutation checks.
- `tests/test_program_suite_runner.py`: independently pinned fixture modes, exact bootstrap path checks and mutations.
- `tests/suites/section_map_performance_suite.gd`: deterministic budgets and per-seed node diagnostics.
- `spec/development_workflow.md`: document scope/token/mode/bootstrap rules; avoid a stale supplemental count.
- `tests/qa_08_review_fixes.md`: this handoff and proof links.

## TODO_DESIGN placeholders

None. No player-facing behavior, values, assets or wording changed.

## Chosen defaults

Only synthetic test fixture identities and temporary paths: A/B/Ghost/Active
suite names, the `directory` value `runtime-paths`, and the `foreign` value
`foreign-project`. They are local named test fields/variables. Existing fixture
timeouts, scheduler settings and approved map budgets are reused unchanged.

## Open issues

No new failing required check. Existing quarantine entries, including host-dependent
bug-02, are preserved for their assigned follow-ups. Native Windows execution
remains unverified. Changes are uncommitted; no peer review, publication or
branch operation was performed.
