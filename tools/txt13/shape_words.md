# txt-13 tile shape wording

Audited authored game data, rendered GDScript copy, dynamically formatted card panels and move summaries, and the existing glossary and combat text inventories. The table records the original words and the resulting display. `@pattern(…)` represents a diagram drawn by the card-face renderer. The pale reference tile denotes an unaffected origin and the pale dot marks the hero on an affected tile.

An adjacent single-target action, a movement distance, line of sight, footprint size, and a named ability (such as Crosswind or Shatterline) are targeting rules, dials or names. They are excluded unless the sentence also describes a multi-tile footprint. Engine IDs, stored saves, item names, map styling and narrative dialogue are outside the display rewrite. Round 1 shortens card catalogue copy and caption or button text, and uses plain distance or count wording when the tiles vary.

| Surface | Source | Before | Display after |
| --- | --- | --- | --- |
| Combat intent, pre-battle and marked-tile hover | `scripts/action_icon_library.gd / marked_move_text(lob_mark)` | `A cross on you.` | `@pattern(cross:hero) On your tile. Next turn they take the hit and become Fire.` |
| Slagmaster combat intent, pre-battle and marked-tile hover | `scripts/action_icon_library.gd / LOB_TWO_CROSS_DESCRIPTION` | `A cross on you and one 2 tiles away.` | `@pattern(cross:hero) @pattern(cross) On your tile and 2 tiles away. Next turn they take the hit and become Fire.` |
| Known Lob move | `scripts/action_icon_library.gd / lob_text` | `Marks your tile and the 4 around it. Next turn: %d in the centre, %d around it, and they become Fire.` | `@pattern(cross:hero) Marks these tiles, centred on you. Next turn: %d in the centre, %d around it, and they become Fire.` |
| Known Slagmaster move | `scripts/action_icon_library.gd / lob_text` | `Marks %d crosses. Next turn: %d in each centre, %d around them, and they become Fire.` | `@pattern(cross:hero) @pattern(cross) Marks these tiles, centred on you and 2 tiles away. Next turn: %d in each centre, %d around them, and they become Fire.` |
| Lob and Slagmaster landing | `scripts/action_icon_library.gd / marked_move_text(lob_land)` | `Marked tiles take the hit: %d in the centre, %d around it, and they become Fire. / Marked tiles take the hit: %d in each centre, %d around them, and they become Fire.` | `Same landing sentences with one or two preceding diagrams from the held centers.` |
| Icefall combat and pre-battle move | `scripts/action_icon_library.gd / MARKED_MOVE_DESCRIPTIONS.icefall` | `Marks 3 tiles across yours. Next turn they take the hit and turn to Ice.` | `@pattern(icefall:hero) Marks these tiles. Next turn they take the hit and turn to Ice.` |
| Guardian move | `scripts/action_icon_library.gd / tokens_for_guardian_rule(ring)` | `Ring %d–%d / Ring %d. Distance is measured from the nearest occupied dragon tile.` | `Diagram of the current inner and outer reaches from the dragon footprint. Distance is measured from the nearest occupied dragon tile.` |
| Guardian move | `scripts/action_icon_library.gd / tokens_for_guardian_rule(cross)` | `Cross %d. Two-wide lanes extend from all four edges of the dragon. Leaves Ice on the marked ground.` | `@pattern(body_cross:{reach}) Leaves Ice on the marked ground.` |
| Guardian move | `scripts/action_icon_library.gd / tokens_for_guardian_rule(surface_snapshot)` | `Marked + adjacent. Hits surviving marked ground and its orthogonal neighbors. Replacing marked ground removes its area; later ground is not added.` | `Diagram first. Hits these tiles at surviving marked ground. Replacing marked ground removes its area; later ground is not added.` |
| Guardian move | `scripts/action_icon_library.gd / tokens_for_guardian_rule(swept_path)` | `Along approach +%d. Hits the shown approach path and every tile within this distance of the dragon's swept body, including where it started. The approach direction stays fixed.` | Hits the tiles it passes and every tile within the stated distance of its body as it moves, including where it started. |
| Enemy Burst row and tooltip, pre-battle trait | `scripts/enemy_mechanics/death_burst_view.gd / trait_token` | `When it dies, it hits every unit next to it for %d and leaves Fire.` | `@pattern(surround:origin) When it dies, it hits every unit on these tiles for %d and leaves Fire.` |
| Enemy Splits trait | `scripts/enemy_mechanics/split_trait_text.gd / trait_token` | `When it dies, it splits into %d %s next to it.` | Keeps the count and uses the authored distance in tiles. |
| Tile trap tooltip | `scripts/combat_board_view.gd / _trap_tooltip_text` | `Leaves %s on this tile and each tile next to it.` | `@pattern(cross) Leaves %s on these tiles.` |
| Air trap tile tooltip | `scripts/combat_board_view.gd / _trap_tooltip_text` | `@kw(push) each unit next to this tile 1 tile away.` | `@pattern(neighbors:origin) @kw(push) each unit on these tiles 1 tile away.` |
| Powder Keg tile tooltip | `scripts/combat_board_view.gd / _terrain_tooltip_text` | `When destroyed, deals %d to its tile and each tile next to it.` | `@pattern(cross) When destroyed, deals %d to these tiles.` |
| Worldspine tile tooltip | `scripts/combat_board_view.gd / _terrain_tooltip_text` | `At the start of your turn, each enemy next to it takes %d.` | `@pattern(neighbors:origin) At the start of your turn, each enemy on these tiles takes %d.` |
| Card native tooltip and row | `scripts/action_icon_library.gd / tokens_for_action(burst_terrain)` | `%d-tile line beyond. Hits each enemy in the %d tiles beyond the outcrop, away from you.` | `@pattern(beyond:{line_length}:origin) Hits each enemy on these tiles beyond the outcrop, away from you.` |
| Card native tooltip and row | `scripts/action_icon_library.gd / _append_maneuver_tokens(force_area)` | `within %d. Pull each enemy within %d of %s %d toward it. / Push each enemy within %d of %s %d away from it.` | `Resolved area diagram with reference centre. Pull each enemy on these tiles {n} tiles toward the chosen tile. / Push each enemy on these tiles {n} tiles away from the chosen tile or you.` |
| Card targeting choice | `scripts/run_scene.gd / _surface_relic_mode_buttons` | `Cross strike` | `Strike` |
| Card targeting choice | `scripts/surface_relic_rules.gd / action_variants` | `Spend %d Stoneskin · cross` | `Spend %d Stoneskin` |
| Upgrade choice | `scripts/game_data.gd / _pattern_upgrade_options` | `Extend cross / Add diagonals` | `Add %d tiles` |
| Combat turn caption | `scripts/action_icon_library.gd / lob_text` | `Marks %d crosses. / Marks your tile and the 4 around it.` | `Lob Slag next turn · {centre} / {outer}` and `Lob Slag · {centre} / {outer}`. |
| Guardian move detail | `scripts/action_icon_library.gd / tokens_for_action(terrain_burst)` | `Hits within %d of surviving Worldspines. / Surviving outcrops rupture every floor tile within the shown distance.` | Keeps the shown distance from surviving terrain. |
| Pre-battle and objective HUD | `scripts/combat_objective_rules.gd / description_for_objective` | `Kill the captain and the rest flee. Followers within 2 tiles of it deal +1 damage.` | `@pattern(diamond:2) Kill the captain and the rest flee. Followers on these tiles around it deal +1 damage. Text-only objective heading unchanged.` |
| Card tooltip | `data/card_panel_text.json#shatter` | `If the target was Frozen, deal {n} to each enemy next to it.` | `@pattern(neighbors:origin) If the target was Frozen, deal {n} to each enemy on these tiles.` |
| Card tooltip | `data/card_panel_text.json#title_sentence_light` | `Creates Light of this radius.` | `@pattern(diamond:{r}) Creates Light on these tiles.` |
| Card tooltip | `data/card_panel_text.json#title_sentence_light_self` | `Creates Light of this radius around you.` | `@pattern(diamond:{r}:hero) Creates Light on these tiles around you.` |
| Card tooltip | `data/card_panel_text.json#raise_worldspine` | `Raises a Worldspine with this much Health on each empty tile around the target.` | `@pattern(neighbors:origin) Raises a Worldspine with this much Health on each empty one of these tiles around the target.` |
| Card tooltip | `data/card_panel_text.json#keg_detonate` | `When destroyed, the keg deals {n} to everything on and next to it.` | `@pattern(cross) When destroyed, the keg deals {n} to everything on these tiles.` |
| Card tooltip | `data/card_panel_text.json#worldspine_burst` | `Each turn, enemies next to your Worldspines take {n}.` | `@pattern(neighbors:origin) Each turn, enemies on these tiles around your Worldspines take {n}.` |
| Card tooltip | `data/card_panel_text.json#light_trail` | `Creates Light of this radius on each tile you enter.` | `@pattern(diamond:{r}) Creates Light on these tiles centered on each tile you enter.` |
| Card tooltip | `data/card_panel_text.json#light_target` | `Creates Light of this radius at the target.` | `@pattern(diamond:{r}) Creates Light on these tiles at the target.` |
| Card tooltip | `data/card_panel_text.json#light_land` | `Creates Light of this radius where you land.` | `@pattern(diamond:{r}) Creates Light on these tiles where you land.` |
| Card tooltip | `data/card_panel_text.json#title_sentence_pull_area` | `Pulls each enemy within {r} of the chosen tile {n} tiles toward it.` | `@pattern(hollow_diamond:{r}:origin) Pulls each enemy on these tiles {n} tiles toward the chosen tile.` |
| Card tooltip | `data/card_panel_text.json#title_sentence_push_area_target` | `Pushes each enemy within {r} of the chosen tile {n} tiles away from it.` | `@pattern(hollow_diamond:{r}:origin) Pushes each enemy on these tiles {n} tiles away from the chosen tile.` |
| Card tooltip | `data/card_panel_text.json#title_sentence_push_area` | `Pushes each enemy within {r} of you {n} tiles away.` | `@pattern(hollow_diamond:{r}:origin) Pushes each enemy on these tiles {n} tiles away from you.` |
| Card tooltip | `data/card_panel_text.json#unchanged_each_empty_tile_next_to_the_illusion` | `Each empty tile next to the illusion.` | `@pattern(neighbors:origin) Each empty one of these tiles next to the illusion.` |
| Card tooltip | `data/card_panel_text.json#unchanged_creates_one_illusion_on_each_empty_tile_next_to_you_up_to_four` | `Creates one illusion on each empty tile next to you (up to four).` | `@pattern(neighbors:origin) Creates one illusion on each empty one of these tiles (up to four).` |
| Card tooltip | `data/card_panel_text.json#unchanged_hits_each_enemy_on_the_four_tiles_next_to_the_destroyed_terrain` | `Hits each enemy on the four tiles next to the destroyed terrain.` | `@pattern(neighbors:origin) Hits each enemy on these tiles next to the destroyed terrain.` |
| Card tooltip | `data/card_panel_text.json#unchanged_hits_each_enemy_on_the_four_tiles_next_to_the_destroyed_illusion` | `Hits each enemy on the four tiles next to the destroyed illusion.` | `@pattern(neighbors:origin) Hits each enemy on these tiles next to the destroyed illusion.` |
| Card tooltip | `data/card_panel_text.json#unchanged_each_other_enemy_next_to_the_target` | `Each other enemy next to the target.` | `@pattern(neighbors:origin) Each other enemy on these tiles next to the target.` |
| Status / keyword | `data/glossary.json#burst.definition` | `When it dies, it hits every unit next to it and leaves Fire.` | `@pattern(surround:origin) When it dies, it hits every unit on these tiles and leaves Fire.` |
| Status / keyword | `data/glossary.json#eclipse.definition` | `The darkest Umbra: you see only 1 tile around you.` | `@pattern(cross:hero) The darkest Umbra: you see only these tiles.` |
| Status / keyword | `data/glossary.json#traps.definition` | `Trigger when entered or attacked: damage the unit on them, then leave their element on their tile and each tile next to it. Air traps push instead.` | `@pattern(cross) Trigger when entered or attacked: damage the unit on them, then leave their element on these tiles. Air traps push instead.` |
| Relic detail | `data/relics.json#pilgrim_boots.description` | `Gain 1 more @kw(movement) each turn. Moving leaves radius-1 @term(illuminate) for 2 turns on tiles you enter, unless the card attacks. @kw(blink) lights both ends.` | `@pattern(cross) Gain 1 more @kw(movement) each turn. Moving leaves @term(illuminate) for 2 turns on these tiles centered on each tile you enter, unless the card attacks. @kw(blink) lights both ends.` |
| Relic detail | `data/relics.json#frost_prism.description` | `When you kill a @term(freeze&#124;Frozen) enemy with an attack, leave @term(surface_rubble) on its tile and each tile next to it.` | `@pattern(cross) When you kill a @term(freeze&#124;Frozen) enemy with an attack, leave @term(surface_rubble) on these tiles centered on it.` |
| Relic detail | `data/relics.json#thawing_charm.description` | `Excess healing becomes @term(stoneskin), up to 8 each turn. It also creates radius-1 @term(illuminate) on you for 2 turns, once per turn.` | `@pattern(cross:hero) Excess healing becomes @term(stoneskin), up to 8 each turn. It also creates @term(illuminate) on these tiles around you for 2 turns, once per turn.` |
| Relic detail | `data/relics.json#ember_siphon.description` | `When an enemy dies on @term(surface_fire), @kw(surface_fire) spreads to each tile next to it without @kw(surface_fire), @term(surface_ice) or @term(surface_electrified).` | `@pattern(neighbors:origin) When an enemy dies on @term(surface_fire), @kw(surface_fire) spreads to each of these tiles without @kw(surface_fire), @term(surface_ice) or @term(surface_electrified).` |
| Relic detail | `data/relics.json#thornmail_brooch.description` | `Your single-target @kw(melee) can spend 4 @term(stoneskin) to strike a cross instead, leaving @term(surface_rubble) on it.` | `@pattern(cross) Your single-target @kw(melee) can spend 4 @term(stoneskin) to strike these tiles instead, leaving @term(surface_rubble) on them.` |
| Relic detail | `data/relics.json#overflow_censer.description` | `When you place @term(surface_fire), @term(surface_ice) or @term(surface_electrified) over a different one, it also spreads to each tile next to it that has none.` | `@pattern(neighbors:origin) When you place @term(surface_fire), @term(surface_ice) or @term(surface_electrified) over a different one, it also spreads to each of these tiles that has none.` |
| Relic detail | `data/relics.json#ashen_brand.description` | `Your @kw(detonate) @kw(surface_consume&#124;Expends) all connected @term(surface_fire). A target hit by several blast crosses takes 25% more damage per extra cross.` | `@pattern(cross) Your @kw(detonate) @kw(surface_consume&#124;Expends) all connected @term(surface_fire). A target hit by several blasts takes 25% more damage per extra blast.` |
| Relic detail | `data/relics.json#eclipse_mantle.description` | `Your first @kw(blink) each turn leaves a 2-@term(health) @term(illusion) where you started. Your @kw(illusion&#124;Illusions) shed radius-2 @term(illuminate).` | `@pattern(diamond:2) Your first @kw(blink) each turn leaves a 2-@term(health) @term(illusion) where you started. Your @kw(illusion&#124;Illusions) shed @term(illuminate) on these tiles.` |
| Relic detail | `data/relics.json#tallow_candle.description` | `At the start of combat, create radius-2 @term(illuminate) on your tile for 3 turns.` | `@pattern(diamond:2:hero) At the start of combat, create @term(illuminate) centered on your tile for 3 turns.` |
| Rite card and popup | `data/cards.json#rite_of_noon.description` | `Rite: you radiate radius-2 Light, and your attacks deal 2 more to enemies in Light.` | `@pattern(diamond:2:hero) Rite: you radiate Light on these tiles, and your attacks deal 2 more to enemies in Light.` |
| Battlefield HUD / turn rail | `data/battlefield_rules.json#vyraketh.sentence` | `When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions.` | `@pattern(neighbors:origin) When Vyraketh breathes, every Fire tile spreads to these tiles.` |
| Battlefield HUD / turn rail | `data/battlefield_rules.json#vyraketh.at_half_health.sentence` | `After every second Vyraketh turn, every Fire tile spreads 1 tile in all four directions.` | `@pattern(neighbors:origin) After every second Vyraketh turn, every Fire tile spreads to these tiles.` |
| Grimoire article | `data/grimoire.json#combat:traps.body[0]` | `A trap triggers when a unit enters its tile or an attack hits that tile. The trap damages the unit on its tile, then leaves its element on that tile and each tile next to it. An Air trap leaves no ground: it pushes each unit next to it 1 tile away.` | `@pattern(cross) @pattern(neighbors:origin) A trap triggers when a unit enters its tile or an attack hits that tile. The trap damages the unit on its tile, then leaves its element on that tile and each tile next to it. An Air trap leaves no ground: it pushes each unit next to it 1 tile away.` |
| Grimoire article | `data/grimoire.json#combat:traps.body[1]` | `Trigger when entered or attacked. Damage the unit on them, then leave their element on their tile and each tile next to it.` | `@pattern(cross) Trigger when entered or attacked. Damage the unit on them, then leave their element on their tile and each tile next to it.` |
| Grimoire article | `data/grimoire.json#combat:outcrops.body[1]` | `A tile is legal only when the raise keeps every floor tile connected, so an outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.` | `@pattern(neighbors:origin) A tile is legal only when the raise keeps every floor tile connected, so an outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.` |
| Grimoire article | `data/grimoire.json#combat:outcrops.body[2]` | `Powder kegs and Worldspines are raised the same way. A keg blocks movement but not sight; when anything destroys it, it deals its damage to its tile and each tile next to it, setting off other kegs. Your Worldspines pulse at the start of each of your turns, hitting each enemy next to one of them once.` | `@pattern(cross) @pattern(neighbors:origin) Powder kegs and Worldspines are raised the same way. A keg blocks movement but not sight; when anything destroys it, it deals its damage to its tile and each tile next to it, setting off other kegs. Your Worldspines pulse at the start of each of your turns, hitting each enemy next to one of them once.` |
| Grimoire article | `data/grimoire.json#keyword:illusion.body[1]` | `Some illusions carry an effect while they live: enemies that damage a charged illusion take damage back (once per enemy attack), and a Doppelganger lets your ranged attacks fire from its tile. Mirror Feint places its illusion beside an enemy; Hall of Mirrors fills every empty tile next to you.` | `@pattern(neighbors:origin) Some illusions carry an effect while they live: enemies that damage a charged illusion take damage back (once per enemy attack), and a Doppelganger lets your ranged attacks fire from its tile. Mirror Feint places its illusion beside an enemy; Hall of Mirrors fills every empty tile next to you.` |
| Grimoire article | `data/grimoire.json#keyword:retaliate.body[1]` | `Melee means a melee attack or any attack made from a tile next to you. Retaliate triggers once per enemy attack. Several Retaliates add their damage and Bleed; Shock and Push use the largest.` | `@pattern(neighbors:origin) Melee means a melee attack or any attack made from a tile next to you. Retaliate triggers once per enemy attack. Several Retaliates add their damage and Bleed; Shock and Push use the largest.` |
| Grimoire article | `data/grimoire.json#combat:cinder_marks.body[0]` | `Meteorfall strikes marked tiles and leaves Fire. When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions.` | `@pattern(neighbors:origin) Meteorfall strikes marked tiles and leaves Fire. When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions.` |
| Grimoire article | `data/grimoire.json#combat:cinder_marks.body[2]` | `The Meteorfall card marks a line of tiles the same way. The marks stay through enemy turns; at the start of your next turn, before you draw, each marked tile takes the damage (anyone standing there, including you) and becomes Fire.` | `@pattern(line:3) The Meteorfall card marks a line of tiles the same way. The marks stay through enemy turns; at the start of your next turn, before you draw, each marked tile takes the damage (anyone standing there, including you) and becomes Fire.` |
| Grimoire article | `data/grimoire.json#combat:hollow_gale.body[0]` | `Hollow Gale strikes everywhere within 2 tiles of Vaeloryx and Pushes struck actors away.` | `@pattern(body_area:2) Hollow Gale strikes everywhere within 2 tiles of Vaeloryx and Pushes struck actors away.` |
| Grimoire article | `data/grimoire.json#combat:hollow_gale.body[2]` | `Eye of the Storm threatens a wide ring after the dragon retreats. Escape the outer edge, or step into the eye and face a weaker bite.` | `@pattern(ring_2:5) Eye of the Storm threatens a wide ring after the dragon retreats. Escape the outer edge, or step into the eye and face a weaker bite.` |
| Grimoire article | `data/grimoire.json#combat:area_force.body[2]` | `Squall pushes each enemy in its cross away from the cross's center; the enemy on the center itself is pushed away from you.` | `@pattern(cross) Squall pushes each enemy in its cross away from the cross's center; the enemy on the center itself is pushed away from you.` |
| Grimoire article | `data/grimoire.json#enemy:vyraketh.body[1]` | `When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions. At half Health its Fire spreads after every second Vyraketh turn. Crownfire detonates its own marked Fire, and its bite renews the marks.` | `@pattern(neighbors:origin) When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions. At half Health its Fire spreads after every second Vyraketh turn. Crownfire detonates its own marked Fire, and its bite renews the marks.` |
| Grimoire article | `data/grimoire.json#enemy:vaeloryx.body[1]` | `After each Vaeloryx turn, its wind Pushes everyone 1 tile, then turns a quarter clockwise. At half Health it Pushes 2 tiles. Its retreating storm combines a wide ring with a weaker close bite.` | `@pattern(ring_2:5) After each Vaeloryx turn, its wind Pushes everyone 1 tile, then turns a quarter clockwise. At half Health it Pushes 2 tiles. Its retreating storm combines a wide ring with a weaker close bite.` |
| Grimoire article | `data/grimoire.json#keyword:burst.body[0]` | `When it dies, it deals the shown damage to every unit in the 8 tiles around it, then leaves Fire.` | `@pattern(surround:origin) When it dies, it deals the shown damage to every unit in the 8 tiles around it, then leaves Fire.` |
| Grimoire article | `data/grimoire.json#keyword:eclipse.body[0]` | `The darkest Umbra stage: you see only 1 tile around you. Light still reveals; Dispel Umbra lowers it.` | `@pattern(cross:hero) The darkest Umbra stage: you see only 1 tile around you. Light still reveals; Dispel Umbra lowers it.` |
| Brazier tile tooltip | `scripts/combat_board_view.gd / data/special_encounters.json#last_light` | `Brazier: lights 2 tiles around it. A Wick Shade's Snuff puts it out; step onto it to relight it.` | `@pattern(diamond:2) Brazier: lights these tiles. A Wick Shade's Snuff puts it out; step onto it to relight it.` |
| Brazier tile tooltip | `scripts/combat_board_view.gd / data/special_encounters.json#last_light` | `Light radius 2 blocks Eclipse darkness. The marked ground and other attacks can still hit.` | `@pattern(diamond:2) Light blocks Eclipse darkness on these tiles. The marked ground and other attacks can still hit.` |
| Brazier tile tooltip | `scripts/combat_board_view.gd / data/special_encounters.json#last_light` | `Step onto this brazier's tile to relight it and restore Light radius 2.` | `@pattern(diamond:2) Step onto this brazier's tile to relight it and restore Light on these tiles.` |
| Brazier tile tooltip | `scripts/combat_board_view.gd / data/special_encounters.json#last_light` | `Light radius 2` | `@pattern(diamond:2) Light on these tiles` |
| Brazier tile tooltip | `scripts/combat_board_view.gd / data/special_encounters.json#last_light` | `Watch Brazier · Light radius 2` | `@pattern(diamond:2) Watch Brazier · Light on these tiles` |
| Guardian move tooltip | `scripts/action_icon_library.gd / detonate_cinders` | `Expends Fire. Each affected actor, including the dragon, takes damage once on the Fire or its four neighboring tiles.` | `@pattern(cross) Expends Fire. Each affected actor, including the dragon, takes damage once on these tiles.` |
| Card native ground tooltip | `scripts/action_icon_library.gd / _append_illusion_placement_tokens` | `Leaves this ground on each empty tile next to the illusion.` | `@pattern(neighbors:origin) Leaves this ground on each empty one of these tiles next to the illusion.` |
| Status / keyword | `data/glossary.json#illuminate.definition` | `Lights tiles within its radius through the Umbra.` | Keeps the shown distance without a shape noun. |
| Grimoire article | `data/grimoire.json#keyword:illuminate` | `Creates light that reveals nearby Umbra within the displayed radius. Its duration counts down on player turns. / Reveals tiles within its radius through the Umbra for the shown number of your turns.` | Keeps the shown distance without a shape noun. |
| Grimoire article | `data/grimoire.json#keyword:vision` | `Expands the light around you for the displayed number of turns. / Widen your sight radius by that much for the shown turns. It creates no Light.` | Keeps the shown distance without a shape noun. |
| Grimoire article | `data/grimoire.json#combat:worldspines.body[0]` | `Tharokh marks a line of tiles between you and it. After every second turn of yours, Tharokh's marked tiles rise as Outcrops unless something immovable is on them. At half Health they rise after each of your turns.` | Tharokh marks tiles between you and it. The rest of the paragraph remains as authored. |
| Grimoire article | `data/grimoire.json#combat:area_force.body[0]` | `An area force pushes or pulls every enemy within its radius of a center: you, or a tile you choose. Each enemy moves along its own straight line away from (Push) or toward (Pull) the center, using the normal Push and Pull rules. An enemy standing on a Pull's center stays put.` | Uses the shown distance from the center and movement directly toward or away from it. |
| Grimoire article | `data/grimoire.json#keyword:upheaval.body[0]` | `Marked tiles rise as Outcrops when the rule fires. A unit on a rising tile is pushed to a free tile beside it; the tile stays flat if a wall, a trap, a brazier or a unit that can't be pushed off is on it. Outcrops can be broken like any terrain, so a ring of them can be broken from inside.` | Outcrops can be broken like any terrain, even from inside when they surround you. |
| Battlefield rule HUD / turn rail | `data/battlefield_rules.json#slagmaster.sentence` | `After every second Slagmaster turn, its Fire spreads 1 tile toward you.` | Retains the existing direction and 1-tile spread. |
| Battlefield rule HUD / turn rail | `data/battlefield_rules.json#snare_fire.sentence` | `After each of your turns, the Fire spreads 1 tile away from the entry.` | Retains the existing direction and 1-tile spread. |
| Skill or relic tooltip | `data/skills.json#witchlight.description` | `Your @icon(illusion) have +1 @icon(illuminate) radius while they last.` | Illusions shed Light the stated number of tiles farther while they last. |
| Skill or relic tooltip | `data/relics.json#witchglass_lantern.description` | `Your @icon(illusion) have +{radius} @icon(illuminate) radius while they last.` | Illusions shed Light the stated number of tiles farther while they last. |
| Light tile tooltip | `scripts/combat_board_view.gd / Light Source` | `Reveals Umbra within %d tile%s.` | `@pattern(diamond:{radius}) Reveals these tiles through the Umbra.` |
| Tethered Light tile tooltip | `scripts/combat_board_view.gd / _tethered_light_tooltip` | `Tethered Light — Radius %d` | `Tethered Light. @pattern(diamond:{radius}) Reveals these tiles through the Umbra. Contributor lines and expiry remain.` |
| Relic tooltip | `data/relics.json#winters_spur.description` | `Each straight line of Ice you move across costs only 1 Movement. Turning starts a new line.` | `Uses movement without turning or contact along the direction.` |
| Relic tooltip | `data/relics.json#galehook_talon.description` | `Your Push and Pull move the target together with every enemy touching it in a line along that direction. Only the front one collides.` | `Uses movement without turning or contact along the direction.` |
| Card catalogue | `data/cards.json#waning_pulse.description` | `Deal 3 to each adjacent enemy and push them 1.` | `Deal 3 damage and push each enemy hit 1 tile.` |
| Card catalogue | `data/cards.json#whirlwind_slash.description` | `Strike all adjacent tiles for 8.` | `Strike for 8.` |
| Card catalogue | `data/cards.json#lantern_shot.description` | `Deal 3 at range 3, then create radius-2 Light at the impact for 2 turns. Draw 1.` | `Deal 3 at range 3, then create Light 2 at the impact for 2 turns. Draw 1.` |
| Card catalogue | `data/cards.json#guiding_flare.description` | `Deal 3 at range 3, then leave Fire and radius-2 Light for 2 turns.` | `Deal 3 at range 3, then leave Fire and Light 2 for 2 turns.` |
| Card catalogue | `data/cards.json#storm_beacon.description` | `Deal 3 Lightning damage with Chain 2 at range 3, then leave Electrified and radius-2 Light for 2 turns at the impact.` | `Deal 3 Lightning damage with Chain 2 at range 3, then leave Electrified and Light 2 for 2 turns at the impact.` |
| Card catalogue | `data/cards.json#needle_flurry.description` | `Strike the three tiles in an arc in front of you for 5.` | `Strike 3 tiles for 5.` |
| Card catalogue | `data/cards.json#threaded_path.description` | `Move 3. Create radius-1 Light where you arrive for 2 turns, then draw 1.` | `Move 3. Create Light 1 where you arrive for 2 turns, then draw 1.` |
| Card catalogue | `data/cards.json#ember_rain.description` | `Deal 3 in a cross pattern at range 3, then create radius-2 Light at the impact for 2 turns.` | `Deal 3 at range 3, then create Light 2 at the impact for 2 turns.` |
| Card catalogue | `data/cards.json#cyclone_seal.description` | `Exhaust. Choose a tile within range 3. Pull every enemy within 3 of it up to 3 tiles toward it, then deal 9 to each enemy next to it.` | `Exhaust. Choose a tile within range 3. Pull enemies within 3 tiles of it up to 3 tiles toward it, then deal 9 damage.` |
| Card catalogue | `data/cards.json#cinder_bloom.description` | `Deal 2 in a cross at range 2, then leave Fire in the pattern. Empower (Exhaust): the pattern becomes a radius-2 diamond.` | `Deal 2 at range 2, then leave Fire. Empower (Exhaust) increases the area reach to 2.` |
| Card catalogue | `data/cards.json#inferno_ritual.description` | `Deal 3 in a cross at range 2, then Detonate 9 in that pattern.` | `Deal 3 at range 2, then Detonate 9.` |
| Card catalogue | `data/cards.json#molten_reach.description` | `Deal 4 along a three-tile line at range 2, then leave Fire along it.` | `Deal 4 across 3 tiles at range 2, then leave Fire.` |
| Card catalogue | `data/cards.json#rime_shard.description` | `Deal 2 Ice damage along a two-tile line at range 2, then leave Ice.` | `Deal 2 Ice damage across 2 tiles at range 2, then leave Ice.` |
| Card catalogue | `data/cards.json#shatterline.description` | `Pierce a three-tile line for 5 Ice damage at range 2. Empower (+2 Time): the line is five tiles.` | `Pierce 3 tiles for 5 Ice damage at range 2. Empower (+2 Time): 5 tiles.` |
| Card catalogue | `data/cards.json#glacier_pin.description` | `Deal 3 Ice damage along a two-tile line at range 2 and immobilize. Leave Ice in the line.` | `Deal 3 Ice damage across 2 tiles at range 2 and immobilize. Leave Ice.` |
| Card catalogue | `data/cards.json#spark_dart.description` | `Deal 4 Lightning damage at range 3, then leave Electrified and radius-1 Light for 2 turns.` | `Deal 4 Lightning damage at range 3, then leave Electrified and Light 1 for 2 turns.` |
| Card catalogue | `data/cards.json#spark_focus.description` | `Place a three-tile Electrified line at range 3, draw 1, then gain 1 Vision for 2 turns.` | `Place Electrified on 3 tiles at range 3, draw 1, then gain 1 Vision for 2 turns.` |
| Card catalogue | `data/cards.json#volt_surge.description` | `Deal 4 Lightning damage along a three-tile line at range 2, then leave Electrified.` | `Deal 4 Lightning damage across 3 tiles at range 2, then leave Electrified.` |
| Card catalogue | `data/cards.json#thunderline.description` | `Deal 6 Lightning damage along a three-tile line at range 2 with Chain 1. Electrified-assisted hits also Shock.` | `Deal 6 Lightning damage across 3 tiles at range 2 with Chain 1. Electrified-assisted hits also Shock.` |
| Card catalogue | `data/cards.json#squall_shot.description` | `Deal 2 in a cross at range 3 and push each enemy in it 1 away from the center. The enemy on the center is pushed away from you.` | `Deal 2 at range 3 and push each enemy hit 1 away from the center. The enemy on the center is pushed away from you.` |
| Card catalogue | `data/cards.json#grave_mortar.description` | `Strike adjacent tiles for 9, then leave Rubble there.` | `Strike for 9, then leave Rubble.` |
| Card catalogue | `data/cards.json#spike_mantle.description` | `Pierce adjacent tiles for 8, or 12 against targets on Rubble. Expend adjacent Rubble to gain 4 Stoneskin.` | `Pierce for 8, or 12 against targets on Rubble. Expend Rubble to gain 4 Stoneskin.` |
| Card catalogue | `data/cards.json#tectonic_maul.description` | `Move 1, then strike for 11, or 15 against a target on Rubble. Leave a cross of Rubble at the impact and Stagger 3.` | `Move 1, then strike for 11, or 15 against a target on Rubble. Leave Rubble at the impact and Stagger 3.` |
| Card catalogue | `data/cards.json#grave_cleave.description` | `Strike the three tiles in an arc in front of you for 8 and Expose 3.` | `Strike 3 tiles for 8 and Expose 3.` |
| Card catalogue | `data/cards.json#unsealed_gale.description` | `Exhaust. Push every enemy within 3 of you 3 tiles away.` | `Exhaust. Push enemies within 3 tiles of you 3 tiles away.` |
| Card catalogue | `data/cards.json#tombsplitter.description` | `Strike the first two tiles in a line from you for 14 and Stagger 3.` | `Strike 2 tiles for 14 and Stagger 3.` |
| Card catalogue | `data/cards.json#sweeping_haft.description` | `Strike the four diagonal tiles for 6 and Sunder 3.` | `Strike 4 tiles for 6 and Sunder 3.` |
| Card catalogue | `data/cards.json#phoenix_cleave.description` | `Exhaust. Lose 1 health. Strike adjacent tiles for 10, then Detonate 10 on those tiles.` | `Exhaust. Lose 1 health. Strike for 10, then Detonate 10 on those tiles.` |
| Card catalogue | `data/cards.json#ember_guard.description` | `Gain 10 Block, then leave Fire under each adjacent enemy.` | `Gain 10 Block, then leave Fire under enemies.` |
| Card catalogue | `data/cards.json#cinderweave_guard.description` | `Gain 5 Block, then strike adjacent tiles for 2 and leave Fire there.` | `Gain 5 Block, then strike for 2 and leave Fire there.` |
| Card catalogue | `data/cards.json#hoarfrost_shell.description` | `Gain 6 Block, then place a two-tile Ice line at range 2.` | `Gain 6 Block, then place Ice on 2 tiles at range 2.` |
| Card catalogue | `data/cards.json#borrowed_spark.description` | `Exhaust. Lose 1 health. Place a two-tile Fire line at range 3, draw 2, and gain 1 Card Play.` | `Exhaust. Lose 1 health. Place Fire on 2 tiles at range 3, draw 2, and gain 1 Card Play.` |
| Card catalogue | `data/cards.json#nail_bomb.description` | `Consume. Deal 4 in a cross at range 3 and Sunder 2.` | `Consume. Deal 4 at range 3 and Sunder 2.` |
| Card catalogue | `data/cards.json#windlass_volley.description` | `Deal 4 along a 2-tile line at range 3.` | `Deal 4 across 2 tiles at range 3.` |
| Card catalogue | `data/cards.json#beacon.description` | `Create radius-2 Light within range 4 for 3 turns, then draw 1.` | `Create Light 2 within range 4 for 3 turns, then draw 1.` |
| Card catalogue | `data/cards.json#blessed_salve.description` | `Exhaust. Heal 3, then create radius-2 Light on yourself for 2 turns.` | `Exhaust. Heal 3, then create Light 2 on yourself for 2 turns.` |
| Card catalogue | `data/cards.json#caltrops.description` | `Consume. Leave Rubble in a cross within range 2. Enemies in it Bleed 2.` | `Consume. Leave Rubble within range 2. Enemies on those tiles Bleed 2.` |
| Card catalogue | `data/cards.json#censer_swing.description` | `Strike all adjacent tiles for 5, then create radius-2 Light on yourself for 2 turns.` | `Strike for 5, then create Light 2 on yourself for 2 turns.` |
| Card catalogue | `data/cards.json#cinder_wall.description` | `Leave Fire on a 4-tile line within range 2, then gain 4 Block, or 8 if you stand on Fire.` | `Leave Fire on 4 tiles within range 2, then gain 4 Block, or 8 if you stand on Fire.` |
| Card catalogue | `data/cards.json#fan_of_knives.description` | `Deal 3 along a three-tile line at range 2.` | `Deal 3 across 3 tiles at range 2.` |
| Card catalogue | `data/cards.json#flame_jet.description` | `Deal 4 to the first 3 tiles in a line from you, then leave Fire on the farthest tile.` | `Deal 4 across 3 tiles, then leave Fire on the farthest tile.` |
| Card catalogue | `data/cards.json#frost_lane.description` | `Leave Ice on a three-tile line within range 3, then draw 1.` | `Leave Ice on 3 tiles within range 3, then draw 1.` |
| Card catalogue | `data/cards.json#frost_nova.description` | `Deal 4 Ice damage to each adjacent enemy, then leave Ice on all eight tiles around you.` | `Deal 4 Ice damage, then leave Ice on 8 tiles.` |
| Card catalogue | `data/cards.json#glacier_salts.description` | `Consume. Leave Ice in a cross within range 3.` | `Consume. Leave Ice within range 3.` |
| Card catalogue | `data/cards.json#hoarfrost_wall.description` | `Gain 8 Block, then leave Ice on each tile next to you.` | `Gain 8 Block, then leave Ice.` |
| Card catalogue | `data/cards.json#lamp_oil.description` | `Consume. Leave Fire on a three-tile line within range 3.` | `Consume. Leave Fire on 3 tiles within range 3.` |
| Card catalogue | `data/cards.json#spear_thrust.description` | `Strike in a 2-tile line from you for 6, or 10 against Immobilized targets.` | `Strike 2 tiles for 6, or 10 against Immobilized targets.` |
| Card catalogue | `data/cards.json#sun_flash.description` | `Gain 5 Block, then create radius-2 Light on yourself for 2 turns.` | `Gain 5 Block, then create Light 2 on yourself for 2 turns.` |
| Card catalogue | `data/cards.json#thunderclap.description` | `Strike all adjacent tiles for 5 Lightning damage and Push each enemy 1, then Electrify your tile.` | `Strike for 5 Lightning damage and Push each enemy hit 1, then Electrify your tile.` |
| Card catalogue | `data/cards.json#cinderburst.description` | `Deal 7 in a cross pattern at range 3.` | `Deal 7 at range 3.` |
| Card catalogue | `data/cards.json#earthen_rampart.description` | `Raise outcrops on a three-tile line within range 2, then gain 3 Stoneskin. Empower (Exhaust): the line is five tiles.` | `Raise outcrops on 3 tiles within range 2, then gain 3 Stoneskin. Empower (Exhaust): 5 tiles.` |
| Card catalogue | `data/cards.json#tremor.description` | `Strike in a radius-2 diamond for 4 and Stagger 2. Empower (+2 Time): Stagger 4.` | `Strike within 2 tiles for 4 and Stagger 2. Empower (+2 Time): Stagger 4.` |
| Card catalogue | `data/cards.json#wind_shear.description` | `Deal 3 along a three-tile line at range 2 and push each target 1 away from you. Empower (+2 Time): push 2 instead.` | `Deal 3 across 3 tiles at range 2 and push each target 1 away from you. Empower (+2 Time): push 2 instead.` |
| Card catalogue | `data/cards.json#bottled_gale.description` | `Consume. Push each adjacent enemy 3.` | `Consume. Push 3.` |
| Card catalogue | `data/cards.json#dust_devil.description` | `Expend a Rubble tile within range 3. Push each enemy next to it 2 away and Expose 4.` | `Expend a Rubble tile within range 3. Push 2 away and Expose 4.` |
| Card catalogue | `data/cards.json#ember_ward.description` | `Gain 5 Block, then leave Fire under each adjacent enemy.` | `Gain 5 Block, then leave Fire under enemies.` |
| Card catalogue | `data/cards.json#flash_powder.description` | `Consume. Create radius-3 Light within range 3 for 2 turns. Enemies within 2 of its center are Exposed 2.` | `Consume. Create Light 3 within range 3 for 2 turns. Enemies within 2 tiles of its center are Exposed 2.` |
| Card catalogue | `data/cards.json#flashsteam.description` | `Deal 3 in a cross at range 3. Expend Ice there; enemies that stood on it take 4 more.` | `Deal 3 at range 3. Expend Ice there; enemies that stood on it take 4 more.` |
| Card catalogue | `data/cards.json#gale_ward.description` | `Gain 5 Block, then push each adjacent enemy 1.` | `Gain 5 Block, then push 1.` |
| Card catalogue | `data/cards.json#grounding.description` | `Remove every Electrified tile within 2 of you. Gain 3 Stoneskin per tile removed (maximum 9).` | `Remove Electrified within 2 tiles of you. Gain 3 Stoneskin per tile removed (maximum 9).` |
| Card catalogue | `data/cards.json#hall_of_mirrors.description` | `Create a 2-health illusion on each empty tile next to you, then gain 3 Block.` | `Create 2-health illusions, then gain 3 Block.` |
| Card catalogue | `data/cards.json#hoarfrost_ward.description` | `Gain 5 Block, then leave Ice under each adjacent enemy.` | `Gain 5 Block, then leave Ice under enemies.` |
| Card catalogue | `data/cards.json#ice_sculpture.description` | `Create a 4-health illusion within range 3, then leave Ice on each empty tile next to it.` | `Create a 4-health illusion within range 3, then leave Ice.` |
| Card catalogue | `data/cards.json#immolation.description` | `Deal 3 to each adjacent enemy. Then Detonate 8 on every Fire tile within 1 of you, including yours. You take no damage from it. Empower (2 HP): detonate within 2.` | `Deal 3 damage. Then Detonate 8 on Fire within 1 tile of you, including yours. You take no damage from it. Empower (2 HP): Detonate within 2 tiles.` |
| Card catalogue | `data/cards.json#magma_vent.description` | `Expend a Rubble tile within range 3 to deal 7 there and to its 4 neighbors, then leave Fire there.` | `Expend Rubble within range 3 to deal 7 there and on 4 other tiles, then leave Fire there.` |
| Card catalogue | `data/cards.json#meteorfall.description` | `Mark a three-tile line within range 4. At the start of your next turn, each marked tile takes 8 and becomes Fire.` | `Mark 3 tiles within range 4. At the start of your next turn, each marked tile takes 8 and becomes Fire.` |
| Card catalogue | `data/cards.json#powder_keg.description` | `Consume. Place a 3-health keg within range 2. When destroyed, it deals 6 to its tile and each tile next to it.` | `Consume. Place a 3-health keg within range 2. When destroyed, it deals 6 damage.` |
| Card catalogue | `data/cards.json#refraction.description` | `Deal 4 at range 3. It also hits each enemy next to one of your illusions.` | `Deal 4 at range 3. It also hits enemies near your illusions.` |
| Card catalogue | `data/cards.json#rime_step.description` | `Move 3, then leave Ice under each adjacent enemy.` | `Move 3, then leave Ice under enemies.` |
| Card catalogue | `data/cards.json#rockburst.description` | `Destroy an outcrop or crate within range 3 to deal 6 to each enemy next to it, then leave Rubble in a cross there.` | `Destroy an outcrop or crate within range 3 to deal 6, then leave Rubble.` |
| Card catalogue | `data/cards.json#shatter.description` | `Deal 5 Ice damage at range 3. If the target was Frozen, also deal 5 to each enemy next to it.` | `Deal 5 Ice damage at range 3. If the target was Frozen, also deal 5 splash damage.` |
| Card catalogue | `data/cards.json#shatter_swing.description` | `Strike for 10 Ice damage. If the target is Frozen, also deal 6 to each enemy next to it.` | `Strike for 10 Ice damage. If the target is Frozen, also deal 6 splash damage.` |
| Card catalogue | `data/cards.json#shattered_reflection.description` | `Destroy one of your illusions within range 6 to deal 6 to each enemy next to it and create radius-2 Light there for 2 turns.` | `Destroy one of your illusions within range 6 to deal 6 and create Light 2 there for 2 turns.` |
| Card catalogue | `data/cards.json#static_ward.description` | `Gain 5 Block, then Electrify your tile and the tile of each adjacent enemy.` | `Gain 5 Block, then Electrify your tile and tiles under enemies.` |
| Card catalogue | `data/cards.json#stone_ward.description` | `Gain 5 Block, then leave Rubble under each adjacent enemy.` | `Gain 5 Block, then leave Rubble under enemies.` |
| Card catalogue | `data/cards.json#sunpath_stride.description` | `Move 4, leaving radius-1 Light on each tile you enter for 2 turns.` | `Move 4, leaving Light 1 on each tile you enter for 2 turns.` |
| Card catalogue | `data/cards.json#vortex.description` | `Choose a tile within range 3. Pull each enemy within 2 of it 2 tiles toward it.` | `Choose a tile within range 3. Pull enemies within 2 tiles of it 2 tiles toward it.` |
| Card catalogue | `data/cards.json#worldbreak.description` | `Destroy an adjacent Outcrop or Worldspine you raised to deal 10 to each enemy in the three-tile line beyond it and Stagger 2.` | `Destroy an adjacent Outcrop or Worldspine you raised to deal 10 across 3 tiles and Stagger 2.` |
| Card catalogue | `data/cards.json#worldspine.description` | `Exhaust. Raise a 4-health Worldspine on each empty tile next to a tile within range 3. At the start of each of your turns, each enemy next to a Worldspine takes 3.` | `Exhaust. Raise 4-health Worldspines within range 3. At the start of each of your turns, they deal 3 damage.` |
| Umbra HUD tooltip | `scripts/run_scene.gd / _refresh_umbra_subtitle` | `Personal vision: %d tile%s.` | `@pattern(diamond:{radius}:hero) Personal vision covers these tiles.` Unlimited vision retains its copy. |
| Grimoire article | `data/grimoire.json#combat:outcrops.body[3]` | `Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an outcrop you raised.` | The same sentence follows the adjacent blast and the three tiles beyond the outcrop diagrams. |
| Grimoire article | `data/grimoire.json / Melee and Ranged` | `Melee actions target adjacent or pattern-defined nearby tiles. Ranged actions require a legal range and line-of-sight path.` | The same sentence follows the adjacent tiles diagram. |

