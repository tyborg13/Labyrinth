# bal-07 implementation proof

The comparison uses `23152865ae25efdea3a915fc7bb56fe2a10e18fd` before and the uncommitted `codex/bal-07` worktree after. The standard-risk checks cover the four changed cards and the affected card presentation and targeting paths.

## 1. Card data and visible copy

| Card | Approved changes | Player-facing data path |
| --- | --- | --- |
| Static Ward (`static_ward`) | Block 5 → 6 | The Block chip reads the action amount. The Grimoire reads the catalogue description. |
| Frost Lane (`frost_lane`) | Time 3 → 2 | The Time badge and Grimoire read the card cost. The Ice pattern and Draw 1 come from the existing actions. |
| Thorn Skewer (`thorn_skewer`) | Pierce damage 6 → 7 and Rubble bonus +3 → +4 | The attack row and conditional Pierce chip read the action and bonus. The Grimoire reads both numbers from the catalogue description. |
| Quarry Claw (`venom_claw`) | Strike 8 → 9 | The Melee chip and keyword panel read the action amount. The Grimoire reads the catalogue description. |

The four cards have generated icon rows and no `data/card_faces.json` overrides. The probe exercises the production combat hover stack and reward screen and checks the Grimoire entries in each phase. It checks the generic Block and Pierce definitions with the numeric card chips visible, Frost Lane's Time badge with the Draw panel open, and Quarry Claw's amount-filled Melee panel.

```sh
rg -in --max-columns 240 'static[ _]ward|frost[ _]lane|thorn[ _]skewer|venom_claw|quarry[ _]claw' \
  data scripts tests tools assets/tooltip_loops -g '!*.uid' -g '!*.import' -g '!*.log' -g '!tools/bal07/**'
rg -in --max-columns 240 "Gain 5 Block, then leave Electrified|Pierce an adjacent enemy for 6\. Deal 3 more|Strike for 8, then leave Rubble|Leave Ice on 3 tiles, then Draw 1" \
  data scripts tests tools -g '!*.log' -g '!tools/bal07/**'
```

The hits include historical evidence such as the TXT-25 inventory and truth report, board-surface and pool proposals, the CRD-14 heuristic assumptions snapshot, and probes that select cards by ID. The `w4a_fx_static_ward` fixture supplies a synthetic Block amount and asserts Electrified placement. No live source duplicates the changed rules numbers. Search output is in `card-copy-search.txt` and `old-number-search.txt` in the output directory.

```text
BAL-07 DATA SCOPE PASS: exactly eight field edits in four card records; all generate their faces
```

## 2. Reward-pool scores

Ran `python3 tools/card_heuristic.py --reward-pool --json --cards-path` on the base catalogue and on the edited catalogue. Raw data and scores are in `/private/tmp/labyrinth_codex/bal-07/` as `cards-before.json` and `scores-{before,after}.json`.

| Card | Brief before → after | Measured before → after | Common rank before → after |
| --- | ---: | ---: | ---: |
| Static Ward | 2.78 → 3.03 | 2.7822 → 3.0322 | 45 → 33 |
| Frost Lane | 2.70 → 3.15 | 2.6962 → 3.1462 | 46 → 28 |
| Thorn Skewer | 2.62 → 2.98 | 2.6176 → 2.9820 | 50 → 36 |
| Quarry Claw | 2.62 → 2.86 | 2.6165 → 2.8567 | 51 → 45 |

| Rarity | Cards | Median before | Median after | Leader in both phases |
| --- | ---: | ---: | ---: | --- |
| Common | 53 | 3.1479 | 3.1479 | Beacon, 4.7275 |
| Rare | 40 | 3.5756 | 3.5756 | Trapdoor, 5.5200 |
| Epic | 21 | 2.7000 | 2.7000 | Ball Lightning, 5.0941 |
| Legendary | 12 | 4.55750 | 4.55750 | Skybolt, 6.6238 |

The brief's common median of 3.18 refers to a pool with bal-06 applied. This comparison uses the requested bal-07 base.

```text
BAL-07 SCORE SCOPE PASS: all four pairs within 0.03; no affected card leads its rarity
```

## 3. Changed files and test pins

| File | Changed lines |
| --- | --- |
| `data/cards.json` | 2082 and 2088 Quarry Claw description and Strike. 2148, 2154 and 2161 Thorn Skewer description, Pierce and Rubble bonus. 4924 Frost Lane Time. 8715 and 8721 Static Ward description and Block. |
| `tests/fixtures/card_summary_fit_baseline_full.json` | Line 1. Refreshed 144 Thorn Skewer and 120 Quarry Claw layout hashes. The exact old and new hashes and their sample IDs are in `/private/tmp/labyrinth_codex/bal-07/layout-pin-updates.json`. |
| `tools/bal07/native.sh` | New, 1–63. Runs the before and after project through the documented runners. |
| `tools/bal07/probe.gd` | New, 1–239. Checks live card UI and Grimoire values and captures each card in hand and on the reward screen. |
| `tools/bal07/probe.gd.uid` | New, line 1. Script resource identity. |
| `tools/bal07/proof.json` | New, 1–14. Eight required 1920×1080 PNGs per phase. |
| `tools/bal07/result.md` | New, 1–119. Implementation and proof report. |
| `/private/tmp/labyrinth_codex/bal-07/native.sh` | New, 1–4. Director's launcher. |

