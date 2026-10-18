# qa-08 feedback 3 — loaded child budgets

Base: owner merge `9705bec9b`, including the accepted qa-08 integration (`770837365`) and fix-05. This report supersedes the open timing items in [the feedback-2 report](qa_08_runner_integration.md). Worker changes remain uncommitted; no Git mutation, peer review, sign-off request or windowed run was performed.

## 1. Separate map performance child

`tests/suites/section_map_performance_program.gd` invokes the complete existing fix-05 performance suite in a separate scheduler slot. The v5 aggregate no longer preloads or calls that performance suite, so its duplicate main-body/standalone executions become one dedicated child. Every unique regression remains: seed 1792271957 plus the protected 20-slowest-seed fixture, pruning/memo/cutoff checks, rejection child, graph determinism, all map rules, and the existing timing/fallback assertions. The performance suite and all protected data files are byte-for-byte unchanged.

The final guarded manifest has 165 children: the original 158, one performance child, two extra map partitions, and four extra forced-query partitions. The accepted 116-entry supplemental JSON is unchanged; its forced-query entry expands to five required child programs. Removing the child fails the manifest guard. A new guard also prevents reintroducing the performance suite inside the map aggregate. The completeness audit follows the performance suite's actual `Regression._run_child` call; its regression proves that an unused/commented call cannot register the rejection test. Current classification: `TEST REGISTRATION AUDIT: PASS (736 scripts; full suite=389, quarantined=33, windowed probe=314)`.

Focused result: `SECTION MAP PERFORMANCE PROGRAM RESULT: PASS (6377 checks, 0 failures)`, 16.331 seconds. [Child log](../output/qa-08/feedback-3/map-performance-focused.logs/00-suites-section_map_performance_program.log), [scheduler report](../output/qa-08/feedback-3/map-performance-focused.json).

The first loaded trial passed in 359.30s with a 75.144s child maximum. The next trial passed functional Godot checks in 484.87s but exposed `forced_movement_query_equivalence_test` at 122.034s, so it did not meet the timing gate. Map v5 also reached 108.887s. These initial trials are retained separately ([run 1](../output/qa-08/feedback-3/load-run-1.log), [run 2](../output/qa-08/feedback-3/load-run-2.log)). I edited the partition module while trial 2's Python discovery was still active; its cached older dependency caused `ImportError: cannot import name 'program_paths'`. That Python result is invalid, not claimed as passing. All three final proofs restart from frozen source after validation finishes.

The final map partitions are current-map checks, revision-3/4 hash ranges 1–100 and 101–200, and the entire performance regression. The original standalone map test still defaults to all 200 hash seeds; the in-process 50-seed invocation also retains its original range. The current-map child selects zero hash seeds because the two hash children execute the complete 200-seed sweep. Each hash child executes 200 original hash assertions plus one partition-coverage assertion: 400 original checks and two added guards in total. The canonical `Regression.run` retains public dispatch, structural rejection, probe readiness and layout seeds 1/2/5; its assertion bodies are unchanged.

The forced-query partitions each inherit the original test's unchanged assertion and oracle bodies and select one existing fixture: open, dense, heart, surface_ready, blocked. Every fixture retains all four variants and its complete Push/Pull action matrix (2,160 action combinations overall), ordered oracle queries, landing/direction checks, and source immutability assertions. Their executed check counts are 2,470 + 7,978 + 2,200 + 3,910 + 868 = **17,426**, exactly the original count, in every final full run. All original assertion-call lines are identical. The unpartitioned standalone input path remains supported. [Focused counts](../output/qa-08/feedback-3/forced-partition-counts.json), [all final assertion-preservation checks](../output/qa-08/feedback-3/proof-v2/assertion-preservation.json).

A focused batch overlapping native runner tests exceeded four existing 250ms section assertions (maximum 362.059ms); that failure is retained ([log](../output/qa-08/feedback-3/partition-focused.logs/07-suites-section_map_performance_program.log)). A subsequent serial run passed the entire unchanged performance suite in 13.626s, and each final loaded run passed all 6,377 checks. No timing assertion was relaxed.

## 2. EN06 root-cause evidence and five loaded profiles

