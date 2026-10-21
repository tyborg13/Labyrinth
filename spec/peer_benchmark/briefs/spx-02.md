# spx-02 — Special encounters on the section map: placement, emblems, legend, tooltips and rewards

## Header
- **Owner, enc-specials (approved 2026-10-21):** "have them be unique encounters similar to our guardians, but not
  restricted to a certain path ... they can have their own icon on the map, so you know what you're getting into ...
  maybe you get guaranteed higher rarity or more choices or more embers." Hoarder: "reuse enemies for now."
- **Proposal:** https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX (sections Special encounters, Rewards, Placement).
  The map mockup is `/Users/borgerding/workspace/Labyrinth/output/encounter-redesign-2026-10-20/mock_special_map.png`.
- **Protected director data:**
  - `spec/peer_benchmark/staged/spx/special_encounters.json` → install as `data/special_encounters.json`, byte for byte.
    It defines placement, rewards, and per type: enabled, name, emblem, tooltip line, objective, bonus and variants.
  - `spec/peer_benchmark/staged/spx/emblems/{warband,umbral_snare,ember_hoarder,last_light}.png` →
    `assets/art/icons/map/`, byte for byte, with `provenance.json` beside them and a hash test.
  - Unclear semantics → `TODO_DESIGN_<field>`.
- **Base:** integration HEAD. **Parallel units:** spx-01 (measurement; owns `analytics_store.gd` and its context
  builders) and spx-03 (the Warband's combat rules; owns `room_generator.gd`, `combat_objective_rules.gd`,
  `combat_engine.gd`, enemy AI, `combat_board_view.gd` and the pre-battle views).
- **Owned here:**
  - `scripts/section_map_graph.gd`, `room_icon_library.gd`, `section_map_node.gd`, `section_map_panel.gd`,
    `section_map_skin.gd` and `chronicle_panel.gd` (labels only);
  - the room-entry and reward paths in `run_engine.gd` (`move_to_room`, `finish_combat`, `_generate_card_rewards`,
    `_equipment_drop_for_room`);
  - a new `scripts/special_encounter_library.gd`, the data, the emblems, `spec/section_map.md`, and tests.

## Contract with spx-03
A special node is saved as `type: "special"`, `special_type` (a key of `types`) and `special_variant` (the section
dragon's biome: earth, fire, air, ice, lightning or shadow). It counts as a fight everywhere `_is_fight` counts
combat. Room entry treats it like combat: pre-battle, then the room layout from `RoomGenerator`. spx-03 builds the
special room from those three fields. Until spx-03 lands, a special room may generate as a standard fight. The library
answers `definition(type)`, `variant(type, biome)`, `enabled_types()`, `display_name(room)` and `tooltip_line(room)`
for both units.

## Change
1. **Layout revision 6** for new runs. Revisions 3–5 keep their stored graphs and generation exactly; a golden-seed
   test proves it. In revision 6, after the type solver, convert standard combat nodes into special nodes:
   - Count per section: weighted 2 or 3 (`per_section_count_weights`), capped by the number of enabled types and by
     legal slots. With only the Warband enabled, every section has exactly one.
   - Eligible: rolled type `combat` (never a mystery, never a mystery that hides combat), at steps
     `first_step`..S−`last_step_from_boss`, not joined by an edge to a Guardian node, and at least
     `min_outgoing_edges[type]` exits for that type.
   - Constraints: each route passes at most 2 special nodes; at least 2 routes contain one when the count is 2 or more;
     at least one route has none; types are distinct within a section. Route fight budgets are unchanged.
   - Pick types and nodes with the section's seeded RNG; same seed, same map. Use bounded repair with a deterministic
     fallback, as the rest of the generator does.
   - In section VI's fog, special nodes are landmarks, like Guardians.
2. **Emblems.** Register `special_<type>` in `RoomIconLibrary` with the approved emblems. Draw them like other room
   emblems (`MapSkin.draw_medallion`, the same sizes and states as standard combat). Each is its own concept, so add
   them to `tests/test_icon_identity_policy.py`.
3. **Legend.** List only the room types the displayed section contains, in this order: Standard combat, Warband,
   Umbral Snare, Ember Hoarder, Last Light, Guardian combat, Event, Scavenger, Graftwright, Relic, Ember Hearth, Boss,
   Unknown room.
   - Keep one row. Space the entries evenly with gaps from 40 px down to 12 px so the row fits beside Scout.
   - Only if 12 px still doesn't fit, wrap to a centred second row and grow the legend frame to match.
   - Prove it with the fullest legal section.
4. **Tooltip and labels.**
   - The title is `"<Name> · <captain title>"` for the Warband (e.g. "Warband · The Stormcaller") and `<Name>` for the
     other types.
   - Below the title comes the type's `tooltip_line`, then the usual state line.
   - The chronicle and every other room-type label read the library's name.
5. **Rewards for a special room** (in `finish_combat` and the reward generation), when the room's goal was met:
   - 4 card choices instead of 3. If none of the four is Rare or better, re-roll the last slot from the same element
     filter at Rare or better.
   - Embers: `ember_multiplier` × the sum of `reward_embers` of the room's starting enemies, with the usual omen and
     depth scaling. This replaces the per-kill embers for that room.
   - The type's bonus. For the Warband, `equipment_drop` guarantees the room's equipment drop: force one if the normal
     roll gave none, and reset the pity counter as a normal drop does. Implement the other bonus kinds when their types
     are enabled, not now.
   - When the goal failed (types with a failable goal, later), give the standard reward.
   - Never relics.
6. **Analytics.** Put `special_type` and `special_variant` in the room metadata that combat start and end already
   read, so spx-01's new context fields fill in. Don't edit `analytics_store.gd`.

## Keep
Everything about revisions 3–5, the route budgets and Guardian rules, mystery behaviour, Scout, recovery, save and load,
and the existing emblems and states. Map proofs keep their current assertions.

## Proof
- Headless: the map suite at 64 seeds × 6 sections for revision 6, with every constraint above checked exhaustively per
  section; golden seeds for revisions 3–5; reward unit tests for 4 choices, the rarity floor, the embers formula and the
  forced equipment drop; save and load of special nodes; and the icon policy test.
- Windowed, run by the director: the map with special nodes (available, future, visited and bypassed states, hover
  tooltip, focus), the fullest legend, and section VI's fog with a special landmark, all at 1920×1080 and 100% UI scale.
  List the exact commands.

## Out of scope
The combat rules of any special type, standard-fight objectives, and the Snare, Hoarder and Last Light rules (spx-03
onward).
