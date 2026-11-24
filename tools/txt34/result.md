# txt-34 Grimoire bestiary implementation

## Acceptance criteria

1. All 18 creature pages render the two protected lore paragraphs through the existing body label and inline renderer. The eight changed rules articles retain the original article layout.
2. Each creature page builds Battlefield Rule, Traits and Moves in that order, omitting empty sections. The rule and half-Health sentence come directly from the rule instance. Traits use the existing Burst, Split and unit-trait token providers. Command remains specific to a live captain and objective. The move table reads the catalog in order, includes follow-up and zero-weight intents, and uses the shared Known Moves icon, row and summary logic with authored base values. The pre-battle control tree matched revision `23152865a` for the Bone Harrier fixture.
3. Section labels share the Granted Cards style. The rows use parchment ink, 52 px minimum height, 12 px horizontal spacing, 40 px sockets styled from the entry socket, a 1 px separator and a 16 px gap before each section header. The summaries wrap and render existing pattern diagrams. The Time labels are right aligned and vertically centred.
4. Mouse wheel and vertical right stick scroll the creature detail beneath the fixed header. The detail scrollbar inherits the same theme as the navigation scrollbar. The left list stays stationary when the mouse wheel is over the detail pane.
5. Search indexes lore alongside ordinary rules text at the same weight. The proof found Cinder Droplet with the lore word “gobbet.”
6. The fixture changes preserve exact equality checks. The dragon suite now checks the exact lore in both fixtures and requires the old body field to be absent.

## Truth table

The creature table covers the mechanical and visual claims in paragraph 2. Intent paths refer to catalog IDs in `data/enemies.json`. The rules table cites the resolver witnesses by ID. A `TODO_DESIGN_*` verdict identifies protected wording for the director to resolve.

### Creature lore

