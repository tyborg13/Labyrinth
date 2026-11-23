# fx-33 implementation and proof

## Base inventory

The inventory follows the presentation dispatches from authored cards, intents and battlefield rules at `0d3ccfd26`. An action can reach more than one row.

| Action or rule | Element | Base presentation and ownership |
| --- | --- | --- |
| `ember_tick` death, including an enemy-phase kill or a Kindle bonus | Fire | The resolver journals one cross per death. Ordinary defeats call `DeathBurstView.decorate`; traced enemy cascades use `deferred_death_view.gd` and `BurstFx.decorate`. Both submit a death-only `TileGlow`, puffs through `_puff/_sprite`, and a ribbon through `_ribbon`. |
| `ember_hoarder` death, including a Kindle bonus | Fire | Its authored `death_burst` trait uses the same journal and painters. Snare dissolves suppress the rule itself. These are the only two authored death-Burst types. |
| `chain_bolt`, `storm_relay`, and electrically conducted Lightning attacks | Lightning | The opening shot uses the normal ranged route. Later airborne contacts can be Spark, with existing fx-27 tile bursts on ordinary hops. The board also submits `ChainAttackFx.draw_hop`, with a routed polyline and endpoint caps plus ribbon/glow fallbacks. Relay-only hops and grouped conduction are distinct resolver beats. The floor pass draws resolver paths of at least two tiles through `PixelFxLayer.line`. |
| Lightning ranged attacks | Lightning | Authored candidates are `storm_beacon`, `spark_dart`, `chain_bolt`, `static_lash`, `storm_relay`, `stormstring_shot`, `forked_nock`, `storm_jar`, `storm_salvo`, `jolt`, `arc_flash`, `plasma_arc`, `skybolt`, `thunderstone`, `lightning_wisp:static_lash`, `lightning_wisp:blinding_arc`, `bell_tender:staff_bolt`, and `arc_thrall:arc_bolt`. The retained Shot route suppresses the board travel/release/ground/impact painter when selected. Owned fallback contact functions reach `impact → _storm → _glow/_sparks/_bolt`. |
| `storm_capacitor:discharge` | Lightning | Its own adapter submits the actor-to-actor `kind=chain` painter without a Spark hop index. State merges and floating numbers land after its timed loop. The resolver uses adjacency for later hops with no floor path. |
| Battlefield `lightning_storm` | Lightning | Baked primary sky strike. The current rule explicitly disables Chain and conduction, so the staged rule playback’s legacy air-hop branch has no live authored caller. The Electrified field is the primary footprint. |
| `immolation` and other Detonate cards | Fire, Ice, Earth, Air or Lightning | Ground-area fallbacks reach depth `impact` and floor `ground`. The existing fx-12 Detonate route supplies the tiles and schedules contact. Authored candidates are `cinderline_tempo`, `inferno_ritual`, `wildfire_halo`, `phoenix_cleave`, `rekindle_edge`, `cinder_second`, `flashsteam`, `immolation`, `magma_vent`, `pyroclasm`, `dust_devil`, `frost_heave`, `plasma_arc`, `shatter`, and `shatter_swing`. `immolation` also retains Fire surface-consumption feedback. |
| Ranged elemental areas | Fire, Ice, Earth, Air or Lightning | The owned depth and floor fallback functions support all five styles. Existing fx-12/fx-17 contact specs own these areas. Authored non-dragon ranged areas include `cinder_bloom`, `inferno_ritual`, `molten_reach`, `wildfire_halo`, `pitch_firebomb`, `flame_jet`, `flashsteam`, `magma_vent`, `rime_shard`, `shatterline`, `glacier_pin`, `volt_surge`, `thunderline`, `thunderclap`, `squall_shot`, `wind_shear`, `grave_dust_satchel`, and `caltrops`. Dragon spell areas have their separate fx-18 schedule. |
| `root_snare`, `briar_weaver:lash_of_thorns`, and other Earth projectile fallback paths | Earth | Travel fragments and sparks use the Earth spike path owned by fx-32. The target has its own fx-17 contact plan. Preview and clipped flight share the legacy travel helpers. |
| `lodestone_reversal` and other force fallback paths | Lightning, Fire and other styled elements | The owned contact/performance, ground/scene and release delegates are shared with fx-32's travel/force painters. The force `TileGlow` and collision handling belong to fx-32. |
| `zekarion:skybreak` | Lightning | `_draw_dragon_area_depth → draw_source → release → _ribbon` adds setup geometry before the baked sky strike. `present_sky_strike` already owns the falling sheet and impact. |