## Native handoff

Fade and Slagmaster use the director’s installed 282×168 recordings. Erupt uses the shipped `marked_burrow_grub.tlw`. The probe pins production tooltip content to the UI canvas and compares each contract region with the same surface transparent. Keeping the surface mounted preserves the live Unsealed Gale stack and each tooltip's loop. Each animated still waits for the middle frame at full opacity. At 1920×1080 and 100% UI scale, the live Unsealed Gale stack is 379 px high against a 1,044 px viewport limit. The headless check measures zero overlap in the one-card fixture and all five slots of the five-card fixture.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-13 && python3 tools/visual_probe_runner.py tools/txt13/capture.gd --task-id txt-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/txt13/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/txt-13/capture/manifest.json --overwrite-result-manifest
```

The tooltip probe writes 18 PNGs at 1920×1080 and 100% UI scale under `/private/tmp/labyrinth_codex/txt-13/capture`. The following command uses the tip-05 MovieWriter clock to record the three pinned combat tooltips. It writes a five-second, 30 fps, 1920×1080 H.264 CRF 22 MP4 and one matching mid-loop PNG for each tooltip under `/private/tmp/labyrinth_codex/txt-13/clips`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-13 && python3 tools/txt13/capture_clips.py
```

The proof uses fixture-only actor positions and facing from `loop_fixture.gd`, a 5×5 camera patch for both full barrage footprints, and the proof panel anchor and eight-frame settle from `capture.gd`. The clip camera places the panel beside the patch with 24 px of padding, then expands the crop to 16:9 and scales it to 1920×1080. The recorder skips render ticks spent waiting for a decoded texture, so the exported timeline keeps the original playback speed.

