# Runtime feasibility audit — board surfaces

> Historical design record from the initial surface refactor. The current rules
> are in [DESIGN.md](DESIGN.md), version 5. In the feedback pass, Fire became
> 2 damage on entry / 3 at turn start, Chilled +2 attack damage, Frozen triple
> attack damage, and Rubble charges on departure. Ordinary Electrified survives
> conduction and Chain; Stormcoal Fire is still consumed. Lightning specialist
> Shock now requires an Electrified-assisted hit instead of separately paid fuel.
> The proposals below retain their original rationale and are not current rules.

Read-only audit, 2026-09-06. No game or source changes made.

Update after user follow-up: `DESIGN.md` supersedes the initial recommendations below for trap footprints (center damage plus cardinal wake), Fire creation (no immediate damage), Charge layering, and causal card-kill credit. The descriptions of the current runtime remain historical observations. Numbers below marked recommendations are proposed rules, not observed existing behavior.

## What the game does today

- Combat is an initiative queue, not a shared round. Player activation base delay is 9 plus played cards' Time; independent movement has no Time. Every player activation starts with 2 movement points. `finish_player_activation` schedules the next activation; `prepare_next_player_turn` clears Block, resets resources, resolves status start effects, then draws. Enemies clear Block and resolve statuses before their intent. Frozen enemies skip an activation (and its intent Time), then get a new intent.
- Move and navigation currently assume one orthogonal tile equals one movement point. This assumption is in `PathUtils.reachable_tiles/find_path`, player target validity, preferred navigation, prevalidated move validation, pool spending, enemy reachable anchors, actual paths and future route prefixes. Rubble cannot be implemented only as a path preference.
- Many enemies have Move 1: acolyte, warden, cinder ooze/droplet, bile bloomer, chainbound gaoler, grave surgeon, frostglass lancer and Zekarion have such intents. Permanent cost-2 ground would otherwise completely strand some of them.
- Player movement can be split and interleaved with cards. Its spent amount is presently resolved path length minus one; Blink spends Manhattan distance. Hidden actors truncate the path without revealing their position in previews. Loot is collected and traps resolve at each traversed step.
- Forced movement walks tile by tile and stops at blockers, actor death or combat end. It triggers traps at each step. Its distance is not paid from the moved actor's movement pool. Directed pushes must increase distance from the source; pulls must decrease it. Bodies with multiple occupied tiles are supported.
- There is no Chilled status. Freeze is a directly applied integer (max rather than additive). It immediately doubles incoming damage, including most status/trap damage, and decrements when it skips the affected actor's next activation. Shock removes nonmovement actions; Immobilize removes movement actions. Burn damages at activation start and decays by one natural unit. Poison stores damage plus a two-activation delay.
- Chain N means maximum Manhattan distance N for each jump, not number of jumps. It follows nearest unvisited living visible enemies; equal distances follow stable enemy-array order. It has no line-of-sight test, unlimited distinct targets within the connected chain, full damage and riders at each hit, and can jump onward from the location of a killed target. The recent presentation trace already records ordered enemy-to-enemy hits for animation.
- Traps are independent one-use objects. Movement onto a trap or direct/AOE attacks detonate a 3x3 blast, remove the trap, and affect player, enemies, illusions and destructible terrain. Boss cinder marks also use the trap collection. A trap owner can be immune to its own blast. Room generation creates 2–3 traps; earth traps currently apply Poison. Trap damage and visuals currently scale with intensity.
- AOE attacks currently require a live enemy, terrain or trap somewhere in their footprint and the resolver returns early without any of these. Empty-floor setup therefore needs an intentional target-validity and resolver change.
- Ordinary damage to an enemy currently always goes through `_damage_enemy`, which also awards death card plays, embers, kill statistics, on-kill relic rewards and death spawns. Source attribution must become explicit if passive surface damage is prohibited from producing card refunds or attack-specific benefits.
- The renderer has retained ground/path/world layers plus per-isometric-tile scene depth passes. New persistent effects should join these existing layers; a final flat screen-space overlay would repeat the depth problems fixed in the visual pass.

## Recommended invariants for the proposed design

### Ground and movement