| Entry | Claim | Evidence | Verdict |
| --- | --- | --- | --- |
| Tunnel Crawler | Scuttles toward the player | `data/enemies.json → crawler.intents.skitter_strike` and `lunge`, both `move_toward` | Supported |
| Tunnel Crawler | Rakes with its claws | `crawler.intents.skitter_strike/lunge` both use Range 1 melee. The claw phrasing describes that melee. | Supported |
| Tunnel Crawler | Curls into a defensive hide | `crawler.intents.coil` gives Block. | Supported |
| Dust Acolyte | Prefers fighting at a distance | `acolyte.ai_profile` is artillery with preferred range 3. | Supported |
| Dust Acolyte | Throws grave-dust bolts | `acolyte.intents.dust_bolt` is a Range 3 shot. | Supported |
| Dust Acolyte | Wards itself with Block | `acolyte.intents.ward_chant` ends with Block. | Supported |
| Dust Acolyte | Drains hero Health to mend itself | `acolyte.intents.siphon` has separate ranged damage and self-heal actions. The `heal_self` handler heals independently of Health damage dealt. `scripts/combat_engine.gd:5000` | `TODO_DESIGN_enemy_acolyte` |
| Bone Harrier | Throws its spear at range | `harrier.intents.pelt/darting_pelt` are ranged. The spear is visible in the approved Harrier art. | Supported |
| Bone Harrier | Its hardest throw goes through Block | `harrier.intents.pelt` has damage 5 and Pierce. Darting Pelt has damage 4 and no Pierce. | Supported |
| Bone Harrier | Skips back out of reach | `harrier.intents.retreat_step` moves away up to 2 tiles and gives Block. | Supported as retreat behaviour |
| Bone Harrier | Rushes in to stab | `harrier.intents.rush` moves toward the player before melee. | Supported |
| Stone Warden | Marches in behind its shield and swings a spiked mace | `warden.intents.marching_blow` moves toward the player and uses melee. The shield and spiked mace are visible in `assets/units/stone_warden_cutout/front/rest.png`. | Supported |
| Stone Warden | Stamps to hit adjacent tiles | `warden.intents.crushing_step` targets the 4 cardinal neighbours. | Supported |
| Stone Warden | Gives Block to each other enemy | `warden.intents.bulwark` uses `all_other_enemies`. The handler skips the Warden and dead enemies. `scripts/combat_engine.gd:5022` | Supported |
| Cinder Ooze | Oozes toward the player | `cinder_ooze.intents.smolder_slide/ooze_advance` move toward the target. | Supported |
| Cinder Ooze | Leaves Fire where it strikes | `cinder_ooze.intents.smolder_slide/cinder_bloom` both have `surface: fire`. | Supported |
| Cinder Ooze | Consumes nearby flames for more protection | `cinder_ooze.intents.slag_shell.surface_fuel` consumes Fire within 1 and adds to Block. | Supported |
| Cinder Ooze | Always splits into two Cinder Droplets on death | `cinder_ooze.death_spawn` requests 2. Eligible landing sites can run out, and the death hook skips summoned parents. `scripts/combat_engine.gd:8633`, `scripts/combat_engine.gd:8721` | `TODO_DESIGN_enemy_cinder_ooze` |
| Cinder Droplet | Darts in and spatters the player | `cinder_droplet.intents.spatter` moves toward the target before melee. | Supported |
| Cinder Droplet | Spatter leaves Fire on the hit tile | `cinder_droplet.intents.spatter.actions[1].surface` is Fire. | Supported |
| Cinder Droplet | Retreats and gains a thin layer of Block | `cinder_droplet.intents.hiss_back` moves away 1 and gives Block 2. | Supported |
| Shale Bloomer | Flying stone leaves Rubble around the enemy | `bile_bloomer.intents.bile_burst` places Rubble on the authored attack area around its destination. | Supported |
| Shale Bloomer | Shards make the next hit land harder | `bile_bloomer.intents.spore_mark` gives Expose. Incoming hit calculations add Expose. `scripts/combat_engine.gd:5337` | Supported |
| Shale Bloomer | Grows Stoneskin | `bile_bloomer.intents.pustule_shell` gives Stoneskin. | Supported |
| Shale Bloomer | Adjacent Rubble thickens the Stoneskin | `bile_bloomer.intents.pustule_shell.surface_fuel` uses Rubble within 1 to add Stoneskin. | Supported |
| Chainbound Gaoler | Hooks the player and pulls them in | `chainbound_gaoler.intents.chain_reel` Pulls toward the source. | Supported |
| Chainbound Gaoler | Shackles the player in place | `chainbound_gaoler.intents.manacle_pin` sets Immobilize. | Supported |
| Chainbound Gaoler | Batters the player up close | `chainbound_gaoler.intents.cudgel_press` approaches and attacks in melee. | Supported |
| Chainbound Gaoler | Also uses Block | `chainbound_gaoler.intents.iron_guard` gives Block. | Supported |
| Grave Surgeon | Hangs back to heal other enemies | `grave_surgeon.ai_profile` is support with preferred range 3. `triage_suture` heals within range 3. | Supported |
| Grave Surgeon | Braces other enemies with Block | `grave_surgeon.intents.field_brace` uses `guard_ally`. | Supported |
| Grave Surgeon | Bracing clears Fire, Ice or Electrified beneath the recipient | `field_brace` sets `clear_surface: elemental`. The guard handler removes it on the recipient's footprint. `scripts/combat_engine.gd:5041` | Supported |
| Grave Surgeon | Cuts with a serrated saw in close combat | `grave_surgeon.intents.saw_jab` is melee. The serrated weapon is visible in `assets/art/enemies/grave_surgeon.png`. | Supported |
| Frostglass Lancer | Thrusts through a line of tiles and leaves Ice | `frostglass_lancer.intents.glass_lunge` has an oriented 3-tile line and `surface: ice`. | Supported |
| Frostglass Lancer | Throws the spear from range | `frostglass_lancer.intents.spear_cast` is ranged. | Supported |
| Frostglass Lancer | Strong attacks Stagger hit targets on Ice | `frostglass_lancer.intents.glass_lunge/frost_pin` have the Ice-on-target Stagger rider. | Supported |
| Frostglass Lancer | Falls back behind Block | `frostglass_lancer.intents.refract_guard` moves away and gives Block. | Supported |
| Lightning Wisp | Zips in to sting | `lightning_wisp.intents.spark_dart` moves toward the target and uses melee. | Supported |
| Lightning Wisp | Electrifies the ground below itself | `lightning_wisp.intents.static_lash` ends with a Range 0 Electrified placement. | Supported |
| Lightning Wisp | Arcs along Electrified ground | `lightning_wisp.intents.blinding_arc` is lightning ranged. Electrified routing can add electrically assisted victims. `scripts/combat_engine.gd:12418` | Supported |
| Lightning Wisp | Its conducted Arc shocks the units it reaches | `blinding_arc` uses a `conducted` Shock rider. The engine tests `electrically_assisted` per hit. `scripts/combat_engine.gd:12982` | Supported |
| Veilbound Acolyte | Fires needles of shadow at short range | `veilbound_acolyte.intents.veil_needle` is shadow ranged, Range 2. | Supported |
| Veilbound Acolyte | Slips away | `veilbound_acolyte.intents.shroudstep` moves away up to 2. | Supported |
| Zekarion | Scatters lightning and Electrified tiles | `zekarion.intents.skybreak` uses scattered lightning strikes and leaves Electrified. | Supported |
| Zekarion | Overload strikes units standing on Electrified | `data/battlefield_rules.json → instances.zekarion` fires Lightning Storm on Overload (`tempest_breath`). The beat resolves on Electrified tiles for all eligible units. `scripts/battlefield_rules/lightning_storm.gd:11` | Supported |
| Zekarion | Lashes at the player with lightning | `zekarion.intents.storm_claw` uses lightning ranged damage. | Supported |
| Zekarion | Calls Lightning Wisps between storm beats | `zekarion.intents.call_wisps` summons `lightning_wisp`. The `cycle_order` includes the summons between Skybreaks. | Supported |
| Tharokh | Sends lines of breaking stone | `tharokh.intents.stonewake` is a line attack with earth presentation. | Supported |
| Tharokh | Breathes a wave that leaves Rubble | `tharokh.intents.bedrock_breath` is a line attack with `surface: rubble`. | Supported |
| Tharokh | Rakes at close range | `tharokh.intents.worldspine_claw` moves toward the target and attacks with a Range 1 crescent. | Supported |
| Tharokh | Marked ground heaves into Outcrops | `data/battlefield_rules.json → instances.tharokh` installs Upheaval. A blocked site or a unit that cannot be displaced can prevent a marked tile from rising. `scripts/battlefield_rules/upheaval_rise.gd:23` | `TODO_DESIGN_enemy_tharokh` if read as applying to each Mark |
| Tharokh | Burrow Grubs fight at its side | `tharokh.dragon_helpers` includes 2 Burrow Grubs. | Supported |
| Vyraketh | Cinders Mark and ignite the ground | `vyraketh.intents.kindle_ground/cinder_maw` both create cinder Marks and Fire. `scripts/combat_engine.gd:7067` | Supported |
| Vyraketh | Its breath spreads each fire to adjacent tiles | `data/battlefield_rules.json → instances.vyraketh` fires Wildfire on Cinder Breath above half Health. At half Health the cadence switches to every second Vyraketh turn. | `TODO_DESIGN_enemy_vyraketh` for the unqualified breath trigger |
| Vyraketh | Bites hard up close | `vyraketh.intents.cinder_maw` has damage 8 melee, Range 1. | Supported |
| Vyraketh | Crownfire sets off its Marked fires at once | `vyraketh.intents.crownfire` opens with `detonate_cinders`. The resolver bursts the fuel together before movement. `scripts/combat_engine.gd:7091` and witness `crownfire_order` | Supported |
| Vyraketh | Cinder Droplets fight at its side | `vyraketh.dragon_helpers` includes a Cinder Droplet. | Supported |
| Vaeloryx | Hooks and drags the player from range | `vaeloryx.intents.skyhook` is Range 4 with Pull 2. | Supported |
| Vaeloryx | Dives and hits along its path | `vaeloryx.intents.razor_dive` uses an approach and `swept_path` area. | Supported |
| Vaeloryx | Throws back everyone nearby | `vaeloryx.intents.hollow_gale` has a body-centred range-2 area with Push 1. Ordinary Push can be blocked or resisted. `scripts/combat_engine.gd → _force_move_actor` | Supported as the move's intent |
| Vaeloryx | Gust blows downwind at the end of each of its turns | `data/battlefield_rules.json → instances.vaeloryx.cadence` specifies every source turn. `scripts/battlefield_rules/gust.gd:273` applies the wind direction. | Supported |
| Vaeloryx | Gust moves each unit | Gust excludes Anchored and buried units and routes the rest through the Push/Collision resolver. `scripts/battlefield_rules/gust.gd:108` | `TODO_DESIGN_enemy_vaeloryx` |
| Vaeloryx | Gust Shrikes fly at its side | `vaeloryx.dragon_helpers` includes a Gust Shrike. | Supported |
| Iskaldra | Builds Crystal Mantle layers | `iskaldra.intents.crystal_mantle` adds `frost_armor` layers. | Supported |
| Iskaldra | Lances the floor with Ice | `iskaldra.intents.whiteout_lance` places Ice in its attack area. | Supported |
| Iskaldra | Claws at close range | `iskaldra.intents.rime_talon` attacks in melee, Range 1. | Supported |
| Iskaldra | Each layer widens Shatterstorm | `iskaldra.intents.shatterstorm` reads `range_status: frost_armor`. Witness `shatterstorm_layers`. | Supported at announcement |
| Iskaldra | Frostbite damages units standing on Ice | `data/battlefield_rules.json → instances.iskaldra` and `scripts/battlefield_rules/frostbite.gd:11` use the Ice hit area. | Supported |
| Iskaldra | Rime Spitters fight at its side | `iskaldra.dragon_helpers` includes 2 Rime Spitters. | Supported |
| Noctyrax | Night Coil pulls the player closer | `noctyrax.intents.night_coil` has Pull 1 and an oriented line. | Supported |
| Noctyrax | Night Coil extinguishes braziers | `night_coil.actions[0].snuff_nearest` chooses one brazier per Coil. Witness `night_coil_nearest`. | Supported |
| Noctyrax | Rakes with its claws | `noctyrax.intents.void_claw` moves and attacks at Range 1. | Supported |
| Noctyrax | Breathes darkness that ignores Block | `noctyrax.intents.starless_breath` has shadow and Pierce. | Supported |
| Noctyrax | Last Eclipse hits Marked ground | `noctyrax.intents.last_eclipse` uses a held area for the hit. `scripts/boss_area_rules.gd → freeze/strike_tiles` | Supported |
| Noctyrax | Darkness follows the hit | `scripts/run_scene.gd:26533` applies the displayed attack losses before copying Eclipse into the displayed board state. The resolver uses the held target set and stages both changes in one step. `scripts/combat_engine.gd:7188` | Supported in presentation |
| Noctyrax | Brings Veilbound Acolytes into combat | `noctyrax.intents.last_eclipse.actions[1]` summons a Veilbound Acolyte within its cap. | Supported |

