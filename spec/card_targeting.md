# Card targeting contract and full-pool audit

Cards expose one board decision, or a targetless confirmation. A card can still have several ordered effects; automatic effects are never selectable steps. Selecting an enemy on a movement/attack card uses the existing automatic approach, while selecting floor commits movement alone. Flurry repeats reuse the chosen target.

Right-click anywhere in the unobstructed combat surface, Escape, and controller Back cancel an uncommitted selection without payment or effects. Once a card commits, its existing animation/payment lock remains authoritative. Targetless cards retain self-tile confirmation, second card click, controller Accept, and board drag release.

Numbered steps, Skip and the separate Cancel button are retired for every card, including resolution animations. Only optional Rotate and relic technique buttons can use the existing compact command host. Turn-end consequences remain in the established forecast ribbon, refreshed as the selected target changes.

Push/Pull accepts a visible enemy at any distance up to printed range (with line of sight past range 1) when the action does something to it: damage above zero, at least one tile of travel, or a collision. A zero-damage Pull on an enemy already beside the hero is therefore illegal, while a zero-damage Push on a pinned enemy is legal because it collides. The line itself follows [forced movement](forced_movement.md): an off-axis target offers two straight lines, the default is chosen automatically, and optional Rotate (keyboard left/right, controller LB/RB) switches lines without adding a board decision. Hover forecast and commit use the same aimed line. Walls, Umbra and the shared large-footprint targeting rule remain enforced.

## Card pool overhaul additions (wave 1)

- **Facing-aimed areas** (`"aim": "facing"`, range 1: Cleaver Sweep, Grave Cleave, Spear Thrust, Flame Jet). The player picks any adjacent visible floor tile, occupied or empty. The pattern is authored facing +x with offset `(0, 0)` on the chosen tile, and rotates to the cardinal direction from the hero to that tile; it is anchored on the chosen tile rather than centered on it. There is no Rotate button. `CombatEngine.aoe_tiles_for_player_action`, legality, hover preview and commit all derive the orientation from the same tile. A `surface_pattern` rider uses the same facing frame (Flame Jet leaves Fire only on `[2, 0]`). Physical facing areas use the melee swing and sound. Card chips draw the pattern from the hero.
- **Outcrops** (`{"type": "outcrop", "range": R, "health": H}`: Raise Stone, Geode, Plant Pavise, Raise the Anvil). One visible, in-sight tile within range. Each raised tile must be empty floor (`CombatTerrainRules.is_empty_floor`) and must keep every floor tile connected (`GuardianCombatRules.preserves_routes`); a tile that would seal any floor away is not offered. Outcrops are 3-health `crag_outcrop` terrain owned by the hero: they block movement and sight, can be attacked, and leave Rubble. `outcrop_tiles_for_player_action` also accepts an optional `pattern`/`rotate` (Earthen Rampart, wave 2): every legal pattern tile rises, re-checking routes after each one. A patterned, rotatable outcrop shares the area aim (`RunScene._action_uses_aoe_aim`): optional Rotate, keyboard left/right, controller LB/RB and board drag turn it without adding a board decision; hover highlights exactly the tiles that will rise for the current aim, and commit raises the same tiles (proof: `tests/earthen_rampart_rotate_probe.gd`).
- **Blink then required adjacent force** (Kestrel Dive, Spur Vault) is a supported one-click approach, like Move then a required melee/push/pull: clicking the enemy blinks next to it and resolves the push.
- **Range-0 Light** (Censer Swing, Sun Flash, Blessed Salve) targets only the hero's tile. Vision and Truesight never take a target.
- Authored `"_allow_sideways_force": true` (Crosswind) lets a push leave in any open cardinal direction, as the Quarry Winch mode does.

## Findings

The September 29 audit covered all 159 cards then authored (the inventory below is regenerated for the current pool): 31 with no targeted action, 112 with one targeted action, and 16 with a combined move/attack decision. The 96 cards with multiple effects could still recreate the legacy strip during resolution, even when their target input already completed in one click. A shared fix is needed; no card-stat or art rewrite is necessary.

Gust Step’s apparent range ring came from rejecting Pull targets with no legal displacement. An adjacent enemy cannot move onto the hero. The same legality check affected 15 authored force cards. Their damage can now resolve against blocked targets while displacement remains collision-limited. Gust Step keeps Move 1, damage 3, range 2, Pull 2 and Time 4. Its heuristic remains 2.71; full-pool scores are unchanged because the existing reach factors already model maximum range.

