# bos-01 feedback 3 — encounter golden and full regression proof

## Field-by-field diagnosis

The prior feedback-2 claim that the mismatch was pre-existing was incorrect: that comparison used an already
modified bos-01 HEAD. The integration runtime reference (`codex/peer-benchmark`,
`c50297c3040fa7d87d184e48f69ed5a635756dee`) produces the original frozen expected golden exactly.
No branch, index or commit was changed. The diagnostic temporarily read that reference's tracked runtime source
bytes into this worktree for one headless probe, then restored every working byte in a `finally` block. Its clean
reference run exited 0 with `BOS01 GOLDEN DIAGNOSTIC: PASS`. The standalone diagnostic and complete normalized
snapshots are in `/private/tmp/labyrinth_codex/bos-01/feedback3/`.

The complete snapshot diff before this round contains exactly these three fields (indices are zero-based):

| Field | Original integration | bos-01 before fix | Cause |
| --- | --- | --- | --- |
| seed 1 `combat[19].surface_events[2].half_health_switched` | absent | false | Dispatcher unconditionally stored the new analytics default in an existing Gale Herald beat event. |
| seed 421 `combat[9].surface_events[2].half_health_switched` | absent | false | Same dispatcher default on another Gale Herald beat. |
| seed 421 `combat[23].enemies[1].upheaval_pending.marks` | `(1,5), (2,5), (3,5)` | `(1,5), (3,5)` | Enemy id 2, Briar Weaver at `(3,6)`, executes Thornwall (`line_between`). After accepting `(1,5)`, placing `(2,5)` disconnects the walkable floor. The shared structural guard rejects it and accepts `(3,5)`. |

Before fixing the defaults, only seed 1 and 421 `combat` and `save_roundtrip` hashes differed. Every map and room
hash, and all four seed 19 hashes, matched. There are no cursor/latch changes on ordinary instances and no FIFO
or weighted-routing differences in these snapshots. The existing focused FIFO test also compares complete costs,
steps and chosen parents against the weighted traversal without Rubble; the weighted Rubble path stays Dijkstra.

The mark skip is intended by brief requirement 4, which explicitly covers **every** `line_between` user, including
Thornmother. This golden happens to contain an ordinary Briar Weaver Thornwall rather than a Thornmother.
The diagnostic independently calls the existing shared guard after each candidate:

```text
GUARD TRACE: tile=(1, 5) connected=true preserves_source_exits=true
GUARD TRACE: tile=(2, 5) connected=false preserves_source_exits=false
GUARD TRACE: tile=(3, 5) connected=true preserves_source_exits=true
```

Evidence files: `structured-diff.json` (all differing fields, before and after),
`{integration-reference,bos01-before,bos01-after}-seed-{1,19,421}.json`, the corresponding `*-hashes.json`,
`integration-reference.log`, `golden-after.log`, and `golden_diagnostic.gd.txt`.
The temporary project diagnostic was removed before running the full suites.

## Changes in this round

- `scripts/battlefield_rules/dispatcher.gd`: save the event flag only when true. The existing analytics adapter
  still exports a boolean on every `battlefield_rule_fired`, with false supplied for an absent field.
- `tests/suites/bos01_rules_suite.gd`: four new checks cover absent default saved event/instance metadata and
  explicit false exported analytics, both without a declared switch and before a declared switch fires.
- `tests/fixtures/encounter_measurement_golden.json`: update only seed 421's `combat` and `save_roundtrip` hashes
  for that one guarded mark. Keep all other ten hashes unchanged.
- `tests/encounter_measurement_test.gd`: comment naming the exact ordinary Thornwall case and its generic guard.
- `tests/suites/fix_11_activation_suite.gd`: forward the new optional accepted-action callback in its observer
  override, preserving every existing assertion and observation.
- `tools/encounter_bot.gd`: restore the historical policy's exact integration bytes. Its SHA256 is
  `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`.
- `scripts/battlefield_rules/bot_policy.gd` and sidecar: move the accepted-action support into a companion of the
  frozen policy. All decisions, order, scores, limits and weights still come from policy v2. Selected target
  descriptors remain outside combat/save dictionaries.
- `tools/encounter_measurement_bot.gd`: instantiate that companion for current measurements.
- `tests/suites/bos01_bot_policy_suite.gd` and sidecar: compare companion choices against the frozen policy for
  all six rules, verify selection is pure, and prove `run_room` accepts its hit and switches every rule.
