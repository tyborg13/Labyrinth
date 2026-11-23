# Candidate 4 card text truth check

Audited `codex/txt-25` at `b8c417d681da42543b988797c966d13e440e5b15` over `codex/mrg-14`. Checked all **305 live cards**, and found **13 common** and **13 edge** false claims. Each finding has a headless witness.

The [semantic inventory](inventory.json) covers each Time badge, face sentence or icon row, affected diagram offsets, inspection sentence and keyword column. It uses the game's Data, CardWidget, CardDisplay, ActionIconLibrary, pattern rewrite and inline-text paths. The review covered 952 catalog panels, 40 distinct neutral hand presentations, 22 Quartermaster’s Ledger variants and 13 Alchemist’s Retort variants and 8 saved-run starter variants. The inventory includes 86 differences in embedded inspection panels. Shared panel bodies were checked with the cards that display them. The numbers on damage and status icons are base amounts before defenses, caps or an explicit modifier. Bracketed icon IDs, diagram markers and row dividers transcribe the non-text parts of the face.

No raw markup remained in 4,080 inspected strings. The scan covered keyword, term, icon and pattern syntax, braces, radius prefixes and format specifiers. The Burst and Light diagrams were checked against their resolved offsets. The Light witness records a combat-long source, and White Silence's witness records 6 Stagger and zero Freeze. [Inventory log](inventory.log), [runtime log](probe.log)

## Findings

