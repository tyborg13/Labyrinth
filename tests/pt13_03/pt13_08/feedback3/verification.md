# pt13-08 feedback 3: context-aware catalog coverage

Strict rules-text identity remains unchanged. Definition eligibility now comes
from the owning production builder, recorded centrally in
`tests/helpers/card_legibility_sources.gd`:

- Base only: boon spells; Scavenger offer, sell, receipt and detail; deck view,
  campfire and purge picker; purge confirmation; Graftwright cards and inspector.
- Base and modified: all nine hand contexts; reward offers; both Grimoire views;
  card/equipment tooltips; both Chronicle previews; combat pile dialog; upgrade
  preview; drag proxy and both staged-effect contexts.

The first group resolves IDs directly to base definitions, including indirect
`CardWidget.configure(id)` calls. The second group passes explicit definitions
or resolves progression / recorded Chronicle definitions. ID-taking front ends
with a definition resolver retain their modified coverage. Each context carries
the exact production call chain justifying its classification.

The audit applies this eligibility filter before batching and requires every
eligible definition to be sampled. A base-only context independently rejects
modified entries in `sample_errors`; the existing printed-definition, variant,
visibility, text-identity and legibility assertions remain. Unknown definition
sources fail closed. Native initial-face checks and all 26 negative fixtures
remain intact.

`audit.json` records the source, production call, definition counts and sample
count in every context summary, plus the context source on every measurement.
Its global inventory still includes every definition and variant alias.
The default audit also writes `result.md` with a per-context definition-source
table, builder calls, counts and measured floors; no manual report merge is
needed. The global inventory is 309 base plus 2,025 modified definitions.

Exact observed proof:

```text
CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 52413 samples, 56638 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 625 checks, 0 failures)
CARD LEGIBILITY NEGATIVE FIXTURES: PASS (26 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 248 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 7 contexts, 21 samples, 294 checks, 0 failures)
Ran 5 tests in 75.146s
OK
CARD LEGIBILITY MUTATIONS: 14 caught, 0 survived
CATALOG PROVENANCE: PASS (309 base, 2025 modified definitions; 11 base-only, 21 both contexts; 52413 samples; 0 unsupported samples)
MODIFIED COVERAGE: PASS (all 2025 modified definitions retained)
MODIFIED ITEM PROOF: PASS (nail_bomb/item_once_per_combat sampled in 21 contexts; 0 base-only contexts)
STRICT GRAFT IDENTITY: PASS (309 base definitions, one visible nonempty match each)
RESULT SOURCE TABLE: PASS (32 contexts with matching production calls and source labels)
```

Commands, from the task worktree:

```bash
python3 tools/godot_task_runner.py --task-id pt13-08 --timeout 1200 --stream -- godot --headless --path . --script tests/card_legibility_test.gd
python3 tools/godot_task_runner.py --task-id pt13-08 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --context-smoke
python3 tests/test_card_legibility.py
python3 tests/run_card_legibility_mutations.py
```

The Python module executes the negative fixtures, coverage-gap, regression and
fixed-context checks, and the Windows typed-array guard (now including the new
source helper). The 1,200-second full-catalog cap is the existing documented cap.
All fourteen mutations retain their original failure expectations except the
previously documented zero-match error wording. Individual mutation logs and
`results.json` are in `../mutations/`; this folder contains this round's full,
short, module and aggregate mutation logs. The incremental headless import
generated the new helper's UID and exited 0.

Files changed for this decision: the new source helper and UID,
`tests/card_legibility_test.gd`, the audit helper, the Python module's typed-array
file inventory, regenerated `tests/pt13_03/audit.json` and `result.md`, and proof
reports/logs. No production script, scene, data, art, floor, exemption, timing
or fixture value changed. No new defaults or TODO_DESIGN placeholders were
introduced. Whether the production Graftwright should display modified rules
remains a separate director question; the audit now samples what it actually
builds.

No full project suite, windowed run, peer review, commit, push, merge, branch,
queue or cleanup operation was performed. All implementation changes remain
uncommitted.
