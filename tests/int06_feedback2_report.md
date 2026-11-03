# int-06 feedback 2 — regeneration parity and strict golden guard

Base: accepted `fd6b56faa`, clean at the start of this round. All changes remain uncommitted. No peer review, publication, full suite, Blender job or windowed run was performed.

## Findings and acceptance

| # | Finding / cause | Fix and proof |
|---|---|---|
| 1 | Generators copied today's shared files while validation hashed their historical unit-end bytes. Storm Cantor stopped before compilation; Lamplighter produced an unacceptable inventory. | `input_bytes` now owns the selection used by both hashing and materialization. Both generators write that selected closure, independently re-hash the actual copied files and require exact membership/hash parity before invoking the clean compiler or any native work. Native inputs belonging to each figure remain live; shared/foreign inputs remain historical. |
| 1 | The generation path itself lacked coverage. | Both `regenerate()` functions run their real copy and Python compilation stages in temporary projects, then stop at a mocked first native boundary. Tests compare the resulting inventory against validation and re-hash every copied declared file. A corrupted copied shared renderer must stop before the compiler or native work. Before the fix, the new controls reproduced Storm's `Copied clean inputs differ from current sources` and Lamplighter's mismatched inventory (`regeneration-before.log`). All four new tests pass in the final maquette run. |
| 2 | `int(counter) == 0` admitted fractions and strings. | The audit's shared predicate requires `TYPE_INT` and exact zero. Encounter measurement tests call that same predicate: accept integer zero; reject missing, `0.5`, `"0"`, `0.0`, `1`, `-1`, `null` and `false`. The existing re-pin gate still requires all 108 snapshots and every reconstructed prior hash to match. No fixture was re-pinned. |
| 3 | Obsolete declarations looked like inventory authorities. | Removed Storm's `INPUT_DATA` and Lamplighter's `FIGURE_INPUTS`. Membership remains bound to the signed unit-end inventory. |

Storm's declared closure also contains `proof.py`, which the clean recipe compiler and native entry points never execute. Its copied orchestration bytes are now historical alongside `regeneration_checks.py`, so changing the outer orchestration does not falsely reseal old native evidence. Both copying and validation use that same explicit exclusion. Live native recipe, geometry, pose, probe and capture inputs remain bound; every existing stale-source, failed-comparison, digest, output and opaque-glass rejection test still runs. Existing receipts, input inventories, geometry, delivery images and protected design data are unchanged.

## Files changed

- `tools/maquette_input_history.py`: shared selected-byte reader, hash reader and checked materialization.
- `spec/art_identity/maquettes/storm_cantor/proof.py` and `regeneration_checks.py`: selected copying, parity and obsolete declaration removal.
- `spec/art_identity/maquettes/last_lamplighter/proof.py` and `regeneration_validation.py`: selected copying, parity, shared hash accessor and obsolete declaration removal.
- `tests/maquette_regeneration.py`: temporary pre-native execution and corrupt-copy controls for both figures.
- `tests/test_mq17_maquette.py`, `tests/test_mq18_maquette.py`: two generation-path cases each.
- `tools/enc04_golden_audit.gd`, `tests/encounter_measurement_test.gd`: strict counter predicate and boundary cases.
- `tests/int06_feedback2_report.md`: this report.

No new `tests/test*.py` module was added. The existing mq-17/mq-18 resource declarations remain `[]`: the new helper writes only per-test temporary directories and does not run native engines.

## Focused verification

Logs: `/private/tmp/labyrinth_codex/int-06/r2/`.

- `python3 -B -m unittest tests.test_mq17_maquette tests.test_mq18_maquette tests.test_int04_preservation tests.test_int05_preservation`: mq-17's 44, mq-18's 34 and int-04's 13 tests all passed. The combined loader additionally reported `Ran 92 tests ... FAILED (errors=1)` because int-05 imports a sibling using its legacy top-level name. This was an invocation issue; no assertion was changed. Log: `maquette-preservation.log`.
- Correct standalone int-05 command: `python3 -B -m unittest discover -s tests -p 'test_int05_preservation.py'`: `Ran 6 tests in 1.157s`, `OK`. Log: `int05-preservation.log`.
- `python3 tests/test_art_identity_gate.py`: `Ran 111 tests in 75.978s`, `OK`. Log: `art-identity.log`.
- `python3 tools/godot_task_runner.py --task-id int-06 --stream -- godot --headless --path . --script tests/encounter_measurement_test.gd`: `ENCOUNTER MEASUREMENT: PASS (2671 checks; 0 failures)`. Log: `encounter-measurement.log`.
- `python3 tools/godot_task_runner.py --task-id int-06 --stream -- godot --headless --path . --script tools/enc04_golden_audit.gd -- --output-dir /private/tmp/labyrinth_codex/int-06/r2/golden-audit`: `ENC04 GOLDEN AUDIT: legacy_matches_frozen=false current_matches_frozen=true`; `repinned=false`. Log: `golden-audit.log`; snapshot proof: `golden-audit/snapshots.json`. `prior_matches_frozen=false` is expected against the already re-pinned current fixture.
- `python3 tools/output_gdignore.py`: `OUTPUT GDIGNORE: PASS (18 folders; 6 referenced roots)`. Its unrelated untracked `output/enc-04/.gdignore` is removed after the headless runs.
- `git diff --check`: passes.

The initial four-test follow-up found only a macOS `/var` versus `/private/var` alias in the new test's expected path; resolving that test-owned path fixed the assertion. The final maquette run includes those four cases successfully. No existing product assertion was rewritten. The initial logs remain as `regeneration-before.log` and `regeneration-after.log`.

Final focused assertion failures: none. Art checks print existing NumPy/Pillow warnings; Godot prints its existing macOS certificate diagnostic. All completed commands above, apart from the corrected combined-loader invocation, exit zero.

## TODO_DESIGN, chosen defaults and open issues

No TODO_DESIGN placeholders or player-facing defaults were introduced. Proof-only named values are `COPY_MUTATION` (a comment appended to a temporary copied renderer), `SHARED_RENDER` (the existing renderer path), and `REJECTED_PENDING_COUNTERS` (the explicit type-boundary fixtures listed above). Test outputs use temporary directories and the existing task log root. No timeout or dependency changed.

No windowed proof or inspection fixture is required for this workflow/guard correction. No capture was generated. Open issues: none in this follow-up. The director retains full-suite, review, commit and merge ownership.