The old test instantiated a fresh live scene before installing its fixed enemy state. That synchronously runs `_ready → _boot_run → _start_run → RunEngine.create_new_run → SectionMapGraph.initialize`, using `_new_seed()`'s current Unix second. The [failed child's final file inventory](../output/qa-08/feedback-3/timed-out-child-files.json) contains its roundtrip fixture and analytics metadata; no live profile/run save exists. Those files were written at Unix time 1792274652.606–1792274652.931, immediately before the startup interval.

A diagnostic copy of the exact graph at the timed-out integration (`46a4f5209`) has the same SHA-256 as pre-fix-05 (`004580a30^`). Its only initial transform removes the global class name so it can coexist with production. Six timestamp-neighbour replays show:

| Seed | Pre-fix result |
|---|---|
| 1792274651 | 0.136 seconds, exit 0 |
| 1792274652 | 0.157 seconds, exit 0 |
| 1792274653 | Exceeded the 18-second diagnostic cap, exit 124 |
| 1792274654 | 0.164 seconds, exit 0 |
| 1792274655 | 0.143 seconds, exit 0 |
| 1792274656 | 0.107 seconds, exit 0 |

A second copy only prints each 10,000 existing solver nodes. It reached 20,000 nodes before the same cap, inside synchronous `_solve_types_v5` recursion; there is no asynchronous wait in that call path. This supports a timestamp-seeded CPU search explosion already fixed by the merged fix-05, rather than a stuck animation wait. The original failed run did not log its seed or phase, so its exact seed cannot be proved retrospectively. [Replay results](../output/qa-08/feedback-3/legacy-replays.json), [CPU-search trace](../output/qa-08/feedback-3/legacy-search-trace.log), [source provenance](../output/qa-08/feedback-3/legacy-source-provenance.json).

EN06 now deliberately boots seed 1792274653 through the existing process-local probe hook, then restores any previous hook value and installs the same existing enemy fixture (seed 61027). This retains the pathological startup as regression coverage while eliminating unrelated timestamp variability. All 100 original assertion-call source lines are identical; all original 176 executed checks remain, plus one boot-seed identity check. [Assertion preservation](../output/qa-08/feedback-3/assertion-preservation.json).

Optional `LABYRINTH_EN06_PROFILE=1` logs each phase boundary and read-only wait samples. It reads the stored presentation clock rather than advancing it, and never writes the scene, pause state or time scale. The preliminary smoke run passed all 177 checks in 9.744 seconds; Mirror animation took 1.159 seconds and Chain animation 0.525 seconds. The 180-second production child cap is unchanged. [Smoke log](../output/qa-08/feedback-3/en06-smoke.logs/00-en06_enemies_test.log).

The initial calibration runs alongside full Python discovery and repeated map-v5, map-layout, scene-interaction and creature-cutout children. The smoke run and first two calibration samples exposed an absent-optional-metadata diagnostic from the new fixture; the guarded read is corrected. These logs are retained as calibration, and a fresh five-sample distribution is collected after the correction under the same ongoing Python load and four other scheduler children. The calibration timings were 10.188, 10.149, 10.117, 11.130 and 10.761 seconds (all 177 checks passed). No calibration timing was discarded as an outlier; the fresh set follows the fixture diagnostic correction.

| Final EN06 loaded run | Child seconds | Result |
|---|---:|---|
| 1 | 9.856 | `EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)` |
| 2 | 9.894 | `EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)` |
| 3 | 10.072 | `EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)` |
| 4 | 9.923 | `EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)` |
| 5 | 9.930 | `EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)` |

Minimum 9.856s, median 9.923s, mean 9.935s, maximum 10.072s. Python discovery remained active at both boundaries of the entire focused scheduler batch. Every sample passed without the optional-metadata error. Typical loaded time is below 90 seconds, so no EN06 split is required. [Distribution and all phase samples](../output/qa-08/feedback-3/en06-profile-summary.json), [per-child logs/report](../output/qa-08/feedback-3/en06-final-profiles.json).

The same pure-graph replay on production reports `CURRENT MAP REPLAY: PASS (seed 1792274653; 0.162 seconds; max attempt 40 nodes)` ([log](../output/qa-08/feedback-3/current-map-replay.log)). The production solver fix is already supplied by fix-05; this unit does not change graph generation.

