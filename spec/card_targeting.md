# Card targeting contract and full-pool audit

Cards expose one board decision, or a targetless confirmation. A card can still have several ordered effects; automatic effects are never selectable steps. Selecting an enemy on a movement/attack card uses the existing automatic approach, while selecting floor commits movement alone. Flurry repeats reuse the chosen target.

Right-click anywhere in the unobstructed combat surface, Escape, and controller Back cancel an uncommitted selection without payment or effects. Once a card commits, its existing animation/payment lock remains authoritative. Targetless cards retain self-tile confirmation, second card click, controller Accept, and board drag release.

Numbered steps, Skip and the separate Cancel button are retired for every card, including resolution animations. Only optional Rotate and relic technique buttons can use the existing compact command host. Turn-end consequences remain in the established forecast ribbon, refreshed as the selected target changes.

Push/Pull accepts a visible enemy at any distance up to printed range (with line of sight past range 1) when the action does something to it: damage above zero, at least one tile of travel, or a collision. A zero-damage Pull on an enemy already beside the hero is therefore illegal, while a zero-damage Push on a pinned enemy is legal because it collides. The line itself follows [forced movement](forced_movement.md): an off-axis target offers two straight lines, the default is chosen automatically, and optional Rotate (keyboard left/right, controller LB/RB) switches lines without adding a board decision. Hover forecast and commit use the same aimed line. Walls, Umbra and the shared large-footprint targeting rule remain enforced.

## Findings

