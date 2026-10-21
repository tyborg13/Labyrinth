# spx-06 — Umbral Snare: the room closes in (one pressure per section)

## Header
- **Owner, enc-specials (approved 2026-10-21):** the Snare is "the shadow tried to trap you in a room and you have to
  escape". The approved proposal gives each section its own way of closing in, so dodging and waiting lose value.
- **Proposal:** https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX (Umbral Snare, the "The room closes in" column).
- **Base:** integration HEAD with spx-05, map-03 and spx-07 merged (sealing doors, Sealbinders, the Umbral Gaoler, hunters,
  escape bonus; revision-7 maps; locked wind, real-frame hover caches).
- **Protected director data:** `spec/peer_benchmark/staged/spx-06/pressures.json` holds the six pressure objects (id,
  text, numbers). Replace `types.umbral_snare.variants[<biome>].pressure` with them in `data/special_encounters.json`
  and in the staged copy `spec/peer_benchmark/staged/spx/special_encounters.json` (the two stay byte-identical; a test
  checks it). Unclear semantics → `TODO_DESIGN_<what>`.
- **Owned:** `scripts/snare_room_rules.gd`, the Snare hooks in `combat_engine.gd`, `combat_board_view.gd` (pressure
  marks and the vision exemption), `scripts/enemy_mechanics/wind.gd` and `wind_view.gd` (a room-sourced wind and its
  chip label only), `scripts/enemy_mechanics/tether.gd` and `tether_view.gd` (live beams only), the objective tooltip
  line, the console and fixture commands, `spec/encounters.md`, `spec/analytics.md` (additive) and tests. Nothing else
  runs in parallel.

## Change (director decisions; exact)

### Common rules
1. Each Snare room runs its section's pressure, chosen by the variant (the room's biome). Pressures exist only in
   Snare rooms.
2. **Timing.** Every pressure that changes the board resolves at the end of the player's turn. It runs after the
   pending-escape check (a hero who escapes is gone, and nothing resolves) and before the enemy round. Seals keep
   spx-05's timing at the end of the enemy round. Wording below: "player turn N" is the player's Nth turn.
3. **Preview equals outcome.** During the player's turn, whatever the pressure will change at the end of this turn is
   shown, computed live from the current board. That is exactly what resolves when the turn ends. Tile marks use the
   marked-intent renderer's area style, as spx-04's Thornwall preview does (`bramble_view.gd` `presentation_for`); no
   new colour, icon or marker.
4. **Rules text.** The pressure's `text` is the last line of the Snare objective tooltip (the objective panel and the
   pre-battle objective heading share it).
5. **Analytics (additive).** `combat_ended` gets `snare_pressure` (the id; empty outside the Snare). Each pressure
   change emits one `snare_pressure` event with `{id, player_turn, tiles}` (tiles empty for headwind and Umbra).

### The six pressures (data id → rule)
6. **earth, `rubble_lane`:** "Each round, Rubble rises on one tile of your shortest way out."
   - At the end of each player turn, take the hero's cheapest walking path to any open exit threshold. Ignore units,
     count Rubble's movement cost (leaving Rubble costs 2), and break ties by spx-05's door order (shortest path, then
     the lower map lane).
   - Rubble is placed on the first tile of that path that is at least `min_steps_from_hero` (2) steps from the hero,
     isn't an exit threshold, has no Rubble yet, and can take Rubble (`BoardSurfaceRules.can_place`). If no tile
     qualifies, nothing happens.
   - Because cost counts, the next pick moves to whichever lane is now cheapest.
7. **fire, `fire_rows`:** "Fire spreads one row from the entry each round."
   - At fight start, measure every floor tile's walking distance from the entry threshold, ignoring units and surfaces.
     Store it, and never recompute it.
   - At the end of player turn N, Fire is placed (normal Fire rules: 2 on entry, 3 at turn start) on every tile at
     distance N − 1 that can take Fire, except exit thresholds.
   - Hunters still arrive as spx-05 places them.