## Round 1 implementation

| Decision | Result |
| --- | --- |
| 1. Chain openings | The resolved primary tile uses the Lightning row at the same contact sample as the health and number updates. A step-local reservation lets an existing contact own the tile and lets a later return relay light the same tile on its own beat. Chain Bolt, Storm Relay and Storm Salvo have explicit proof cases. |
| 2. Conducted contacts | The chain player submits every target in the resolver's grouped conduction beat at its existing contact. Spark Dart exercises the conducted victim. The floor line uses the same depth pass, path, alpha and stroke functions. |
| 3. Capacitor discharge | The retained Spark uses the existing discharge window for each resolved hop. The cutout adapter still supplies its pose, sounds, completion and number publication. The tile burst lands on the damage-number frame. Reduced motion shows the authored still on that frame. |
| 4. Direct Capacitor kill | Base shows the Tick's lethal hit and the Burst loss in the same hop's number submission. That sample starts the Fire cross. The cross owns its visible tiles on the shared sample, including the defeated Tick's tile. A later hop on another sample can still land Lightning on a cross arm. |
| 5. Hidden-source traced Burst | The anonymous board receipt retains the existing feedback clock. A private callback carries the actual origin and publishes the visible tiles after the board updates its visibility. The hidden centre receives no stamp. |
| 6. Painter cleanup | Removed the airborne board dispatch, `chain_attack_fx.gd` and its UID, and the unused pixel-bound case. The old GPU proof drops the three legacy airborne line images and retains the floor-conduction, Lightning, line-width and alpha cases. |

The Fire crosses, their puff, ribbon and wash removal, and the Skybreak setup from the previous round are unchanged. `burst_fx.gd` still owns the legacy Burst feedback duration and has focused proof callers. The old ranged contact and release delegates still have fx-32 callers. The retained elemental library still serves surface layers, dragon presentation and the legacy Earth travel path. Tick glow, Kindle body feedback, dissolve, hover wash, Skybreak release glows and the Electrified floor line retain their existing presentation.

For authored floor paths, the existing twelve-sample chain beat has nine samples where `0 < progress < 0.8` before quantization and none in reduced motion. Spark Dart provides the retained floor-line witness. Its route contains a path of four cells. Chain Bolt and Storm Relay's wider Electrified fixtures use air relay beats. Capacitor has a private adjacency chain, and the room `lightning_storm` rule explicitly disables Chain and conduction.

## Contact samples

Frames are relative to the start of each 60 Hz take. Rear and front rows start together, so the table lists each tile once. Falling sheets are recorded separately in `take.json`.

