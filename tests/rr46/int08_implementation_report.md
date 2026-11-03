# int-08 integration repair

Feedback 2: the director accepted round 1 and authorized the int-07 audit repair. The previous ownership blocker is resolved; final focused results are recorded at the end. Earlier full-suite results remain historical evidence and were not rerun.

Worktree: `/Users/borgerding/workspace/Labyrinth.worktrees/int-08`, branch `codex/int-08`, base `698720ea1fa509d594d5570d82a0d71cc24b2a02`. Risk tier: standard. All edits remain uncommitted. No product code, design-owner data, art, audio or fonts were changed. No Git metadata writes, branch changes, peer reviews or windowed runs were performed.

## Recorded acceptance criterion

The existing director-owned contract was read with `python3 tools/parallel_task.py status` and not modified:

> Every failure already red at ff77c892c is root-caused and fixed or re-pinned with an audit; no guard weakened; hero_facing Frostbite fixture legal under bos-04; orphan sidecars removed

Required proof: both full suites serially, re-pin mutations, failure table and native depth command list. Inspection: not applicable, test/pin repair with no player-facing change. Preflight, commit, review, inspection and publication remain the director's responsibility.

## Numbered requirements

1. **Lancer approved inputs.** `integration_extensions.json` records the original rr-46 and approved rr-45 `999caa5e3` Git blobs and SHA-256 for front layout, rear layout and integration bindings. Independent structured comparison proves only front `/parts/8/z_index` and rear `/parts/6/z_index` changed in the layouts. The integration file has its own exact byte pin. No production asset was edited. All three same-file byte mutations fail.
2. **Historical runtime.** `runtime_extensions.json` records all twelve exact first-parent transitions for `run_scene.gd` and `combat_board_view.gd`, each with before/after Git blob IDs, SHA-256, unit and decision. The nine named integrations are card-02, sum-01, bos-01, enc-04/enc-03, int-06, bos-03, hf-01, rr-46/rr-47 and bos-04. `before_integrated_runtime` accepts only the exact final audited bytes, checks the historical sealed blob, and maps back to the original rr-46 base for comparison. Same-file mutations fail for both runtime files. pt14 still uses the independent, literal rr-46 reversal and does not inherit the wider runtime approval.
3. **Authored copy.** `integration_extensions.json` records the full before/after hashes for the int-06/sum-01 director reward copy and bos-02 Hollow Gale copy. Structured comparison proves exactly six changed fields across entries 70 and 75; the approved file also gains its final newline. A same-file unapproved byte fails. All other authored/reference inputs retain their existing pins; int-07's 80-file ledger and its audit remain intact.
4. **Native inventory.** Regenerated headlessly using the unchanged production exporter. The complete candidate differs from int-07's inventory in exactly three source hashes: Lancer integration (rr-45), board view (sum-01/enc-04/rr-46/rr-47), room generator (bos-02). Every other field is identical, including coverage, timing, budgets, drawn primitives and routes. `native_extensions.json` records all three exact before/after hashes and decisions. Each mutated source fails the actual inventory loader in a private immutable-input tree. The strict archive verifier rejects an archive carrying the old inventory seal before image verification; no fake passing archive was created. The current inventory SHA-256 is `0fc1fab9f32fa30c11562a3b940356d4e42062ae6de17d4b458e77d8178c893a`.
5. **pt14 boundary.** Added only bos-04 `12bb98b9a`'s exact load, combat-entry and combat-exit reset callers. Tests reverse them to that commit's byte-identical parent and audit their full integrated before/after hashes through the runtime ledger. All three changed-caller mutations and an extra unowned runtime byte fail. No performance assertion or timing allowance changed.
6. **Hero-facing fixture.** Read-only historical replay brackets the failure at the bos-04 merge: `2309a2a1e^` passes all 76 checks, `2309a2a1e` fails only `Frostbite fixture really deals damage`. Holding the post-merge snapshot constant, replacing only `battlefield_rules/frostbite.gd` with the pre-`12bb98b9a` version passes all 76; replacing it with `12bb98b9a`'s version fails that same assertion. The causal line changes `Surfaces.tiles` to `Surfaces.fuel_tiles`; surface placement stamps the current player activation, so freshly laid Ice cannot fuel that beat. The rule is correct. The owned fixture now uses the existing `mature_fuel` helper after laying Ice, modelling one earlier player activation, and preserves both the damage and facing assertions. Current fixture: `HERO FACING TEST: PASS (76 checks)`.
7. **Orphan sidecars.** Deleted exactly the six tracked rr-48 PNG imports named in the brief after confirming each source PNG is absent. No other rr-48 file was changed. The sidecar guard passes with unstaged deletions.

