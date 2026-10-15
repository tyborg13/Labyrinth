# Relic text rewrite

Final draft, aligned to the director's decisions (`decisions.md`, Relics section) and the final glossary (`glossary_rewrite.json`, `final: true`, 145 live entries). This is a proposal only: `data/relics.json` and all code are unchanged. Every row in `relic_rewrite.json` is the source of truth, and every clause cites the rules code.

## Counts

| | Relics |
| --- | ---: |
| Total in `data/relics.json` | 112 |
| Active (shown to players) | 100 |
| Retired (redirected, text never shown; no rewrite) | 12 |
| Active with changed read-aloud text or name | 72 |
| Active unchanged (token syntax only) | 28 |
| Reason: accuracy | 9 |
| Reason: length | 12 |
| Reason: clarity | 30 |
| Reason: consistency | 21 |
| Names changed | 1 (Winter’s Spur → Winter's Spur); Storm Capacitor rename pending your pick |
| Over the 25-word budget: before → after | 12 → 0 (max now 25) |
| Rows with `director_decision_needed` | 1 (Storm Capacitor) |

Each concept token counts as one word (the audit rule), and hyphenated values such as `radius-2` or `2-Health` count as one. `current_words` uses the same counter on the resolved current text.

## Decisions applied

- **Tokens:** `@term(key)` gives icon + glossary name at the first mention of resources, statuses, ground, Light and Illusion. `@kw(key)` gives keyword style with no icon. `|Form` selects an inflection. `description_read_aloud` shows the rendered text, and `token_plan` lists each concept's choice and glossary status.
- **Names from the glossary:**
  - Light, not Illuminate (key `illuminate`).
  - Expend for removing ground (key `surface_consume`), used by Flint Edge, Worldroot Idol, Basalt Kiln, Stormcoal Crucible, Black Sun Dial, Quarry Winch, Ashen Brand and The Breaking Wheel. Consume stays the item keyword (Quartermaster's Ledger).
  - **ground** is the family noun (Black Sun Dial, The Breaking Wheel).
  - **Movement** is the per-turn resource (Pilgrim Boots, Beaconrunner Spurs, Winter's Spur, Procession Lantern, Unbound Pinion).
  - **Item** and **Items** (Quick-Draw Bandolier, Alchemist's Retort, Crown of Surplus, Ashen Phylactery, Quartermaster's Ledger).
  - **Outcrops** (Copper-Shod Staff, Mason's Plumb, Cragbound Gauntlet). The glossary's Outcrop entry covers Worldspines and Powder Kegs, matching the code (`forced_relic_rules.gd:43`, `illusion_relic_rules.gd:147`). The Worldbreak follow-up in `decisions.md` changes no relic text: Worldbreak excludes Powder Kegs, but these relics include them.
  - **Wait** (Pocket Sundial: "If your turn ends with no Wait" matches `base_plays_waited == 0`, `tempo_relic_rules.gd:21-23`).
  - **Swap** (Glassway Compass now references Swap instead of re-explaining it as "trade places").
  - Bramble and Cinder Marks: no relic text names either.
- **Durations:** written in turns ("for 2 turns"), never with the Time icon.
- **Fire and Ice** keep their shared element/ground names (Q2). In Hobnail Cleats and Rimecatcher Vial, which name both, every Ice mention carries its own icon (element crest or ground), not only the first.
- **"+1 Chain":** used for additive bonuses (Brightglass Lens, Storm Capacitor, Grounding Pin; also +1 Stagger and +1 Expose).
- **Black Sun Dial:** 25 words with the exact rule: "Store up to 3 ground you Expend. Your next attack releases them: +2 damage each. Fire: Fire beneath. Ice: Chilled. Electrified: Shock. Rubble: Stagger 2."
- **Winter's Spur:** apostrophe fixed.

## Accuracy fixes (current text disagrees with the code)

| Relic | Old (read aloud) | New (read aloud) | Evidence |
| --- | --- | --- | --- |
| Pilgrim Boots | Gain Move +1 each turn. Your movement creates Illuminate 1 Time 2 along its path; Blink covers both endpoints. | Gain 1 more Movement each turn. Moving leaves radius-1 Light for 2 turns on tiles you enter, unless the card attacks. Blink lights both ends. | `scripts/combat_engine.gd:889-890`, `scripts/combat_engine.gd:1838-1850`, `scripts/combat_engine.gd:1864-1870` |
| Coffin Nails | When your Block stops all of an enemy attack's damage, the attacker gains Bleed 1. | When an enemy attack hits your Block and deals no Health damage, the attacker gains Bleed 1. | `scripts/common_relic_rules.gd:120-130`, `scripts/combat_engine.gd:11982-11984` |
| Ember Siphon | When an enemy dies while standing on Fire, Fire spreads to each empty tile next to where it fell. | When an enemy dies on Fire, Fire spreads to each tile next to it without Fire, Ice or Electrified. | `scripts/surface_variety_relic_rules.gd:141-149`, `scripts/combat_engine.gd:12130` |
| Rimecatcher Vial | When your attack applies Freeze, you may Relocate Ground one consumed Ice tile beside the target. | When your Ice attack Freezes an enemy on Ice, you can spill that Ice onto a tile next to it. | `scripts/surface_relic_rules.gd:72-77`, `scripts/surface_relic_rules.gd:136-137`, `scripts/surface_relic_rules.gd:253-262` |
| Captured Noon | While you have 3 active Illuminate sources, lower The Umbra by 1 stage; with 6 sources, lower it by 2. | While 3 or more Lights are active, the Umbra is 1 stage lower; with 6 or more, 2 stages lower. | `scripts/combat_engine.gd:395-420`, `scripts/combat_engine.gd:476-488` |
| Cragbound Gauntlet | Ranged Earth spells raise a 3 Health outcrop at an empty ground target. | Your Earth Ranged attacks and Area Attacks also raise a 3-Health Outcrop on an empty floor target. | `scripts/game_data.gd:1364-1369`, `scripts/combat_engine.gd:11781`, `scripts/combat_engine.gd:11981` |
| Leaden Pommel | Attacks on cards that cost 5 or more Time Stagger 1. | Attacks on cards that cost 5 or more Time gain +1 Stagger. | `scripts/game_data.gd:1231-1239`, `scripts/game_data.gd:1335-1337`, `data/relics.json:2040-2068` |
| Briar Vambrace | When a card gives you Block, also gain Retaliate 1 until your next turn. | When a card gives you Block, also gain Retaliate 1, once per card. | `scripts/common_relic_rules.gd:65-75`, `scripts/retaliate_rules.gd:34-36` |
| Ashen Phylactery | When you Exhaust a card, gain Stoneskin equal to the Time you paid for it (max 5). | When you Exhaust a non-Item card, gain Stoneskin equal to the Time you paid for it, up to 5. | `scripts/combat_engine.gd:2021-2022`, `scripts/defense_relic_rules.gd:138-144`, `scripts/item_relic_rules.gd:33-40` |

Accuracy-adjacent fixes filed under other reasons (see each row's `notes`):

- **Thawing Charm** used the Time icon as a duration (`Illuminate 1 Time 2`), like Pilgrim Boots above and six retired relics.
- **Grounding Pin** and **Brightglass Lens** add 1 to existing Chain, so they now say `+1 Chain`. Leaden Pommel's Stagger is in the table above.
- **Gale Tabi:** a second Blink replaces the pending bonus (`surface_variety_relic_rules.gd:133-136`).
- **Borrowed Hourglass:** the ending turn's Time, including Wait, is deferred onto the extra turn (`tempo_relic_rules.gd:37-41`).
- **Phoenix Ember:** pays out on any Defiance trigger, not only the charge it adds.

## Longest descriptions

| Words | Relic | Description (read aloud) |
| ---: | --- | --- |
| 25 | Black Sun Dial | Store up to 3 ground you Expend. Your next attack releases them: +2 damage each. Fire: Fire beneath. Ice: Chilled. Electrified: Shock. Rubble: Stagger 2. |
| 25 | Borrowed Hourglass | The first time each combat you end your turn with a Card Play unused, take another turn at once. This turn's Time is added to it. |
| 25 | Cold Mirror | When you Freeze an enemy while you have 4 or more Block, trade all your Block for 1 Crystal Mantle layer per 4, up to 2. |
| 25 | Crowncoal Heart | Once per turn, your single-target hit on a tile without Fire, Ice or Electrified places Fire. Detonating 2+ Fire grants 6 Stoneskin, once per turn. |
| 25 | Hollow Puppet | Your Push and Pull can target your Illusions harmlessly. An Illusion that collides with an enemy shatters and deals its remaining Health to it instead. |
| 25 | Mirror Triptych | Up to 3 Illusions repeat your first attack each turn for half damage, rounded down. Each hits the nearest reachable enemy and loses 1 Health. |
| 25 | Pilgrim Boots | Gain 1 more Movement each turn. Moving leaves radius-1 Light for 2 turns on tiles you enter, unless the card attacks. Blink lights both ends. |
| 25 | Unbound Pinion | Once per turn, when your Push or Pull moves an enemy 2 or more tiles or makes it collide, refill your Movement and Draw 1. |
| 25 | Worldheart | At the end of your turn, up to 2 Block becomes Stoneskin. Gaining Stoneskin deals half, rounded down, to enemies next to you, max 4. |
| 24 | Fivefold Knot | Each element you play this combat ties a knot. 3 knots: your attacks Pierce. 4: also Chain 1. 5: every card grants 3 Block. |
| 24 | Gale Tabi | After you Blink, your next attack this turn deals 1 more damage per tile blinked, up to 4 more. A later Blink replaces it. |
| 24 | Galehook Talon | Your Push and Pull move the target together with every enemy touching it in a line along that direction. Only the front one collides. |

## Director decision: Storm Capacitor rename

Rename required (decisions.md): 'Storm Capacitor' is also an enemy (data/enemies.json:3107). Pick one: (1) 'Widegap Cell' (recommended: the art shows a spark leaping between two terminals, and +1 Chain makes each jump reach 1 tile farther); (2) 'Leyden Cell' (matches the art: a brass coil cell with spark terminals); (3) 'Fulgurite Rod' (lightning-fused glass rod; fits the longer reach, less the art). None of the words Leyden, Widegap, Cell, Fulgurite or Rod appears in any card, enemy, relic, equipment, skill, event, NPC, upgrade, biome, grimoire or glossary name (data/*.json, glossary_rewrite.json, action_icon_library.gd labels). Avoided: Capacitor, Coil, Spark, Arc (Arc Burst intent), Bolt, Static, Relay, Jar, Charge.

The `name` field keeps "Storm Capacitor" until you pick a name. The relic's art (`assets/art/relics/storm_capacitor.png`) is a brass coil cell with a spark between two terminals.

## Remaining conflicts with the glossary draft

None of these block the wording, and none needs a decision unless you disagree.

1. **Next Attack.** That keyword means "your next attack on a later card this turn". Four relics deliberately say "next attack/card" in plain words because their timing differs:
   - Gale Tabi's bonus can apply later in the same card (`surface_variety_relic_rules.gd:139`).
   - Bloodmoon Chalice's is immediate (`defense_relic_rules.gd:104`).
   - Black Sun Dial's store persists across turns.
   - Echoing Blade's expires after the next card (`tempo_rules.gd:96-97`).
   Readers may still connect them to the keyword.
2. **Relocate Ground.** Rimecatcher Vial says "spill that Ice" (its UI variant label, `surface_relic_rules.gd:76`), not Relocate Ground. The relic re-places Expended Ice in a chosen direction, which is not the keyword's "move one ground tile to another open tile".
3. **Movement has no icon.** Movement is a resource, so the default would be icon + word, but the glossary entry has no icon. Its mentions are keyword style only. Switch the first mention to `@term` if it gets one.
4. **Inflections the glossary does not list as aliases.** The renderer needs these to resolve `|Form`:
   - `detonate` → Detonating (Crowncoal Heart)
   - `exhaust` → Exhausted (Pyre-Keeper's Urn)
   - `freeze` → Freezes (Rimecatcher Vial)
   - `illuminate` → Lights (Captured Noon, Unclouded Sun)
   - `illusion` → Illusions (Copper-Shod Staff, Eclipse Mantle, Glassway Compass, Hollow Puppet, Mirror Triptych, Procession Lantern, Witchglass Carapace)
   - `rite` → Rites (Crown of Surplus)
   - `umbra` → the Umbra (Captured Noon)
5. **Keyword overrides.** These are relic exceptions that the text states explicitly. No change proposed.
   - Health Cost ("Block and Stoneskin don't prevent it") vs Iron Lung, which pays it from Stoneskin.
   - Retaliate ("Until your next turn") vs Briar Throne ("no longer expires").
6. **Readability of "ground" as a noun.** "Store up to 3 ground you Expend" (Black Sun Dial) and "collides on ground" (The Breaking Wheel) follow the glossary convention but read unusually. Flag for the 1920×1080 capture review.

## Retired relics

12 retired ids redirect to an active relic through `GameData.resolve_relic_id` (`scripts/game_data.gd:405-413`), so their own text is never shown: mossbound_wraps → rubblewalker_greaves, cinderbrand_tongs → pitch_gloves, ion_spool → grounding_pin, voltaic_tuning_fork → copper_shod_staff, hollow_die → tallow_candle, moonless_compass → echoing_blade, dawnbrand_filament → fencers_gloves, glowstone_matrix → grave_dirt, true_north → bonded_set, dawnstitch_cord → martyrs_gorget, starless_astrolabe → changelings_rattle, witchglass_lantern → hollow_puppet. Their descriptions are dead data (six also misuse Time as a duration). They are left unchanged; deleting them is a separate cleanup.