## Approved move copy

The before strings are from `b03efbc55` (txt-09). The diagram is drawn before the text in the after column. The short Lob tooltip in txt-09 used just the targeting sentence. The round 2 change restores the next-turn hit and Fire sentence to that tooltip as requested. The detailed move rows retain their existing resolved damage values.

| Surface | Before | After |
| --- | --- | --- |
| Fade | `Lands behind you if it can, otherwise next to you; Ambushes next turn.` | `Lands behind you if it can, otherwise next to you; Ambushes next turn.` |
| Lob tooltip | `A cross on you.` | `On your tile. Next turn they take the hit and become Fire.` |
| Slagmaster Lob tooltip | `A cross on you and one 2 tiles away.` | `On your tile and 2 tiles away. Next turn they take the hit and become Fire.` |
| Lob detailed move row | `Marks your tile and the 4 around it. Next turn: %d in the centre, %d around it, and they become Fire.` | `Marks these tiles, centred on you. Next turn: %d in the centre, %d around it, and they become Fire.` |
| Slagmaster Lob detailed move row | `Marks %d crosses. Next turn: %d in each centre, %d around them, and they become Fire.` | `Marks these tiles, centred on you and 2 tiles away. Next turn: %d in each centre, %d around them, and they become Fire.` |
| Erupt | `Emerges at its mark, or the nearest free tile.` | `Emerges at its mark, or the nearest free tile.` |
| Icefall marking | `Marks 3 tiles across yours. Next turn they take the hit and turn to Ice.` | `Marks these tiles. Next turn they take the hit and turn to Ice.` |
| Icefall landing | `Marked tiles take the hit and turn to Ice.` | `Marked tiles take the hit and turn to Ice.` |