| ID and frequency | Card | Surface and rendered text | Behavior and reachable scenario | Sources and proof |
| --- | --- | --- | --- | --- |
| <a id="f01"></a>F01 · common | Lodestone Reversal `lodestone_reversal` | **Inspection sentence**<br>“Pull the target 2 tiles at Range 2 for 3 damage, leave Electrified at the destination, then gain 5 Block.” | The Pull moves the enemy. The ground rider uses the original aim tile.<br>Pull an enemy from (4,4) to (3,4). Electrified appears only on (4,4). | [board_attack_rules.gd:189](../../scripts/board_attack_rules.gd#L189), [board_attack_rules.gd:251](../../scripts/board_attack_rules.gd#L251)<br>[F01 runtime witness](probe.log) |
| <a id="f02"></a>F02 · common | Ember Guard `ember_guard` | **Inspection sentence**<br>“Gain 10 Block, then leave Fire on each enemy's tile.” | The effect places Fire on visible enemy footprint tiles orthogonally adjacent to you.<br>With enemies one and three tiles away, cast the card. Only the adjacent enemy's tile gains Fire. | [surface_card_rules.gd:104](../../scripts/surface_card_rules.gd#L104), [surface_card_rules.gd:118](../../scripts/surface_card_rules.gd#L118)<br>[F02 runtime witness](probe.log) |
| <a id="f03"></a>F03 · common | Ember Ward `ember_ward` | **Inspection sentence**<br>“Gain 5 Block, then leave Fire on each enemy's tile.” | The effect places Fire on visible enemy footprint tiles orthogonally adjacent to you.<br>With enemies one and three tiles away, cast the card. Only the adjacent enemy's tile gains Fire. | [surface_card_rules.gd:104](../../scripts/surface_card_rules.gd#L104), [surface_card_rules.gd:118](../../scripts/surface_card_rules.gd#L118)<br>[F03 runtime witness](probe.log) |
| <a id="f04"></a>F04 · common | Static Ward `static_ward` | **Inspection sentence**<br>“Gain 5 Block, then leave Electrified on your tile and each enemy's tile.” | The effect places Electrified on visible enemy footprint tiles orthogonally adjacent to you and on your tile.<br>With enemies one and three tiles away, cast the card. Only the adjacent enemy's tile gains Electrified and your tile also gains Electrified. | [surface_card_rules.gd:104](../../scripts/surface_card_rules.gd#L104), [surface_card_rules.gd:118](../../scripts/surface_card_rules.gd#L118)<br>[F04 runtime witness](probe.log) |
| <a id="f05"></a>F05 · common | Stone Ward `stone_ward` | **Inspection sentence**<br>“Gain 5 Block, then leave Rubble on each enemy's tile.” | The effect places Rubble on visible enemy footprint tiles orthogonally adjacent to you.<br>With enemies one and three tiles away, cast the card. Only the adjacent enemy's tile gains Rubble. | [surface_card_rules.gd:104](../../scripts/surface_card_rules.gd#L104), [surface_card_rules.gd:118](../../scripts/surface_card_rules.gd#L118)<br>[F05 runtime witness](probe.log) |
| <a id="f06"></a>F06 · common | Cinderweave Guard `cinderweave_guard` | **Inspection sentence**<br>“Gain 5 Block, then Strike for 2 and leave Fire on the target's tile.” | The Strike is a targetless attack on the four adjacent tiles. The same area gains Fire, including empty floor.<br>Play between two adjacent enemies on open floor. Each loses 2 Health and all four neighboring tiles gain Fire. | [cards.json:3441](../../data/cards.json#L3441), [board_attack_rules.gd:255](../../scripts/board_attack_rules.gd#L255), [combat_engine.gd:12076](../../scripts/combat_engine.gd#L12076)<br>[F06 runtime witness](probe.log) |
| <a id="f07"></a>F07 · common | Bottled Gale `bottled_gale` | **Inspection sentence**<br>“Consume. Push the target 3 tiles.” | A targetless, self-centered area Pushes each adjacent enemy 3 tiles away.<br>Play with enemies east and north of you. Both move 3 tiles and the card accepts zero target selections. | [cards.json:7246](../../data/cards.json#L7246), [maneuver_rules.gd:185](../../scripts/maneuver_rules.gd#L185), [maneuver_rules.gd:288](../../scripts/maneuver_rules.gd#L288)<br>[F07 runtime witness](probe.log) |
| <a id="f08"></a>F08 · common | Caltrops `caltrops` | **Face sentence**<br>“Tile [range] 2<br>[consume] Consume tile. Leave [surface_rubble] Rubble and [expose] Expose 2 each enemy hit.[diagram 1]”<br>Diagram 1 affected offsets: (0,-1), (-1,0), (0,0), (1,0), (0,1). | The word “tile” is part of the visible command. The card consumes the item copy and keeps the target tile, placing Rubble there.<br>Aim at a stone tile while an enemy is in the area. The board tile stays stone with Rubble and the card enters the consumed pile. | [card_faces.json:560](../../data/card_faces.json#L560), [board_attack_rules.gd:243](../../scripts/board_attack_rules.gd#L243), [combat_engine.gd:2066](../../scripts/combat_engine.gd#L2066)<br>[F08 runtime witness](probe.log) |
| <a id="f09"></a>F09 · common | Powder Keg `powder_keg` | **Range panel**<br>“Place the Outcrop within Range.” | Placement raises a powder keg. A keg blocks movement but has `blocks_sight = false`.<br>Place the card on any legal nearby floor tile. The resulting terrain kind is `powder_keg` and line of sight through the tile is preserved. | [card_panel_text.json:113](../../data/card_panel_text.json#L113), [terrain_card_rules.gd:31](../../scripts/terrain_card_rules.gd#L31), [combat_engine.gd:1771](../../scripts/combat_engine.gd#L1771)<br>[F09 runtime witness](probe.log) |
| <a id="f10"></a>F10 · common | Grounding `grounding` | **Expend panel**<br>“Remove the named ground from the target's tile to use this effect.” | The card has no selected target for Expend. It removes eligible Electrified within 2 tiles of you, including empty tiles.<br>Put Electrified on an empty adjacent tile and play the card. The ground is removed and you gain 6 Stoneskin. | [combat_engine.gd:12062](../../scripts/combat_engine.gd#L12062), [combat_engine.gd:12668](../../scripts/combat_engine.gd#L12668), [combat_engine.gd:12677](../../scripts/combat_engine.gd#L12677)<br>[F10 runtime witness](probe.log) |
| <a id="f11"></a>F11 · common | Spike Mantle `spike_mantle` | **Expend panel**<br>“Remove the named ground from the target's tile to use this effect.” | The card has no selected target for Expend. It removes eligible Rubble on the four adjacent tiles, including empty tiles.<br>Put Rubble on an empty adjacent tile and play the card. The ground is removed and you gain 4 Stoneskin. | [combat_engine.gd:12062](../../scripts/combat_engine.gd#L12062), [combat_engine.gd:12668](../../scripts/combat_engine.gd#L12668), [combat_engine.gd:12677](../../scripts/combat_engine.gd#L12677)<br>[F11 runtime witness](probe.log) |
| <a id="f12"></a>F12 · common | Seek the Light `seek_the_light` | **Blink panel**<br>“Move to a visible open tile up to 2 tiles away, ignoring intervening tiles.” | The ordinary destination limit is 2. The card's alternate limit for open Light destinations is 5.<br>Create Light on open floor five tiles away and use Seek the Light to land there. | [cards.json:8446](../../data/cards.json#L8446), [combat_engine.gd:1244](../../scripts/combat_engine.gd#L1244), [maneuver_rules.gd:700](../../scripts/maneuver_rules.gd#L700)<br>[F12 runtime witness](probe.log) |
| <a id="f13"></a>F13 · common | Sleet Squall `sleet_squall` | **Ranged panel**<br>“Deal 3 damage to a target within Range and line of sight.” | Range 3 applies to the Push aim. The automatic Ranged action follows the moved enemy and does not require a new Range or sight check.<br>Aim at an enemy three tiles away on a clear line. The enemy ends five tiles away and still takes 3 damage. | [cards.json:8648](../../data/cards.json#L8648), [combat_engine.gd:1612](../../scripts/combat_engine.gd#L1612), [combat_engine.gd:1623](../../scripts/combat_engine.gd#L1623)<br>[F13 runtime witness](probe.log) |
| <a id="f14"></a>F14 · edge | Snare Coil `snare_coil` | **Inspection sentence**<br>“Deal 2 damage at Range 3 and Pull the target 3 tiles, then Immobilize.” | The same hit applies Immobilize before resolving the Pull and its collision.<br>With Fetter Spikes, Pull an initially un-Immobilized enemy into another enemy. The mover takes 12 Collision damage instead of 6 because it is already Immobilized. | [combat_engine.gd:6753](../../scripts/combat_engine.gd#L6753), [combat_engine.gd:6764](../../scripts/combat_engine.gd#L6764), [forced_relic_rules.gd:49](../../scripts/forced_relic_rules.gd#L49)<br>[F14 runtime witness](probe.log) |
| <a id="f15"></a>F15 · edge | Skybolt `skybolt` | **Ranged panel**<br>“Deal 8 damage to a target within Range and line of sight.” | The card's ranged route explicitly ignores line of sight to a visible target.<br>Target a visible enemy on the other side of a wall. There is no line of sight and the enemy still takes 8 damage. | [dragon_trophy_rules.gd:62](../../scripts/dragon_trophy_rules.gd#L62), [combat_engine.gd:1325](../../scripts/combat_engine.gd#L1325)<br>[F15 runtime witness](probe.log) |
| <a id="f16"></a>F16 · edge | Thunderstone `thunderstone` | **Ranged panel**<br>“Deal 5 damage to a target within Range and line of sight.” | The card's ranged route explicitly ignores line of sight to a visible target.<br>Target a visible enemy on the other side of a wall. There is no line of sight and the enemy still takes 5 damage. | [dragon_trophy_rules.gd:62](../../scripts/dragon_trophy_rules.gd#L62), [combat_engine.gd:1325](../../scripts/combat_engine.gd#L1325)<br>[F16 runtime witness](probe.log) |
| <a id="f17"></a>F17 · edge | Meteorfall `meteorfall` | **Ranged panel**<br>“Deal 8 damage to a target within Range and line of sight.” | The cast aims a center. At impact the damage uses saved Marked tiles and checks occupants without measuring fresh Range or sight.<br>Aim at distance 4 with an enemy standing on the far end of the mark line at distance 5. The saved mark hits that enemy for 8. | [combat_engine.gd:1360](../../scripts/combat_engine.gd#L1360), [surface_card_rules.gd:503](../../scripts/surface_card_rules.gd#L503), [surface_card_rules.gd:536](../../scripts/surface_card_rules.gd#L536)<br>[F17 runtime witness](probe.log) |
| <a id="f18"></a>F18 · edge | Meteorfall `meteorfall` | **Inspection sentence**<br>“Mark 3 tiles within Range 4. At the start of your next turn, deal 8 damage on each Marked tile, then leave Fire.” | Range 4 is the center selection limit. The saved marks extend beyond the center.<br>In an open corridor aim at distance 4. The three marked tiles lie at distances 3, 4 and 5. | [combat_engine.gd:1360](../../scripts/combat_engine.gd#L1360), [combat_engine.gd:8948](../../scripts/combat_engine.gd#L8948), [surface_card_rules.gd:503](../../scripts/surface_card_rules.gd#L503)<br>[F18 runtime witness](probe.log) |
| <a id="f19"></a>F19 · edge | Meteorfall `meteorfall` | **Range panel**<br>“Mark tiles within Range and line of sight.” | Range and line of sight constrain center selection. The other marked tiles are taken from the area at that center.<br>Select the legal distance-4 center. A tile at distance 5 is marked. | [card_panel_text.json:506](../../data/card_panel_text.json#L506), [combat_engine.gd:1360](../../scripts/combat_engine.gd#L1360), [surface_card_rules.gd:503](../../scripts/surface_card_rules.gd#L503)<br>[F19 runtime witness](probe.log) |
| <a id="f20"></a>F20 · edge | Cinder Wall `cinder_wall` | **Inspection sentence**<br>“Leave Fire on 4 tiles within Range 2, then gain 4 Block. On Fire: +4 Block.” | The Range 2 check applies to the aim tile. The pattern can place Fire on floor farther away.<br>Aim straight down an open corridor at distance 2. The resulting Fire occupies distances 1 through 4. | [combat_engine.gd:1227](../../scripts/combat_engine.gd#L1227), [combat_engine.gd:8835](../../scripts/combat_engine.gd#L8835), [combat_engine.gd:12062](../../scripts/combat_engine.gd#L12062)<br>[F20 runtime witness](probe.log) |
| <a id="f21"></a>F21 · edge | Frost Lane `frost_lane` | **Inspection sentence**<br>“Leave Ice on 3 tiles within Range 3, then Draw 1.” | The Range 3 check applies to the aim tile. The pattern can place Ice on floor farther away.<br>Aim straight down an open corridor at distance 3. The resulting Ice occupies distances 2 through 4. | [combat_engine.gd:1227](../../scripts/combat_engine.gd#L1227), [combat_engine.gd:8835](../../scripts/combat_engine.gd#L8835), [combat_engine.gd:12062](../../scripts/combat_engine.gd#L12062)<br>[F21 runtime witness](probe.log) |
| <a id="f22"></a>F22 · edge | Lamp Oil `lamp_oil` | **Inspection sentence**<br>“Consume. Leave Fire on 3 tiles within Range 3.” | The Range 3 check applies to the aim tile. The pattern can place Fire on floor farther away.<br>Aim straight down an open corridor at distance 3. The resulting Fire occupies distances 2 through 4. | [combat_engine.gd:1227](../../scripts/combat_engine.gd#L1227), [combat_engine.gd:8835](../../scripts/combat_engine.gd#L8835), [combat_engine.gd:12062](../../scripts/combat_engine.gd#L12062)<br>[F22 runtime witness](probe.log) |
| <a id="f23"></a>F23 · edge | Earthen Rampart `earthen_rampart` | **Inspection sentence**<br>“Raise Outcrops on 3 tiles within Range 2, then gain 3 Stoneskin. Empower for Exhaust: 5 tiles.” | Range 2 limits the aim. The individual Outcrop locations are taken from the line around that aim.<br>On open floor aim along a row at distance 2. The card raises Outcrops at distances 1, 2 and 3. | [cards.json:6197](../../data/cards.json#L6197), [combat_engine.gd:1283](../../scripts/combat_engine.gd#L1283), [combat_engine.gd:1771](../../scripts/combat_engine.gd#L1771)<br>[F23 runtime witness](probe.log) |
| <a id="f24"></a>F24 · edge | Grapple `grapple` | **Inspection sentence**<br>“Blink to a tile adjacent to an enemy, Outcrop or crate within Range 4.” | The destination check accepts adjacency to any live terrain. The current game includes player-placed powder kegs.<br>Place a keg and Blink to a tile adjacent only to that keg, with no enemy, crate or Outcrop adjacent to the destination. | [maneuver_rules.gd:700](../../scripts/maneuver_rules.gd#L700), [maneuver_rules.gd:713](../../scripts/maneuver_rules.gd#L713), [terrain_card_rules.gd:31](../../scripts/terrain_card_rules.gd#L31)<br>[F24 runtime witness](probe.log) |
| <a id="f25"></a>F25 · edge | Jaw Trap `jaw_trap` | **Inspection sentence with Alchemist’s Retort**<br>“Deal 2 damage at Range 3 and Immobilize.” | The relic increases the damage to 3 and leaves Range at 2. The inspection binder places the Range value in the damage slot and damage in the Range slot.<br>Equip Alchemist’s Retort. Read Jaw Trap in the item detail and play it on a distance-2 crawler. The face and runtime are damage 3 and Range 2. | [relics.json:2628](../../data/relics.json#L2628), [item_rules_text.gd:16](../../scripts/item_rules_text.gd#L16), [item_rules_text.gd:52](../../scripts/item_rules_text.gd#L52), [run_scene.gd:30987](../../scripts/run_scene.gd#L30987), [combat_engine.gd:1325](../../scripts/combat_engine.gd#L1325)<br>[F25 runtime witness](probe.log) |
| <a id="f26"></a>F26 · edge | Frost Circuit `frost_circuit` | **Ranged panel**<br>“Deal 2 damage to a target within Range and line of sight.” | The chosen tile has Range 3. Converting a connected Ice component hits each enemy touching the converted tiles without a new Range or sight check.<br>Aim at adjacent Ice while a continuous Ice line leads to a hidden enemy four tiles away. The far tile converts and the enemy takes 2 damage. | [surface_card_rules.gd:44](../../scripts/surface_card_rules.gd#L44), [surface_card_rules.gd:313](../../scripts/surface_card_rules.gd#L313), [surface_card_rules.gd:333](../../scripts/surface_card_rules.gd#L333), [surface_card_rules.gd:346](../../scripts/surface_card_rules.gd#L346)<br>[F26 runtime witness](probe.log) |

## Borderline

- `immolation`, `phoenix_cleave`, `rekindle_edge`, `shatter_swing`, `worldbreak` — The generic Burst panel highlights the source plus four neighbors. The card face or sentence says the card spares you. The diagram asserts an area and no longer says you are among the direct victims. A separate keg or trap can still hit you. [burst_rules.gd:54](../../scripts/burst_rules.gd#L54), [combat_engine.gd:12574](../../scripts/combat_engine.gd#L12574), [combat_engine.gd:12643](../../scripts/combat_engine.gd#L12643)
- `discharge`, `flashsteam`, `immolation`, `inferno_ritual`, `phoenix_cleave`, `plasma_arc`, `wildfire_halo` — Each named fuel tile supplies a Burst footprint. A unit in two footprints takes one hit for the combined area under the default rules. The current wording names each source without promising a repeated hit when footprints overlap. [burst_rules.gd:39](../../scripts/burst_rules.gd#L39), [burst_rules.gd:54](../../scripts/burst_rules.gd#L54), [combat_engine.gd:12566](../../scripts/combat_engine.gd#L12566)
- `salamander_heart`, `cinder_trail` — Under R23, Fire is the ground term in these sentences. Fire-ground contact really does no damage while protected. A broad reading that includes a separate Burst fueled by Fire would conflict with the resolver. Candidate 4's sentences give that attack its own Burst term. [card_text_style.md:59](../../spec/card_text_style.md#L59), [rite_rules.gd:136](../../scripts/rite_rules.gd#L136), [combat_engine.gd:12598](../../scripts/combat_engine.gd#L12598)
- `cinderline_tempo`, `frost_heave`, `hush_of_winter`, `plasma_arc`, `pyroclasm`, `shatter`, `skybolt`, `thunderstone` — Enemy chips and enemy-first Range help describe the ordinary aim. Ranged also accepts selectable terrain or traps, and Lightning can offer a conductive aim tile. Treat the extra board targets as omissions in the short copy. The affirmative line-of-sight restriction on the two trophies is separately listed. [combat_engine.gd:1325](../../scripts/combat_engine.gd#L1325), [combat_engine.gd:1412](../../scripts/combat_engine.gd#L1412)
- `cyclone_seal` — The Ranged 9 panel can be read as an independent sight or Range gate on the final hit. The card does require sight and Range 3 to choose its center. The two diagrams and the sentence tie the hit to that center instead of a new target selection. [maneuver_rules.gd:254](../../scripts/maneuver_rules.gd#L254), [combat_engine.gd:1612](../../scripts/combat_engine.gd#L1612), [combat_engine.gd:1352](../../scripts/combat_engine.gd#L1352)
- `eye_of_the_storm`, `static_mantle`, `barbed_mail`, `battle_rhythm`, `brace_the_spear`, `bristle`, `deflect`, `riposte_lunge`, `spike_check`, `undertaker_stand` — The cards use “in melee.” Retaliate treats melee attacks and attacks launched from adjacent tiles as melee contact. An adjacent ranged hit can trigger it. Read “in melee” as in melee contact in the short panels, with the glossary supplying the precise test. [glossary.json:315](../../data/glossary.json#L315), [retaliate_rules.gd:61](../../scripts/retaliate_rules.gd#L61)
- `borrowed_spark`, `glassbone_guard`, `phoenix_cleave`, `reprise`, `thorn_crown_pact` — The Health cost is presented first and paid at commitment after the effects. The sentences use a separate cost command without “then” to specify an execution order. [combat_engine.gd:2050](../../scripts/combat_engine.gd#L2050), [combat_engine.gd:2104](../../scripts/combat_engine.gd#L2104)
- `glacier_salts`, `spark_focus`, `hoarfrost_shell`, `molten_reach`, `volt_surge`, `windlass_volley` — “At Range N” on a patterned action conventionally describes the aim. Glacier Salts says “within Range 3” without attaching a tile count, so it can still describe where you can aim. The findings distinguish sentences that put an explicit number of affected tiles within the Range limit. [combat_engine.gd:1227](../../scripts/combat_engine.gd#L1227), [combat_engine.gd:8925](../../scripts/combat_engine.gd#L8925)
- `thorn_crown_pact` — “Gain Retaliate 4 each turn” describes the effective ongoing amount. Runtime adds a persistent +4 when totaling Retaliate instead of depositing a fresh stack each turn. It is already effective the turn you play the Rite. [retaliate_rules.gd:41](../../scripts/retaliate_rules.gd#L41), [rite_rules.gd:32](../../scripts/rite_rules.gd#L32)
- `vortex`, `cyclone_seal` — The diagram marks the center as a reference. The prose “within” includes the center geometrically, but an enemy at the center has no direction toward it. There is no promise to move that enemy elsewhere. [maneuver_rules.gd:190](../../scripts/maneuver_rules.gd#L190)

## crd-28 re-judgement

The 24 claim rows follow the order of the old False table. The card crosswalk records the same 53 previously flagged IDs. [crd-28 audit](../crd28/REPORT.md)

| Old row | Claim | Candidate 4 | Reason |
| --- | --- | --- | --- |
| 1 | P010 · Card Play | omission only | Ordinary plays spend one and eligible player-card kills award one. Waivers, kill credit and summoned enemies are exceptions. [combat_engine.gd:2096](../../scripts/combat_engine.gd#L2096) |
| 2 | P057 · Petrify | fixed | The card and its panel now describe Stagger, with no Skip or Block promise. [combat_engine.gd:1799](../../scripts/combat_engine.gd#L1799) |
| 3 | P068 · Quicken 1 | omission only | The 1-Time floor limits the discount. [tempo_rules.gd:52](../../scripts/tempo_rules.gd#L52) |
| 4 | P069 · Quicken 2 | omission only | The 1-Time floor limits the discount. [tempo_rules.gd:52](../../scripts/tempo_rules.gd#L52) |
| 5 | P070 · Quicken 3 | omission only | The 1-Time floor limits the discount. [tempo_rules.gd:52](../../scripts/tempo_rules.gd#L52) |
| 6 | P071 · Quicken 4 | omission only | The 1-Time floor limits the discount. [tempo_rules.gd:52](../../scripts/tempo_rules.gd#L52) |
| 7 | P105 · Skybolt Shock | omission only | Surviving eligible enemies are Shocked. Defeat and Shock immunity are exceptions. The former custom panel has also been replaced by a Shock definition. [surface_card_rules.gd:198](../../scripts/surface_card_rules.gd#L198), [combat_engine.gd:6735](../../scripts/combat_engine.gd#L6735) |
| 8 | P123 · Frost Circuit Ice | fixed | The connected Ice traversal includes concealed tiles. The old conversion body is also gone from the focus column. [surface_card_rules.gd:313](../../scripts/surface_card_rules.gd#L313) |
| 9 | P124 · Ice | fixed | The panel now says Ice gives Expose 2 on entry or turn start. It makes no Chilled claim and no immediate-placement promise. [board_surface_rules.gd:166](../../scripts/board_surface_rules.gd#L166), [glossary.json:101](../../data/glossary.json#L101) |
| 10 | P088 · Caltrops, Flash Powder | fixed | Caltrops omits the zero-damage Ranged panel. Flash Powder creates Light directly and has no Ranged panel. [card_area_presentation.gd:35](../../scripts/card_area_presentation.gd#L35), [cards.json:4653](../../data/cards.json#L4653), [cards.json:7500](../../data/cards.json#L7500) |
| 11 | P088 · Skybolt, Thunderstone | still false | Both retain a generic line-of-sight restriction in the Ranged panel. [dragon_trophy_rules.gd:62](../../scripts/dragon_trophy_rules.gd#L62) [F15](#f15), [F16](#f16) |
| 12 | P088 · Sleet Squall | still false | The follow-up still hits the moved enemy after the Push takes the enemy past Range 3. [combat_engine.gd:1612](../../scripts/combat_engine.gd#L1612) [F13](#f13) |
| 13 | P017 · Immolation | fixed | The Burst panel no longer says “you included.” The card explicitly says “sparing you” and the direct Burst skips you. [glossary.json:69](../../data/glossary.json#L69), [burst_rules.gd:54](../../scripts/burst_rules.gd#L54) |
| 14 | P087 · Powder Keg, Worldspine | still false | Powder Keg still says Outcrop. Worldspine is fixed by its own aim-tile panel. [card_panel_text.json:107](../../data/card_panel_text.json#L107), [card_panel_text.json:113](../../data/card_panel_text.json#L113) [F09](#f09) |
| 15 | Lodestone Reversal · inspection | still false | Electrified still goes on the original target tile. [board_attack_rules.gd:243](../../scripts/board_attack_rules.gd#L243) [F01](#f01) |
| 16 | Empty Husk · face | omission only | “any illusion” still requires a visible target. A hidden tile is an omitted targeting exception under this brief. [illusion_card_rules.gd:329](../../scripts/illusion_card_rules.gd#L329) |
| 17 | Snare Coil · inspection | still false | The explicit “then” still reverses the Immobilize and Pull order. [combat_engine.gd:6753](../../scripts/combat_engine.gd#L6753), [combat_engine.gd:6764](../../scripts/combat_engine.gd#L6764) [F14](#f14) |
| 18 | White Silence · inspection | fixed | The card now selects enemies on Ice and Staggers them. It no longer promises Freeze. [surface_card_rules.gd:425](../../scripts/surface_card_rules.gd#L425), [surface_card_rules.gd:408](../../scripts/surface_card_rules.gd#L408) |
| 19 | Salamander Heart · face and inspection | omission only | Fire in Candidate 4 names a ground. The immunity works for Fire contact. Other damage sources are outside that claim. See Borderline for the broader reading. [rite_rules.gd:136](../../scripts/rite_rules.gd#L136) |
| 20 | Cinder Trail · inspection | omission only | Fireproof works for Fire contact this turn. A separate attack or Burst is a different source. See Borderline. [combat_engine.gd:12598](../../scripts/combat_engine.gd#L12598), [rite_rules.gd:136](../../scripts/rite_rules.gd#L136) |
| 21 | Skybolt · inspection | omission only | Eligible direct and conducted hits carry Shock. Death and immunity are exceptions. [surface_card_rules.gd:198](../../scripts/surface_card_rules.gd#L198), [combat_engine.gd:6735](../../scripts/combat_engine.gd#L6735) |
| 22 | Frost Circuit · inspection | fixed | The old traversal cutoff is gone. Immunity and defeat can still prevent Shock and are omissions under this brief. [surface_card_rules.gd:313](../../scripts/surface_card_rules.gd#L313), [surface_card_rules.gd:394](../../scripts/surface_card_rules.gd#L394) |
| 23 | Petrify · inspection | fixed | The inspection now reads “Stagger 6 an enemy within Range 3.” The normal Stagger cap and dragon reduction are exceptions. [combat_engine.gd:1799](../../scripts/combat_engine.gd#L1799), [card_keyword_rules.gd:218](../../scripts/card_keyword_rules.gd#L218) |
| 24 | Galvanize, Stolen Moment, Hourglass Sand · inspection | omission only | The current sentences now use the Quicken keyword. The 1-Time floor remains an exception in the shared definition. [tempo_rules.gd:52](../../scripts/tempo_rules.gd#L52) |

### Previously flagged card IDs

| Card | Old claim rows | Candidate 4 |
| --- | --- | --- |
| Bitter Tonic `bitter_tonic` | 1 | omission only |
| Borrowed Spark `borrowed_spark` | 1 | omission only |
| Caltrops `caltrops` | 10 | fixed |
| Charged Orb `charged_orb` | 4 | omission only |
| Cinder Trail `cinder_trail` | 20 | omission only |
| Cloudstep Loop `cloudstep_loop` | 1 | omission only |
| Crank Reload `crank_reload` | 1 | omission only |
| Daybreak `daybreak` | 1 | omission only |
| Empty Husk `empty_husk` | 16 | omission only |
| Flash Powder `flash_powder` | 10 | fixed |
| Flashsteam `flashsteam` | 9 | fixed |
| Frost Circuit `frost_circuit` | 8, 22 | fixed |
| Frost Heave `frost_heave` | 9 | fixed |
| Frost Lane `frost_lane` | 9 | fixed |
| Frost Nova `frost_nova` | 9 | fixed |
| Frost Snare `frost_snare` | 9 | fixed |
| Frostbolt `frostbolt` | 9 | fixed |
| Frozen Bite `frozen_bite` | 1 | omission only |
| Galvanize `galvanize` | 4, 24 | omission only |
| Gathering Rhythm `gathering_rhythm` | 1 | omission only |
| Glacier Pin `glacier_pin` | 9 | fixed |
| Glacier Salts `glacier_salts` | 9 | fixed |
| Glide `glide` | 9 | fixed |
| Guarded Step `guarded_step` | 1 | omission only |
| Headsman's Toll `headsmans_toll` | 1 | omission only |
| Hoarfrost Shell `hoarfrost_shell` | 9 | fixed |
| Hoarfrost Wall `hoarfrost_wall` | 9 | fixed |
| Hoarfrost Ward `hoarfrost_ward` | 9 | fixed |
| Hourglass Sand `hourglass_sand` | 6, 24 | omission only |
| Ice Sculpture `ice_sculpture` | 9 | fixed |
| Immolation `immolation` | 13 | fixed |
| Kept Breath `kept_breath` | 9 | fixed |
| Loaded Toss `loaded_toss` | 1 | omission only |
| Locket Chill `locket_chill` | 9 | fixed |
| Lodestone Reversal `lodestone_reversal` | 15 | still false |
| Overclock `overclock` | 1 | omission only |
| Petrify `petrify` | 2, 23 | fixed |
| Powder Keg `powder_keg` | 14 | still false |
| Rime Hack `rime_hack` | 9 | fixed |
| Rime Shard `rime_shard` | 9 | fixed |
| Rime Step `rime_step` | 9 | fixed |
| Rimefang `rimefang` | 9 | fixed |
| Rimeplate Lock `rimeplate_lock` | 9 | fixed |
| Salamander Heart `salamander_heart` | 19 | omission only |
| Skybolt `skybolt` | 7, 11, 21 | still false |
| Sleet Squall `sleet_squall` | 12 | still false |
| Snare Coil `snare_coil` | 17 | still false |
| Spur Spark `spur_spark` | 3 | omission only |
| Static Rush `static_rush` | 4 | omission only |
| Stolen Moment `stolen_moment` | 5, 24 | omission only |
| Thunderstone `thunderstone` | 11 | still false |
| White Silence `white_silence` | 18 | fixed |
| Worldspine `worldspine` | 14 | fixed |

## Style observations

- `worldroot_stride` · Inspection sentence · R25 · “Leave Rubble under you.” The fixed vocabulary uses “your tile.”
- `vortex` · Inspection sentence · R12 and R25 · “Pull each enemy within 2 tiles of the chosen tile 2 tiles toward that tile.” “The chosen tile” is reserved for definitions. The card sentence uses the selected tile as its target.
- `frost_circuit` · Face and inspection sentence · R21 · “On Ice: do the same on each connected Ice tile.” “Do the same” substitutes a general verb for the repeated game actions.
- `serrated_slip` · Face sentence · R18 · “If the target is already Exposed: ++4.” The authored text adds a leading plus and the renderer adds another before the bonus damage icon. The intended number is still 4.

The card observations are outside the false-claim totals. The rules-text ratchet retains 16 existing hits. Its two legacy card-panel templates are distinct from the live focus-panel copy.

## Skipped IDs

- `bone_dart` → `pale_spark`. Retired definition. The live resolver returns the replacement definition.
- `ember_jab` → `backhand_nick`. Retired definition. The live resolver returns the replacement definition.
- `cinderburst` → `ember_rain`. Retired definition. The live resolver returns the replacement definition.
- `gate_gambit` → `trapdoor`. Retired definition. The live resolver returns the replacement definition.

## Proof for the design owner

The report uses headless semantic and runtime proof. The brief specifies no windowed probe or inspection fixture.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-25
python3 tools/godot_task_runner.py --task-id txt-25 --stream -- godot --headless --path . --script tools/txt25/dump_cards.gd -- tools/txt25/inventory.json
python3 tools/godot_task_runner.py --task-id txt-25 --stream -- godot --headless --path . --script tools/txt25/probe_claims.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$PWD/tools/txt25/python-default"
python3 tests/test_rules_text_lint.py
```

- Inventory · `TXT25 INVENTORY: 305 live cards, 4 retired IDs, 952 catalog panels, 40 hand differences, 22 item variants` · `TXT25 LEGACY: 8 resumable starter variants` [Log](inventory.log)
- Runtime witnesses · `TXT25 WITNESS RESULT: PASS (29 witnesses, 0 failures)` [Log](probe.log)
- Python default group · `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 31.294s` · `OK` [Log](checks.log)
- Rules-text lint · `Ran 3 tests in 0.047s` · `OK` · `PASS: Rules text lint (16 existing hits)` · `Hits by rule: sentence_start=1, pronoun=11, hedge=0, semicolon=2, spaced_dash=0, article=0, vocabulary=2` [Log](checks.log)

## Chosen defaults

- The semantic export instantiates the existing 250×352 CardWidget to resolve sentence faces.
- The probes use the existing Surface Test room and seed, a clear floor position at (2,4), 40-Health Tunnel Crawlers, and authored cards. Scenario positions are local constants in probe_claims.gd.

## TODO_DESIGN placeholders

None.

## Open issues and audit limits

- Geometry and text were checked headlessly. Pixel layout, clipping and tooltip-loop video are outside this audit.
- A diagnostic export produced 1,846 numeric-upgrade previews across 281 non-item IDs. The live launcher opens Skills, purchasing is disabled and combat definitions ignore legacy card_mods. The exported diagnostic previews are unreachable.
- The variant review includes authored Follow-up and Empower copy, saved-run starters and the two item relics named in the inventory. Other interactions were examined where a claim required them.
- Godot logged a macOS certificate-store warning and exited successfully. The Python runner could not write its learned timing cache in shared Git metadata. The tests passed.
