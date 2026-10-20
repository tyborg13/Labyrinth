# int-04 preservation sweep

Scope: tests and preservation helpers only. Approved art, motion, layouts,
registries, policy data and historical hash ledgers are unchanged.

## Converted checks

| File | Original guard | Historical scope now |
| --- | --- | --- |
| `experiments/cutouts/hollow_mimic/gates.py` and `rr20_preservation.py` | Prior figures' bytes in `protected_inputs.json`; exercised by both rr-20 failing tests | `73e076bfb..901d32789`, the integration tree imported by rr-20 through its signed-off head; all other figure asset/case paths, including added/deleted paths. Mimic's own approved inputs remain live pins. |
| `experiments/cutouts/hollow_mimic/rr26_refresh.py` | Regenerate an authorization ledger for later Seer/Thrall changes | `coverage` validates the same rr-20 range without writing a ledger. `rr26_source_coverage.json` is retained as historical evidence and no gate consumes it. |
| `tests/test_rr24_feedback2.py` | Every alpha, non-colour layout field and gait target position preserved by rr-24's colour rebuild | Read layouts **and PNGs** at `288107b25` (rr-24's final proof head), against the original unchanged feedback-2 pins. This preserves every assertion; excluding later-authorized fields would weaken the colour-only contract. |
| `tests/test_rr21_cutout.py` | Weaver did not touch Seer, Thrall, Mirror or Capacitor assets/cases | `23bc4b2f2..cc92cad47`, imported integration tree through rr-21's final delivery head; no comparison to current HEAD/worktree. |
| `experiments/cutouts/arc_thrall/rr24_preservation.py` | Other figures, approved Thrall jobs/director, unrelated identity/density records | `521fa8f20..288107b25` for protected paths and shared records; own approved jobs/director additionally retain their live byte guard. Range diff replaces the rolling aggregate hash; original `protected.json` remains untouched. |
| `experiments/cutouts/glacial_mirror/rr23_preservation.py` | Exact approved motion hashes are the only allowed changes outside Mirror ownership | The already pinned range is retained; hash exceptions now read **its endpoint blob**, rather than today's bytes. Live authoring calls without an endpoint retain their existing behavior. |
| `spec/art_identity/maquettes/blender/test_creature.py` | mq-05 compiler additions preserved batch-A delivered spec hashes | Foreign recipes and delivery hashes at mq-05 signoff `7bde1e145`; batch-B own-source pins unchanged. |
| `tests/test_arc_thrall_maquette_r2.py` | mq-07 preserved Seer/Herald/Stalker delivered spec hashes | Foreign recipes and delivery hashes at mq-07 signoff `c1ecf9f22`. |
| `tests/test_glacial_mirror_shoulder.py` | mq-08 preserved all other compiled recipes, including Lancer | Foreign recipes and reference hashes at mq-08 signoff `8da120901`. |
| `tests/test_mq09_maquettes.py` | mq-09 sampling/attachment additions were opt-in for prior figures | Foreign recipe inventory, recipe bytes and delivery hashes at mq-09 signoff `2f64d5905`; own invalid-input checks remain live. |
| `spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback4/audit.py` | mq-06 preserved other figures' maquettes/paintings in its fixed hash table | `rear_turn/preservation.py` reads foreign bytes at the audit's owning commit `57d2abd81`; own Seer/shared-tooling checks remain live. |
| `spec/art_identity/maquettes/hoarfrost_seer/rear_turn/feedback5/audit.py` | Same table after Seer rear staging | Same `57d2abd81` audit snapshot, including root-level Shrike files. No historical record is rewritten. |
| `tests/test_mq09_forms.py::test_clean_regeneration_inventory_is_the_current_builder_and_recipe` | Cold-build receipt binds the current native builder and batch-C recipes | Own recipes and native builder bytes/module inventory remain live. Validation-test bytes and other figures' incidental inputs are read at mq-10's sealing head `9b7cba3b2` via `tests/maquette_preservation.py`. Editing a validation test cannot alter native pixels or invalidate an approved receipt. |
| `tests/test_mq09_forms.py::test_merged_builder_baseline_regeneration_inventories_are_current` | mq-10 preserved eight other figures' cold-build inventories, including Seer's rear override | Foreign recipes, receipt metadata, view selection and validation-test inputs read at mq-10's sealing head `9b7cba3b2`; the live native builder/new-module guard is retained. |

The imported integration bases for rr-20/21 include the director-authorized
gait/Mirror changes merged into those branches. Thus the endpoints preserve the
unit's final result without treating those imports as authored foreign edits.

## Sweep exclusions

Searches covered Python, GDScript and shell tests/gates under `tests`,
`experiments`, `tools` and `spec`, including `protected_inputs`, `baseline`,
`byte_identical`, `prior_figures`, `every_other_figure`, Git diff/show reads,
literal SHA-256 values, protected hash tables and compiled-spec delivery pins.

