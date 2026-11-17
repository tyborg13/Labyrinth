# tune-01 review report

Campaign wall time: **14282.5 seconds**; search status: **budget reached**. Four low-priority simulation workers maximum. 0/18 cells have a full N=96 confirmation inside the Health-cost band. The table below evaluates the exact proposed Health/damage pairs; it never combines different dials.

Baseline: [cost and win tables](baseline.md). Count rule: [before/after census](census.md). Methods, focused checks and owner-run visual command: [implementation and proof](implementation.md). All stage tables and win-order/identity details remain in [the search report](search.md).

## Normal controls under the new count cap

| Section | N | Cost [95%] | Win % [95% Wilson] | Median turns |
|---|---|---|---|---|
| s0 | 244 | 41.3 [33.2, 50.4] | 78.7 [73.1, 83.4] | 9.0 |
| s2 | 258 | 70.5 [57.1, 84.1] | 55.4 [49.3, 61.4] | 6.0 |
| s4 | 253 | 78.1 [70.0, 87.1] | 41.5 [35.6, 47.7] | 5 |

These are unique section/depth/seed/repeat controls. Each target gap below reweights its exact matched controls, so its matched-normal cost can differ from the pooled section value.

## Proposed cost table

| Section | Cell | Health % / damage | N / paired / confirm | Baseline cost / gap | Proposed cost [95%] | Matched normal | Gap [95%] | Band | Outside | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| s0 | guardian | 115 / +0 | 89 / 89 / 89 | 41.1 / +11.5 | 51.8 [44.9, 58.8] | 31.2 | 20.6 [12.4, 28.7] | 15–25 | 0.0 | unconfirmed (89/96 confirmation fights) |
| s0 | dragon | 135 / +0 | 89 / 89 / 89 | 67.3 / +17.7 | 83.8 [78.8, 88.8] | 48.7 | 35.1 [9.6, 57.5] | 25–35 | 0.1 | unconfirmed (89/96 confirmation fights) |
| s0 | warband | 115 / +0 | 89 / 89 / 89 | 27.1 / -4.2 | 52.9 [43.6, 62.6] | 33.2 | 19.7 [8.8, 33.7] | 5–15 | 4.7 | unconfirmed (89/96 confirmation fights) |
| s0 | umbral_snare | 175 / +3 | 48 / 48 / 0 | 0.0 / -59.7 | 12.6 [0.0, 34.9] | 53.9 | -41.3 [-54.4, -26.6] | 5–15 | 46.3 | stat-limit probe outside band |
| s0 | last_light | 175 / +3 | 89 / 89 / 89 | 25.2 / -16.2 | 56.6 [45.6, 69.2] | 46.3 | 10.3 [-6.2, 26.4] | 5–15 | 0.0 | unconfirmed (89/96 confirmation fights) |
| s0 | ember_hoarder | 175 / +0 | 89 / 89 / 89 | 23.1 / -5.1 | 51.0 [44.7, 59.0] | 37.7 | 13.3 [-10.2, 29.6] | 5–15 | 0.0 | unconfirmed (89/96 confirmation fights) |
| s2 | guardian | 155 / +0 | 88 / 88 / 88 | 60.5 / -5.0 | 90.2 [84.0, 95.5] | 63.9 | 26.3 [14.1, 38.9] | 15–25 | 1.3 | unconfirmed (88/96 confirmation fights) |
| s2 | dragon | 175 / +3 | 48 / 48 / 0 | 87.5 / -1.5 | 100.0 [100.0, 100.0] | 90.5 | 9.5 [2.6, 17.4] | 25–35 | 15.5 | stat-limit probe outside band |
| s2 | warband | 150 / +0 | 88 / 88 / 88 | 69.5 / -8.9 | 87.2 [74.6, 96.5] | 75.4 | 11.9 [1.8, 20.9] | 5–15 | 0.0 | unconfirmed (88/96 confirmation fights) |
| s2 | umbral_snare | 175 / +3 | 48 / 48 / 0 | 25.0 / -49.3 | 36.0 [14.5, 56.5] | 84.3 | -48.3 [-65.5, -28.6] | 5–15 | 53.3 | stat-limit probe outside band |
| s2 | last_light | 175 / +3 | 48 / 48 / 0 | 25.6 / -61.3 | 82.2 [67.0, 94.0] | 81.3 | 0.9 [-9.5, 13.3] | 5–15 | 4.1 | stat-limit probe outside band |
| s2 | ember_hoarder | 175 / +2 | 89 / 89 / 89 | 36.6 / -23.1 | 75.9 [67.1, 86.0] | 64.7 | 11.3 [-6.6, 46.1] | 5–15 | 0.0 | unconfirmed (89/96 confirmation fights) |
| s4 | guardian | 150 / +0 | 89 / 89 / 89 | 86.4 / +8.9 | 97.3 [93.5, 100.0] | 78.4 | 18.9 [7.2, 34.9] | 15–25 | 0.0 | unconfirmed (89/96 confirmation fights) |
| s4 | dragon | 175 / +3 | 48 / 48 / 0 | 86.9 / -2.8 | 99.7 [99.1, 100.0] | 89.3 | 10.4 [4.3, 16.9] | 25–35 | 14.6 | stat-limit probe outside band |
| s4 | warband | 130 / +0 | 89 / 88 / 89 | 82.0 / -3.1 | 93.4 [83.4, 99.6] | 84.5 | 8.9 [-9.4, 32.0] | 5–15 | 0.0 | incomplete pairing (88/89) |
| s4 | umbral_snare | 175 / +3 | 48 / 48 / 0 | 39.6 / -39.8 | 59.9 [41.1, 86.4] | 82.3 | -22.3 [-42.5, -4.9] | 5–15 | 27.3 | stat-limit probe outside band |
| s4 | last_light | 175 / +0 | 88 / 88 / 88 | 64.7 / -7.0 | 72.7 [61.4, 83.2] | 76.3 | -3.6 [-13.5, 7.9] | 5–15 | 8.6 | unconfirmed (88/96 confirmation fights) |
| s4 | ember_hoarder | 175 / +3 | 48 / 48 / 0 | 52.3 / -41.6 | 93.2 [88.6, 97.5] | 90.6 | 2.5 [-6.2, 11.1] | 5–15 | 2.5 | stat-limit probe outside band |

