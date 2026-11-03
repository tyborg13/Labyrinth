# rr-42 feedback 2 — native calibration and tuck ownership

All changes are uncommitted on `codex/rr-42`. The director approved round-1 motion at 2–3×; this round changes no production art, motion, renderer code, tuning, timing or wording. The retained director-native evidence passes all gates with zero errors. The final Python-only compatibility fix preserves the legacy call-time calibration policy; the regenerated sweep, native proof and compositions all pass against its hashes. The latest full suites report one historical Python motion assertion failure and one unrelated Godot program timeout. The timed-out program passes when rerun alone under the same 180-second limit.

## Requirements

1. The four tuck failures cover **219 unchanged required coordinates**: torso 153, pelvis 21, chain 43, far arm 2. The receipt `rr42/proof/feedback2_tucks.json` records every coordinate, new owner, exact RGBA and reason. **155** requirements follow exact director-underlay receivers; **64** follow original visible owners where the director deliberately cleared procedural backing. No required mask pixel is deleted and no paint is restored, removed or synthesized. Optional `owner_bindings` in the build receipt are checked against the director partition by the Gaoler source gate.
2. The rigid raster model retains exact nearest-source candidates and uses the measured painted-node float32 transforms. Its Gaoler-only UV band is one 8-bit step (1/256); legacy defaults remain 1/512. Both original and native-origin contexts remain in the calibrated families. There is no RGB distance or changed-pixel allowance. This resolves the six head pixels and released-chain edge without an art change.
3. The terminal discrepancy is **origin-dependent float32 snapping**, not a fade. The native probe origin is (192,192); the canonical contract probe runs at (0,0). At death phase 1, the coat-tip half-pixel key resolves to y≈206 at the native origin and 207 at zero. The new headless native-origin sampler reproduces both frame-95 coat layers **exactly by the CPU default**, including the 773 visible-coat and 501 hidden-coat pixels. The latter is the thirteenth error, omitted from the director console's twelve-line summary. Native coat frames 93–95 are byte-identical. There is no final-frame waiver.
4. `rr42/proof/feedback2_native/` retains the original native layers, source/donor paint, geometry and actual sampled poses, all hash-bound. The selected 18 layers include the nine original raster failures, a held control, and eight existing arm matches that must remain valid when the model is extended. The retained whole capture is accepted only across named analysis-only Python changes; all art, motion, geometry and Godot runtime hashes must match. The original native manifest is never rewritten. Exact-pixel results can be reused only with the same full model/input/sample hashes, complete frame inventory and freshly checked native layer hashes.
5. Headless import and both full suites are required in this round. No assertions of unrelated failures are rewritten.

## Verification

```text
RR42 NATIVE CALIBRATION: PASS (18 retained layers; 0 unexplained required; frame95 exact=True)
Ran 8 tests in 4.600s
OK
Ran 35 tests in 51.562s
OK
Ran 16 tests in 6.164s
OK
RR42 SOURCE AUTHORITY: PASS (0 errors; 4589 justified clear texels)
RR42 CALIBRATED SWEEP: PASS (892 frames; 0 findings; painted_exposure=True; native_pixels=False)
RR42 NATIVE PAINTED EXPOSURE: PASS (0 errors)
RR42 ALL GATES: PASS (0 errors; native=True)
RR10 SHEETS: PASS (16 frames; experiments/cutouts/chainbound_gaoler/rr42/proof/contact_sheets)
RR10 REVIEW: PASS (957 frames; experiments/cutouts/chainbound_gaoler/rr42/proof/chainbound_gaoler_review.mp4)
TEST REGISTRATION AUDIT: PASS (841 scripts; full suite=487, quarantined=29, windowed probe=325)
MAIN BODY RUNTIME: 350.575 seconds
MAIN BODY ASSERTIONS: 495565
FULL SUITE RUNTIME: 822.731 seconds (budget 900 seconds)
TEST RESULT: FAIL (1 failure(s))
PERF03 TRANSITION DIFFERENTIAL RESULT: PASS
Ran 2004 tests in 5056.186s
FAILED (failures=1, skipped=66)
```

The latest full Godot run passed 219 of 220 standalone programs; `perf/transition_failure_case` hit its 180-second program limit. Its full-suite runtime remained within the unchanged 900-second budget. The same program passes alone under that same 180-second guard. The earlier complete run passed all 220 programs in 755.511 seconds, before the Python-only default-argument fix. The concurrent attempt and latest isolated timeout are retained below; no final full-suite success is claimed. Headless import completed with exit 0 on the 900-second retry. The first 300-second attempt timed out while scanning generated proof/capture images; the native output alone contains 75,743 PNGs. The proof wrapper now creates output-only `.gdignore` markers for captures and logs. Real asset/probe inputs remain visible. The existing macOS CA-certificate and duplicate-placeholder UID messages are retained in import logs.

