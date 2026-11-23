# pla-06 implementation handoff

Base `44f7c9ec4909a616f4c0e2e7233430423d8ff052` (`codex/pla-04`). The implementation is uncommitted in `codex/pla-06`.

## Cards

The scores use the card data and scorer at each revision. Face lines are the headless check at 250×352. Slash marks separate icon rows. The sentence line count excludes the target chip.

| Card ID | Old → new behavior | Face and lines | Score old → new |
| --- | --- | --- | ---: |
| `frostbolt` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 4 · Range 3 · Ice / Target on Ice: · Stagger 6 | 4.05 → 3.60 |
| `icebound_chains` | Conditional Freeze → Stagger 6 on Ice. Reveal all hidden enemies for two turns, printed as Vision. | Ranged 5 · Range 2 · Immobilize / Target on Ice: · Stagger 6 / Vision · Time 2 | 5.60 → 5.25 |
| `rime_shard` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 2 · Range 2 · Area · Ice / Target on Ice: · Stagger 6 | 3.81 → 3.34 |
| `cold_grasp` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Melee 7 · Range 2 / Target on Ice: · Stagger 6 | 3.58 → 3.29 |
| `icicle_lance` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Pierce 6 · Range 3 / Target on Ice: · Stagger 6 | 4.69 → 4.25 |
| `hush_of_winter` | Draw 2 when the hit Freezes → draw 2 on a hit against Ice, with Stagger 6. | Enemy 4 · 3 lines · ➶5. On Ice: also Stagger 6 and Draw 2. | 4.39 → 3.89 |
| `shatterline` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 5 · Range 2 · Area · Pierce / Target on Ice: · Stagger 6 / Empower · Time +2 · Area | 4.27 → 3.76 |
| `glacier_pin` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 3 · Range 2 · Area · Immobilize · Ice / Target on Ice: · Stagger 6 | 4.40 → 3.93 |
| `white_silence` | Select visible Chilled enemies and Freeze → select visible enemies on Ice and Stagger 6. | 3 lines · ➶4 and Stagger 6 each enemy you can see on Ice. | 4.08 → 1.68 |
| `threadbare_guard` | Threadbare Guard removes Bleed, Immobilize and Chilled → Unpick removes Immobilize and Shock. | 6 lines · Remove Immobilize and Shock from yourself. Gain Block 4 and Draw 1. | 4.25 → 3.90 |
| `rimeplate_lock` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Stoneskin 3 / Block 3 / Ranged 2 · Range 2 · Immobilize · Ice / Target on Ice: · Stagger 6 | 5.05 → 4.70 |
| `locket_chill` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 5 · Range 2 · Ice / Target on Ice: · Stagger 6 | 3.68 → 3.33 |
| `frost_snare` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Consume / Ranged 2 · Range 2 · Immobilize · Ice / Target on Ice: · Stagger 6 | 3.30 → 2.95 |
| `cold_shoulder` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Melee 6 · Push 2 / Target on Ice: · Stagger 6 | 3.81 → 3.62 |
| `frost_nova` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Melee 4 · Area / Target on Ice: · Stagger 6 / Ice · Area | 3.04 → 2.76 |
| `rime_hack` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Melee 7 · Ice / Target on Ice: · Stagger 6 | 3.19 → 3.01 |
| `shiver_shot` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 2 · Range 4 / Target on Ice: · Stagger 6 | 3.80 → 3.30 |
| `rimefang` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Ranged 4 · Range 2 / Target on Ice: · Stagger 6 / Follow-up · Ranged +3 · Ice | 3.79 → 3.44 |
| `rite_of_hoarfrost` | Reward on Freeze → reward when an Ice card adds Stagger. | 6 lines · Rite: when one of your Ice cards Staggers an enemy, gain Block 3 and Draw 1. | 2.30 → 2.30 |
| `frozen_bite` | Card Play 1 and Draw 1 on Freeze → same rewards on a hit against Ice, with Stagger 6. | 4 lines · ⚔5. On Ice: also Stagger 6, gain Card Play 1 and Draw 1. | 3.16 → 2.98 |
| `hoarfrost_ward` | Ice under adjacent enemies sets up Chilled → sets up Expose 2 on contact. | 4 lines · Gain Block 5. Leave Ice under each enemy next to you. | 2.69 → 2.69 |
| `petrify` | Skip the next turn and give the target 5 Block, Time 5 → Stagger 6, Time 3, range 3. | Stagger 6 · Range 3 | 2.47 → 2.39 |
| `rime_step` | Ice under adjacent enemies sets up Chilled → sets up Expose 2 on contact. | 4 lines · Move 3. Leave Ice under each enemy next to you. | 2.64 → 2.64 |
| `sleet_squall` | Conditional Freeze → Stagger 6 on Ice. Other actions carry over. | Range 3 · Push 2 · Ranged 3 / Target on Ice: · Stagger 6 | 4.07 → 3.62 |
| `smelling_salts` | Removes Immobilize, Shock and Chilled → removes Immobilize and Shock. | 4 lines · Consume. Remove Immobilize and Shock from yourself. Move 2. | 2.45 → 2.10 |

