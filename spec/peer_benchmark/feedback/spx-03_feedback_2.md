# spx-03 feedback 2 (Codex peer review of ade9f5ca6: CHANGES REQUESTED)

The director already restored the leaked `playtest/headless` files. They came from the director's console runs, not
your work.

Fix these four, each with a test that fails before and passes after:

1. **Medium: Command numbers disagree after movement.** `intent_badges.gd:103` and `enemy_intent_compass.gd:40` apply
   Command at the follower's current tile. The plan and resolution use the tile it will attack from.
   - Repro: an Ash Hound at (1,3), the captain at (3,1) and the player at (4,3); the Hound moves 2 then melees 3. Both
     displays show 3, but 4 lands. With the captain at (1,1) the mismatch reverses.
   - Derive displayed damage from the projected attack action. Test a follower entering and leaving the aura.
2. **Medium: the screen check uses grid-path length, not Manhattan.** `warband_room_rules.gd:44` and its validator
   accept detours. `generate_room(54, Fixture.room_spec("air", 2), Vector2i.DOWN)` puts the screen at (5,3), with
   distances summing to 8 against an entry-to-captain distance of 6.
   - Require Manhattan equality: d(entry, screen) + d(screen, captain) == d(entry, captain).
   - Enforce it in generation, validation and tests. Check reachability separately.
3. **Medium: the break tests miss prohibited bursts and excess travel.**
   - Assert on `death_burst_events`, not `surface_events`.
   - Place a Tick beside the player.
   - Add a follower whose route to the edge is longer than two tiles, and assert it moves at most 2 before it
     dissolves.
4. **Low:** `warband_inspection.gd:12` builds an `Array[String]` from a bare literal. Use the AGENTS.md pattern.

Focused tests only. The director reruns the windowed probe if anything visible changes.