1. Store surfaces separately from the base grid, blocking terrain, traps, loot and Light. Use deterministic tile keys and explicit kinds. Duplicate placement is idempotent: it neither increases strength nor retriggers contact.
2. Surface strength and duration have no stacks/counters. The proposed Fire, Ice and Charge effects are binary per tile; Rubble is a binary ground modifier. If Fire and Ice conflict, resolve the chosen replacement rule explicitly before checking contact. Rubble remains independently present. Treat Charge as an independent consumable overlay if the design allows it to coexist with either.
3. Rubble costs 2 movement to enter, regardless of actor footprint size. For a large actor a step costs 2 if any newly entered footprint tile has Rubble, otherwise 1. Leaving Rubble is not independently charged.
4. Use weighted shortest-path/reachability with exact movement cost, and keep movement cost distinct from tiles traversed. Pool spending uses actual resolved costs, whereas long-move relics and movement-light spacing can still use geometric distance if their text says tiles.
5. To prevent permanent Move-1 imprisonment, a fresh positive movement allowance may always make its first adjacent passable step into costly ground, ending that move if it could not afford the full cost. No debt persists. For the shared player movement pool this exception is tied to the fresh allowance, not each mouse click, to prevent split-click abuse.
6. Forced movement ignores the movement surcharge but triggers entry effects along its actual path. Blink ignores intervening ground and surcharge, but its landing triggers contact. No movement is stopped merely because a surface is harmful. Blockers and actors still stop movement.
7. AI must weigh exact surface danger and movement cost. Existing trap penalties treat traps as nearly forbidden (1000 plus damage); copying that penalty to persistent Fire would make common ground behave like a wall. Prefer safer equally effective routes, but accept a finite hazard cost when it advances the intended attack. Threat projections must execute the same costs, contact events, deaths and restrictions as actual resolution.

### Fire and simultaneous effects

- Proposed baseline: 1 damage for entering each newly entered burning tile, deduplicated to one hit per actor per movement step; 2 at that actor's activation start regardless of occupied footprint count. Creating Fire under an actor causes one contact hit after the printed attack, deduplicated per actor across the placement. Repainting existing Fire does nothing. Ordinary Fire does not also add Burn.
- This avoids the free-movement split-click loophole of a per-action cap. Repeated push/pull across Fire remains a real positional benefit paid for by the action resources; price it in the balance pass.
- Activation-start Fire should resolve after expired Block clears, before action restrictions, matching the existing start-of-activation structure. Persistent Stoneskin can still absorb it. Explicitly disable Freeze/Chill amplification, attack riders, vampirism and card-play refunds for passive surface damage. Preserve legitimate embers, objectives and kill statistics.
- Entry is based on new footprint tiles. An actor that shifts while keeping some of its body in Fire still receives only one contact hit for that step, and a stationary large actor receives only one start tick.
- Proposed Detonate: choose a printed pattern, snapshot and remove its Fire, form the union of all blast tiles, hit each preexisting actor once for printed damage (proposed 6). It does not multiply damage by overlapping Fire tiles or recursively consume all Fire reached by the blast.
- Resolve a shared blast as a batch before checking victory/defeat. Killing the encounter leader first must not cancel lethal simultaneous player damage. Death-spawn actors should not be silently included in the already-snapshotted blast. Fire newly created by another death effect cannot be recursively consumed by that cast.
- Keep explicit Detonate attack damage distinct from passive surface damage; printed attack modifiers can apply only according to authored rules, never by inheriting whichever card happened to create the Fire.

### Ice and Charge

- Ice contact on entry/new creation Chills; standing still or repainting the same Ice does not refresh it. The Ice attack checks whether the target was Chilled before that hit. Thus an attack creating Ice cannot both supply its own prerequisite and Freeze with the same hit.
- Make Frozen nonstacking and prohibit refreshing it while already Frozen. Consuming Chill on Freeze plus contact-only Ice avoids an automatic permanent-freeze loop for an actor stranded on the same Ice. Reapplying an identical existing tile must not count as creation. Specify when unconsumed Chill clears and whether it is a one-hit damage bonus; that is a new status design, not existing behavior.
- A consumable Charge relay is safer than persistent enter/start Shock, which would otherwise remove enemy attacks indefinitely. Charge need not hurt on entry. Use a deterministic path of visible charged tiles to bridge Chain, consume only the relay path actually used, and share one visited actor set across the whole chain/cast. Snapshot route tie-breaking before presentation.
- For larger actors, Chain range should be explicitly measured between closest occupied tiles or anchors; the current implementation uses anchors. Relay paths must not accidentally bypass permanent walls or reveal hidden actors unless deliberately authored. Keep no hidden board-wide charge bank.

### Presentation and exact simulation

