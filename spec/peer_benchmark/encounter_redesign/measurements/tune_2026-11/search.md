# tune-01 proposed stat search

Wall time 14282.5s; peak workers ≤4, four low-priority simulation threads (macOS Utility QoS; process nice unavailable). Bot SHA c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82.

## normal

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | normal | 244 / — | 41.3 [33.2, 50.4] | unavailable | unavailable [unavailable, unavailable] | baseline | unavailable |
| s2 | normal | 258 / — | 70.5 [57.1, 84.1] | unavailable | unavailable [unavailable, unavailable] | baseline | unavailable |
| s4 | normal | 253 / — | 78.1 [70.0, 87.1] | unavailable | unavailable [unavailable, unavailable] | baseline | unavailable |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | normal | 244 | 78.7 [73.1, 83.4] | 9.0 | 78.7 |
| s2 | normal | 258 | 55.4 [49.3, 61.4] | 6.0 | 55.4 |
| s4 | normal | 253 | 41.5 [35.6, 47.7] | 5 | 41.5 |

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|

### Identity outliers (no base Health edits applied)

No measured identity exceeds the tier band by more than 10 points.

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## probe

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | guardian | 48 / 48 | 54.6 [47.6, 62.2] | 27.1 | 27.5 [20.8, 33.8] | 15–25 | 2.5 |
| s0 | boss | 48 / 48 | 80.0 [71.9, 87.4] | 50.3 | 29.8 [0.1, 55.5] | 25–35 | 0.0 |
| s0 | warband | 48 / 48 | 61.7 [49.8, 75.1] | 30.4 | 31.3 [10.6, 53.3] | 5–15 | 16.3 |
| s0 | umbral_snare | 48 / 48 | 11.0 [1.3, 25.5] | 53.9 | -42.9 [-63.8, -23.2] | 5–15 | 47.9 |
| s0 | last_light | 48 / 48 | 33.2 [25.4, 44.1] | 44.7 | -11.5 [-27.2, 4.4] | 5–15 | 16.5 |
| s0 | ember_hoarder | 48 / 48 | 38.8 [31.2, 46.5] | 34.9 | 3.9 [-19.6, 20.1] | 5–15 | 1.1 |
| s2 | guardian | 48 / 48 | 93.2 [89.1, 97.0] | 64.7 | 28.5 [14.0, 42.8] | 15–25 | 3.5 |
| s2 | boss | 48 / 48 | 97.9 [95.5, 100.0] | 90.5 | 7.4 [0.2, 16.1] | 25–35 | 17.6 |
| s2 | warband | 48 / 48 | 84.5 [66.4, 96.6] | 73.1 | 11.5 [1.5, 22.0] | 5–15 | 0.0 |
| s2 | umbral_snare | 48 / 48 | 31.9 [11.2, 52.8] | 84.3 | -52.4 [-69.6, -33.1] | 5–15 | 57.4 |
| s2 | last_light | 48 / 48 | 66.8 [50.8, 83.1] | 81.3 | -14.4 [-31.1, 2.1] | 5–15 | 19.4 |
| s2 | ember_hoarder | 48 / 48 | 60.7 [50.8, 67.7] | 67.1 | -6.4 [-27.6, 26.3] | 5–15 | 11.4 |
| s4 | guardian | 48 / 48 | 97.1 [93.2, 99.8] | 80.2 | 16.8 [7.7, 27.2] | 15–25 | 0.0 |
| s4 | boss | 48 / 48 | 99.6 [99.2, 100.0] | 89.3 | 10.3 [4.3, 17.7] | 25–35 | 14.7 |
| s4 | warband | 48 / 48 | 96.9 [93.5, 100.0] | 82.9 | 14.0 [-0.4, 35.6] | 5–15 | 0.0 |
| s4 | umbral_snare | 48 / 48 | 52.1 [33.8, 77.7] | 82.3 | -30.2 [-50.3, -13.3] | 5–15 | 35.2 |
| s4 | last_light | 48 / 48 | 71.3 [58.6, 84.0] | 72.1 | -0.8 [-10.8, 15.6] | 5–15 | 5.8 |
| s4 | ember_hoarder | 48 / 48 | 86.0 [81.5, 91.1] | 90.6 | -4.6 [-14.6, 6.1] | 5–15 | 9.6 |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | guardian | 48 | 91.7 [80.4, 96.7] | 7.0 | 91.7 |
| s0 | boss | 48 | 68.8 [54.7, 80.1] | 9.0 | 68.8 |
| s0 | warband | 48 | 50.0 [36.4, 63.6] | 15.5 | 50.0 |
| s0 | umbral_snare | 48 | 100.0 [92.6, 100.0] | 2.0 | 100.0 |
| s0 | last_light | 48 | 97.9 [89.1, 99.6] | 4.0 | 97.9 |
| s0 | ember_hoarder | 48 | 97.9 [89.1, 99.6] | 4.0 | 4.2 |
| s2 | guardian | 48 | 31.2 [19.9, 45.3] | 7.5 | 31.2 |
| s2 | boss | 48 | 4.2 [1.2, 14.0] | 5.0 | 4.2 |
| s2 | warband | 48 | 33.3 [21.7, 47.5] | 7.0 | 33.3 |
| s2 | umbral_snare | 48 | 77.1 [63.5, 86.7] | 2.0 | 77.1 |
| s2 | last_light | 48 | 66.7 [52.5, 78.3] | 4.0 | 66.7 |
| s2 | ember_hoarder | 48 | 87.5 [75.3, 94.1] | 5.0 | 0.0 |
| s4 | guardian | 48 | 16.7 [8.7, 29.6] | 3.0 | 16.7 |
| s4 | boss | 48 | 4.2 [1.2, 14.0] | 4.0 | 4.2 |
| s4 | warband | 48 | 6.2 [2.1, 16.8] | 4.0 | 6.2 |
| s4 | umbral_snare | 48 | 66.7 [52.5, 78.3] | 2.0 | 66.7 |
| s4 | last_light | 48 | 60.4 [46.3, 73.0] | 4.0 | 60.4 |
| s4 | ember_hoarder | 48 | 50.0 [36.4, 63.6] | 4.0 | 0.0 |

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|
| s0 | warband ≥ guardian | ORDER VIOLATION | 50.0 / 91.7 |
| s0 | umbral_snare ≥ guardian | compatible within 95% intervals | 100.0 / 91.7 |
| s0 | last_light ≥ guardian | compatible within 95% intervals | 97.9 / 91.7 |
| s0 | ember_hoarder ≥ guardian | compatible within 95% intervals | 97.9 / 91.7 |
| s0 | guardian ≥ boss | compatible within 95% intervals | 91.7 / 68.8 |
| s2 | warband ≥ guardian | compatible within 95% intervals | 33.3 / 31.2 |
| s2 | umbral_snare ≥ guardian | compatible within 95% intervals | 77.1 / 31.2 |
| s2 | last_light ≥ guardian | compatible within 95% intervals | 66.7 / 31.2 |
| s2 | ember_hoarder ≥ guardian | compatible within 95% intervals | 87.5 / 31.2 |
| s2 | guardian ≥ boss | compatible within 95% intervals | 31.2 / 4.2 |
| s4 | warband ≥ guardian | compatible within 95% intervals | 6.2 / 16.7 |
| s4 | umbral_snare ≥ guardian | compatible within 95% intervals | 66.7 / 16.7 |
| s4 | last_light ≥ guardian | compatible within 95% intervals | 60.4 / 16.7 |
| s4 | ember_hoarder ≥ guardian | compatible within 95% intervals | 50.0 / 16.7 |
| s4 | guardian ≥ boss | compatible within 95% intervals | 16.7 / 4.2 |

