# Headless Playtester Strategy Guide

Use this guide before making combat decisions in the headless playtest harness.

1. Never step on traps unless the damage is worth it. Traps now blast all adjacent tiles and can be triggered by attacks, so also avoid standing next to a trap an enemy can profitably detonate.
2. Collect room pickups when the path is not costly. `H` is a healing potion and `S` is a rusty shield. The harness prints fixed-point combat numbers, so `40` in the console means `4` player-scale HP/block/damage.
3. Treat boxes and crates as real terrain. `B` and `C` block movement but not line of sight, have low HP, and can be attacked. Breaking terrain can open a path, but it spends a card action that might otherwise kill or prevent damage.
4. Try not to enter enemy range until you can kill an enemy. This allows one more play to use block, movement, terrain, traps, or illusion to avoid excessive damage from other enemies.
5. Generally, save low-movement, high-damage enemies such as warden for last, since you can move around them quite easily to avoid their damage without additional card plays.
6. Try to heal whenever expedient, but not if you can avoid damage by moving, collecting a shield, breaking terrain, or killing another enemy. Whenever you find yourself safe for a turn, sneak that heal in.
7. It is okay to pass if moving into range is going to just make you eat damage. Let the enemies get closer so you are set up to get a one-turn kill next turn.
8. Use illusions as a way blocker when needed to eat up a full enemy attack. Enemies prefer the closest player-side actor; if the player and one or more illusions are tied at the same distance, they choose randomly among those tied targets. Spawn the illusion closer than the player when you need reliable protection.
9. Build elemental intensity deliberately. Many reward cards now turn on at 2 intensity, so a matching elemental room often makes the first same-element card fully active, while off-element builds usually need one setup play first. Getting a kill or preventing damage is still higher priority, but take same-element cards when they make the next combat plan more reliable.
10. For first-boss playtests, treat every campfire as a continue point, not a run endpoint. Use `linger` to heal and continue when available; use `level` to spend Embers and bank one skill point. Spend banked points independently with `learn SKILL_ID` whenever the run is outside combat; `skills` prints the unspent total and every legal ID with its effect. Do not use `rest` or stop the run at a campfire unless the harness is blocked and no legal progress is possible.
11. In room mode, read `outward, deeper` as the boss clock, not an automatic choice. Compare the offered rooms: free-value lateral rooms such as relic/treasure and campfire are often worth taking, and early depth-1 lateral combats should be considered when they offer useful card rewards or match the element you are building.
12. As your deck gets stronger, tighten the route. Depth 1 is tuned to be more stable for efficient players, while depth 3 is a real step up; use the easier combats to assemble damage, defense, movement, and a boss plan, then skip extra lateral combat once the deck is doing its job. After each resolved card, re-run `cards` before choosing the next play because hand indexes can shift.

Harness notes:

- Use `state`, `cards`, and target previews after each action; hand indices and target lists change as cards resolve.
- The console's `Order` and `Round clock` lines are the headless version of the live turn-order widget. Card rows also show `if played return +N...` previews so you can compare fast, normal, and heavy plays against upcoming enemy turns.
- Range is orthogonal/Manhattan. A melee range 1 attack hits the four cardinal adjacent tiles, not diagonals.
- The `Hand` line shows hand cap, draw, discard, burned, and next fatigue damage. If your hand is full, future draws stop at the cap, so visible hand count may not grow even when the setup line names draw effects.
- The first boss is the lightning boss room at depth 4. Clearing that boss returns the run to room mode with the labyrinth opening outward instead of ending the whole run; that counts as first-boss success.
- Board legend: `P` player, `0-9` enemies, `I` illusion, `B` box, `C` crate, `H` potion, `S` shield, `T` trap, `#` wall/pillar, `D` door.
- Treat target labels like `e0`, `e1`, named terrain/traps, and printed tile previews as safer than guessing from enemy order.
- Keyword text such as `pierce`, `immobilize`, `push`, and `pull` is tactical information. Pierce bypasses block/stoneskin instead of removing it; immobilize prevents movement on that unit's next turn.
- Target previews include terrain damage, broken terrain, triggered trap blasts, and pickup effects. Recheck them before confirming a line through dense battlefield clutter.
- Trap-only AOE previews are hazards, not attacks. If a target hint says `trap-only` or shows trap blasts without enemy damage, treat it as a way to alter terrain/status space rather than as progress toward clearing the room.
- If a pending card says `No legal targets` but offers `skip`, skipping commits the earlier parts of that card and omits the listed action. Use `cancel` when that partial card is not worth spending.
- If every movement option steps on or adjacent to a trap risk, prefer passing unless the move prevents larger unavoidable damage or secures lethal.
