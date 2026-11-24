# pol-83 tooltip inventory

Base `e3b27e209`. Each row lists the tooltip input once per screen and names the controls or moves that use it. `@pattern` is existing diagram markup. Percent placeholders identify values interpolated by production at runtime.

Sources include the live CardWidget export (309 catalog IDs, including hand and legacy projections), the production combat and pre-battle move builders (44 creature IDs and 137 authored moves), and the tooltip owners and data for the other screens. The focused check and hover probe use real tooltip panels.

## Cards

Native chip hovers can appear on the live CardWidget wherever its native hover is enabled, including combat, card rewards, item and gear previews, and the Grimoire’s card previews. The icon-led card focus stack names each panel explicitly.

The card rows show the numbers exported for the catalog, hand and legacy presentations. A live projection can substitute its current values in the same copy, for example the Health cost, Meteorfall damage, Outcrop Health or the reach of a diagram.

| Tooltip input | Where |
| --- | --- |
| `@pattern(hollow_diamond:1:origin) Push each enemy on these tiles 1 tile away from you.` | gale_ward |
| `@pattern(hollow_diamond:1:origin) Push each enemy on these tiles 3 tiles away from you.` | bottled_gale |
| `@pattern(hollow_diamond:2:origin) Pull each enemy on these tiles 2 tiles toward the chosen tile.` | vortex |
| `@pattern(hollow_diamond:3:origin) Push each enemy on these tiles 3 tiles away from you.` | unsealed_gale |
| `@pattern(neighbors:origin) Create 1 Illusion on each empty tile adjacent to you.` | hall_of_mirrors |
| `@pattern(neighbors:origin) Each empty tile adjacent to the Illusion.` | ice_sculpture |
| `Add 2 Time to your next turn.` | chain_bolt, mirror_image, overhead_smash, shatterline, tremor, wind_shear |
| `Any of your illusions on the board.` | empty_husk |
| `Area: the pattern shows which tiles this card hits.` | borrowed_spark, caltrops, censer_swing, cinder_bloom, cinder_wall, cinderburst, cinderweave_guard, cyclone_seal, dust_devil, earthen_rampart, ember_rain, fan_of_knives, fault_strike, flame_jet, flashsteam, frost_lane, frost_nova, glacier_pin, glacier_salts, grave_cleave, grave_dust_satchel, grave_mortar, hoarfrost_shell, hoarfrost_wall, immolation, inferno_ritual, lamp_oil, meteorfall, molten_reach, nail_bomb, needle_flurry, phoenix_cleave, pitch_firebomb, rime_shard, shatterline, spark_focus, spear_thrust, spike_mantle, squall_shot, sweeping_haft, tectonic_maul, thunderclap, thunderline, tombsplitter, tremor, volt_surge, waning_pulse, whirlwind_slash, wildfire_halo, wind_shear, windlass_volley, worldspine |
| `Choose a tile within this range.` | cyclone_seal, frost_circuit, shattered_reflection, vortex |
| `Choose an Electrified tile within Range and line of sight.` | discharge |
| `Choose an enemy within Range.` | mirror_feint |
| `Continues the action above.` | ball_lightning, fan_the_flames, glacier_pin, grapple, grave_dust_satchel, headlong, headsmans_toll, meteorfall, mirror_feint, refraction |
| `Deal +1 damage for each Stoneskin you have, up to +6.` | stonefist |
| `Deal +1 damage per tile you moved this turn, up to +5.` | couched_lance, iron_wheel |
| `Enemies that damage this Illusion gain Shock.` | ball_lightning |
| `Enemies that damage this Illusion take 4 damage and gain Shock once per enemy attack.` | ball_lightning |
| `Gain 1 Block for each tile you Move.` | catch_the_wind |
| `Give your Block to the Illusion as extra Health.` | empty_husk |
| `Leave an Illusion with 4 Health on the tile you left.` | voidsilk_molt |
| `Leaves this ground under each adjacent enemy and on your tile.` | static_ward |
| `Leaves this ground under each adjacent enemy.` | ember_guard, ember_ward, stone_ward |
| `Lose 1 Health after the card resolves.` | bloody_lunge, overclock, royal_bramble |
| `Lose 2 Health after the card resolves.` | blood_price |
| `Next turn before you Draw, deal 8 damage and leave Fire on each Marked tile.` | meteorfall |
| `Only a Lightning card uses this bonus.` | capacitor, charged_orb |
| `Place the Illusion on the open tile adjacent to the target that is nearest you.` | mirror_feint |
| `Place the Illusion within Range.` | ball_lightning, basalt_guard, doppelganger, ice_sculpture, mirror_charm, mirror_flash, mirror_image, reflected_threat, straw_double, witchglass_double |
| `Place the Outcrop within Range.` | earthen_rampart, geode, plant_pavise, raise_stone, raise_the_anvil |
| `Push 2 in any open direction.` | crosswind |
| `Raise an Outcrop with 3 Health that blocks movement and line of sight.` | earthen_rampart, geode, plant_pavise, raise_stone, raise_the_anvil |
| `Remove Fire from your tile.` | cinder_patch |
| `The chosen enemy is Exposed 3.` | mirror_feint |
| `The destination must be adjacent to an enemy, Outcrop or crate.` | grapple |
| `This attack also hits each other enemy adjacent to one of your Illusions once.` | refraction |
| `This bonus applies if the target is Immobilized.` | spear_thrust |
| `This bonus applies if the target is Shocked.` | jolt |
| `This bonus applies if the target's next turn is Staggered.` | hobnail_drive |
| `This card Exhausts after resolving.` | cinder_bloom, earthen_rampart, hurl_spear |
| `Turn your Block into Stoneskin.` | shrug_off |
| `While this Illusion lasts, your ranged attacks can come from this Illusion's tile.` | doppelganger |