## Verification evidence

Logs are relative to this worktree under `output/int-08/`; these are scratch evidence, not native captures.

- One-time headless import through the int-08 runner: exit 0, `import.log`. It initialized the fresh worktree's resource cache; no editor scan was used as a parser check.
- Historical merge replay: `historical-replay.log`, `before-bos04-hero-facing.log`, `after-bos04-hero-facing.log`. Before: exit 0, `HERO FACING TEST: PASS (76 checks)`; after: exit 1, `ERROR: Frostbite fixture really deals damage`, `HERO FACING TEST: FAIL (76 checks)`.
- Causal one-file replay: `frostbite-line-bisect.log`, `after-bos04-before-frostbite-hero-facing.log`, `after-bos04-r0-frostbite-hero-facing.log`. Pre-r0 resolver: exit 0, `HERO FACING TEST: PASS (76 checks)`; r0 resolver: exit 1, same sole Frostbite assertion. All historical files came from read-only Git archives/objects in temporary projects. No bisect state or alternate index was written.
- Headless inventory: `native-inventory-candidate.log`, exit 0, `RR46 NATIVE CASE INVENTORY: 2 boards; 20 jobs; 20 deaths; stride 2 move/retreat plus every midpoint neighbour, stride 1 death; res://output/int-08/native-inventory-candidate.json`. Complete field comparison: `INT08 HEADLESS INVENTORY DIFF: PASS (exactly 3 source hashes; every other field identical)`.
- Initial focused pins: `pins-focused.log`, exit 0, `Ran 8 tests in 2.102s`, `OK`; includes `RR46 frostglass_lancer PRESERVATION: PASS (221 protected files)`, `RR46 AUTHORED PRESERVATION: PASS (480 byte-identical protected files vs e3034e24fd81)` and the pt14 frozen boundary pass.
- Final mutation/sidecar checks: `pins-sidecars-final.log`, exit 0, `Ran 23 tests in 3.585s`, `OK`. Exact witnesses:
  - `INT08 PRESERVATION AUDIT: PASS (rr-45 spear depth only; int-06/bos-02 six copy fields; 4/4 same-file byte mutations rejected)`
  - `INT08 RUNTIME AUDIT: PASS (12 exact transitions across 9 named units; 2/2 same-file byte mutations rejected)`
  - `INT08 INVENTORY AUDIT: PASS (only 3 approved source hashes changed; every coverage/timing/route field identical; 3/3 source mutations and old archive seal rejected)`
  - `INT08 PT14 BOUNDARY MUTATIONS: PASS (bos-04 exact caller reversal; 3/3 caller mutations and unowned byte rejected)`
- Current headless facing fixture: `hero-facing-final.log`, exit 0, `HERO FACING TEST: PASS (76 checks)`.
- Python resource audit: `python-audit.log`, exit 0, `ISOLATION AUDIT: 264 modules`. The new module declares live Lancer readers and the pt14 module dependency. Native mutation projects use Git-frozen inputs; all writes stay in per-test temporary directories. The explicit imported-module edge is colocated by the audited suite runner.

- Affected suites: `affected-focused.log`, exit 0, `Ran 31 tests in 255.785s`, `OK`. Command: `python3 -m unittest -v tests.test_rr46_playback tests.test_rr47_feedback1 tests.test_rr47_feedback2 tests.test_pt14_04_coverage`. This covers scaling/death/depth/painter negative controls, authored gait, native coverage/calibration, rr-47 midpoint/corner and framing mutations, and pt14 instrumentation/parity/performance.
- Final bos-04 caller mutation simplification: `bos04-mutations-final.log`, exit 0, `Ran 1 test in 0.114s`, `OK`, same three caller and unowned-byte rejection witness.
- Final resource audit: `python-audit-final.log`, exit 0, `ISOLATION AUDIT: 264 modules`.

