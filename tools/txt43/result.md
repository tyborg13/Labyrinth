# txt-43 verification

`TXT43 AUDIT: 137 rows, 13 False, 0 UNTESTED` on `codex/txt-43` based on `8f6b5f918`. The txt-41 audit had 34 False and 1 UNTESTED. The remaining audit findings cover four force actions, seven Stormcoal relay exceptions, Groundsplit after an Outcrop dies, and Field Brace over Rubble. The implementation is uncommitted.

## Before and after

| Requirement | Before | After and witness |
| --- | --- | --- |
| 1. Fixed Push and Pull | The builder selected fixed wording by committed shape and printed `1 tiles`. Hooked Sweep, Hookwind, Razor Pinion, and Mourning Hook used the generic tooltip. | The builder accepts a stored force vector for any enemy shape and formats the singular. Night Coil showed `1 tile`, and a proof-only AoE with an explicit vector used the forward Push sentence. All four listed guardian actions had a declared orientation of `(1, 0)` and no force vector after commitment. Their source-relative copy stays in place. [Commitment](../../scripts/guardian_combat_rules.gd#L179) |
| 2. Range | `Maximum distance to the target in tiles, counted without diagonals.` | `How far this attack reaches in tiles, counted without diagonals.` Raking Flame uses the existing area sentence, `How far this attack reaches, in tiles, counted without diagonals.` Its broken line reached 4 tiles forward across 3 lanes. [Range check](../../scripts/combat_engine.gd#L4721) |
| 3. Lightning relay | `to a target within Range and line of sight.` | `to a target within Range and line of sight, or to a target on Electrified tiles connected to one in Range and line of sight.` All seven moves hit an out-of-Range hero from the nearer Electrified entry tile. A wall between the shooter and entry removed that route in each case. Stormcoal Crucible also enables Fire-only relays. In the Arc Bolt receipt, the entry changed from invalid to `(4, 4)` when the relic was added. [Relay entry](../../scripts/combat_engine.gd#L12818) · [Conductive ground](../../scripts/board_surface_rules.gd#L43) |
| 4. Marked | `Marked tiles show where this enemy acts on its next turn.` | `Marked tiles show where this enemy will act.` Thornwall retained 3 pending tiles until the Upheaval boundary. Groundsplit marked 22 tiles and still hit those 22 after the first Outcrop died. The surviving Outcrop accounts for 10 tiles. The hero at `(4, 3)` lay outside those 10 and lost 7 Health. The held branch of `live_tiles` takes precedence over `quake_tiles`. Removing those marks alone would hide real hits. [Held footprint](../../scripts/guardian_combat_rules.gd#L421) · [Pending Thornwall](../../scripts/enemy_mechanics/bramble.gd#L70) |
| 5. Shock | `Shocked units can only Move or Blink on their next turn.` | `Shocked units can't attack on their next turn.` Hero melee and enemy Arc Jab were blocked. The catalog action gate admitted Move, Blink, and Shock Cleanse in the fixture. [Hero legality](../../scripts/combat_engine.gd#L1161) · [Enemy turn status](../../scripts/combat_engine.gd#L8031) |
| 6. Burrow | `Burrowed enemies cannot be targeted.` | `You can't choose a Burrowed enemy as a target.` Melee, Ranged, Push, Pull, Swap, and Stagger could choose the unburied Grub. The buried Grub appeared in zero of those target lists. The live move uses the existing Burrow token whose glossary alias is Marked. [Targetability](../../scripts/enemy_mechanics/burrow.gd#L15) |
| 7. Lay the Choir | `Extends existing Electrified toward its target.` | `Lays Electrified tiles toward its target.` The resolver produced the full five-tile route in the adjacent-target fixture with empty ground. [Connector](../../scripts/guardian_combat_rules.gd#L698) |
| 8. Gust Shrike Dive | `Hits its path and the tiles next to it.` | `Hits each Marked tile.` Forecast and impact matched on 16 tiles with an open approach and 7 with the wall at `(4, 4)`. [Swept footprint](../../scripts/committed_pattern_shapes.gd) |
| 9. Razor Dive | `Range 1 of the dive trail behind this enemy`, a Range chip, and `Along approach +1`. | `Hits each Marked tile.` The Marked chip appears in the intent, and the two old chips are gone. Forecast and impact matched on 23 open and 19 interrupted tiles. [Held footprint](../../scripts/boss_area_rules.gd#L97) |
| 10. Skybreak | `This enemy hits random tiles.` | `This enemy hits each Marked tile.` The committed fixture resolved exactly the 9 announced tiles. [Lightning strikes](../../scripts/combat_engine.gd#L6886) |
| 11. Hollow Gale | `This enemy damages each unit within 2 tiles, then Pushes each unit hit 1 tile.` | `This enemy damages you and your Illusions on Marked tiles, then Pushes you 1 tile away.` Vaeloryx damaged the hero and Illusion. The ally was unharmed. The hero moved from `(2, 3)` to `(1, 3)`, and the Illusion stayed at `(4, 2)`. A wall also removed the hero's tile from the declaration in the cover fixture. [Enemy hit riders](../../scripts/combat_engine.gd#L4899) |
| 12. Gust | `On each Gust beat, each unit is Pushed downwind.` | `On each Gust beat, each unit that isn't Anchored or Burrowed is Pushed downwind.` The hero moved downwind and both the Anchored unit and Burrowed Grub stayed put. [Gust actors](../../scripts/battlefield_rules/gust.gd#L105) |
| 13. Field Brace | `Remove Shape Ground from your tile.` | `Clears the ground under the guarded unit.` The ally gained Block and lost Ice. Rubble remained under the ally, and Fire remained under the Surgeon. [Guard resolution](../../scripts/combat_engine.gd#L5040) · [Ground removal](../../scripts/board_surface_rules.gd#L118) |
| 14. Fade | `This enemy Blinks behind you, or to another adjacent tile, then Ambushes on this enemy’s next turn.` | `Blinks behind you, or to another tile next to you if there is room.` Open placement went behind to `(5, 4)`, a blocked rear tile sent the Stalker to `(4, 3)`, and a boxed hero left the Stalker at `(2, 4)`. The existing follow-up still resolves. [Destination](../../scripts/enemy_mechanics/stalker.gd#L22) |
| 15. Refraction | The catalog chip had no explicit offsets. The live board already built a four-tile diagram separately. | Both use the authored line from `pattern_line`. The chip, resolver and impact had four forward tiles, from `(3, 4)` to `(6, 4)`. [Resolver](../../scripts/enemy_mechanics/reflect.gd#L104) |
| 16. Rules lint | 16 baseline hits. | `PASS: Rules text lint (16 existing hits)`. The Python lint scans JSON. Manual review of the approved GDScript copy found Fade's `next to` under R14/R25 and Lay the Choir's unnamed `its` under R13. Gust's explicit exception crosses R10. The brief's exact copy takes precedence. |

## Open design items

- `TODO_DESIGN_fixed_force` covers the four named guardian moves. Making their direction fixed would change the resolver. Keep the existing Pull hover visible in the inspection capture.
- `TODO_DESIGN_groundsplit` covers the conflict between immediate mark removal and preserving the held hit footprint. The native fixture captures the existing post-destruction fight.
- `TODO_DESIGN_relay` covers the witnessed Stormcoal Crucible exception to Electrified-only relays. The seven standard tooltips use the approved line-of-sight variant.
- `TODO_DESIGN_field_brace_rubble` covers the distinction between clearing elemental ground and clearing the Rubble underlay. The tooltip uses the approved sentence.

## Receipts

| Proof | Observed result |
| --- | --- |
| Engine witness | `TXT43 WITNESS: PASS (baseline)` and `TXT43 WITNESS: PASS (current)`. These assert the observed engine paths, including the remaining design conflicts. [Before](../../output/txt43/witness-before.log) · [After](../../output/txt43/witness-after.log) |
| Grimoire and live catalogs | `TXT38 INVENTORY: PASS (44 creature pages, 137 move rows, 7 live controls)` and `TXT41 LIVE INVENTORY: PASS (137 Known Moves controls and combat intents)`. The overlay uses the txt-36 creature pages and current non-creature pages, as the worktree's production Grimoire has 18 creature pages. [After](../../output/txt43/after.log) · [Live](../../output/txt43/live-after.log) |
| Audit and widget export | `TXT43 AUDIT: 137 rows, 13 False, 0 UNTESTED`. `TXT43 LIVE COPY: PASS (approved sentences, Razor Dive chips, Refraction offsets)`. `TXT43 CARDS: PASS (309 catalog IDs, 9 source lists, byte-identical outside glossary hovers on 112 cards)`. The audit exits 1 while claims are open. [Log](../../output/txt43/audit.log) · [Full text diff and evidence](../../output/txt43/diff.md) |
| Godot copy fixtures | `TXT43 STRING FIXTURES: 352 checks, 0 failures` from `dragon_feedback1_suite.gd`, `en02_enemies_suite.gd`, and `sta01_mechanics_suite.gd`. `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)`. `MRK01 MARKED TEST: PASS (69 checks, 0 failures)`. [Copy suites](../../output/txt43/string-fixtures.log) · [Short card tooltips](../../output/txt43/short-card-tooltips.log) · [Marked](../../output/txt43/marked-test.log) |
| Guardian and dragon integration | `GUARDIAN RULES TEST RESULT: FAIL (693 checks, 1 failures)` on both the baseline and current sources. The existing `Choir badge text reads the authored linked-tile count` assertion still expects `linked tiles`. The baseline already renders `Up to 6 tiles`. The existing assertion was preserved. `Dragon committed patterns passed.` [Guardian baseline](../../output/txt43/guardian-rules-baseline.log) · [Guardian current](../../output/txt43/guardian-rules.log) · [Dragon](../../output/txt43/dragon-committed.log) |
| Python default | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 30.565s`, `OK`. Includes `test_short_card_tooltips.py`, `test_card_panel_text.py`, and the icon and rules-text checks. Tests completed before the runner reported `[Errno 1] Operation not permitted` writing the shared Git timing cache. [Log](../../output/txt43/python-default-final.log) |
| Lints | `PASS: Rules text lint (16 existing hits)`. UI identity `Ran 25 tests in 4.699s`, `OK`. [Rules](../../output/txt43/rules-text.log) · [UI](../../output/txt43/ui-identity.log) |
| Native dry run | `TXT43 NATIVE PROBE: PASS (headless, 4 capture states)`. All four embedded popups opened through GUI input. The headless paths in the log are planned PNG paths. [Dry run](../../output/txt43/native-dry-run.log) |

The macOS Godot certificate loader emitted `Condition "ret != noErr" is true. Returning: ""` during startup. The full Godot suite was outside the requested proof.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-43 && tools/txt43/native.sh
```

The windowed runner sets `LABYRINTH_CEL_LOOK=all` and checks its four images at 1920×1080, 100% UI scale. It prints each PNG path and records the contract result in `output/txt43/native.*/captures.json`.

- `output/txt43/native.*/arc_thrall_arc_bolt_1920x1080.png`
- `output/txt43/native.*/gallows_roc_hookwind_1920x1080.png`
- `output/txt43/native.*/vaeloryx_razor_dive_1920x1080.png`
- `output/txt43/native.*/craghide_after_outcrop_1920x1080.png`

## Chosen defaults

- Witnesses use the STA-01 arena and seed. The new fixture fields set relay entry distances, wall and actor positions, one-Health Outcrops, and a one-Health-damage test shot. The inherited Razor Dive fixture uses a 99-Health blocker.
- Native proof uses reduced motion, a 3 px pointer sample and inset, and the copied GFIX54 helper's 2-second popup timeout. The semantic image contract uses the same board region and luma thresholds as txt-41's board capture.

## Changed card hovers

- Range (108) · `anchor_slam`, `arc_flash`, `bone_dart`, `borrowed_spark`, `buffet`, `caltrops`, `chain_bolt`, `chain_catch`, `chain_lock`, `changing_winds`, `cinder_bloom`, `cinder_fusillade`, `cinder_second`, `cinder_wall`, `cinderburst`, `cinderline_tempo`, `clockwork_mark`, `cold_grasp`, `couched_lance`, `crack_the_whip`, `crosswind`, `dazzle`, `dull_bolt`, `dust_devil`, `ember_rain`, `ember_tithe`, `fan_of_knives`, `fan_the_flames`, `far_draw`, `firebrand_volley`, `flashsteam`, `forked_nock`, `frost_heave`, `frost_lane`, `frost_snare`, `frostbolt`, `glacier_pin`, `glacier_salts`, `grave_dust_satchel`, `guiding_flare`, `gust_step`, `headsmans_toll`, `hoarfrost_shell`, `hook_and_hold`, `hookspine_reap`, `hurl_spear`, `hush_of_winter`, `icebound_chains`, `icicle_lance`, `inferno_ritual`, `jaw_trap`, `jolt`, `kept_breath`, `kindle`, `lamp_oil`, `lantern_shot`, `lash`, `loaded_toss`, `locket_chill`, `lodestone_reversal`, `magma_vent`, `molten_reach`, `nail_bomb`, `pale_spark`, `petrify`, `pinning_quarrel`, `pitch_firebomb`, `plasma_arc`, `pyroclasm`, `razor_gale`, `refraction`, `ricochet_knife`, `rime_shard`, `rimefang`, `rimeplate_lock`, `rockburst`, `root_snare`, `royal_bramble`, `scorch`, `seek_the_light`, `shatter`, `shatterline`, `shiver_shot`, `skybreak_current`, `sleet_squall`, `snake_eyes`, `snare_coil`, `spark_dart`, `spark_focus`, `squall_shot`, `static_lash`, `storm_beacon`, `storm_jar`, `storm_relay`, `storm_salvo`, `stormstring_shot`, `sunlance`, `throwing_net`, `thunderline`, `undertow_guard`, `updraft`, `vacuum_line`, `volt_surge`, `wildfire_halo`, `wind_shear`, `windlass_volley`, `worldbreak`, `yank`
- Shock (9) · `frost_circuit`, `jolt`, `smelling_salts`, `static_lash`, `static_mantle`, `storm_jar`, `storm_relay`, `threadbare_guard`, `thunderline`
- Marked (0) · None
