# Feedback 2 observed verification

No full suite or windowed run was performed. Headless plans do not prove rendered PNG pixels.

## audit

`CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 74688 samples, 74890 checks, 0 failures)`

## before_plan

`CARD LEGIBILITY CAPTURE PLAN: PASS`

## after_plan

`CARD LEGIBILITY CAPTURE PLAN: PASS`

## card_widget_tooltip_item_preview

Exit 0; PASS.

`CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)`

## reading_layouts

Exit 0; PASS.

`CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)`

## scavenger_inspection

Exit 0; PASS.

`SCAVENGER INSPECTION RESULT: PASS (14 checks, 0 failures)`

## scavenger_visual

Exit 1; FAIL.

`SCAVENGER VISUAL PASS 4: FAIL`

## scavenger_regression

Exit 0; PASS.

`SCAVENGER / MERCHANT / LOADOUT REGRESSION: PASS`

The sole Scavenger visual failure is the preserved baseline `Controller trade buys the inspected card` assertion. Its original source is restored exactly; no assertion changed.

## python_card_legibility

`Ran 4 tests in 32.006s`
`OK`

## ui_identity

`Ran 25 tests in 4.667s`
`OK`

## Scope and proof contracts

`FEEDBACK 2 SCOPE: PASS (original shelf restored; only scavenger_offer metrics changed; 31 contexts unchanged)`

`PROOF SOURCE CONTRACT: PASS (before; 16 native SubViewport capture plans, no headless PNG readback)`

`PROOF SOURCE CONTRACT: PASS (after; 16 native SubViewport capture plans, no headless PNG readback)`

The pre-decision inspection passed 11 checks. The post-restoration inspection adds native-size/ancestor-scale assertions and passes 14 checks. An initial numeric-only-card fixture handling error and an incorrect assumption about the Graftwright sample glyph size were corrected before the final runs.