## Combat enemy chips

| Tooltip input | Where |
| --- | --- |
| `@pattern(diamond:2) Enter the brazier's tile to relight the brazier and restore Light on these tiles.` | wick_shade / Snuff |
| `Both braziers relight after this move.` | last_lamplighter / Last Procession |
| `Deal 5 damage on the central tile and 3 damage on each adjacent tile.` | slag_mortar / Lob Slag |
| `Deal 7 damage on each central tile and 5 damage on each adjacent tile.` | Slagmaster / Lob Slag |
| `Each remaining layer adds 1 range, up to 4. Break layers to shrink the warning; Shatterstorm spends the rest.` | iskaldra / Shatterstorm, iskaldra / Shatterstorm (half Health) |
| `Extends existing Electrified toward its target.` | bell_tender / Join the Choir, storm_cantor / Lay the Choir |
| `Forms Crystal Mantle. Each direct damaging hit breaks one layer and prevents its damage; ground and damage over time bypass it.` | iskaldra / Crystal Mantle, iskaldra / Crystal Mantle (half Health) |
| `Grants Block to every other living enemy.` | warden / Bulwark |
| `Hits every tile within this distance of its path.` | gust_shrike / Dive, vaeloryx / Razor Dive, vaeloryx / Razor Dive (half Health) |
| `Its Burst deals 2 more.` | ember_hoarder / Kindle |
| `Lasts until Last Procession, including a skipped turn.` | last_lamplighter / Snuff |
| `Night Coil puts out the Marked brazier. Enter that brazier's tile to relight the brazier before Eclipse.` | noctyrax / Night Coil |
| `No valid support target.` | briar_weaver / Root Mend, grave_surgeon / Triage Suture |
| `On each Lightning Storm beat, when Zekarion uses Overload, each unit on Electrified takes 6 damage.` | zekarion / Overload |
| `On each Lightning Storm beat, when Zekarion uses Overload, each unit on Electrified takes 7 damage.` | zekarion / Overload (half Health) |
| `On each Lightning Storm beat, when the Cantor uses Peal, each unit on Electrified takes 4 damage.` | storm_cantor / Peal |
| `Remove Ice from your tile.` | frostglass_lancer / Refract Guard |
| `Remove Shape Ground from your tile.` | grave_surgeon / Field Brace |
| `Support target: Glacial Mirror.` | glacial_mirror / Crystal Guard |
| `Support target: Grave Surgeon.` | grave_surgeon / Field Brace |
| `This enemy Bursts each surviving Worldspine.` | tharokh / Faultline, tharokh / Faultline (half Health) |
| `This enemy Bursts the Fire on each tile from this enemy's last Cinder Marks.` | vyraketh / Crownfire, vyraketh / Crownfire (half Health) |
| `This enemy hits each floor tile within the shown distance of a surviving Outcrop.` | craghide / Groundsplit |
| `This enemy hits random tiles.` | zekarion / Skybreak, zekarion / Skybreak (half Health) |
| `This enemy hits you and your illusions on Marked tiles, then starts Eclipse for 2 turns.` | noctyrax / Last Eclipse |
| `This enemy leaves Fire on each Marked tile.` | vyraketh / Cinder Maw, vyraketh / Cinder Maw (half Health), vyraketh / Meteorfall, vyraketh / Meteorfall (half Health) |