Scene startup median/max: 1.789/1.876s; rules: 0.361/0.364s; Mirror animation: 1.152/1.160s; Chain animation: 0.530/0.535s. No observed wait stalls, and no wait was shortened or bypassed.

The profiling workload's full Python discovery returned `Ran 729 tests in 627.448s`; `OK (skipped=63)`; `real 628.10`, exit 0 ([log](../output/qa-08/feedback-3/python-profile-load.log)).

## 3. Three consecutive full runs under load

All three final full Godot runs and their independent concurrent full Python discoveries pass, with source hashes unchanged across the three pairs. Each run includes all 165 children. There were no other qa-08 engine/test workloads during these pairs. The scheduler retains five slots, 180-second child caps and the 900-second command cap.

| Final loaded run | Godot full-suite seconds | Godot command wall seconds | Largest child | Child seconds | Full Python discovery |
|---|---:|---:|---|---:|---|
| 1 | 446.707 | 451.37 | `suites/full_scene_interaction_program` | 80.156 | `Ran 730 tests in 763.044s`; `OK (skipped=63)` |
| 2 | 532.819 | 540.34 | `suites/forced_movement_query_dense_program` | 91.141 | `Ran 730 tests in 835.202s`; `OK (skipped=63)` |
| 3 | 376.357 | 380.57 | `suites/full_scene_interaction_program` | 67.413 | `Ran 730 tests in 589.793s`; `OK (skipped=63)` |

Every Godot run ends with `TEST RESULT: PASS`. The proof driver reports:

```text
LOAD PROOF: PASS (3 consecutive runs; every child <=110s; wall <=600s; full Python passed alongside each)
FINAL PROOF AGGREGATE: PASS (3 loaded runs; 165 child maxima <=110s; all walls <=600s; original assertions preserved)
```

The maximum over all 495 child observations is **91.141s**. Complete per-child run times and maxima: [Markdown table](../output/qa-08/feedback-3/proof-v2/per-child-maxima.md), [CSV](../output/qa-08/feedback-3/proof-v2/per-child-maxima.csv), [JSON](../output/qa-08/feedback-3/proof-v2/per-child-maxima.json). [All result lines, source hashes and report paths](../output/qa-08/feedback-3/proof-v2/load-proof-summary.json).

The final EN06 full-suite times are 11.497, 14.567 and 8.581 seconds. Performance-regression child times are 20.787, 23.752 and 17.190 seconds, retaining all 6,377 checks each time. Python is independent concurrent load; its full discovery durations are reported separately from the Godot command's ≤600-second target.

Final focused runner guard: `Ran 25 tests in 20.446s`; `OK`. Final focused registration guard: `Ran 24 tests in 0.951s`; `OK`. [Runner log](../output/qa-08/feedback-3/runner-partition-final.log), [registration log](../output/qa-08/feedback-3/guard-partition-final.log). The slow guard was rerun after fix-05: `QUARANTINE RUNTIME: 374.308 seconds (4 workers)`; `QUARANTINE CHECK: PASS (33 entries; 32 programs; 0 now passing)` ([log](../output/qa-08/feedback-3/quarantine.log), [per-entry results](../output/qa-08/feedback-3/quarantine/results.json)). No quarantine values or owners were rewritten.

## Commands and proof for the design owner

```sh
LABYRINTH_EN06_PROFILE=1 /usr/bin/time -p python3 tools/godot_task_runner.py --task-id qa-08 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
LABYRINTH_TASK_ID=qa-08 LABYRINTH_EN06_PROFILE=1 /usr/bin/time -p python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 -m unittest discover -s tests -p 'test_program_suite_runner.py' -v
python3 -m unittest discover -s tests -p 'test_test_registration_audit.py' -v
python3 tools/test_registration_audit.py
python3 tools/output_gdignore.py --check
```

Run the first two commands concurrently, then repeat for three pairs. The final local driver is `output/qa-08/feedback-3/run_full_load_proof_v2.py`; it writes `proof-v2/` and requires the recorded precheck gates. Raw evidence and diagnostic drivers remain under `output/qa-08/feedback-3/`. Initial trial drivers are historical; final run logs are under `proof-v2/`. Every engine process uses the task runner, directly or through the shared program scheduler. No captures or inspection fixture apply to this test/workflow change; no windowed command is required.