- `spec/analytics.md`: document default omission in saved events and explicit inclusion in exported JSONL.
- `tests/bos01_feedback2_proof.md`: correct the earlier baseline interpretation and point to this addendum.
- This proof file: record the full diagnosis and verification.

After the fix, the entire normalized snapshot diff against integration consists solely of that one mark array.
The resulting seed 421 hashes are:

```text
combat:        14eb6d47afce9063d7771d610d45a2aaeb97dc0f75657f33eaa3e1bffddf0bd3
save_roundtrip: a891604f6e82db88d0ae0de297c4f822665870e6210fea68991e426532b5bb3d
```

## Verification

All logs in `/private/tmp/labyrinth_codex/bos-01/feedback3/`. Every Godot process uses the task runner.

Focused command:

```sh
python3 tools/godot_task_runner.py --task-id bos-01 --stream -- godot --headless --path . --script tests/bos01_rules_test.gd
```

Observed (`focused-rules.log`):

```text
BOS01 RULES TEST RESULT: PASS (384 checks, 0 failures)
BOS01 F1 64x64 PREPARE: min=73.280 median=74.785 max=75.270 ms (5 samples, five marks, one exit)
```

Full commands, each after the final code change:

```sh
python3 tools/godot_task_runner.py --task-id bos-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/bos-01/feedback3/full-python
```

The first full Godot run, before cache preparation, ended with:

```text
MAIN BODY RUNTIME: 292.749 seconds
MAIN BODY ASSERTIONS: 495687
ENCOUNTER MEASUREMENT: PASS (2662 checks; 0 failures)
FULL SUITE RUNTIME: 779.921 seconds (budget 900 seconds)
TEST RESULT: FAIL (4 failure(s))
```