- `Support target: %s.` uses the current selected ally name for Crystal Guard, Field Brace, Triage Suture, Root Mend and other single-target support rows. The table shows the target names seen in the single-actor fixtures.

- The Groundsplit chip on this base reads `Each Outcrop · within 2`. The separate txt-43 capture uses `Within 2 tiles of each Outcrop` and the hover `Hits each Marked tile.`. The native probe uses the matching live Groundsplit chip and preserves the wording of whichever revision supplies it.
- The generic enemy `raise_terrain` builder has `This enemy raises terrain in the shown area.` and `Health of each terrain piece.`. Both meet the rule. This base has no authored enemy move with that action type. Current Outcrop encounters use other action types or battlefield rules.

## Pre-battle enemy inspection

| Tooltip input | Where |
| --- | --- |
| `Its Burst deals 2 more.` | ember_hoarder / Kindle |

Trait rows with a plain tooltip include the following. The Cinder Ooze Splits and Ember Tick Burst rows resolve to their source-matched loops.

| Tooltip input | Where |
| --- | --- |
| `@pattern(cross:origin) When this enemy dies, this enemy Bursts 4, leaving Fire.` | Ember Hoarder Burst trait |
| `@pattern(diamond:2) Followers on these tiles deal +1 damage.` | Warband captain Command trait |
| `Anchored units can't be moved by Push, Pull or Gust.` | Gale Herald and Gallows Roc Anchored trait |
| `Takes half Stagger.` | Steadfast trait for Tharokh, Vyraketh, Vaeloryx, Iskaldra, Noctyrax and Zekarion |
| `This enemy is immune to Immobilize.` | Vaeloryx Immune trait |
| `This enemy is immune to Shock.` | Zekarion Immune trait |

## Combat HUD and board controls

| Tooltip input | Where |
| --- | --- |
| `Choose Electrified, then select a highlighted tile.` | Shape Ground selector |
| `Choose Elemental layer, then select a highlighted tile.` | Shape Ground relocation selector |
| `Choose Fire, then select a highlighted tile.` | Shape Ground selector |
| `Choose Ice, then select a highlighted tile.` | Shape Ground selector |
| `Choose Rubble, then select a highlighted tile.` | Shape Ground selector |
| `Objective threshold · Reach this tile to clear the encounter.` | Reach the Exit objective marker |
| `The Hoarder slips away with its hoard after your 4th turn.` | Ember Hoarder battlefield HUD, tiers 2 and 3 |
| `The Hoarder slips away with its hoard after your 5th turn.` | Ember Hoarder battlefield HUD, tier 1 |
| `This enemy creates Gust. Gust ends when this enemy dies.` | Gale Herald Gust status chip |
| `Use Rubble for this card's Detonate, leaving Fire behind.` | Crush Rubble aim control for the prior-impact follow-up |
| `Whenever your Ice card Staggers an enemy on Ice, you can move that Ice to an adjacent tile.` | Spill Ice aim control with Rimecatcher Vial |

The Card Plays meter, Undo Move button and risk panel use native Godot labels. The Pass forecast uses its dedicated panel.

### Battlefield beats on the initiative rail

The rail uses a single line when the rule copy needs no diagram rewrite. The left column includes the rule name as production supplies it.

