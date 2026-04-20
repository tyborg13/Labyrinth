# Labyrinth of Ash Prototype

## High-Level Pillars

- Gloomhaven-meets-Slay-the-Spire combat loop: one card played per turn from a shifting deck.
- Isometric, tile-based dungeon rooms with procedural blockers, enemy formations, and occasional loot pickups.
- Health is the timer. Damage, some card costs, and cycling the deck all chip away at a run.
- Spatial push-your-luck structure: a central start room, outward escalation, lateral farming, and checkpoint banking.
- Headless-first architecture: all room generation, combat resolution, rewards, and progression logic must run without the renderer.

## Prototype Scope

This first playable prototype intentionally focuses on:

- One fully playable hero with a deckbuilding loop.
- Four regular enemy archetypes plus one boss archetype.
- Procedural rooms on a finite labyrinth map with revisiting and lateral movement.
- Card rewards, treasure relics, checkpoints, and persistent upgrade currency.
- Placeholder SVG art and polished-enough UI framing for repeated playtesting.

It intentionally excludes, for now:

- Multiplayer.
- Animation-heavy combat presentation.
- Audio and music.
- Narrative events or branching dialogue.
- Deep content volume beyond what is needed to validate the core loop.

## Run Structure

- The player starts at `(0, 0)` in a safe central room.
- The map is a Manhattan-distance labyrinth up to depth `4`.
- Depth `1-3` rooms are a mixture of combat, treasure, and checkpoint spaces.
- Depth `4` rooms are boss-tier sanctums; clearing one wins the run.
- Rooms can be revisited. Cleared rooms stay safe.
- Lateral movement keeps depth the same, allowing safer farming at the cost of more turns and deck cycles.

## Combat Loop

- The player begins combat with a hand of `3` cards, plus persistent-upgrade and relic adjustments.
- Each round:
  - The player plays exactly `1` card.
  - The card resolves its scripted actions in sequence.
  - The card is discarded or burned.
  - Enemies execute their previewed intent.
  - A new card is drawn.
- When the draw pile empties and the discard pile is reshuffled, the player loses health from fatigue.
- Burned cards stay removed for the rest of the run, accelerating future fatigue cycles.

## Combat Rules

- Orthogonal movement on a small procedural room grid.
- Melee attacks use adjacency.
- Ranged attacks target enemies within range, while ranged AOE attacks target a tile pattern within line-of-sight.
- Temporary block absorbs damage until the actor’s next major phase.
- Rooms can spawn loot pickups such as healing vials and ember caches.
- Enemy behavior is deterministic from seed plus state, and each enemy always displays its next intent.

## Progression

- Rooms award unbanked embers.
- Checkpoints let the player bank embers permanently and recover some health.
- Death loses unbanked embers but keeps what was banked earlier.
- Treasure rooms offer relics for the current run only.
- Persistent upgrades modify future runs, starting with max health, hand size, and healing support.

## Content Targets

- Starter deck: 10 cards.
- Reward pool: 12-16 additional cards.
- Regular enemies: crawler, acolyte, harrier, warden.
- Boss: heart warden.
- Relics: 4-6 simple, high-signal effects.
- Persistent upgrades: 3-4 simple upgrades.

## Technical Targets

- Core logic lives in pure `RefCounted` scripts operating on dictionaries and arrays.
- Presentation reads state but does not own game rules.
- Regression tests cover:
  - room generation determinism and reachability
  - combat damage and targeting rules
  - deck cycling and burn exhaustion behavior
  - enemy intent progression
  - run map generation and reward flow
  - progression save/load behavior
