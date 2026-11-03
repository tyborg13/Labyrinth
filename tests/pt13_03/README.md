# pt13-03 feedback 3 handoff

Changes remain uncommitted on `codex/pt13-03`. The accepted visuals and seven
exemption reasons are unchanged. No peer review, publication, full suite or
windowed run was performed. The director's existing capture changes are preserved.

## 1. Production hierarchies and resting transforms

The catalog now uses `card_legibility_contexts.gd`: sixteen independent,
1920×1080 production RunScenes. Each context opens its real screen/overlay and
selects a face created by the production caller. Catalog definitions and their
variant rows are applied to that live face without detaching/reparenting it.
The hand uses its actual fan, pile/purge use their real dialogs and pools,
Grimoire uses its detail-page row, and the other callers retain their native
screen, popover, tooltip, proxy or Boon hierarchy. The retained upgrade/legacy
sell contexts invoke their real builders inside the owning production screen.
Graftwright's text-only inspection uses its actual ExactRules popover, which
prints base/ID rules as production does. It intentionally has no summary icons.

`card_legibility_settle.gd` waits for pending finite tweens, including delays,
then requires three consecutive exactly unchanged global-transform frames for
the card and every CanvasItem/CanvasLayer ancestor. It fails after three seconds;
the audit does not measure a timed-out batch. Infinite cosmetic tweens are not
awaited, but any ancestor transform movement still prevents settling. Thus the
initial quiet part of a one-second-delayed tween cannot count as rest.

[audit.json](audit.json) records live node paths, settled frame counts, complete
production ancestor snapshots and the native pre-override measurements. The
pre-override check also guards the production caller before any variant layout
work. The report validates printed IDs, definition/variant-row signatures and
surcharges, so asynchronous refresh cannot silently substitute another face.
`make_card` remains only for isolated component fixtures and accepted visual
proof; the catalog driver does not use its synthetic wrappers.

## 2. Non-vacuity and negative fixtures

Every sample must be visible, have area intersecting its viewport/clipping
ancestors, have nonzero inherited alpha, and provide a rules/token measurement.
Definitions with content glyphs or summary/inline icons require those
measurements; an unchanged time badge cannot disguise a removed rules surface.
Optional absent footer/text-only-popover icons remain explicitly optional.
Hidden/missing-content failures apply even to the seven size exemptions.

Each context must sample every definition and have a nonzero count. Empty
input/context sets fail. Negative fixtures reject a hidden face, removed rules
surface (including missing expected icons), and an empty context. They also
prove that a one-second delayed tween is awaited and a continuously moving
ancestor fails at the three-second cap.

The seven mutation checks all report `REJECTED`: equipment preview restored to
180 px, summary-type shrink, rules-font shrink, removed shared minimum, hidden
Thorn Crown Pact, the production Grimoire row at half scale, and a production
CardScaleFrame tween delayed one second. The Grimoire mutation applies its scale
after container layout, so it tests a genuinely half-sized resting row rather
than an assignment normalized away by Container layout. Rejections require the
expected assertion failure and reject parser/script errors as evidence.

## 3. UID sidecars

The runner's `godot --headless --path . --import` generated all eight requested
sidecars and sidecars for the three new helpers: **11 adjacent .gd.uid files**.
[sidecars.json](feedback3/sidecars.json) lists every source/UID pair. No UID was
invented or ignored. The first 180-second import reached the existing image
archive and timed out; the 600-second bounded continuation completed. Logs:
[import.log](feedback3/import.log), [import_complete.log](feedback3/import_complete.log).

The repository sidecar guard passes against the prospective handoff file set
(tracked sources plus the eleven new source/UID pairs). The Git index was left
unchanged, so the design owner can commit the pairs together.

## 4. Hotspot and generated output

The Grimoire wrapping-row constructor now belongs to `ItemPreviewBuilders`;
the preserved grid-width constant belongs to `PileDialogView`. `run_scene.gd`
is **34,609 lines**, versus **34,612 at base**. No layout values changed.