- Existing rr-23 shared-record/shadow checks, gait-01 scope and rr-13 geometry
  preservation already read pinned unit history; unchanged.
- rr-14 Seer identity, rr-17 Capacitor inputs, rr-22 Mortar sources, rr-07/12
  director copies, rr-15/24/27 Thrall paint/motion, protagonist seam references
  and Shrike fill inputs protect their own figure; unchanged.
- `cutout_pipeline`/maquette baseline and protected-input helpers validate their
  supplied case or a single operation's before/after inputs; no foreign-unit
  fixed pin. General delivery/capture validation binds each figure to its own
  current receipt; unchanged.
- UI equivalence, splash/music hashes, synthetic fixture hashes and runtime
  behavior assertions are outside cross-figure preservation; unchanged.

## Mutation proof

`tests/test_int04_preservation.py` makes Git histories only in disposable test
repositories. It exercises the actual converted checks with foreign mutations
committed inside their compared ranges, then restores or changes working bytes
to prove the historical endpoint controls the outcome.

- Range diff: committed foreign edit is rejected; later commits/working edits
  do not affect the original unit range (Mimic and Weaver).
- Shared records: a foreign registry entry inside rr-24's range is rejected,
  even when today's registry is restored; its own live input bytes stay pinned.
- Exact-hash exception: an allowlisted foreign director path is accepted only
  with its approved endpoint bytes; later working bytes cannot authorize it.
- Hash table: foreign historical mutation is rejected; own live mutation is
  still rejected by the original pin.
- Compiled-spec hash: a foreign unit-head recipe mutation is rejected by the
  original mq-07 assertion.
- Colour snapshot: separate unit-head geometry, gait-target and alpha mutations
  each fail the original preservation assertions.
- Regeneration inventory: foreign historical recipe mutations are rejected;
  native builder edits, added native modules and own live recipe edits still
  change the checked inventory. Later validation-test/foreign data edits do not.

Only test defaults were selected: disposable repository identity/messages,
synthetic mutation text/spec id, a one-pixel offset and an alpha-bit XOR of one.
No player-facing defaults or TODO_DESIGN placeholders were added.

`tools/unit_preservation.py` supplies the shared historical blob, tracked-path
inventory and explicit range-diff reads. New mutation coverage is kept in
`tests/test_int04_preservation.py`; the existing tests retain their assertions.

## Inspection

No windowed proof, capture or playable fixture applies: this unit changes tests
and preservation helpers only. Product code, scenes, assets, motion and records
are untouched. The design owner retains commit/review/publication ownership.

