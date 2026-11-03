# rr-42 feedback 3 — final review fixes

Risk tier: standard, inherited routing unit. Starting HEAD: `75e4b3896cf1cf46a035b4f34778bc57aae06d21`. Changes remain uncommitted. The director accepted the native sheets and zero gate errors; this round changes no art, motion data, gate implementation, protected input or native manifest.

## Acceptance and proof

1. Candidate compilation takes an explicit motion-case root. The rr-42 test uses tracked `CASE` data; production search tools explicitly retain their production proof case. Run the motion test alone in a tracked-files temporary copy without ignored production output.
2. Keep every historical row-donor and rest assertion. Bind rr-38's own motion to its build-receipt SHA and recompile it exactly. Separately compare current production with current staged motion, including the existing accepted clamps.
3. Derive move frames from `Action.frames_for("chainbound_gaoler", "move")` and frame seconds from `Action.FPS`. The existing Gaoler routing probe checks the authored move clock.
4. Remove the unused `held_drop.policy()` helper without changing any release calculations or policy data.

Focused proof only: rr-42 tests, `test_rr38_feedback2`, Gaoler routing probe, existing raster/dependency regressions, and the isolated tracked-files motion test. No full suite, windowed run, peer review or publication is assigned to this worker.

## Execution notes

The prepared worktree was clean on `codex/rr-42`. The requested Git preflight cannot repeat its smoke write in this sandbox: `git write-tree` cannot create the worktree index lock in the parent repository's metadata. The design owner already supplied the prepared worktree and passed preflight. No Git ref or branch smoke operation was reached, and no sandbox override or manual Git write was attempted; implementation proceeds within that existing authorization.

## Observed verification

```text
Ran 45 tests in 67.904s
OK
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
RR42 TRACKED-ONLY MOTION TEST: PASS (5116 tracked files; ignored production_case absent)
Ran 1 test in 2.188s
OK
TEST REGISTRATION AUDIT: PASS (841 scripts; full suite=487, quarantined=29, windowed probe=325)
```

The 45-test run contains all rr-42 tests (including the new tracked-only copy regression), `test_rr38_feedback2`, the existing native raster tests, proof runtime-path/dependency tests and maquette-certificate/import-closure tests. The one required motion test also runs by itself inside the copy, in 0.080 seconds; that child receives no inherited `PYTHONPATH`. The ignored `production_case` does not exist before or after it runs. This is a scoped copy of tracked working-tree files, not a claim that uncommitted changes are already in HEAD.

Commands:

```sh
python3 -B -m unittest tests.test_rr42_feedback3 -v
LABYRINTH_TASK_ID=rr-42 python3 -B -m unittest tests.test_rr42_gaoler tests.test_rr42_feedback2 tests.test_rr42_feedback3 tests.test_rr38_feedback2 tests.test_maquette_native_raster tests.test_proof_runtime_paths tests.test_maquette_certificates -v
python3 tools/godot_task_runner.py --task-id rr-42 --stream -- godot --headless --path . --script tests/rr38/runtime_checks.gd
python3 tools/test_registration_audit.py
git diff --check
```

Logs: `/private/tmp/rr42-r3-{focused,clean-copy,routing,registration}.log`; hashed copies are under `rr42/proof/logs/feedback3/`. The compact record is `rr42/proof/feedback3_receipts.json`.

The initial focused run exposed one error in the new current-production test: runtime packaging omits `anatomy.json`, which the authoring compiler needs. The corrected test compiles current staged motion with tracked authoring layouts, then compares that exact result against production. The first result was `Ran 45 tests in 73.508s` / `FAILED (errors=1)`; the final run above passes. No runtime package, motion or gate was changed to address this test-fixture error.

Dependency checks report the existing archived `gaoler_motion.gd` gaps for mq3 rounds 4/5/6; their regression verdict passes. The routing log retains the existing macOS CA-certificate warning. Neither is a new test failure.

## Files and preservation

- `rr42_candidate.py`: require the motion-case root for authored and candidate compilation. `rr42_channel_search.py` and `rr42_angle_budget.py` explicitly pass their existing production proof root; the test passes tracked `CASE`.
- `tests/test_rr42_gaoler.py`: remove the ignored-output dependency and separately recompile current staged motion against current production.
- `tests/test_rr38_feedback2.py`: only replace the stale final current-staged comparison with the recorded historical SHA and exact historical recompilation. All row-donor and rest assertions remain present.
- `renderer.gd`: source move frames through `Action.frames_for` and frame seconds through `Action.FPS`. The accepted clock remains 51 frames.
- `held_drop.gd`: remove only the unused `policy()` function; angle and release-transform calculations are unchanged.
- `tests/test_rr42_feedback2.py` and `rr42/proof/feedback3_adapter_cleanup.json`: retain exact old SHA pins for every production input except the two explicitly authorized adapter cleanups, which have exact before/after hashes. The native calibration manifest remains immutable. No gate whitelist or provenance exemption was added.
- `tests/test_rr42_feedback3.py`: run the motion regression alone in a tracked-only temporary copy. This handoff and `feedback3_receipts.json` record the final results.

The tracked historical director motion, historical compiled motion and build receipt are byte-identical to starting HEAD. Current staged motion and current production motion are also unchanged. The changed-file scope excludes art, motion data, gate code, shared runtime code and other figures.

The accepted native pixels remain historical evidence. The two authorized GDScript cleanups change production source hashes, so strict native freshness checks will require a fresh capture for those hashes if rerun. No old capture was rebound or relabelled; this round follows the requested focused-only proof scope.

## Chosen defaults and open issues

Chosen default: `CLEAN_COPY_TIMEOUT_SECONDS = 60`, a non-player test subprocess guard. No player-visible value was chosen or changed. No TODO_DESIGN placeholder or implementation finding remains open. The Git smoke-write limitation above remains environmental; the design owner owns full suites at merge and any fresh windowed capture.
