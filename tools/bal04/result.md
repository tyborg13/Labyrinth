# bal-04 implementation proof

Candidate 7 is `647b49092cd1464d5c6339b9808b05973f62a4f4`. The implementation is on `codex/bal-04` with uncommitted changes.

## 1. Card data and visible copy

| Card | Applied change | Live display |
| --- | --- | --- |
| Squall | Push 1 → 2 | Authored face, fallback description, generated Push panel, and the Grimoire area-force example and diagram |
| Wind Shear | 5 → 3 Time | Generated Time badge in hand and rewards. Empower still adds 2 Time and replaces Push 1 with Push 2. |
| Dazzle | 2 → 3 damage, 3 → 2 Time | Generated damage row, Time badge and keyword stack, plus the fallback description |
| Discharge | Burst 5 → 7 | Authored face, fallback description and generated Burst text. The approved loop recording still shows `-5` as described below. |
| Tectonic Maul | 11 → 13 damage, 8 → 6 Time | Authored face, fallback description, generated Time badge and Melee panel. The Stagger 3 and Rubble +4 rider are intact. |

The copy audit used the five IDs and names across live data, scripts, tests and tools.

```sh
rg -n -i 'squall_shot|wind_shear|tectonic_maul|\bdazzle\b|\bdischarge\b|\bsquall\b|wind shear|tectonic maul' \
  data scripts tests tools -g '*.json' -g '*.gd' -g '*.py' \
  -g '!card_summary_fit_baseline_full.json' -g '!inventory.json' -M 240
rg -n 'Squall Shot Pushes|Burst 5 an Electrified|Strike for 11 and Stagger|Deal 2 at Range 3\. If the target stands in Light|Deal 2 at Range 3 and Push each enemy|\["discharge", "burst=5"\]' \
  data tests -g '*.json' -g '*.gd' -M 400
rg -n 'discharge_network' data scripts tests tools -g '*.json' -g '*.gd' -g '*.py' -M 240
```

The matches identified the individual card and authored face rows, the repeated Squall example and exact-match diagram key, the two Grimoire expectations, and the combat and hover assertions below. Discharge's Grimoire entries describe the Electrified network without a damage value. The tooltip registry routes to an approved recording by source card ID. Its provenance at `assets/tooltip_loops/discharge_network.tlw.json` records `enemy_1:-5` and `player:-5` in the frames.

| File | Changed lines |
| --- | --- |
| `data/cards.json` | 2018, 2050 Squall. 2335–2336, 2342 Tectonic Maul. 6156–6157, 6163 Dazzle. 7180 Wind Shear. 7356, 7363 Discharge. |
| `data/card_faces.json` | 35 Discharge. 110–111 Squall and plural agreement. 118 Tectonic Maul. |
| `data/grimoire.json` | 711 Squall's area-force example. |
| `data/pattern_rule_text.json` | 19 Squall's diagram lookup key and displayed sentence. |
| `tools/bal04/native.sh` | New file, lines 1–62. Candidate staging and headless or native entry point. |
| `tools/bal04/probe.gd` | New file, lines 1–210. Real hand hover and reward display proof. |
| `tools/bal04/probe.gd.uid` | New file, line 1. Godot script identity. |
| `tools/bal04/proof.json` | New file, lines 1–16. Ten exact-size images required per phase. |
| `tools/bal04/result.md` | New file, this report. |
| `/private/tmp/labyrinth_codex/bal-04/native.sh` | New launcher, lines 1–4. |

Parsed data and compared normalized records against candidate 7. The scope check printed `BAL-04 DATA SCOPE PASS: exactly five card records, three authored faces, and five reward-pool scores changed`. Scorer coefficients, game rules and analytics schemas had no affected assumptions.

## 2. Reward-pool scoring

Ran `python3 tools/card_heuristic.py --reward-pool --json` before and after. Raw outputs are `/private/tmp/labyrinth_codex/bal-04/scores-before.json` and `/private/tmp/labyrinth_codex/bal-04/scores-after.json`.

