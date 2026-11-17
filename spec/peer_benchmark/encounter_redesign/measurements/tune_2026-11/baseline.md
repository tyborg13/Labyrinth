# diff-01 recomputed Health cost

Defeats (ending Health ≤0) cost 100; all other fights, including bot turn-cap outcomes, use gross Health lost / starting max Health. No baseline fights were rerun. Native section/depth/ladder-seed/repeat pairing is unchanged. 95% percentile intervals resample whole ladder-seed clusters (2,000 samples, seed 101), preserving repeated loadouts and shared controls. Wilson intervals describe win rates. The old raw files lack objective goal-met; it cannot be recovered and is marked unavailable.

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | normal | 192 / — | 35.5 [26.0, 47.0] | unavailable | unavailable [unavailable, unavailable] | baseline | unavailable |
| s0 | guardian | 64 / 64 | 41.1 [34.0, 48.6] | 29.7 | 11.5 [-2.0, 25.7] | 15–25 | 3.5 |
| s0 | boss | 64 / 64 | 67.3 [61.1, 73.7] | 49.5 | 17.7 [-2.5, 35.7] | 25–35 | 7.3 |
| s0 | warband | 16 / 16 | 27.1 [17.3, 34.7] | 31.2 | -4.2 [-17.6, 5.0] | 5–15 | 9.2 |
| s0 | umbral_snare | 9 / 9 | 0.0 [0.0, 0.0] | 59.7 | -59.7 [-87.5, -49.0] | 5–15 | 64.7 |
| s0 | last_light | 17 / 17 | 25.2 [15.4, 42.9] | 41.4 | -16.2 [-30.5, -3.1] | 5–15 | 21.2 |
| s0 | ember_hoarder | 22 / 22 | 23.1 [19.0, 26.9] | 28.2 | -5.1 [-23.7, 5.3] | 5–15 | 10.1 |
| s2 | normal | 192 / — | 65.7 [61.8, 70.6] | unavailable | unavailable [unavailable, unavailable] | baseline | unavailable |
| s2 | guardian | 64 / 64 | 60.5 [47.5, 75.3] | 65.6 | -5.0 [-17.7, 7.1] | 15–25 | 20.0 |
| s2 | boss | 64 / 64 | 87.5 [81.5, 93.2] | 89.0 | -1.5 [-11.7, 9.0] | 25–35 | 26.5 |
| s2 | warband | 22 / 22 | 69.5 [45.3, 92.2] | 78.4 | -8.9 [-27.3, 9.9] | 5–15 | 13.9 |
| s2 | umbral_snare | 12 / 12 | 25.0 [1.5, 48.5] | 74.3 | -49.3 [-68.1, -30.1] | 5–15 | 54.3 |
| s2 | last_light | 21 / 21 | 25.6 [16.3, 36.3] | 86.9 | -61.3 [-76.0, -46.6] | 5–15 | 66.3 |
| s2 | ember_hoarder | 9 / 9 | 36.6 [15.3, 50.0] | 59.7 | -23.1 [-47.2, 29.2] | 5–15 | 28.1 |
| s4 | normal | 192 / — | 74.5 [69.4, 79.4] | unavailable | unavailable [unavailable, unavailable] | baseline | unavailable |
| s4 | guardian | 64 / 64 | 86.4 [76.2, 95.8] | 77.5 | 8.9 [-0.5, 18.4] | 15–25 | 6.1 |
| s4 | boss | 64 / 64 | 86.9 [80.3, 94.0] | 89.6 | -2.8 [-13.8, 9.8] | 25–35 | 27.8 |
| s4 | warband | 15 / 15 | 82.0 [59.8, 96.6] | 85.2 | -3.1 [-29.8, 23.4] | 5–15 | 8.1 |
| s4 | umbral_snare | 12 / 12 | 39.6 [21.4, 53.9] | 79.5 | -39.8 [-69.2, -11.2] | 5–15 | 44.8 |
| s4 | last_light | 17 / 17 | 64.7 [50.9, 77.1] | 71.7 | -7.0 [-17.2, 5.1] | 5–15 | 12.0 |
| s4 | ember_hoarder | 20 / 20 | 52.3 [44.9, 58.7] | 93.9 | -41.6 [-54.2, -26.3] | 5–15 | 46.6 |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | normal | 192 | 85.4 [79.7, 89.7] | 7.0 | unavailable |
| s0 | guardian | 64 | 100.0 [94.3, 100.0] | 6.0 | unavailable |
| s0 | boss | 64 | 78.1 [66.6, 86.5] | 7.0 | unavailable |
| s0 | warband | 16 | 56.2 [33.2, 76.9] | 12.5 | unavailable |
| s0 | umbral_snare | 9 | 100.0 [70.1, 100.0] | 2 | unavailable |
| s0 | last_light | 17 | 100.0 [81.6, 100.0] | 4 | unavailable |
| s0 | ember_hoarder | 22 | 100.0 [85.1, 100.0] | 4.0 | unavailable |
| s2 | normal | 192 | 61.5 [54.4, 68.1] | 5.0 | unavailable |
| s2 | guardian | 64 | 79.7 [68.3, 87.7] | 6.5 | unavailable |
| s2 | boss | 64 | 40.6 [29.5, 52.9] | 5.0 | unavailable |
| s2 | warband | 22 | 50.0 [30.7, 69.3] | 7.0 | unavailable |
| s2 | umbral_snare | 12 | 83.3 [55.2, 95.3] | 2.0 | unavailable |
| s2 | last_light | 21 | 100.0 [84.5, 100.0] | 4 | unavailable |
| s2 | ember_hoarder | 9 | 100.0 [70.1, 100.0] | 5 | unavailable |
| s4 | normal | 192 | 47.9 [41.0, 55.0] | 5.0 | unavailable |
| s4 | guardian | 64 | 35.9 [25.3, 48.2] | 4.0 | unavailable |
| s4 | boss | 64 | 35.9 [25.3, 48.2] | 4.0 | unavailable |
| s4 | warband | 15 | 46.7 [24.8, 69.9] | 5 | unavailable |
| s4 | umbral_snare | 12 | 75.0 [46.8, 91.1] | 2.0 | unavailable |
| s4 | last_light | 17 | 64.7 [41.3, 82.7] | 4 | unavailable |
| s4 | ember_hoarder | 20 | 90.0 [69.9, 97.2] | 4.0 | unavailable |
### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|
| s0 | normal ≥ warband | compatible within 95% intervals | 85.4 / 56.2 |
| s0 | normal ≥ umbral_snare | compatible within 95% intervals | 85.4 / 100.0 |
| s0 | normal ≥ last_light | compatible within 95% intervals | 85.4 / 100.0 |
| s0 | normal ≥ ember_hoarder | compatible within 95% intervals | 85.4 / 100.0 |
| s0 | warband ≥ guardian | ORDER VIOLATION | 56.2 / 100.0 |
| s0 | umbral_snare ≥ guardian | compatible within 95% intervals | 100.0 / 100.0 |
| s0 | last_light ≥ guardian | compatible within 95% intervals | 100.0 / 100.0 |
| s0 | ember_hoarder ≥ guardian | compatible within 95% intervals | 100.0 / 100.0 |
| s0 | guardian ≥ boss | compatible within 95% intervals | 100.0 / 78.1 |
| s2 | normal ≥ warband | compatible within 95% intervals | 61.5 / 50.0 |
| s2 | normal ≥ umbral_snare | compatible within 95% intervals | 61.5 / 83.3 |
| s2 | normal ≥ last_light | ORDER VIOLATION | 61.5 / 100.0 |
| s2 | normal ≥ ember_hoarder | ORDER VIOLATION | 61.5 / 100.0 |
| s2 | warband ≥ guardian | compatible within 95% intervals | 50.0 / 79.7 |
| s2 | umbral_snare ≥ guardian | compatible within 95% intervals | 83.3 / 79.7 |
| s2 | last_light ≥ guardian | compatible within 95% intervals | 100.0 / 79.7 |
| s2 | ember_hoarder ≥ guardian | compatible within 95% intervals | 100.0 / 79.7 |
| s2 | guardian ≥ boss | compatible within 95% intervals | 79.7 / 40.6 |
| s4 | normal ≥ warband | compatible within 95% intervals | 47.9 / 46.7 |
| s4 | normal ≥ umbral_snare | compatible within 95% intervals | 47.9 / 75.0 |
| s4 | normal ≥ last_light | compatible within 95% intervals | 47.9 / 64.7 |
| s4 | normal ≥ ember_hoarder | ORDER VIOLATION | 47.9 / 90.0 |
| s4 | warband ≥ guardian | compatible within 95% intervals | 46.7 / 35.9 |
| s4 | umbral_snare ≥ guardian | compatible within 95% intervals | 75.0 / 35.9 |
| s4 | last_light ≥ guardian | compatible within 95% intervals | 64.7 / 35.9 |
| s4 | ember_hoarder ≥ guardian | compatible within 95% intervals | 90.0 / 35.9 |
| s4 | guardian ≥ boss | compatible within 95% intervals | 35.9 / 35.9 |

