# Escape the Umbra Prototype

## High-Level Pillars

- Gloomhaven-meets-Slay-the-Spire combat loop: one card played per turn from a shifting deck.
- Isometric, tile-based dungeon rooms with procedural blockers, enemy formations, and occasional loot pickups.
- Health is the timer. Damage, some card costs, and cycling the deck all chip away at a run.
- Spatial push-your-luck structure: a central start room, outward escalation, lateral farming, and campfire extraction or leveling choices.
- Headless-first architecture: all room generation, combat resolution, rewards, and progression logic must run without the renderer.

## Prototype Scope

This first playable prototype intentionally focuses on:

- One fully playable hero with a deckbuilding loop.
- Four regular enemy archetypes plus one boss archetype.
- Procedural rooms on a finite labyrinth map with revisiting and lateral movement.
- Card rewards, treasure relics, campfires, and persistent character levels.
- Placeholder SVG art and polished-enough UI framing for repeated playtesting.

It intentionally excludes, for now:

- Multiplayer.
- Animation-heavy combat presentation.
- Audio and music.
- Narrative events or branching dialogue.
- Deep content volume beyond what is needed to validate the core loop.

## Run Structure

- The player starts at `(0, 0)` in a safe central room.
- The playable map works outward through six four-depth sequences.
- Depths `1-3` are a mixture of combat, treasure, and checkpoint spaces, and
  depth `4` is the first boss gate.
- Each later sequence repeats the same local room-density curve with a higher
  enemy baseline. Depths `4`, `8`, `12`, `16`, and `20` contain the five
  elemental dragons (earth, fire, air, ice, and lightning) in a deterministic
  run-seeded random order without repeats.
- Clearing an intermediate dragon opens the next sequence. Depth `24` always
  contains Noctyrax, the shadow dragon; defeating it wins the run.
- Rooms can be revisited. Cleared rooms stay safe.
- Lateral movement keeps depth the same, allowing safer farming at the cost of more turns and deck cycles.

## Combat Loop

- The player begins combat with a hand of `5` cards, plus relic adjustments.
- Each round:
  - The player normally plays up to `2` cards.
  - The card resolves its scripted actions in sequence.
  - The card is discarded or exhausted.
  - Enemies execute their previewed intent.
  - A new card is drawn.
- When the draw pile empties and the discard pile is reshuffled, the player loses health from fatigue.
- Exhausted cards stay removed for the rest of the run, accelerating future fatigue cycles.

## Combat Rules

- Orthogonal movement on a small procedural room grid.
- Melee attacks use adjacency.
- Ranged attacks target enemies within range, while ranged AOE attacks target a tile pattern within line-of-sight.
- Temporary block absorbs damage until the actor’s next major phase.
- Rooms can spawn loot pickups such as healing vials and rusty shields.
- Enemy behavior is deterministic from seed plus state, and each enemy always displays its next intent.

## Progression

- Rooms award held embers.
- Campfires force a choice: heal and continue, carry held embers into the next
  run by ending safely, or spend held embers to gain a permanent character
  level and bank one skill point.
- Death loses held embers unless they were carried forward from a campfire or
  final victory.
- Treasure rooms offer relics for the current run only.
- Persistent progression is a 24-node qualitative skill tree. Learned skills
  add tactical options, recovery lines, and cross-system interactions without
  permanently scaling printed card or character numbers.
- A Moltshard from the first boss can reset the whole learned tree after one
  confirmation, restoring every earned point; it exists only in progression
  and never enters run inventory.

## Content Targets

- Starter deck: 10 cards.
- Reward pool: 12-16 additional cards.
- Regular enemies: crawler, acolyte, harrier, warden.
- Boss: heart warden.
- Relics: 4-6 simple, high-signal effects.
- Persistent progression: 20 character levels earning one bankable skill point
  per level after level 1, up to 19 active skills and one exclusive keystone.

## Technical Targets

- Core logic lives in pure `RefCounted` scripts operating on dictionaries and arrays.
- Presentation reads state but does not own game rules.
- Regression tests cover:
  - room generation determinism and reachability
  - combat damage and targeting rules
  - deck cycling and card exhaustion behavior
  - enemy intent progression
  - run map generation and reward flow
  - progression save/load behavior