### Changed rules sentences

| Article | Claim | Evidence | Verdict |
| --- | --- | --- | --- |
| Map | Revealed exits show the next legal rooms | `map_revealed_move`, `scripts/run_engine.gd:905` and `:2293` | Supported |
| Map | Previously occupied room seals on departure | `map_sealed`, `scripts/run_engine.gd:943` | Supported |
| Defiance | A charge prevents a lethal hit | `defiance_lethal_hit`, `scripts/combat_engine.gd:11634` | Supported |
| Defiance | The hit leaves exactly 25% of maximum Health | `defiance_rounding` observed 6 of 22. The restore rounds up. `scripts/combat_engine.gd:11642` | `TODO_DESIGN_combat_defiance` |
| Targeting | Attacks target visible units within Range | `targeting_attack_and_light` checked both visibility and range, with Beacon as the hidden-tile control. `scripts/combat_engine.gd:1294` | Supported for direct enemy selection |
| Targeting | Ranged attacks need line of sight | `targeting_ranged_sight` blocks Arc Flash. `targeting_ranged_exception` lets Skybolt target the same visible enemy. Skybolt and Sleet Squall have `ignore_los`. `scripts/dragon_trophy_rules.gd:62` | `TODO_DESIGN_combat_targeting` |
| Fatigue | Each reshuffle adds 1 Health cost in the same combat | `fatigue_steps_and_resets` checked two reshuffles and a fresh combat at Depths 0, 17 and 18. `scripts/combat_engine.gd:8277` | Supported |
| Fatigue | Fatigue bypasses Block | `fatigue_ignores_block` measured identical Block before and after. `scripts/combat_engine.gd:8280` | Supported |
| Fatigue | Draw and Pass previews show the Fatigue cost | `fatigue_preview_cost` compared the Draw preview and Pass forecast to the direct Draw. `scripts/run_scene.gd:34587`, `scripts/pass_forecast_turn_start.gd:38` | Supported |
| Card Play | Each enemy summon gives one extra Card Play next turn | `summon_play` observed one arrival and one next-turn credit. The resolver credits successful summon moves. Each current authored summon move has a count of 1. `scripts/summon_card_play_rules.gd:15` | Supported for successful summons |
| Card Play | Killing a summon gives no Card Play | `summoned_kill` found 0 credit for the summoned kill and 1 for the unsummoned control. | Supported |
| Meteorfall and Crownfire | Crownfire Bursts Vyraketh's Marked Fire, then moves and attacks | `crownfire_order` exercised the Burst, movement and melee order, with Ice in place of Fire as a control. | Supported |
| Meteorfall and Crownfire | The Meteorfall card Marks tiles | `meteorfall_marks` saw three Marks before any damage. `scripts/surface_card_rules.gd:515` | Supported |
| Meteorfall and Crownfire | At next turn start, units on Marks take damage and the tiles turn to Fire | `meteorfall_lands` observed 8 Health loss and Fire on all three tiles. `scripts/combat_engine.gd:3405`, `scripts/surface_card_rules.gd:538` | Supported |
| Crystal Mantle | Each layer extends Shatterstorm by 1 at announcement | `shatterstorm_layers` measured effective range and marked tiles for 0, 1 and 2 layers. `scripts/guardian_combat_rules.gd:547` | Supported |
| Crystal Mantle | Shatterstorm breaks remaining layers | `shatterstorm_layers` confirmed the two remaining layers were spent. `scripts/guardian_combat_rules.gd:405` | Supported |
| Crystal Mantle | Card layers last until broken or combat ends | `crystal_mantle_card` checked gain, turn retention, one layer spent on a hit and a fresh combat. `scripts/maneuver_rules.gd:524`, `scripts/combat_engine.gd:5342` | Supported |
| Last Eclipse | Night Coil puts out the nearest brazier | `night_coil_nearest` compared two different distances. `scripts/dragon_combat_rules.gd:101` | Supported |
| Last Eclipse | Walk or Blink onto a dark brazier to relight it | `night_coil_relight` exercised both movement paths. `scripts/dragon_combat_rules.gd:221` | Supported |
| Last Eclipse | Light blocks Eclipse darkness | `eclipse_light` made an Eclipse-hidden tile visible with Beacon. | Supported |

