# Relic text rewrite (draft for director review)

Proposal only: `data/relics.json` and all code are unchanged. Source of truth for every row is `relic_rewrite.json` (same folder). Each clause was checked against the rules code; evidence is cited per row.

## Counts

| | Relics |
| --- | ---: |
| Total in `data/relics.json` | 112 |
| Active (shown to players) | 100 |
| Retired (redirected, text never shown; no rewrite) | 12 |
| Active with changed read-aloud text or name | 67 |
| Active unchanged (token syntax only) | 33 |
| Reason: accuracy | 9 |
| Reason: length | 12 |
| Reason: clarity | 30 |
| Reason: consistency | 16 |
| Names changed | 1 (Winter’s Spur → Winter's Spur) |
| Over the 25-word budget: before → after | 12 → 0 (max now 25) |

Word counts treat each concept token as one word (the ux-02 audit rule), and hyphenated values such as `radius-2` or `2-Health` as one word. `current_words` uses the same counter on the resolved current text, so it can differ by 1 from the audit table.

## Token convention used in `description` (needs director sign-off)

- `@term(key)`: the concept's icon followed by its glossary name, in keyword style. It counts as one word, reads aloud as the name and opens the glossary panel. Used at the **first mention** of resources, statuses, surfaces, Light and Illusion.
- `@kw(key)`: glossary name in keyword style, no icon, also opens the glossary panel. Used for action keywords (Push, Pull, Melee, Ranged, Move, Blink, Chain, Detonate, Pierce, Stagger, Quicken, Empower, Follow-up, Rite, Exhaust, Flurry, Consume, Retaliate, Collision, Draw, Dispel Umbra, Turn Clock, the Umbra, Wait, elements) and for every later mention of any concept.
- `|Form` selects an inflection the glossary would have to list: `@term(illusion|Illusions)`, `@term(freeze|Frozen)`, `@kw(detonate|Detonating)`, `@kw(umbra|the Umbra)`.
- Because names come from the glossary key, the parallel glossary rename flows into relic text without edits.
- Today `@icon(key)` renders the icon only (`scripts/inline_icon_text.gd:41-83`) and reads as its label (`plain_text`, line 85); the per-row `token_plan` records the icon/word decision for each concept, and `description_read_aloud` shows the result.
- Numbers are written as resolved literals. 13 active relics currently bind values through `{placeholders}` (`current_uses_placeholders`); keep those bindings when wiring.

## Accuracy fixes (current text disagrees with the code)

| Relic | Old (read aloud) | New (read aloud) | Evidence |
| --- | --- | --- | --- |
| Pilgrim Boots | Gain Move +1 each turn. Your movement creates Illuminate 1 Time 2 along its path; Blink covers both endpoints. | Gain 1 more movement each turn. Moving leaves radius-1 Light for 2 turns on tiles you enter, unless the card attacks. Blink lights both ends. | `scripts/combat_engine.gd:889-890`, `scripts/combat_engine.gd:1838-1850`, `scripts/combat_engine.gd:1864-1870` |
| Coffin Nails | When your Block stops all of an enemy attack's damage, the attacker gains Bleed 1. | When an enemy attack hits your Block and deals no Health damage, the attacker gains Bleed 1. | `scripts/common_relic_rules.gd:120-130`, `scripts/combat_engine.gd:11982-11984` |
| Ember Siphon | When an enemy dies while standing on Fire, Fire spreads to each empty tile next to where it fell. | When an enemy dies on Fire, Fire spreads to each tile next to it without Fire, Ice or Electrified. | `scripts/surface_variety_relic_rules.gd:141-149`, `scripts/combat_engine.gd:12130` |
| Rimecatcher Vial | When your attack applies Freeze, you may Relocate Ground one consumed Ice tile beside the target. | When your Ice attack Freezes an enemy on Ice, you can spill that Ice onto a tile next to it. | `scripts/surface_relic_rules.gd:72-77`, `scripts/surface_relic_rules.gd:136-137`, `scripts/surface_relic_rules.gd:253-262` |
| Captured Noon | While you have 3 active Illuminate sources, lower The Umbra by 1 stage; with 6 sources, lower it by 2. | While 3 or more Lights are active, the Umbra is 1 stage lower; with 6 or more, 2 stages lower. | `scripts/combat_engine.gd:395-420`, `scripts/combat_engine.gd:476-488` |
| Cragbound Gauntlet | Ranged Earth spells raise a 3 Health outcrop at an empty ground target. | Your Earth Ranged and area attacks also raise a 3-Health outcrop on an empty floor target. | `scripts/game_data.gd:1364-1369`, `scripts/combat_engine.gd:11781`, `scripts/combat_engine.gd:11981` |
| Leaden Pommel | Attacks on cards that cost 5 or more Time Stagger 1. | Attacks on cards that cost 5 or more Time gain +1 Stagger. | `scripts/game_data.gd:1231-1239`, `scripts/game_data.gd:1335-1337`, `data/relics.json:2040-2068` |
| Briar Vambrace | When a card gives you Block, also gain Retaliate 1 until your next turn. | When a card gives you Block, also gain Retaliate 1, once per card. | `scripts/common_relic_rules.gd:65-75`, `scripts/retaliate_rules.gd:34-36` |
| Ashen Phylactery | When you Exhaust a card, gain Stoneskin equal to the Time you paid for it (max 5). | When you Exhaust a non-item card, gain Stoneskin equal to the Time you paid for it, up to 5. | `scripts/combat_engine.gd:2021-2022`, `scripts/defense_relic_rules.gd:138-144`, `scripts/item_relic_rules.gd:33-40` |

Accuracy-adjacent fixes filed under other reasons (see each row's `notes`):

- Thawing Charm (like Pilgrim Boots above and six retired relics) used the Time icon as a duration (`Illuminate 1 Time 2`). Time is the turn-clock resource only; durations now read 'for 2 turns'.
- Grounding Pin and Brightglass Lens add 1 to existing Chain (like Leaden Pommel's Stagger); text now says `+1 Chain`.
- Gale Tabi: a second Blink replaces the pending bonus (`surface_variety_relic_rules.gd:133-136`); now stated.
- Borrowed Hourglass: the ending turn's Time (including Wait) is deferred onto the extra turn (`tempo_relic_rules.gd:37-41`); 'Everything it costs' did not say which turn.
- Phoenix Ember pays out on any Defiance trigger, not only the charge it adds.

## Longest remaining descriptions

| Words | Relic | Description (read aloud) |
| ---: | --- | --- |
| 25 | Black Sun Dial | Store up to 3 consumed surfaces. Your next attack deals 2 more damage per surface. Fire: Fire beneath. Ice: Chilled. Electrified: Shock. Rubble: Stagger 2. |
| 25 | Borrowed Hourglass | The first time each combat you end your turn with a Card Play unused, take another turn at once. This turn's Time is added to it. |
| 25 | Cold Mirror | When you Freeze an enemy while you have 4 or more Block, trade all your Block for 1 Crystal Mantle layer per 4, up to 2. |
| 25 | Crowncoal Heart | Once per turn, your single-target hit on a tile without Fire, Ice or Electrified places Fire. Detonating 2+ Fire grants 6 Stoneskin, once per turn. |
| 25 | Hollow Puppet | Your Push and Pull can target your Illusions harmlessly. An Illusion that collides with an enemy shatters and deals its remaining Health to it instead. |
| 25 | Mirror Triptych | Up to 3 Illusions repeat your first attack each turn for half damage, rounded down. Each hits the nearest reachable enemy and loses 1 Health. |
| 25 | Pilgrim Boots | Gain 1 more movement each turn. Moving leaves radius-1 Light for 2 turns on tiles you enter, unless the card attacks. Blink lights both ends. |
| 25 | Unbound Pinion | Once per turn, when your Push or Pull moves an enemy 2 or more tiles or makes it collide, refill your movement and Draw 1. |
| 25 | Worldheart | At the end of your turn, convert up to 2 Block to Stoneskin. Gaining Stoneskin deals half, rounded down, to adjacent enemies, up to 4. |
| 24 | Fivefold Knot | Each element you play this combat ties a knot. 3 knots: your attacks Pierce. 4: also Chain 1. 5: every card grants 3 Block. |
| 24 | Gale Tabi | After you Blink, your next attack this turn deals 1 more damage per tile blinked, up to 4 more. A later Blink replaces it. |
| 24 | Galehook Talon | Your Push and Pull move the target together with every enemy touching it in a line along that direction. Only the front one collides. |

## Open questions for the director

Global:

1. **Token convention.** Approve `@term`/`@kw` (above) and counting each token as one word? Without it, icon + word at first mention would need `@icon(x) Word`, which costs two words and reads twice aloud.
2. **Light has no glossary concept.** 9 active relics wrote the Illuminate icon as a noun ('enemies in Illuminate'). Cards already say 'radius-2 Light' and the card condition 'if Target in Light' uses the Illuminate icon (`scripts/action_icon_library.gd:1104`). Proposed: add `light` (name Light, Illuminate icon).
3. **Wait has no glossary/icon entry** although the style guide names it as a keyword. Needed by Pocket Sundial.
4. **Move vs movement.** The Move keyword is the card action; the per-turn pool (HUD '2 / 3 movement') has no separate concept. Relic text uses plain 'movement' for the pool (Pilgrim Boots, Beaconrunner Spurs, Winter's Spur, Procession Lantern, Unbound Pinion). Add a Movement concept?
5. **Outcrop.** The glossary concept `raise_terrain` is named both 'Raise Terrain' and 'Outcrops'. 'Your outcrops' in Mason's Plumb and Copper-Shod Staff also covers your Worldspines and Powder Kegs (`forced_relic_rules.gd:43`, `illusion_relic_rules.gd:147`). Pick one name and define its scope.
6. **'consume' collides with Consume.** Consume is the item keyword ('Uses this item card once'); surfaces are also 'consumed' (Flint Edge, Basalt Kiln, Quarry Winch, Stormcoal Crucible, Ashen Brand, Worldroot Idol, Black Sun Dial). Lowercase 'consume' is used for surfaces here; rename one of them?
7. **Ice is two concepts.** The element and the surface share the name and both appear in Hobnail Cleats, Rimecatcher Vial and Winter's Hourglass. The surface carries its icon; the element is a plain keyword word.
8. **Item** has no glossary concept but appears in 5 relics (Quick-Draw Bandolier, Alchemist's Retort, Crown of Surplus, Ashen Phylactery, Quartermaster's Ledger).
9. **'+1 Chain' / '+1 Stagger' / '+1 Expose'** for additive modifiers vs 'Chain 1' for a flat value. Confirm the form.

Per relic:

- **Storm Capacitor** (`storm_capacitor`): Name collides exactly with the enemy 'Storm Capacitor' (data/enemies.json:3107). Rename the relic (candidate: 'Arc Capacitor') or keep?
- **Black Sun Dial** (`black_sun_dial`): 'Store up to 3 surfaces you consume' is exact but makes it 26 words (1 over). Accept 'consumed surfaces' (25) or allow 26?
- **Pocket Sundial** (`pocket_sundial`): Uses the 'Wait' keyword, which has no glossary entry or icon yet. Approve adding Wait to the glossary, or fall back to 'If you use both base Card Plays this turn, ...' (14 words)?
- **Copper-Shod Staff** (`copper_shod_staff`): 'Your outcrops' here (and in Mason's Plumb) also covers your Worldspines and Powder Kegs (illusion_relic_rules.gd:147). Define 'outcrop' in the glossary to include them, or name them in the text?
- **Mason's Plumb** (`masons_plumb`): 'Your outcrops' includes your Worldspines and Powder Kegs (terrain_kinds). Naming them pushes this to 27 words; prefer a glossary definition of 'outcrop' that includes them?

## Glossary alignment

`glossary_rewrite.json` did not exist when this draft finished, so names follow the current glossary labels (`scripts/action_icon_library.gd` KEYWORDS). If the rename lands, `@term`/`@kw` tokens pick up the new names; re-check `description_read_aloud`, word counts and the `|Form` inflections.

## Retired relics

12 retired ids redirect to an active relic through `GameData.resolve_relic_id` (`scripts/game_data.gd:405-413`), so their own text is never shown: mossbound_wraps → rubblewalker_greaves, cinderbrand_tongs → pitch_gloves, ion_spool → grounding_pin, voltaic_tuning_fork → copper_shod_staff, hollow_die → tallow_candle, moonless_compass → echoing_blade, dawnbrand_filament → fencers_gloves, glowstone_matrix → grave_dirt, true_north → bonded_set, dawnstitch_cord → martyrs_gorget, starless_astrolabe → changelings_rattle, witchglass_lantern → hollow_puppet. Their descriptions are dead data (six also misuse Time as a duration). Left unchanged; deleting them is a separate cleanup.
