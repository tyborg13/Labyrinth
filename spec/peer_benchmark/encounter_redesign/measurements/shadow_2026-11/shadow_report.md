# Shadow rooms — meas-04

Integration `5c099f24b39841012673d71134c2126ce68e7917`; map revision 7; policy v2 `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82` unchanged. 200 runs per group, first seed 1; standard rooms only. Dark off changes only the shadow layout copy’s `umbra.stage` to the existing `clear` value before combat creation. All outcomes, including turn caps, enter medians and nearest-rank P10–P90; HP lost is cumulative damage_received. Presence cuts overlap; “Other type” means at least one enemy other than Hollow Mimic or Gloam Stalker. Paired shadow rows retain the same seeds, coordinates, entrances, encounters and initial enemy types. Seeds without an eligible room are skipped; each group retains the first 200 matching seeds. Extended scans: tier 2 fire on: last seed 201; tier 2 air on: last seed 202; tier 2 lightning on: last seed 201.

| Tier | Element | Setup | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) |
|---:|---|---|---:|---:|---|---|
| 1 | fire | default | 200 | 66.0% | 5 (3–7) | 16 (0–26) |
| 1 | earth | default | 200 | 83.5% | 5 (3–8) | 9 (0–24) |
| 1 | ice | default | 200 | 77.5% | 5 (3–9) | 9 (0–24) |
| 1 | air | default | 200 | 83.5% | 5 (3–8) | 8.5 (0–24) |
| 1 | lightning | default | 200 | 70.5% | 5 (3–9) | 13 (0–26) |
| 1 | shadow | dark on | 200 | 18.5% | 4 (3–8) | 24 (16–26) |
| 1 | shadow | dark off | 200 | 26.5% | 4 (3–8) | 24 (14–26) |
| 2 | fire | default | 200 | 41.0% | 5 (3–8) | 24 (8–26) |
| 2 | earth | default | 200 | 48.0% | 6 (4–10) | 20.5 (5–26) |
| 2 | ice | default | 200 | 46.5% | 6 (3–11) | 24 (4–26) |
| 2 | air | default | 200 | 50.0% | 6 (3–9) | 24 (4–26) |
| 2 | lightning | default | 200 | 40.0% | 5 (3–9) | 24 (5–26) |
| 2 | shadow | dark on | 200 | 0.0% | 3 (3–5) | 24 (24–26) |
| 2 | shadow | dark off | 200 | 2.5% | 4 (3–6) | 24 (24–26) |
| 3 | fire | default | 200 | 27.0% | 5 (3–10) | 24 (16–26) |
| 3 | earth | default | 200 | 28.5% | 7 (3–14) | 24 (7–26) |
| 3 | ice | default | 200 | 37.0% | 7 (3–15) | 24 (7–26) |
| 3 | air | default | 200 | 33.0% | 7 (3–12) | 24 (10–26) |
| 3 | lightning | default | 200 | 20.5% | 5 (3–11) | 24 (15–26) |
| 3 | shadow | dark on | 200 | 1.5% | 4 (2–6) | 24 (24–26) |
| 3 | shadow | dark off | 200 | 1.5% | 4 (2–7) | 24 (24–26) |

| Tier | Shadow room held | Dark | N | Win rate | Median HP lost | N < 30 |
|---:|---|---|---:|---:|---:|---|
| 1 | Mimic present | on | 20 | 10.0% | 24 | yes |
| 1 | Stalker present | on | 45 | 33.3% | 24 | no |
| 1 | Other type present | on | 200 | 18.5% | 24 | no |
| 1 | Mimic present | off | 20 | 20.0% | 24 | yes |
| 1 | Stalker present | off | 45 | 40.0% | 24 | no |
| 1 | Other type present | off | 200 | 26.5% | 24 | no |
| 2 | Mimic present | on | 22 | 0.0% | 24 | yes |
| 2 | Stalker present | on | 74 | 0.0% | 24 | no |
| 2 | Other type present | on | 200 | 0.0% | 24 | no |
| 2 | Mimic present | off | 22 | 0.0% | 24 | yes |
| 2 | Stalker present | off | 74 | 1.4% | 24 | no |
| 2 | Other type present | off | 200 | 2.5% | 24 | no |
| 3 | Mimic present | on | 39 | 0.0% | 24 | no |
| 3 | Stalker present | on | 80 | 2.5% | 24 | no |
| 3 | Other type present | on | 200 | 1.5% | 24 | no |
| 3 | Mimic present | off | 39 | 0.0% | 24 | no |
| 3 | Stalker present | off | 80 | 2.5% | 24 | no |
| 3 | Other type present | off | 200 | 1.5% | 24 | no |

Tier 1: shadow wins 18.5% with dark on versus fire 66.0%, earth 83.5%, ice 77.5%, air 83.5%, lightning 70.5%; shadow dark off wins 26.5% (+8.0 percentage points). Tier 2: shadow wins 0.0% with dark on versus fire 41.0%, earth 48.0%, ice 46.5%, air 50.0%, lightning 40.0%; shadow dark off wins 2.5% (+2.5 percentage points). Tier 3: shadow wins 1.5% with dark on versus fire 27.0%, earth 28.5%, ice 37.0%, air 33.0%, lightning 20.5%; shadow dark off wins 1.5% (+0.0 percentage points).

Ten tier-2 dark-on losses, first losses in seed order; 37 turn ends. 20 ended with cards still playable; 1 turn had no legal targeted hand attack at a logged decision/end but gained a hidden-enemy target with darkness removed; the bot moved toward its nearest enemy on 0 of those turns. The fully targetless count restricted to pass/end states is 0. 5 turns had at least one attack action blocked by sight, including turns with another legal attack; the bot approached on 0 of these turns. Turns ended 1–6 Manhattan tiles from the nearest living enemy, 6 adjacent. Committed card movement/dodges encountered unseen enemies 0 times (production movement_interrupted_total deltas). Endings: 10 deaths, 0 turn caps. Sources: [decision log](audit.log.gz), [per-turn records](audit.json.gz).

- Seed 1: 3/4 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 2: 2/6 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 3: 1/3 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 4: 3/5 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 5: 2/3 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 6: 3/3 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 7: 1/2 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 8: 2/4 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 9: 2/4 turn ends with playable cards; turns without targets due to sight: 0, 0 with approach; 0 unseen collisions; death.
- Seed 10: 1/3 turn ends with playable cards; turns without targets due to sight: 1, 0 with approach; 0 unseen collisions; death.

Playable cards use the existing normal-play UI query after the final dodge, with play budget remaining. An unseen-target turn has a logged decision/end state where every budgeted targeted hand attack has zero legal targets, but changing only umbra.stage to clear on a diagnostic copy exposes a legal hidden-enemy target at the same hero position. Approach counts such turns with at least one actual card movement or final dodge that decreases Manhattan distance to the nearest living enemy anchor before that movement (the policy’s Manhattan metric; engine order breaks ties); it counts turns, not individual steps. Audit outcomes, damage, turns, kills, decisions and preview counts match their unobserved default runs exactly.

Non-shadow controls below 25% (no reruns): lightning tier 3: 20.5%.

Reproduce collection and audit: `cd /Users/borgerding/workspace/Labyrinth.worktrees/meas-04 && python3 tools/encounter_shadow_measurement.py --workers 4`; then `cd /Users/borgerding/workspace/Labyrinth.worktrees/meas-04 && python3 tools/encounter_shadow_report.py`. Existing checkpoints under the work directory resume automatically. No windowed proof or inspection fixture applies.