## Changed files

- `scripts/grimoire_panel.gd`, `scripts/grimoire_creature_page.gd` and `scripts/grimoire_creature_page.gd.uid`. Creature detail, typography, sockets and scrolling.
- `scripts/grimoire_search.gd`, `scripts/input_wording.gd`. Lore indexing and body paragraph selection.
- `scripts/known_move_text.gd` and `scripts/known_move_text.gd.uid`, `scripts/pre_battle_inspection_view.gd`, `scripts/run_scene.gd`. Shared static move presentation and unchanged pre-battle rendering path.
- `tests/fixtures/pla02_grimoire_pages.json`, `tests/fixtures/txt20_rules_copy.json`, `tests/fixtures/bos02_feedback1_grimoire.json`, `tests/suites/dragon_feedback1_suite.gd`. Updated rules and lore pins and exact lore comparisons for the dragon fixture.
- `tools/txt34/pages.gd`, `tools/txt34/witnesses.gd`, `tools/txt34/fixture_suites.gd`, `tools/txt34/pages.gd.uid`, `tools/txt34/witnesses.gd.uid`, `tools/txt34/fixture_suites.gd.uid`, `tools/txt34/native.sh`, `tools/txt34/native_contract.json`, `tools/txt34/result.md`. Implementation proof and handoff.
- `/private/tmp/labyrinth_codex/txt-34/native.sh`. Executable wrapper the director requested.

The two protected files match the worktree's original HEAD. Changes are uncommitted.

## UI identity lint

| Rule | Before | After |
| --- | ---: | ---: |
| R1 raw boxes | 65 | 65 |
| R2 colour literals | 1264 | 1264 |
| R3 outline boxes | 14 | 14 |
| R4 bare bars | 2 | 2 |
| R5 ad-hoc fonts | 39 | 39 |
| R6 tiny captions | 6 | 6 |

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-34 && /private/tmp/labyrinth_codex/txt-34/native.sh
```

The script uses the existing clean release checkout at `23152865a` for the before project. Set `TXT34_BASE_PROJECT` to a clean checkout of that SHA if the release checkout has moved. The probe renders the live in-run Grimoire and pinned pre-battle inspection in a 1920×1080 SubViewport at 100% UI scale with `LABYRINTH_CEL_LOOK=all`. The windowed runner validates 17 PNGs per revision and prints each absolute path. Vyraketh has a top and bottom capture in both revisions. Both before positions show the original article without a scrollable move table. The after positions show the bestiary at each scroll limit. There are no PNGs from the headless run.

## Chosen defaults

- Proof only. Reused the pre-battle fixture's first eligible seed, room selection and 1920×1080 viewport. The probe grants the 26 requested and audited entries to the temporary run, uses pointer modality with an Xbox controller family, settles layout for four process frames and freezes decorative transitions with reduced motion for both versions.
- Proof only. Vertical stick input uses amplitudes −1 and +1 and a 0.1-second test interval. The capture contract checks a central 920×420 region starting at (500, 320) for a luma range of at least 25 and standard deviation of at least 3. The product uses the existing section map response of 1150 px/s and a 0.22 deadzone on the vertical axis.
- Witnesses reuse the existing 9×9 walled combat fixture, seed 24, 100 test Health and its starting positions. The named cases use 2 reshuffles at depths 0, 17 and 18, 50 test Block, a level 4 Depth 14 run for Defiance, 1 Health for lethal controls, 0 to 2 starting Shatterstorm layers and two distinct brazier distances.

## Observed checks

| Command or probe | Exact result |
| --- | --- |
| `python3 tests/test_rules_text_lint.py` | `PASS: Rules text lint (16 existing hits)`, `Ran 3 tests in 0.066s`, `OK` |
| `python3 tests/text_budget_test.py` | `Ran 6 tests in 0.132s`, `OK` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.507s`, `OK` |
| `python3 tests/test_icon_identity_policy.py` | `Ran 10 tests in 0.097s`, `OK` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| `tests/mrk01_marked_test.gd` | `MRK01 MARKED TEST: PASS (69 checks, 0 failures)` |
| `tests/pre_battle_semantics_test.gd` | `INT06 LOB INSPECTION: one/two crosses; raw known moves; scaled and held values checked`, `PRE-BATTLE SEMANTICS TEST: PASS`, `TEST RESULT: PASS` |
| `tests/grimoire_focus_return_probe.gd` | `GRIMOIRE SEARCH PROBE RESULT: PASS` |
| `tools/txt34/fixture_suites.gd` | `TXT34 FIXTURES relic_u1_suite.gd: 4510 checks, 0 failures`, `TXT34 FIXTURES inline_icon_description_suite.gd: 2832 checks, 0 failures` |
| `tests/worldspine_rules_test.gd` | `grimoire_search_suite.gd: 33 checks, 0 failures`, `dragon_feedback1_suite.gd: 84 checks, 0 failures`; wrapper `TRN-01 RULES RESULT: FAIL (2254 checks, 4 failures)` |
| `tests/worldspine_rules_test.gd -- --feedback-only` on `23152865a` | `TRN-01 RULES RESULT: FAIL (14 checks, 4 failures)` with the same four messages |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/txt-34/python-default-final` | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 39.711s`, `OK` |
| `/private/tmp/labyrinth_codex/txt-34/native.sh --dry-run` | `TXT34 PAGE PROOF: PASS (headless, 26 pages, 17 capture states)` in both versions, `TXT34 SCROLL: wheel=39, bottom=246, fixed header`, `TXT34 COMPARISON: PASS (Bone Harrier pre-battle text, icons and layout identical)`, `TXT34 RULES WITNESSES: PASS (20 checks, 2 design findings, 0 unexpected failures)` |
| `python3 tools/cel_look.py status` | `CEL_STATUS current` |
| Planned PNG names against the capture contract | `TXT34 CAPTURE PLAN: PASS (17 planned PNG paths per version match the contract)` |

