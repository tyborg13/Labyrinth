# tt-01 implementation handoff

Round 0 was committed by the design owner as `f65f7a28a`, and the director
accepted its renderer captures for Lantern Shot, Royal Bramble and Storm Beacon.
Round 1 was committed by the design owner as `9f28d14fd`. Feedback 2 changes are
uncommitted on `codex/tt-01`; commit, review and publication remain with the
design owner.

## Feedback 2 — independent test expectations

The three adopted review findings are addressed without changing production
data or behavior:

1. Remove all three literal initializers for typed arrays from the proof helper.
   `selected` is populated with `append()`; the two other arrays are declared
   without literals. A focused Python guard covers both tt-01 GDScript files.
   Windows execution itself is not available in this macOS sandbox.
2. Replace implementation-derived discovery witnesses with the checked-in
   `tests/fixtures/short_card_tooltips_expectations.json`: 29 explicit term-to-
   encounter mappings and 31 hand-written encounter outcomes. Four unrelated
   cases cover Quick Stab, Tunnel Crawler, `fringe`, and `clear`. The real
   discovery sync must produce exactly the expected new non-default keyword
   set and unread receipts, so every unrelated new keyword remains locked.
3. Pin all 108 old definitions to explicit owning Grimoire entry ids in both
   Python and Godot. Both drivers unconditionally check the schema of all
   39 new entries, including each entry's own full-definition paragraph.

Focused baseline results:

- `SHORT CARD TOOLTIPS TEST RESULT: PASS (845 checks, 0 failures)`
- `TT01 GRIMOIRE DISCOVERY: PASS (39 entries; 10 default, 29 discovered; 31 independent encounters)`
- `GLOSSARY TEST RESULT: PASS (6760 checks, 0 failures)`
- `GRIMOIRE SEARCH TEST RESULT: PASS`
- `GRIMOIRE PERFORMANCE RESULT: PASS`
- `GRIMOIRE ROW RETENTION RESULT: {"cases":50,"differences":0,"errors":[],"orphan_nodes":0,"reused_rows":371}`
- `tests/test_short_card_tooltips.py`: `Ran 5 tests` / `OK`.