Defensive movement examples include Guarded Step, Warded Advance, Leather Roll, Dust Glide, Static Pivot, Zephyr Feint and Worldroot Stride; Blink/support examples include Shadow Step, Trapdoor, Shadow Gate, Gravewind Step and Voidsilk Molt. The shared interaction fix covers their automatic riders.

Peer review also caught the optional Worldroot origin-then-target flow and a targetless drag-cancel race. Worldroot now offers enemy targets directly and chooses the first legal origin in connected cardinal BFS order (nearest to the hero). Preview and resolution share the choice and Rubble payment; remote-only reach defaults to Worldroot so the card remains selectable. Right-click/Escape snapback revokes input and commit eligibility before animation, preventing a later left-release from playing the cancelled card. Worldroot’s range, damage and fuel cost remain unchanged.

## Design and UI proof

Surface: combat card targeting. Player question: which target/destination should receive this card? Primary action: one board click or supported controller/drag activation. Hierarchy: selected card and spatial consequences lead; optional aiming tools remain secondary; exact rules stay on cards/tooltips. Supported pointer, drag, keyboard and controller paths are preserved. Native proof uses 1920×1080, 100% UI scale; reduced motion and controller-to-pointer handoff are included.

| UI rubric gate | Result |
| --- | --- |
| Immediate comprehension | Pass: selected card, shared targeting arrow and valid board tiles identify the decision. |
| Visual hierarchy | Pass: no step strip or duplicate Cancel/Skip controls. |
| Gameplay visibility | Pass: board and actors remain clear; Rotate occupies the existing safe edge. |
| Compact precise copy | Pass: card rules and optional tool labels remain unchanged. |
| State and consequence | Pass: HP/defense, targets, turn order and forecast retain speculative/committed feedback. |
| Interaction completeness | Pass: every base card selects/cancels/completes; controller Back and pointer handoff, AOE rotation and existing drag paths are exercised. |
| Visual cohesion | Pass: existing card, board arrow, forecast and UiSkin buttons. |
| Accessibility | Pass: focus, shape/text cues and reduced motion preserved. |
| Layout resilience | Pass: inspected 1920×1080/100% frames. Existing controller hand tuck is retained; Focus Hand restores card detail. |
| Visual proof | Pass: thirteen native Metal frames, with semantic assertions and screenshot-region contracts. |

## Reproducible verification

Run from the isolated task checkout:

```sh
python3 tools/godot_task_runner.py --task-id card-targeting-audit --stream -- godot --headless --path . --script tests/card_targeting_audit_test.gd
python3 tools/godot_task_runner.py --task-id card-targeting-audit --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/godot_task_runner.py --task-id card-targeting-audit --stream -- godot --headless --path . --script tests/board_surface_presentation_test.gd
python3 tools/godot_task_runner.py --task-id card-targeting-audit --stream -- godot --headless --path . --script tests/forced_movement_query_equivalence_test.gd
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 90 --task-id card-targeting-audit --expect-size 1920x1080 --proof-contract tests/card_targeting_audit_probe_contract.json tests/card_targeting_audit_probe.gd
python3 -m unittest discover -s tests -p "test_card_heuristic*.py"
python3 tools/card_heuristic.py
python3 tools/card_targeting_inventory.py <printed user://card_targeting_audit.json path>
```

The focused suite invokes production selection/preview/input handlers for all cards and every target offered in its Clear fixture (October 1 rerun for the 305-card pool: 309 ids including 4 retired, 2,062 targets). Its host substitutes the final animation/save boundary with the normal payment resolver to keep the exhaustive run bounded; native proof separately executes actual commits, payment, analytics and animations. It also validates every generated action-add option (699 in the October 1 rerun; this is the compatibility upgrade API, since current meta-progression does not apply old numerical mods). Every damaging force card is tested from distance 1 through range+1; pure force and blocked LOS are negative witnesses. Existing full-suite tests cover Umbra, interrupted approaches, relic variants, drag and controller behavior. The force-query oracle has 6,260 comparisons under the corrected legality rule.