- Full Godot, run once after the last test-code change: `python3 tools/godot_task_runner.py --task-id int-08 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd`, exit 1, `godot-full.log`. `MAIN BODY ASSERTIONS: 495984`; `FULL SUITE RUNTIME: 710.264 seconds (budget 900 seconds)`; `TEST RESULT: FAIL (1 failure(s))`. All 262 registered program results completed (`godot-program-suites.json`). `PROGRAM SUITE hero_facing_test: PASS`; `PROGRAM SUITE card_display_performance_test: PASS`. The only failing program was `threats_at_rest_test`: `THREATS AT REST TEST RESULT: FAIL (1 failures / 16950 assertions)`, six-enemy layout median/p95 within 5%. Its metrics were pt14-04 median 5.043 ms / p95 6.119 ms versus current median 5.199 ms / p95 6.497 ms. The median fits the guard, the p95 does not. Full child log retained as `threats_at_rest_test-full-failure.log`. No production file, test guard or budget changed; the isolated follow-up below passes without changing this guard.
- The driver `run_full_serial.py` waited for Godot to exit before starting Python. `full-suite-driver.log` and `full-suite-results.json` retain sequence, commands and observed exits. No full suites overlapped, and neither full suite is being repeated.

- In the full Python run, int-07's unchanged independent witnesses pass: `INT07 PIN MUTATIONS: PASS (80/80 same-file unapproved byte changes rejected, including added caps)`, `INT07 EXTENSION AUDIT: PASS (80 exact rr-44/rr-49 deltas; 26 additions; no earlier integration absorbed)` and `INT07 OTHER RIGS: PASS (664/664 submitted states byte-identical to ff77c892c; 12 rigs; both views; every clip)`. Its protected inventory audit records the ownership conflict documented below.

- Full Python was launched once with `python3 tools/run_python_suite.py --shards 4 --output-dir output/int-08/python-full`, after full Godot exited. All four worker result records are complete: 264 distinct modules, 2,532 executed tests, one failure, zero errors, 66 existing optional-environment skips, zero import-guard violations. Shards 2, 3 and 4 have zero failures/errors; shard 1 has only the protected int-07 inventory audit failure described below. All four new int-08 witnesses pass in shard 2. The final rr-49 checks also pass: `RR49 EXACT IDENTITY: PASS (8364 poses; 304685 polygon buffers; actual one-vertex mutation caught)` and the cost/reload mutation witnesses.
- **Parent-session limitation and recovery:** after the director's capacity continuation, `write_stdin` for the original session failed with `Unknown process id 2063`. The workers continued and wrote all four result JSON files, but the original parent emitted no final summary/exit; `full-suite-driver.log` ends at `START FULL PYTHON` and `full-suite-results.json` contains only the observed Godot exit. The sandbox also prevents process-list inspection (`pgrep: Cannot get process list`; `sysmon request failed with error: sysmond service not found`). No parent exit code or parent wall time is claimed. Used the existing `run_python_suite.summary` function to recover an aggregate from the completed records without rerunning tests. Audited all four invocation IDs as distinct, each complete assigned module set, all test-ID counts and zero import-guard violations, and recorded SHA-256 seals for the result files in `python-full/recovered-summary.json`. Observed recovery lines in `python-recovered-summary.log`: `Ran 2532 tests in 1885.793s`; `FAILED (failures=1, skipped=66)`. The displayed duration is the measured longest completed shard (1,885.792732708 seconds), **not** an observed parent wall time. The recovery log explicitly labels this distinction.
- Isolated timing follow-up, after all four full-Python worker records were complete: `python3 tools/godot_task_runner.py --task-id int-08 --stream -- godot --headless --path . --script tests/threats_at_rest_test.gd`, exit 0, `threats-at-rest-isolated.log`: `THREATS AT REST TEST RESULT: PASS (16950 assertions; includes compass suite)`. Exact metrics: `PT15 VS PT14-04: warband_air_3_crowd (6 enemies) pt14-04 median=4.864 ms p95=5.592 ms; cached-sole median=4.892 ms p95=5.785 ms`. Both values fit the unchanged 5% guard. Git comparison against `698720ea1` reports no changed production scripts/assets/data, no change to `threats_at_rest_test.gd`, its threats/intent-chip suites or `pt14_01_source_suite.gd`. The full-run failure is environment-sensitive timing, with identical source inputs and a passing isolated replay; it remains recorded as a full-run failure. Neither full suite was repeated.

