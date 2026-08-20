# Headless Playtester Strategy Guide

Use this guide before making combat decisions in the headless playtest harness.

1. Read the complete committed enemy geometry before acting. Enemy previews distinguish movement paths, attack tiles, forced movement, and tiles that will become Corrupted. Enemies do not retarget after commitment: move the player, an Illusion, terrain, or another enemy into the sequence to make contact short-circuit everything downstream.
2. Use the free Move 2 as a positioning resource, not a card substitute. It costs no card play or Time, is unsplittable, and refreshes each player activation. Check it before spending a movement card; save movement cards for longer routes, Blink, board-effect traversal, or compound attack setups.
   Playing your final available card does not end the activation while Free Move
   remains ready. Use the move afterward or `pass`; if both resources are spent,
   the harness advances automatically.
3. Manage the board clock. Corruption damages the player on traversal and activation start while healing enemies on their activation start. Radiance damages enemies on traversal/start, replaces Corruption, and reveals through Umbra. Both Fields and Surfaces expire at their printed absolute Time, so judge whether a setup survives until the relevant actor activates.
4. Build elemental packages across elements instead of chasing a threshold. Earth creates Bramble and Poison routes; Ice creates slides and Snowdrift vulnerability; Air pushes and pulls along printed directions; Lightning chains through groups and uses Electrified to suppress attack segments; Fire rewards grouped enemies and consumes Surfaces with Combust. Mixed packages should create the strongest turns.
5. Board Surfaces are compact rules with broad applications. Bramble ends movement, Poison arms on entry and deals 1 for each later route tile, Ice continues travel in the entry direction until open ground or collision, Snowdrift adds 2 incoming attack damage, and Electrified suppresses attacks for that activation before being consumed.
6. Never step on traps unless the damage is worth it. Traps blast adjacent tiles and can be triggered by attacks, so also avoid standing next to a trap an enemy can profitably detonate. Lightning traps suppress attacks and Earth traps Immobilize; neither recreates a retired actor status.
7. Collect room pickups when the path is not costly. `H` is a `2` HP healing
   vial and `S` is a `3` block rusty shield. The harness prints natural combat
   numbers: `4` means exactly `4` HP, block, or damage.
8. Treat boxes and crates as real terrain. `B` and `C` block movement but not line of sight, have low HP, and can be attacked. Breaking terrain can open a path, but it spends a card action that might otherwise kill or prevent damage.
9. Do not evaluate safety only by current enemy range. A clean sidestep can still lose the board if the missed pattern leaves Corruption that constricts later turns. Prefer lines that prevent contact, redirect the committed sequence, clear Corruption with Radiance, or secure enough tempo to end the fight before the board closes.
10. Enemy healing, Block, and ally protection can make support units the correct focus target even when their attack profile is modest. Compare the next committed activations rather than relying on a fixed kill order.
11. Healing is deliberately scarce and healing cards exhaust. Use it when it
   preserves a route or prevents a Defiance spend, but prefer avoiding damage
   through movement, shields, terrain, or kills.
12. Passing is still useful when it lets an enemy approach, but check what its committed miss will leave behind. Pass only when the next board state is better, not merely because current HP is safe.
13. Use Illusions as deterministic interceptors for committed paths and projectiles. Their value is no longer limited to winning a target-selection tie: after an intent is committed, place or move an Illusion into the shown line to absorb contact and cancel later tiles.
14. For first-boss playtests, treat every campfire as a continue point, not a run endpoint. Use `linger` to heal and continue when available; use `level` to spend Embers and bank one skill point. Spend banked points independently with `learn SKILL_ID` whenever the run is outside combat; `skills` prints the unspent total and every legal ID with its effect. Do not use `rest` or stop the run at a campfire unless the harness is blocked and no legal progress is possible.
15. In room mode, read `outward, deeper` as the boss clock, not an automatic
   choice. Compare the offered rooms: a high-value relic, treasure, or campfire
   can justify one lateral detour, but repeated rooms are health-negative in
   expectation. After three visited rooms at one depth, an outward route is
   guaranteed when none was already available.
16. As your deck gets stronger, tighten the route. Depth 1 is tuned to be more stable for efficient players, while depth 3 is a real step up; use the easier combats to assemble damage, defense, movement, and a boss plan, then skip extra lateral combat once the deck is doing its job. After each resolved card, re-run `cards` before choosing the next play because hand indexes can shift.
17. Combat rewards enter reserve magic rather than the active deck. Between
   combats, use `magic`, then `attune RESERVE_INDEX SLOT_INDEX` to swap a reward
   into one of the six active slots. A committed Reach Exit route pauses at
   `pre_battle`, where you can attune before using `battle` to enter the next room.
18. Read the printed objective every activation. Kill All and Kill the Leader
   end through lethal, Survive ends at its target Time, and Reach Exit ends only
   when the player reaches a marked threshold; clearing its pursuers is optional.

Harness notes:

- Use `state`, `cards`, and target previews after each action; hand indices and target lists change as cards resolve.
- The console's `Order` and `Round clock` lines are the headless version of the live turn-order widget. Field and Surface expiry uses that same absolute clock. Card rows also show `if played return +N...` previews so you can compare fast, normal, and heavy plays against upcoming enemy turns.
- Range is orthogonal/Manhattan. A melee range 1 attack hits the four cardinal adjacent tiles, not diagonals.
- The `Hand` line shows hand cap, draw, discard, burned, and next fatigue damage. If your hand is full, future draws stop at the cap, so visible hand count may not grow even when the setup line names draw effects.
- `Defiance N/M` is the run's remaining extra-life clock. Otherwise-lethal
  damage spends one charge and restores `25%` maximum HP. Charges do not refill
  during the run, so avoid spending one for a low-value detour.
- The first boss is the lightning boss room at depth 4. Clearing that boss returns the run to room mode with the labyrinth opening outward instead of ending the whole run; that counts as first-boss success.
- Board legend: `P` player, `0-9` enemies, `I` illusion, `B` box, `C` crate, `H` potion, `S` shield, `T` trap, `#` wall/pillar, `D` door.
- Prefer `target e0`, `target e1`, named terrain/traps, and printed tile previews. A bare `target N` means target-list row N, which may be terrain rather than the similarly numbered enemy.
- Keyword text such as `pierce`, `immobilize`, `push`, `pull`, `chain`, and `combust` is tactical information. Pierce bypasses block/stoneskin instead of removing it; Immobilize prevents movement for the activation; deterministic force follows the printed pattern without a direction prompt.
- Target previews include terrain damage, broken terrain, triggered trap blasts, and pickup effects. Recheck them before confirming a line through dense battlefield clutter.
- Trap-only AOE previews are hazards, not attacks. If a target hint says `trap-only` or shows trap blasts without enemy damage, treat it as a way to alter terrain and routes rather than as direct progress toward clearing the room.
- If a pending card says `No legal targets` but offers `skip`, skipping commits the earlier parts of that card and omits the listed action. Use `cancel` when that partial card is not worth spending.
- If every movement option steps on or adjacent to a trap risk, prefer passing unless the move prevents larger unavoidable damage or secures lethal.
