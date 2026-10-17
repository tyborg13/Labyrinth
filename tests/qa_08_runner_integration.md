# qa-08 shared-runner integration

Base: design-owner merge `46a4f5209`. All changes in this feedback phase remain uncommitted. The earlier root-cause/audit work is in [qa_08_test_audit.md](qa_08_test_audit.md); this report supersedes its pending qa-07 integration status.

## 1. Registration and isolation

`tools/program_suite_runner.py:SUITES` now includes the accepted 116 entries from `tests/headless_test_programs.json`, in order, with their original invocation modes. The manifest guard requires the complete original, merged and supplemental set; removing any supplemental entry fails it. The obsolete `supplemental_program_suites.gd` dispatcher is deleted. The main harness calls the fast completeness guard directly; Surface Relic retains its existing in-process hook.

Package and capture-settings fixtures use `tools/program_suite_fixture.py` inside one scheduler slot. Package build/verify stages keep their original arguments and empty-project boundary. Capture settings use a fresh private project and startup override. Each stage uses the qa-07 namespace bootstrap, explicit engine log, and task-runner HOME/APPDATA/LOCALAPPDATA/XDG isolation. One outer 180-second deadline bounds the entire fixture. Reused report paths get fresh staging directories. Actual native headless fixtures, fake child environments, parent cancellation during a package stage, and staged build/verify arguments are covered by the runner tests.

The merge also introduced unregistered boon-recovery, map-v5 and map-v5-layout programs; they join the same queue. The audit follows inherited constants and nested suite aliases, the exact encounter partitions, the map regression's actual child calls, and Python's reachable subprocess invocation of the scheduler fixture. The CBT-01 and opening-boon image probes have explicit native exclusions. Current audit: `TEST REGISTRATION AUDIT: PASS (733 scripts; full suite=386, quarantined=33, windowed probe=314)`.

## 2. Calibration, fixes and runtime

The original three-child scheduler completed all 152 programs in `FULL SUITE RUNTIME: 649.482 seconds (budget 900 seconds)`; command wall time was `real 656.22`. It returned `TEST RESULT: FAIL (2 failure(s))`: glossary and save/resume. [Calibration log](../output/qa-08/integrated-run-1.log), [per-child report](../output/qa-08/integrated-run-1.report.json).

The glossary's frozen pre-glossary Immolation snapshot predates approved CBT-01 commit `5e20c1099`, which added adjacent damage before Detonate. The original JSON is untouched. A small independent fixture composes its new melee/pattern prefix and order from the historical Quick Stab and Immolation entries. Every card still has exact count, order and body-line assertions. Focused result: `GLOSSARY TEST RESULT: PASS (7321 checks, 0 failures)` ([log](../output/qa-08/glossary-cbt-fixture.log)).

Two save/resume clearing assertions also predate the durable heirloom prompt. Their fixture now asserts that the same terminal prompt is durably resumable, completes the real Leave nothing model boundary, then retains the original clearing predicates. The unchanged animation-time Save & Quit fallback equality assertion exposed a persistence-ordering regression: the pending-prompt branch introduced in `1382b6916` replaced the original unprocessed fallback while profile persistence was still failing. The branch now requires durable profile/receipt persistence before replacing an animation-held fallback, matching ordinary terminal Quit ordering. This proves restoration of the exact-fallback contract; no currency-loss claim is made. Existing recovery metadata may also recover a processed terminal fallback. No original assertion was weakened. Focused result: `TEST RESULT: PASS — committed save/resume boundary matrix` ([log](../output/qa-08/save-boundary-boon-fix.log)). Analytics documentation records the ordering; event shapes and idempotency keys are unchanged.

Presentation and interaction children exceeded 110 seconds even in the calibration (110.871s and 111.872s). Coherent scene partitions now separate presentation, shared cutouts, creature cutouts, audio, navigation, card dragging, input controls, clock, choices and interaction. All 96 original invocations remain in the same order; inherited assertion bodies are unchanged. [Invocation proof](../output/qa-08/scene-split-coverage.json).

Because calibration exceeded 600 seconds, the default child concurrency now follows `min(6, logical_cpus // 3)`, with a one-child minimum on small hosts. This machine reports 15 logical CPUs, so the scheduler uses five children alongside the main Godot. The 180-second child and 900-second command caps are unchanged. The final queue contains 158 programs.