- Final scope audit: `INT08 FINAL SCOPE AUDIT: PASS (14 tracked paths; only owned edits; product and protected tests unchanged; inventory seal unchanged)`. Six new deliverable files are listed below. Final `git diff --check`: exit 0.

### Final failure table

| Check | Full-run result | Follow-up / action |
| --- | --- | --- |
| `threats_at_rest_test` | Sole full Godot failure: six-enemy p95 exceeds unchanged 5% timing guard; all 262 programs completed | Isolated replay passes all 16,950 assertions; relevant input bytes identical to base. No guard, budget or product change. |
| int-07 native inventory audit | Sole Python failure in 2,532 completed tests; zero errors | Protected module requires the exact three additional native-binding allowances below. New owned audit and all mutations pass. |

**Contract status:** all seven owned repairs are implemented and verified; every original failure is addressed in its owned guard/fixture. Aggregate verification is not fully green because the protected int-07 audit needs a director-side ownership decision/update. The transient full Godot timing failure and unavailable Python parent exit are reported rather than erased. Native renderer proof remains the director's explicitly assigned step. Native capture remains the director's windowed work; exact 20-job and verifier commands are in [int08_proof_for_design_owner.md](int08_proof_for_design_owner.md).

## Round 1 ownership conflict (resolved in feedback 2)

`tests/test_int07_preservation.py::IntegrationPreservationTests::test_native_inventory_only_rebinds_approved_gaoler_sources` freezes the entire live inventory to int-07's two Gaoler-only changes. The now-authorized three additional source bindings necessarily fail its final equality. Focused replay: `int07-inventory-audit.log`, `Ran 1 test in 0.082s`, `FAILED (failures=1)`. This is a stale audit expectation introduced by the int-08 rebind, not a product failure or environmental exemption. That module lies outside the brief's owned file list; an early asynchronous scope clarification is pending. It has not been edited or bypassed. The new owned audit independently proves all three exact additional bindings and that every other field remains identical. The concrete director-side fix is to extend that audit with `native_extensions.json`: for each of its exact three entries, assert that the original inventory hash equals `before_sha256` and the live inventory hash equals `after_sha256`, then restore that entry in the comparison copy before the existing final whole-document equality. Keep the two Gaoler assertions, the equality assertion and all three new mutation witnesses. This preserves the guard rather than dropping any comparison.

## Files changed

- `tests/rr46/preservation.py`: combine disjoint, independently audited int-07 and int-08 exact preservation ledgers.
- `tests/rr46/integration_extensions.json`: four exact rr-45/int-06/bos-02 before/after pins.
- `tests/rr46/runtime_preservation.py`, `runtime_extensions.json`: exact integrated runtime seal and twelve named historical transitions; retain independent pt14 literal reversal.
- `tests/rr46/native_inventory.json`, `native_extensions.json`: three regenerated bindings and their before/after audit.
- `tests/rr46/verify_native.py`: optional temporary source root for real loader mutation tests; default production behavior unchanged.
- `tests/test_rr46_integration_pins.py`: pin, field-delta, historical chain, caller, mutation and archive-seal witnesses.
- `tests/test_rr46_playback.py`: use exact integrated runtime pin, retaining missing-clock-anchor rejection.
- `tests/test_pt14_04_coverage.py`: three exact bos-04 caller allowances.
- `tests/hero_facing_test.gd`: mature the Frostbite fuel fixture one player activation.
- `tools/python_suite_resources.json`: audit registration for the new test module.
- Six deleted `spec/peer_benchmark/staged/rr-48/*.png.import`: `front_body_underlay`, `front_underlay_raw`, `rear_body_underlay`, `rear_underlay_raw`, `ref_front_approved_x4`, `ref_rear_approved_x4`.
- This report and `tests/rr46/int08_proof_for_design_owner.md`: evidence and exact owner commands.

## TODO_DESIGN placeholders / Chosen defaults / open issues

