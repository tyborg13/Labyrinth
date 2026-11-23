# txt-27 truth rerun

The headless replay reused the [txt-24 fixtures and witnesses](../txt24/truth.md) and checked the revised copy and outcomes. The 34 findings below map to 29 original witnesses. Fifteen additional checks cover the second Air Push, the other six event offers and skips, Snuff dispatch, and saved battlefield copy.

`TXT27 WITNESSES: 44 passed, 0 failed`

| Surface | Finding | Outcome | Witness | Observed result |
| --- | --- | --- | --- | --- |
| Skills | `sure_footed` | **fixed in code** | `sure_footed_air` | Arc Flash triggers the Air trap. Aim, held-card forecast and resolution keep the hero at (3, 4). The charge is spent. A second Push moves the hero to (2, 4). |
| Skills | `ghost_stride` | **kept by decision** | `ghost_stride_range` | With 1 Movement remaining, Ghost Stride has Blink range 1 and excludes the legal tile 2 away. |
| Skills | `deferred_choice` | **fixed in code** | `deferred_choice_event_skip` | Skipping the Cinder Supplicant offer saves Immolation and closes the reward with the same Health. |
| Skills | `borrowed_time` | **fixed in code** | `borrowed_time_empower` | Empowered Chain Bolt spends a banked play and the skill charge. Preview, turn-order delta and actual Time are 0. |
| Opening boons and upgrades | `heirloom` | **text now true** | `heirloom_last_run` | The same Duelist Rapier survives one declined run. The new offer reads “Start with the Duelist Rapier you left here.” |
| Event choices | `cinder_supplicant/hand` | **fixed in code** | `event_hover_deferred_choice` | Choice text, hover IDs and the reward chooser all offer Immolation, Pyroclasm and Shatterline. |
| Event choices | `whispering_well/ember` | **text now true** | `whispering_well_cost` | “Drop Embers in” agrees with the Pay row and the observed 25-Ember debit at ordinary depth. |
| Event choices | `ossuary_gamblers/wager_embers` | **fixed in code** | `ossuary_gamblers_cost` | At depth 15, “Stake 65 Embers” and “Pay 65 Embers.” agree with the 65-Ember debit. |
| Enemy text | `storm_capacitor/discharge` | **fixed in code** | `arc_lash_diagonal` | The hero loses 6 Health. The diagonal Arc Thrall loses 0. The only Marked and struck tile is (3, 4). |
| Enemy text | `briar_weaver/thornwall` | **text now true** | `marked_thornwall` | Three Marked tiles become Outcrops and hero Health stays 100. Marked now says where the enemy acts. |
| Enemy text | `wick_shade/snuff` | **fixed in code** | `wick_shade_snuff_duration` | Snuff darkens the brazier. Entering the tile relights it. The tooltip shows the Last Light relight rule. |
| Enemy text | `ember_tick/death_burst` | **fixed in code** | `ember_tick_burst_diagram` | Details and the trait tooltip agree with the five resolved hit tiles. The hero on a diagonal keeps 100 Health. |
| Enemy text | `ember_hoarder/death_burst` | **fixed in code** | `ember_hoarder_burst_diagram` | Details and the trait tooltip agree with the five resolved hit tiles. The hero on a diagonal keeps 100 Health. |
| Enemy text | `storm_capacitor/discharge:dynamo` | **fixed in code** | `dynamo_storm_ground` | The encounter sentence describes 4 damage on Electrified. The beat deals 4 damage and leaves existing ground in place. |
| Enemy text | `storm_cantor/peal` | **fixed in code** | `storm_cantor_storm_ground` | The Peal sentence describes 4 damage on Electrified. The beat deals 4 damage and leaves existing ground in place. |
| Enemy text | `zekarion/tempest_breath` | **fixed in code** | `zekarion_storm_ground` | The Overload sentence describes 6 damage on Electrified. The beat deals 6 damage and leaves existing ground in place. |
| Enemy text | `slag_mortar:slagmaster_barrage` | **text now true** | `slagmaster_order_fire` | Player-owned Fire at (4, 4) spreads onto (5, 4). Order says each Fire tile spreads on the Slagmaster-to-hero axis. |
| Enemy text | `gloam_stalker/fade` | **text now true** | `gloam_stalker_fade_fallback` | A blocked tile behind the hero redirects Fade to (3, 3). Fade includes the existing Grimoire fallback sentence. |
| Enemy text | `burrow_grub/erupt` | **text now true** | `burrow_grub_erupt_fallback` | An Outcrop blocks the mark at (3, 4). The Grub emerges at (2, 4). Erupt uses the existing Grimoire sentence. |
| Battlefield rules | `ashen_reaver` | **text now true** | `ashen_reaver_wildfire_axis` | Fire spreads from (4, 4) to (5, 4). Wildfire describes the direction from the Reaver to the hero. |
| Battlefield rules | `slagmaster` | **text now true** | `slagmaster_wildfire_axis` | Fire spreads from (4, 4) to (5, 4). Wildfire describes the direction from the Slagmaster to the hero. |
| Battlefield rules | `gallows_roc` | **text now true** | `gallows_roc_axis` | The Fledgling east of the Roc moves one tile east. Gust describes the direction from the hero to the Roc. |
| Battlefield rules | `dynamo` | **text now true** | `dynamo_intent_name` | The intent named Arc Lash fires the Lightning Storm beat. The panel uses Arc Lash. |
| Battlefield rules | `prior` | **text now true** | `prior_shadowstep_distance` | The hidden follower moves 2 tiles. The panel gives a maximum of 3. |
| Battlefield rules | `noctyrax` | **text now true** | `noctyrax_shadowstep_distance` | The hidden Acolyte moves 2 tiles. The panel gives a maximum of 3. |
| Battlefield rules | `snare_shadow` | **text now true** | `snare_shadow_shadowstep_distance` | The hidden enemy moves 1 tile. The panel gives a maximum of 2. |
| Battlefield rules | `last_light` | **text now true** | `last_light_shadowstep_distance` | The hidden Wick Shade moves 1 tile. The panel gives a maximum of 2. |
| Glossary | `traps` | **text now true** | `traps_air_ground` | Entering an Air trap consumes it and creates 0 ground tiles. The generic Traps definition ends at “attacked.” |
| Glossary | `surface_electrified` | **kept by decision** | `electrified_hidden` | Jolt hits the visible Crawler for 2 and the connected hidden Crawler for 0. |
| Glossary | `marked` | **text now true** | `marked_thornwall` | Three Marked tiles become Outcrops and hero Health stays 100. Marked now says where the enemy acts. |
| Glossary | `skill_sure_footed` | **fixed in code** | `sure_footed_air` | Arc Flash triggers the Air trap. Aim, held-card forecast and resolution keep the hero at (3, 4). The charge is spent. A second Push moves the hero to (2, 4). |
| Glossary | `skill_ghost_stride` | **kept by decision** | `ghost_stride_range` | With 1 Movement remaining, Ghost Stride has Blink range 1 and excludes the legal tile 2 away. |
| Glossary | `skill_deferred_choice` | **fixed in code** | `deferred_choice_event_skip` | Skipping the Cinder Supplicant offer saves Immolation and closes the reward with the same Health. |
| Glossary | `skill_borrowed_time` | **fixed in code** | `borrowed_time_empower` | Empowered Chain Bolt spends a banked play and the skill charge. Preview, turn-order delta and actual Time are 0. |