Full-suite commands used from this worktree:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-04 && python3 tools/godot_task_runner.py --task-id int-04 --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-04 && LABYRINTH_TASK_ID=int-04 python3 -m unittest discover -s tests -p 'test_*.py'
```

## Observed verification

- Focused rr-20/21/24 and mutation checks:
  `Ran 41 tests in 48.445s` / `OK` (`/private/tmp/int04-focused.log`).
- Focused maquette checks (mq-05/07/08/09 and rr-24 preservation):
  `Ran 52 tests in 13.350s` / `OK`.
- Final mutation checks, including shared records:
  `Ran 7 tests in 10.874s` / `OK`
  (`/private/tmp/int04-mutations-complete.log`).
- Own-input preservation follow-up:
  `Ran 8 tests in 12.809s` / `OK`
  (`/private/tmp/int04-final-checks-fixed.log`).
- Godot full suite, run once with the brief's exact runner command:
  `FULL SUITE RUNTIME: 421.939 seconds (budget 900 seconds)`;
  `TEST RESULT: PASS`; exit 0 (`/private/tmp/int04-godot-full.log`).
- Python full suite, run once:
  `Ran 1396 tests in 1429.645s` /
  `FAILED (failures=9, skipped=63)`; exit 1
  (`/private/tmp/int04-python-full.log`). The brief's three original failures
  were resolved. All nine new failures were the two regeneration inventory
  methods above: their seals hashed `blender/test_creature.py` as builder input.
  The fix scopes validation/foreign inputs without rewriting any receipt or
  weakening native-builder/own-recipe checks.
- Post-fix regeneration and mutation checks:
  `Ran 23 tests in 7.741s` / `OK`
  (`/private/tmp/int04-regeneration-final.log`). Every failing inventory assertion
  was replayed, including all figures and Seer's rear override.

- Final combined focused run on the completed executable patch:
  `Ran 124 tests in 63.407s` / `OK`; exit 0
  (`/private/tmp/int04-final-focused-all.log`). This includes all eight preservation
  tests, rr-20/21/24, mq-05/07/08/09 and all regeneration inventory assertions.
  The added regeneration pattern reports `INT04 REGENERATION MUTATIONS: PASS`.

At the initial handoff, the full Python suite had not been repeated after the
inventory fix, so a final full-suite pass was unverified. Feedback 1 below
requests both full suites again and supersedes that handoff's proof limitation.

The intermediate 116-test focused run had `FAILED (errors=1)` from the new
coverage test importing script-local `case`; it now invokes the actual CLI.
An intermediate 8-test follow-up had `FAILED (failures=1)` because its synthetic
Thrall fixture was incorrectly labeled foreign to Thrall; the fixture now uses
Mimic. Both test defects were fixed and the final focused runs above passed.
No existing master assertion was rewritten.

The supplied pre-task Python log reports `Ran 1388 tests in 1506.195s` /
`FAILED (failures=3, skipped=63)`, naming exactly the two rr-20 tests and the
rr-24 colour-preservation test from the brief.

## Feedback 1: historical inputs and preservation independent of receipts

The four maquette checks retain their compilation/hash assertions. The
`historical_compiler` test context supplies the owning head's exact Lancer blob
to both `compile_recipe.PROJECT` and `creature_recipe.PROJECT`, including the
`compile_solids` path. It writes only a disposable input fixture; production
compiler code, approved Lancer data and native builder receipts stay unchanged.

Each check first compares a pinned range across all foreign maquette namespaces,
including additions and deletions. A matching endpoint recipe/report pair can
no longer authorize a foreign edit.

| Owning unit | Pinned base | Pinned head | Owned figures |
| --- | --- | --- | --- |
| mq-05 | `3fcc62690` | `7bde1e145` | Grub, Tick, Mirror |
| mq-07 | `78d87f474` | `c1ecf9f22` | Thrall |
| mq-08 | `76b75ad3a` | `8da120901` | Mirror |
| mq-09 | `87bd64903` | `2f64d5905` | Mimic, Weaver, Mortar |

mq-07's base is its imported integration tree, including authorized mq-05/06
deliveries. Its own Thrall floor exception lives in Seer's shared floor ledger:
the guard compares all metadata and every other figure's entry, while allowing
only the owning figure's entry to change. Shared builder/base-mesh/proof folders
are outside figure ownership, as before.

| Mutation | Check exercised | Observed result |
| --- | --- | --- |
| Live Lancer `target[0] += 0.01` | mq-05/07/08/09; direct poisoned cloth/solid compilation is a negative control | All four historical checks pass; both historical input paths are isolated |
| Seer head scales doubled and `spec_hash` recomputed to match | Original mq-05/07/08/09 assertions on disposable committed ranges | All four reject the coordinated edit, despite endpoint self-consistency |
| Seer recipe deleted from the endpoint inventory | Original mq-09 assertion | Rejected by the range guard before enumeration can omit it |
| Foreign figure added | Range guards for all four units | All four reject the addition |
| Thrall's own shared floor entry changed, then Seer's entry changed | Shared-record portion of the range guard | Own entry allowed; foreign entry rejected |

Initial focused mutation result: `Ran 12 tests in 10.394s` / `OK`
(`/private/tmp/int04-f1-mutations.log`). The original four positive checks also
passed: `Ran 4 tests in 1.033s` / `OK`
(`/private/tmp/int04-f1-historical-fixed.log`). An earlier focused run caught the
legitimate Thrall floor-ledger update; the field-scoped comparison above fixes
that without excluding Seer's folder or changing the record.

Combined focused result on the feedback-1 executable patch:
`Ran 136 tests in 69.408s` / `OK`; exit 0
(`/private/tmp/int04-f1-focused.log`). This includes all affected maquette tests,
all int-04 negative controls, regeneration receipts and cold-input boundaries,
and the earlier rr-20/21/24 preservation checks.

Feedback-1 Godot full suite, run once:
`FULL SUITE RUNTIME: 405.825 seconds (budget 900 seconds)`;
`TEST RESULT: PASS`; exit 0 (`/private/tmp/int04-f1-godot-full.log`).

Feedback-1 Python full suite, run once:
`Ran 1401 tests in 1425.447s` / `OK (skipped=63)`; exit 0
(`/private/tmp/int04-f1-python-full.log`). Both full suites passed on the
feedback-1 executable patch; the original green-merge acceptance criterion is
now verified. No production code, approved data, art, motion or records changed.

Feedback-1 files: `tests/maquette_preservation.py`,
`spec/art_identity/maquettes/blender/test_creature.py`,
`tests/test_arc_thrall_maquette_r2.py`, `tests/test_glacial_mirror_shoulder.py`,
`tests/test_mq09_maquettes.py`, `tests/test_int04_preservation.py` and this report.
No TODO_DESIGN placeholders or player-facing defaults were added. The new
numeric mutation values (0.01 and 2) are prescribed by the director; only
disposable fixture names/paths were selected. No windowed proof or inspection
fixture applies. Changes are left uncommitted for the design owner.
