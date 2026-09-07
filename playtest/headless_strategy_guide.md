# Headless Playtester Strategy Guide

Use this guide before making combat decisions in the headless playtest harness.

1. Never step on traps unless the damage is worth it. Traps hit only the center occupant, then create Fire, Ice, Rubble or Electrified on four cardinal neighbors. Air traps push those neighbors directly outward. The center hit and wake are shared hazards.
2. Collect room pickups when the path is not costly. `H` is a `2` HP healing
   vial and `S` is a `3` block rusty shield. The harness prints natural combat
   numbers: `4` means exactly `4` HP, block, or damage.
3. Treat boxes and crates as real terrain. `B` and `C` block movement but not line of sight, have low HP, and can be attacked. Breaking terrain can open a path, but it spends a card action that might otherwise kill or prevent damage.
4. Try not to enter enemy range until you can kill an enemy. This allows one more play to use block, movement, terrain, traps, or illusion to avoid excessive damage from other enemies.
5. Generally, save low-movement, high-damage enemies such as warden for last, since you can move around them quite easily to avoid their damage without additional card plays.
6. Healing is deliberately scarce and healing cards exhaust. Use it when it
   preserves a route or prevents a Defiance spend, but prefer avoiding damage
   through movement, shields, terrain, or kills.
7. It is okay to pass if moving into range is going to just make you eat damage. Let the enemies get closer so you are set up to get a one-turn kill next turn.
8. Use illusions as a way blocker when needed to eat up a full enemy attack. Enemies prefer the closest player-side actor; if the player and one or more illusions are tied at the same distance, they use deterministic target ordering among those tied targets. Spawn the illusion closer than the player when you need reliable protection.
9. Build useful ground deliberately. Fire deals two damage on each entry and three at an actor's start; Detonate consumes selected Fire for one shared union blast. Rubble costs two movement to leave, with one minimum-progress step from a fresh allowance. Ice entry or start activates Chilled (+2 direct damage); a direct Ice hit freezes and consumes all supporting Ice. Frozen triples direct attack damage. Electrified connects ordinary Lightning through cardinal components; Chain may use individual tiles to bridge gaps. Ordinary Electrified remains after use; Stormcoal Fire is consumed when conducting. Prefer mixed setup/payoff that improves this board rather than painting distant empty corners. Ground never grants Light on its own.
10. For first-boss playtests, treat every campfire as a continue point, not a run endpoint. Use `linger` to heal and continue when available; use `level` to spend Embers and bank one skill point. Spend banked points independently with `learn SKILL_ID` whenever the run is outside combat; `skills` prints the unspent total and every legal ID with its effect. Do not use `rest` or stop the run at a campfire unless the harness is blocked and no legal progress is possible.
11. In room mode, read `outward, deeper` as the boss clock, not an automatic
   choice. Compare the offered rooms: a high-value relic, treasure, or campfire
   can justify one lateral detour, but repeated rooms are health-negative in
   expectation. After three visited rooms at one depth, an outward route is
   guaranteed when none was already available.
12. As your deck gets stronger, tighten the route. Depth 1 is tuned to be more stable for efficient players, while depth 3 is a real step up; use the easier combats to assemble damage, defense, movement, and a boss plan, then skip extra lateral combat once the deck is doing its job. After each resolved card, re-run `cards` before choosing the next play because hand indexes can shift.

Harness notes:

- Use `state`, `cards`, and target previews after each action; hand indices and target lists change as cards resolve.
- The console's `Order` and `Round clock` lines are the headless version of the live turn-order widget. Card rows also show `if played return +N...` previews so you can compare fast, normal, and heavy plays against upcoming enemy turns.
- Range is orthogonal/Manhattan. A melee range 1 attack hits the four cardinal adjacent tiles, not diagonals.
- The `Hand` line shows hand cap, draw, discard, exhausted, and next fatigue damage. If your hand is full, future draws stop at the cap, so visible hand count may not grow even when the setup line names draw effects.
- `Defiance N/M` is the run's remaining extra-life clock. Otherwise-lethal
  damage spends one charge and restores `25%` maximum HP. Charges do not refill
  during the run, so avoid spending one for a low-value detour.
- The first boss is the lightning boss room at depth 4. Clearing that boss returns the run to room mode with the labyrinth opening outward instead of ending the whole run; that counts as first-boss success.
- Board legend: `P` player, `0-9` enemies, `I` illusion, `B` box, `C` crate, `H` potion, `S` shield, `T` trap, `#` wall/pillar, `D` door.
- Treat target labels like `e0`, `e1`, named terrain/traps, and printed tile previews as safer than guessing from enemy order.
- Keyword text such as `pierce`, `immobilize`, `push`, and `pull` is tactical information. Pierce bypasses block/stoneskin instead of removing it; immobilize prevents movement on that unit's next turn.
- Target previews include terrain damage, broken terrain, triggered trap blasts, and pickup effects. Recheck them before confirming a line through dense battlefield clutter.
- Trap-only AOE previews are hazards, not attacks. If a target hint says `trap-only` or shows trap blasts without enemy damage, treat it as a way to alter terrain/status space rather than as progress toward clearing the room.
- If a pending card says `No legal targets` but offers `skip`, skipping commits the earlier parts of that card and omits the listed action. Use `cancel` when that partial card is not worth spending.
- If every movement option enters a trap, Fire, or a dangerous cardinal trap wake, prefer passing unless the move prevents larger unavoidable damage or secures lethal.

- Read the objective before optimizing damage: Reach Exit finishes only when the player enters its marked exit, even after every enemy dies. Use `continue` after its reward to follow the exit, and again from pre-battle to enter combat.
- Manual surface skills take `skill SKILL_ID KIND x,y [origin_x,origin_y]`; kinds are `fire`, `ice`, `electrified`, and `rubble`. Confluence requires the actual surface kind and a visible nearby source tile. An unchanged destination spends no use.

For a repeatable board-surface regression run, use `tools/board_surface_playtest.gd` with `--build mixed|fire|earth|ice|air|lightning`, a fixed `--seed`, and a unique `--output-dir`, through the mandatory Godot task runner. The script reuses this console's action, movement, reward, travel, save and analytics APIs. It selects six common spells with ordinary starting equipment and progression, keeps that controlled loadout by taking heal rewards, and ends on defeat or boss victory. Its greedy policy is intentionally inspectable: it values immediate damage/control, forecasts the next activation, and prefers locally useful ground. It is a regression aid, not an optimal player or a source of statistical win rates. Read `manual_playtest_notes.md`, `policy_summary.json`, and the analytics JSONL together before drawing balance conclusions.

For manual controlled-loadout play, add `--manual`; `--resume` loads the exact saved session without rebuilding its hand or room. During a pending push/pull card, use `force up|right|down|left` to set its remaining force rider, then inspect the updated target result before committing. Normal direction legality still applies.