The exact native painted-exposure check covers all **446 front frames**. The all-rounding CPU sweep covers all **892 front/rear frames**, and the complete native bundle verifies source ownership, tucks, calibrated pixels, components, draw order, hook contact, motion directions, support and reach. All 13 reported errors are resolved. Mutations of original fills, required paint, ownership, arbitrary native RGB, native layer bytes, provenance and cache inventory remain rejected. The 35-test compatibility run includes existing Gaoler and generic proof tests; the final eight-test suite includes both cold native-report persistence and verified positive-cache reuse. No assertion was rewritten.

The sheets and movie above were composed headlessly from the director's unchanged round-1 native capture. This is retained-native proof, not a fresh windowed run. The original capture manifest SHA-256 remains `3180050c54f6702a805238e97da70c3435b1d74ede47fc21f8bf7f6904caae71`. The calibration fixture manifest is `3d0b1241dad17952f9f91e5996fa58b5b9bdeec853fc1048a893d8123123f2cf`.

The first complete Python run reported `Ran 2004 tests in 6063.733s` and `FAILED (failures=3, skipped=66)`. Two subtest failures were caused by the optional raster default being captured at function-definition time; the 16-test run and final full run verify the corrected call-time policy without rewriting the existing calibration assertions. The sole remaining failure is the historical rr-38 kneel versus protected staged slump comparison described below. The final clean-checkout regression separately reports `Ran 31 tests in 219.587s` / `OK` and `RR39 CLEAN CHECKOUT: PASS (HEAD f6603b5a272a0c3249f7239b8a1c41d0d63916e9; 0 ignored input files; scoped fix overlay=0 files)`.

Final logs are `/private/tmp/rr42-r2-python-full-final.log`, `/private/tmp/rr42-r2-sweep-post-cache-fix.log`, `/private/tmp/rr42-r2-native-post-cache-fix.log` and `/private/tmp/rr42-r2-godot-full.log`. The final compact receipt is `rr42/proof/feedback2_receipts.json`; its log copies live under `rr42/proof/logs/feedback2_final/`.

The final-round commands were:

```sh
python3 tools/godot_task_runner.py --task-id rr-42 --timeout 900 --stream -- godot --headless --path . --import
python3 tools/godot_task_runner.py --task-id rr-42 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd
LABYRINTH_TASK_ID=rr-42 python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B -m unittest tests.test_maquette_native_raster tests.test_rr42_feedback2 -v
python3 -B experiments/cutouts/chainbound_gaoler/rr42_sweep.py --exposure
python3 -B experiments/cutouts/chainbound_gaoler/rr42_native_checks.py --native experiments/cutouts/chainbound_gaoler/rr42/proof/native
python3 -B experiments/cutouts/chainbound_gaoler/rr42_runtime_gates.py --native experiments/cutouts/chainbound_gaoler/rr42/proof/native
```

## Verification failures and causes

- The initial headless import exceeded its 300-second guard while scanning generated proof PNGs. It completed with exit 0 using a named 900-second guard, after output-only import exclusions were added. No parser or production fix was needed.
- An intermediate calibration replaced the canonical context and lost eight previously matched arm-edge pixels. Retaining both measured contexts resolved these gaps; all eight are permanent fixture controls.
- An initial retained-arm fixture omitted the existing clip recipe and donor source. Retaining those unchanged inputs made the fixture reproduce the actual source texture. No paint changed.
- An intermediate cold native-report run reached the end of all frames, then failed with `TypeError: 'tuple' object is not callable`: the frame-loop variable shadowed the cache-key function. An explicit function alias fixes it; the new cold-path test and both complete native runs pass.
- Early focused tests exposed an absent-build-receipt exception and an incorrect fixture-key assumption. The source gate now reports the missing receipt as a failure, and the fixture test selects an actual retained production key. Final focused checks pass. No existing assertion of a master failure was changed.
- The first full Python run exposed two subtest failures in `test_maquette_native_raster.NativeRasterTests.test_rr07_rotated_before_fixtures_require_the_subtexel_band` (Seer `skirt_far`/67 and Thrall `fore_near`/116). A captured default argument bypassed the tests' narrower raster-policy mutation. The optional parameter now resolves the unchanged legacy policy at call time. Both existing subtests pass in the 16-test raster/feedback-2 run.
- **Baseline failure, preserved:** `test_rr38_feedback2.Feedback2Tests.test_row_fill_pixels_are_own_painted_values_and_rest_is_exact`, line 106, compares historical rr-38 `director_motion.json` (kneel) byte for byte with the director-edited protected staged tracks (planted-feet slump). The test and both input files are unchanged from starting HEAD `f6603b5a272a0c3249f7239b8a1c41d0d63916e9`. The isolated run reports `Ran 1 test in 8.605s` / `FAILED (failures=1)`. `rr42/proof/feedback2_baseline_failures.json` retains their exact hashes. Neither the assertion nor protected/historical motion was rewritten.
- A concurrent final Godot attempt reported `FULL SUITE RUNTIME: 901.712 seconds (budget 900 seconds)` / `TEST RESULT: FAIL (12 failure(s))`. `retained_character_inventory_equivalence_test` hit its unchanged 180-second program limit. Ten programs then exhausted the full-suite budget: `perf/transition_failure_case`, `fix_14_test`, `fix_12_arrival_test`, `fix_12_reactions_0_test`, `fix_12_reactions_1_test`, `fix_12_cascades_test`, `fix_12_feedback_test`, `fix_12_bleed_test`, `short_card_tooltips_test` and `rr38/runtime_checks`. The full-suite budget check is the twelfth failure. This attempt overlapped the full Python suite, two CPU sweep workers and native pixel analysis; no assertion failure was reported by the completed programs. The exact per-program timings/reasons are retained in `rr42/proof/feedback2_concurrent_godot.json`.
- The subsequent isolated full Godot run resolved the suite-budget issue and passed retained inventory in **114.548 seconds**, but `perf/transition_failure_case` timed out after **180.243 seconds**. All other 219 programs passed. The timed-out program launches 28 nested headless engine processes for seven parent/current transition comparisons and fresh-process restart reads. Its existing focused runner (`tests/perf/run_perf03_checks.py`) allows 300 seconds, while the full-suite entry allows 180. No shared limit or test was changed. The same-180-second focused recheck exits 0 with **all seven comparisons PASS** and `PERF03 TRANSITION DIFFERENTIAL RESULT: PASS`. This resolves the program's correctness check; the full-suite timeout remains recorded.