### Identity outliers (no base Health edits applied)

| Section | Tier | Identity | N | Cost | Matched gap | Outside band | Suggested base Health |
|---|---|---|---|---|---|---|---|
| s0 | guardian | ashen_reaver | 6 | 69.4 | +38.2 | 13.2 | 40 → 32 |
| s0 | boss | tharokh | 12 | 66.7 | -27.1 | 52.1 | 72 → 126 |
| s0 | boss | vaeloryx | 12 | 93.4 | +67.4 | 32.4 | 50 → 40 |
| s0 | boss | vyraketh | 6 | 71.5 | +0.7 | 24.3 | 52 → 91 |
| s0 | boss | zekarion | 12 | 87.8 | +63.2 | 28.2 | 62 → 50 |
| s2 | guardian | ashen_reaver | 6 | 95.8 | -2.1 | 17.1 | 40 → 67 |
| s2 | guardian | craghide | 24 | 92.3 | +47.3 | 22.3 | 44 → 36 |
| s2 | boss | tharokh | 24 | 95.8 | +1.7 | 23.3 | 72 → 126 |
| s2 | boss | vyraketh | 6 | 100.0 | +0.0 | 25.0 | 52 → 91 |
| s4 | guardian | rimejaw | 6 | 98.8 | +1.9 | 13.1 | 34 → 53 |
| s4 | guardian | storm_cantor | 12 | 88.9 | +35.5 | 10.5 | 66 → 53 |
| s4 | boss | iskaldra | 6 | 100.0 | +5.6 | 19.4 | 62 → 108 |
| s4 | boss | vaeloryx | 18 | 100.0 | +0.0 | 25.0 | 50 → 88 |
| s4 | boss | vyraketh | 12 | 98.5 | +14.7 | 10.3 | 52 → 76 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## damage1

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | umbral_snare | 48 / 48 | 14.5 [2.1, 37.8] | 53.9 | -39.4 [-51.6, -25.8] | 5–15 | 44.4 |
| s0 | last_light | 48 / 48 | 40.5 [30.8, 53.1] | 44.7 | -4.2 [-19.4, 10.5] | 5–15 | 9.2 |
| s2 | boss | 48 / 48 | 98.9 [96.8, 100.0] | 90.5 | 8.4 [1.8, 16.5] | 25–35 | 16.6 |
| s2 | umbral_snare | 48 / 48 | 33.1 [13.5, 51.1] | 84.3 | -51.2 [-66.6, -34.6] | 5–15 | 56.2 |
| s2 | last_light | 48 / 48 | 75.3 [61.7, 88.3] | 81.3 | -6.0 [-20.3, 8.4] | 5–15 | 11.0 |
| s2 | ember_hoarder | 48 / 48 | 70.0 [64.3, 76.6] | 67.1 | 2.9 [-18.8, 39.8] | 5–15 | 2.1 |
| s4 | boss | 48 / 48 | 99.7 [99.2, 100.0] | 89.3 | 10.5 [4.4, 17.7] | 25–35 | 14.5 |
| s4 | umbral_snare | 48 / 48 | 54.2 [33.9, 77.6] | 82.3 | -28.1 [-51.0, -12.5] | 5–15 | 33.1 |
| s4 | ember_hoarder | 48 / 48 | 88.5 [82.2, 95.1] | 90.6 | -2.1 [-12.8, 7.9] | 5–15 | 7.1 |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | umbral_snare | 48 | 95.8 [86.0, 98.8] | 2.0 | 95.8 |
| s0 | last_light | 48 | 95.8 [86.0, 98.8] | 4.0 | 95.8 |
| s2 | boss | 48 | 4.2 [1.2, 14.0] | 4.0 | 4.2 |
| s2 | umbral_snare | 48 | 81.2 [68.1, 89.8] | 2.5 | 81.2 |
| s2 | last_light | 48 | 58.3 [44.3, 71.2] | 4.0 | 58.3 |
| s2 | ember_hoarder | 48 | 83.3 [70.4, 91.3] | 4.0 | 0.0 |
| s4 | boss | 48 | 2.1 [0.4, 10.9] | 3.0 | 2.1 |
| s4 | umbral_snare | 48 | 68.8 [54.7, 80.1] | 2.0 | 68.8 |
| s4 | ember_hoarder | 48 | 43.8 [30.7, 57.7] | 4.0 | 0.0 |

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|