`tests/run_short_card_tooltip_mutations.py` replays the reviewer's 11 mutations
and four additional checks for both retention drivers, unconditional schemas,
and the typed-array guard. It requires the expected assertion failure: a parser
error, launch failure or timeout cannot count as a caught mutation. Each input
is restored byte-for-byte after its case, with hashes in the summary.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tt-01 && python3 tests/run_short_card_tooltip_mutations.py
```

Mutation replay completed with exit 0: **15/15 caught; all inputs restored**.
All 11 reviewer mutations and the four additional checks below failed through
their expected assertions, with no parser, launch or timeout failures.

| Mutation | Result |
| --- | --- |
| `old_glossary` | Caught |
| `alias_changed` | Caught |
| `unchanged_skill_changed` | Caught |
| `old_rule_lost` | Caught |
| `old_rule_wrong_topic` | Caught |
| `time_panel_restored` | Caught |
| `boon_time_restored` | Caught |
| `nondefault_made_default` | Caught |
| `old_discovery_mapper` | Caught |
| `mirror_on_every_action` | Caught |
| `eclipse_on_fringe` | Caught |
| `old_rule_wrong_topic_godot` | Caught |
| `new_entry_schema_python` | Caught |
| `new_entry_schema_godot` | Caught |
| `typed_array_literal` | Caught |

Structured results and input hashes are in
`proof/tt-01/feedback2/mutations/{mutations,summary}.json`; each mutation has
its own log. No full suite or windowed probe was run in this round.
After the mutations, the normal baseline passed again: 845 Godot checks and
five Python tests. All five production inputs match HEAD byte-for-byte, and
`git diff --check` passes. No open issue remains for the adopted findings;
native Windows execution remains unverified.
Proof-only choices are the explicit encounter fixtures above and a 150-second
per-mutation timeout; production values remain unchanged.

Feedback 2 files: the proof helper, the Godot and Python short-tooltip tests,
the expectations fixture, the mutation replay tool, and this handoff.

## Feedback 1 — discovery resolved

All 39 new entries have a policy and no discovery TODO field remains:

- Eight general-rule defaults from the supplied list: `range`, `time`, `turns`,
  `movement`, `health`, `wait`, `item`, `ember`.
- Two approved no-trigger defaults: `skill_point` and `moltshard`. Progression
  resource gains are not inputs to the existing discovery sync; no trigger was
  invented for them.
- The remaining 29 entries are discovered through the existing observed card,
  intent, enemy-type and Umbra-stage inputs. The library resolves authored
  glossary aliases and action icons (including self-flag stances), card elements,
  Reflect/Flying permanent traits, and the existing Eclipse stage. The sync's
  input fields, memoization, receipts and persistence flow are unchanged.

Feedback 1's original regression found authored encounter witnesses through
the library. Feedback 2 replaces that weak expectation with the independent
fixture and exact-set checks described above. The policy and behavior remain
the same: initial locking, encounter-based unlocking, unread receipts,
idempotent syncs, exact defaults, all TODO removals and the two fallbacks.

Observed focused results for feedback 1:

- `TT01 GRIMOIRE DISCOVERY: PASS (39 entries; 10 default, 29 discovered; no-trigger defaults: skill_point, moltshard)`
- `SHORT CARD TOOLTIPS TEST RESULT: PASS (456 checks, 0 failures)`
- `GLOSSARY TEST RESULT: PASS (6760 checks, 0 failures)`
- `GRIMOIRE SEARCH TEST RESULT: PASS`
- `GRIMOIRE PERFORMANCE RESULT: PASS`
- `GRIMOIRE ROW RETENTION RESULT: {"cases":50,"differences":0,"errors":[],"orphan_nodes":0,"reused_rows":371}`
- `tests/test_short_card_tooltips.py`: `Ran 3 tests` / `OK`.
- `git diff --check`: exit 0.

No full suite or windowed probe was run for feedback 1. Round 0 renderer proof
is accepted. No new chosen defaults or open design issues remain in this round.
Logs are under `proof/tt-01/feedback1/`.

Feedback 1 files: `data/grimoire.json`, `scripts/grimoire_library.gd`,
`tests/short_card_tooltips_test.gd`, and this handoff.

## Requirements

1. All 108 `tooltip` strings from the protected director JSON replace glossary
   definitions verbatim. Names, aliases, icons, entry order, all 29 skills and the
   five unchanged battlefield rules retain their original values. The Python
   regression pins metadata and unchanged entries with baseline hashes.
2. Remove the leading Time panel in the combat hand and opening-boon inspection.
   Reward, shop, deck and codex card previews do not assemble a leading Time
   panel. Keep the Time glossary entry, direct Time inspection, duration tokens,
   contextual explanations, modifiers and Rite panels.
3. Preserve all 94 original Grimoire entries and their body paragraphs. Append
   68 full definitions; create 39 keyword entries; Chilled already has its full
   definition. Feedback 1 resolves discovery for all 39 entries as described above.
   Skill Point and Moltshards use central registry keys for the exact existing
   glossary assets: Grimoire icons require keys, whereas those glossary fields
   contain resource paths. No asset was changed or created.
4. Update pinned tooltip strings and panel expectations; retain the Petrify
   Grimoire paragraph assertions and add the former full definition assertion.
   The new focused program checks all 108 full definitions in the Grimoire and
   exercises production hover paths. It is appended last in the
   headless manifest and matching `POST_SNARE_PROGRAMS` list.

## Layout measurements

These are **headless layout measurements**, not inspected renderer proof.
The ranking scans all 309 cards using production combat display rows, original
director definitions, and the former leading Time panel. Before/after pairs
use the same fixture and production stack; switching copy clears cached rows.

| Card | Before height | After height | Panels |
| --- | ---: | ---: | ---: |
| Lantern Shot | 668 px | 426 px | 6 → 5 |
| Royal Bramble (tallest) | 1079 px | 795 px | 9 → 8 |
| Storm Beacon (second) | 889 px | 584 px | 7 → 6 |

Generated measurements: `proof/tt-01/measurements_headless.json`.
The renderer command independently repeats the ranking and measurements.

## Round 0 renderer reproduction command

The implementation engineer attempted no windowed command because this sandbox
has no macOS window-server access. The design owner has since reported director
acceptance. The following command remains available for reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tt-01 && python3 tools/visual_probe_runner.py --task-id tt-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/proof_contracts/short_card_tooltips.json --result-manifest proof/tt-01/renderer_manifest.json tests/short_card_tooltips_test.gd -- --capture
```

