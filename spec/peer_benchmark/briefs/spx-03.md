# spx-03 — The Warband in combat, and standard fights are always Defeat All

## Header
- **Owner, enc-specials (approved 2026-10-21):** "have the leader always be a specific enemy ... a little bit of flavor
  attached to each ... [standard combat] is always just defeat all the enemies."
- **Proposal:** https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX (section The Warband; diagram "warband").
- **Protected director data:** `data/special_encounters.json`, installed by spx-02 from
  `spec/peer_benchmark/staged/spx/special_encounters.json`. If spx-02 hasn't landed when you start, read the staged
  copy through the same library path. Use the `warband` type's fields: captain, escort, title, command,
  keep_distance, start_distance, stoneskin_by_tier, hp_multiplier and break_line. The variant `order` fields are
  **not** in this unit; they come in spx-04.
- **Contract with spx-02:** a special room arrives as `type: "special"`, `special_type: "warband"` and
  `special_variant: <biome>`. spx-02 owns the map, room entry, rewards and embers. You own everything from room
  generation to the end of combat.
- **Base:** integration HEAD. **Owned:** `room_generator.gd`, `combat_objective_rules.gd`, `combat_engine.gd`, enemy
  AI, `combat_board_view.gd`, `combat_objective_hud.gd`, `pre_battle_view.gd`, `pre_battle_inspection_view.gd`, the
  headless console fixture commands, `spec/encounters.md` and tests. spx-01 also touches analytics context builders,
  so keep your combat-engine edits away from them.

## Change
1. **Standard fights are always Defeat All** in layout revision 6 or later runs (`_type_for_room`). Earlier revisions
   keep their current roll exactly, proved by a golden-seed test.
2. **Warband room generation.**
   - The roster is the variant's captain plus its escort list: the first 3 at tier 1, 4 at tier 2, all 5 at tier 3. The
     tier is the existing depth band.
   - **Captain:** `is_leader`, max HP × `hp_multiplier` (1.25), Stoneskin `stoneskin_by_tier` (2/3/4). These replace
     Defeat the Leader's ×1.5 and 2+depth for Warbands only. No scale change: the board's pixel density stays exact.
   - **Placement** (hard rules, checked on every room):
     - the captain starts `start_distance` (4–6) tiles from the player's entry, using the game's own range metric;
     - it is never the closest enemy;
     - escort[0], the screen, stands on a shortest path between the entry and the captain;
     - the other escorts start within 3 tiles of the captain.
     Reroll up to 20 times with the room's seeded RNG, then use a deterministic legal fallback.
   - **The Dynamo** (an immobile Storm Capacitor) starts on the reachable tile farthest from the entry that still meets
     the rules.
3. **Command.** While the captain lives, a follower standing within 2 tiles of it deals +1 damage on every damaging
   action.
   - Its intent numbers and previews show the +1, so what you see is what lands.
   - **Floor banner:** the tiles within 2 of the captain get the leader marker's gold as an 18% fill, and the zone's
     outer edge a 2 px line in the same gold at 70%. It moves with the captain and goes when it dies. Use the existing
     gold token, not a new colour literal (UI identity gate).
4. **Keeps its distance.**
   - At the start of the captain's turn, if the player is within 2 tiles, it first steps 1 tile: to the reachable tile
     farthest from the player that keeps a follower between them, or just the farthest if none does.
   - Then it takes its normal intent, re-targeted as usual.
   - An immobile captain skips this.
5. **The warband breaks.** When the captain dies, the fight ends as Defeat the Leader does today, but visibly:
   - every follower runs up to 2 tiles toward its nearest board edge in one beat, then dissolves with the existing enemy
     dissolve, silently;
   - Ember Ticks don't burst;
   - followers drop nothing individually (spx-02 pays the room);
   - `break_line` ("The warband breaks!") shows once, in the existing combat announcement style;
   - no new sound: the existing victory flow plays.
6. **Titles.** Add a per-instance display name, and give the captain the variant title wherever an enemy's name shows:
   - action captions ("The Stormcaller: Gust Bolt");
   - the turn order, tooltips and the pre-battle foe card;
   - the objective title and heading, as "Defeat the Stormcaller", with a lowercase "the" in running text.
   The objective tooltip: "Kill the captain and the rest flee. Followers within 2 tiles of it deal +1 damage."
   Everything else keeps the definition name. The leader marker stays as it is.
7. **Fixture.** Add a headless console and inspection-fixture command that starts a Warband room for any biome and tier
   from a seed, for tests and proof.
8. **Balance and analytics.** Check `spec/card_balance_heuristic.md`. If the scorer reads encounter assumptions these
   rules change, update the spec and scorer together; otherwise say so. Combat outcome events stay as they are, and
   any new field is additive.

## Keep
Guardian and dragon rooms (still Defeat the Leader with no extra scaling), every other objective, earlier revisions'
behaviour, save and load mid-combat in a Warband room, and the reduced-motion paths (the break's run becomes an
instant dissolve).

## Proof
- Headless:
  - all six variants at all three tiers × 200 seeds, with the placement rules asserted on every room;
  - command +1 on intents and on resolved damage;
  - the keep-distance step, including with a blocked screen;
  - the break: followers removed, no Tick burst, no per-follower embers;
  - title resolution in every naming path;
  - golden seeds for standard fights in revisions 3–5;
  - save and load mid-Warband.
- Windowed, run by the director, at 1920×1080 and 100% UI scale, for the Stormcaller (air, tier 2) and the Dynamo
  (lightning, tier 3): the pre-battle, the first player turn with the banner and +1 intents, a keep-distance step, and
  the moment the warband breaks. List the exact commands.

## Out of scope
The map, rewards and embers (spx-02), the variant orders (spx-04), and the other special types.