| Card | Director target | Measured before → after | Rarity rank before → after |
| --- | --- | --- | --- |
| Squall | 2.39 → 3.52 | 2.3877 → 3.5165 | 39 → 22 of 40 |
| Wind Shear | 2.18 → 3.08 | 2.1753 → 3.0753 | 51 → 29 of 53 |
| Dazzle | 1.99 → 2.86 | 1.9856 → 2.8589 | 53 → 38 of 53 |
| Discharge | 1.75 → 2.67 | 1.7518 → 2.6690 | 20 → 13 of 21 |
| Tectonic Maul | 2.51 → 3.98 | 2.5103 → 3.9824 | 12 → 9 of 12 |

| Rarity | Before median | After median | Highest before and after |
| --- | ---: | ---: | --- |
| Common | 3.1372 | 3.1372 | Beacon, 4.7275 |
| Rare | 3.5756 | 3.5756 | Trapdoor, 5.5200 |
| Epic | 2.7000 | 2.7000 | Ball Lightning, 5.0941 |
| Legendary | 4.45675 | 4.45675 | Skybolt, 6.6238 |

Every score is within 0.02 of its director target. No changed card leads its rarity.

## 3. Updated test pins

| File | Line | Updated expectation |
| --- | ---: | --- |
| `tests/burst_rules_test.gd` | 309 | Discharge test comment now names Burst 7. |
| | 313 | An enemy touching multiple sources loses 7 once. |
| | 316 | The adjacent player loses 7. |
| | 322 | The hover forecast shows 7 for the player and affected enemy. |
| | 378 | A concealed network still resolves and forecasts the full 7. |
| `tests/fixtures/pla02_grimoire_pages.json` | 195 | The full area-force paragraph expects 2 tiles. |
| `tests/fixtures/txt20_rules_copy.json` | 399 | The area-force sentence expects 2 tiles. |
| `tests/run_tests.gd` | 2161 | Tailwind increases Squall's Push to 3. |
| `tests/suites/card_mechanics_surfaces_suite.gd` | 218 | Each of three targets moves two tiles and takes the same hit as before. |
| | 233 | Tectonic Maul leaves 47 HP on plain ground or 41 HP with Rubble and Expose. |
| | 337 | Chain fixture hero is at (2, 4). |
| | 338 | Chain fixture center is at (3, 5). |
| | 339 | First Chain hop is at (5, 5). |
| | 340 | Next Chain hop is at (7, 4), adjacent to the first hop's two-tile landing. |
| | 341 | The initial target is at (3, 4), in the cross and aligned with the hero. |
| | 348 | Forecast and resolution both push the first Chain hop two tiles from the player origin. |
| `tests/suites/card_pool_overhaul_suite.gd` | 391 | Base Tectonic Maul leaves 47 HP and adds 3 Stagger. |
| | 396 | Tectonic Maul deals 17 on Rubble, leaving 43 HP. |
| | 438 | Dazzle deals 3 in Light and darkness, with the Light-only Stagger intact. |
| | 798 | Discharge's card summary displays Burst 7. |

## Checks

Godot checks ran through `tools/godot_task_runner.py --task-id bal-04 --stream -- godot --headless --path . --script …`. Logs are under `/private/tmp/labyrinth_codex/bal-04/`.

