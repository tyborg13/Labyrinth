# Last Light beside the Warband and the Umbral Snare (spx-08)

Revision 7 maps with Last Light and Ember Hoarder enabled (int-09), source HEAD `28e738838b4928fc21873a02c27835b54489c18a` plus the uncommitted int-09 integration. 150 natural rooms per cohort and tier, first seed 1, the unchanged policy-v2 bot (`policy_sha256` c90b92005d67…) and its tier deck presets. Numbers only; tuning is the director's.

| Tier | Cohort | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | Turn cap |
|---|---|---|---:|---:|---:|---:|---:|
| 1 | warband | kill_leader | 150 | 76.7% | 7 (4–30) | 10 (1–24) | 16 |
| 1 | snare | reach_exit | 150 | 82.7% | 3 (1–4) | 2.5 (0–24) | 0 |
| 1 | last_light | survive | 150 | 98.0% | 4 (3–4) | 6.5 (0–18) | 0 |
| 2 | warband | kill_leader | 150 | 61.3% | 9 (4–30) | 10 (0–24) | 33 |
| 2 | snare | reach_exit | 150 | 78.7% | 3 (2–5) | 4 (0–24) | 0 |
| 2 | last_light | survive | 150 | 97.3% | 4 (4–4) | 5 (0–16) | 0 |
| 3 | warband | kill_leader | 150 | 44.7% | 9 (3–30) | 22 (6–26) | 16 |
| 3 | snare | reach_exit | 150 | 80.7% | 3 (2–5) | 4 (0–24) | 1 |
| 3 | last_light | survive | 150 | 88.0% | 4 (4–5) | 8 (0–24) | 0 |

## Last Light braziers

Braziers lit at dawn count victories only (the brief's reward basis); Snuffs are per fight, all outcomes.

| Tier | Wins | Lit at dawn median (P10–P90) | 0 / 1 / 2 / 3 lit | Snuffs per fight mean | Snuffs median (P10–P90) |
|---|---:|---:|---:|---:|---:|
| 1 | 147 | 2 (1–3) | 12 / 30 / 54 / 51 | 1.24 | 1 (0–3) |
| 2 | 146 | 2 (1–3) | 13 / 28 / 42 / 63 | 1.23 | 1 (0–3) |
| 3 | 132 | 2 (1–3) | 12 / 22 / 46 / 52 | 1.17 | 1 (0–3) |

## Notes

- The bot policy has no objective term for braziers: it never walks to a brazier to relight it, so relights happen only when its dodge or approach steps onto one. Lit-at-dawn counts are a floor for a player who tends the braziers.
- Survive is not in the policy's objective-distance terms; it plays the room as Defeat All (damage, kills and dodging) until dawn.
- Enabling Last Light changes revision-7 special placement, so the Warband and Snare rows are re-measured on the same maps rather than taken from `measurements/revision7/`.
- Both new specials use `first_layout_revision: 7`; the shared place-level gate preserves revision-6 maps. `data_sha256` in `summary.json` records the exact merged catalog used for this measurement.

Reproduce: `python3 tools/last_light_measurement.py --runs 150 --workers 2`; raw gzipped records are beside this report.