## v5 copy changes

Hush of Winter, White Silence, and Frozen Bite have revised sentence faces. The other five sentence faces match the v5 segments.

| Card | v5 → implementation |
| --- | --- |
| Hush of Winter | ➶5. On Ice: also Draw 2. → ➶5. On Ice: also Stagger 6 and Draw 2. |
| White Silence | ➶4 each enemy you can see on Ice. → ➶4 and Stagger 6 each enemy you can see on Ice. |
| Frozen Bite | ⚔5. On Ice: also gain Card Play 1 and Draw 1. → ⚔5. On Ice: also Stagger 6, gain Card Play 1 and Draw 1. |

The simple cards with a new Ice rider print it as an icon row. These fallback descriptions differ from v5.

| Card | Fallback description |
| --- | --- |
| Frostbolt | Deal 4 at range 3. On Ice: also Stagger 6. Leave Ice. |
| Icebound Chains | Deal 5 at range 2 and Immobilize. On Ice: also Stagger 6. Gain Vision for 2 turns. |
| Rime Shard | Deal 2 to each enemy hit at range 2. On Ice: also Stagger 6. Leave Ice. |
| Cold Grasp | Strike up to range 2 for 7. On Ice: also Stagger 6. |
| Icicle Lance | Deal 6 at range 3. Pierce. On Ice: also Stagger 6. |
| Shatterline | Deal 5 to each enemy hit at range 2. Pierce. On Ice: also Stagger 6. Empower (+2 Time): the longer area shown. |
| Glacier Pin | Deal 3 to each enemy hit at range 2 and Immobilize. On Ice: also Stagger 6. Leave Ice. |
| Rimeplate Lock | Gain 3 Stoneskin and 3 Block. Deal 2 at range 2 and Immobilize. On Ice: also Stagger 6. Leave Ice under the target. |
| Locket Chill | Deal 5 at range 2. On Ice: also Stagger 6. Leave Ice. |
| Frost Snare | Consume. Deal 2 at range 2 and Immobilize. On Ice: also Stagger 6. Leave Ice. |
| Cold Shoulder | Strike an adjacent enemy for 6 and Push 2 away from you. On Ice: also Stagger 6. |
| Frost Nova | Deal 4 to each enemy hit. On Ice: also Stagger 6. Then leave Ice on the tiles shown. |
| Rime Hack | Strike for 7. On Ice: also Stagger 6. Leave Ice beneath the target. |
| Shiver Shot | Deal 2 at range 4. On Ice: also Stagger 6. |
| Rimefang | Deal 4 at range 2. On Ice: also Stagger 6. Follow-up: deal 3 more and leave Ice. |
| Sleet Squall | Push 2 away from you at range 3, then deal 3 to the target. On Ice: also Stagger 6. |

## Enemies and battlefield rules

The enemy scores apply the card heuristic to printed intent packages, weighted by each intent’s authored weight. For Icefall Landing, the scoring input represents the three-tile ranged area with the mark’s range 5. The scorer has no independent cost model for the discarded persistent Chilled rider, Steadfast, or the retained Iskaldra Mantle.

| Enemy | Affected intents and scores | Weighted package score |
| --- | --- | ---: |
| Frostglass Lancer (`frostglass_lancer`) | glass_lunge 3.27 → 3.00<br>frost_pin 3.11 → 2.66 | 2.17 → 2.04 |
| Iskaldra, the Rime Tyrant (`iskaldra`) | crystal_mantle 3.86 → 3.36<br>whiteout_lance 7.05 → 6.31<br>rime_talon 2.81 → 2.62 | 3.86 → 3.46 |
| Rimejaw (`rimejaw`) | harrowing_pounce 1.62 → 1.43<br>frostbite 1.86 → 1.67 | 1.48 → 1.36 |
| Rime Whelp (`rime_whelp`) | circle 1.54 → 1.35 | 1.25 → 1.15 |
| Rime Spitter (`rime_spitter`) | recover 2.68 → 2.23 | 1.51 → 1.29 |
| Hoarfrost Seer (`hoarfrost_seer`) | icefall_land 7.35 → 6.60<br>rime_bolt 3.37 → 2.87 | 1.14 → 0.97 |
| Glacial Mirror (`glacial_mirror`) | refraction 2.22 → 1.90 | 1.11 → 0.95 |