Expected outputs under `proof/tt-01/`: `lantern_shot_before.png`,
`lantern_shot_after.png`, `royal_bramble_before.png`,
`royal_bramble_after.png`, `storm_beacon_before.png`,
`storm_beacon_after.png`, and `measurements.json`. The fixed 1920×1080
SubViewport avoids Retina resampling; settings use 100% UI scale. The contract
requires all six native captures. The longer timeout covers the all-card scan
and production scene fixtures. No inspection-fixture command is required by this
unit; the design owner owns inspection fixture preparation.

## Chosen defaults

Proof-only fields in `tests/helpers/short_card_tooltips_proof.gd`:
`PROOF_SEED=73101`, `SCAN_OWNER_POSITION=(700,320)`,
`SCAN_OWNER_SIZE=(250,352)`, `SETTLE_FRAMES=4`,
`HOVER_SETTLE_SECONDS=0.5`. `FIXTURE` names the 8×8 room, coordinate `(4,3)`,
hero Health 24 and position `(2,4)`, and one Crawler with Health 14 at `(4,4)`.
The inspected card is between Quick Stab and Guarded Step. Baseline-height ties
sort by card id. These values only affect tests and proof. Output files live in
`proof/tt-01/`; isolated settings and save paths start with `user://tt01_`.

## Validation

Observed final focused results:

- `SHORT CARD TOOLTIPS TEST RESULT: PASS (230 checks, 0 failures)`
- `GLOSSARY TEST RESULT: PASS (6760 checks, 0 failures)`
- `GRIMOIRE SEARCH TEST RESULT: PASS`
- `GRIMOIRE PERFORMANCE RESULT: PASS`
- `GRIMOIRE ROW RETENTION RESULT: {"cases":50,"differences":0,"errors":[],"orphan_nodes":0,"reused_rows":371}`
- `PETRIFY CARD PROBE CONTRACT: PASS (Petrify in hand, pointer + keyboard/controller focus, 1920x1080, UI scale 100%)` (`--check-only`, headless, no images).
- UI identity lint: `Ran 25 tests` / `OK`.
- Icon identity policy: `Ran 8 tests` / `OK`.
- Protected copy/metadata/Grimoire Python checks: `Ran 3 tests` / `OK`.
- Text-budget approval, identity, alias and token checks: `Ran 6 tests` / `OK`.
- Baseline glossary: `GLOSSARY TEST RESULT: PASS (7373 checks, 0 failures)`.
- Additional all-affected-domain focused invocation before removing duplicate
  suite calls: `SHORT CARD TOOLTIPS TEST RESULT: PASS (3101 checks, 0 failures)`.
- `git diff --check`: exit 0.

Full Godot suite: `TEST RESULT: FAIL (4 failure(s))`. The main body completed
495,565 assertions. Of 219 child suites, 215 passed, including
`SHORT CARD TOOLTIPS TEST RESULT: PASS (230 checks, 0 failures)`; its runtime was
19.470 seconds. The registration audit reports
`TEST REGISTRATION AUDIT: PASS (841 scripts; full suite=487, quarantined=29, windowed probe=325)`.

Failures are in files verified byte-identical to the task's base revision:

- `special_encounter_test`: real resource loading cannot open imported `.ctex`
  files for Warband, Umbral Snare, Ember Hoarder and Last Light emblems, including
  their director-staged sidecars. Its two emblem-loading assertions fail.
- `enemy_no_action_test`: `Identifier "GameData" not declared in the current scope`
  at `tests/suites/enemy_no_action_suite.gd:36` and `:128`; its dependent script
  cannot compile, then the child times out at 180 seconds.
