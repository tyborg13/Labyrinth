# Enemy surface acceptance receipt

The receipt below records the completed **v4** implementation. Its historical
PASS is not a claim that these same fixtures already passed against v5. The
feedback pass updates the current suites for Fire 2/3, Rubble departure cost,
Chilled +2, Frozen ×3, and reusable ordinary Electrified. Zekarion/Wisp Shock now
requires a conducted hit; replacing a useful connection still denies the setup.
Stormcoal Fire remains consumable. Current v5 receipts are recorded with the
feedback-pass verification, preserving this original result for comparison.

## Historical v4 receipt

All ten proof-encounter themes from `spec/board_surface_refactor/ENEMY_MIGRATION_DESIGN.md` now have focused executable coverage. These are constructed rule/interaction fixtures, supplemented by generated playtests; they do not claim a complete human-played boss campaign. The new suite invokes current authored intents through the real core action resolver and checks resulting board state.

Run the new cases with:

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tests/enemy_surface_acceptance_test.gd
```

Result: **PASS**, 11 focused scenarios, zero failed assertions. The known host CA-certificate diagnostic does not interrupt execution.

| Accepted proof encounter | Exact executable coverage | Evidence and limit |
|---|---|---|
| 1. Crawler/Warden through Rubble beside Fire | `enemy_surface_acceptance_suite.gd::_test_physical_approach`; `board_surface_suite.gd::_test_dynamic_movement_allowance` | Both physical roles make fresh Move1 minimum progress and pay shared Fire contact; both player and enemy stop/charge correctly when a trap creates Rubble mid-walk. The manual Sooted Vault fight additionally shows persistent Fire+Rubble and lethal-threshold changes. |
| 2. Ooze shell denial and split | `enemy_surface_acceptance_suite.gd::_test_ooze_denial_and_split` | Exact selected fuel denied without substitution; two droplets appear after the finished lethal AOE, pay one Fire arrival each, and give no summoned-kill play refunds. |
| 3. Shale Bloomer + Gaoler | `enemy_surface_acceptance_suite.gd::_test_bloomer_gaoler_angle` | Authored Shard Mark preserves Fire while adding Rubble; actual Gaoler pull crosses it without voluntary movement surcharge. A changed approach angle avoids the Fire crossing while retaining the direct attack. |
| 4. Surgeon Ice counterplay | `enemy_surface_acceptance_suite.gd::_test_surgeon_ice_counterplay` | Authored Field Brace removes Ice and active Chill but preserves Rubble and an existing Freeze; displacing the Surgeon beyond support range preserves the preparation. Manual Quiet Hall demonstrates actual support timing defeating a pushed Fire payoff. |
| 5. Lancer Ice lane | `enemy_surface_acceptance_suite.gd::_test_lancer_lane` | Authored Glass Lunge paints after impact without immediate Chill. Moving away avoids Frost Pin conversion; pushing the Lancer into Ice allows the player's subsequent Ice hit to Freeze it. |
| 6. Worldspine denial | `enemy_surface_acceptance_suite.gd::_test_worldspine_denial`; `dragon_boss_suite.gd::_test_opening_gimmicks_resolve` | Raising real spines clears both hidden-under-terrain layers. Destroying one removes its announced Faultline coverage and leaves local Rubble; the remaining distant spine still ruptures without restoring denied coverage. |
| 7. Crownfire selected shared union | `enemy_surface_acceptance_suite.gd::_test_crownfire_shared_denial`; `dragon_boss_suite.gd::_test_opening_gimmicks_resolve` | Full selected-Fire replacement fizzles without touching replacement Ice or other Fire; displacement makes Vyraketh take its own once-per-actor blast alongside the player. Existing boss fixture covers opening selection and partial replacement. |
| 8. Iskaldra two-step Ice | `enemy_surface_acceptance_suite.gd::_test_iskaldra_two_step_freeze`; `dragon_boss_suite.gd::_test_status_immunities_are_atomic` | Enemy painter cannot instantly Chill/Freeze; activation enables conversion; repeated attacks cannot bypass the skipped activation's protected contact window. Existing immunity fixture rejects Freeze without consuming Iskaldra's supporting Ice or awarding player Freeze relics. |
| 9. Zekarion/Wisp fuel and electrical sharing | `enemy_surface_acceptance_suite.gd::_test_specialist_shock_fuel` and `_test_electrical_opponent_sets`; `board_surface_suite.gd::run` and `_test_enemy_and_trace_integration`; `surface_relic_suite.gd::run` | Actual authored attacks gain specialist Shock only from their exact paid fuel. Enemy conduction hits player/illusions and excludes allies; allied bodies cannot bridge enemy Chain. Core cases cover cardinal components, bare-floor gaps, normal Chain reach, useful relays, consumption and trace paths. Stormcoal relic case proves conductive Fire is consumed while Rubble survives. |
| 10. Eclipse Light; Air cascades/large bodies | `enemy_surface_acceptance_suite.gd::_test_eclipse_ground_and_air_cascade`; `dragon_boss_suite.gd::_test_opening_gimmicks_resolve`; `board_surface_suite.gd::_test_large_actors_and_sources` | Glowing Fire never protects against Eclipse; a true Light source does. An Air trap pushes the player into a second trap once, displaces a large neighboring body once, and actual resolution equals preview. Existing boss opening proves Vaeloryx damage and displacement. |

The acceptance audit found one data mismatch: unconditional Shock remained on five Zekarion/Wisp attack records. The content owner removed those baseline riders, retaining the selected-fuel Shock bonus. The new paid/denied tests then passed. No further production mechanic changes were required by these acceptance fixtures.

Related prior independent review regression: `tests/surface_core_review_test.gd` covers trap-created Ice timing, direct Detonate trap events, visible-only electrical routing, hidden AOE heads, grouped/split movement consistency, atomic terminal damage and invalid paid-mode no-mutation behavior. Whole-pool smoke remains 159 cards / 249 legal actions / 62 intents / 18 enemies.
