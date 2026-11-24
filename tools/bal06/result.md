# bal-06 implementation proof

The before snapshot is `23152865ae25efdea3a915fc7bb56fe2a10e18fd` on `codex/release`. The after snapshot is the uncommitted `codex/bal-06` worktree. The task uses the standard risk tier. Raw proof logs, scores and the pin manifest are in `/private/tmp/labyrinth_codex/bal-06/`.

## 1. Card data and player-facing copies

| Card | Applied change | Catalogue lines in `data/cards.json` | Authored face |
| --- | --- | --- | --- |
| Grave Mortar | Time 6 → 5, damage 9 | 2221 | Generated |
| Molten Reach | Damage 4 → 5 | 1219, 1225 | Generated |
| Volt Surge | Damage 4 → 5 | 1848, 1854 | Generated |
| Arc Flash | Damage 3 → 4, Follow-up Chain 2 | 5930, 5946 | Generated |
| Stone Ward | Block 5 → 7 | 8762, 8768 | Generated |
| Gale Ward | Block 5 → 6, Push 1 | 7700, 7707 | Generated |
| Hoarfrost Ward | Block 5 → 6 | 7906, 7912 | `data/card_faces.json:377` |

```sh
rg -ni 'grave[ _]mortar|molten[ _]reach|volt[ _]surge|arc[ _]flash|stone[ _]ward|gale[ _]ward|hoarfrost[ _]ward' \
  data scripts scenes tests tools assets/tooltip_loops \
  -g '!*.log' -g '!*.uid' -g '!*.import' -g '!tools/bal06/**' --max-columns 240
rg -ni '\b(grave[ _]mortar|molten[ _]reach|volt[ _]surge|arc[ _]flash|stone[ _]ward|gale[ _]ward|hoarfrost[ _]ward)\b' \
  data/tooltip_loops.json scripts/tooltip_loop_registry.gd assets/tooltip_loops tools/tooltip_loops \
  -g '!*.uid' -g '!*.import'
```

The search found six catalogue descriptions, Hoarfrost Ward's authored sentence face, generated display lookups, numeric test expectations and layout fingerprints. Documentation and benchmark snapshots preserve the revisions they measure. The search output is saved as `card-copy-search.txt` and `loop-card-search.txt`.

The live probe checks the Time badge, damage or Block face value, damage in the attack keyword text, the Block keyword definition, and every card's exact Grimoire description and Time. Ward Block amounts and Grave Mortar's Time are visible on the card face while hovering. The shared Block and Time glossary definitions have no card-specific amounts.

`BAL-06 DATA DELTA PASS: only the seven approved card values and their numeric copies changed`. An equality check against the candidate data with only the approved substitutions covers every other field and card, including bal-04 and bal-05.

## 2. Reward-pool score

```sh
git show 23152865a:data/cards.json > /private/tmp/labyrinth_codex/bal-06/cards-before.json
python3 tools/card_heuristic.py --reward-pool --json --cards-path /private/tmp/labyrinth_codex/bal-06/cards-before.json
python3 tools/card_heuristic.py --reward-pool --json
```

| Card | Rarity | Brief before → after | Measured before → after |
| --- | --- | --- | --- |
| Grave Mortar | Rare | 2.87 → 3.32 | 2.8722 → 3.3222 |
| Molten Reach | Rare | 2.91 → 3.44 | 2.9149 → 3.4408 |
| Volt Surge | Rare | 2.92 → 3.51 | 2.9165 → 3.5122 |
| Arc Flash | Common | 2.58 → 3.19 | 2.5785 → 3.1933 |
| Stone Ward | Common | 2.55 → 3.05 | 2.5460 → 3.0460 |
| Gale Ward | Common | 2.67 → 2.92 | 2.6666 → 2.9166 |
| Hoarfrost Ward | Common | 2.69 → 2.94 | 2.6900 → 2.9400 |