## Files changed

### assets

- `assets/tooltip_loops/fade_gloam_stalker.tlw`
- `assets/tooltip_loops/fade_gloam_stalker.tlw.json`
- `assets/tooltip_loops/lob_slagmaster_barrage.tlw`
- `assets/tooltip_loops/lob_slagmaster_barrage.tlw.json`

### data

- `data/card_panel_text.json`
- `data/cards.json`
- `data/pattern_rule_text.json`
- `data/relics.json`
- `data/skills.json`
- `data/tooltip_loops.json`

### scripts

- `scripts/action_icon_library.gd`
- `scripts/aoe_pattern_view.gd`
- `scripts/aoe_pattern_view.gd.uid`
- `scripts/battlefield_rule_hud.gd`
- `scripts/board_tile_tooltip.gd`
- `scripts/card_focus_tooltip_stack.gd`
- `scripts/card_panel_text.gd`
- `scripts/card_widget.gd`
- `scripts/combat_board_view.gd`
- `scripts/enemy_mechanics/burst_trait_text.gd`
- `scripts/enemy_mechanics/death_burst_view.gd`
- `scripts/enemy_mechanics/split_trait_text.gd`
- `scripts/game_data.gd`
- `scripts/inline_icon_text.gd`
- `scripts/item_rules_text.gd`
- `scripts/pattern_text.gd`
- `scripts/pattern_text.gd.uid`
- `scripts/pre_battle_inspection_view.gd`
- `scripts/run_scene.gd`
- `scripts/surface_relic_rules.gd`
- `scripts/tooltip_loop_context.gd`
- `scripts/tooltip_loop_registry.gd`
- `scripts/turn_order_slots.gd`
- `scripts/ui_palette.gd`
- `scripts/ui_tooltip_panel.gd`

