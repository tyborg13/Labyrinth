# qa-18 retained validation

Scope: high-risk committed-plan identity repair plus the explicitly requested hunt-tool changes. All repository changes remain uncommitted; no Git writes, queue changes, peer review, publication, full suites, windowed engine or visual captures. Design-owner workflow split applies.

Cold import: exit 0; `/private/tmp/labyrinth-godot-home/qa-18-1793588549437600000-67484/godot.log` ends `[ DONE ] loading_editor_layout`. Existing macOS CA certificate diagnostic and duplicate Reaver placeholder UID were emitted. This was the required cold import, not a parser check.

Frozen measurement policy: `ENCOUNTER POLICY HASH: PASS c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`, using existing `encounter_shadow_dial_measurement.policy_hash()`.

Failing first: the final three-enemy scenario against the original guardian source emitted `QA18 REGRESSION: FAIL (20 checks, 15 failures)` plus the invalid index error. Before log: `regression-before-final.log`. Production source was restored in `finally`; no branch or index operation. After log: `regression-after-final.log`, `QA18 REGRESSION: PASS (20 checks, 0 failures)`.

Focused combat: `QA18 FOCUSED COMBAT: PASS (704 checks, 0 failures)` in `focused.log`. Private entry point calls the existing Guardian rules, Guardian encounters/tuning, enemy-intent preview and dragon suites; the regression is reached by the already registered `tests/guardian_rules_test.gd` program; nothing was added to default program groups.

Python default group: `Ran 178 tests in 30.721s`, `OK`; `INPUT GROUP TIME default: 19 modules; 82.642 module-seconds; 30.549s maximum attributed shard work`. Command: `cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/qa-18/python-default`. The change filter selected only the default group; no full suite was run. Results and audit in `python-default/`. The optional learned-timing cache could not write outside the sandbox; tests completed successfully. Separate resource audit: `ISOLATION AUDIT: 54 modules` in `python-audit.log`; no new Python test modules.

Eight-room bounded encounter CLI batch: revision 7, standard cohort, tier 1, first seed 101; includes seed 101 sections 0–5 and seed 102 sections 0–1. Before/after records are identical in every field: 7 victories, 1 defeat, 0 changed records/outcomes. Both engine logs contain 8 `ENCOUNTER BOT RUN:` lines and zero `SCRIPT ERROR:` lines. Existing CLI was invoked through private `encounter_batch.py`, which supplies task ID qa-18 to its existing Godot runner without modifying the CLI or policy. Full records: `batch-comparison.json`; compressed originals: `before-batch/` and `after-batch/`; logs: `before-logs/` and `after-logs/`.

Hunt parser: `--headless --check-only --script tools/run_hunt.gd`, exit 0, `hunt-parser.log`. Python syntax: `PYTHONPYCACHEPREFIX=/private/tmp/labyrinth_codex/qa-18/pycache python3 -m py_compile tools/run_hunt.py`, exit 0. An earlier syntax command tried the system cache outside the sandbox; rerouting only that cache resolved it.

Runtime smoke: `RUN HUNT RESULT: started=1 finished=1 finding_groups=1` for seed 101 / 25 decisions (`hunt-smoke/`) and seed 7 / 300 decisions (`browse-smoke/`). Each sole finding is the platform certificate diagnostic. Seed 7 exercised two forced merchant exits following eight browse actions. Source-art headless only.

Production boundary and terminal-choice proof: `QA18 HUNT POLICY / PRODUCTION FILTER: PASS (0 failures)` in `hunt-policy-proof-final.log`. Embrace metadata and Abandon callback were excluded, and the production scene helper removed the dead first enemy. Initial private probe incorrectly added a bare RunScene script to the tree, causing missing-scene-node errors; the corrected probe calls the helper off-tree and passes without script errors.

Initial campaign attempt was interrupted by a continuation before either seed finished; partial evidence in `whole-runs/`, excluded from final campaign totals. Fresh campaign: seed 101, two processes, no Embrace, 60-minute launch cutoff, `campaign-2/`.

No TODO_DESIGN placeholders; no perceivable decisions or approved assets changed. Test-only defaults are named in `COMMITTED_ACTOR_FIXTURE` (positions, hero position, third charge, lethal damage, test intent/time/ranges/damage). Existing fixture supplies the 9×9 arena, 100-HP Wardens and 24-HP hero. Measurement-only defaults are 8 standard/tier-1 rooms from seed 101 and smoke replay caps 25/300. Hunt limits 8/400/50, campaign seed/cap/process count come directly from the brief.

