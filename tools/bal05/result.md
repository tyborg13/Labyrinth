# bal-05 implementation proof

The before snapshot is candidate 7, `7b3176ac60526b4d249f0e330631e98097a1ed1c`. The after snapshot is the uncommitted `codex/bal-05` worktree.

## 1. Card data and visible copy

| Card | Damage before → after | Time before → after | Face source |
| --- | ---: | ---: | --- |
| Flame Jet | 4 → 5 | 3 → 2 | Generated from the area attack |
| Hurricane Palm | 4 → 5 | 3 → 2 | Generated from the damaging Push |
| Cinderline Tempo | 2 → 4 ranged | 3 → 3 | Authored sentence, with Burst 6 |
| Thunderclap | 5 → 6 | 4 → 3 | Generated from the area attack |
| Kestrel Dive | 5 → 7 Strike | 4 → 3 | Generated from the Strike and Push after Blink |
| Stonefist | 6 → 9 base | 3 → 3 | Generated from the Strike, with +1 per Stoneskin up to +6 |

The Time badges and combat keyword stacks read the card data. The Grimoire lists all six under Magicks and displays each card's updated description and Time. The headless comparison checks the production hand, keyword stack, reward card and Grimoire entry in both snapshots.

```sh
rg -in --max-columns 235 'flame[ _]jet|hurricane[ _]palm|cinderline[ _]tempo|thunderclap|kestrel[ _]dive|stonefist' \
  data tests scripts tools assets/tooltip_loops --glob '!*.uid' --glob '!*.import'
rg -in --max-columns 250 'Deal 2 at Range 2\. If the target stands on Fire|Deal 4 across 3 tiles, then leave Fire on the farthest tile|Strike for 4 and Push the target 3 tiles|Blink 3, then Strike an adjacent enemy for 5 and Push|Strike for 5 and Push each enemy hit 1 tile|Strike for 6\. Add \+1 damage per Stoneskin' \
  --glob '!*.log' --glob '!*.import' --glob '!*.uid'
rg -n 'detonate_fire|inferno_ritual|cinderline_tempo' \
  data/tooltip_loops.json assets/tooltip_loops/detonate_fire.tlw.json tools/tooltip_loops/tip06_fixture.gd -M 220
```

The search found one authored face, the six catalogue entries, two direct numeric assertions, an opt-in layout fixture, one loop route and historical snapshots. Comparison against the candidate confirmed that only the specified card and face fields changed.

```text
BAL-05 DATA SCOPE PASS: exactly six card records and one authored face changed
BAL-05 SCORE SCOPE PASS: six scores within 0.02; no affected card leads its rarity
```

| File | Changed lines |
| --- | --- |
| `data/cards.json` | 1114, 1120 Cinderline Tempo. 4882–4883, 4889 Flame Jet. 5175–5176, 5182 Hurricane Palm. 5242–5243, 5253 Kestrel Dive. 5727–5728, 5734 Thunderclap. 6930, 6936 Stonefist. |
| `data/card_faces.json` | 135 Cinderline Tempo's ranged damage. |
| `tests/helpers/card_display_cache_regressions.gd` | 98 Stonefist cache assertion. |
| `tests/suites/card_pool_overhaul_suite.gd` | 695 Stonefist hand assertion and its arithmetic comment. |
| `tests/fixtures/card_summary_fit_baseline_full.json` | 1. Refreshed 336 Flame Jet and Kestrel Dive layout hashes that pinned the previous printed values. |
| `tools/bal05/native.sh` | New, 1–62. Candidate staging and capture runner. |
| `tools/bal05/probe.gd` | New, 1–224. Checks descriptions and creates both captures per card per phase. |
| `tools/bal05/probe.gd.uid` | New, 1. Godot script identity. |
| `tools/bal05/proof.json` | New, 1–18. Twelve exact-size images per phase. |
| `tools/bal05/result.md` | New, entire report. |
| `/private/tmp/labyrinth_codex/bal-05/native.sh` | New, 1–4. Director's launcher. |

## 2. Reward-pool scores

Scored the original and edited card data with `python3 tools/card_heuristic.py --reward-pool --json`. The outputs are `/private/tmp/labyrinth_codex/bal-05/scores-before.json` and `/private/tmp/labyrinth_codex/bal-05/scores-after.json`. Scoring bal-04's data and a scratch copy with both batches via `--cards-path` produced the same six pairs of scores and the same rarity medians.