## Acceptance

1. Sure-Footed spends the same charge on a trap hit and an adjacent Air Push. The resolver is shared with aim and held-card forecasts. The standalone trap suite also checked player, enemy, attack and skill-triggered traps.
2. Borrowed Time zeroes the charged card's total Time, including Empower. The headless scene reported 0 for both the card preview and the turn-order delta, and the committed card paid 0.
3. Event Skip uses the combat reward's card selection. All seven spell-choice effects were replayed with a saved Shatterline. Choice text, hover, forecast and reward agreed on card identities and order. Skips saved the chosen card without healing. The event receipt still records the authored roll.
4. The Ossuary Gamblers title and Pay row both displayed 65 Embers at depth 15. The catalogue's other event titles contain no numeric Ember amount tied to a scaled effect.
5. Discharge forecast, Marked tiles and committed hits use side adjacency. A four-hit route still lands with 6, 5, 4 and 3 damage. No other authored enemy hop claims adjacent while accepting a diagonal.
6. Both enemy death Burst traits use the five-tile cross in Details, the trait tooltip and the pre-battle trait. The other enemy Burst presentations use live Marked tiles or the existing generic cross. No other authored death Burst trait was found.
7. The Dynamo, Cantor and Zekarion addenda show their encounter's Lightning Storm sentence. Skybreak still uses its Lightning Strikes definition.
8. Wick Shade uses the authored Last Light relight diagram. The Lamplighter retains the Last Procession tooltip and Night Coil retains its own rule. The pre-battle notes apply the same action distinction.
9. The generic Traps definition has no diagram. The non-Air tile hover shows the supplied ground sentence and cross, and the Air tile hover uses the supplied Push sentence.
10. Headless layout exercised the revised text on the live surfaces. Resumed rule instances refresh the authored sentence while retaining beat state and dials. Ashen Reaver's pre-battle screen has no Wildfire text slot. The capture plan includes that screen and the separate live Wildfire panel.