The listed attacks replace their former Ice Freeze with a printed Stagger 6 against targets already on Ice. Hoarfrost Seer’s Rime Bolt and Glacial Mirror’s Refraction also lose their explicit Chilled flag. Iskaldra loses Freeze immunity and retains Crystal Mantle and Shatterstorm. She is the sole production enemy with Frost Armor in the base data.

| Frostbite instance | Package change | Per affected unit old → new |
| --- | --- | ---: |
| `oracle` | Damage 2 only. | 5.70 → 0.90 |
| `snare_ice` | Damage 1 only. | 5.25 → 0.45 |
| `rimejaw` | Stagger 6 only. | 4.80 → 1.80 |
| `iskaldra` | Damage 3 only. Same impact at the half-Health cadence. | 6.15 → 1.35 |

Frostbite scores use the raw hit and control coefficients with a target already on Ice. The revised card scorer values ambient Expose on the ground placer.

## Related scores

Skate keeps its amounts and protects against Ice Expose. Other cards affected by the shared scorer changes were also rescored.

| Card | Score old → new |
| --- | ---: |
| `shatter` | 4.96 → 3.52 |
| `shatter_swing` | 4.02 → 3.27 |
| `skate` | 3.65 → 3.65 |

## Chosen defaults

- Rules fixture uses seed 40617, an 11×10 board, 40 hero Health, 30 default enemy Health, and Time 20 for queued enemies.
- Visual fixture uses the existing pla-03 seed 73101 and test board. Ice preview coordinates are (3, 5) for the hero’s move and (4, 4) for the enemy’s turn start. The dry manifest records Expose 2 in both states.
- Scoring maps the delayed Icefall landing to the existing three-tile ranged area model. No live tuning depends on that mapping.

## Files changed

- `data/battlefield_rules.json`
- `data/card_faces.json`
- `data/card_panel_text.json`
- `data/cards.json`
- `data/enemies.json`
- `data/glossary.json`
- `data/grimoire.json`
- `data/pattern_rule_text.json`
- `data/relics.json`
- `data/sfx_cues.json`
- `data/special_encounters.json`
- `data/tooltip_loops.json`
- `scripts/action_icon_library.gd`
- `scripts/battlefield_rules/dispatcher.gd`
- `scripts/battlefield_rules/frostbite.gd`
- `scripts/board_attack_rules.gd`
- `scripts/board_surface_rules.gd`
- `scripts/card_face_spec.gd`
- `scripts/card_keyword_rules.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/common_relic_rules.gd`
- `scripts/enemy_mechanics/burrow.gd`
- `scripts/enemy_mechanics/marked_strike.gd`
- `scripts/enemy_mechanics/reflect.gd`
- `scripts/enemy_mechanics/reflect_view.gd`
- `scripts/enemy_mechanics/unit_traits.gd`
- `scripts/enemy_mechanics/unit_traits.gd.uid`
- `scripts/forced_relic_rules.gd`
- `scripts/game_data.gd`
- `scripts/grimoire_library.gd`
- `scripts/ice_contact_rules.gd`
- `scripts/ice_contact_rules.gd.uid`
- `scripts/illusion_relic_rules.gd`
- `scripts/intent_badges.gd`
- `scripts/maneuver_rules.gd`
- `scripts/pre_battle_inspection_view.gd`
- `scripts/run_scene.gd`
- `scripts/sfx_cue_router.gd`
- `scripts/surface_card_rules.gd`
- `scripts/surface_relic_rules.gd`
- `scripts/surface_variety_relic_rules.gd`
- `scripts/target_click_feedback.gd`
- `spec/analytics.md`
- `spec/card_balance_heuristic.md`
- `spec/card_mechanics_maneuver.md`
- `spec/card_mechanics_surfaces.md`
- `spec/card_text_style.md`
- `tests/burst_glossary_contract.py`
- `tests/card_panel_text_test.gd`
- `tests/fixtures/approved_glossary_structure.gd`
- `tests/fixtures/pla06_ice_copy.json`
- `tests/glossary_test.gd`
- `tests/headless_test_programs.json`
- `tests/helpers/short_card_tooltips_proof.gd`
- `tests/ice_stagger_merge_rules_test.gd`
- `tests/ice_stagger_merge_rules_test.gd.uid`
- `tests/petrify_tooltip_test.gd`
- `tests/sfx_cue_coverage_probe.gd`
- `tests/sfx_sync_bank_test.gd`
- `tests/short_card_tooltips_test.gd`
- `tests/suites/battlefield_fuel_suite.gd`
- `tests/suites/battlefield_rules_feedback_2_suite.gd`
- `tests/suites/battlefield_rules_feedback_suite.gd`
- `tests/suites/battlefield_rules_suite.gd`
- `tests/suites/board_surface_suite.gd`
- `tests/suites/card_noop_legality_suite.gd`
- `tests/suites/dragon_boss_suite.gd`
- `tests/suites/en05_enemies_suite.gd`
- `tests/suites/relic_suite.gd`
- `tests/suites/tooltip_consistency_suite.gd`
- `tests/test_card_heuristic_maneuver.py`
- `tests/test_card_heuristic_surfaces.py`
- `tests/test_card_heuristic_wave4_surfaces.py`
- `tests/test_card_panel_text.py`
- `tests/test_element_rule_contract.py`
- `tests/test_icon_identity_policy.py`
- `tests/test_short_card_tooltips.py`
- `tests/text_budget_test.py`
- `tools/board_surface_content_audit.py`
- `tools/card_heuristic.py`
- `tools/pla03/face_fit_check.gd`
- `tools/pla03/sentence_face_probe.gd`
- `tools/pla06/focused_suites.gd`
- `tools/pla06/focused_suites.gd.uid`
- `tools/pla06/implementation_report.md`
- `tools/pla06/proof_contract.json`
- `tools/pla06/rows_dump.gd`
- `tools/pla06/rows_dump.gd.uid`

