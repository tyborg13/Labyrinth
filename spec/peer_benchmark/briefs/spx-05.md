# spx-05 — Umbral Snare: sealing doors, Sealbinders, the Umbral Gaoler and the hunters

## Header
- **Owner, enc-specials (approved 2026-10-21):** "have the one where you have to escape have a specific sort of
  composition of enemies ... maybe there's like a mini boss ... this is the shadow tried to trap you in a room and you
  have to escape."
- **Proposal:** https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX (section Umbral Snare; diagram "snare").
- **Protected director data:** `data/special_encounters.json` → `types.umbral_snare` (jailer, sealbinder,
  seal_after_player_turns, hunters_max, bonus, variants[].hunters and start_hunters). The variants' `pressure` fields
  are **not** in this unit; they come in spx-06.
- **Base:** integration HEAD, which has the map (spx-02), the Warband (spx-03) and measurement (spx-01). Use the
  Warband's shapes for special-room generation, titles and the fixture command.
- **Owned:** `room_generator.gd` and `combat_objective_rules.gd` (Snare paths only), `combat_engine.gd` (seals,
  hunters, escape bonus context), the reward bonus hook in `run_engine.gd` (`embers_per_open_door` only),
  `combat_board_view.gd` (seal chips and sealed doors), a new `scripts/snare_room_rules.gd`, the console and fixture
  commands, `spec/encounters.md`, `spec/analytics.md` (additive fields) and tests. spx-04 (Warband orders) runs in
  parallel and owns `scripts/enemy_mechanics/*`; don't touch those.

## Change (director decisions; exact)
1. **Enable the type.** Set `types.umbral_snare.enabled` to `true` in `data/special_encounters.json` and in its staged
   copy. That field only; the director authorizes it. Placement already requires 2+ exits.
2. **Doors.**
   - The objective is the existing Reach the Exit, with its exits built from the room's outgoing branches.
   - The **jailer door** is the exit with the shortest walking path from the entry (ties: the lower map lane). Every
     other exit is a **sealing door**.
   - Seal times come from `seal_after_player_turns` [2, 4], assigned to sealing doors from the shortest path to the
     longest. A room with exactly one sealing door uses 3.
   - Every exit is at least 5 path tiles from the entry, so no door can be reached on the first turn. Reroll the layout
     as the Warband does if this fails.
3. **Sealbinders.**
   - One per sealing door: the data's `sealbinder` unit (a Veilbound Acolyte, 4 HP) titled "Sealbinder", on the free
     tile beside that door's threshold, inside the room.
   - It never moves or attacks. Its only intent is **Seal**, which shows the turns left.
4. **The seal.**
   - At the end of the enemy round that follows the player's Nth turn, the door seals. It becomes impassable, its
     threshold stops being an exit, and its Sealbinder dissolves silently.
   - Kill a Sealbinder first and its door stays open for the rest of the fight.
   - The jailer door never seals.
5. **Display.**
   - Each sealing door gets a chip above it in the existing HUD chip style, reading `Seals · N` (the same format as
     `Wind · N`).
   - Its threshold tile is tinted with the existing Umbra/veil violet token.
   - A sealed door shows the dark seal tint on the door itself and has no chip.
   - When a Sealbinder dies, its chip leaves with it.
   - No new icon and no new colour literal (UI identity gate).
6. **The Umbral Gaoler.**
   - The data's `jailer` (a Chainbound Gaoler) titled "The Umbral Gaoler", with HP × `hp_multiplier` (2.0) and Stoneskin
     `stoneskin_by_tier`.
   - It starts on the jailer door's path, 1 tile inside the threshold, and keeps the Gaoler's normal intents and AI.
7. **Hunters.**
   - At the start of each enemy round, one hunter of the variant's `hunters` type enters on the entry door's threshold,
     or the nearest free tile. A list alternates.
   - At most `hunters_max` (3) in total.
   - With `start_hunters` (ice: 3), that many start on the tiles nearest the entry instead, at least 2 tiles from the
     player, and no more arrive.
8. **Escape and reward.**
   - Stepping onto any open exit's threshold escapes, as today, and commits that branch.
   - The Snare's goal is always met on escape.
   - Bonus `embers_per_open_door`: +6 embers for each exit still open at the moment of escape, the used one included.
     It's added to spx-02's special reward (4 cards with a Rare floor and 1.5× roster embers, where the roster is the
     Gaoler and Sealbinders).
   - Add analytics fields, additive: `doors_open_at_escape` and `sealbinders_killed`.
9. **Fixture:** `snare BIOME TIER [seed]` in the console and inspection fixture, as `warband` does.

## Keep
Reach the Exit in revision 5 and earlier, the Warband and its orders, the map, the rewards, saves (including mid-Snare,
with timers and hunters), and reduced motion.

## Proof
- **Headless:**
  - all six variants × three tiers × 200 seeds, with the door roles, seal times, Sealbinder and Gaoler placement and
    the 5-tile rule asserted;
  - seal timing at the exact enemy-round boundary;
  - a killed Sealbinder keeps its door open;
  - hunter arrival and cap, plus the ice start;
  - the escape bonus count;
  - save and load mid-Snare;
  - golden seeds for revision-5 Reach the Exit.
- **Windowed** (director, 1920×1080, 100% UI scale), fire tier 2:
  - the first turn with both chips;
  - the frame after the first seal;
  - a killed Sealbinder with its door still open;
  - the escape.
  List the exact commands.

## Out of scope
The per-section pressures (spx-06), Last Light, the Hoarder, new art and new icons.