### Identity outliers (no base Health edits applied)

| Section | Tier | Identity | N | Cost | Matched gap | Outside band | Suggested base Health |
|---|---|---|---|---|---|---|---|
| s2 | boss | tharokh | 24 | 97.7 | +3.6 | 21.4 | 72 → 126 |
| s2 | boss | vyraketh | 6 | 100.0 | +0.0 | 25.0 | 52 → 91 |
| s4 | boss | iskaldra | 6 | 100.0 | +5.6 | 19.4 | 62 → 108 |
| s4 | boss | vaeloryx | 18 | 100.0 | +0.0 | 25.0 | 50 → 88 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## damage2

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | umbral_snare | 48 / 48 | 12.8 [0.0, 34.9] | 53.9 | -41.1 [-54.4, -25.8] | 5–15 | 46.1 |
| s0 | last_light | 48 / 48 | 49.5 [38.0, 63.0] | 44.7 | 4.8 [-13.6, 22.4] | 5–15 | 0.2 |
| s2 | boss | 48 / 48 | 99.2 [97.7, 100.0] | 90.5 | 8.7 [2.3, 16.8] | 25–35 | 16.3 |
| s2 | umbral_snare | 48 / 48 | 33.6 [13.1, 53.4] | 84.3 | -50.7 [-67.4, -31.6] | 5–15 | 55.7 |
| s2 | last_light | 48 / 48 | 77.7 [61.5, 91.3] | 81.3 | -3.6 [-16.4, 9.8] | 5–15 | 8.6 |
| s2 | ember_hoarder | 48 / 48 | 75.2 [69.0, 84.1] | 67.1 | 8.1 [-11.2, 44.5] | 5–15 | 0.0 |
| s4 | boss | 48 / 48 | 100.0 [100.0, 100.0] | 89.3 | 10.7 [4.4, 18.2] | 25–35 | 14.3 |
| s4 | umbral_snare | 48 / 48 | 57.4 [34.3, 87.3] | 82.3 | -24.9 [-49.4, -4.0] | 5–15 | 29.9 |
| s4 | ember_hoarder | 48 / 48 | 92.0 [87.1, 96.4] | 90.6 | 1.4 [-9.2, 11.6] | 5–15 | 3.6 |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | umbral_snare | 48 | 95.8 [86.0, 98.8] | 2.0 | 95.8 |
| s0 | last_light | 48 | 91.7 [80.4, 96.7] | 4.0 | 91.7 |
| s2 | boss | 48 | 2.1 [0.4, 10.9] | 4.0 | 2.1 |
| s2 | umbral_snare | 48 | 79.2 [65.7, 88.3] | 2.0 | 79.2 |
| s2 | last_light | 48 | 56.2 [42.3, 69.3] | 4.0 | 56.2 |
| s2 | ember_hoarder | 48 | 62.5 [48.4, 74.8] | 4.0 | 0.0 |
| s4 | boss | 48 | 0.0 [0.0, 7.4] | 3.0 | 0.0 |
| s4 | umbral_snare | 48 | 52.1 [38.3, 65.5] | 2.0 | 52.1 |
| s4 | ember_hoarder | 48 | 29.2 [18.2, 43.2] | 3.0 | 0.0 |

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|