8. **air, `headwind`:** "A headwind slides everyone 1 tile toward the entry at the end of your turn."
   - A persistent wind sourced by the room, not an enemy, using the existing wind mover, preview, collisions and
     anchoring (`wind.gd`). Push `tiles` (1), every player turn, never expiring.
   - Direction: from the room toward the wall the entry door is on.
   - Sealbinders are anchored, since they never move.
   - The wind chip under the turn order shows its direction arrow and reads `Headwind`, with no count.
9. **ice, `frost_thresholds`:** "The tile in front of each sealing door is Ice."
   - At fight start, before the first player turn, place Ice (normal Ice rules: Chilled while on it) on each sealing
     door's approach tile. That is the floor tile next to the threshold, inside the room, on the shortest path from the
     entry; ties go to the lower x, then the lower y.
   - It stays on even after the door seals.
10. **lightning, `live_tethers`:** "Crossing a live tether hurts and Shocks you."
    - During the player's turn, every tile of an Arc Thrall tether beam that is telegraphed for the coming enemy round
      (`tether.gd`'s planned beam, the same beam its telegraph shows) is live. The telegraph's look is being redesigned
      separately by the director (`../Labyrinth.worktrees/wbv-01`); don't change how it's drawn.
    - Each time the hero enters a live tile, by moving or by being moved, they take that beam's shown damage and Shock,
      exactly as if the beam had hit them.
    - The hero's movement preview shows that damage the way it shows Fire entry damage.
    - The beam still fires in the enemy round as today.
11. **shadow, `umbra_rings`:** "The Umbra closes in: every two rounds, your sight shrinks by 1."
    - At the end of every `every_player_turns` (2) player turns, the hero's Umbra vision radius drops by 1, down to
      `min_radius` (1). It starts at the room's normal radius for its section. Use the existing Umbra vision and its fog.
    - Exit doors, thresholds, seal chips and Sealbinders stay visible at any radius; the player must always know where
      the ways out are.

### Data (the director's staged pressure objects, imported as is)
```json
"earth":     {"id": "rubble_lane",       "text": "Each round, Rubble rises on one tile of your shortest way out.", "min_steps_from_hero": 2}
"fire":      {"id": "fire_rows",         "text": "Fire spreads one row from the entry each round."}
"air":       {"id": "headwind",          "text": "A headwind slides everyone 1 tile toward the entry at the end of your turn.", "tiles": 1}
"ice":       {"id": "frost_thresholds",  "text": "The tile in front of each sealing door is Ice."}
"lightning": {"id": "live_tethers",      "text": "Crossing a live tether hurts and Shocks you."}
"shadow":    {"id": "umbra_rings",       "text": "The Umbra closes in: every two rounds, your sight shrinks by 1.", "every_player_turns": 2, "min_radius": 1}
```

## Keep
spx-05's door roles, seal timing, Sealbinders, Gaoler, hunters and bonus; the Warband and its orders (the held wind
still belongs to the Stormcaller there); ordinary Fire, Ice, Rubble, wind and tether behaviour outside the Snare;
revision-5 Reach the Exit; saves (mid-Snare with each pressure's state); reduced motion.

## Proof
- **Headless:**
  - each pressure: exact tiles or slides at fixed seeds; preview equals outcome at the end of the turn; nothing
    resolves after an escape;
  - Rubble's lane switching once a lane is costlier;
  - fire distance rings fixed at fight start;
  - headwind collisions and the anchored Sealbinders;
  - Ice approach tiles and their tie-break;
  - live-tether damage on entering, both by moving and by being moved, plus its preview;
  - Umbra radius steps and the visibility exemptions;
  - save/load mid-Snare for each pressure;
  - the six variants × three tiers × 200 seeds still pass spx-05's matrix.
- **Windowed** (director; 1920×1080, 100% UI scale), tier 2, seed 83, one frame per variant on player turn 3 with the
  pressure's preview showing: `earth`, `fire`, `air`, `ice`, `lightning` (two Thralls aligned) and `shadow` (radius
  already shrunk). Add these to the Snare probe and list the exact command.

## Out of scope
Last Light, the Ember Hoarder, new art, icons or colours, tuning of the hunters or seals.