Godot commands used `python3 tools/godot_task_runner.py --task-id txt-34 --stream -- godot --headless --path . --script <script>`. The before proof used the exact release snapshot as its project path. The dry-run logs, inventories and planned capture paths are in `/private/tmp/labyrinth_codex/txt-34/proof.H3Oefi/` under `before.log`, `after.log`, `witnesses.log`, `before/inventory.json` and `after/inventory.json`.

## Open issues

- Native rendering, pixel parity and visual identity review require the window-server session.
- The Worldspine wrapper reports two FB1.1 Tick burst/Pass forecast failures and two FB1.2 Stoneskin cast-order failures. All four reproduce on `23152865a`.
- The headless runner emitted the macOS system CA diagnostic. The Python runner could not save learned timings in shared read-only Git metadata after its 196 tests passed.
- Protected copy has seven director findings in the truth table. The task introduced no placeholder into runtime data or UI.

## Fixture line inventory

Each diff hunk below lists every removed and added line in the three changed text fixtures.

### `tests/fixtures/pla02_grimoire_pages.json`

```diff
@@ -9 +9 @@
-      "Revealed exits show where you can travel next. Cleared rooms stay available as routes.",
+      "Revealed exits show where you can travel next. Rooms you leave are sealed behind you.",
@@ -41 +41 @@
-      "Each Defiance charge saves you from 1 lethal hit and leaves you at 25% Health.",
+      "Each Defiance charge saves you from 1 lethal hit and leaves you at 25% of your maximum Health.",
@@ -45 +45 @@
-      "Targets must be visible and within Range. Ranged attacks also need line of sight.",
+      "Attacks need a visible target within Range. Ranged attacks also need line of sight.",
@@ -50 +50 @@
-      "Fatigue costs 2 Health the first time and +1 Health each time after. Fatigue bypasses Block. Draw and Pass previews show the Health that Fatigue costs."
+      "Each Fatigue in a combat costs 1 more Health than the last. Fatigue bypasses Block. Draw and Pass previews show the Health that Fatigue costs."
@@ -102 +102 @@
-      "Each enemy summon gives you 1 more Card Play next turn."
+      "Each enemy summon gives you 1 more Card Play next turn. Killing a summoned enemy gives none."
@@ -187 +187 @@
-      "Meteorfall hits each Marked tile and leaves Fire. Whenever Vyraketh breathes, Fire spreads to each adjacent tile. Crownfire Bursts Vyraketh's Marked Fire while Vyraketh moves toward you. Replace that Fire to stop Crownfire's Burst, or lure the dragon into the Burst. The Meteorfall card leaves Marked tiles through enemy turns. At the start of your next turn before you Draw, deal damage to each unit on a Marked tile, then leave Fire on each Marked tile."
+      "Crownfire Bursts each of Vyraketh's Marked Fire tiles, then Vyraketh moves toward you and attacks. The Meteorfall card Marks tiles. At the start of your next turn, each unit on a Marked tile takes damage, and each Marked tile becomes Fire."
@@ -210 +210 @@
-      "Each layer extends Shatterstorm by 1 tile. Break layers before Shatterstorm to reduce the area. Shatterstorm breaks the remaining layers. Ice on Iskaldra's tile gives Iskaldra an extra layer. Remove that Ice before Iskaldra's turn. Crystal Mantle cards give you layers that last until broken or combat ends."
+      "Each layer extends Iskaldra's Shatterstorm by 1 tile, and Shatterstorm breaks the remaining layers. Crystal Mantle cards give you layers that last until broken or combat ends."
@@ -214 +214 @@
-      "Night Coil puts out a Marked brazier before Noctyrax announces Last Eclipse. Walk or Blink onto that brazier's tile to relight the brazier. Light blocks Eclipse's darkness. Relight a brazier or create Light, then avoid or guard against the Marked tiles. Noctyrax replaces defeated Acolytes, up to 2 alive. Light and Vision reveal hidden Acolytes. Braziers still relight and Shades from Snuff still leave when the enemy's turn is skipped."
+      "Night Coil puts out the nearest brazier. Walk or Blink onto a dark brazier's tile to relight that brazier. Light blocks Eclipse's darkness."
```

### `tests/fixtures/txt20_rules_copy.json`