### Identity outliers (no base Health edits applied)

| Section | Tier | Identity | N | Cost | Matched gap | Outside band | Suggested base Health |
|---|---|---|---|---|---|---|---|
| s2 | boss | tharokh | 24 | 98.4 | +4.3 | 20.7 | 72 → 126 |
| s2 | boss | vyraketh | 6 | 100.0 | +0.0 | 25.0 | 52 → 91 |
| s4 | boss | iskaldra | 6 | 100.0 | +5.6 | 19.4 | 62 → 108 |
| s4 | boss | vaeloryx | 18 | 100.0 | +0.0 | 25.0 | 50 → 88 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## damage3

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | umbral_snare | 48 / 48 | 12.6 [0.0, 34.9] | 53.9 | -41.3 [-54.4, -26.6] | 5–15 | 46.3 |
| s0 | last_light | 48 / 48 | 57.1 [45.1, 69.9] | 44.7 | 12.4 [-7.9, 31.9] | 5–15 | 0.0 |
| s2 | boss | 48 / 48 | 100.0 [100.0, 100.0] | 90.5 | 9.5 [2.8, 17.2] | 25–35 | 15.5 |
| s2 | umbral_snare | 48 / 48 | 36.0 [14.5, 56.5] | 84.3 | -48.3 [-65.5, -28.6] | 5–15 | 53.3 |
| s2 | last_light | 48 / 48 | 82.2 [66.3, 94.1] | 81.3 | 0.9 [-10.1, 13.1] | 5–15 | 4.1 |
| s4 | boss | 48 / 48 | 99.7 [99.1, 100.0] | 89.3 | 10.4 [4.3, 17.9] | 25–35 | 14.6 |
| s4 | umbral_snare | 48 / 48 | 59.9 [41.1, 86.4] | 82.3 | -22.3 [-42.5, -4.9] | 5–15 | 27.3 |
| s4 | ember_hoarder | 48 / 48 | 93.2 [88.5, 97.2] | 90.6 | 2.5 [-7.1, 11.4] | 5–15 | 2.5 |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | umbral_snare | 48 | 97.9 [89.1, 99.6] | 2.0 | 97.9 |
| s0 | last_light | 48 | 85.4 [72.8, 92.8] | 4.0 | 85.4 |
| s2 | boss | 48 | 0.0 [0.0, 7.4] | 4.0 | 0.0 |
| s2 | umbral_snare | 48 | 79.2 [65.7, 88.3] | 2.0 | 79.2 |
| s2 | last_light | 48 | 41.7 [28.8, 55.7] | 4.0 | 41.7 |
| s4 | boss | 48 | 2.1 [0.4, 10.9] | 2.0 | 2.1 |
| s4 | umbral_snare | 48 | 54.2 [40.3, 67.4] | 2.0 | 54.2 |
| s4 | ember_hoarder | 48 | 20.8 [11.7, 34.3] | 2.0 | 0.0 |

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|