## Headless checks

The replay logs are in [the task proof folder](/private/tmp/labyrinth_codex/txt-27). The focused runner's event group was rerun separately after the combined run exhausted its timeout during the event UI suite. The terminal lines below come from the focused successes after updating the superseded text assertions.

| Check | Result line |
| --- | --- |
| Truth rerun | `TXT27 WITNESSES: 44 passed, 0 failed` |
| Trap acceptance | `TRP01 TRAP RULES: PASS (376 checks, 0 failures)` |
| Board surfaces | `TXT27 SUITE traps: 91 checks, 0 failures` |
| Combat skills | `TXT27 SUITE combat skills: 122 checks, 0 failures` |
| Run skills and rewards | `TXT27 SUITE run skills and rewards: 123 checks, 0 failures` |
| Event rules and rewards | `TXT27 SUITE events and rewards: 84339 checks, 0 failures` |
| Event UI | `TXT27 SUITE event UI: 1255 checks, 0 failures` |
| Event previews | `TXT27 SUITE event previews: 1867 checks, 0 failures` |
| Enemy intent previews | `TXT27 SUITE enemy intent previews: 41 checks, 0 failures` |
| Enemy intent continuity | `TXT27 SUITE enemy intent continuity: 1918 checks, 0 failures` |
| Enemy Burst | `TXT27 SUITE enemy Burst: 145 checks, 0 failures` |
| Capacitor | `TXT27 SUITE Capacitor: 132 checks, 0 failures` |
| Icefall | `TXT27 SUITE Icefall: 226 checks, 0 failures` |
| Marked | `TXT27 SUITE Marked: 69 checks, 0 failures` |
| Guardians | `TXT27 SUITE guardians: 151 checks, 0 failures` |
| Last Light | `TXT27 SUITE Last Light: 238 checks, 0 failures` |
| Battlefield rules | `TXT27 SUITE battlefield rules: 629 checks, 0 failures` |
| Glossary and Grimoire | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| Rules text lint | `PASS: Rules text lint (16 existing hits)` |
| UI identity lint | `Ran 25 tests in 7.084s`, `OK` |
| Changed GDScript typed arrays | `TXT27 TYPED ARRAYS: 26 files scanned, 0 new candidates` |
| Python default | `Ran 196 tests in 28.097s`, `OK` |