| Take | Tile burst rows and start frames |
| --- | --- |
| `tick` | `steel_hit` at 13 on 4:3 · `fire_hit` at 50 on 4:3 · `fire_floor` at 52 on 4:2, 3:3 · `fire_hit` at 52 on 5:3, 4:4 |
| `tick_reduced` | `steel_hit` at 0 on 4:3 · `fire_hit` at 33 on 4:3, 5:3, 4:4 · `fire_floor` at 33 on 4:2, 3:3 |
| `kindled_tick` | `steel_hit` at 114 on 4:3 · `fire_hit` at 151 on 4:3 · `fire_floor` at 153 on 4:2, 3:3 · `fire_hit` at 153 on 5:3, 4:4 |
| `kindled_tick_reduced` | `steel_hit` at 35 on 4:3 · `fire_hit` at 68 on 4:3, 5:3, 4:4 · `fire_floor` at 68 on 4:2, 3:3 |
| `hoarder` | `steel_hit` at 13 on 4:3 · `fire_hit` at 50 on 4:3 · `fire_floor` at 52 on 4:2, 3:3 · `fire_hit` at 52 on 5:3, 4:4 |
| `hoarder_reduced` | `steel_hit` at 0 on 4:3 · `fire_hit` at 33 on 4:3, 5:3, 4:4 · `fire_floor` at 33 on 4:2, 3:3 |
| `enemy_kill` | `fire_hit` at 64 on 4:3 · `fire_floor` at 73 on 4:2, 3:3, 5:3 · `fire_hit` at 73 on 4:4 · `lightning_hit` at 79 on 4:4 |
| `enemy_kill_reduced` | `fire_hit` at 21 on 4:3, 4:4 · `fire_floor` at 21 on 4:2, 3:3, 5:3 |
| `warden_trap` | `impact_hit` at 98 on 4:3, 3:4 · `impact_floor` at 98 on 5:4, 4:5 · `fire_floor` at 98 on 4:2, 3:3, 5:3 · `fire_hit` at 98 on 4:4 · `fire_hit` at 133 on 4:3 · `fire_floor` at 136 on 4:2, 3:3, 5:3 · `fire_hit` at 136 on 4:4 |
| `warden_trap_reduced` | `impact_hit` at 22 on 4:3, 3:4 · `impact_floor` at 22 on 5:4, 4:5 · `fire_floor` at 22 on 4:2, 3:3, 5:3 · `fire_hit` at 22 on 4:4 · `fire_hit` at 63 on 4:3, 4:4 · `fire_floor` at 63 on 4:2, 3:3, 5:3 |
| `hidden` | `steel_hit` at 13 on 4:3 · `fire_hit` at 50 on 4:3 · `fire_hit` at 52 on 4:4 |
| `hidden_reduced` | `steel_hit` at 0 on 4:3 · `fire_hit` at 33 on 4:3, 4:4 |
| `hidden_trace` | `fire_hit` at 7 on 3:4 |
| `hidden_trace_reduced` | `fire_hit` at 0 on 3:4 |
| `chain_bolt` | `lightning_hit` at 18 on 6:4 · `lightning_hit` at 44 on 6:5 · `lightning_hit` at 62 on 5:5 |
| `chain_bolt_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_hit` at 8 on 6:5 · `lightning_hit` at 16 on 5:5 |
| `storm_salvo` | `lightning_hit` at 18 on 6:4 · `lightning_hit` at 44 on 6:5 · `lightning_hit` at 62 on 5:5 |
| `storm_salvo_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_hit` at 8 on 6:5 · `lightning_hit` at 16 on 5:5 |
| `chain_conduction` | `lightning_hit` at 18 on 6:4 · `lightning_hit` at 44 on 6:5 · `lightning_floor` at 59 on 6:4 · `lightning_floor` at 67 on 6:2 · `lightning_hit` at 78 on 6:1 |
| `chain_conduction_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_hit` at 8 on 6:5 · `lightning_floor` at 16 on 6:4 · `lightning_floor` at 22 on 6:2 · `lightning_hit` at 28 on 6:1 |
| `spark_conduction` | `lightning_hit` at 18 on 6:4 · `lightning_hit` at 44 on 6:1 |
| `spark_conduction_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_hit` at 8 on 6:1 |
| `storm_relay` | `lightning_hit` at 18 on 6:4 · `lightning_hit` at 44 on 6:5 · `lightning_floor` at 59 on 6:4 · `lightning_floor` at 67 on 6:2 · `lightning_hit` at 78 on 6:1 |
| `storm_relay_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_hit` at 8 on 6:5 · `lightning_floor` at 16 on 6:4 · `lightning_floor` at 22 on 6:2 · `lightning_hit` at 28 on 6:1 |
| `capacitor` | `lightning_hit` at 64 on 4:3 · `lightning_hit` at 77 on 4:4 · `lightning_hit` at 92 on 5:4 |
| `capacitor_reduced` | `lightning_hit` at 21 on 4:3, 4:4, 5:4 |
| `skybreak` | `lightning_floor` at 64 on 1:1, 1:2, 2:1, 1:3, 2:2, 3:1, 1:4, 2:3, 1:5 |
| `skybreak_reduced` | `lightning_floor` at 21 on 1:1, 1:2, 2:1, 1:3, 2:2, 3:1, 1:4, 2:3, 1:5 |
| `lightning_storm` | `lightning_hit` at 5 on 4:4 |
| `lightning_storm_reduced` | `lightning_hit` at 0 on 4:4 |
| `immolation` | `fire_floor` at 10 on 5:4 · `fire_floor` at 18 on 5:3, 4:4, 5:5 · `fire_hit` at 18 on 6:4 |
| `immolation_reduced` | `fire_floor` at 0 on 5:4, 5:3, 4:4, 5:5 · `fire_hit` at 0 on 6:4 |
| `root_snare` | `earth_hit` at 28 on 6:4 |
| `root_snare_reduced` | `earth_hit` at 0 on 6:4 |
| `thorn_lash` | `earth_hit` at 42 on 4:4 |
| `thorn_lash_reduced` | `earth_hit` at 21 on 4:4 |
| `lodestone_reversal` | `lightning_hit` at 21 on 6:4 · `lightning_hit` at 31 on 5:4 |
| `lodestone_reversal_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_hit` at 17 on 5:4 |
| `volt_surge` | `lightning_hit` at 18 on 6:4 · `lightning_floor` at 24 on 5:4, 7:4 |
| `volt_surge_reduced` | `lightning_hit` at 0 on 6:4 · `lightning_floor` at 0 on 5:4, 7:4 |
| `recording` | `steel_hit` at 13 on 4:3 · `fire_hit` at 50 on 4:3 · `fire_floor` at 52 on 4:2, 3:3, 5:3 · `fire_hit` at 52 on 4:4 · `lightning_hit` at 157 on 6:4 · `lightning_hit` at 183 on 6:5 · `lightning_hit` at 201 on 5:5 |