```diff
@@ -207 +207 @@
-      "Each Defiance charge saves you from 1 lethal hit and leaves you at 25% Health.",
+      "Each Defiance charge saves you from 1 lethal hit and leaves you at 25% of your maximum Health.",
@@ -211,2 +211,2 @@
-      "A target must be visible and within Range. Walls and Outcrops block the line of sight required by ranged attacks.",
-      "Area actions hit the tiles shown in the preview. Push and Pull move the target from or toward the source until the target reaches the distance or stops."
+      "Attacks need a visible target within Range. Ranged attacks also need line of sight.",
+      "Walls and Outcrops block the line of sight required by ranged attacks. Area actions hit the tiles shown in the preview. Push and Pull move the target from or toward the source until the target reaches the distance or stops."
@@ -215 +215,2 @@
-      "When you Draw from an empty draw pile, shuffle your discard pile into your draw pile and lose 2 Health, +1 each time. Fatigue bypasses Block."
+      "Drawing from an empty draw pile shuffles your discard into your draw pile and costs Health.",
+      "Each Fatigue in a combat costs 1 more Health than the last. Fatigue bypasses Block. Draw and Pass previews show the Health that Fatigue costs."
@@ -264 +265,2 @@
-      "Playing a card spends 1 Card Play. Card Plays refill each turn. Killing an enemy on your turn gives 1 more, except summons."
+      "Spend 1 Card Play per card, refilling each turn and gaining 1 per kill.",
+      "Each enemy summon gives you 1 more Card Play next turn. Killing a summoned enemy gives none."
@@ -348,34 +349,0 @@
-    "enemy:acolyte": [
-      "A ranged enemy whose intents alternate between damage, defense and Health loss."
-    ],
-    "enemy:harrier": [
-      "The Harrier often moves before a ranged attack with Pierce."
-    ],
-    "enemy:warden": [
-      "The Stone Warden uses melee attacks and gains Block. The Stone Warden's Block absorbs damage before Health."
-    ],
-    "enemy:cinder_ooze": [
-      "The Cinder Ooze leaves Fire. Slag Shell removes adjacent Fire for extra Block. When this enemy dies, this enemy splits into Cinder Droplets."
-    ],
-    "enemy:cinder_droplet": [
-      "A Cinder Droplet spawns when a Cinder Ooze dies. Cinder Droplet attacks leave Fire."
-    ],
-    "enemy:bile_bloomer": [
-      "The Bile Bloomer's attacks leave Rubble on hit tiles and Expose targets. Shale Shell removes adjacent Rubble for extra Stoneskin."
-    ],
-    "enemy:chainbound_gaoler": [
-      "The Chainbound Gaoler uses Push, Pull and Immobilize to restrict movement."
-    ],
-    "enemy:grave_surgeon": [
-      "The Grave Surgeon heals allies and gives Block. The guard removes elemental ground from the target's tile."
-    ],
-    "enemy:frostglass_lancer": [
-      "The Frostglass Lancer leaves Ice. Refract Guard removes Ice from the Lancer's tile."
-    ],
-    "enemy:zekarion": [
-      "Zekarion is supported by Lightning Wisps. Skybreak and Storm Lash leave Electrified.",
-      "When Zekarion uses Overload, each unit on Electrified takes 6 damage. At half Health, each unit on Electrified takes 7 damage. Stay off Electrified or lure Zekarion's Wisps onto Electrified."
-    ],
-    "enemy:lightning_wisp": [
-      "The Lightning Wisp leaves Electrified. Capacitor Arc Shocks targets hit through Electrified."
-    ],
@@ -387,3 +355,2 @@
-      "Meteorfall hits each Marked tile and leaves Fire. Whenever Vyraketh breathes, Fire spreads to each adjacent tile.",
-      "Crownfire Bursts Vyraketh's Marked Fire while Vyraketh moves toward you. Replace that Fire to stop Crownfire's Burst, or lure the dragon into the Burst.",
-      "The Meteorfall card leaves Marked tiles through enemy turns. At the start of your next turn before you Draw, deal damage to each unit on a Marked tile, then leave Fire on each Marked tile."
+      "When this attack lands, each unit on a Marked tile takes X damage, and each Marked tile becomes Fire.",
+      "Crownfire Bursts each of Vyraketh's Marked Fire tiles, then Vyraketh moves toward you and attacks. The Meteorfall card Marks tiles. At the start of your next turn, each unit on a Marked tile takes damage, and each Marked tile becomes Fire."
@@ -414,3 +381 @@
-      "Each layer extends Shatterstorm by 1 tile. Break layers before Shatterstorm to reduce the area. Shatterstorm breaks the remaining layers.",
-      "Ice on Iskaldra's tile gives Iskaldra an extra layer. Remove that Ice before Iskaldra's turn.",
-      "Crystal Mantle cards give you layers that last until broken or combat ends."
+      "Each layer extends Iskaldra's Shatterstorm by 1 tile, and Shatterstorm breaks the remaining layers. Crystal Mantle cards give you layers that last until broken or combat ends."
@@ -419,27 +384,2 @@
-      "Night Coil puts out a Marked brazier before Noctyrax announces Last Eclipse. Walk or Blink onto that brazier's tile to relight the brazier.",
-      "Light blocks Eclipse's darkness. Relight a brazier or create Light, then avoid or guard against the Marked tiles.",
-      "Noctyrax replaces defeated Acolytes, up to 2 alive. Light and Vision reveal hidden Acolytes.",
-      "Last Eclipse hits you and your Illusions on Marked tiles, then starts Eclipse for 2 turns."
-    ],
-    "enemy:veilbound_acolyte": [
-      "The Umbra hides the Veilbound Acolyte's tile. Light and Vision reveal the Acolyte before the Acolyte attacks."
-    ],
-    "enemy:tharokh": [
-      "Earth dragon supported by Burrow Grubs.",
-      "After every second turn of yours, Tharokh's Marked tiles become Outcrops. A Marked tile stays flat if the unit on that tile cannot be moved to an open tile. At half Health, Tharokh's Marked tiles become Outcrops after each of your turns."
-    ],
-    "enemy:vyraketh": [
-      "Fire dragon that creates Marked Fire. Cinder Droplets also leave Fire.",
-      "Whenever Vyraketh breathes, Fire spreads to each adjacent tile. At half Health, Fire spreads after every second Vyraketh turn. Crownfire Bursts Vyraketh's Marked Fire. Vyraketh's bite Marks tiles again."
-    ],
-    "enemy:vaeloryx": [
-      "Air dragon that strikes from the sky and dives at you, supported by Gust Shrikes.",
-      "After each Vaeloryx turn, Gust Pushes each unit 1 tile, then turns a quarter clockwise. At half Health, Gust Pushes 2 tiles. Move closer to Vaeloryx after the retreat to take less damage from Eye of the Storm."
-    ],
-    "enemy:iskaldra": [
-      "Ice dragon protected by Crystal Mantle layers. Rime Spitters leave Ice.",
-      "When Iskaldra uses Rime Talon, Frostbite deals 3 damage to each unit on Ice. At half Health, Frostbite hits after every second Iskaldra turn instead. Break Crystal Mantle layers to shrink Shatterstorm's area."
-    ],
-    "enemy:noctyrax": [
-      "Shadow dragon and final boss of depth 24, supported by Veilbound Acolytes.",
-      "When Noctyrax uses Void Claw, hidden Veilbound Acolytes Blink 3 tiles toward you. Night Coil puts out a brazier. Enter that brazier's tile to relight the brazier. Light blocks Eclipse's darkness."
+      "Last Eclipse hits you and your Illusions on Marked tiles, then starts Eclipse for 2 turns.",
+      "Night Coil puts out the nearest brazier. Walk or Blink onto a dark brazier's tile to relight that brazier. Light blocks Eclipse's darkness."
@@ -1001,0 +942,74 @@
+  },
+  "grimoire_lore": {
+    "enemy:crawler": [
+      "A hairless, milk-eyed burrower from the deep tunnels. It hunts by the tremor of footsteps on stone.",
+      "It scuttles straight at you and rakes with its claws, or curls up behind its thick hide."
+    ],
+    "enemy:acolyte": [
+      "A robed skeleton still keeping the rites of a forgotten order. The orb in its hand is packed with the dust of the dead.",
+      "It prefers to fight from a distance, hurling bolts of grave dust, warding itself with Block and draining your Health to mend its own bones."
+    ],
+    "enemy:harrier": [
+      "The bones of a hunter who died in the Labyrinth and kept on hunting. It still carries the spear it fell with.",
+      "It harries you with its spear from range, and its hardest throws punch through Block. It skips back out of reach, or rushes in to stab."
+    ],
+    "enemy:warden": [
+      "A dead knight still keeping the watch it swore to. Its shield bears the skull of its order.",
+      "It marches in behind its shield and swings a spiked mace, or stamps down to hit everything beside it. It can also give Block to each other enemy."
+    ],
+    "enemy:cinder_ooze": [
+      "Slag that crawled out of a forge fire and kept burning. A cracked crust holds in a core that never cools.",
+      "It oozes after you and leaves Fire wherever it strikes, and it soaks up nearby flames to harden its crust. When it dies, it splits into two Cinder Droplets."
+    ],
+    "enemy:cinder_droplet": [
+      "A burning gobbet of slag, thrown off when a Cinder Ooze dies. It is small, quick and just as hot.",
+      "It darts in to spatter you and leaves Fire on your tile, then hisses back behind a thin crust of Block."
+    ],
+    "enemy:bile_bloomer": [
+      "A flower of living stone, rooted in the deep rock. Its petals are slate, and its seeds are shards.",
+      "It bursts in a spray of flying stone that leaves Rubble around it, and flicks shards that make the next hit on you land harder. It grows Stoneskin, and Rubble beside it makes that skin thicker."
+    ],
+    "enemy:chainbound_gaoler": [
+      "The Labyrinth's jailer, still walking the rounds of cells no one has left in centuries. It carries a hook on a length of chain for new prisoners.",
+      "It hooks you with its chain and drags you in, shackles you in place and batters you up close. It also hides behind Block."
+    ],
+    "enemy:grave_surgeon": [
+      "A plague doctor who kept working after the plague had taken everyone. It patches up the Labyrinth's dead and sends them back to fight.",
+      "It hangs back to heal the other enemies and brace them with Block, and the bracing clears Fire, Ice or Electrified from under them. Up close, it cuts at you with a serrated saw."
+    ],
+    "enemy:frostglass_lancer": [
+      "A knight of the Rime Hall, cloaked in frozen blue. Its spear is a single shard of glacier ice.",
+      "It drives its spear through a line of tiles and leaves Ice behind, or throws it from range, and its hardest strikes Stagger anyone standing on Ice. It also falls back behind a guard of Block."
+    ],
+    "enemy:zekarion": [
+      "The storm dragon of the Tempest Spire. Lightning crawls over its scales, and the air around it never settles.",
+      "Zekarion scatters lightning across the floor and leaves that ground Electrified, then uses Overload to strike everyone standing on it. Between storms, it lashes you with lightning and calls Lightning Wisps to its side."
+    ],
+    "enemy:lightning_wisp": [
+      "A scrap of thundercloud torn from Zekarion's storm. Zekarion calls Wisps down to fight for it.",
+      "It zips in to sting, charges the ground beneath it with Electrified, and fires arcs that leap along Electrified ground and Shock whoever they reach there."
+    ],
+    "enemy:veilbound_acolyte": [
+      "An acolyte who walked into the Umbra and came back wearing it. It serves Noctyrax at the heart of the dark.",
+      "It pricks you with needles of shadow from a short distance, then slips away again."
+    ],
+    "enemy:tharokh": [
+      "An earth dragon so old that the Worldspine Roots grew around it. Its scales are slabs of bedrock.",
+      "Tharokh sends lines of breaking stone across the room, breathes a wave of Rubble and rakes anything in reach of its claws. The ground it Marks heaves up into Outcrops, and Burrow Grubs fight at its side."
+    ],
+    "enemy:vyraketh": [
+      "The fire dragon that rules the Cinder Crown. Its scales glow like banked coals.",
+      "Vyraketh rains cinders that Mark the floor and set it burning, breathes flame that spreads each fire to the tiles around it, and bites hard up close. Crownfire sets off its Marked fires at once, and Cinder Droplets fight at its side."
+    ],
+    "enemy:vaeloryx": [
+      "The wind dragon of the Hollow Gale, pale as cloud. Its wings never stop moving.",
+      "Vaeloryx hooks you from afar and drags you in, dives through anything in its path, and whips up wind that throws back everyone near it. Its Gust shoves each unit downwind after each of its turns, and Gust Shrikes fly at its side."
+    ],
+    "enemy:iskaldra": [
+      "The ice dragon of the Rime Hall, armored in crystal that grows back as fast as it breaks.",
+      "Iskaldra wraps itself in layers of Crystal Mantle, lances the floor with Ice and claws at close range. Each layer widens Shatterstorm, Frostbite hurts each unit standing on Ice, and Rime Spitters fight at its side."
+    ],
+    "enemy:noctyrax": [
+      "The dragon at the heart of the Umbra. Every shadow in the Labyrinth leans toward it.",
+      "Noctyrax drags you closer with coils of night that snuff out braziers, rakes with its claws and breathes darkness that ignores Block. Its Last Eclipse strikes Marked ground and then swallows the room in dark, and Veilbound Acolytes rise to fight beside it."
+    ]
```

