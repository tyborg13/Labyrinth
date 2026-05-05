# Manual Headless Playtest Report

- Date: 2026-05-05
- Runs: 10 manual runs through `tools/headless_playtest.gd`
- Outcomes: 7 defeats, 3 campfire rests, 0 victories
- Source notes: `playtest/headless_manual/manual_playtest_notes.md`
- Source analytics: `playtest/headless_manual/analytics/events-2026-05-05.jsonl`

## What Is Working

- The universal fallback lanes are doing their job. They were used only 17 times out of 647 card plays, so they are not replacing real card text. Fallback attack secured 4 small kills, and fallback move occasionally fixed a busted tactical position.
- Card-play/refund cards feel good. Battle Rhythm, Gate Gambit, Updraft, Guarded Step, and similar effects create real tactical turns without trivializing the run.
- Early relics are exciting and stabilizing, especially Ember Lens, Mirror Shard, Iron Lung, and Pilgrim Boots, but they did not guarantee success. Strong relic starts still ended in defeats or low-HP rests.
- The boss run was dramatic. Reaching Zekarion once and getting him to 13/72 HP felt like the run had an arc, not like the game was impossible.

## Balance Concerns

- Overall difficulty is very high. Across 49 combats, depth 1 was mostly survivable, but depth 2 and beyond produced the collapses: depth 2 had 3 defeats in 14 combats, depth 3 had 2 defeats in 3 combats, and the only depth 4 boss combat was a defeat.
- Healing pressure is severe. Exactly half of rewards were skipped for healing. Heal skips happened at an average of 13 HP before the choice, while card picks happened at an average of 24.9 HP. Below roughly 16 HP, healing felt close to mandatory.
- Campfires currently feel more like extraction points than recovery beats. All three rests happened at 8-9 HP, where continuing felt reckless.
- Warden plus support enemies creates an attrition cliff. Warden rooms were tense in a good way individually, but Warden/Acolyte/Harrier or double-Warden packages often pushed from "clutch" to "no real recovery window."
- Acolyte Ward/Siphon loops can make progress feel erased. Acolytes surviving at 1-3 HP often converted a good turn into a dangerous next turn.
- Draw cards are powerful but risky and sometimes confusing. Lantern Shot was played 64 times; 14 were zero-damage draw-only plays, usually from no valid target, and draw effects contributed negative HP delta through fatigue. Ricochet Knife showed the same pattern in 4 of 11 plays.
- Boss pressure may be too compressed at low HP. Repeated adds plus Storm Claw left little recovery space once under about 15 HP.

## Readability And UX Issues

- Crawler Coil needs a much louder telegraph if it is intended to start the next turn with 0 plays. This came up repeatedly and felt like lost agency.
- Shortcut previews for move-to-attack lines do not reliably show trap damage on the movement leg. Direct move targets show HP loss more clearly.
- When a damage-plus-draw or push-plus-card-play card has no target, the card can resolve as draw/refund only. That may be mechanically valid, but the skipped primary effect needs explicit feedback.
- Some intents are hard to read from their names alone. Warden defensive-looking intents, especially Bulwark/Marching lines, need clearer consequence previews.
- The current analytics log does not record relic choices, which makes it harder to connect run outcomes to relic packages after the fact.

## Suggested Priorities

1. Improve telegraphs and text feedback for Crawler Coil, skipped primary card actions, trap shortcut damage, and Warden intent outcomes.
2. Smooth depth-2-plus attrition by reducing the harshness of Warden/support packages or by adding more recovery space before/after those fights.
3. Revisit Acolyte survivability or Ward/Siphon tuning so one low-HP survivor does not erase too much progress.
4. Add relic-pick analytics so future playtests can compare outcomes by relic package.
5. Consider a small boss recovery valve or slightly slower add cadence so reaching the boss at low HP is difficult but not immediately doomed.
