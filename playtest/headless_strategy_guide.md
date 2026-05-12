# Headless Playtester Strategy Guide

Use this guide before making combat decisions in the headless playtest harness.

1. Never step on traps.
2. Try not to enter enemy range until you can kill an enemy. This allows one more play to use block, movement, or illusion to avoid excessive damage from other enemies.
3. Generally, save low-movement, high-damage enemies such as warden for last, since you can move around them quite easily to avoid their damage without additional card plays.
4. Try to heal whenever expedient, but not if you can avoid damage by moving or killing another enemy. Whenever you find yourself safe for a turn, sneak that heal in.
5. It is okay to pass if moving into range is going to just make you eat damage. Let the enemies get closer so you are set up to get a one-turn kill next turn.
6. Use illusions as a way blocker when needed to eat up a full enemy attack. Enemies will only attack the illusion if it is closer, so spawn it one square closer to them when trying to do this.
7. Build elemental intensity opportunistically. Getting a kill or preventing damage is usually higher priority, but if you can do those things while building an element that you will need later, prefer to do so.

Harness notes:

- Use `state`, `cards`, and target previews after each action; hand indices and target lists change as cards resolve.
- Treat target labels like `e0`, `e1`, and printed tile previews as safer than guessing from enemy order.
- If every movement option steps on a trap, prefer passing unless the move prevents larger unavoidable damage or secures lethal.