| Check | Observed result | Log |
| --- | --- | --- |
| `tests/burst_rules_test.gd` | `BURST RULES: 130 checks, 0 failures` · `TEST RESULT: PASS` | `burst-after.log` |
| `card_mechanics_surfaces` via `tools/pla04/focused_suites.gd` | `SUITE card_mechanics_surfaces: 0 failures` · `PLA04 FOCUSED: 255 checks, 0 failures` · `TEST RESULT: PASS` | `mechanics-final.log` |
| `card_pool_overhaul`, `maneuver`, `card_targeting_audit` via the same runner | `SUITE card_pool_overhaul: 0 failures` · `SUITE maneuver: 0 failures` · `SUITE card_targeting_audit: 0 failures` | `focused-after.log` |
| Existing Tailwind assertion, `ForcedMovementSuite`, and rotated Wind Shear aim from `tests/run_tests.gd` | `BAL-04 EXISTING TAILWIND, FORCE AND ROTATED AIM: 101 checks, 0 failures` · `TEST RESULT: PASS` | `tailwind-force-aim.log` |
| `tools/pla03/face_fit_check.gd` | `FACE FIT CHECKS: 18944 checks, 0 failures` · `TEST RESULT: PASS` | `face-fit-after.log` |
| `tests/card_summary_fit_unit_test.gd` | `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` | `card-summary-fit.log` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` | `card-panel-after.log` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` | `short-card-tooltips.log` |
| Discharge loop recorder semantics via `record.py --task-id bal-04 --loops discharge_network --check-only` | `TIP01 SEMANTICS discharge_network: PASS` · `TIP01 SEMANTICS RESULT: PASS (0 failures)` | `loop-after.log` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.052s` · `OK` · `PASS: Rules text lint (16 existing hits)` | Python default also ran this lint. |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.237s` · `OK` | Direct check. |
| `run_python_suite.py --shards 4 --audit-only` | `ISOLATION AUDIT: 59 modules` | `python-audit.log` |
| `run_python_suite.py --shards 4 --changed-since 647b49092` | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 32.690s` · `OK` | `python-default.log` and `python-default/summary.json` |

The tailored Tailwind and aim check used a temporary SceneTree entry point that overrides full-suite startup and calls the existing tests. The combined suite also surfaced 15 pre-existing `inline_icon_description` relic-copy mismatches. Candidate 7 printed `SUITE inline_icon_description: 15 failures`, `PLA04 FOCUSED: 10264 checks, 15 failures`, and `TEST RESULT: FAIL`. The after run reproduced the same 15 relic mismatches. The one intermediate Squall Chain fixture failure was fixed and the final focused mechanics check passed. The Python runner passed and reported a read-only Git timing-cache write error. Earlier headless runs also logged missing local imported textures. The task-local import bootstrap completed and produced the new probe UID.

## Proof for the design owner

The launcher uses the POL-75 native invocation at exact 1920×1080 from a SubViewport and 100% UI scale with `LABYRINTH_CEL_LOOK=all`. Each phase uses a saved production combat with the subject in hand and a production card reward screen with the subject in the middle slot. The probe checks the displayed Time and damage or Push, including the live keyword stack, before requesting each capture.

The headless run printed `BAL-04 before headless PASS (5 combat hovers, 5 reward cards)`, `BAL-04 after headless PASS (5 combat hovers, 5 reward cards)` and `BAL-04 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/bal-04/headless.itq15M`. Godot reported `3 resources still in use at exit` after the second phase. The command exited 0. See `native-dry.log`.

The native run takes the PNGs under `/private/tmp/labyrinth_codex/bal-04/native.*/{before,after}/`, with one `hover_<card_id>.png` and one `reward_<card_id>.png` per card and a proof manifest per phase. It prints every PNG's absolute path on its own line.

Re-record the approved Discharge tooltip loop using the live card's updated damage. Then run the comparison.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-04 && \
  python3 tools/tooltip_loops/record.py --task-id bal-04 --loops discharge_network \
    --keep-passing --proof-contract tools/tooltip_loops/tip13_record_contract.json \
    --output-dir /private/tmp/labyrinth_codex/bal-04/discharge-loop

cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-04 && \
  /private/tmp/labyrinth_codex/bal-04/native.sh
```

## Chosen defaults

- Probe seed `919042` and neighboring reward offers `crosswind` and `beacon` provide the same comparison setup in both phases.
- Squall's Chain fixture uses the listed coordinates to preserve two consecutive player-origin hops without a wall collision.
- The readiness timeout is 20 seconds and the native runner limit is 300 seconds per phase. The outer window reserves 64×96 pixels for desktop margins while the SubViewport stays 1920×1080.
- The proof contract uses the existing 18-pixel inset and luma thresholds of 16 range and 3 standard deviation for blank-image detection.

## Open issues

The Discharge loop needs a native re-record so the two damage floats show `-7`. The existing approved recording is still installed. Windowed comparison PNGs and director playtesting are pending. No `TODO_DESIGN_*` placeholders were introduced.

## Round 1

### Root cause

The director's native start PNG shows the purple Electrified network. The first-motion PNG shows two `-7` floats and the ground has already been consumed. The failure was in draw detection. [Native recorder log](/private/tmp/labyrinth_codex/native_inserts/9a069_bal04.log).

`tools/tooltip_loops/playback.gd:82–84` holds the opening pose before resolving the card. `tools/tooltip_loops/record.gd:128–158` already observes the production board after the renderer submits each source frame, including frame zero, which is saved as `source_start` at line 180. The auditor used by tip-13 at `c0751d4ee:tools/tooltip_loops/terrain_checks.gd:20–28` recognized only the legacy retained per-tile nodes, including `_surface_electric_layer`. This lookup was still present on candidate 7.

