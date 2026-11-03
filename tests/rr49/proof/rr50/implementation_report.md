# rr-50 implementation and evidence

Branch `codex/rr-50`, starting HEAD `6135c6ec6c9c2ac63a91545e27f74aa79c964ce0`.
Risk tier: standard. The owner supplied the contract/preflight and owns commit,
peer review, inspection and publication. All implementation changes are uncommitted.

## Acceptance criteria

1. **Timing guard catches the production mutation.** The exact reviewer patch
   and original clean/mutated JSON were copied first into `reviewer/`, unchanged.
   `paired_cost.gd` switches production mesh helpers between the optimized groups
   and the same generic float64 fallback at each exact pose. Both caches are
   disabled for the pair; order alternates per pose/round. Each view measures
   1,071 matched samples per implementation: seven motion clips x 51 poses x
   three rounds. The minimum ratio is 1.6, independent of timing headroom.
   Existing absolute 2,000/3,000/500 us limits and 2.0 CI headroom remain intact.
   The Python guard requires five clean runs. Reviewer-patch speedups were
   0.9921 front / 1.0010 rear: rejected. Initial clean five-run speedups were
   2.0044–2.1810. See `timing-five.log` and the final full Python shard output.
2. **Obsolete hash removed.** Production `register_mesh` only stores its shallow
   source copy; it no longer serializes/hash-compiles the definition or stores
   `_stable_definition`. The memory probe rejects that field in live metadata.
   The immutable legacy scalar fixture still requires its historical key, so
   only benchmark setup supplies it when `--legacy-submission` is selected.
   Frozen fixtures and their manifest are unchanged.
3. **Bounded cache memory and retained performance.** Motion and idle now share
   one per-mesh 16-entry LRU budget. Each mode can reach 16 when used alone.
   Two independent full 16-entry buffers would use 6.24 MiB front / 5.50 MiB rear,
   so sharing retention is necessary to meet the combined 4 MiB requirement.
   The probe fills each mode, exercises mixed occupancy, checks hit refresh and
   cross-mode oldest-entry eviction, and counts actual packed buffers plus keys.
   Full payload peaks: front 3,312,640 bytes; rear 2,920,192 bytes. A real capacity
   mutation to 128 exceeds the memory budget in both views and fails. Three rigs
   interleave before each exact repeat; each repeat must be a hit. A 51-pose
   cycle repeat would deliberately exceed the requested 16-entry working set.

## Preservation and pins

The only production paths changed are `stable_paint.gd` and `stable_skin.gd`.
`runtime_binding_changes.json` records their exact before/after SHA-256 with an
rr-50 comment and the immutable starting revision. `runtime_provenance.py`
validates the exact two-path inventory, Git before-images, live after-images,
and complete fresh pose/report digest before normalizing those two hashes.
The small integration in `test_rr41_feedback3.py` then runs int-07's original
rr-46/pt14-04/fix-18 normalization and requires the **complete historical pose
seal**. No art/motion/certificate fixture is re-sealed or rewritten.
Both same-file unapproved-byte controls and an unknown-path record fail.
Existing unknown-binding, bone-transform, runtime-byte, forged-hash and forged
fix-18 membership controls all pass. See `rest-pins-final.log` and `pins-final.log`.

Byte-identity is unchanged: 8,364 poses, seed 4903, 304,685 submitted buffers;
the actual one-vertex mutation is caught. All 664 other-rig submitted states
match the frozen premerge baseline (12 rigs, both views, every clip).
No time quantization or float64 expression/accumulation changes were made.

## Focused proof

- `identity.log`: `Ran 2 tests in 19.179s`, `OK`;
  `RR49 EXACT IDENTITY: PASS (8364 poses; 304685 polygon buffers; actual one-vertex mutation caught)`;
  `INT07 OTHER RIGS: PASS (664/664 submitted states byte-identical to ff77c892c; 12 rigs; both views; every clip)`.
- `timing-five.log`: `Ran 1 test in 105.853s`, `OK`;
  `RR50 CLEAN TIMING: PASS (5/5 paired and absolute guards under task runner)`.
  Worst clip median over those runs was 1,901 us; worst individual sample was
  3,304 us under the unchanged 2.0 headroom. Run 4 observed 1,466 / 2,475 us.
  Raw sample jitter above the unmultiplied 3 ms target is retained in the log.
- `cache-pins-final.log`: `Ran 2 tests in 2.765s`, `OK`;
  `RR50 CAPACITY MUTATION: PASS (128 exceeds 4 MiB in both views)`.
- `cache-legacy-final.log`: `Ran 1 test in 13.399s`, `OK`;
  `RR49 COST MUTATIONS: PASS (disabled cache loses repeat hits; legacy per-mesh scalar path exceeds timing budget)`.
