# Agent Playtest Round Summary - 2026-05-14

## Scope

- Testers: 6 sub-agent manual headless playtests.
- Seeds: 5142601 through 5142606.
- Harness: `godot --headless --path . --script tools/headless_playtest.gd`.
- Guide: `playtest/headless_strategy_guide.md`.
- Sources: each `playtest/agent_round_20260514_*/manual_playtest_notes.md` plus `analytics/events-2026-05-14.jsonl`.

## Run Outcomes

| Run | Seed | Endpoint | Combat sample | Final HP | Notes |
| --- | ---: | --- | --- | ---: | --- |
| 01 | 5142601 | Campfire rest after banking 66 embers | 2 wins: D1 earth, D2 earth | 14/36 | Depth-2 earth ended at 8 HP before mandatory heal. |
| 02 | 5142602 | Mid depth-2 earth evidence stop | 2 wins plus 8 turns in D2 earth | 31/36 | HP was healthy, but Warden/Harrier stoneskin cleanup became low-agency. |
| 03 | 5142603 | Stopped after 3 depth-1 combats and treasure | 3 wins: earth, air, fire | 18/36 | Skipped all 3 card rewards for heal. |
| 04 | 5142604 | Stopped after D2 earth win and heal | 3 wins: air, ice, earth | 11/36 | Earth trap cascade drove poison to 16 and left combat at 5 HP. |
| 05 | 5142605 | Stopped after 2 depth-1 combats and treasure | 2 wins: earth, air | 14/36 | First earth room felt overtuned; second air room fairer but still costly. |
| 06 | 5142606 | Stopped mid second earth combat | 1 win plus deep second earth combat | 3/36 | Final acolyte remained with 11 HP and 5 stoneskin. |

## Analytics Summary

- Combat starts/completions: 15 starts, 13 completed combats.
- Reward offers: 13.
- Reward choices: 10 heal skips, 3 card picks (`Stone Plate`, `Skybreak Current`, `Reprise`).
- Lowest HP by run: 8, 25, 5, 5, 8, 3.
- Earth exposure: 8 of 15 combat starts were earth, including all three depth-2 samples.
- Card-play analytics recorded 219 card plays, 535 enemy HP damage, 45 kills, and 8 card-triggered traps.

The analytics support the notes: card rewards were usually unaffordable, and earth encounters accounted for the most severe low-HP endpoints.

## Repeated Findings

1. Early sustain is too tight.
   - Ten of thirteen reward choices were heal skips.
   - Three runs ended or stopped at 14 HP or lower after reward healing.
   - One run stopped at 3 HP in the second combat despite taking a heal reward.

2. Earth rooms are the highest-confidence balance outlier.
   - Depth-1 earth cleared at 5 HP in run 03 and 12 HP in run 05.
   - Depth-2 earth cleared at 8 HP in run 01 and 5 HP in run 04.
   - Notes repeatedly identify poison plus trap cascades as more threatening than direct damage.

3. Stoneskin stacking creates long cleanup turns.
   - Tunnel Crawler `Coil`, Ash Acolyte `Ward Chant`, and Ash Warden `Bulwark` repeatedly pushed enemies into high stoneskin states.
   - Reported examples include crawler stoneskin of 8 and 14, and warden stoneskin of 24.
   - These states are survivable only through kiting, but fatigue then becomes the main clock.

4. Trap-adjacent pickups are often bait.
   - Several testers avoided or regretted potion/shield lines because enemy forced movement or adjacent-blast trap rules converted pickups into net HP/status losses.
   - Earth traps are especially punishing because poison stacks persist after the immediate trap damage.

5. Ranged chip and kill refunds feel good.
   - `Bone Dart`, `Lantern Shot`, `Skybreak Current`, and kill-refund chains were repeatedly cited as strong, correct tools in cluttered rooms.
   - This is a positive signal: the tactical kit works when enemies do not outscale it with defense/status clocks.

## Suspected Bugs Or Harness Issues

- Queued/buffered commands can spill into the next turn after auto enemy phases, causing accidental passes.
- `pass` preview can read as safe while fatigue damage applies during next-turn setup.
- Pending targeting plus `pass` can accidentally end the turn after an illegal target attempt.
- Trap-trigger output sometimes lacks enough geometry detail to explain why an enemy-triggered trap fired or who was hit.
- Some block/fatigue turns were misread as block failure, especially when `Brace` was followed by HP loss from fatigue or status.
- AOE and melee targeting need clearer preview language for adjacent-only versus diagonal/clutter cases.
- Top-line embers do not update immediately on kill even when kill logs show ember rewards; this may be intentional reward timing, but it reads like inconsistency.

## Recommendations

1. Reduce early earth attrition first.
   - Lower earth trap poison from 2 to 1 at depth 1, or keep poison 2 but prevent multiple earth trap poison stacks from accumulating in the same enemy phase.
   - Consider making depth-1 earth rooms spawn fewer trap-adjacent pickups or fewer central earth traps.

2. Cap or decay enemy defensive stacking.
   - Cap repeated `Coil`, `Ward Chant`, and `Bulwark` accumulation per enemy, or convert some block-style enemy defenses to temporary block that expires after the enemy phase.
   - Target the specific low-agency cases: crawler and warden should not reach 14-24 effective extra HP while fatigue rises.

3. Make reward healing less mandatory.
   - Either raise post-combat heal from 6, add a smaller baseline heal when taking a card, or reduce first-act encounter damage/status enough that card picks are viable above roughly 20 HP.
   - The current signal is not "players dislike cards"; it is "players cannot afford cards."

4. Revisit trap/pickup placement scoring.
   - Pickups adjacent to traps should be rarer, more valuable, or explicitly treated as high-risk.
   - If the design wants trap-adjacent pickups as tactical gambles, the preview needs to include likely enemy detonation and forced-movement risk more clearly.

5. Improve harness safety before the next large round.
   - Flush or reject queued commands after auto enemy phases.
   - Make `pass` cancel pending target selection only with explicit `cancel`, or require confirmation when a card is pending.
   - Include fatigue/status tick previews in "safe pass" output.
   - For trap triggers, print triggering actor, trap tile, blast tiles, and affected units.

6. Keep the positive combat tempo.
   - Do not nerf kill refunds or ranged chip based on this round. They are the main tools letting testers recover from pressure and are producing good tactical decisions.
