# Glossary rewrite (FINAL)

This is final: every Glossary decision in [decisions.md](decisions.md#glossary) has been applied. No game file, data or code was changed.

**Data file:** [glossary_rewrite.json](glossary_rewrite.json).
- It is a top-level wrapper: `{"final": true, "decisions": …, "source": …, "rules_head": "6fa01cbc3", "entries": [...]}`.
- Each object in `entries` keeps the same row schema: `id`, `current_name`, `current_definition`, `name`, `definition`, `words`, `changed`, `reason`, `evidence` (file:line), `aliases`, `merge_into`, `director_decision_needed`, plus an optional `note`.
- Deleted rows stay in the file, marked `"deleted": true`.
- New rows carry `"new_entry": true` and `"icon": null` (text-only).

**Sources:**
- Entries: `Labyrinth.worktrees/ux-03/data/glossary.json` (142 entries).
- Rules: checked at `peer-benchmark` HEAD `6fa01cbc3`. Its `scripts/` and `data/` are identical to the audit commit `0e3273caf`.

## Counts

| | |
| --- | ---: |
| Rows | 148: 142 existing + 6 new (`wait`, `turns`, `ice_pillar`, `movement`, `item`, `outcrop`) |
| Live entries | 145 (148 − 3 deleted) |
| Changed | 136 (including 3 deletions and 6 new rows) |
| Unchanged | 12 |
| By reason | accuracy 50 (3 are the deletions) · clarity 55 · consistency 20 · length 11 · unchanged 12 |
| Entry renames | 7 (below), plus one enemy-intent rename: Discharge → Arc Burst |
| Merges | 0: Swap Illusion is kept separate (Q4) |
| Deleted | 3: `raise_cover`, `reclaim_cover` (Q7) and `skill_layaway` (Q8) |
| Open director questions | 1: Outcrop vs Worldbreak, a code contradiction |

- Every definition is 20 words or fewer; the longest is 20.
- Word counting follows the audit: icons and numbers count as words, BBCode does not.
- Definitions avoid numbers that vary with section or depth scaling (`combat_engine.gd:101-102, 9032-9057`; `depth_rules.gd:66-71`). They say "the shown damage" instead.

### Conventions (accepted)

- **"next to"** means the 4 orthogonal tiles.
- **"attack"** means a direct hit; ground, Bleed, Collision and traps are not attacks.
- **"ground"** is the single noun for Fire, Ice, Electrified and Rubble.
- **Durations** are written in words, and their chips use the Turns entry.
- **Keyword names** are capitalized and referenced, never re-explained.
- **Fire and Ice** keep their shared element/ground names (Q2).

## New entries (decisions Q3, Q9 and the new-entry list)

| id | Name | Definition | Key evidence |
| --- | --- | --- | --- |
| wait | Wait | Each of your first 2 Card Plays left unused adds 5 Time to your next turn. | combat_engine.gd:54, 60, 3007-3016; tempo_relic_rules.gd:25-30; run_scene.gd:14190 |
| turns | Turns | Counts down at the start of each of your turns. The effect ends at 0; ∞ lasts all combat. | combat_engine.gd:2860, 5124-5156; action_icon_library.gd:1418, 1422, 1614, 1882-1890 |
| ice_pillar | Ice Pillar | Blocks movement and sight for 3 enemy turns. A unit forced into it takes 2 damage and shatters it. | enemy_mechanics/icefall.gd:11-12, 68-72, 80-103; data/enemies.json:2765-2766 |
| movement | Movement | Tiles you can walk each turn without a card or Time. Refills at the start of your turn; base 2. | combat_engine.gd:56, 2019, 2871-2872, 2905-2950, 2964-2985 |
| item | Item | A card equipped in one of your 2 item slots. It joins your deck and has Consume. | game_data.gd:70, 303-305; run_engine.gd:2364-2370; combat_engine.gd:1955-1970 |
| outcrop | Outcrop | Attackable terrain that blocks movement. Worldspines and Powder Kegs count as Outcrops. Plain ones also block sight and leave Rubble. | combat_terrain_rules.gd:18-29; terrain_card_rules.gd:20-41; combat_engine.gd:1663-1665; illusion_relic_rules.gd:146-147 |

- **Turns.** Code counts the hero's turns for every chip that exists today: Light, Vision, Truesight and Eclipse all tick in `_tick_umbra_player_activation`. So the definition says "your turns", not your draft's "the bearer's turns". A duration of N ends when your Nth turn from now starts.
- **Outcrop.** Powder Keg (data/cards.json:8162-8168) and Worldspine (data/cards.json:8766) raise through the same `outcrop` action. Mason's Plumb and Copper-Shod Staff already treat both as outcrops.
- **Movement.** The Movement HUD meter borrows the Move icon (`run_scene.gd:9847`). Like the Turns icon, a distinct icon is an art task.
- **Alias moved.** The `outcrop` alias moves from Raise Terrain to Outcrop. The action-to-icon map at `action_icon_library.gd:492` is unchanged.

## Accuracy fixes (all accepted)

The full old text is in the JSON; each row below says what was wrong.

| id | What was wrong | New definition | Key evidence |
| --- | --- | --- | --- |
| time | "each unused play takes 5": Wait is capped at the 2 base plays; bonus and banked plays never add it (audit finding) | Cards cost Time; the more you spend, the later your next turn. Playing under 2 cards adds Wait. | combat_engine.gd:3007-3016, 54, 60 |
| chilled (Grimoire copy) | Grimoire says "+2 … while on Ice", but relic Chill persists off Ice (audit finding). The glossary text was already right and now uses Expend. | Takes 2 more damage from attacks. An Ice attack Freezes it and Expends the Ice beneath. | surface_variety_relic_rules.gd:123-125; board_surface_rules.gd:153-160; fix grimoire.json:970 |
| shock | Not just the next non-movement action: all non-movement actions for the whole next turn | On its next turn, it can only Move or Blink. | combat_engine.gd:1087-1089, 2569, 7565-7570 |
| chain | The value is jump distance, not a jump count; it keeps jumping while a new target is in reach | Jump to a new target within that many tiles, repeating from each one. Electrified tiles relay the jump. | combat_engine.gd:11669, 11687-11718, 12298-12366 |
| bleed | Damage equals the Bleed value; it clears at the end of the bearer's turn, even mid-turn Bleed from Retaliate | Before each move or attack, it takes damage equal to its Bleed. Clears when its turn ends. | combat_engine.gd:125-126, 7472-7482, 7531-7551 |
| sunder | Removes at most N, not all Block and Stoneskin | Before damage, remove up to that much Block, then Stoneskin, from the target. | combat_engine.gd:4704-4720 |
| block | Enemy Block ends at the enemy's own turn start | Absorbs damage before Health. Lost at the start of its holder's next turn. | combat_engine.gd:2515-2516, 2861-2862 |
| immobilize | Omitted Swap | Can't Move, Blink or Swap during its next turn. | combat_engine.gd:1090-1091; maneuver_rules.gd:106-107 |
| anchored | Enemies can be Anchored; it also stops Wind | Push, Pull and Wind don't move it or cause a Collision. Yours lasts until your next turn. | enemy_mechanics/wind.gd:66-72; combat_engine.gd:7031-7032 |
| pull | A Pull that reaches its source does not collide | Move the target that many tiles straight toward the source. If blocked before reaching it: Collision. | combat_engine.gd:6757-6765 |
| detonate | Hits you and your illusions too (only Immolation spares you); Magma Vent and Basalt Kiln use Rubble as fuel | Expend the chosen Fire, or the shown ground. Hit everyone on those tiles and next to them once, including you. | combat_engine.gd:12022-12063; action_icon_library.gd:1316-1317 |
| health_cost | Paid after the card resolves; bypasses Block and Stoneskin | Lose that much Health when the card finishes. Block and Stoneskin don't prevent it. | combat_engine.gd:2003-2005; defense_relic_rules.gd:69-81 |
| health | Also marks max Health and terrain Health | At 0 Health a unit is defeated or terrain breaks. Your Health carries over between rooms. | combat_engine.gd:4787-4795, 4892-4910 |
| vision | Wrong: Vision widens sight radius and makes no Light | Widen your sight radius by that much for the shown turns. It creates no Light. | combat_engine.gd:5076-5090, 6658-6670 |
| eclipse | "Absolute Umbra" overstated: sight radius is 1, Light reveals, Dispel lowers it | The darkest Umbra stage: you see only 1 tile around you. Light still reveals; Dispel Umbra lowers it. | combat_engine.gd:91-99, 304-310 |
| umbra_eclipse | Omitted the damage and the 2-turn duration | Unprotected targets take the shown damage, then the Umbra becomes Eclipse for 2 turns. Light, Vision and Truesight protect you. | combat_engine.gd:6658-6726 |
| radiance | It is a card school and skill branch, not "protective light" | Cards and skills that counter the Umbra with Light, Vision, Truesight and Dispel Umbra. | grimoire_library.gd:651-652; skill_tree_library.gd:7 |
| reflect | Chain, Push/Pull and splash ranged hits are not reflected | Single-target ranged hits from more than 1 tile away bounce back to the attacker. Melee, area and Chain hits land. | enemy_mechanics/reflect.gd:13-16; combat_engine.gd:11895 |
| dive | Base numbers were baked into %d; the push goes to its right; the strike can miss | Flies straight at you, giving each unit it passes Push 1 to its right. Strikes if it lands beside you. | enemy_mechanics/dive.gd:79-121, 147 |
| flying | Collision immunity missing | Moves over Bramble and Ice Pillars. Ignores traps, ground and Collision damage. Push, Pull and Wind still move it. | combat_engine.gd:11399, 11470, 7003-7005 |
| charge | It declares at 3 and fires next turn; Shock removes 1; literal `<n>` | Gains Charge each use. At 3, its next intent is Arc Burst: lightning jumping between nearby units. Shock removes 1. | enemy_mechanics/capacitor.gd:6, 23-33, 115-116 |
| mirror | Uses base damage, first damaging action only, no riders; literal placeholders | Copies your last damaging card at base damage, without its effects. The copy is fixed when declared. | enemy_mechanics/mimic.gd:22-72, 136-139 |
| icefall | Omitted the damage and Ice Pillars | Marks 3 tiles across your tile. Next turn they take the shown damage; empty ones become Ice Pillars. | enemy_mechanics/icefall.gd:17-27, 50-72 |
| wind | Many units are immune without being Anchored; duration missing | After each of the next 2 enemy turns, Push every unit 1 tile downwind. Anchored units and bosses are immune. | enemy_mechanics/wind.gd:58-110 |
| tether | "for 4" hard-coded; "break the line" is wrong (standing in it doesn't break it) | Every unit between two aligned Arc Thralls takes the shown damage and Shock. Terrain between them stops it. | enemy_mechanics/tether.gd:14-26, 85-133 |
| veil | Chain, conduction and Sweeping Strike also hit; reach melee is blocked | You can target it only from an adjacent tile. Untargeted hits, like Area Attacks and Chain, still land. | enemy_mechanics/veil.gd:20-27 |
| erupt | Omitted damage on the mark | Emerges at the mark, hitting and displacing its occupant. Neighbors get Push 1. Leaves Rubble; gains Expose 2. | enemy_mechanics/burrow.gd:50-102 |
| burst | Hits all 8 surrounding tiles, not "next to"; leaves Fire | When it dies, it deals the shown damage to every unit in the 8 tiles around it, then leaves Fire. | enemy_mechanics/death_burst.gd:6-65 |
| terrain_burst | Faultline and Rockburst/Worldbreak destroy the terrain | Hits units around terrain pieces for the shown damage. Some uses destroy the terrain too. | combat_engine.gd:6514-6545; action_icon_library.gd:1397-1410 |
| detonate_cinders | Uses only its own marked Fire; the dragon can hit itself | Detonate the Fire on its last Cinder Marks. Everyone caught is hit once, the dragon included. | combat_engine.gd:6547-6620, 12088 |
| gale_force | Described the dead `gale_force` action, not the live Hollow Gale (implementation wires that intent to this icon) | Strikes everywhere within 2 tiles of the dragon with Push 2, then erupts along its last Razor Dive path. | data/enemies.json:1275-1299; combat_engine.gd:6626-6642 |
| guard_ally / heal_ally | "Another enemy" is wrong: the Surgeon and the Mirror can target themselves; Warden guards all | Gives the shown Block to one or more enemies, sometimes including itself. / Restores the shown Health to a wounded enemy, possibly itself. | combat_engine.gd:4081-4108, 4477-4503 |
| worldspines | The player raises them too | Attackable stone spires that block movement, not sight. Destroyed ones leave Rubble. Damage pulses out around them. | combat_engine.gd:6463-6513; data/cards.json:8732 |
| ember | Omitted the Scavenger and the death drop; "run currency" is wrong because the bank persists | Earned from kills and victories. Spend them on wares and levels. Dying drops them; recover them next run. | run_engine.gd:1282-1284, 1741-1744, 3608-3614; run_scene.gd:28789-28799 |
| loadout | Relics are not in the loadout | The menu for your gear, attuned magic, items and skills. Your gear, magic and items make up your deck. | run_engine.gd:2364-2370; character_menu_view.gd:83 |
| defiance | Not one rescue: floor(level/4) charges; restores 25% | Each charge turns lethal damage into 25% Health. You get 1 per 4 levels, refilled each run. | combat_engine.gd:10926-10938; progression_store.gd:998-1000 |
| fatigue | Amount and escalation missing | When you must draw from an empty draw pile, reshuffle your discard and lose 2 Health, +1 each time. | combat_engine.gd:53, 7765-7773 |
| moltshard | Was a requirement message, not a definition | Won from your first dragon each run. Trade 1 for 250 Embers, or spend 1 to reset your skills. | run_engine.gd:1285-1292; progression_store.gd:918-921, 1183-1192 |
| element_ice | "Chills exposed units" collides with Expose | Card element. Ice cards place Ice ground, and an Ice attack Freezes a Chilled target. | combat_engine.gd:11488-11505 |
| skill_sure_footed | The "Air Traps Push" clause is false: no check exists, and `protect_air_push` is never read | Once per combat, take no damage from the first @icon(traps) that hits you. | combat_engine.gd:7349-7370; skills.json:201-202 |
| skill_long_dawn | `@icon(time) +1` reads as Time; the unit is turns | Temporary @icon(illuminate), @icon(vision) and @icon(truesight) you create last 1 more turn. | combat_engine.gd:5160-5166 |
| skill_witchlight | "+1 radius" implied a base; the base is 0 | Your @icon(illusion) give off @icon(illuminate) 1 while they last. | combat_engine.gd:438-448 |
| skill_ghost_stride | Only free movement converts | Once per combat, activate to make your next free move a @icon(blink) of up to 2 tiles. | combat_engine.gd:2928-2942 |
| skill_plunderers_step | Card Move/Blink only, not free movement | The first time each combat a card's @icon(move) or @icon(blink) collects loot, gain 1 @icon(card_play). | combat_engine.gd:7844-7853, 1594-1595 |
| skill_prismatic_instinct | Missing the visible-tile requirement | Once per combat, place any ground on a visible tile within @icon(range) 4. Costs no @icon(card_play) or @icon(time). | combat_engine.gd:11620 |
| skill_discerning_eye / skill_deferred_choice | Boss rewards are excluded | …non-boss combat reward… / …next non-boss card reward. | run_engine.gd:1318, 1848 |

## Decision-driven definition changes

- **Charge (Q10):** "Gains Charge each use. At 3, its next intent is Arc Burst: lightning jumping between nearby units. Shock removes 1."
- **Swap Illusion (Q4):** kept separate with its own icon, defined by reference to Swap: "Swap with one of your visible illusions, anywhere unless a Range is shown." It needs no line of sight (`illusion_card_rules.gd:316-357`).
- **Sure-Footed (Q5):** the Air clause is dropped. "Once per combat, take no damage from the first @icon(traps) that hits you."
- **Hollow Gale (Q6):** defined from Vaeloryx's live intent (data/enemies.json:1275-1299): "Strikes everywhere within 2 tiles of the dragon with Push 2, then erupts along its last Razor Dive path." The implementation wires that intent to the `gale_force` icon. The dormant resolver (`combat_engine.gd:6626-6642`) is not described.
- **Expend (Q1):** confirmed. Spend stays for points and currency.

## Renames and blast radius

Each of these places must change to the new name.

1. **Thornwall → Bramble** (`bramble`). The Briar Weaver intent keeps the name Thornwall.
   - `action_icon_library.gd:14` (label)
   - `pre_battle_threat_tags.gd:46`
   - Definition copies: `enemy_mechanics/bramble.gd:97`, `bramble_view.gd:14`.
2. **Consume Ground / Consume Surface / "consume" (ground) → Expend** (`surface_consume`). The item keyword Consume is unchanged.
   - `action_icon_library.gd:32, 33, 34, 263, 374, 1079, 1469, 1546, 1966`
   - `board_surface_presentation.gd:42`
   - `combat_engine.gd:12120`
   - `run_scene.gd:34397`
   - `surface_relic_rules.gd:61` ("Spend Rubble · redirect")
   - cards.json descriptions: `dust_devil:7337`, `flashsteam:7518`, `frost_heave:7587`, `magma_vent:8047`, `plasma_arc:8128`, `pyroclasm:8177`, `spike_mantle:2250`
   - relics.json descriptions: `flint_edge:179`, `worldroot_idol:738`, `rimecatcher_vial:799`, `basalt_calendar:882`, `coalheart_crucible:906`, `black_sun_dial:1011`, `briar_winch:1360`, `ashen_brand:1647`, `crowncoal_heart:1786`
   - grimoire.json:683, 701, 924, 970, 979, 985 (title), 988, 1003 (title → "Ground Techniques"), 1006
   - Keep the verb off other concepts: `grimoire.json:842` (Mantle layers → "breaks"), `graftwright_view.gd:513`.
   - Delete `ux-03/scripts/glossary.gd:10, 43` (`TODO_DESIGN_GLOSSARY_CONSUME_PROSE`).
3. **Illuminate → Light** (`illuminate`)
   - `action_icon_library.gd:115`
   - grimoire.json:604 (title), 598
4. **Summon Minions → Summon** (`summon_minions`)
   - `action_icon_library.gd:242`
   - grimoire.json:231
5. **Kindle Ground → Cinder Marks** (`cinder_marks`)
   - `action_icon_library.gd:257`
   - `run_scene.gd:14469`, `14480`
6. **The Last Eclipse → Last Eclipse** (`umbra_eclipse`)
   - `action_icon_library.gd:287`
   - `pre_battle_threat_tags.gd:63`
7. **Character and Loadout / Character Loadout → Character** (`loadout`)
   - `action_icon_library.gd:313`
   - `run_scene.gd:3971`
   - `scenes/run_scene.tscn:132`
   - grimoire.json:70
8. **Storm Capacitor intent Discharge → Arc Burst** (Q10). Discharge stays the card keyword.
   - Player-visible:
     - data/enemies.json:3140 (intent name)
     - `enemy_mechanics/capacitor.gd:131` (step label "Discharge")
     - `enemy_mechanics/capacitor_view.gd:16` (badge "discharges chain lightning"; replace with the Charge glossary text)
   - Docs: `spec/enemies/storm_capacitor.md:13-14`. The historical handoff `spec/enemies/en06_implementation_handoff.md:12, 24-25` is optional.
   - Internal only, so optional:
     - intent id `"discharge"` at data/enemies.json:3139 and `capacitor.gd:24`
     - test messages `tests/en06_enemies_probe.gd:74, 87` and `tests/suites/en06_enemies_suite.gd:92, 127, 139, 145, 296` (no copy assertions)
     - capture names in `tests/en06_enemies_probe_contract.json:25, 59`.
   - Not this concept, so do not change: "Mirror: Discharge" (`en06_enemies_suite.gd:244`, the player card) and the card Discharge (`action_icon_library.gd:181`; card_mechanics_surfaces suite).
   - The `chain_discharge` alias moves from Chain to Charge, and `action_icon_library.gd:439` should map `chain_discharge` → `charge`.
9. **Duration chips → Turns** (Q3; text-only entry). These are the panels that currently resolve to Time:
   - `action_icon_library.gd:1418, 1422, 1614, 1882-1890`
   - relics.json @icon(time) used as a duration at lines 51, 462, 765, 927, 1059, 1300, 1332, 1497 (owned by the relic rewrite)
   - skills.json:583, 604, 683 (already reworded in this file).

### Spelling unifications (accepted)

- **Rooted → Immobilize/Immobilized:**
  - `action_icon_library.gd:1529`
  - `maneuver_rules.gd:34, 111`
  - `run_scene.gd:12631`
  - grimoire.json:809
  - The card names Rooted Kick and Rooted Stance stay.
- **Boss status row** (`run_scene.gd:12631`): "Guard" → Stoneskin and "Mantle" → Crystal Mantle.
- **True Sight / truesight → Truesight:**
  - `combat_board_view.gd:16675`
  - cards.json:403, 1447
- **Hollow Gale:** "The Hollow Gale" at grimoire.json:774 and "Arena Gale" at `pre_battle_threat_tags.gd:61` become Hollow Gale. The dragon epithet and the room name keep "the Hollow Gale".
- **Sweeping Strikes → Sweeping Strike:** grimoire.json:1015.
- **Card Play, always Title Case:**
  - grimoire.json:132 (title), 141, 142, 349, 359, 445
  - cards.json:39, 476, 2854, 3706, 3816, 4355, 4385, 4407, 4430, 4478, 4503, 4545, 5841, 6464, 7612, 7809
  - `action_icon_library.gd:93, 98, 1085`
  - `combat_engine.gd:1641`
  - `contextual_combat_tutorial.gd:265-266, 308-309, 337-338`
  - `grimoire_library.gd:934`
  - `run_scene.gd:9733, 13545, 13550, 15673`
  - Bare "play" also becomes Card Play: cards.json:3916, 4457; `action_icon_library.gd:106`; `contextual_combat_tutorial.gd:186-187, 194-195, 345-346, 359-360`; `run_scene.gd:13041, 13557, 13559, 24245`.
- **Embers, capitalized in prose:**
  - `combat_board_view.gd:8024`
  - `combat_engine.gd:7826`
  - `run_engine.gd:1742, 3734`
  - `run_end_recap_overlay.gd:240, 250, 253, 265, 293`
  - `run_scene.gd:1109, 16760, 29335, 32162`
  - `scavenger_shop_view.gd:678, 1136, 1138, 1140, 1251`
  - grimoire.json:53
- **Shard → Moltshard:** `dialogue_engine.gd:65, 128`.
- **"surface(s)" → "ground":**
  - `action_icon_library.gd:13, 27, 35, 180, 1308, 1315, 1329, 1364, 1491, 1603, 1606, 1650, 1967`
  - `burrow_view.gd:98, 106`
  - `game_data.gd:568`
  - grimoire.json:204, 299, 720, 799, 921 (→ "Ground"), 930/939/948 (→ bare names), 994, 997, 1009
  - relics.json: `breaking_wheel:2550`, `ion_spool:823`, `updraft_bottle:856`, `black_sun_dial:1011`, `crowncoal_heart:1786`
- **Step-tracker and threat-tag labels:** read the glossary names instead of hard-coding them.
  - `run_scene.gd:14439, 14461, 14465, 14467, 14471`
  - `pre_battle_threat_tags.gd:50, 51, 53, 59, 60`
- **Ice Pillar copy** follows the new entry: `icefall_view.gd:13`, `icefall.gd:102`.
- **Dead data:** delete `element_data.gd:29, 41, 53, 65, 77` (`short_label`; not player-visible).

## Gaps

- **Skill Point:** your text is kept and verified (`progression_store.gd:995-997`; `run_scene.gd:29664`).
- **Quarry Winch** (id `briar_winch`): "Your @icon(push) and @icon(pull) can Expend @icon(surface_rubble) under an enemy to move it in any of the 4 directions." (19 words). Rules:
  - `surface_relic_rules.gd:59-61` (the optional redirect variant)
  - `surface_relic_rules.gd:141-145` (the target enemy must stand on Rubble)
  - `surface_relic_rules.gd:164-166` (the Rubble under it is removed)
  - `combat_engine.gd:6788-6791` (any of the 4 cardinal directions)

## Implementation notes (unchanged; the code fixes belong to a separate unit per decisions.md)

**Copy that must follow these definitions.** These strings are pinned by the en01–en06 test suites:
- `reflect.gd:7`
- `bramble.gd:97` and `bramble_view.gd:14`
- `capacitor_view.gd:16`
- `mimic_view.gd:14`
- `action_icon_library.gd:1226-1230`
- `death_burst_view.gd:22`
- `wind_view.gd:172`
- `icefall_view.gd:13, 42`
- `lob_view.gd:33-34`
- `burrow_view.gd:82, 98`
- `run_scene.gd:12637`
- `card_widget.gd:1365`

**Dive formatting.** `action_icon_library.gd:654-662` must stop %-formatting the Dive definition.

## Open director question (code contradicts a decision)

1. **Outcrop vs Worldbreak.** The decision says Powder Kegs count as Outcrops. Mason's Plumb and Copper-Shod Staff already count them, but Worldbreak's "outcrop you raised" (`owned_outcrop_only`) cannot target a Powder Keg: `OWNED_OUTCROP_KINDS` is crag_outcrop + worldspine (`terrain_card_rules.gd:26, 178-179`). Either add powder_keg to that list in code, or word Worldbreak's token to exclude kegs.
