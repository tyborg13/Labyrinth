# card-01 — feedback 1 evidence

Feedback changes are uncommitted on `codex/card-01`, starting from the director’s `102995e0034336d73b4c153e71dd7e21a1312c86`. No commit, publication, queue edit, or peer review was performed by this worker.

## Review findings

1. **Continuation glyphs stay attached.** Overflowing rows bundle the glyph and following item into one unbreakable unit, retaining their existing internal spacing. Tightening changes gaps between units. Hall of Mirrors base and all upgrade definitions are named regressions in every reading context, including deck and hovered hand.
   Hall’s native caption unit is 171 px (15 px glyph + existing 3 px gap + 153 px caption). At deck scale its actual available width is 171.43 px, while integer centering leaves only 1.752 px on one side. Exact geometric centering gives about **2.190 screen pixels on each side**, preserving the whole unit, font, and spacing. This fractional placement is derived from centering, with no new tuning value.
2. **Fit and preservation are per face.** The 2 px inset uses the face’s actual global scale. A scale change reflows only when the rounded inset changes; position-only changes and 30 idle frames retain the same row objects. The comparator runs for every after sample without `--before`, keyed by context/card/variant. Immutable baseline fixtures are included for the owner’s next commit; after-runs require no old code.
   **240 faces changed**, exactly the 240 formerly overflowing faces in the full baseline corpus. The 72 previously fitting faces changed by the fixed-scale implementation are restored. In the registered 400-sample sweep, all 144 already-fitting CardWidget faces and 16 text-only popovers retain identical fingerprints.
3. **Vertical checks always run.** Every measured sample checks the complete visible bounds of rows, composite items, icons, value suffixes and text. The check is independent of the baseline comparison. A synthetic icon extending beyond its token also exercises this measurement.
4. **Renderer proof accepted by the director.** The director ran and judged the captures at:

   - `proof/card-01/before-20261027T214759799029Z`
   - `proof/card-01/after-20261027T214841016280Z`

   **Director verdict:** Worldbreak and Cloudstep Loop wrap cleanly in deck view and the hovered hand. This resolves finding 4 for `102995e00`; no further capture work was done for that finding. The existing eight PNGs were read during this feedback pass. The updated after plan below adds Hall of Mirrors for the director’s feedback re-capture.

## Scope and baseline

The registered `--regressions-only` sweep and the default invocation select 16 definitions: every base/upgraded definition of Worldbreak, Cloudstep Loop and Hall of Mirrors, plus base Quick Stab as an unaffected control in each context. It measures **400 samples across 25 contexts** and includes **all 240 changed faces**. Full 58,350-layout execution requires the explicit `--full-matrix` option and was not run this round. Full project suites were not run.

Baseline files: `tests/fixtures/card_summary_fit_baseline_focused.json` and `tests/fixtures/card_summary_fit_baseline_full.json`. Both reference original commit `64c6a6d267a985954998846c5663ba1f4ba7dea6` and CardWidget SHA-256 `8b794e01111cbbaa5d36f980bb63e2c6e9dfaf38727054a0f9e24085d4240441`. The full fixture compacts the previously observed 58,350-sample original-code report; the focused fixture was recorded using the original script on this round’s focused selection. Separate fixtures retain exact hidden-control geometry for each pool assignment as well as visible geometry. Recording requires that original script hash, preventing accidental rebasing onto the implementation being tested.

Card data, words, numbers, fonts, icons, art, colours, card sizes, saves and analytics remain unchanged.

## Focused per-context results

All rows have zero horizontal, vertical, continuation and floor failures. Values are minimum row-edge margins in actual screen pixels at 1920×1080, 100% UI scale.

