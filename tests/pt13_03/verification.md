# pt13-03 verification

All commands ran through the required task/visual runners. No windowed command ran in this sandbox. Changes remain uncommitted.

## Observed focused results

### Catalog audit

```text
CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 74688 samples, 74882 checks, 0 failures)
```

### Card widget / tooltip / item preview

```text
CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (381 checks, 0 failures)
```

### Latest overflow / footer / Sabatons regression

```text
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 203 checks, 0 failures)
```

### Locked tooltip bounds

```text
CARD LEGIBILITY EQUIPMENT BOUNDS: splintered_shield (482.0, 417.0) (46 two-card items)
CARD LEGIBILITY EQUIPMENT BOUNDS TEST: PASS (185 checks, 0 failures)
```

### Card pool

```text
CARD POOL OVERHAUL: PASS
```

### Tooltip copy and layout

```text
SHORT CARD TOOLTIPS TEST RESULT: PASS (845 checks, 0 failures)
```

### Mutation checks

```text
CARD LEGIBILITY MUTATION equipment_180: REJECTED
CARD LEGIBILITY MUTATION fit_shrinks_type: REJECTED
CARD LEGIBILITY MUTATION rules_shrink: REJECTED
```

### Registration

```text
TEST REGISTRATION AUDIT: PASS (858 scripts; full suite=502, quarantined=29, windowed probe=327)
```

### Before capture plan

```text
CARD LEGIBILITY CAPTURE PLAN: PASS
```

### After capture plan

```text
CARD LEGIBILITY CAPTURE PLAN: PASS
```

### UI identity lint

```text
Ran 25 tests in 6.617s
OK
```

### Focused Python

```text
Ran 2 tests in 7.446s
OK
```

## Full-suite status

Final serial Godot run completed all 227 child suites in 785.763 seconds. Main body: 495,562 assertions in 315.104 seconds. Overall observed line: `TEST RESULT: FAIL (2 failure(s))`: `main_menu_input_test` (startup seal fade assertion) and `special_encounter_test` (missing emblem import-cache entries). `STATUS MOVEMENT PROBE RESULT: PASS`. The card regression child passed all 203 checks.

Targeted startup recheck: `TEST RESULT: PASS — main menu input and startup transitions`. Special-encounter recheck after recovering all eight matching import-cache entries: `SPX special encounter suite: 0 failures` (runner exit 0). Both failing full-suite children therefore pass independently; the full-suite result remains recorded as FAIL, not retroactively changed to PASS.

Earlier full Godot attempts: `TEST RESULT: FAIL (2 failure(s))` (missing emblem import-cache entries and the unchanged 4000 µs cold-plan check measuring 5288 µs); `TEST RESULT: FAIL (44 failure(s))` (180/900-second child/program limits under concurrent test load). All eight matching import-cache entries (Warband, Umbral Snare, Ember Hoarder, Last Light; live and staged paths) were copied from the base worktree after source MD5 and byte-identity checks; no source or asset values changed. Assertions and scheduler limits were preserved.

Extra full Python discovery was interrupted in `test_rr41_feedback1.py::test_every_front_pose_and_rounding_choice_has_no_unpainted_exposure` during its 2048-case asset sweep (exit 130 / `KeyboardInterrupt`). It is **incomplete**, not a pass. The required runtime full suite is Godot; the focused Python checks above completed.

## Windowed proof

Both phases construct seven capture cases headlessly and emit `measurements.json`; there are no screenshot PNGs. The exact design-owner commands, capture paths, and proof contract are in `README.md`.

## Source fingerprints

- `scripts/card_widget.gd`: `c6c1baf00baf67144963f3d1edeff5cb840d34b05efdf077610e892824141852`
- `scripts/item_preview_builders.gd`: `176697672eee1cddd14a1b9395e2ab6c972a89530181a9d1c6707c0087275059`
- `tests/helpers/card_legibility_audit.gd`: `db92bbd6a42955b60960b1891bfb949fe3fd57a8ecef25c33e8f08b249f50c69`
- `tests/card_legibility_test.gd`: `a339901dea0562bf7f08dadbe89a7813e1440991318dd48f90f51c8cef9e7cba`

## Final scope and remaining owner work

All unit-specific acceptance checks pass, including every non-exempt audit context, Sabatons, plain/summary overflow handling, visible footer and watch-number floors, all three rejected mutations, focused tooltip/card/item-preview checks, UI lint, and registration. The remaining work assigned to the design owner is windowed before/after capture and inspection, decisions on fourteen measured design exemptions and the two overflow cards, commit, peer review, and publication. The unused legacy RunScene size constant is documented in README.md.

Full-suite machine-readable results are in `full_suite_serial.json`; all changed paths are in `changed_files.txt`.