The September 29 audit covered all 159 authored cards: 31 with no targeted action, 112 with one targeted action, and 16 with a combined move/attack decision. The 96 cards with multiple effects could still recreate the legacy strip during resolution, even when their target input already completed in one click. A shared fix is needed; no card-stat or art rewrite is necessary.

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
```

The focused suite invokes production selection/preview/input handlers for all cards and all 1,274 targets offered in its Clear fixture. Its host substitutes the final animation/save boundary with the normal payment resolver to keep the exhaustive run bounded; native proof separately executes actual commits, payment, analytics and animations. It also validates 349 generated action-add options (the compatibility upgrade API; current meta-progression does not apply old numerical mods). Every damaging force card is tested from distance 1 through range+1; pure force and blocked LOS are negative witnesses. Existing full-suite tests cover Umbra, interrupted approaches, relic variants, drag and controller behavior. The force-query oracle has 6,260 comparisons under the corrected legality rule.

Artifacts: `output/card-targeting-audit/` (ignored, reproducible): `card-pool-audit.json`, `full-03.log`, `surface-02.log`, `force-query.log`, heuristic before/after logs, `native-06.json`, and `images-v4/`. Native snapshots cover Gust Step select/cancel/adjacent hit, Guarded Step select/all effects, optional Rotate, targetless confirmation, controller targeting with reduced motion, Back/pointer handoff, Flurry completion, automatic Worldroot origin/hit and drag-cancel release safety. Cancellations emit no `card_played`; a normal target commit emits exactly one.

Limitations: native runtime proof is macOS Metal; physical controller hardware and Windows execution are not claimed. Typed-array conventions are preserved. This is an interaction/correctness audit, not a new win-rate or performance calibration.

## Audited card inventory

Every row passes selection, cost-free right-click/Escape cancellation and one-click completion of every offered target in the audit fixture. The count is fixture-specific, not the card’s range or maximum number of possible targets.

| Card | Effects | Board choice | Targets checked |
| --- | --- | --- | ---: |
| Quick Stab (`quick_stab`) | melee | One target | 1 |
| Guarded Step (`guarded_step`) | move, block, card_play | One target | 8 |
| Shadow Step (`shadow_step`) | blink, draw | One target | 17 |
| Pale Spark (`bone_dart`) | ranged | One target | 3 |
| Pale Spark (`pale_spark`) | ranged | One target | 3 |
| Dull Bolt (`dull_bolt`) | ranged | One target | 3 |
| Waning Pulse (`waning_pulse`) | aoe | Self confirmation | 1 |
| Sidestep Slash (`sidestep_slash`) | move, melee | One target | 10 |
| Whirlwind Slash (`whirlwind_slash`) | aoe | Self confirmation | 1 |
| Patch Up (`patch_up`) | heal, block | Self confirmation | 1 |
| Bloody Lunge (`bloody_lunge`) | move, melee | One target | 10 |
| Brace (`brace`) | block | Self confirmation | 1 |
| Measured Cut (`ember_jab`) | melee, draw | One target | 1 |
| Lantern Shot (`lantern_shot`) | ranged, draw | One target | 3 |
| Guiding Flare (`guiding_flare`) | ranged | One target | 12 |
| Dawnstep (`dawnstep`) | move, vision | One target | 15 |
| Prism Sight (`prism_sight`) | truesight, block, draw | Self confirmation | 1 |
| Storm Beacon (`storm_beacon`) | ranged | One target | 21 |
| Glowstone Ward (`glowstone_ward`) | stoneskin, illuminate | One target | 21 |
| Daybreak (`daybreak`) | dispel_umbra, draw, card_play | Self confirmation | 1 |
| Iron Wheel (`iron_wheel`) | move, melee | One target | 18 |
| Ricochet Knife (`ricochet_knife`) | ranged, draw | One target | 3 |
| Cleaver Sweep (`needle_flurry`) | aoe | Self confirmation | 1 |
| Warded Advance (`warded_advance`) | move, block | One target | 8 |
| Threaded Path (`threaded_path`) | move, draw | One target | 15 |
| Cinch Straps (`rallying_breath`) | block, draw | Self confirmation | 1 |
| Parry Rhythm (`battle_rhythm`) | block, draw | Self confirmation | 1 |
| Shrapnel Burst (`cinderburst`) | aoe | One target | 20 |
| Reprise (`reprise`) | draw, block | Self confirmation | 1 |
| Blood Price (`blood_price`) | melee | One target | 1 |
| Trapdoor (`trapdoor`) | blink, block, vision | One target | 26 |
| Needle Thrust (`bodkin_arrow`) | melee | One target | 1 |
| Low Sweep (`hamstring_shot`) | move, melee | One target | 10 |
| Spur Trip (`hamstring_slice`) | move, melee | One target | 10 |
| Lantern Rain (`ember_rain`) | aoe | One target | 20 |
| Gravewind Gate (`shadow_gate`) | blink, block | One target | 17 |
| Force Seal (`cyclone_seal`) | aoe | One target | 20 |
| Glass Mending (`last_light`) | heal, stoneskin | Self confirmation | 1 |
| Coffin Brace (`grave_sprint`) | block, heal | Self confirmation | 1 |
| Gate Gambit (`gate_gambit`) | draw, card_play, block | Self confirmation | 1 |
| Firebrand Volley (`firebrand_volley`) | ranged | One target | 21 |
| Cinder Bloom (`cinder_bloom`) | aoe | One target | 11 |
| Hearth Rush (`hearth_rush`) | move, melee | One target | 11 |
| Cinderline Tempo (`cinderline_tempo`) | ranged, detonate | One target | 6 |
| Inferno Ritual (`inferno_ritual`) | aoe, detonate | One target | 11 |
| Molten Reach (`molten_reach`) | aoe | One target | 11 |
| Wildfire Halo (`wildfire_halo`) | aoe, detonate | One target | 11 |
| Frostbolt (`frostbolt`) | ranged | One target | 21 |
| Icebound Chains (`icebound_chains`) | ranged, truesight | One target | 3 |
| Rime Shard (`rime_shard`) | aoe | One target | 11 |
| Cold Grasp (`cold_grasp`) | melee | One target | 3 |
| Icicle Lance (`icicle_lance`) | ranged | One target | 3 |
| Hush of Winter (`hush_of_winter`) | ranged, draw | One target | 3 |
| Shatterline (`shatterline`) | aoe | One target | 11 |
| Glacier Pin (`glacier_pin`) | aoe | One target | 11 |
| White Silence (`white_silence`) | ranged | One target | 3 |
| Spark Dart (`spark_dart`) | ranged | One target | 21 |
| Chain Bolt (`chain_bolt`) | ranged | One target | 3 |
| Spark Focus (`spark_focus`) | surface, draw, vision | One target | 21 |
| Static Lash (`static_lash`) | ranged | One target | 3 |
| Storm Relay (`storm_relay`) | ranged | One target | 3 |
| Volt Surge (`volt_surge`) | aoe | One target | 11 |
| Thunderline (`thunderline`) | aoe | One target | 11 |
| Gust Step (`gust_step`) | move, pull | One target | 6 |
| Slipstream Cut (`slipstream_cut`) | move, melee | One target | 10 |
| Updraft (`updraft`) | push | One target | 3 |
| Vacuum Line (`vacuum_line`) | pull, draw | One target | 3 |
| Squall Shot (`squall_shot`) | aoe | One target | 11 |
| Skybreak Current (`skybreak_current`) | ranged | One target | 3 |
| Quarry Claw (`venom_claw`) | melee | One target | 5 |
| Stone Plate (`stone_plate`) | stoneskin, draw | Self confirmation | 1 |
| Quarry Step (`quarry_step`) | move, melee | One target | 11 |
| Thorn Skewer (`thorn_skewer`) | melee | One target | 1 |
| Root Snare (`root_snare`) | ranged | One target | 12 |
| Basalt Guard (`basalt_guard`) | illusion, block, stoneskin | One target | 17 |
| Grave Mortar (`grave_mortar`) | aoe | Self confirmation | 1 |
| Spike Mantle (`spike_mantle`) | aoe, consume_surface | Self confirmation | 1 |
| Tectonic Maul (`tectonic_maul`) | move, melee | One target | 8 |
| Cleaver Hook (`cleaver_hook`) | push | One target | 1 |
| Riposte Lunge (`riposte_lunge`) | move, melee, block | One target | 10 |
| Grave Cleave (`grave_cleave`) | aoe | Self confirmation | 1 |
| Kite Bash (`kite_bash`) | block, push | One target | 1 |
| Chain Catch (`chain_catch`) | pull, block | One target | 3 |
| Mirror Feint (`mirror_feint`) | illusion, block | One target | 17 |
| Leather Roll (`leather_roll`) | move, block | One target | 8 |
| Glassbone Guard (`glassbone_guard`) | stoneskin, draw | Self confirmation | 1 |
| Undertaker Stand (`undertaker_stand`) | block, stoneskin | Self confirmation | 1 |
| Dust Skip (`dust_skip`) | blink, draw | One target | 17 |
| Spur Vault (`spur_vault`) | move, push | One target | 10 |
| Gravewind Step (`gravewind_step`) | blink, block | One target | 17 |
| Ember Tithe (`ember_tithe`) | ranged, heal | One target | 12 |
| Clockwork Mark (`clockwork_mark`) | ranged, draw | One target | 3 |
| Unsealed Gale (`unsealed_gale`) | aoe | One target | 20 |
| Butcher Chop (`butcher_chop`) | melee | One target | 1 |
| Tombsplitter (`tombsplitter`) | aoe | Self confirmation | 1 |
| Chain Lock (`chain_lock`) | ranged, block | One target | 3 |
| Mirror Flash (`mirror_flash`) | illusion, block | One target | 8 |
| Dust Glide (`dust_glide`) | move, block | One target | 15 |
| Sawtooth Flurry (`sawtooth_flurry`) | melee | One target | 1 |
| Serrated Slip (`serrated_slip`) | move, melee | One target | 10 |
| Backhand Nick (`backhand_nick`) | melee, draw | One target | 1 |
| Stormstring Shot (`stormstring_shot`) | ranged | One target | 30 |
| Forked Nock (`forked_nock`) | ranged | One target | 3 |
| Far Draw (`far_draw`) | surface, draw | One target | 21 |
| Hookspine Reap (`hookspine_reap`) | pull | One target | 3 |
| Sweeping Haft (`sweeping_haft`) | aoe | Self confirmation | 1 |
| Hook and Hold (`hook_and_hold`) | melee | One target | 3 |
| Phoenix Cleave (`phoenix_cleave`) | aoe, detonate | Self confirmation | 1 |
| Ember Guard (`ember_guard`) | block, surface | One target | 5 |
| Rekindle Edge (`rekindle_edge`) | melee, detonate | One target | 3 |
| Nail Parry (`nail_parry`) | block, melee | One target | 1 |
| Spike Check (`spike_check`) | block, push | One target | 1 |
| Lodestone Reversal (`lodestone_reversal`) | pull, block | One target | 12 |
| Polar Guard (`polar_guard`) | block | Self confirmation | 1 |
| Witchglass Double (`witchglass_double`) | illusion, block, draw | One target | 17 |
| Reflected Threat (`reflected_threat`) | illusion, block | One target | 17 |
| Anchor Slam (`anchor_slam`) | stoneskin, pull | One target | 3 |
| Undertow Guard (`undertow_guard`) | block, pull | One target | 3 |
| Field Suture (`field_suture`) | heal, block | Self confirmation | 1 |
| Threadbare Guard (`threadbare_guard`) | block, draw | Self confirmation | 1 |
| Cinderweave Guard (`cinderweave_guard`) | block, aoe | Self confirmation | 1 |
| Cinder Patch (`cinder_patch`) | heal, block | Self confirmation | 1 |
| Rimeplate Lock (`rimeplate_lock`) | stoneskin, block, ranged | One target | 12 |
| Hoarfrost Shell (`hoarfrost_shell`) | block, surface | One target | 12 |
| Voidsilk Molt (`voidsilk_molt`) | blink, block, draw | One target | 26 |
| Empty Husk (`empty_husk`) | illusion, block | One target | 17 |
| Hobnail Drive (`hobnail_drive`) | move, push | One target | 10 |
| Heel Hook (`heel_hook`) | move, melee | One target | 10 |
| Static Pivot (`static_pivot`) | move, block | One target | 15 |
| Spur Spark (`spur_spark`) | move | One target | 8 |
| Cloudstep Loop (`cloudstep_loop`) | blink, draw | One target | 17 |
| Zephyr Feint (`zephyr_feint`) | move, draw, block | One target | 15 |
| Worldroot Stride (`worldroot_stride`) | move, stoneskin, surface | One target | 15 |
| Rooted Kick (`rooted_kick`) | move, push | One target | 11 |
| Loaded Toss (`loaded_toss`) | ranged, draw, card_play | One target | 3 |
| Snake Eyes (`snake_eyes`) | ranged, draw | One target | 3 |
| Locket Chill (`locket_chill`) | ranged | One target | 12 |
| Kept Breath (`kept_breath`) | block, draw, surface | One target | 12 |
| Borrowed Spark (`borrowed_spark`) | surface, draw, card_play | One target | 21 |
| Cinder Second (`cinder_second`) | block, detonate, draw | One target | 12 |
| Thorn Crown Pact (`thorn_crown_pact`) | stoneskin, ranged | One target | 3 |
| Royal Bramble (`royal_bramble`) | pull | One target | 3 |
| Crimson Draught (`crimson_draught`) | heal | Self confirmation | 1 |
| Mossglass Elixir (`mossglass_elixir`) | heal, stoneskin | Self confirmation | 1 |
| Nail Bomb (`nail_bomb`) | aoe | One target | 11 |
| Pitch Firebomb (`pitch_firebomb`) | aoe | One target | 11 |
| Frost Snare (`frost_snare`) | ranged | One target | 12 |
| Storm Jar (`storm_jar`) | ranged | One target | 3 |
| Smoke Bomb (`smoke_bomb`) | blink, block | One target | 8 |
| Jaw Trap (`jaw_trap`) | ranged | One target | 3 |
| Bone-Ward Charm (`bone_ward_charm`) | stoneskin, block | Self confirmation | 1 |
| Quarry Dust (`grave_dust_satchel`) | aoe | One target | 11 |
| Windlass Volley (`windlass_volley`) | aoe, aoe | One target | 20 |
| Crank Reload (`crank_reload`) | draw, card_play | Self confirmation | 1 |
| Blade Dance (`blade_dance`) | block, melee, block, melee | One target | 1 |
| Gathering Rhythm (`gathering_rhythm`) | move, draw, card_play | One target | 8 |
| Cinder Fusillade (`cinder_fusillade`) | ranged, ranged | One target | 21 |
| Storm Salvo (`storm_salvo`) | ranged, draw, ranged, draw | One target | 3 |
| Razor Gale (`razor_gale`) | ranged, ranged | One target | 3 |
