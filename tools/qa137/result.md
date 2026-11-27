# QA-137 save-failure proof

`codex/qa-137` uses `codex/release` commit `c6d0e65fca428d19d2ac2b36f4b9704b0137a374` as its baseline. The implementation is uncommitted.

## Failure paths

| Path | Counts |
| --- | --- |
| Profile archive, temp open, validation, required backup rotation, invalid-live removal, or promotion failure (`scripts/progression_store.gd:554`) | Once when `save_data` or `save_data_in_tree` receives the failed disk job (`:532`, `:538`). A failed restore of the old file belongs to the same request (`:591`). |
| New Run replacement write (`scripts/progression_store.gd:772`) | Once if the replacement transaction fails. A failed prerequisite flush leaves the existing checkpoint request pending and prevents the replacement transaction from starting. |
| Checkpoint archive, temp open, write or validation, required Windows backup rotation, or promotion failure (`scripts/progression_store.gd:828`) | Once when the failed snapshot is discarded by explicit clearing (`:881`, `:886`) or at the final application drain (`scripts/run_persistence.gd:132`). A successful retry or superseding checkpoint retires the failed attempt. |
| Required migration archive copy, checksum, or rename (`scripts/progression_store.gd:971`) | When it prevents profile or checkpoint promotion, as part of the owning save request. |
| Post-promotion backup cleanup (`scripts/progression_store.gd:595`, `:878`) | Zero. The primary save succeeded. |
| Existing boundary errors (`scripts/progression_store.gd:806`, `:1258`; `scripts/run_persistence.gd:254`, `:352`, `:399`, `:414`, `:449`, `:460`) | Existing messages stay at their original boundaries. Telemetry comes from the underlying save request. |
| Backup promotion during Continue (`scripts/progression_store.gd:639`), a failed deletion (`:892`), and an analytics append failure (`scripts/run_persistence.gd:155`) | Zero for these operations. An exhausted checkpoint encountered by the clear barrier can independently count. |

The worker records the Godot error on the request and completes the existing disk job. The main thread collects the result, determines finality and calls `PlayStats.notify`. `save_failed` appends `{kind, reason}` through the local JSONL writer. Diagnostics can be appended while gameplay receipts are waiting for a checkpoint.

The hands-off RunScene errors for tutorial progress (`scripts/run_scene.gd:8414`, `:8440`, `:8462`, `:8486`), migration and replacement (`:9624`, `:9657`, `:9780`), withdrawal (`:28046`, `:28051`), outbox and settlement (`:29106`, `:29451`, `:34302`), repair (`:30870`) and purge (`:35261`) delegate to the instrumented saves. The opening-boon profile warning (`scripts/opening_boon_flow.gd:201`) also delegates to a profile save. The suspend warning (`scripts/application_suspend.gd:28`) leaves the checkpoint eligible for retry.

Managed quit reports before Steam submits the clean-quit batch. The hands-off root cleanup (`scripts/application_shutdown.gd:232`) also covers final cancellation on direct engine exit, when Steam may already have completed its exit hook. The hard-stop watchdog (`scripts/persistence_disk_worker.gd:17`) can terminate the process while an OS write is unresolved, so it has no settled outcome to count.

## Headless witness

The release capture ran before production edits with `--capture-release`. The implementation witness used the same demo seed and profile and compared the entire files against that capture.