| Context | Samples | Before margin px | After margin px | Changed faces |
|---|---:|---:|---:|---:|
| `hand_1_focused` | 16 | -3.195 | 2.130 | 4 |
| `hand_1_hovered` | 16 | -3.195 | 2.130 | 4 |
| `hand_1_targeting` | 16 | -2.773 | 2.311 | 13 |
| `hand_7_focused` | 16 | -3.195 | 2.130 | 4 |
| `hand_7_hovered` | 16 | -3.195 | 2.130 | 4 |
| `hand_7_targeting` | 16 | -2.773 | 2.311 | 13 |
| `hand_controller_focused` | 16 | -3.656 | 2.437 | 4 |
| `reward_offers` | 16 | -3.504 | 2.336 | 4 |
| `boon_spells` | 16 | -2.932 | 2.443 | 13 |
| `scavenger_detail` | 16 | -3.000 | 2.000 | 4 |
| `deck_view` | 16 | -2.628 | 2.190 | 13 |
| `grimoire` | 16 | -2.880 | 2.400 | 13 |
| `grimoire_equipment` | 16 | -2.628 | 2.190 | 13 |
| `card_tooltip` | 16 | -2.688 | 2.240 | 13 |
| `chronicle_card` | 16 | -2.688 | 2.240 | 13 |
| `equipment_tooltip` | 16 | -2.688 | 2.240 | 13 |
| `chronicle_equipment` | 16 | -2.688 | 2.240 | 13 |
| `graftwright` | 16 | -2.628 | 2.190 | 13 |
| `graftwright_inspection` | 16 | N/A | N/A | 0 |
| `campfire` | 16 | -2.628 | 2.190 | 13 |
| `purge_picker` | 16 | -2.628 | 2.190 | 13 |
| `pile_dialog` | 16 | -2.628 | 2.190 | 13 |
| `purge_confirmation` | 16 | -3.000 | 2.000 | 4 |
| `upgrade_preview` | 16 | -2.628 | 2.190 | 13 |
| `card_fx_staged` | 16 | -2.696 | 2.246 | 13 |

Graftwright inspection is a text-only base-ID rules popover with no summary row; modified card faces are covered separately in `graftwright`. Existing pt13-03 exemptions remain unchanged.

## Observed result lines

```text
CARD SUMMARY BEFORE RESULT: PASS (2831 checks, 0 failures, 400 samples)
CARD SUMMARY FIT RESULT: PASS (3788 checks, 0 failures, 400 samples)
CARD SUMMARY CHANGED FACES: 240
CARD SUMMARY FIT UNIT RESULT: PASS (22 checks, 0 failures)
CARD WIDGET EXISTING LAYOUT RESULT: PASS (149 checks, 0 failures)
CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)
CARD LEGIBILITY NEGATIVE FIXTURES: PASS (26 checks, 0 failures)
CARD SUMMARY PROOF PLAN: PASS (0 failures)
UI identity lint: Ran 25 tests; OK
TEST REGISTRATION AUDIT: PASS (875 scripts; full suite=513, quarantined=29, windowed probe=333)
ISOLATION AUDIT: 227 modules
FOCUSED COVERAGE: PASS (240/240 previously overflowing faces covered and changed; no fitting face changed)
FEEDBACK1 STATIC CHECKS: PASS (Python, JSON, eight captures, Windows-safe typed arrays)
```

The existing main-suite assertion bodies were invoked by the focused layout entry point and were not modified. No new Python unittest module was introduced; the mutation runner is a documented manual utility.

## Review mutation replay

All mutations run the registered `--regressions-only` sweep without `--before` in an isolated project copy.

| Mutation | Registered sweep result | Detector |
|---|---|---|
| Review’s Quick Stab gap increment | FAIL: 24 assertions | Per-sample fitting fingerprint |
| Review’s wrapped-line minimum height 400 | FAIL: 160 assertions | Complete vertical bounds |
| Restore fixed minimum-scale inset | FAIL: 72 assertions | Per-sample fitting fingerprint |
| Disable continuation-unit bundling | FAIL: 80 assertions | Orphaned continuation glyph |