## Proposed win-rate table

| Section | Cell | N | Win % [95% Wilson] | Median turns | Objective goal met % |
|---|---|---|---|---|---|
| s0 | guardian | 89 | 97.8 [92.2, 99.4] | 7 | — |
| s0 | dragon | 89 | 57.3 [46.9, 67.1] | 9 | — |
| s0 | warband | 89 | 60.7 [50.3, 70.2] | 14 | 60.7 |
| s0 | umbral_snare | 48 | 97.9 [89.1, 99.6] | 2.0 | 97.9 |
| s0 | last_light | 89 | 84.3 [75.3, 90.4] | 4 | 84.3 |
| s0 | ember_hoarder | 89 | 98.9 [93.9, 99.8] | 4 | 2.2 |
| s2 | guardian | 88 | 34.1 [25.0, 44.5] | 7.5 | — |
| s2 | dragon | 48 | 0.0 [0.0, 7.4] | 4.0 | — |
| s2 | warband | 88 | 31.8 [23.0, 42.1] | 6.0 | 31.8 |
| s2 | umbral_snare | 48 | 79.2 [65.7, 88.3] | 2.0 | 79.2 |
| s2 | last_light | 48 | 41.7 [28.8, 55.7] | 4.0 | 41.7 |
| s2 | ember_hoarder | 89 | 64.0 [53.7, 73.2] | 4 | 1.1 |
| s4 | guardian | 89 | 7.9 [3.9, 15.4] | 3 | — |
| s4 | dragon | 48 | 2.1 [0.4, 10.9] | 2.0 | — |
| s4 | warband | 89 | 11.2 [6.2, 19.5] | 4 | 11.2 |
| s4 | umbral_snare | 48 | 54.2 [40.3, 67.4] | 2.0 | 54.2 |
| s4 | last_light | 88 | 68.2 [57.9, 77.0] | 4.0 | 68.2 |
| s4 | ember_hoarder | 48 | 20.8 [11.7, 34.3] | 2.0 | 0.0 |