No new `TODO_DESIGN_*` placeholder and no new player-visible value. The existing Seer gait placeholder in rr-46 remains unchanged and is outside this repair.

Chosen proof-only defaults: `UNAPPROVED_BYTE = b'\n'` in the new module; temporary-directory prefixes and scratch/archive paths. Existing 900-second full Godot budget and 330-second windowed capture timeout are retained for their documented command behavior. Source revisions, source hashes, transition counts and test totals are observed facts, not chosen tuning.

Round 1 open work (superseded by feedback 2 below): the protected int-07 inventory audit clarification/update above; fresh native depth archive capture and verifier result on the director's machine. The full Godot timing failure passes in isolation with unchanged inputs; all Python test records are complete, but the original parent summary/exit was unavailable after continuation and is explicitly recovered above. No product regression was found. The director owns committing, peer review, inspection and publication.


## Feedback 2: int-07 inventory audit resolved

The director accepted round 1, assigned `tests/test_int07_preservation.py` for this repair, accepted the `threats_at_rest` timing failure as environmental, and reserved quiet full suites for merge. This feedback changes only that test module and this report. The director's active native capture directory was not accessed or written, and neither the inventory nor `depth_probe.gd` was modified.

- Added exactly three literal before/after SHA-256 pairs in `INT08_NATIVE_REBINDINGS`: Lancer integration, board view and room generator. Each has an int-08 comment naming its originating units. The pairs exactly match `native_extensions.json`.
- Kept every original assertion, including the two Gaoler bindings and final whole-document equality. The 80-file extension audit, its mutation test, and the other-rig submission test are unchanged. An AST audit verifies the original assertions and unchanged methods.
- Added a direct mutation witness against the actual inventory audit. A fourth unapproved rebind of existing `scripts/path_utils.gd`, and a newly added source binding, both fail. Mutations are in-memory `Path.read_text` patches; no inventory or production file is written.
- No other affected check imports `test_int07_preservation`; the focused run includes the complete int-07 module and every `test_rr46_*.py` module. Existing resource declarations remain valid: no new test module, cross-test import or shared write was introduced.

Observed proof (paths relative to this worktree):

- `output/int-08/feedback2/audit.log`: `INT08 FEEDBACK2 AUDIT: PASS (3 exact before/after rebindings; every original assertion retained; 80-file and other audits unchanged; capture inputs unchanged)`.
- `output/int-08/feedback2/focused.log`: **Ran 32 tests in 193.566s**, **`OK`**, exit 0. Exact module command is retained in `output/int-08/feedback2/command.json`; the runner result and duration are in `result.json`.
- `INT07 INVENTORY AUDIT: PASS (two approved Gaoler and three exact int-08 source bindings; all coverage/timing/route fields preserved)`
- `INT08 FOURTH BINDING MUTATIONS: PASS (unapproved source rebind and added binding both rejected)`
- `INT07 EXTENSION AUDIT: PASS (80 exact rr-44/rr-49 deltas; 26 additions; no earlier integration absorbed)`
- `INT07 PIN MUTATIONS: PASS (80/80 same-file unapproved byte changes rejected, including added caps)`
- `INT07 OTHER RIGS: PASS (664/664 submitted states byte-identical to ff77c892c; 12 rigs; both views; every clip)`
- All ten rr-46 family preservation checks pass, along with the integration pin, playback, timing, gait, depth, painter, archive and routing controls. No full suite was rerun.
- `git diff --check`: exit 0. Inventory SHA-256 remains `0fc1fab9f32fa30c11562a3b940356d4e42062ae6de17d4b458e77d8178c893a`; depth probe still matches its sealed source hash.

TODO_DESIGN: none added. Chosen test-only defaults: `UNAPPROVED_NATIVE_REBINDING = 'scripts/path_utils.gd'` and `UNAPPROVED_NATIVE_ADDITION = 'scripts/int08_unapproved_binding.gd'`; the invalid digest reuses the existing `UNAPPROVED_BYTE`. No product values changed.

The round-1 ownership blocker is closed. Quiet full-suite rechecks and the in-progress native archive verification remain director-owned. All changes remain uncommitted; no Git metadata writes, branch changes or peer review were performed for this feedback.
