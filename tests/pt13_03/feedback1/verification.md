# Feedback 1: observed verification

Only focused suites and the full card catalog audit were run. No full Godot/Python suite or windowed command was run.

## audit

`CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 74688 samples, 74889 checks, 0 failures)`

## before_plan

`CARD LEGIBILITY CAPTURE PLAN: PASS`

## after_plan

`CARD LEGIBILITY CAPTURE PLAN: PASS`

## card_widget_tooltip_item_preview

Exit 0; PASS.

`CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)`

## scavenger_regression

Exit 0; PASS.

`SCAVENGER / MERCHANT / LOADOUT REGRESSION: PASS`

## graftwright

Exit 0; PASS.

`Graftwright suite: 0 failures`

## graftwright_console

Exit 0; PASS.

`GRAFTWRIGHT CONSOLE TEST: PASS`

## pile_viewer

Exit 0; PASS.

`PILE VIEWER TEST: PASS`
`TEST RESULT: PASS`

## grimoire

Exit 0; PASS.

`GRIMOIRE SEARCH TEST RESULT: PASS`

## grimoire_equivalence

Exit 0; PASS.

`GRIMOIRE ROW RETENTION RESULT: {"cases":50,"differences":0,"errors":[],"orphan_nodes":0,"reused_rows":371}`

## magic_deck

Exit 0; PASS.

`MAGIC DECK TEST: PASS`
`TEST RESULT: PASS`

## campfire_purge_deck_input

Exit 0; PASS.

`PURGE WHOLE-ROW SCROLL CHECKS: PASS`
`MAGIC DECK INPUT TEST: PASS`
`TEST RESULT: PASS`

## scavenger_visual

Exit 1; FAIL.

`SCAVENGER VISUAL PASS 4: FAIL`

The only remaining assertion is `Controller trade buys the inspected card`. It checks `magic_inventory`, although the current feature places purchased spells into the deck. The identical assertion fails using the accepted round-0 Scavenger script at `d63d005f0`; see `scavenger_visual_baseline.log`. It was preserved. The new banner-clearance and tag-containment failures were fixed.

## reading_layouts

Exit 0; PASS.

`CARD READING LAYOUT RESULT: PASS (345 checks, 0 failures)`

## purge_guard_mutations

Exit 0; PASS.

`TEST RESULT: PASS`

## Mutations

`CARD LEGIBILITY MUTATION equipment_180: REJECTED`
`CARD LEGIBILITY MUTATION fit_shrinks_type: REJECTED`
`CARD LEGIBILITY MUTATION shared_minimum_removed: REJECTED`
`CARD LEGIBILITY MUTATION rules_shrink: REJECTED`

## Python focused checks

python_card_legibility:

`Ran 3 tests in 14.588s`
`OK`

ui_identity:

`Ran 25 tests in 3.357s`
`OK`

## Runtime diagnostics

The macOS headless engine prints its existing `get_system_ca_certificates` warning. Successful checks are reported only from observed result lines and exit codes. An initial fixture compile/name error and fixture expectation failures were corrected before the final runs.


`CONTEXT SIZE SCOPE: PASS (8 requested contexts changed; 24 unchanged)`

`SCAVENGER BASELINE COMPARISON: PASS (identical existing assertion; no new failures)`

`PROOF PLAN SOURCE CHECK: PASS (before, 15 captures, current/accepted sources)`

`PROOF PLAN SOURCE CHECK: PASS (after, 15 captures, current/accepted sources)`

`FINAL AUDIT CONTRACT: PASS (six named exemptions; all other contexts meet floor)`