- `mutations-reload.log`: production fast-path mutation passed its negative
  control and reload passed; this earlier run exposed the legacy fixture key
  dependency. That dependency is fixed and verified in `cache-legacy-final.log`.
- `rest-pins-final.log`: `Ran 3 tests in 102.220s`, `OK`;
  `RR41 REST/DENSITY RESEAL: PASS (complete historical pose digest recovered; both rest images, zero mismatches and density bindings unchanged)`.
- `native-headless.log`: `Ran 5 tests in 56.984s`, `OK`;
  52/52 retained native findings replayed; 892 fresh submitted-geometry frames,
  100 idle frames and 1,184 root-transform checks pass. This is headless proof,
  not a new native capture.
- `canvas-equivalence.log`:
  `V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}`;
  `PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}`.
- `python-audit.log`: `ISOLATION AUDIT: 263 modules` (exit 0). No new Python test
  module was added; mutation writes remain in per-test temporary projects. The
  existing Gaoler resource declaration remains sufficient.
- `registration.log`: `TEST REGISTRATION AUDIT: PASS (916 scripts; full suite=549, quarantined=29, windowed probe=338)`.

Initial development diagnostics caught a native-class constant name collision
(`Skin`, renamed `StableSkin`), the frozen legacy metadata dependency, and the
need to validate live rr-50 hashes before int-07's historical normalization.
All were fixed before full suites. The initial broken cost process ended at its
300-second runner deadline; final cost invocations use the inherited 120-second
guard. The denied process-list/signal attempts made no filesystem changes.
`legacy-cost.log.gz` retains the superseded fixture diagnostic.

## Full suites and baseline comparisons

Full Godot ran once after the final implementation change, through the required
900-second runner, and exited 1:

```text
MAIN BODY RUNTIME: 269.493 seconds
MAIN BODY ASSERTIONS: 495984
FULL SUITE RUNTIME: 813.421 seconds (budget 900 seconds)
TEST RESULT: FAIL (5 failure(s))
```

All 262 programs completed; 257 passed. `godot-programs.json` retains each child
result and `godot-failures/` retains all five failing logs. Peer replays use the
unchanged program scheduler/bootstraps and existing copied peer class/UID cache
plus read-only imported textures; no editor/import scan ran.

| Godot child | rr-50 full run | Frozen peer-benchmark replay |
| --- | --- | --- |
| special_encounter_test | FAIL, two assertions: approved/director emblem imports unavailable | PASS, exit 0, 53.056s with existing imports |
| enemy_no_action_test | GameData undeclared at enemy_no_action_suite.gd:36,128; unchanged 180s child deadline, exit 124 | PASS, exit 0, 24.299s with existing class cache |
| fix_11_test | Same GameData compile failure, exit 1 | PASS, exit 0, 16.507s |
| fix_11_probe | Same GameData compile failure, exit 1 | PASS, exit 0, 5.274s |
| hero_facing_test | FAIL: Frostbite fixture really deals damage | Same assertion FAIL, exit 1, 4.464s |

The first four are known bootstrap/cache failures, with unchanged sources;
the fifth reproduces directly. No assertion was altered. `peer-godot.json` and
`peer-godot.log` contain the complete comparison. The source snapshot is in
`/private/tmp/labyrinth_codex/rr50-peer-snapshot`, outside test discovery.

The focused frozen-peer Python replay observed `Ran 7 tests in 7.966s`,
`FAILED (failures=5, errors=3)`. `peer-python-final.log` contains all identities
and tracebacks. The sidecar case uses the exact frozen Git inventory and the
actual read-only peer worktree for `git check-ignore`; other cases execute
unchanged in the snapshot. An earlier raw-snapshot sidecar attempt failed its
Git context, rather than the guard; the corrected replay restores the actual
Git context without changing any assertion. `peer-sidecars.log` independently
lists the six same tracked orphan rr-48 PNG sidecars.

Full Python ran once, through the four-shard coordinator, and exited 1:

```text
Ran 2525 tests in 2069.065s
FAILED (failures=6, errors=3, skipped=66)
PYTHON SUITE WALL: 2069.065s
```

All 263 modules and four matching shard results completed, with zero import-guard
violations. Every rr-50 submission test passed in the full run (148.156s):
`RR50 CLEAN TIMING: PASS (5/5 paired and absolute guards under task runner)`;
`RR50 CAPACITY MUTATION: PASS (128 exceeds 4 MiB in both views)`;
`RR49 EXACT IDENTITY: PASS (8364 poses; 304685 polygon buffers; actual one-vertex mutation caught)`;
`RR50 FAST-PATH MUTATION: PASS` (ratios 0.99854 / 0.99954);
`RR50 PIN AUDIT: PASS`; and `RR49 RELOAD: PASS`.
Clean paired ratios in the full coordinator were 1.9573–2.1749; worst absolute
clip median/max were 1,496/2,471 us. Both views' three-rig repeats remained hits.