The final full run's **66 skips** comprise 6 tests requiring the pinned Python 3.12 audio environment; 41 missing optional `soundfile`, `scipy` and `pyloudnorm`; 16 missing optional `mido` and `music21`; 2 opt-in director Blender-bridge tests; and 1 explicitly unadopted rr-27 Tether study. No dependencies were added and no skip policy was changed. Every skipped test and its exact reason is retained in the final receipt.

Known worktree gaps from the preceding round were bootstrapped before the full suites: the import rebuilds emblem imports and the `GameData` cache; the empty generated `experiments/cutouts/briar_weaver/mq9/proof/logs/` directory was initialized for existing rr-21 temporary fixtures. No Briar Weaver source or assertion changed. Intentionally interrupted development runs are not counted as passing results.

## Files

- `rr42_tucks.py`, the case build receipt and per-coordinate tuck receipt; hooks in `rr42_build.py` and `rr42_gates.py`.
- `rr42_raster.py`, `rr42_sampling.py`, `tests/rr42/native_samples.gd` and UID; consumers in `rr42_exposure.py`, `rr42_sweep.py` and `rr42_native_checks.py`.
- `rr42_retained.py`, `rr42_calibrate_native.py`, `rr42_native_cache.py`, `rr42_compose.py`, the immutable native fixture and calibration receipt.
- `rr42_proof.sh`, `rr42_runtime_gates.py`, the final receipt collector, and eight focused tests in `tests/test_rr42_feedback2.py`.
- `rr42/proof/feedback2_{baseline_failures,bootstrap,concurrent_godot,receipts}.json` and this handoff retain the complete execution results and causes.
- Optional/additive interfaces in `tools/humanoid_cutout/{gates,proof}.py` and `tools/maquette_motion/{pixels,raster}.py`; other figures keep their default paths and numerical behavior.

## Proof for the design owner

Run from this worktree, at 1920×1080 and 100% scale, then inspect at 2–3×:

```sh
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh native
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh sheets
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh review
```

Native captures: `rr42/proof/native/`; 3× sheets: `rr42/proof/contact_sheets/`; movie: `rr42/proof/chainbound_gaoler_review.mp4`. Worker execution uses only headless samplers and retained-native analysis/composition. No windowed run, peer review, sign-off, publication, commit, push, branch change or queue edit is authorized for this worker.

The original brief's other windowed entry points remain available; the feedback-2 rerun requests only the three commands above:

```sh
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh density
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh rest
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh idle
sh experiments/cutouts/chainbound_gaoler/rr42_proof.sh production
```

## Chosen defaults and remaining work

New proof choices: 900-second cold-import guard and 1800-second full-Godot outer guard; corruption-fixture RGBA (254,7,199,255), zero/one SHA-256 mutation strings and the constructed cache-model marker. These are named arguments/constants. Existing 4-frame shards, 2 workers, 180-second shard deadline, 128-triangle raster batches, 12 px crop context and 4× crops are retained. Native origin (192,192) is the existing capture registration; the UV step is a calibrated model value. No player-facing value is chosen.

No TODO_DESIGN placeholder is unresolved. The director's fresh windowed rerun remains pending. The unchanged historical rr-38 motion assertion remains open; the full-suite transition timeout is recorded alongside its passing focused recheck. No new visual defect or motion clamp was found.