Artifacts: `output/card-targeting-audit/` (ignored, reproducible): `card-pool-audit.json`, `full-03.log`, `surface-02.log`, `force-query.log`, heuristic before/after logs, `native-06.json`, and `images-v4/`. Native snapshots cover Gust Step select/cancel/adjacent hit, Guarded Step select/all effects, optional Rotate, targetless confirmation, controller targeting with reduced motion, Back/pointer handoff, Flurry completion, automatic Worldroot origin/hit and drag-cancel release safety. Cancellations emit no `card_played`; a normal target commit emits exactly one.

Limitations: native runtime proof is macOS Metal; physical controller hardware and Windows execution are not claimed. Typed-array conventions are preserved. This is an interaction/correctness audit, not a new win-rate or performance calibration.

## Audited card inventory

Every row passes selection, cost-free right-click/Escape cancellation and one-click completion of every offered target in the audit fixture. The count is fixture-specific, not the card’s range or maximum number of possible targets.

<!-- card-inventory:start -->
Generated by `tools/card_targeting_inventory.py` from the audit JSON: 305 live cards (82 self confirmations, 223 with one board decision) and 2,012 exercised targets. The audit also replays the 4 retired ids (`bone_dart`, `ember_jab`, `cinderburst`, `gate_gambit`), which resolve to their replacements.

