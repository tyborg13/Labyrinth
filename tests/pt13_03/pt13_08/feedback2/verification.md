# pt13-08 feedback 2: rules identity by content

The rules-body locator no longer uses child order or text-node type alone.
It calls production `ActionIconLibrary.card_rules_text` with the sample's
definition. Expected text and each candidate's parsed text pass through the
same production inline-token renderer, Godot BBCode parser, nonbreaking-space
replacement and whitespace collapse. Recursive matching includes hidden nodes.
Exactly one nonempty match is required before checking its visibility or
measuring its font, transform and inline icons. Zero matches report
`missing rules body`; multiple matches report `ambiguous rules body`. Neither
failure produces a substitute rules measurement.

The initial native popover uses the definition resolved from its actual source
card ID. Batched audit measurements receive each entry's definition explicitly;
the expected text is never inferred from a title, subtitle or the panel's text.
Capture-plan wiring supplies the initial native definition too. Measurement
reports include expected normalized text and the match count.

The native Graftwright fixtures retain references to their authored body before
making changes, independently of the locator under test. Existing hidden,
empty, whitespace-only and missing-body fixtures remain. Empty/whitespace rules
now fail with zero content matches rather than a positional empty-label error.
Additional checks cover reordered visible rules, swapped title with hidden
rules, an inserted subtitle with hidden and empty rules, duplicate matching
nodes (including a hidden duplicate), unrelated nonempty text, missing expected
definitions, and normalization on both the expected and actual side.

All eleven previous mutation cases remain. Three new cases cover both reviewer
categories, including both subtitle failure modes:

```text
CARD LEGIBILITY MUTATION graftwright_title_swap_hidden: REJECTED
CARD LEGIBILITY MUTATION graftwright_subtitle_hidden: REJECTED
CARD LEGIBILITY MUTATION graftwright_subtitle_empty: REJECTED
CARD LEGIBILITY MUTATIONS: 14 caught, 0 survived
```

Focused observed results (all runners exited 0):

```text
Ran 5 tests in 66.968s
OK
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)
CARD LEGIBILITY NEGATIVE FIXTURES: PASS (26 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 236 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 7 contexts, 21 samples, 280 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 561 checks, 0 failures)
CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)
CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)
CARD LEGIBILITY CAPTURE PLAN: PASS
CARD LEGIBILITY COVERAGE CAPTURE PLAN: PASS (18 checks, 0 failures)
Ran 25 tests in 3.941s
OK
REMOVED FILE REFERENCES: none (git grep exit 1)
```

Commands:

```bash
python3 tests/test_card_legibility.py
python3 tools/godot_task_runner.py --task-id pt13-08 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --context-smoke
python3 tests/run_card_legibility_mutations.py
python3 tools/godot_task_runner.py --task-id pt13-08 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --focused-shared
python3 tools/godot_task_runner.py --task-id pt13-08 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --reading-layouts
python3 tests/pt13_03_proof.py --phase after --plan-only
python3 tools/godot_task_runner.py --task-id pt13-08 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --coverage-capture-plan
python3 tests/test_ui_identity_lint.py
git grep -n -E 'capture[_]before[.]gd([.]uid)?' -- .
```

Individual mutation logs and `results.json` are in `../mutations/`; this folder
contains the new aggregate mutation log and every focused result log. The
native Graftwright capture plan records one matching, visible, nonempty body
with expected text “Strike an adjacent enemy for 6. Follow-up: deal 3 more.”
Its headless measurements are in `../captures/measurements.json`; no PNGs were
generated. Existing windowed commands and proof contracts remain applicable.

Changed files: `tests/card_legibility_test.gd`, the audit/context/capture/negative
card-legibility helpers, `tests/run_card_legibility_mutations.py`, and this
report. Production scripts, scenes, data, assets, floor values, exemptions and
settling rules are unchanged. No full catalog audit, full suite, windowed run,
peer review, commit, publication, branch or queue operation was performed.

Chosen defaults: test-only subtitle text `Audit subtitle`, stored in named
`SUBTITLE_FIXTURE_TEXT` constants. BBCode and whitespace wrappers are test-only
definition/text-field values. No player-facing values or TODO_DESIGN
placeholders were introduced.

Open scope clarification: strict per-sample matching follows the brief and is
retained. Source inspection also shows that production Graftwright builds its
inspector from `Data.card_def(id)`, while the audit includes modified item
definitions. For example, `nail_bomb` has base rules beginning “Consume.” and
its nonhealing once-per-combat variant changes that word to “Exhaust.” through
production `ItemRelicRules.modify_card`. Strict matching will distinguish those
texts. This production/variant discrepancy was raised with the director; the
full catalog was not rerun or claimed passing in this focused round.