The Python runner's post-test learned timing write was refused by the read-only Git metadata sandbox.

## Proof for the design owner

The [native launcher](native.sh) is also at `/private/tmp/labyrinth_codex/txt-27/native.sh`. Run it from the unit worktree.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-27 && bash /private/tmp/labyrinth_codex/txt-27/native.sh
```

The launcher prints a fresh output folder with `before-1920x1080`, `after-1920x1080` and `after-1280x800` subfolders. Each call uses the native visual probe runner, 100% UI scale, `LABYRINTH_CEL_LOOK=all`, an exact-size SubViewport, and an image contract. The sibling txt-25 worktree matches candidate 4 on the production paths. Real captures and visual inspection are pending.

The baseline headless replay also recorded `TXT27 HEADLESS LAYOUT 1920x1080: 20 surfaces, 0 failures.` Its sibling asset cache emitted missing generated texture diagnostics. The native runner performs its normal asset bootstrap before rendering. [Baseline layout](/private/tmp/labyrinth_codex/txt-27/before-layout/layout.json).

The headless dry run recorded `TXT27 HEADLESS LAYOUT 1920x1080: 20 surfaces, 0 failures.` and `TXT27 HEADLESS LAYOUT 1280x800: 20 surfaces, 0 failures.` [1920×1080 layout](/private/tmp/labyrinth_codex/txt-27/captures.4hjlAr/after-1920x1080/layout.json), [1280×800 layout](/private/tmp/labyrinth_codex/txt-27/captures.4hjlAr/after-1280x800/layout.json).

## Chosen defaults and open proof

- The witness reuses txt-24's seed, grid, Health, cards and positions. The capture uses existing encounter fixtures and their seed 7262026, Duelist Rapier for Heirloom, Shatterline for deferral, a 100-Ember fixture wallet and a Fire trap at (5, 4).
- The probe uses reduced motion to settle static screens, a 600-frame readiness budget, five settling frames, a two-pixel measurement tolerance and a 180-second native runner timeout. The debug tooltip placement is specified in the probe.
- `TODO_DESIGN_ashen_reaver_prebattle_rule_placement` records the missing pre-battle Wildfire placement. The existing pre-battle screen and the Wildfire battlefield panel are separate captures.

## Changed files

- `scripts/` `action_icon_library.gd`, `battlefield_rules/dispatcher.gd`, `battlefield_rules/intent_rows.gd`, `board_tile_tooltip.gd`, `combat_board_view.gd`, `combat_engine.gd`, `enemy_mechanics/capacitor.gd`, `enemy_mechanics/death_burst_view.gd`, `event_rules.gd`, `event_view.gd`, `guardian_library.gd`, `run_engine.gd`, `run_scene.gd`.
- `spec/` `analytics.md`, `card_balance_heuristic.md`.
- `tests/` `fixtures/txt13_approved_copy.json`, `short_card_tooltips_test.gd`, `suites/battlefield_rules_suite.gd`, `suites/en02_enemies_suite.gd`, `suites/en06_enemies_suite.gd`, `suites/last_light_suite.gd`, `suites/mrk01_marked_suite.gd`, `suites/special_encounter_suite.gd`, `test_element_rule_contract.py`, `test_short_card_tooltips.py`, `text_budget_test.py`, `trap_copy_contract.py`.
- `tools/` `card_heuristic.py`, `txt27/battlefield_proof.gd`, `txt27/battlefield_proof.gd.uid`, `txt27/capture.gd`, `txt27/capture.gd.uid`, `txt27/combat_proof.gd`, `txt27/combat_proof.gd.uid`, `txt27/fixture.gd`, `txt27/fixture.gd.uid`, `txt27/focused.gd`, `txt27/focused.gd.uid`, `txt27/native.sh`, `txt27/probe.gd`, `txt27/probe.gd.uid`, `txt27/proof-1280x800.json`, `txt27/proof-1920x1080.json`, `txt27/result.md`.