### Identity outliers (no base Health edits applied)

| Section | Tier | Identity | N | Cost | Matched gap | Outside band | Suggested base Health |
|---|---|---|---|---|---|---|---|
| s2 | boss | tharokh | 24 | 100.0 | +5.9 | 19.1 | 72 → 125 |
| s2 | boss | vyraketh | 6 | 100.0 | +0.0 | 25.0 | 52 → 91 |
| s4 | boss | iskaldra | 6 | 100.0 | +5.6 | 19.4 | 62 → 108 |
| s4 | boss | vaeloryx | 18 | 100.0 | +0.0 | 25.0 | 50 → 88 |
| s4 | boss | vyraketh | 12 | 98.8 | +14.9 | 10.1 | 52 → 76 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## confirm

| Section | Cell | N / paired | Cost [95%] | Matched normal | Gap [95%] | Band | Outside |
|---|---|---|---|---|---|---|---|
| s0 | guardian | 89 / 89 | 51.8 [45.4, 58.7] | 31.2 | 20.6 [12.3, 29.2] | 15–25 | 0.0 |
| s0 | boss | 89 / 89 | 83.8 [78.8, 88.8] | 48.7 | 35.1 [9.6, 57.5] | 25–35 | 0.1 |
| s0 | warband | 89 / 89 | 52.9 [43.6, 62.6] | 33.2 | 19.7 [8.8, 34.4] | 5–15 | 4.7 |
| s0 | last_light | 89 / 89 | 56.6 [45.6, 69.2] | 46.3 | 10.3 [-5.8, 26.4] | 5–15 | 0.0 |
| s0 | ember_hoarder | 89 / 89 | 51.0 [44.7, 59.0] | 37.7 | 13.3 [-10.2, 29.6] | 5–15 | 0.0 |
| s2 | guardian | 88 / 88 | 90.2 [84.1, 95.6] | 63.9 | 26.3 [12.9, 39.2] | 15–25 | 1.3 |
| s2 | warband | 88 / 88 | 87.2 [74.6, 96.5] | 75.4 | 11.9 [1.8, 20.9] | 5–15 | 0.0 |
| s2 | ember_hoarder | 89 / 89 | 75.9 [67.1, 86.0] | 64.7 | 11.3 [-6.6, 46.1] | 5–15 | 0.0 |
| s4 | guardian | 89 / 89 | 97.3 [93.5, 100.0] | 78.4 | 18.9 [7.2, 34.9] | 15–25 | 0.0 |
| s4 | warband | 89 / 88 | 93.4 [83.4, 99.6] | 84.5 | 8.9 [-9.4, 32.0] | 5–15 | 0.0 |
| s4 | last_light | 88 / 88 | 72.7 [61.4, 83.2] | 76.3 | -3.6 [-13.5, 7.9] | 5–15 | 8.6 |