## Verification

| Check | Observed result |
| --- | --- |
| Base rules reproduction | `ICE STAGGER MERGE RULES: 89 checks, 59 failures` |
| Final rules | `ICE STAGGER MERGE RULES: 94 checks, 0 failures` |
| Face fit | `FACE FIT CHECKS: 10197 checks, 0 failures` |
| Glossary | `GLOSSARY TEST RESULT: PASS (6564 checks, 0 failures)` |
| Card panels | `CARD PANEL TEXT TEST RESULT: PASS (2231 definitions, 8050 panels, 8266 checks, 0 failures)` |
| Short tooltips | `SHORT CARD TOOLTIPS TEST RESULT: PASS (734 checks, 0 failures)` |
| Focused integration | `PLA06 FOCUSED: 813 checks, 0 failures` for battlefield and Glacial Mirror, and `PLA06 FOCUSED: 706 checks, 0 failures` for the final battlefield revision. Board Surface, card legality, dragon boss, and relic suites each printed `0 failures`. |
| Rail and audio | `STAGGER BADGE/TURN-ORDER TEST RESULT: PASS` and `SFX SYNC BANK TEST RESULT: PASS (0 failures)` |
| UI and icon identity | `Ran 25 tests` and `Ran 10 tests`, both `OK` |
| Windows typed arrays | `TYPED ARRAY SCAN: 52 scripts; 0 new; 18 pre-existing` |
| Python changed-since | `Ran 188 tests in 154.112s`, `FAILED (failures=7, errors=1)` |

The Python result includes the inherited Black Sun Dial copy assertion and five missing pla-04 sidecars. The approved-content smoke exceeded its 30-second limit both in the changed-since run and in isolation. Runner tests separately reported a missing child start, a missing package-stage start, two 15-second parent timeouts, and one 30-second fixture timeout. The detailed output is in `.godot/pla06-python-delivery.log`.

The sentence-face probe dry run printed 36 `DRY SHOT` lines and `TEST RESULT: PASS`. Its manifest at `.godot/pla06-dry/manifest.json` recorded the move preview and the enemy turn-start Expose. Native frames remain pending.

## Open design item

`TODO_DESIGN_shared_vision_cutover` in `data/cards.json` records the shared Vision naming decision. Icebound Chains prints Vision and still reveals hidden enemies for two turns. The shared status badge and Grimoire currently call that effect Truesight.