The grd-11 commit `d0000a819` adds depth-sorted sheet draws for Fire and Electrified on the pixel ground path. Commit `44302e421` disables the legacy persistent draws when pixel mode is active. The behavior changed for default recordings in **`1aa409a7f`**, the candidate 4 integration commit that set `data/ground_surface_style.json:3` to `"pixel"`. `scripts/combat_board_view.gd:17940–17947` selects the draw path, and `scripts/board_ground_fx_sheet.gd:146–188` submits the sheet stamps in tile or unit painter slots.

The old audit failed with Burst 5 as well. A headless check used the committed candidate 7 Discharge record in memory and the original auditor against the same production opening board. The original auditor observed zero tiles at Burst 5 and Burst 7. A full rehearsal before the fix also reproduced `TIP04 PATCH VISIBILITY discharge_network: FAIL` with four lifetime failures and an empty `observed_surfaces` list.

### Recorder change

[terrain_checks.gd](../tooltip_loops/terrain_checks.gd) lines 5–7 and 23–62 add the pixel-ground draw lookup. It requires rendered tile membership and either a visible Fire or Electrified stamp with a bound sheet and an active row for that element, or a visible shader floor with a bound atlas and a submitted decal of the requested kind in that tile's bin. The legacy path and lifetime and final-state requirements still apply. The standard audit already samples the capture opening, so the recorder frame loop and proof contracts needed no edits. `tools/bal04/native.sh` is unchanged.

A focused headless check sampled only the opening pose and then consumed the network. With both drawing sources hidden for one tile, the audit failed that tile's lifetime requirement even though the combat state and field still contained it. Both independent draw paths and the preserved legacy path were also checked.

```text
BAL-04 ROUND 1 BURST 5: old gate 4 missing; fixed gate 0 missing; hidden tile 1 missing
TEST RESULT: PASS
BAL-04 ROUND 1 BURST 7: old gate 4 missing; fixed gate 0 missing; hidden tile 1 missing
TEST RESULT: PASS
```

### Headless results

The fixture inventory checked the initial state, beat transitions, enemy steps and final state of every selectable loop. The following 13 fixtures contained ground. Each ran through `tools/tooltip_loops/record.py --task-id bal-04 --loops <comma-separated IDs> --check-only`, then through the recorder's headless rehearsal with the production board tree.

| Loop | Ground | `TIP01 SEMANTICS` | `TIP04 PATCH VISIBILITY` | Observed tiles |
| --- | --- | --- | --- | ---: |
| `marked_burrow_grub` | Rubble | PASS | PASS | 1 |
| `lightning_strikes` | Electrified | PASS | PASS | 2 |
| `marked_icefall_seer` | Ice | PASS | PASS | 3 |
| `lob_slagmaster_barrage` | Fire | PASS | PASS | 9 |
| `marked_lob_slag` | Fire | PASS | PASS | 3 |
| `rule_wildfire` | Fire | PASS | PASS | 3 |
| `trap_fire` | Fire | PASS | PASS | 5 |
| `trap_ice` | Ice | PASS | PASS | 5 |
| `trap_lightning` | Electrified | PASS | PASS | 5 |
| `trap_earth` | Rubble | PASS | PASS | 5 |
| `detonate_fire` | Fire | PASS | PASS | 2 |
| `burst_ember_tick` | Fire | PASS | PASS | 1 |
| `discharge_network` | Electrified | PASS | PASS | 4 |

Result lines were `TIP01 SEMANTICS RESULT: PASS (0 failures)` and `TIP01 REHEARSAL RESULT: PASS (0 failures)`. The Discharge rehearsal reported `enemy_1:-7` and `player:-7`. A separate `LABYRINTH_GROUND_FX=off` Discharge rehearsal also passed with four observed tiles. [Round 1 logs](/private/tmp/labyrinth_codex/bal-04/round1).

### Native re-record

Run on the director's window server. The recorder creates a fresh attempt directory. Native recording and installation are pending.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/bal-04 &&
  python3 tools/tooltip_loops/record.py --task-id bal-04 --loops discharge_network \
    --keep-passing --proof-contract tools/tooltip_loops/tip13_record_contract.json \
    --output-dir /private/tmp/labyrinth_codex/bal-04/discharge-loop
```