| Tooltip input | Where |
| --- | --- |
| `Frostbite — On each Frostbite beat, after every second Iskaldra turn, each unit on Ice takes 3 damage.` | iskaldra (half Health) |
| `Frostbite — On each Frostbite beat, after every second Oracle turn, each unit on Ice takes 2 damage.` | oracle |
| `Frostbite — On each Frostbite beat, after your turn, each unit on Ice takes 1 damage.` | snare_ice |
| `Frostbite — On each Frostbite beat, after your turn, each unit on Ice takes Stagger 6.` | rimejaw |
| `Frostbite — On each Frostbite beat, when Iskaldra uses Rime Talon, each unit on Ice takes 3 damage.` | iskaldra |
| `Gust — On each Gust beat, after Vaeloryx's turn, each unit is Pushed 1 tile downwind, then Gust turns a quarter clockwise.` | vaeloryx |
| `Gust — On each Gust beat, after Vaeloryx's turn, each unit is Pushed 2 tiles downwind, then Gust turns a quarter clockwise.` | vaeloryx (half Health) |
| `Gust — On each Gust beat, after the Gale Herald's turn, each unit is Pushed 1 tile downwind.` | gale_herald |
| `Gust — On each Gust beat, after the Stormcaller's turn, each unit is Pushed 1 tile downwind.` | stormcaller |
| `Gust — On each Gust beat, after your turn, each unit is Pushed 1 tile in the direction from you to the Roc.` | gallows_roc |
| `Gust — On each Gust beat, after your turn, each unit is Pushed 1 tile toward the entry.` | snare_air |
| `Lightning Storm — On each Lightning Storm beat, after your turn, each unit on Electrified takes 3 damage.` | snare_lightning |
| `Lightning Storm — On each Lightning Storm beat, when Zekarion uses Overload, each unit on Electrified takes 6 damage.` | zekarion |
| `Lightning Storm — On each Lightning Storm beat, when Zekarion uses Overload, each unit on Electrified takes 7 damage.` | zekarion (half Health) |
| `Lightning Storm — On each Lightning Storm beat, when the Cantor uses Peal, each unit on Electrified takes 4 damage.` | storm_cantor |
| `Lightning Storm — On each Lightning Storm beat, when the Dynamo uses Arc Lash, each unit on Electrified takes 4 damage.` | dynamo |
| `Shadowstep — On each Shadowstep beat, after every second Prior turn, each hidden follower Blinks up to 3 tiles toward you.` | prior |
| `Shadowstep — On each Shadowstep beat, after your turn, each hidden Wick Shade Blinks 1 tile toward you.` | last_lamplighter |
| `Shadowstep — On each Shadowstep beat, after your turn, each hidden enemy Blinks up to 2 tiles toward you.` | last_light, snare_shadow |
| `Shadowstep — On each Shadowstep beat, when Noctyrax uses Void Claw, each hidden Veilbound Acolyte Blinks up to 3 tiles toward you.` | noctyrax |
| `Upheaval — On each Upheaval beat, after every second Craghide turn, each Marked tile becomes an Outcrop.` | craghide |
| `Upheaval — On each Upheaval beat, after every second Thornmother turn, each Marked tile becomes an Outcrop.` | thornmother |
| `Upheaval — On each Upheaval beat, after every second turn of yours, each Marked tile becomes an Outcrop.` | tharokh |
| `Upheaval — On each Upheaval beat, after your turn, a Marked tile on the way out becomes an Outcrop.` | snare_earth |
| `Upheaval — On each Upheaval beat, after your turn, each Marked tile becomes an Outcrop.` | tharokh (half Health) |
| `Wildfire — On each Wildfire beat, after every second Slagmaster turn, each Fire tile spreads 1 tile in the direction from the Slagmaster to you.` | slagmaster |
| `Wildfire — On each Wildfire beat, after every second turn of yours, each Fire tile spreads 1 tile in the direction from the Reaver to you.` | ashen_reaver |
| `Wildfire — On each Wildfire beat, after your turn, each Fire tile spreads 1 tile away from the entry.` | snare_fire |

## Section map

