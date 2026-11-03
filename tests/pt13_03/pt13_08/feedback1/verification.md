# pt13-08 feedback 1: retire historical execution

Retired the historical Python test, capture entry point and UID, file-splicing
CLI path, old badge-font calculation, capture phase override and before-only
layout-validation switches. The mutation copier now serves only its mutation
caller. The current-code CLI remains `--phase after` and supports headless
`--plan-only` through the `pt13-08` Godot runner.

All current-code test and audit assertions remain. The reading helper's twelve
`expect.call` statements and one `Presentation.assert_grid` call are identical
to the original calls and now run unconditionally. Floors, exemptions, settle
rules, fixture values, production scripts and assets are unchanged.

The README records: “The before evidence is historical, recorded at 591da4132.”
Stale file entries were removed from the changed-file report and UID manifest.
The accepted historical measurements and captures remain historical evidence.

Focused observed results:

```text
Ran 5 tests in 63.968s
OK
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)
CARD LEGIBILITY NEGATIVE FIXTURES: PASS (15 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 236 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 7 contexts, 21 samples, 280 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 561 checks, 0 failures)
CARD LEGIBILITY CAPTURE PLAN: PASS
CARD LEGIBILITY MUTATIONS: 11 caught, 0 survived
REMOVED FILE REFERENCES: none (git grep exit 1)
```

Commands executed from the task worktree:

```bash
python3 tests/test_card_legibility.py
python3 tools/godot_task_runner.py --task-id pt13-08 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --context-smoke
python3 tests/run_card_legibility_mutations.py
python3 tests/pt13_03_proof.py --phase after --plan-only
git grep -n -E 'capture[_]before[.]gd([.]uid)?' -- .
python3 tests/pt13_03_proof.py --help
```

The reference search found no matches (expected exit 1). CLI help lists only
`--phase {after}`. Logs are in this folder; individual mutation logs and their
machine-readable results are in `../mutations/`. The current capture plan
writes measurements to `tests/pt13_03/feedback2/captures/after/measurements.json`
without generating PNGs.

No full suites or windowed runs were performed. No new defaults or TODO_DESIGN
placeholders were introduced. All changes remain uncommitted; no peer review,
publication, queue edit or branch operation was performed.