The three-target discharge lands at frames 64, 77 and 92. The visible Spark windows are 55–63, 64–76 and 77–91. In reduced motion, the existing clock publishes all three at frame 21 with no flight. The direct kill publishes the Fire centre on frame 64, or frame 21 in reduced motion. The resolved receipt on that sample reports both the lethal 1 Health loss and the hero's 4 Health Burst loss. The visible arm of the hidden-source case submits on frame 0, first shows on frame 7, and shows immediately on frame 0 in reduced motion.

Spark Dart's floor line has 14 progress-active samples and 11 floor painter frames in both builds. Its after take has 8 quantized stroke frames. The reduced-motion takes submit no floor line. Skybreak's 225 full-motion and 126 reduced-motion strike samples still match base.

## Verification

The full dry run produced 41 base/current comparisons at `0d3ccfd26`. All action durations, contact samples, per-frame floating texts, actor durability, health-bar ghosts, and retained sky-strike samples matched. The verifier retained the previous contact and per-tile assertions. The final result was `FX-33 VERIFY PASS (2262 checks, 0 failures)`. [Full log](/private/tmp/labyrinth_codex/fx-33/round-1/logs/full-proof.log)

| Check | Exact result |
| --- | --- |
| fx-12 | `FX-12 VERIFY: 120 checks, 0 failures`, `TEST RESULT: PASS` |
| fx-17 | `FX-17 VERIFY: 132 checks, 0 failures`, `TEST RESULT: PASS` |
| fx-18 | `FX-18 FOCUSED PASS (0 failures)`. The original historical overlay still fails to parse the retired Acolyte and Bile Bloomer paths and obsolete surface calls. The current sweep reports `FX-18 CURRENT FAIL (2 failures)`, the same Skyhook visible-set and contact assertions reproduced at exact base. |
| fx-27 | `FX-27 VERIFY: PASS (164 checks, 0 failures)` |
| Burst and Kindle | `BRS01 FOCUSED RESULT: PASS (4854 checks; 0 failures)`, `BRS02 FOCUSED RESULT: PASS (442 checks; 0 failures)` |
| Chain, conduction, and enemy suites | `FX-33 FOCUSED chain_attack PASS`, `FX-33 FOCUSED battlefield_conduction PASS`, `FX-33 FOCUSED en01_enemies PASS`, `FX-33 FOCUSED en06_enemies PASS`, `FX-33 FOCUSED hoarder PASS`, `FX-33 VERIFY PASS (8088 checks, 0 failures)`, and `EN06 ENEMIES TEST RESULT: PASS (135 checks, 0 failures)` |
| GDScript and static validation | 14 `--check-only` scripts, shell syntax, Python syntax, visual contract sizes and `git diff --check` pass. |
| Python default | `Ran 194 tests in 48.060s` and `OK`. The optional shared timing cache write was denied by read-only Git metadata. |

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-33 && /private/tmp/labyrinth_codex/fx-33/native.sh
```

The launcher uses the visual probe runner and the 60 fps MovieWriter clock with a 1920×1080 SubViewport, HUD, 100% UI scale, and `LABYRINTH_CEL_LOOK=all`. Before/after outputs for Tick, Chain Bolt, Storm Relay, Capacitor and Spark Dart go under `/private/tmp/labyrinth_codex/fx-33/native/{before,after}/<case>/`. Each take prints its absolute directory and writes `strip.png`, `native-evidence.png`, `take.json` and `manifest.json`. The Tick strip keeps the hit followed by Burst contact and +100, +233 and +366 ms. The three-column strips use contact, +100 and +233 ms. Capacitor uses its first damage-number sample and Spark Dart uses its conducted victim's contact. The after-only silent 360-frame reel is `/private/tmp/labyrinth_codex/fx-33/native/ember-tick-then-chain-bolt.mp4`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-33 && FX33_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-33/round-1 /private/tmp/labyrinth_codex/fx-33/native.sh --dry-run
```