| Section | Cell | N | Win % [95% Wilson] | Median turns | Goal met % |
|---|---|---|---|---|---|
| s0 | guardian | 89 | 97.8 [92.2, 99.4] | 7 | 97.8 |
| s0 | boss | 89 | 57.3 [46.9, 67.1] | 9 | 57.3 |
| s0 | warband | 89 | 60.7 [50.3, 70.2] | 14 | 60.7 |
| s0 | last_light | 89 | 84.3 [75.3, 90.4] | 4 | 84.3 |
| s0 | ember_hoarder | 89 | 98.9 [93.9, 99.8] | 4 | 2.2 |
| s2 | guardian | 88 | 34.1 [25.0, 44.5] | 7.5 | 34.1 |
| s2 | warband | 88 | 31.8 [23.0, 42.1] | 6.0 | 31.8 |
| s2 | ember_hoarder | 89 | 64.0 [53.7, 73.2] | 4 | 1.1 |
| s4 | guardian | 89 | 7.9 [3.9, 15.4] | 3 | 7.9 |
| s4 | warband | 89 | 11.2 [6.2, 19.5] | 4 | 11.2 |
| s4 | last_light | 88 | 68.2 [57.9, 77.0] | 4.0 | 68.2 |

### Win-rate order

| Section | Required order | Result | Win % |
|---|---|---|---|
| s0 | warband ≥ guardian | ORDER VIOLATION | 60.7 / 97.8 |
| s0 | last_light ≥ guardian | ORDER VIOLATION | 84.3 / 97.8 |
| s0 | ember_hoarder ≥ guardian | compatible within 95% intervals | 98.9 / 97.8 |
| s0 | guardian ≥ boss | compatible within 95% intervals | 97.8 / 57.3 |
| s2 | warband ≥ guardian | compatible within 95% intervals | 31.8 / 34.1 |
| s2 | ember_hoarder ≥ guardian | compatible within 95% intervals | 64.0 / 34.1 |
| s4 | warband ≥ guardian | compatible within 95% intervals | 11.2 / 7.9 |
| s4 | last_light ≥ guardian | compatible within 95% intervals | 68.2 / 7.9 |

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
| s4 | guardian | storm_cantor | 22 | 89.2 | +50.5 | 25.5 | 66 → 53 |

Base-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.

## Cell status

- 0:guardian: confirmation incomplete; proposed hp/damage [115, 0]
- 0:boss: confirmation incomplete; proposed hp/damage [135, 0]
- 0:warband: confirmation incomplete; proposed hp/damage [115, 0]
- 0:umbral_snare: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
- 0:last_light: confirmation incomplete; proposed hp/damage [175, 3]
- 0:ember_hoarder: confirmation incomplete; proposed hp/damage [175, 0]
- 2:guardian: confirmation incomplete; proposed hp/damage [155, 0]
- 2:boss: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
- 2:warband: confirmation incomplete; proposed hp/damage [150, 0]
- 2:umbral_snare: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
- 2:last_light: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
- 2:ember_hoarder: confirmation incomplete; proposed hp/damage [175, 2]
- 4:guardian: confirmation incomplete; proposed hp/damage [150, 0]
- 4:boss: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
- 4:warband: confirmation incomplete; proposed hp/damage [130, 0]
- 4:umbral_snare: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
- 4:last_light: confirmation incomplete; proposed hp/damage [175, 0]
- 4:ember_hoarder: stats cannot reach band at 175/+3; proposed hp/damage [175, 3]