| Tooltip input | Where |
| --- | --- |
| `A choice, often with a cost.` | Event legend |
| `A tough enemy holds this room. Richer rewards.` | Guardian legend |
| `Anything could be here. Scout reveals it.` | Unknown room legend |
| `Bring two gear pieces of the same kind; one inherits the other's card.` | Graftwright legend |
| `Catch the Ember Hoarder before it slips away with its hoard.` | Ember Hoarder legend |
| `Claim 1 of 3 relics.` | Treasure legend |
| `Completed section.` | Scout while browsing a completed section |
| `Defeat each enemy.` | Combat legend, ordinary encounters |
| `Defeat the marked leader. The rest flee.` | Combat legend on older map layouts with a single combat objective description |
| `Kill the captain and the rest flee.` | Warband legend |
| `No Scouts remaining.` | Scout with no uses |
| `No unknown rooms in sight.` | Scout with no available target |
| `Reach a marked door to escape.` | Combat legend on those older layouts |
| `Resolve the current room first.` | Scout while the current room blocks scouting |
| `Rest to heal, or bank your Embers and end the run.` | Campfire legend |
| `Reveal an unknown room.` | Scout available |
| `Survive until dawn in the dark. Keep the braziers lit.` | Last Light legend |
| `Survive until the marked time.` | Combat legend on those older layouts |
| `The doors are sealing. Get out before they close.` | Umbral Snare legend |
| `The section's dragon.` | Boss legend |
| `Trade Embers for supplies.` | Scavenger legend |

Individual room previews include the room name, description and state on separate lines.

## Rewards

| Tooltip input | Where |
| --- | --- |
| `Choose whether one offered card follows you to the next reward. Health is already full.` | Skip & Recover with Deferred Choice at full Health |
| `Leave every offered card behind and recover %d Health.` | Skip & Recover |
| `Leave every offered card behind. Health is already full.` | Skip & Recover at full Health |
| `Once between bosses, replace each card in a non-boss combat reward.` | Card reward Reroll |
| `Recover %d Health and choose whether one offered card follows you to the next reward.` | Skip & Recover with Deferred Choice |
| `Your rewards have been saved.` | Dragon reward Continue or Complete Ascent |
| `Save nothing.` | Deferred Choice dialog after an event reward |
| `Save nothing. Health is already full.` | Deferred Choice dialog after a combat reward at full Health |
| `Take the healing reward and leave every offered card behind.` | Deferred Choice dialog when healing is available |
| `Skip a card reward to save 1 offered card. Replace 1 card in your next non-boss reward with that card.` | Deferred Choice dialog card-choice buttons |
| `Take this relic and leave the remaining choices behind.` | Curator’s Patience dialog |
| `This relic will replace one choice in your next relic offer.` | Curator’s Patience dialog save-relic buttons |

Native CardWidget hovers on offered cards use the Cards inventory above.

## Shop and room interactions

| Tooltip input | Where |
| --- | --- |
| `Open the merchant's stock again.` | Return to Shop button after closing the merchant |
| `Speak to the Emaciated Man.` | Speak |
| `Trade Moltshards for Embers or purchase levels.` | Awaken Power |

The Scavenger’s Leave, Buy/Sell, card paging and Purge buttons use native Godot tooltips. The ware tooltip carries a title and a price. Card previews use the Cards inventory above.

## Events

Event text and choice hover routes resolve inline glossary entries. Reward previews use explicit icon panels. Choice availability reasons are rendered in the choice with the event’s existing text controls. No additional plain sentence hovers were found in these event routes. Card reward buttons use the Rewards inventory above.

## Grimoire

The creature page’s Moves section renders the summary and time as mouse-ignored content for all creature IDs. Enemy chip hovers belong to combat and the distinct pre-battle inspection. Individual Grimoire navigation entries use their title. The search field uses its native help label.

| Tooltip input | Where |
| --- | --- |
| `Board rules, timing, defenses, hazards, and card flow.` | Combat navigation tab |
| `Card and enemy terms unlocked as they appear.` | Keywords navigation tab |
| `Enemies recorded the first time they are seen.` | Creatures navigation tab |
| `Magic cards recorded when they are gained, offered, or seen in combat.` | Magicks navigation tab |
| `NPCs recorded when encountered.` | Characters navigation tab |
| `Run flow, rooms, rewards, and the character sheet.` | Basics navigation tab |
| `Single-use scavenger cards recorded when carried or offered.` | Items navigation tab |
| `Weapons, armor, trinkets, and other gear recorded when discovered.` | Equipment navigation tab |

## One-line tooltips that still read like sentences

| Tooltip input | Where |
| --- | --- |
| `If this hit defeats the target, also (on top of the usual Card Play for a kill):` | headsmans_toll card face |
| `Clear search and return to section browsing` | Grimoire search Clear button |
| `After this action: Expose %d` | Predicted Expose status chip when hovering in combat |