| Python failure/error | Peer-benchmark | Final disposition |
| --- | --- | --- |
| test_godot_sidecars.GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources | Same FAIL: six orphan rr-48 PNG sidecars | Pre-existing; retained |
| test_rr46_preserve_frostglass_lancer.PreservationTests.test_approved_inputs_are_byte_identical | Same FAIL at front.json pin | Pre-existing; retained |
| test_rr46_playback.PlaybackTests.test_historical_runtime_pin_rejects_unowned_changes | Same FAIL in historical run_scene bytes | Pre-existing; retained |
| test_rr46_playback.PlaybackTests.test_motion_and_reference_inputs_are_byte_identical | Same FAIL at tt-01/tooltips.json | Pre-existing; retained |
| test_pt14_04_coverage.HeroCoverage.test_runtime_boundary_and_reverts | Same FAIL, reset vs baseline caller | Pre-existing; retained |
| test_rr46_playback.PlaybackTests.test_native_archive_requires_complete_painted_coverage | Same ERROR, stale Lancer integration inventory | Pre-existing; retained |
| test_rr47_feedback1.FeedbackOneTests.setUpClass | Same ERROR from inventory | Pre-existing; retained |
| test_rr47_feedback2.FeedbackTwoTests.test_omitting_native_midpoint_and_corner_route_fails | Same ERROR from inventory | Pre-existing; retained |
| test_test_registration_audit.RegistrationAuditTests.test_repository_headless_registration_guard | PASS | Worker proof-output mistake corrected; focused unchanged guard PASS |

The ninth entry was caused by this worker's peer replay placing five generated
bootstrap `.gd` files in `peer-godot.logs/` under the test tree. They were moved
outside test discovery to `/private/tmp/labyrinth_codex/rr50-peer-godot.logs`;
no assertion or production/test source changed. The unchanged focused guard now
reports `Ran 1 test in 5.975s`, `OK`, and the peer guard reports `Ran 1 test in
5.912s`, `OK`. This original full-run failure remains in the recorded total;
it is not silently subtracted or attributed to baseline. The full suites were
not repeated after moving generated proof artifacts.

`results.json` includes every identity/traceback and peer classification. Full
shard logs/results and the coordinator summary are retained in `python-full/`.
The expected optional timing-cache write was denied by read-only Git metadata:
`Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted`.
All tests still completed normally. No alternate index or Git metadata was made.

Final `git diff --check` passes. All three supplied reviewer evidence files
remain byte-identical to their originals. The complete changed-file inventory
is in `changed_files.txt`; no protected art, motion, other-rig or source-data
file moved. HEAD remains the supplied `6135c6ec6`, and everything is uncommitted.

Full commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && python3 tools/godot_task_runner.py --task-id rr-50 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-50 && python3 tools/run_python_suite.py --shards 4 --output-dir tests/rr49/proof/rr50/python-full
```

Open issues: the eight pre-existing Python failure/error cases, known Godot
bootstrap failures and the pre-existing Frostbite fixture. Fresh windowed
native/sheets/production proof remains the director's step. No unresolved
rr-50 implementation or test failure remains after the artifact correction.
The compared `codex/peer-benchmark` revision is frozen in `peer-snapshot.json`.
Only read-only Git/source access was used; no metadata write, branch operation,
commit, push, review, or windowed run occurred.

## Files and defaults

Runtime: two owned scripts. Tests/helpers: `submission_cost.gd`, new
`paired_cost.gd` and `cache_payload.gd` with UID sidecars, `runtime_provenance.py`,
`runtime_binding_changes.json`, and `test_rr49_submission.py`. Pin integration:
a small hook in `test_rr41_feedback3.py`; no existing failure assertion changed.
Proof/defaults: this folder and its parent `.gdignore`.

No `TODO_DESIGN_*` placeholders. No player-visible decisions or new assets.
Named proof-only defaults are in `chosen_defaults.json`: three pair rounds,
three warmup poses, a 0.001 transform-key step, identity-matrix synthetic pin
bones and a newline mutation. Five runs and the 16-entry/4 MiB/1.6x limits are
prescribed. The 120-second per-invocation timeout and 2.0 headroom are inherited.
Windowed native/sheets/production commands and capture paths are in
`proof_for_design_owner.md`; inspection is not applicable per the owner contract.