N counts unique native-room/seed/repeat cases at the exact proposed dials. Identical probe/confirmation repeats are deduplicated, with their confirmation label retained; raw repeated executions remain archived. Gap intervals preserve shared normal controls and resample whole loadout clusters. Unmatched deadline-cutoff cases are retained in raw costs but excluded from gaps. The original baseline lacks goal-met flags.

## Win-order feasibility within the intervals

| Section | Required order | Joint interval result |
|---|---|---|
| s0 | normal ≥ warband ≥ Guardian ≥ dragon | ORDER VIOLATION |
| s0 | normal ≥ umbral_snare ≥ Guardian ≥ dragon | ORDER VIOLATION |
| s0 | normal ≥ last_light ≥ Guardian ≥ dragon | ORDER VIOLATION |
| s0 | normal ≥ ember_hoarder ≥ Guardian ≥ dragon | ORDER VIOLATION |
| s2 | normal ≥ warband ≥ Guardian ≥ dragon | compatible |
| s2 | normal ≥ umbral_snare ≥ Guardian ≥ dragon | ORDER VIOLATION |
| s2 | normal ≥ last_light ≥ Guardian ≥ dragon | compatible |
| s2 | normal ≥ ember_hoarder ≥ Guardian ≥ dragon | compatible |
| s4 | normal ≥ warband ≥ Guardian ≥ dragon | compatible |
| s4 | normal ≥ umbral_snare ≥ Guardian ≥ dragon | compatible |
| s4 | normal ≥ last_light ≥ Guardian ≥ dragon | ORDER VIOLATION |
| s4 | normal ≥ ember_hoarder ≥ Guardian ≥ dragon | compatible |

The joint check requires one consistent ordering inside all four intervals; pairwise interval overlap alone does not establish that ordering.

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|
| s0 | normal ≥ warband | compatible within 95% intervals | 78.7 / 60.7 |
| s0 | normal ≥ umbral_snare | ORDER VIOLATION | 78.7 / 97.9 |
| s0 | normal ≥ last_light | compatible within 95% intervals | 78.7 / 84.3 |
| s0 | normal ≥ ember_hoarder | ORDER VIOLATION | 78.7 / 98.9 |
| s0 | warband ≥ guardian | ORDER VIOLATION | 60.7 / 97.8 |
| s0 | umbral_snare ≥ guardian | compatible within 95% intervals | 97.9 / 97.8 |
| s0 | last_light ≥ guardian | ORDER VIOLATION | 84.3 / 97.8 |
| s0 | ember_hoarder ≥ guardian | compatible within 95% intervals | 98.9 / 97.8 |
| s0 | guardian ≥ boss | compatible within 95% intervals | 97.8 / 57.3 |
| s2 | normal ≥ warband | compatible within 95% intervals | 55.4 / 31.8 |
| s2 | normal ≥ umbral_snare | ORDER VIOLATION | 55.4 / 79.2 |
| s2 | normal ≥ last_light | compatible within 95% intervals | 55.4 / 41.7 |
| s2 | normal ≥ ember_hoarder | compatible within 95% intervals | 55.4 / 64.0 |
| s2 | warband ≥ guardian | compatible within 95% intervals | 31.8 / 34.1 |
| s2 | umbral_snare ≥ guardian | compatible within 95% intervals | 79.2 / 34.1 |
| s2 | last_light ≥ guardian | compatible within 95% intervals | 41.7 / 34.1 |
| s2 | ember_hoarder ≥ guardian | compatible within 95% intervals | 64.0 / 34.1 |
| s2 | guardian ≥ boss | compatible within 95% intervals | 34.1 / 0.0 |
| s4 | normal ≥ warband | compatible within 95% intervals | 41.5 / 11.2 |
| s4 | normal ≥ umbral_snare | compatible within 95% intervals | 41.5 / 54.2 |
| s4 | normal ≥ last_light | ORDER VIOLATION | 41.5 / 68.2 |
| s4 | normal ≥ ember_hoarder | compatible within 95% intervals | 41.5 / 20.8 |
| s4 | warband ≥ guardian | compatible within 95% intervals | 11.2 / 7.9 |
| s4 | umbral_snare ≥ guardian | compatible within 95% intervals | 54.2 / 7.9 |
| s4 | last_light ≥ guardian | compatible within 95% intervals | 68.2 / 7.9 |
| s4 | ember_hoarder ≥ guardian | compatible within 95% intervals | 20.8 / 7.9 |
| s4 | guardian ≥ boss | compatible within 95% intervals | 7.9 / 2.1 |