| Rarity | Reward cards | Median before → after | Leader in both snapshots |
| --- | ---: | --- | --- |
| Common | 53 | 3.1479 → 3.1831 | Beacon, 4.7275 |
| Rare | 40 | 3.5756 → 3.5756 | Trapdoor, 5.5200 |
| Epic | 21 | 2.7000 → 2.7000 | Ball Lightning, 5.0941 |
| Legendary | 12 | 4.5575 → 4.5575 | Skybolt, 6.6238 |

Every score is within 0.02 of the brief. These are the only seven reward-pool score changes. None leads its rarity. Raw files are `scores-before.json` and `scores-after.json`.

## 3. Test pins

| File and changed lines | Exact expectation or copied value | Verification |
| --- | --- | --- |
| `tests/suites/maneuver_suite.gd:22,191` | Gale Ward fixture Block 5 → 6 and exact resolution assertion 5 → 6 | Focused maneuver suite, 0 failures |
| `tests/suites/card_mechanics_surfaces_suite.gd:31` | Hoarfrost Ward mirror fixture Block 5 → 6 | Focused surface suite, 0 failures |
| `tools/pla03/face_fit_check.gd:216,224–225` | With Reinforced Shield, Hoarfrost Ward shows Block 9 and Sun Flash shows Block 8 | Face fit, 18,944 checks and 0 failures |
| `tools/pla03/sentence_face_probe.gd:501,511` | Same exact relic expectations in the rollout probe | `review_hoarfrost_ward_relic` reached with the check satisfied headlessly |
| `tests/fixtures/card_summary_fit_baseline_full.json:1` | Refresh 360 Arc Flash and 216 Molten Reach fingerprints. Preserve every existing margin and unrelated sample | 576 introduced mismatches resolved |

The layout comparison selected these seven cards from the existing opt-in fit harness in a scratch copy and kept its original assertions for 25 contexts and 1,550 samples. Candidate `CARD SUMMARY FIT RESULT: FAIL (15390 checks, 625 failures, 1550 samples)`. Edited cards with the original pins had `CARD SUMMARY FIT RESULT: FAIL (15390 checks, 1201 failures, 1550 samples)`. With the 576 refreshed pins the same 625 candidate failures reproduced, including 624 historical fingerprint mismatches and the full-catalog coverage assertion on the restricted selection. All contexts had zero overflow and font floor failures. `BAL-06 LAYOUT DELTA PASS: 576 introduced mismatches resolved; all 625 candidate results reproduced`. Raw evidence is in `layout-{before,after,final}.{log,json}` and `layout-pin-updates.json`.

The existing rollout probe reported `TEST RESULT: FAIL` on both snapshots, with the same two Discharge failures, `discharge hover shows 5 damage` and `discharge confirmation and forecast agree`. Both manifests recorded `"modifier_visible": true` for `review_hoarfrost_ward_relic`. See `pla03-rollout-before.log` and `pla03-rollout.log`.

## 4. Tooltip recordings

Checked all 30 sidecars and all 30 active registry entries. None records these seven cards. The generic Chain demo plays Chain Bolt, and both Push and Collision demos play Haft Shove. No native re-record command applies.

```sh
python3 tools/tooltip_loops/record.py --task-id bal-06 --loops chain_card,push_card,collision_push --check-only
```

```text
TIP01 SEMANTICS chain_card: PASS
TIP01 SEMANTICS collision_push: PASS
TIP01 SEMANTICS push_card: PASS
TIP01 SEMANTICS RESULT: PASS (0 failures)
```

## Focused checks

Godot commands used `python3 tools/godot_task_runner.py --task-id bal-06 --stream -- godot --headless --path . --script …`.