### `tests/fixtures/bos02_feedback1_grimoire.json`

```diff
@@ -5,3 +5,3 @@
-      "body": [
-        "Storm dragon supported by Lightning Wisps. Skybreak and Storm Lash leave Electrified ground.",
-        "When Zekarion uses Overload, lightning strikes every Electrified tile for 5, with Chain 1. At half Health the Chain grows to 2. Stay off charged ground, or lure its Wisps onto it."
+      "lore": [
+        "The storm dragon of the Tempest Spire. Lightning crawls over its scales, and the air around it never settles.",
+        "Zekarion scatters lightning across the floor and leaves that ground Electrified, then uses Overload to strike everyone standing on it. Between storms, it lashes you with lightning and calls Lightning Wisps to its side."
@@ -29,4 +29,2 @@
-        "Meteorfall strikes marked tiles and leaves Fire. When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions.",
-        "Crownfire detonates Vyraketh's own marked Fire while it pursues you. Replace the Fire to deny the blast, or lure the dragon into it.",
-        "The Meteorfall card marks a line of tiles the same way. The marks stay through enemy turns; at the start of your next turn, before you draw, each marked tile takes the damage (anyone standing there, including you) and becomes Fire.",
-        "Marks the shown tiles. When it lands, they take the shown damage and become Fire."
+        "When this attack lands, each unit on a Marked tile takes X damage, and each Marked tile becomes Fire.",
+        "Crownfire Bursts each of Vyraketh's Marked Fire tiles, then Vyraketh moves toward you and attacks. The Meteorfall card Marks tiles. At the start of your next turn, each unit on a Marked tile takes damage, and each Marked tile becomes Fire."
@@ -55,3 +53,3 @@
-      "body": [
-        "Earth dragon that walls you in, with Burrow Grubs at its side.",
-        "After every second turn of yours, Tharokh's marked tiles rise as Outcrops. At half Health they rise after each of your turns. Break through before the wall closes."
+      "lore": [
+        "An earth dragon so old that the Worldspine Roots grew around it. Its scales are slabs of bedrock.",
+        "Tharokh sends lines of breaking stone across the room, breathes a wave of Rubble and rakes anything in reach of its claws. The ground it Marks heaves up into Outcrops, and Burrow Grubs fight at its side."
@@ -66,3 +64,3 @@
-      "body": [
-        "Fire dragon that lays marked Fire, with Cinder Droplets that leave more of it.",
-        "When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions. At half Health its Fire spreads after every second Vyraketh turn. Crownfire detonates its own marked Fire, and its bite renews the marks."
+      "lore": [
+        "The fire dragon that rules the Cinder Crown. Its scales glow like banked coals.",
+        "Vyraketh rains cinders that Mark the floor and set it burning, breathes flame that spreads each fire to the tiles around it, and bites hard up close. Crownfire sets off its Marked fires at once, and Cinder Droplets fight at its side."
@@ -77,3 +75,3 @@
-      "body": [
-        "Air dragon that strikes from the sky and dives at you, with Gust Shrikes riding its wind.",
-        "After each Vaeloryx turn, its wind Pushes everyone 1 tile, then turns a quarter clockwise. At half Health it Pushes 2 tiles. Its retreating storm combines a wide ring with a weaker close bite."
+      "lore": [
+        "The wind dragon of the Hollow Gale, pale as cloud. Its wings never stop moving.",
+        "Vaeloryx hooks you from afar and drags you in, dives through anything in its path, and whips up wind that throws back everyone near it. Its Gust shoves each unit downwind after each of its turns, and Gust Shrikes fly at its side."
@@ -88,3 +86,3 @@
-      "body": [
-        "Ice dragon protected by visible Crystal Mantle layers, with Rime Spitters laying Ice around it.",
-        "When Iskaldra uses Rime Talon, Frostbite hits everyone on Ice for 3. At half Health, Frostbite hits after every second Iskaldra turn instead. Break Mantle layers to shrink Shatterstorm's reach."
+      "lore": [
+        "The ice dragon of the Rime Hall, armored in crystal that grows back as fast as it breaks.",
+        "Iskaldra wraps itself in layers of Crystal Mantle, lances the floor with Ice and claws at close range. Each layer widens Shatterstorm, Frostbite hurts each unit standing on Ice, and Rime Spitters fight at its side."
@@ -99,3 +97,3 @@
-      "body": [
-        "Shadow dragon and final boss of the twenty-fourth depth, with Veilbound Acolytes hiding in its darkness.",
-        "When Noctyrax uses Void Claw, hidden Veilbound Acolytes Blink 3 tiles toward you. Night Coil snuffs a brazier; enter its tile to relight it. Light blocks Eclipse's darkness."
+      "lore": [
+        "The dragon at the heart of the Umbra. Every shadow in the Labyrinth leans toward it.",
+        "Noctyrax drags you closer with coils of night that snuff out braziers, rakes with its claws and breathes darkness that ignores Block. Its Last Eclipse strikes Marked ground and then swallows the room in dark, and Veilbound Acolytes rise to fight beside it."
```