`.gitignore` excludes `tests/pt13_03/**/captures/` and generated
`*_manifest.json` files. Existing tracked capture measurements modified by the
director before this round were preserved; no new capture/manifest was staged
or created. Audit contracts, source, UIDs and the headless audit report remain
reviewable source/evidence.

## Observed verification

```text
CARD LEGIBILITY TEST RESULT: PASS (2334 definitions, 32 contexts, 74688 samples, 80203 checks, 0 failures)
CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 236 checks, 0 failures)
CARD LEGIBILITY NEGATIVE FIXTURES: PASS (7 checks, 0 failures)
CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)
CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)
SCAVENGER INSPECTION RESULT: PASS (14 checks, 0 failures)
SCAVENGER / MERCHANT / LOADOUT REGRESSION: PASS
SCAVENGER VISUAL PASS 4: FAIL
```

The sole Scavenger visual failure is still the permitted baseline assertion
`Controller trade buys the inspected card`; it was not rewritten. All seven
mutations were rejected. Python portability/sidecar-guard fixtures: 19 tests,
`OK`. UI identity lint: 25 tests, `OK`. [Exact result lines and diagnostics](feedback3/verification.md).

The full catalog run ends cleanly. The short live-scene regression emits
production `run_scene.gd` function-state/ObjectDB shutdown warnings while its
assertions and runner exit pass; the diagnostics are retained. The normal macOS
headless CA-certificate warning also remains in the engine logs.

The per-context minima are in [result.md](result.md). Native Boon sizing is now
measured in its actual secondary-screen ancestors, rather than approximated by
the reward row; its catalog minimum remains above the floor. All 32 contexts
have 2,334 visible, validated samples; all data/variant coverage is retained.
The accepted Sabatons/Couched Lance/Stonefist fixes, 224 px equipment previews,
shared 0.875 minimum, original Scavenger layout, wording and assets are unchanged.
The previously recorded Cloudstep Loop/Worldbreak text overflows remain.

Reproduction, from this worktree:

```bash
python3 tools/godot_task_runner.py --task-id pt13-03 --timeout 1200 --stream -- godot --headless --path . --script tests/card_legibility_test.gd
python3 tools/godot_task_runner.py --task-id pt13-03 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --regressions-only
python3 tests/pt13_03_focused.py negative_fixtures card_widget_tooltip_item_preview reading_layouts scavenger_inspection scavenger_visual scavenger_regression
python3 tests/run_card_legibility_mutations.py
python3 tests/test_ui_identity_lint.py
```

## Files and defaults

Production changes: `.gitignore`, `scripts/run_scene.gd`,
`scripts/item_preview_builders.gd`, `scripts/pile_dialog_view.gd` (extraction only).
Audit implementation: `tests/card_legibility_test.gd`,
`tests/helpers/card_legibility_audit.gd`, and new `card_legibility_contexts.gd`,
`card_legibility_settle.gd`, `card_legibility_negative.gd` helpers.
Focused/mutation/report tools and their generated feedback-3 evidence were
updated, along with all eleven UID sidecars. The inspection helper writes new
evidence to feedback3, preserving accepted feedback2 evidence.

New chosen defaults are test-only: the sixteen-worker pool and named fixture
IDs/storage paths. Three stable frames, the three-second cap and exact
transform equality implement the director's requirement. Existing fixture
states, UI values and timeouts are reused; the longer import/catalog caps cover
the observed archive/live-scene workload. No player-facing value was chosen.

No new TODO_DESIGN placeholder remains. Open items are the known Scavenger
baseline assertion, the short-regression shutdown diagnostics, and the prior
copy-overflow findings. Native captures were already accepted; no new visual
proof or sign-off is requested.

The before evidence is historical, recorded at 591da4132.

If the director wants to regenerate the accepted current-code proof, the existing
command remains:

```bash
python3 tests/pt13_03_proof.py --phase after
```

Generated PNGs and manifests are now ignored.