| Card | Brief score | Measured score | Rank within rarity |
| --- | --- | --- | --- |
| Flame Jet | 2.17 → 2.89 | 2.1701 → 2.8935 | 52 → 37 of 53 |
| Hurricane Palm | 2.49 → 3.13 | 2.4897 → 3.1350 | 50 → 29 of 53 |
| Cinderline Tempo | 2.50 → 3.18 | 2.5045 → 3.1831 | 49 → 26 of 53 |
| Thunderclap | 2.68 → 3.49 | 2.6768 → 3.4900 | 34 → 23 of 40 |
| Kestrel Dive | 2.60 → 3.49 | 2.6000 → 3.4883 | 35 → 24 of 40 |
| Stonefist | 2.58 → 3.34 | 2.5816 → 3.3398 | 36 → 27 of 40 |

| Rarity | Median before | Median after | Leader in both snapshots |
| --- | ---: | ---: | --- |
| Common | 3.1372 | 3.1479 | Beacon, 4.7275 |
| Rare | 3.5756 | 3.5756 | Trapdoor, 5.5200 |
| Epic | 2.7000 | 2.7000 | Ball Lightning, 5.0941 |
| Legendary | 4.45675 | 4.45675 | Skybolt, 6.6238 |

## 3. Test pins

- `tests/helpers/card_display_cache_regressions.gd:98` expects `9 + mini(stoneskin, 6)` across the same Stoneskin threshold cases. Covered by `tests/card_display_overrides_test.gd`.
- `tests/suites/card_pool_overhaul_suite.gd:695` expects 12 for the same 3-Stoneskin hand display case. Covered by the focused `card_pool_overhaul` suite.
- `tests/fixtures/card_summary_fit_baseline_full.json:1` updates the 336 exact hashes that passed on the candidate and changed with the new numbers. Every refreshed sample cleared the original fit limits. The change preserves the stored margin values and every other sample. The manifest of updated hashes is `/private/tmp/labyrinth_codex/bal-05/layout-pin-updates.json`.

The opt-in comparison ran the existing layout assertions for these six cards across 25 contexts using a scratch copy of `tests/card_summary_fit_test.gd`. The candidate reported `CARD SUMMARY FIT RESULT: FAIL (12776 checks, 697 failures, 1300 samples)`. The edited data with the old fixture reported `CARD SUMMARY FIT RESULT: FAIL (12776 checks, 1033 failures, 1300 samples)`. The candidate's 697 include 696 historical fingerprint mismatches and the full-catalog coverage assertion on the six-card selection. The 336 additional mismatches all pinned Flame Jet or Kestrel Dive.

After the pin refresh, the audit again reported `CARD SUMMARY FIT RESULT: FAIL (12776 checks, 697 failures, 1300 samples)`. Comparing the failure sets printed `BAL-05 LAYOUT DELTA PASS: 336 introduced mismatches resolved; all 697 candidate results reproduced`. Every context had zero overflow and font-floor failures. See `layout-before.log`, `layout-after.log` and `layout-final.log`.

## 4. Tooltip loops

Checked the registry and all 30 `assets/tooltip_loops/*.tlw.json` recording sidecars. Zero recordings play any of the six cards. The `detonate_fire` route for Cinderline Tempo plays Inferno Ritual's Burst. Its source fixture and recording both name `inferno_ritual`. No native re-record command is needed.

```sh
python3 tools/tooltip_loops/record.py --task-id bal-05 --loops detonate_fire --check-only
```

```text
TIP01 SEMANTICS detonate_fire: PASS
TIP01 SEMANTICS RESULT: PASS (0 failures)
```

## Checks

Godot programs ran through `python3 tools/godot_task_runner.py --task-id bal-05 --stream -- godot --headless --path . --script …`. Logs are under `/private/tmp/labyrinth_codex/bal-05/`.