| Card | Effects | Board choice | Targets checked |
| --- | --- | --- | ---: |
| Quick Stab (`quick_stab`) | melee | One target | 1 |
| Guarded Step (`guarded_step`) | move, block, card_play | One target | 7 |
| Shadow Step (`shadow_step`) | blink, draw | One target | 16 |
| Pale Spark (`pale_spark`) | ranged | One target | 4 |
| Dull Bolt (`dull_bolt`) | ranged | One target | 4 |
| Waning Pulse (`waning_pulse`) | aoe | Self confirmation | 1 |
| Sidestep Slash (`sidestep_slash`) | move, melee | One target | 10 |
| Whirlwind Slash (`whirlwind_slash`) | aoe | Self confirmation | 1 |
| Patch Up (`patch_up`) | heal, block | Self confirmation | 1 |
| Bloody Lunge (`bloody_lunge`) | move, melee | One target | 10 |
| Brace (`brace`) | block | Self confirmation | 1 |
| Lantern Shot (`lantern_shot`) | ranged, draw | One target | 4 |
| Guiding Flare (`guiding_flare`) | ranged | One target | 21 |
| Dawnstep (`dawnstep`) | move, vision | One target | 13 |
| Prism Sight (`prism_sight`) | truesight, block, draw | Self confirmation | 1 |
| Storm Beacon (`storm_beacon`) | ranged | One target | 21 |
| Glowstone Ward (`glowstone_ward`) | stoneskin, illuminate | One target | 21 |
| Daybreak (`daybreak`) | dispel_umbra, draw, card_play | Self confirmation | 1 |
| Iron Wheel (`iron_wheel`) | move, melee | One target | 17 |
| Ricochet Knife (`ricochet_knife`) | ranged, draw | One target | 4 |
| Cleaver Sweep (`needle_flurry`) | aoe | One target | 4 |
| Warded Advance (`warded_advance`) | move, block | One target | 7 |
| Threaded Path (`threaded_path`) | move, draw | One target | 13 |
| Cinch Straps (`rallying_breath`) | block, draw | Self confirmation | 1 |
| Parry Rhythm (`battle_rhythm`) | block, retaliate, draw | Self confirmation | 1 |
| Reprise (`reprise`) | draw, block | Self confirmation | 1 |
| Blood Price (`blood_price`) | melee | One target | 1 |
| Trapdoor (`trapdoor`) | blink, block, vision | One target | 25 |
| Needle Thrust (`bodkin_arrow`) | melee | One target | 1 |
| Low Sweep (`hamstring_shot`) | move, melee | One target | 10 |
| Spur Trip (`hamstring_slice`) | move, melee | One target | 10 |
| Lantern Rain (`ember_rain`) | aoe | One target | 20 |
| Gravewind Gate (`shadow_gate`) | blink, next_attack | One target | 25 |
| Cyclone Seal (`cyclone_seal`) | force_area, aoe | One target | 19 |
| Glass Mending (`last_light`) | heal, stoneskin | Self confirmation | 1 |
| Coffin Brace (`grave_sprint`) | block, heal | Self confirmation | 1 |
| Firebrand Volley (`firebrand_volley`) | ranged | One target | 21 |
| Cinder Bloom (`cinder_bloom`) | aoe | One target | 11 |
| Hearth Rush (`hearth_rush`) | move, melee | One target | 11 |
| Cinderline Tempo (`cinderline_tempo`) | ranged, detonate | One target | 7 |
| Inferno Ritual (`inferno_ritual`) | aoe, detonate | One target | 11 |
| Molten Reach (`molten_reach`) | aoe | One target | 11 |
| Wildfire Halo (`wildfire_halo`) | aoe, detonate | One target | 11 |
| Frostbolt (`frostbolt`) | ranged | One target | 21 |
| Icebound Chains (`icebound_chains`) | ranged, truesight | One target | 4 |
| Rime Shard (`rime_shard`) | aoe | One target | 11 |
| Cold Grasp (`cold_grasp`) | melee | One target | 4 |
| Icicle Lance (`icicle_lance`) | ranged | One target | 4 |
| Hush of Winter (`hush_of_winter`) | ranged | One target | 4 |
| Shatterline (`shatterline`) | aoe | One target | 11 |
| Glacier Pin (`glacier_pin`) | aoe | One target | 11 |
| White Silence (`white_silence`) | all_enemies | Self confirmation | 1 |
| Spark Dart (`spark_dart`) | ranged | One target | 21 |
| Chain Bolt (`chain_bolt`) | ranged | One target | 4 |
| Spark Focus (`spark_focus`) | surface, draw, vision | One target | 21 |
| Static Lash (`static_lash`) | ranged | One target | 4 |
| Storm Relay (`storm_relay`) | ranged | One target | 4 |
| Volt Surge (`volt_surge`) | aoe | One target | 11 |
| Thunderline (`thunderline`) | aoe | One target | 11 |
| Gust Step (`gust_step`) | move, pull | One target | 7 |
| Slipstream Cut (`slipstream_cut`) | move, melee | One target | 10 |
| Updraft (`updraft`) | push | One target | 4 |
| Vacuum Line (`vacuum_line`) | pull, draw | One target | 4 |
| Squall (`squall_shot`) | aoe | One target | 20 |
| Skybreak Current (`skybreak_current`) | push | One target | 4 |
| Quarry Claw (`venom_claw`) | melee | One target | 5 |
| Stone Plate (`stone_plate`) | stoneskin, draw | Self confirmation | 1 |
| Quarry Step (`quarry_step`) | move, melee | One target | 11 |
| Thorn Skewer (`thorn_skewer`) | melee | One target | 1 |
| Root Snare (`root_snare`) | ranged | One target | 21 |
| Basalt Guard (`basalt_guard`) | illusion, block, stoneskin | One target | 16 |
| Grave Mortar (`grave_mortar`) | aoe | Self confirmation | 1 |
| Spike Mantle (`spike_mantle`) | aoe, consume_surface | Self confirmation | 1 |
| Tectonic Maul (`tectonic_maul`) | move, melee | One target | 11 |
| Cleaver Hack (`cleaver_hook`) | melee | One target | 1 |
| Riposte Lunge (`riposte_lunge`) | move, melee, retaliate | One target | 10 |
| Grave Cleave (`grave_cleave`) | aoe | One target | 4 |
| Kite Bash (`kite_bash`) | block, push | One target | 1 |
| Chain Catch (`chain_catch`) | pull, block | One target | 4 |
| Mirror Feint (`mirror_feint`) | illusion | One target | 4 |
| Leather Roll (`leather_roll`) | move, block | One target | 7 |
| Glassbone Guard (`glassbone_guard`) | stoneskin, draw | Self confirmation | 1 |
| Undertaker Stand (`undertaker_stand`) | block, retaliate | Self confirmation | 1 |
| Dust Skip (`dust_skip`) | blink, draw | One target | 7 |
| Spur Vault (`spur_vault`) | blink, push | One target | 10 |
| Gravewind Step (`gravewind_step`) | blink, block | One target | 16 |
| Ember Tithe (`ember_tithe`) | ranged, heal | One target | 12 |
| Clockwork Mark (`clockwork_mark`) | ranged, draw | One target | 4 |
| Unsealed Gale (`unsealed_gale`) | force_area | Self confirmation | 1 |
| Butcher Chop (`butcher_chop`) | melee | One target | 1 |
| Tombsplitter (`tombsplitter`) | aoe | One target | 4 |
| Chain Lock (`chain_lock`) | ranged, block | One target | 4 |
| Mirror Flash (`mirror_flash`) | illusion, block | One target | 7 |
| Dust Glide (`dust_glide`) | move, block | One target | 13 |
| Sawtooth Flurry (`sawtooth_flurry`) | melee, melee | One target | 1 |
| Serrated Slip (`serrated_slip`) | move, melee | One target | 10 |
| Backhand Nick (`backhand_nick`) | melee, draw | One target | 1 |
| Stormstring Shot (`stormstring_shot`) | ranged | One target | 30 |
| Forked Nock (`forked_nock`) | ranged | One target | 4 |
| Far Draw (`far_draw`) | surface, draw | One target | 21 |
| Hookspine Reap (`hookspine_reap`) | pull | One target | 4 |
| Sweeping Haft (`sweeping_haft`) | aoe | Self confirmation | 1 |
| Hook and Hold (`hook_and_hold`) | melee | One target | 4 |
| Phoenix Cleave (`phoenix_cleave`) | aoe, detonate | Self confirmation | 1 |
| Ember Guard (`ember_guard`) | block, surface | One target | 5 |
| Rekindle Edge (`rekindle_edge`) | melee, detonate | One target | 3 |
| Nail Parry (`nail_parry`) | block, melee | One target | 1 |
| Spike Check (`spike_check`) | block, retaliate | Self confirmation | 1 |
| Lodestone Reversal (`lodestone_reversal`) | pull, block | One target | 12 |
| Polar Guard (`polar_guard`) | block | Self confirmation | 1 |
| Witchglass Double (`witchglass_double`) | illusion, block, draw | One target | 16 |
| Reflected Threat (`reflected_threat`) | illusion | One target | 16 |
| Anchor Slam (`anchor_slam`) | stoneskin, pull | One target | 4 |
| Undertow Guard (`undertow_guard`) | block, pull | One target | 4 |
| Field Suture (`field_suture`) | heal, block | Self confirmation | 1 |
| Unpick (`threadbare_guard`) | cleanse, block, draw | Self confirmation | 1 |
| Cinderweave Guard (`cinderweave_guard`) | block, aoe | Self confirmation | 1 |
| Cinder Patch (`cinder_patch`) | heal, block | Self confirmation | 1 |
| Rimeplate Lock (`rimeplate_lock`) | stoneskin, block, ranged | One target | 12 |
| Hoarfrost Shell (`hoarfrost_shell`) | block, surface | One target | 12 |
| Voidsilk Molt (`voidsilk_molt`) | blink, draw | One target | 16 |
| Empty Husk (`empty_husk`) | illusion_swap | One target | 1 |
| Hobnail Drive (`hobnail_drive`) | move, push | One target | 10 |
| Heel Stomp (`heel_hook`) | move, melee | One target | 10 |
| Static Pivot (`static_pivot`) | move, block | One target | 13 |
| Spur Spark (`spur_spark`) | move, quicken | One target | 7 |
| Cloudstep Loop (`cloudstep_loop`) | blink | One target | 16 |
| Zephyr Feint (`zephyr_feint`) | move, draw, block | One target | 13 |
| Worldroot Stride (`worldroot_stride`) | move, stoneskin, surface | One target | 13 |
| Rooted Kick (`rooted_kick`) | move, push | One target | 11 |
| Loaded Toss (`loaded_toss`) | ranged, draw, card_play | One target | 4 |
| Snake Eyes (`snake_eyes`) | ranged, draw | One target | 4 |
| Locket Chill (`locket_chill`) | ranged | One target | 12 |
| Kept Breath (`kept_breath`) | block, draw, surface | One target | 12 |
| Borrowed Spark (`borrowed_spark`) | surface, draw, card_play | One target | 21 |
| Cinder Second (`cinder_second`) | block, detonate, draw | One target | 12 |
| Thorn Crown Pact (`thorn_crown_pact`) | rite | Self confirmation | 1 |
| Royal Bramble (`royal_bramble`) | pull | One target | 4 |
| Crimson Draught (`crimson_draught`) | heal | Self confirmation | 1 |
| Mossglass Elixir (`mossglass_elixir`) | heal, stoneskin | Self confirmation | 1 |
| Shrapnel Bomb (`nail_bomb`) | aoe | One target | 20 |
| Pitch Firebomb (`pitch_firebomb`) | aoe | One target | 11 |
| Frost Snare (`frost_snare`) | ranged | One target | 12 |
| Storm Jar (`storm_jar`) | ranged | One target | 4 |
| Smoke Bomb (`smoke_bomb`) | blink, block | One target | 7 |
| Jaw Trap (`jaw_trap`) | ranged | One target | 4 |
| Bone-Ward Charm (`bone_ward_charm`) | stoneskin, block | Self confirmation | 1 |
| Quarry Dust (`grave_dust_satchel`) | aoe | One target | 11 |
| Windlass Volley (`windlass_volley`) | aoe, aoe | One target | 20 |
| Crank Reload (`crank_reload`) | draw, card_play | Self confirmation | 1 |
| Blade Dance (`blade_dance`) | block, melee, block, melee | One target | 1 |
| Gathering Rhythm (`gathering_rhythm`) | move, draw, card_play | One target | 7 |
| Cinder Fusillade (`cinder_fusillade`) | ranged, ranged | One target | 21 |
| Storm Salvo (`storm_salvo`) | ranged, draw, ranged, draw | One target | 4 |
| Razor Gale (`razor_gale`) | ranged, ranged | One target | 4 |
| Beacon (`beacon`) | illuminate, draw | One target | 30 |
| Bitter Tonic (`bitter_tonic`) | draw, card_play | Self confirmation | 1 |
| Blessed Salve (`blessed_salve`) | heal, illuminate | One target | 1 |
| Break the Veil (`break_the_veil`) | dispel_umbra, draw | Self confirmation | 1 |
| Buffet (`buffet`) | push | One target | 4 |
| Caltrops (`caltrops`) | aoe | One target | 11 |
| Censer Swing (`censer_swing`) | aoe, illuminate | One target | 1 |
| Cinder Wall (`cinder_wall`) | surface, block | One target | 12 |
| Cold Shoulder (`cold_shoulder`) | push | One target | 1 |
| Crosswind (`crosswind`) | push | One target | 4 |
| Fan of Knives (`fan_of_knives`) | aoe | One target | 11 |
| Flame Jet (`flame_jet`) | aoe | One target | 4 |
| Frost Lane (`frost_lane`) | surface, draw | One target | 21 |
| Frost Nova (`frost_nova`) | aoe, surface | Self confirmation | 1 |
| Geode (`geode`) | outcrop, stoneskin | One target | 7 |
| Glacier Salts (`glacier_salts`) | surface | One target | 21 |
| Haft Shove (`haft_shove`) | push | One target | 1 |
| Hoarfrost Wall (`hoarfrost_wall`) | block, surface | Self confirmation | 1 |
| Hurricane Palm (`hurricane_palm`) | push | One target | 1 |
| Incense Haze (`incense_haze`) | truesight, block | Self confirmation | 1 |
| Jolt (`jolt`) | ranged | One target | 4 |
| Kestrel Dive (`kestrel_dive`) | blink, push | One target | 20 |
| Kindle (`kindle`) | surface, draw | One target | 21 |
| Lamp Oil (`lamp_oil`) | surface | One target | 21 |
| Lash (`lash`) | pull | One target | 4 |
| Mirror Charm (`mirror_charm`) | illusion | One target | 16 |
| Pinning Quarrel (`pinning_quarrel`) | ranged | One target | 4 |
| Plant Pavise (`plant_pavise`) | outcrop, block | One target | 3 |
| Quarry Plating (`quarry_plating`) | stoneskin, surface | Self confirmation | 1 |
| Raise Stone (`raise_stone`) | outcrop, draw | One target | 16 |
| Raise the Anvil (`raise_the_anvil`) | outcrop, stoneskin | One target | 3 |
| Rime Hack (`rime_hack`) | melee | One target | 5 |
| Scorch (`scorch`) | ranged | One target | 4 |
| Seeker's Mark (`seekers_mark`) | truesight, draw | Self confirmation | 1 |
| Seer's Candle (`seers_candle`) | truesight, vision | Self confirmation | 1 |
| Shield Charge (`shield_charge`) | move, push | One target | 10 |
| Shiver Shot (`shiver_shot`) | ranged | One target | 4 |
| Snare Coil (`snare_coil`) | pull | One target | 4 |
| Spear Thrust (`spear_thrust`) | aoe | One target | 4 |
| Straw Double (`straw_double`) | illusion, draw | One target | 3 |
| Sun Flash (`sun_flash`) | block, illuminate | One target | 1 |
| Thunderclap (`thunderclap`) | aoe, surface | Self confirmation | 1 |
| Unhorse (`unhorse`) | push | One target | 1 |
| Vigil (`vigil`) | block, vision | Self confirmation | 1 |
| Yank (`yank`) | pull | One target | 4 |
| Arc Flash (`arc_flash`) | ranged | One target | 4 |
| Barbed Mail (`barbed_mail`) | block, retaliate | Self confirmation | 1 |
| Blinding Bash (`blinding_bash`) | melee | One target | 1 |
| Brace the Spear (`brace_the_spear`) | block, retaliate | Self confirmation | 1 |
| Bristle (`bristle`) | stoneskin, retaliate | Self confirmation | 1 |
| Capacitor (`capacitor`) | block, next_attack | Self confirmation | 1 |
| Charged Orb (`charged_orb`) | quicken, next_attack | Self confirmation | 1 |
| Couched Lance (`couched_lance`) | melee | One target | 4 |
| Crack the Whip (`crack_the_whip`) | melee | One target | 4 |
| Crushing Blow (`crushing_blow`) | melee | One target | 1 |
| Dazzle (`dazzle`) | ranged | One target | 4 |
| Deflect (`deflect`) | block, retaliate | Self confirmation | 1 |
| Earthen Rampart (`earthen_rampart`) | outcrop, stoneskin | One target | 10 |
| Eye of the Storm (`eye_of_the_storm`) | block, retaliate | Self confirmation | 1 |
| Flowing Step (`flowing_step`) | move | One target | 7 |
| Galvanize (`galvanize`) | draw, quicken | Self confirmation | 1 |
| Hallowed Strike (`hallowed_strike`) | melee | One target | 1 |
| Headlong (`headlong`) | move, next_attack | One target | 20 |
| Hourglass Sand (`hourglass_sand`) | quicken, draw | Self confirmation | 1 |
| Hurl Spear (`hurl_spear`) | ranged | One target | 4 |
| Main-Gauche (`main_gauche`) | melee | One target | 1 |
| Mirror Image (`mirror_image`) | illusion, draw | One target | 16 |
| Overclock (`overclock`) | draw, card_play | Self confirmation | 1 |
| Overhead Smash (`overhead_smash`) | melee | One target | 1 |
| Palm Blade (`palm_blade`) | melee | One target | 1 |
| Palm Strike (`palm_strike`) | melee | One target | 1 |
| Rimefang (`rimefang`) | ranged | One target | 4 |
| Rite of Hoarfrost (`rite_of_hoarfrost`) | rite | Self confirmation | 1 |
| Rite of Noon (`rite_of_noon`) | rite | Self confirmation | 1 |
| Rite of Tailwinds (`rite_of_tailwinds`) | rite | Self confirmation | 1 |
| Rite of the Mountain (`rite_of_the_mountain`) | rite | Self confirmation | 1 |
| Rite of the Pyre (`rite_of_the_pyre`) | rite | Self confirmation | 1 |
| Rite of the Storm (`rite_of_the_storm`) | rite | Self confirmation | 1 |
| Salamander Heart (`salamander_heart`) | rite | Self confirmation | 1 |
| Static Mantle (`static_mantle`) | block, retaliate | Self confirmation | 1 |
| Static Rush (`static_rush`) | move, quicken | One target | 7 |
| Stolen Moment (`stolen_moment`) | quicken, draw | Self confirmation | 1 |
| Stonefist (`stonefist`) | melee | One target | 1 |
| Stonewall Stance (`stonewall_stance`) | stoneskin | Self confirmation | 1 |
| Sunlance (`sunlance`) | ranged | One target | 4 |
| Sworn Oath (`sworn_oath`) | block, next_attack | Self confirmation | 1 |
| Tempest Form (`tempest_form`) | rite | Self confirmation | 1 |
| Throwing Net (`throwing_net`) | ranged | One target | 4 |
| Tremor (`tremor`) | aoe | Self confirmation | 1 |
| Whetstone (`whetstone`) | next_attack | Self confirmation | 1 |
| Wind Shear (`wind_shear`) | aoe | One target | 11 |
| Ball Lightning (`ball_lightning`) | illusion | One target | 16 |
| Bottled Gale (`bottled_gale`) | force_area | Self confirmation | 1 |
| Catch the Wind (`catch_the_wind`) | move | One target | 13 |
| Changing Winds (`changing_winds`) | swap | One target | 4 |
| Cinder Trail (`cinder_trail`) | self_flag, move | One target | 13 |
| Crystal Mantle (`crystal_mantle`) | mantle | Self confirmation | 1 |
| Discharge (`discharge`) | discharge | One target | 1 |
| Doppelganger (`doppelganger`) | illusion | One target | 16 |
| Dust Devil (`dust_devil`) | force_area | One target | 1 |
| Ember Ward (`ember_ward`) | block, surface_adjacent_enemies | Self confirmation | 1 |
| Fan the Flames (`fan_the_flames`) | push | One target | 4 |
| Fault Strike (`fault_strike`) | melee | One target | 5 |
| Flash Powder (`flash_powder`) | aoe | One target | 20 |
| Flashsteam (`flashsteam`) | aoe | One target | 20 |
| Frost Circuit (`frost_circuit`) | convert_surface | One target | 1 |
| Frost Heave (`frost_heave`) | ranged | One target | 1 |
| Frozen Bite (`frozen_bite`) | melee | One target | 1 |
| Gale Ward (`gale_ward`) | block, force_area | Self confirmation | 1 |
| Glide (`glide`) | move | One target | 13 |
| Grapple (`grapple`) | blink | One target | 10 |
| Grounding (`grounding`) | consume_surface | Self confirmation | 1 |
| Hall of Mirrors (`hall_of_mirrors`) | illusion, block | Self confirmation | 1 |
| Headsman's Toll (`headsmans_toll`) | ranged | One target | 4 |
| Hoarfrost Ward (`hoarfrost_ward`) | block, surface_adjacent_enemies | Self confirmation | 1 |
| Hotfoot (`hotfoot`) | move | One target | 7 |
| Ice Sculpture (`ice_sculpture`) | illusion | One target | 16 |
| Immolation (`immolation`) | detonate | Self confirmation | 1 |
| Joust (`joust`) | move, melee | One target | 8 |
| Magma Vent (`magma_vent`) | detonate | One target | 1 |
| Meteorfall (`meteorfall`) | meteor_marks | One target | 29 |
| Petrify (`petrify`) | petrify | One target | 4 |
| Plasma Arc (`plasma_arc`) | ranged | One target | 4 |
| Powder Keg (`powder_keg`) | outcrop | One target | 7 |
| Pyroclasm (`pyroclasm`) | ranged | One target | 4 |
| Refraction (`refraction`) | ranged | One target | 4 |
| Revealing Glare (`revealing_glare`) | all_enemies, draw | Self confirmation | 1 |
| Rime Step (`rime_step`) | move, surface_adjacent_enemies | One target | 7 |
| Rockburst (`rockburst`) | burst_terrain | One target | 1 |
| Rooted Stance (`rooted_stance`) | stoneskin, self_flag | Self confirmation | 1 |
| Searing Light (`searing_light`) | all_enemies | Self confirmation | 1 |
| Seek the Light (`seek_the_light`) | blink | One target | 3 |
| Shatter (`shatter`) | ranged | One target | 4 |
| Shatter Swing (`shatter_swing`) | melee | One target | 1 |
| Shattered Reflection (`shattered_reflection`) | destroy_illusion | One target | 1 |
| Shield Wall (`shield_wall`) | block, self_flag | Self confirmation | 1 |
| Shrug Off (`shrug_off`) | convert_block_to_stoneskin, draw | Self confirmation | 1 |
| Skate (`skate`) | self_flag, move | One target | 13 |
| Skybolt (`skybolt`) | ranged | One target | 4 |
| Sleet Squall (`sleet_squall`) | push, ranged | One target | 4 |
| Smelling Salts (`smelling_salts`) | cleanse, move | One target | 7 |
| Static Ward (`static_ward`) | block, surface_adjacent_enemies | Self confirmation | 1 |
| Stoke (`stoke`) | all_enemies | Self confirmation | 1 |
| Stone Ward (`stone_ward`) | block, surface_adjacent_enemies | Self confirmation | 1 |
| Sunpath Stride (`sunpath_stride`) | move | One target | 20 |
| Thunderstone (`thunderstone`) | ranged | One target | 4 |
| Vortex (`vortex`) | force_area | One target | 15 |
| Windbreak (`windbreak`) | block, self_flag | Self confirmation | 1 |
| Worldbreak (`worldbreak`) | burst_terrain | One target | 1 |
| Worldspine (`worldspine`) | outcrop | One target | 20 |
<!-- card-inventory:end -->