- `fix_11_test` and `fix_11_probe --check-only`: the same unresolved `GameData`
  identifier prevents their dependency from compiling.

These failures were reported without changing assertions or unrelated files.
This establishes unchanged source, not a separately executed full baseline run.

The workflow's headless `--import` pass then completed with exit 0, populating
the import/global-class caches and generating only the two new scripts' UID
sidecars. All four failed child suites passed on rerun with their original
assertions:

- `SPX special encounter suite: 0 failures`
- `ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)`
- `FIX-11 TEST RESULT: PASS (162 checks, 0 failures)`
- `FIX-11 PROBE CONTRACT: PASS (128 checks; 1920x1080, UI scale 100%)`
- Sidecar checks: `Ran 19 tests` / `OK`.

The original full invocation remains recorded as failed; no second complete
Godot run is claimed. Its 215 passing children plus the four passing reruns
cover all 219 programs. The FIX-11 rerun used `--check-only`, with no renderer
capture claim.

Full commands executed:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tt-01 && python3 tools/godot_task_runner.py --task-id tt-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/tt-01 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Full Python discovery: `Ran 1869 tests in 2537.269s` /
`FAILED (failures=108, errors=2, skipped=66)`.

The 108 subtest failures came from the historical text-budget approval test.
It now reads tt-01's protected definitions as overrides while retaining the
original protected fixture, identities, aliases, entry count and word limits.
Its focused rerun reports `Ran 6 tests` / `OK`.

Both errors came from an absent ignored temporary-output parent directory,
`experiments/cutouts/briar_weaver/mq9/proof/logs`. Creating that empty parent
allowed the unchanged `test_rr21_review.py` suite to pass: `Ran 4 tests in
30.889s` / `OK`. No unrelated test assertions or source files were changed.
The 66 skips include unavailable optional audio modules; full reasons remain
in `proof/tt-01/full-python.log`. No second full Python run is claimed after
these focused fixes. Both original full-run failures and passing reruns are
preserved in the evidence.

The implementation engineer produced no windowed captures. The design owner
subsequently reported director acceptance of the round 0 renderer proof.

Completed logs and the child-suite report are retained under `proof/tt-01/`.
Post-import passing Godot runs also emit sandbox CA-certificate and
ObjectDB/resource cleanup messages at shutdown; the original logs retain them.

## Round 0 files changed

- `data/glossary.json`
- `data/grimoire.json`
- `scripts/action_icon_library.gd`
- `scripts/opening_boon_inspection.gd`
- `scripts/run_scene.gd`
- `tests/fixtures/approved_glossary_structure.gd`
- `tests/glossary_test.gd`
- `tests/hand_card_focus_probe.gd`
- `tests/headless_test_programs.json`
- `tests/petrify_card_probe.gd`
- `tests/run_tests.gd`
- `tests/suites/card_keywords_w3_suite.gd`
- `tests/suites/en01_enemies_suite.gd`
- `tests/suites/en02_enemies_suite.gd`
- `tests/suites/en03_enemies_suite.gd`
- `tests/suites/en04_enemies_suite.gd`
- `tests/suites/en05_enemies_suite.gd`
- `tests/suites/en06_enemies_suite.gd`
- `tests/suites/fix_03_suite.gd`
- `tests/suites/glossary_coverage_suite.gd`
- `tests/suites/magic_deck_suite.gd`
- `tests/suites/tooltip_consistency_suite.gd`
- `tests/suites/turn_clock_copy_suite.gd`
- `tests/suites/turn_clock_hud_suite.gd`
- `tests/test_icon_identity_policy.py`
- `tests/test_program_suite_runner.py`
- `tests/text_budget_test.py`
- `tests/helpers/short_card_tooltips_proof.gd`
- `tests/helpers/short_card_tooltips_proof.gd.uid`
- `tests/proof_contracts/short_card_tooltips.json`
- `tests/short_card_tooltips_test.gd`
- `tests/short_card_tooltips_test.gd.uid`
- `tests/test_short_card_tooltips.py`
- `tests/tt01_handoff.md`