| Check | Observed result | Log |
| --- | --- | --- |
| `tools/pla04/focused_suites.gd` with `PLA04_SUITES=card_pool_overhaul,ground_targeting,card_targeting_audit,maneuver` | Each suite reported `0 failures`. `PLA04 FOCUSED: 7205 checks, 0 failures` · `TEST RESULT: PASS` | `focused-final.log` |
| `tools/ptf09/focused_checks.gd -- --domain shortcut` | `PTF09 FOCUSED: PASS (1052 checks, 0 failures)` | `shortcut.log` |
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` | `card-display-final.log` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` | `card-panel.log` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` | `short-tooltips.log` |
| `tests/card_summary_fit_unit_test.gd` | `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` | `card-summary-fit.log` |
| `tools/pla03/face_fit_check.gd` | `FACE FIT CHECKS: 18944 checks, 0 failures` · `TEST RESULT: PASS` | `face-fit.log` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.054s` · `OK` · `PASS: Rules text lint (16 existing hits)` | `rules-text-final.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.523s` · `OK` | `ui-identity-final.log` |
| `python3 tools/run_python_suite.py --shards 4 --changed-since 7b3176ac6 --output-dir /private/tmp/labyrinth_codex/bal-05/python-default` | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 27.531s` · `OK` | `python-default.log` |
| Native launcher with `--dry-run` | `BAL-05 before headless PASS (6 combat hovers, 6 reward cards)` · `BAL-05 after headless PASS (6 combat hovers, 6 reward cards)` · `BAL-05 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/bal-05/headless.gixt7f` | `native-dry-final.log` |

The first headless rehearsal logged missing generated texture imports. Restored 23 cache files under `.godot/imported/` from the candidate worktree after verifying identical source and import metadata. The final rehearsal had no missing-texture errors. Godot logged its macOS certificate lookup diagnostic in both phases. The display override test logged teardown diagnostics and still passed all assertions. The Python group exited 0 and logged a denied timing-cache write in the read-only Git metadata.

The capture contract and rehearsal logs also passed `BAL-05 PROOF CONTRACT PASS: 12 names per phase, both phases ready headlessly`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-05 && \
  /private/tmp/labyrinth_codex/bal-05/native.sh
```

The launcher prints each PNG's absolute path. It creates 24 PNGs under `/private/tmp/labyrinth_codex/bal-05/native.*/{before,after}/`. Each phase has `hover_<card_id>.png` and `reward_<card_id>.png` for every card plus a `manifest.json`. Captures use the 1920×1080 production viewport at 100% UI scale.

## Chosen defaults

- Inherited the bal-04 proof seed `919042` and neighboring reward offers `crosswind` and `beacon`.
- Inherited the 20-second scene readiness limit, 300-second native limit per phase, and 64×96 outer-window margin.
- Inherited the proof contract's 18-pixel inset and minimum luma range of 16 and standard deviation of 3.

## Open issues

The director's windowed captures and playtest are pending. The opt-in layout audit carries the candidate's historical fingerprint mismatches. No `TODO_DESIGN_*` placeholders.

## Round 1

| Card | Applied change | Brief score | Measured reward-pool score | Rank within rarity |
| --- | --- | --- | --- | --- |
| White Silence | Damage 6 → 8, Stagger 6 | 3.52 → 4.56 | 3.5213 → 4.5615 | 11 → 6 of 12 |
| Revealing Glare | Time 3 → 2 | 2.57 → 3.02 | 2.5660 → 3.0160 | 37 → 35 of 40 |
| Dust Devil | Rubble Burst 5 → 8, Push 2 | 2.43 → 3.50 | 2.4289 → 3.5014 | 38 → 23 of 40 |

Ran `tools/card_heuristic.py --reward-pool --json --cards-path` against the saved pre-round data and the current data. Raw scores are in `/private/tmp/labyrinth_codex/bal-05/round1/scores-{before,after}.json`. All three pairs are within 0.02. The legendary median went from 4.45675 to 4.55750. The rare median is 3.5756 in both snapshots. Common and epic medians are 3.1479 and 2.7000 in both snapshots. Skybolt and Trapdoor still lead legendary and rare rewards.

```sh
rg -in --max-columns 235 'white[ _]silence|revealing[ _]glare|dust[ _]devil' \
  data scripts tests tools assets/tooltip_loops -g '!*.uid' -g '!*.import' -g '!*.log'
rg -in --max-columns 235 'Deal 6 and Stagger 6|Burst 5 that Rubble|Expose 3 each enemy in Light within Range 4' \
  data scripts tests tools -g '!*.log' -g '!inventory.json' -g '!audit.json'
```

`BAL-05 ROUND 1 DATA SCOPE PASS: exactly three card records and two authored faces changed`. The Grimoire reads the card descriptions and Time from the catalogue. White Silence's Sweeping Strike panel describes the target condition. The damage is on the card face and in the Grimoire. Revealing Glare's Time badge remains visible with the hover stack open. Dust Devil's Burst panel fills the damage number from the action. The loop registry and all 30 recording sidecars contained no recording for any of these three cards.

### Changed lines