Those four failed children were `special_encounter_test` (missing imported emblem textures),
`enemy_no_action_test` (missing generated `GameData` class cache, then a timeout), and `fix_11_test` /
`fix_11_probe` (the same cache prerequisite plus the observer override's old signature). The initial secondary
`entries`/`run` errors were consequences of those compile failures, not absent methods. The full nested logs
identified the causes; no assertion was weakened or rewritten. The log/report are preserved as
`full-godot-before-bootstrap{.log,-report.json}`.

Prepared the cache with the documented resource-import command, not as a parser check:

```sh
python3 tools/output_gdignore.py
python3 tools/godot_task_runner.py --task-id bos-01 --stream -- godot --headless --path . --import
```

Observed:

```text
OUTPUT GDIGNORE: PASS (15 folders; 6 referenced roots)
import exit: 0
existing_sidecars: 26733
changed_restored: []
new_removed: []
existing_metadata_preserved: true
```

The audit checked all existing source `.import` / `.uid` bytes. No sidecar needed restoring, and none was created.
Only ignored generated caches were built. `import-bootstrap.log` and `import-metadata-audit.json` retain evidence.
After the observer forwarding fix and cache preparation, the complete Godot run passed all 236 children:

```text
MAIN BODY RUNTIME: 309.666 seconds
MAIN BODY ASSERTIONS: 495687
ENCOUNTER MEASUREMENT: PASS (2662 checks; 0 failures)
FULL SUITE RUNTIME: 728.160 seconds (budget 900 seconds)
TEST RESULT: PASS
```

This intermediate run/report is preserved as `full-godot-pre-policy{.log,-report.json}`. The first Python attempt
then found two exact-byte policy provenance failures (`test_revision6_baseline_is_complete_and_recomputes`,
`test_revision7_baseline_is_complete_and_recomputes`). That attempt was interrupted to fix their cause; its
partial logs are in `full-python-frozen-policy-attempt{.log,/}`. No report hash or assertion was updated. Instead,
the policy file was restored and the active adapter extracted, as listed above. Focused checks after extraction:

```text
BOS01 RULES TEST RESULT: PASS (408 checks, 0 failures)
Ran 14 tests in 1.545s
OK
Ran 6 tests in 27.338s
OK
```

The Python commands were `python3 -m unittest discover -s tests -p test_encounter_measurement.py -v` and
`python3 -m unittest discover -s tests -p test_skybolt_measurement.py -v`. Their logs are
`focused-python-measurement.log` and `focused-skybolt-adapter.log`; the latter exercises a real measured CLI run,
resume, metrics refresh and unchanged policy/card source bytes. The new bot regressions reuse the existing en02
seed, `quick_stab`, a Defeat All fixture objective, and a test-only stop at a successfully accepted switch.

Both complete suites ran after the final code change. Final Godot result (`full-godot.log`, exit 0;
`full-godot-report.json`, 236/236 children passed):

```text
MAIN BODY RUNTIME: 277.060 seconds
MAIN BODY ASSERTIONS: 495687
TEST REGISTRATION AUDIT: PASS (878 scripts; full suite=517, quarantined=29, windowed probe=332)
ENCOUNTER MEASUREMENT: PASS (2662 checks; 0 failures)
WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)
Warband suite: 0 failures
Snare suite: 0 failures
ELEMENT RETROFIT TEST RESULT: PASS (939 checks, 0 failures)
BOS01 RULES TEST RESULT: PASS (408 checks, 0 failures)
BOS01 RULE SCENE RESULT: PASS (122 checks, 0 failures)
FULL SUITE RUNTIME: 723.359 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Final Python result (`full-python.log`, exit 1; `full-python/summary.json`):

```text
ISOLATION AUDIT: 227 modules
Ran 2111 tests in 2004.944s
FAILED (failures=3, skipped=66)
```

All four shards completed. There were zero unittest errors. The three failures are retained without changing
their assertions:

1. `test_pt14_04_coverage.HeroCoverage.test_runtime_boundary_and_reverts` requires the complete
   `scripts/run_scene.gd` bytes to equal the floating `codex/peer-benchmark` ref. bos-01's required commit/banner
   wiring changes that file. The integration ref also advanced during this task from the diagnosis reference
   `c50297c3040fa7d87d184e48f69ed5a635756dee` to observed `a427742ca3cca12f605f98e7f5aae07cb25045f6`.
   This is an incompatible whole-file baseline assertion for this feature worktree; no claim of a pre-existing
   integration failure is made.
2. `test_pt14_04_coverage.HeroCoverage.test_instrumented_runtime_and_baseline` passed its **candidate** run,
   then failed the private **baseline** overlay with exit 124 after 300 seconds. The traceback identifies its
   cause: the newer integration `run_scene.gd` preloads `res://scripts/card_display_overrides.gd`, which does not
   exist in this worktree/private copy. The test replaces selected files from the floating ref without copying
   that new dependency. The resulting compile failure prevents the baseline scene from completing. Candidate
   instrumentation reported initialization 0.417 ms and Continue 0.221 ms, both within its unchanged 0.5 ms cap.
3. `test_sb02_movement.Movement.test_incremental_submission` failed timing during concurrent Python load:
   mixed cold-plan best **4002 us** versus its **4000 us** cap, and movement-plan max **8465 us** versus
   **4000 us**. It had passed in the full Godot run. After all Python workers finished, the unchanged workload
   was rerun once in isolation:

   ```sh
   python3 tools/godot_task_runner.py --task-id bos-01 --timeout 90 --stream -- godot --headless --path . --script tests/status_plates_performance_probe.gd -- --movement-only
   ```

   Observed exit 0, `STATUS MOVEMENT PROBE RESULT: PASS`; mixed cold-plan best **2462 us**, warm median
   **327 us**, movement-plan max **1661 us**. All seven cold-plan cases passed. This supports load sensitivity;
   it does not replace or erase the full-suite failure. Evidence: `isolated-movement.log`,
   `move_cpu-isolated.json`, `cold_plan_cpu-isolated.json`.

The complete tracebacks are in `full-python/shard-{3,4}-result.json` and the combined log. The two baseline-test
failures remain open for integration-context verification. No production dependency from the other unit was
copied into this worktree, no branch was merged/rebased, and no test limit or historical assertion was weakened.
No new Python discovery module was added, so no suite resource-table entry was needed.

## Chosen defaults, TODO_DESIGN and remaining proof

No new player-facing value, asset, dependency or design placeholder. The new regression uses the existing
bos-01 fixtures, the two test-only declared-switch booleans and analytics fixture id `bos01-default`. The bot
regression uses the existing fixture seed/card/objective and its named test `Fight` stops when the switch is
accepted. No new runtime default beyond omitting a false metadata value. No new `TODO_DESIGN` placeholders.

Windowed proof remains the director's queued work, using the unchanged commands in `tests/bos01_proof.md`.
No windowed attempt, reviewer agent, commit, push or publication was performed. All changes remain uncommitted.