| Check | Observed result | Log |
| --- | --- | --- |
| `tools/pla04/focused_suites.gd` with `PLA04_SUITES=card_pool_overhaul,ground_targeting,card_targeting_audit,maneuver` | Each suite reported 0 failures. `PLA04 FOCUSED: 7205 checks, 0 failures` · `TEST RESULT: PASS` | `focused-final.log` |
| Same runner with `PLA04_SUITES=card_mechanics_surfaces` | `SUITE card_mechanics_surfaces: 0 failures` · `PLA04 FOCUSED: 255 checks, 0 failures` · `TEST RESULT: PASS` | `surface-focused.log` |
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` | `card-display.log` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` | `card-panel.log` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` | `short-tooltips.log` |
| `tests/card_summary_fit_unit_test.gd` | `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` | `card-summary-fit-unit.log` |
| `tools/pla03/face_fit_check.gd` | `FACE FIT CHECKS: 18944 checks, 0 failures` · `TEST RESULT: PASS` | `face-fit-final.log` |
| `tools/pla03/sentence_face_probe.gd` with `PLA03_DRY_RUN=1 PLA03_SECTIONS=review` | `TEST RESULT: PASS` | `pla03-review.log` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.055s` · `OK` · `PASS: Rules text lint (16 existing hits)` | `rules-text.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.843s` · `OK` | `ui-identity.log` |
| `python3 tools/run_python_suite.py --shards 4 --changed-since 23152865a --output-dir /private/tmp/labyrinth_codex/bal-06/python-default` | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 33.527s` · `OK` | `python-default.log` |
| Direct after-phase probe smoke check | `BAL-06 after headless PASS (7 combat hovers, 7 reward cards)` | `probe-smoke.log` |
| Director launcher with `--dry-run` | `BAL-06 before headless PASS (7 combat hovers, 7 reward cards)` · `BAL-06 after headless PASS (7 combat hovers, 7 reward cards)` | `native-dry-run.log` |

Godot logged a macOS certificate lookup diagnostic. The display override test also logged resource teardown diagnostics after its passing result. The Python group finished successfully and logged a denied timing-cache write to the read-only Git metadata.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-06 && \
  /private/tmp/labyrinth_codex/bal-06/native.sh
```

The launcher stages the exact Git candidate in a temporary project for the before phase and uses this worktree for the after phase. It prints each absolute PNG path on its own line. A native run produces 28 PNGs in `/private/tmp/labyrinth_codex/bal-06/native.*/{before,after}/`, with `hover_<card_id>.png`, `reward_<card_id>.png` and one `manifest.json` per phase. The dry run used `/private/tmp/labyrinth_codex/bal-06/headless.7c5tviwq/` and generated no PNGs. `BAL-06 PROOF CONTRACT PASS: 14 names per phase, both phases ready headlessly`.

| New file | Lines | Purpose |
| --- | --- | --- |
| `tools/bal06/native.sh` | 1–87 | Stage candidate and run both phases through the supported runners |
| `tools/bal06/probe.gd` | 1–225 | Open live combat and rewards, check numbers and capture each view |
| `tools/bal06/probe.gd.uid` | 1 | Godot script UID |
| `tools/bal06/proof.json` | 1–20 | Required PNG names, dimensions and luminance thresholds |
| `tools/bal06/result.md` | Entire file | Implementation and proof record |
| `/private/tmp/labyrinth_codex/bal-06/native.sh` | 1–4 | Director entry point |

## Chosen defaults

- Reused the bal-05 proof seed `919042` and reward neighbors `crosswind` and `beacon`.
- Reused the 20-second scene readiness limit, 300-second native timeout per phase and 64×96 outer-window margin.
- Reused the native proof contract's 18-pixel inset, minimum luma range of 16 and minimum luma standard deviation of 3. The brief specifies 1920×1080 and 100% UI scale.

## Open issues

Native renderer evidence remains for the design owner. The opt-in layout audit and production rollout probe retain the candidate failures described above. The read-only task status returned `"contract_ready": false` with empty acceptance and proof fields. The acceptance record for this implementation is the owner's brief and this report. No `TODO_DESIGN_*` placeholders.