| File | Round 1 changes |
| --- | --- |
| `data/cards.json` | 1682 and 1689 White Silence description and damage. 7394 and 7400 Dust Devil description and Burst. 8338 Revealing Glare Time. |
| `data/card_faces.json` | 11 Dust Devil Burst. 322 White Silence damage. |
| `tests/burst_rules_test.gd` | 234, 236 and 239 Mirror Triptych echo damage and both previews expect 4. 560 and 569 record and check Burst 8. |
| `tests/ice_stagger_merge_rules_test.gd` | 395 White Silence HP loss 8 and Stagger 6. |
| `tests/suites/card_mechanics_surfaces_suite.gd` | 660 White Silence leaves 22 HP and adds 6 Stagger. |
| `tests/suites/card_noop_legality_suite.gd` | 130 White Silence damage 8 for the targeting and no-op cases. |
| `tools/txt26/probe_truth.gd` | 222 and 483 Hobnail Cleats raises White Silence damage to 10 in resolution and the hand face. |
| `tools/bal05/native.sh` | 10–26, 57–59 and 67. Round selection, output and contract. |
| `tools/bal05/probe.gd` | 14–31, 40, 54, 92, 100–101, 114–123, 149–163 and 172. Per-round expectations, selection and checks for visible numbers and tooltip text. |
| `tools/bal05/proof-round1.json` | New, 1–12. Six required images per phase. |
| `tools/bal05/result.md` | Appended this section. |

### Checks

Godot commands ran headlessly through `tools/godot_task_runner.py --task-id bal-05 --stream -- godot`. Logs are in `/private/tmp/labyrinth_codex/bal-05/round1/`.

| Check | Observed result | Log |
| --- | --- | --- |
| `tests/burst_rules_test.gd` | `BURST RULES: 130 checks, 0 failures` · `TEST RESULT: PASS` | `burst.log` |
| `tests/ice_stagger_merge_rules_test.gd` | `ICE STAGGER MERGE RULES: 130 checks, 0 failures` · `TEST RESULT: PASS` | `ice.log` |
| `tools/pla04/focused_suites.gd` with `PLA04_SUITES=card_mechanics_surfaces,card_noop_legality,surface_relic,black_sun_dial,card_targeting_audit` | Each suite reported `0 failures`. `PLA04 FOCUSED: 6299 checks, 0 failures` · `TEST RESULT: PASS` | `focused.log` |
| `tools/txt26/probe_truth.gd` | `TXT26_CASE hobnail_white_silence PASS {"enemy_health_loss":10}` · `TXT26 truth probe PASS: 18 rerun cases matched, 0 failed` | `txt26.log` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` | `panels.log` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` | `short-tooltips.log` |
| `tools/pla03/face_fit_check.gd` | `FACE FIT CHECKS: 18944 checks, 0 failures` · `TEST RESULT: PASS` | `face-fit.log` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.140s` · `OK` · `PASS: Rules text lint (16 existing hits)` | `rules.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 8.203s` · `OK` | `ui-identity.log` |
| Python default group with `--shards 4 --changed-since 7b3176ac6` | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 41.199s` · `OK` | `python-default.log` |
| Native launcher with `--round-1 --dry-run` | `BAL-05 before headless PASS (3 combat hovers, 3 reward cards)` · `BAL-05 after headless PASS (3 combat hovers, 3 reward cards)` · `BAL-05 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/bal-05/round1/headless.nbdTMI` | `native-dry-final.log` |
| Default launcher with `--dry-run` | `BAL-05 before headless PASS (6 combat hovers, 6 reward cards)` · `BAL-05 after headless PASS (6 combat hovers, 6 reward cards)` | `round0-regression-dry.log` |

The optional layout comparison used the round 0 scratch approach with the three round 1 cards. Both snapshots printed `CARD SUMMARY FIT RESULT: FAIL (5980 checks, 488 failures, 625 samples)`. The failure lists were identical, including 487 historical fingerprint mismatches and the coverage assertion for selecting three cards from the full catalogue. Both had zero overflow and font-floor failures. `BAL-05 ROUND 1 LAYOUT DELTA PASS: all 488 candidate failures reproduced; zero new mismatches`.

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-05 && \
  /private/tmp/labyrinth_codex/bal-05/native.sh --round-1
```

Round 1 writes twelve 1920×1080 PNGs at 100% UI scale under `/private/tmp/labyrinth_codex/bal-05/round1/native.*/{before,after}/`. The script prints every PNG's absolute path. Each phase includes a hand hover and reward image per card plus its proof manifest. The round 0 invocation in the preceding section still selects the original six.

Both rounds matched their expected capture names in the headless logs. The initial Round 1 probe treated White Silence's Sweeping Strike definition as damage text. After checking the live stack, the probe verifies the existing target-condition text there and the numerical damage on the face and in the Grimoire. The final headless launcher exited 0. Godot logged its certificate lookup diagnostic in both phases and three resources in use at exit in the before phase.

### Chosen defaults and open issues

Reused the round 0 proof seed, reward neighbors, timeouts, viewport and blank-image thresholds. The Python group passed with a denied timing-cache write. Windowed captures and playtesting are pending. No `TODO_DESIGN_*` placeholders.
