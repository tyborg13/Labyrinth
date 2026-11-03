# Feedback 3 observed verification

Only focused programs ran. No full suite, peer review, publication, or windowed run.

## audit_final

`CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 74688 samples, 80203 checks, 0 failures)`

## regressions_final

`CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 236 checks, 0 failures)`

## negative_final

`CARD LEGIBILITY NEGATIVE FIXTURES: PASS (7 checks, 0 failures)`

## focused

`CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)`
`CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)`
`SCAVENGER INSPECTION RESULT: PASS (14 checks, 0 failures)`
`SCAVENGER VISUAL PASS 4: FAIL`
`SCAVENGER / MERCHANT / LOADOUT REGRESSION: PASS`

## mutations_final

`CARD LEGIBILITY MUTATION equipment_180: REJECTED`
`CARD LEGIBILITY MUTATION fit_shrinks_type: REJECTED`
`CARD LEGIBILITY MUTATION shared_minimum_removed: REJECTED`
`CARD LEGIBILITY MUTATION rules_shrink: REJECTED`
`CARD LEGIBILITY MUTATION hidden_face: REJECTED`
`CARD LEGIBILITY MUTATION grimoire_ancestor_half: REJECTED`
`CARD LEGIBILITY MUTATION delayed_scale_one_second: REJECTED`

## ui_identity

`Ran 25 tests in 4.595s`
`OK`

## python_guards

`Ran 19 tests in 0.051s`
`OK`

Headless import completed successfully on the 600-second bounded run. The initial 180-second run timed out during reimport of the existing image archive; both logs are retained.

The sidecar guard passes against the prospective handoff source/sidecar set; the Git index was left unchanged.

The short live-scene regression emits ObjectDB/function-state shutdown warnings referencing production run_scene.gd; its assertions and runner exit pass. The full live catalog run ends cleanly. The Scavenger visual suite retains only its previously documented baseline assertion.