The first full Python-loaded run passed all 156 programs: `FULL SUITE RUNTIME: 353.507 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; `real 357.80`. Largest child: `section_map_v5_test`, 83.868 seconds. [Log](../output/qa-08/integrated-load-1.log), [per-child report](../output/qa-08/integrated-load-1.report.json).

The second paired run also passed all 156 programs: `FULL SUITE RUNTIME: 385.123 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; `real 389.28`. Its controls child took 116.702 seconds, so the controls wrapper was split further into navigation, card-drag and remaining controls programs. Their focused timings were 16.311, 34.329 and 18.685 seconds respectively; all passed. The final manifest has 158 programs.

The next paired run, using that final manifest, hit an intermittent timeout in the existing `en06_enemies_test`: 180.209 seconds, exit 124, with no test verdict or script error after bootstrap. Earlier paired runs passed that same program; nine follow-up diagnostic executions each passed all 176 checks, including five launched together during Python discovery. A read-only watchdog sampled an unpaused tree, `Engine.time_scale == 1.0`, and inactive hit-stop in the focused executions; they do not establish the cause of the timed-out run. No EN06 assertion or gameplay code was changed, and its cap remains 180 seconds. All 116 supplemental programs passed in each paired run; their maxima were 59.115s, 69.325s and 67.747s (`forced_movement_query_equivalence_test`). In the final-manifest load run, the largest nonfailed child was `full_scene_interaction_program`, 97.577s. This failure remains open; the failed run is retained rather than claimed as passing. That run reported `FULL SUITE RUNTIME: 431.963 seconds (budget 900 seconds)`; `TEST RESULT: FAIL (1 failure(s))`; wall `real 436.69`. [Failed run](../output/qa-08/integrated-final-load-1.log), [diagnostic example](../output/qa-08/en06-watchdog-5.log).