The dry run wrote `/private/tmp/labyrinth_codex/fx-33/round-1/headless/{before,after}/<case>/take.json` and printed the output paths. Both builds selected Tick frames `13, 50, 56, 64, 72`, Chain Bolt and Storm Relay `18, 24, 32`, Capacitor `64, 70, 78`, and Spark Dart conduction `44, 50, 58`. Both reel plans cover 360 frames. The before projects read changed game sources from exact base and the current project instruments only temporary copies.

The updated historical pixel proof can also run on the desktop.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-33 && python3 tools/visual_probe_runner.py tests/pixel_fx_render_probe.gd --task-id fx-33 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/pixel_fx_render_probe_contract.json
```

## Chosen defaults and open issues

Proof-only defaults are defined in `cases.gd` and `native_capture.gd`. The fixture uses the inherited seed, normal combat speed, 30 hero Health and 20 Block in the blocked Tick case. The direct kill uses a 1 Health Tick. Capacitor starts at full authored Charge and its third discharge target is at `5:4`. The hidden trace places the source at `3:3`, witness at `3:4`, and hero at `3:5` in Eclipse. The strips crop 640×480 per sample and the reel uses a 0.45 s proof pause between cards. The capture timeout is 300 seconds.

No `TODO_DESIGN_*` placeholders. The code and headless proof are complete. The desktop PNGs, GPU pixel proof and MP4 encoding still require windowed execution. Changes are uncommitted.