### Identity outliers (no base Health edits applied)

| Section | Tier | Identity | N | Cost | Matched gap | Outside band | Suggested base Health |
|---|---|---|---|---|---|---|---|
| s0 | guardian | rimejaw | 8 | 23.4 | -26.0 | 41.0 | 34 → 60 |
| s0 | boss | tharokh | 16 | 67.2 | -24.5 | 49.5 | 72 → 126 |
| s0 | boss | zekarion | 16 | 71.4 | +45.1 | 10.1 | 62 → 50 |
| s2 | guardian | ashen_reaver | 8 | 94.8 | -3.6 | 18.6 | 40 → 69 |
| s2 | guardian | storm_cantor | 24 | 64.2 | -20.5 | 35.5 | 66 → 116 |
| s2 | boss | tharokh | 32 | 83.9 | -10.5 | 35.5 | 72 → 126 |
| s2 | boss | vyraketh | 8 | 89.1 | -0.5 | 25.5 | 52 → 91 |
| s2 | boss | zekarion | 24 | 91.8 | +10.2 | 14.8 | 62 → 99 |
| s4 | guardian | rimejaw | 8 | 75.9 | -16.2 | 31.2 | 34 → 60 |
| s4 | boss | iskaldra | 8 | 76.9 | -19.0 | 44.0 | 62 → 109 |
| s4 | boss | vaeloryx | 24 | 86.1 | -13.9 | 38.9 | 50 → 88 |
| s4 | boss | vyraketh | 16 | 81.7 | -3.2 | 28.2 | 52 → 91 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.