Idle run 1 passed all 158 programs: `FULL SUITE RUNTIME: 394.356 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; wall `real 399.43`. Largest child: `section_map_v5_test`, 97.658 seconds. [Log](../output/qa-08/integrated-final-idle-1.log), [per-child report](../output/qa-08/integrated-final-idle-1.report.json). Idle run 2 passed all 158 programs: `FULL SUITE RUNTIME: 452.097 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; wall `real 456.78`. Largest child: `section_map_v5_test`, 115.470 seconds. This is a timing exception, despite the passing verdict; its standalone entrypoint retains the dedicated 200-seed legacy proof. [Log](../output/qa-08/integrated-final-idle-2.log), [per-child report](../output/qa-08/integrated-final-idle-2.report.json). Idle run 3 passed all 158 programs: `FULL SUITE RUNTIME: 402.876 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; wall `real 408.48`. Largest child: `section_map_v5_test`, 89.556 seconds. [Log](../output/qa-08/integrated-final-idle-3.log), [per-child report](../output/qa-08/integrated-final-idle-3.report.json).

| Final manifest run | Full-suite result | Full-suite seconds | Command wall seconds | Largest child seconds |
|---|---|---:|---:|---:|
| Idle 1 | `TEST RESULT: PASS` | 394.356 | 399.43 | 97.658 |
| Idle 2 | `TEST RESULT: PASS` | 452.097 | 456.78 | 115.470 |
| Idle 3 | `TEST RESULT: PASS` | 402.876 | 408.48 | 89.556 |

The three idle commands all exited 0, and their mean wall time was 421.563 seconds. The local combined performance gate prints `IDLE PROOF: FAIL` because it additionally requires every child below 110 seconds; it correctly flags idle 2. The full-suite wall-time target is met. The child-time target and a clean three-consecutive-load-run proof are **not** achieved: EN06 timed out once, and the map standalone exceeded 110 seconds once. These are open issues, with no cap increase, case removal or assertion rewrite to conceal them. A matched baseline delta is unavailable (the earlier pre-qa-07 suite exceeded its hard budget); no artificial seconds-added estimate is claimed. Idle measurements started only after all other qa-08 workloads finish. The sandbox denies process inventory (`ps: operation not permitted`), so external machine idleness cannot be independently verified.

## 3. Guard, Python and quarantine proof

Final focused registration guard: `Ran 22 tests in 0.976s`; `OK`. Final focused scheduler: `Ran 24 tests in 22.399s`; `OK`. [Registration log](../output/qa-08/guard-final.log), [scheduler log](../output/qa-08/runner-final.log).

First full Python discovery: `Ran 727 tests in 577.152s`; `OK (skipped=63)`; `real 577.62`, exit 0 ([log](../output/qa-08/python-integration-full.log)). The second paired discovery passed: `Ran 727 tests in 597.735s`; `OK (skipped=63)`; `real 598.18`. Final-manifest discovery passed: `Ran 727 tests in 659.657s`; `OK (skipped=63)`; `real 660.16` ([log](../output/qa-08/python-final-load-1.log)). Post-merge slow guard: `QUARANTINE CHECK: PASS (33 entries; 32 programs; 0 now passing)`; `QUARANTINE RUNTIME: 367.977 seconds (4 workers)` ([log](../output/qa-08/quarantine-post-merge.log), [per-entry results](../output/qa-08/quarantine-post-merge/results.json)). Quarantine ownership accepted in feedback 2 remains unchanged.

Exact full-suite and guard commands (each idle/full-suite command was executed through this wrapper):

```bash
python3 tools/godot_task_runner.py --task-id qa-08 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 -m unittest discover -s tests -p 'test_program_suite_runner.py' -v
python3 -m unittest discover -s tests -p 'test_test_registration_audit.py' -v
python3 tools/test_registration_audit.py
python3 tools/test_registration_audit.py --check-quarantine --output-dir output/qa-08/quarantine-post-merge
```

## Proof for the design owner

No new visual layout, asset, image capture or playable fixture is required. No windowed run was attempted. Existing exact native commands are in the original report. Native Windows execution remains unverified; Windows Job Objects are exercised by the existing POSIX simulation tests.

## TODO_DESIGN

None. Approved player data, copy, artwork and tuning were not changed.

## Chosen defaults

Only test/tool values: a one-child minimum below three logical CPUs; one ready frame at the start of the new scene partitions; a fresh staging directory per fixture invocation; a deterministic fake-child concurrency barrier using the existing five-second startup budget and poll interval; a 30-second native fixture-test timeout. The temporary EN06 diagnostic uses six-second samples (at most four), 40/45-second outer caps, and nine diagnostic executions; the local proof collector polls every 0.2 seconds. Package-stage cap (30 seconds) and private capture quality (1.0) retain the accepted earlier fixture values. The Leave nothing terminal fixture selects the existing empty-item model option; it invents no player value.

## Files changed in feedback 2

- Scheduler/integration: `tools/program_suite_runner.py`, `tools/program_suite_runner.gd`, new `tools/program_suite_fixture.py`; deleted `tests/helpers/supplemental_program_suites.gd`.
- Registration: `tools/test_registration_audit.py`, new `tools/test_execution_sources.py`, `tests/run_tests.gd`, new `tests/helpers/test_registration_guard.gd`, `tests/windowed_test_allowlist.json`.
- Runner/guard tests: `tests/test_program_suite_runner.py`, `tests/test_test_registration_audit.py`.
- Invocation-only partitions: the existing presentation, controls and interaction wrappers, plus new audio, card-drag, choices, creature-cutouts, cutouts and navigation wrappers in `tests/suites/`.
- Merge regressions: `tests/glossary_test.gd`, new `tests/fixtures/approved_glossary_structure.gd`, `tests/save_resume_boundary_test.gd`, new `tests/helpers/terminal_boundary_fixture.gd`, `scripts/opening_boon_recovery.gd`, `scripts/run_scene.gd`.
- Documentation: `spec/development_workflow.md`, `spec/analytics.md`, this report, `tests/qa_08_test_audit.md`, `tests/qa_08_test_inventory.md`.
- Proof artifacts: `output/qa-08/.gdignore` and `.gitignore` exclude generated proof scripts/logs from import/Git enumeration. Logs and reports stay available in that directory; no capture was required.

The accepted `tests/headless_test_programs.json` and `tests/quarantine.json` values were not rewritten. All feedback-2 changes remain uncommitted.