- Resolve gameplay deterministically, then replay semantic events with positions, actor IDs and before/after deltas. Surface creation/consumption, tile contact, hazard tick, relay hop and blast union deserve explicit events rather than being inferred from unrelated HP differences.
- Preserve serial beats where cause matters (push steps/contact, chain hops, consume-then-blast). Start simultaneous AOE hit feedback together and overlap fading tails. Rule progression cannot wait on counter animations.
- Draw low floor textures/decals below units and targeting; place flame tips/sparks in existing per-tile back/front effect passes. Rubble uses silhouette/height, Ice reflective cracks, Fire low flames, Charge intermittent arcs. Use deterministic per-tile phases, restrained combined brightness, idle-loop frame sharing, visible-only updates and reduced-motion stable alternatives.
- Tile inspection should enumerate coexisting surfaces and exact movement/contact behavior, traps and items. Preview should show resulting surfaces, movement cost, forced-movement contact damage and exact chain route, without adding global surface meters.
- Surface placement, replacement, relay consumption and hazard effects must invalidate the relevant movement/intent/preview caches. New state keys also need retained-render dirty handling.

## Main implementation touchpoints

- `scripts/combat_engine.gd`: `create_combat` (755), targeting (973), movement plans (1163), `_apply_player_action` (1285), per-card completion (1574), activation scheduling/start (1815/2100/2371), movement pool spend (2462), intensity APIs (2611 onward), AOE resolver (4090), damage/death hooks (4150/4262), normalized actors (around 4700), immunity/keywords (5271/5698), Chain (5783), all movement helpers (6391–6631), preferred navigation (6667), traps (6745–6983), status ticks (7123 onward), enemy tactical/future planning (8657–9783), relic hooks (10000 onward).
- `scripts/path_utils.gd`: weighted traversal contract; avoid changing attack geometric distance or LOS when adding move cost.
- `scripts/combat_board_view.gd`: retained dirty keys (2129), ground and per-tile scene passes (2949–3017), ambient intensity system (4006 onward), path/risks (10276/11167), ordered tile rendering (12519), status and trap tooltips (13790/13886).
- `scripts/chain_attack_feedback.gd`: retain the now-readable hopping presentation; expand its event sources for relay nodes.
- `scripts/room_generator.gd`: room trap generation (942 onward) and Earth poison replacement; initial surfaces must preserve reachable exits and first-activation escape options.
- `scripts/run_engine.gd`: persisted combat/room state, legacy fixed-point conversion (around 488–558), postcombat persistence (around 2221). Strip retired intensity/poison runtime fields on migration, map removed IDs and upgrades, and reject or safely reset stale in-progress action/preview caches.
- `scripts/game_data.gd`, `action_icon_library.gd`, `enemy_intent_compass.gd`, `grimoire_library.gd`, analytics and full content/spec/test datasets must remove intensity/poison semantics and describe the new actions accurately. Preserve historical analytics events for old sessions; add a rules/version discriminator and new surface events rather than rewriting records.

## High-value acceptance scenarios

1. Empty-floor AOE setup, same-tile repaint, Fire↔Ice conflict and coexistence with Rubble/Charge/trap/loot.
2. Player movement split into clicks versus one path gives equal costs and damage; hidden actor truncation spends only completed movement; Blink only contacts landing.
3. Move-1 actor can escape permanent Rubble; two- and four-tile actors pay one surcharge and take one contact/start hit.
4. Push→Fire, push across several Fire tiles, pull back, collision interruption and actor death all match preview.
5. Ice attack creates Chill after damage; subsequent Ice attack Freezes; repeated identical placement/attacks cannot refresh Freeze forever; explicit repositioning can set up a new Chill.
6. Chain relay branching ties, consumed nodes, a dead intermediary, hidden actors, blocking walls and large footprints are deterministic, each actor hit at most once.
7. Overlapping Detonate blasts hit actors once, consume chosen Fire only, preserve unrelated Rubble/Charge, handle simultaneous player/leader death and death spawns consistently.
8. Passive Fire kill awards no card play/attack-rider loop; direct Detonate follows its explicit source contract. Shared hazards affect player and illusions as specified.
9. Enemy AI exact plan and displayed threat update after every surface change. Postcombat surfaces cannot damage the player while collecting rewards or walking to the exit.
10. Fresh real-renderer proof at 1920x1080, 100% UI scale, combined layers/large units/hidden cells and reduced motion; frame pacing with a heavily surfaced board; serialized save/load round trip and legacy migration.