### Identity outliers (no base Health edits applied)

| Section | Tier | Identity | N | Cost | Matched gap | Outside band | Suggested base Health |
|---|---|---|---|---|---|---|---|
| s0 | guardian | rimejaw | 11 | 52.7 | +2.3 | 12.7 | 34 → 53 |
| s0 | boss | iskaldra | 11 | 79.9 | +46.2 | 11.2 | 62 → 50 |
| s0 | boss | tharokh | 23 | 75.0 | -15.6 | 40.6 | 72 → 126 |
| s0 | boss | vaeloryx | 22 | 88.3 | +62.5 | 27.5 | 50 → 40 |
| s0 | boss | zekarion | 22 | 92.2 | +63.6 | 28.6 | 62 → 50 |
| s2 | guardian | ashen_reaver | 11 | 97.7 | -1.1 | 16.1 | 40 → 66 |
| s2 | guardian | craghide | 44 | 85.2 | +43.1 | 18.1 | 44 → 36 |
| s2 | boss | tharokh | 24 | 100.0 | +5.9 | 19.1 | 72 → 125 |
| s2 | boss | vyraketh | 6 | 100.0 | +0.0 | 25.0 | 52 → 91 |
| s4 | guardian | storm_cantor | 22 | 89.2 | +50.5 | 25.5 | 66 → 53 |
| s4 | boss | iskaldra | 6 | 100.0 | +5.6 | 19.4 | 62 → 108 |
| s4 | boss | vaeloryx | 18 | 100.0 | +0.0 | 25.0 | 50 → 88 |
| s4 | boss | vyraketh | 12 | 98.8 | +14.9 | 10.1 | 52 → 76 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## Unmeasured sections

| Section | Cell | Health % | Damage | Source |
|---|---|---|---|---|
| s1 | guardian | 135 | 0 | interpolated |
| s3 | guardian | 155 | 0 | interpolated |
| s5 | guardian | 150 | 0 | copied s4 |
| s1 | boss | 155 | TODO_DESIGN_BOSS_S1_FRACTIONAL_DAMAGE_ROUNDING | interpolated |
| s3 | boss | 175 | 3 | interpolated |
| s5 | boss | 175 | 3 | copied s4 |
| s1 | warband | 135 | 0 | interpolated |
| s3 | warband | 140 | 0 | interpolated |
| s5 | warband | 130 | 0 | copied s4 |
| s1 | umbral_snare | 175 | 3 | interpolated |
| s3 | umbral_snare | 175 | 3 | interpolated |
| s5 | umbral_snare | 175 | 3 | copied s4 |
| s1 | last_light | 175 | 3 | interpolated |
| s3 | last_light | 175 | TODO_DESIGN_LAST_LIGHT_S3_FRACTIONAL_DAMAGE_ROUNDING | interpolated |
| s5 | last_light | 175 | 0 | copied s4 |
| s1 | ember_hoarder | 175 | 1 | interpolated |
| s3 | ember_hoarder | 175 | TODO_DESIGN_EMBER_HOARDER_S3_FRACTIONAL_DAMAGE_ROUNDING | interpolated |
| s5 | ember_hoarder | 175 | 3 | copied s4 |

## TODO_DESIGN and open issues

- TODO_DESIGN_BOSS_S1_FRACTIONAL_DAMAGE_ROUNDING
- TODO_DESIGN_LAST_LIGHT_S3_FRACTIONAL_DAMAGE_ROUNDING
- TODO_DESIGN_EMBER_HOARDER_S3_FRACTIONAL_DAMAGE_ROUNDING

The named `TODO_DESIGN_FRACTIONAL_DAMAGE_FALLBACK` constant retains the prior zero tier addition if an unapproved fractional interpolation is present. Each unresolved band/sample status is listed above. The design owner decides objective redesigns and base-Health identity suggestions; no `data/enemies.json` edits were applied. Windowed Hunted captures remain owner-run.