```text
QA137 normal opening saves: save_errors=0 save_failed=0
QA137 failed attempt then successful retry: save_errors=0 save_failed=0
QA137 terminal profile failure: save_errors=1 save_failed=1
QA137 terminal worker failure: save_errors=1 save_failed=1 main_thread=true
QA137 terminal replacement failure: save_errors=1 save_failed=1
QA137 final shutdown failure and cleanup: save_errors=1 save_failed=1
QA137 bytes progression.json: identical (912 bytes, SHA-256 dcbcb6dae8543a9c2e2c3a9c6dc25163d645458b5e3725365004ca638b1fc015)
QA137 bytes 01-departure.save: identical (162440 bytes, SHA-256 c0b4e7a067b283705d02fef189d53c96b0deae1b7a3ec62142594af50358730f)
QA137 bytes 02-pre-battle.save: identical (169904 bytes, SHA-256 cbfc74a84ba7415a734f914da1a525ad3ecc7d1ca266f988c29045424ce38758)
QA137 bytes 03-combat.save: identical (181008 bytes, SHA-256 fcac5454531b6b0367a3597bddb84ef64d64073da813d63b614c3b6aa98b6164)
QA137 bytes 04-retry.save: identical (181008 bytes, SHA-256 fcac5454531b6b0367a3597bddb84ef64d64073da813d63b614c3b6aa98b6164)
QA137 RESULT: PASS (0 failures)
```

- Release bytes are in `/private/tmp/labyrinth-godot-home/qa-137-1795785947389090000-11496/Library/Application Support/Escape the Umbra Parallel qa-137-1795785947389090000-11496/qa137-witness/successful`.
- Implementation bytes are in `/private/tmp/labyrinth-godot-home/qa-137-1795786266914016000-14612/Library/Application Support/Escape the Umbra Parallel qa-137-1795786266914016000-14612/qa137-witness/successful`.
- The implementation capture's sibling `analytics/events-2026-11-27.jsonl` has four `save_failed` rows. The profile has reason `12`. The three run-checkpoint rows have reason `14`.
- [Release witness log](</private/tmp/labyrinth-godot-home/qa-137-1795785947389090000-11496/godot.log>) and [implementation witness log](</private/tmp/labyrinth-godot-home/qa-137-1795786266914016000-14612/godot.log>).

## Existing checks

| Check | Result |
| --- | --- |
| `tests/save_resume_boundary_test.gd` | `TEST RESULT: PASS — committed save/resume boundary matrix` [Log](</private/tmp/labyrinth-godot-home/qa-137-1795786295638892000-14652/godot.log>) |
| `tests/save_pipeline_performance_test.gd` | `TEST RESULT: PASS — save pipeline compatibility and cleanup` [Log](</private/tmp/labyrinth-godot-home/qa-137-1795786295643664000-14653/godot.log>) |
| `tests/perf/background_persistence_test.gd` | `PERF03 DEFERRED PERSISTENCE RESULT: PASS (0 failures)` [Log](</private/tmp/labyrinth-godot-home/qa-137-1795786295638915000-14651/godot.log>) |
| `tests/surface_save_migration_test.gd` | `Surface migration checks: PASS` [Log](</private/tmp/labyrinth-godot-home/qa-137-1795786295638907000-14650/godot.log>) |
| Python default group (23 modules) | `Ran 196 tests in 33.819s` and `OK` [Summary](/private/tmp/labyrinth_codex/qa137-python-default-final/summary.json) |

The initial Python pass caught an approved-content PCK compile error from a dependency on the global `ProgressionStore` class name. The final pass includes the packed smoke check. The runner could not update its timing cache under the read-only `.git` directory. The save/resume test exited 0 and emitted Godot RID and resource leak diagnostics during teardown. The macOS CA certificate diagnostic also appeared in the release witness.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-137 && python3 tools/godot_task_runner.py --task-id qa-137 --stream -- godot --headless --path . --script tools/qa137/witness.gd -- --release-dir '/private/tmp/labyrinth-godot-home/qa-137-1795785947389090000-11496/Library/Application Support/Escape the Umbra Parallel qa-137-1795785947389090000-11496/qa137-witness/successful'
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-137 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/qa137-python-default-final
```

Windowed proof and a playable inspection fixture are inapplicable to this telemetry change.

## Chosen defaults

The witness uses seed `88100`, a profile with `37` Embers, and a file-in-the-way blocker under its task-local `user://qa137-witness` directory. For write validations that returned only a boolean, the local reason uses the corresponding Godot file read, write, or corruption code. No `TODO_DESIGN` placeholders are required.