No literal assertions pin the four old values. The existing layout fixture does pin the rendered icon rows. A scratch copy of `tests/card_summary_fit_test.gd` filtered the full-matrix definitions to these four cards and kept every assertion. The check covered 700 samples across 25 contexts. The base had 216 historical layout fingerprint mismatches and one full-catalogue coverage failure from filtering to four cards. After updating only the 264 newly failing hashes, the failure list was identical to the base. Every context had zero horizontal overflow, vertical overflow and font-floor failures. The layout logs and sample data are `layout-{before,after,final}.{log,json}` in the output directory.

```text
Before:  CARD SUMMARY FIT RESULT: FAIL (7016 checks, 217 failures, 700 samples)
Old pin: CARD SUMMARY FIT RESULT: FAIL (7016 checks, 481 failures, 700 samples)
Final:   CARD SUMMARY FIT RESULT: FAIL (7016 checks, 217 failures, 700 samples)
BAL-07 LAYOUT DELTA PASS: all 217 original results preserved; zero new failures or fit violations
```

## 4. Tooltip loops

```sh
rg -in --max-columns 240 'static[ _]ward|frost[ _]lane|thorn[ _]skewer|venom_claw|quarry[ _]claw' \
  assets/tooltip_loops -g '*.tlw.json' data/tooltip_loops.json scripts/tooltip_loop_registry.gd tools/tooltip_loops
python3 tools/tooltip_loops/record.py --task-id bal-07 --loops pierce --check-only
```

The audit checked 30 sidecars and 30 registry definitions and found no recordings that play any of the four cards. The Pierce recording plays Bodkin Arrow. No re-record command is required. The related Pierce headless check reported `TIP01 SEMANTICS pierce: PASS` and `TIP01 SEMANTICS RESULT: PASS (0 failures)`.

## Headless checks

Godot checks used `python3 tools/godot_task_runner.py --task-id bal-07 --stream -- godot --headless --path . --script …`. Logs are in `/private/tmp/labyrinth_codex/bal-07/`.

| Check | Observed result | Log |
| --- | --- | --- |
| `tools/pla04/focused_suites.gd` with `PLA04_SUITES=card_pool_overhaul,ground_targeting,card_targeting_audit,maneuver` | Each suite reported `0 failures`. `PLA04 FOCUSED: 7205 checks, 0 failures` · `TEST RESULT: PASS` | `focused.log` |
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` | `card_display_overrides_test.log` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` | `card_panel_text_test.log` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` | `short_card_tooltips_test.log` |
| `tests/card_summary_fit_unit_test.gd` | `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` | `card_summary_fit_unit_test.log` |
| `tools/pla03/face_fit_check.gd` | `FACE FIT CHECKS: 18944 checks, 0 failures` · `TEST RESULT: PASS` | `face-fit.log` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.132s` · `OK` · `PASS: Rules text lint (16 existing hits)` | `rules.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 9.261s` · `OK` | `ui-identity.log` |
| `python3 tools/run_python_suite.py --shards 4 --changed-since 23152865a --output-dir /private/tmp/labyrinth_codex/bal-07/python-default` | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 38.111s` · `OK` | `python-default.log` |
| Director's launcher with `--dry-run` | `BAL-07 before headless PASS (4 combat hovers, 4 reward cards)` · `BAL-07 after headless PASS (4 combat hovers, 4 reward cards)` · `BAL-07 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/bal-07/headless.VhsbEh` | `native-dry-final.log` |

The first probe run found a type mismatch between the base damage token's integer and the conditional token's signed text. The final probe compares the displayed values as text and passed both phases. Godot emitted its macOS certificate lookup diagnostic, and the display-override test reported one resource still in use at exit. The Python suite passed with a denied write to the learned timing cache under the read-only Git metadata.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-07 && \
  /private/tmp/labyrinth_codex/bal-07/native.sh
```

The windowed run targets `1920×1080` and `100%` UI scale. It writes sixteen PNGs under `/private/tmp/labyrinth_codex/bal-07/native.*/{before,after}/`, eight per phase. Each directory gets `hover_<card_id>.png` and `reward_<card_id>.png` for all four cards plus `manifest.json`. The probe prints each PNG's absolute path on its own line. The headless rehearsal wrote isolated fixtures and logs with no PNGs and reported `BAL-07 PROOF CONTRACT DRY RUN PASS: eight capture names matched in each phase` in the log comparison. Windowed rendering and inspection are pending.

## Chosen defaults

Reused bal-05's proof-only seed `919042`, neighboring reward choices Crosswind and Beacon, 20-second scene readiness wait, 300-second runner timeout, and `(64, 96)` display margin. Reused the proof viewport, cel-look setting and nonblank-region thresholds. The approved card data supplied every gameplay value.

## Open issues

The optional layout comparison retains the base's historical failures listed above. Its 264 refreshed samples share one compact fixture line with other batches. The per-sample hash manifest is available for combining fixture edits. There are no `TODO_DESIGN_*` placeholders. All changes remain uncommitted for the design owner.
