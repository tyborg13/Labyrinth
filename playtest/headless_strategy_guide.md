# Headless Playtester Strategy Guide

Use this guide before making combat decisions in the headless playtest harness.

1. Never step on traps unless the damage is worth it. Traps now blast all adjacent tiles and can be triggered by attacks, so also avoid standing next to a trap an enemy can profitably detonate.
2. Collect room pickups when the path is not costly. `H` is a healing potion for 4 HP; `S` is a rusty shield for 4 block.
3. Treat boxes and crates as real terrain. `B` and `C` block movement but not line of sight, have low HP, and can be attacked. Breaking terrain can open a path, but it spends a card action that might otherwise kill or prevent damage.
4. Try not to enter enemy range until you can kill an enemy. This allows one more play to use block, movement, terrain, traps, or illusion to avoid excessive damage from other enemies.
5. Generally, save low-movement, high-damage enemies such as warden for last, since you can move around them quite easily to avoid their damage without additional card plays.
6. Try to heal whenever expedient, but not if you can avoid damage by moving, collecting a shield, breaking terrain, or killing another enemy. Whenever you find yourself safe for a turn, sneak that heal in.
7. It is okay to pass if moving into range is going to just make you eat damage. Let the enemies get closer so you are set up to get a one-turn kill next turn.
8. Use illusions as a way blocker when needed to eat up a full enemy attack. Enemies will only attack the illusion if it is closer, so spawn it one square closer to them when trying to do this.
9. Build elemental intensity opportunistically. Getting a kill or preventing damage is usually higher priority, but if you can do those things while building an element that you will need later, prefer to do so.

Harness notes:

- Use `state`, `cards`, and target previews after each action; hand indices and target lists change as cards resolve.
- Board legend: `P` player, `0-9` enemies, `I` illusion, `B` box, `C` crate, `H` potion, `S` shield, `T` trap, `#` wall/pillar, `D` door.
- Treat target labels like `e0`, `e1`, named terrain/traps, and printed tile previews as safer than guessing from enemy order.
- Target previews include terrain damage, broken terrain, triggered trap blasts, and pickup effects. Recheck them before confirming a line through dense battlefield clutter.
- If every movement option steps on or adjacent to a trap risk, prefer passing unless the move prevents larger unavoidable damage or secures lethal.