```text
CARD-01 MUTATION quick_stab_gap: REJECTED
CARD-01 MUTATION wrapped_height_400: REJECTED
CARD-01 MUTATION fixed_scale_inset: REJECTED
CARD-01 MUTATION split_continuation: REJECTED
```

Mutation evidence: [results.json](/Users/borgerding/workspace/Labyrinth.worktrees/card-01/proof/card-01/feedback1-mutations-20261027T231856326162Z/results.json). Focused measurements: [feedback1-final.json](/private/tmp/labyrinth_codex/card-01/feedback1-final.json).

## Commands

Focused checks:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-01 && python3 tools/godot_task_runner.py --task-id card-01 --stream -- godot --headless --path . --script tests/card_summary_fit_test.gd -- --regressions-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-01 && python3 tools/godot_task_runner.py --task-id card-01 --stream -- godot --headless --path . --script tests/card_summary_fit_unit_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-01 && python3 tests/card_01_mutations.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-01 && python3 tests/card_01_proof.py --phase after --plan-only
```

The after plan passed and recorded eight native-frame cases, adding base and upgraded Hall of Mirrors to Worldbreak and upgraded Cloudstep Loop in both contexts. Plan measurements: [measurements.json](/Users/borgerding/workspace/Labyrinth.worktrees/card-01/proof/card-01/after-20261027T231857496163Z/measurements.json). No windowed run was attempted in this sandbox.

**Proof for the design owner — updated after capture:**

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-01 && python3 tests/card_01_proof.py --phase after
```

This uses `tools/visual_probe_runner.py`, one attempt, 1920×1080, 100% UI scale, the eight-image contract, and a fresh `proof/card-01/after-<UTC timestamp>/` directory containing `manifest.json`, `measurements.json`, and `hand_7_hovered_*.png` / `deck_view_*.png`. The director performs this re-capture for findings 1–3.

**Full matrix (opt-in; not executed this round):**

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-01 && python3 tools/godot_task_runner.py --task-id card-01 --timeout 900 --stream -- godot --headless --path . --script tests/card_summary_fit_test.gd -- --full-matrix
```

## Files changed in feedback 1

- `scripts/card_widget.gd`: actual-scale inset/refit, atomic continuation units and exact centering when integer placement cannot fit the complete unit.
- `tests/card_summary_fit_test.gd`: unconditional per-sample preservation, vertical bounds and continuation checks; focused default; explicit full-matrix option; face-count report.
- `tests/helpers/card_summary_fit_measure.gd`: complete item bounds and continuation diagnostics.
- `tests/helpers/card_summary_fit_baseline.gd` and both `tests/fixtures/card_summary_fit_baseline_*.json` files: frozen baseline corpus and per-sample lookup.
- `tests/card_summary_fit_unit_test.gd`: continuation spacing, scale reflow/restoration, idle stability and tall-icon bounds.
- `tests/card_01_mutations.py`: isolated replay of the four review mutations.
- `tests/card_summary_fit_probe.gd`, `tests/card_summary_fit_proof.json`, `tests/card_01_proof.py`: eight-case Hall-inclusive after proof.
- `tests/card_01_results.md`: this updated evidence record.

## TODO_DESIGN placeholders and chosen defaults

No TODO_DESIGN placeholders. No new player-facing tuning choices. The zero-scale division guard is the named technical epsilon `0.001`. New unit-only geometry uses the measured 15 px glyph / 153 px caption / existing 3 px internal gap, a 400 px tall-icon fixture, and 30 idle frames. The existing one-screen/16-face pool, headless FPS 0, 180-second proof/mutation limits and proof crops are retained.

## Open issues

No unresolved focused/headless acceptance failures. Updated native after re-capture remains with the director; finding 4’s earlier renderer verdict is already accepted. The baseline fixture files are ready to be included in the owner’s next commit.

Known macOS certificate and ObjectDB/resource shutdown diagnostics remain observable in the existing capture-plan/negative-fixture paths; those processes return 0 and their assertions pass.