### tests

- `tests/board_surface_visual_probe.gd`
- `tests/board_tile_tooltip_test.gd`
- `tests/brs01_test.gd`
- `tests/card_display_overrides_test.gd`
- `tests/card_summary_fit_test.gd`
- `tests/enc03_lob_probe.gd`
- `tests/enc04_forecast_test.gd`
- `tests/enc04_lob_playback.gd`
- `tests/helpers/brs01_feedback_cases.gd`
- `tests/helpers/card_summary_fit_baseline.gd`
- `tests/helpers/int06_lob_inspection_cases.gd`
- `tests/mrk01_marked_probe.gd`
- `tests/suites/enc03_slag_suite.gd`
- `tests/suites/mrk01_marked_suite.gd`

### tools

- `tools/spl01/capture.gd`
- `tools/tooltip_loops/capture.gd`
- `tools/tooltip_loops/fixture.gd`
- `tools/tooltip_loops/patch_checks.gd`
- `tools/tooltip_loops/playback.gd`
- `tools/tooltip_loops/record.gd`
- `tools/tooltip_loops/record.py`
- `tools/txt13/capture.gd`
- `tools/txt13/capture.gd.uid`
- `tools/txt13/capture_clips.py`
- `tools/txt13/capture_contract.json`
- `tools/txt13/clip_capture.gd`
- `tools/txt13/clip_capture.gd.uid`
- `tools/txt13/loop_fixture.gd`
- `tools/txt13/loop_fixture.gd.uid`
- `tools/txt13/record_contract.json`
- `tools/txt13/shape_words.md`