No windowed proof or inspection-fixture command is applicable: the brief explicitly requires headless rules/tooling proof only and no windowed Godot.

Campaign tooling correction: the initial browse guard mistook a retained `_merchant_shop_open` flag for an actual merchant in seeds 104–105's start rooms, causing repeated Leave attempts and the generic 120-decision stop. These are harness failures, not player softlocks. The corrected guard also requires `_current_room_merchant_kind()`. It applies from seed 107; seeds 101–106 loaded the initial policy. A completeness audit then added the actual desktop-exit menu callback to the terminal exclusion list for seed 108 onward; no desktop exit had been dispatched. All three policy versions, exact private replay drivers, and cutover timestamps/hashes are retained in `campaign-policy-correction.json` and `run_hunt_policy_campaign_initial.gd`. The final report reclassifies those two harness stops as warnings in memory; raw logs, command records and evidence remain unchanged.

## Proof for the design owner

No windowed commands or captures apply: the brief explicitly forbids windowed Godot. The final check entry point uses only the task runner, checks the exact final regression against the original and fixed guardian source, restores the source automatically, and runs the existing focused suites and Guardian program. It is run after every campaign process exits:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && python3 /private/tmp/labyrinth_codex/qa-18/final_checks.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id qa-18 --stream -- godot --headless --path . --script tests/guardian_rules_test.gd
```

The retained paired CLI wrapper changes only the runner task ID, leaving the existing encounter CLI/policy intact. Its two commands were identical apart from the output/log roots:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-18/encounter_batch.py --seed 101 --runs 8 --tier 1 --cohort standard --workers 1 --output-dir /private/tmp/labyrinth_codex/qa-18/before-batch --log-root /private/tmp/labyrinth_codex/qa-18/before-logs
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-18/encounter_batch.py --seed 101 --runs 8 --tier 1 --cohort standard --workers 1 --output-dir /private/tmp/labyrinth_codex/qa-18/after-batch --log-root /private/tmp/labyrinth_codex/qa-18/after-logs
```

## Final source verification

After all nine campaign processes exited, the final-source check script exited 0:

- `QA18 REGRESSION: FAIL (20 checks, 15 failures)` against the original guardian source, with the invalid index and wrong warnings; exit 1, 3.883 seconds. `regression-base-final-head.log`.
- `QA18 REGRESSION: PASS (20 checks, 0 failures)` after restoring the fixed source; exit 0, 3.896 seconds. `regression-fixed-final-head.log`.
- `QA18 FOCUSED COMBAT: PASS (704 checks, 0 failures)`; exit 0, 14.902 seconds. `focused-final-head.log`.
- `GUARDIAN RULES TEST RESULT: PASS (381 checks, 0 failures)` through the existing registered program; exit 0. `guardian-rules-program-final-head.log`.
- `QA18 HUNT POLICY / PRODUCTION FILTER: PASS (0 failures)`; exit 0. Embrace, Abandon, Save and Quit, Desktop Exit exclusions and the non-merchant guard all passed. `policy-final-head.log`.
- Final hunt `--check-only` parser: exit 0. `parser-final-head.log`.
- `QA18 PYTHON COMPILE: PASS`.
- `QA18 FINAL CHECKS: PASS (base failed; all fixed checks passed)`. Exit codes, exact runner argv and durations are retained in `final-checks.json`.

Campaign: `RUN HUNT RESULT: started=9 finished=9 finding_groups=12`; coordinator exit 0. The final report contains 17,212 decisions, five victories, one unchanged-state stop, one 400-decision exploration warning and two reclassified harness stops. Coverage for sections 0–5 is 9, 7, 7, 5, 5, 5 runs. No Embrace, defeat, native Godot crash or stale-plan index error was observed. Peak own-process concurrency was two; final launch 3,455.95 seconds after campaign start. The 60-minute launch cutoff was followed by draining active seeds, for 77.00 minutes total. Endpoint orphan counts were zero in all five section-5 runs; tree-node growth flags remain for director triage. Raw campaign evidence and commands are in `campaign-2/`; source-phase corrections and archived replay drivers are documented above.