## TODO_DESIGN and chosen defaults

No TODO_DESIGN placeholders or player-facing choices. Only test/proof values were chosen: boot regression seed 1792274653 (from the recorded timestamp interval); optional wait sampling every 10 seconds; 18-second historical replay caps; solver trace every 10,000 existing nodes; six neighbour seeds; five EN06 samples; four existing heavy program types as concurrent load; 0.2-second local driver polling; five existing forced-query fixture groups as process boundaries; two equal legacy hash partitions and a zero-hash selection in the current-map child. The actual 200 hash seeds, four force variants and all action values are retained. Existing enemy fixture values, performance thresholds, quarantine ownership, worker count and all runtime caps are retained.

## Files changed

- `tools/program_suite_runner.py`, `tools/test_execution_sources.py`: one dedicated performance child and explicit required map/force partitions; protected supplemental JSON unchanged.
- `tools/test_registration_audit.py`: expands those same registrations, follows the actual performance rejection child, and requires every partition before shared-wrapper coverage can count.
- `tests/test_program_suite_runner.py`, `tests/test_test_registration_audit.py`: manifest-removal, aggregate-exclusion, reachable-child and incomplete-partition regressions.
- `tests/suites/section_map_v5_suite.gd`: removes the performance preload/call, uses the existing canonical regression aggregate, and exposes a starting seed for partitioning the unchanged legacy assertions.
- `tests/forced_movement_query_equivalence_test.gd`: overridable typed fixture selector; all original comparisons/assertions retained.
- New `tests/suites/section_map_{v5,performance,legacy_hashes_0,legacy_hashes_1}_program.gd` and five `forced_movement_query_*_program.gd` entrypoints.
- New `tests/helpers/counted_program.gd` and `tests/helpers/section_map_legacy_program.gd`: small shared counted-result/legacy partition helpers.
- `tests/en06_enemies_test.gd`, `tests/suites/en06_enemies_suite.gd`, new `tests/helpers/en06_phase_profile.gd`: deterministic boot regression and opt-in read-only phase diagnostics; all original checks retained.
- `spec/development_workflow.md`, this report, and the feedback-2 report's historical notice.

Exact changed paths:

```text
spec/development_workflow.md
tests/en06_enemies_test.gd
tests/forced_movement_query_equivalence_test.gd
tests/helpers/counted_program.gd
tests/helpers/en06_phase_profile.gd
tests/helpers/section_map_legacy_program.gd
tests/qa_08_load_proof.md
tests/qa_08_runner_integration.md
tests/suites/en06_enemies_suite.gd
tests/suites/forced_movement_query_blocked_program.gd
tests/suites/forced_movement_query_dense_program.gd
tests/suites/forced_movement_query_heart_program.gd
tests/suites/forced_movement_query_open_program.gd
tests/suites/forced_movement_query_surface_ready_program.gd
tests/suites/section_map_legacy_hashes_0_program.gd
tests/suites/section_map_legacy_hashes_1_program.gd
tests/suites/section_map_performance_program.gd
tests/suites/section_map_v5_program.gd
tests/suites/section_map_v5_suite.gd
tests/test_program_suite_runner.py
tests/test_test_registration_audit.py
tools/program_suite_runner.py
tools/test_execution_sources.py
tools/test_registration_audit.py
```

All worker changes remain uncommitted. No production script, approved data/asset, protected fixture, task queue or quarantine value changed in this feedback phase.

## Open issues and proof limits

No failing required implementation checks remain. The exact timestamp seed of the original failed EN06 process was not logged, so retrospective attribution remains an inference supported by the saved-file timestamps and the reproduced CPU search case. Native Windows execution remains unverified; new typed-array assignments use explicit typed temporaries/`assign`.

External host idleness cannot be independently certified. Aggregate load was sampled at 22.358 on 15 logical CPUs during a run and 12.285 after Godot completed; [raw samples](../output/qa-08/feedback-3/proof-v2/system-load.jsonl) are retained without assigning that load to particular processes. The final proof's actual times meet both requested bounds despite that variation.
