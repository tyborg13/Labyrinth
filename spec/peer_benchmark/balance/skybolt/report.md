# Skybolt paired measurement

Revision 7; policy v2 `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`; source HEAD `d1e17bdafa1115d01e2a3336a8a1bd03a04bc092`. 150 fights per arm per cohort/tier, first seed 1. Each arm adds exactly one card to the unchanged tier preset; `none` retains the preset. No gameplay, authored data, or policy changes.

Samples follow the existing revision-7 bot: ascending seeds, then production section order, taking the first 150 natural matching rooms per cohort/tier (bosses pooled across six dragons). Arms use identical ordered seed/section/room/entrance identities. A seed supplies multiple fights; 150 fights does not mean 150 distinct seeds. All outcomes enter turns and HP percentiles. HP lost is cumulative actual `damage_received`, including fatigue, rather than net HP loss. Turns count hero activations; turn-cap losses retain the existing policy limit.

Tables give median (nearest-rank P10–P90). Deltas are arm minus `none`: mean paired win difference in percentage points and mean paired cumulative HP difference. Negative HP means less damage received. Brackets are 95% percentile bootstrap CIs, resampling whole paired map-seed clusters (10,000 resamples; RNG seed 3102026). These describe this bounded policy and sample, not optimal human play. Raw records, deck lists, literal overrides, hashes and recomputable summaries are in `data/` and `summary.json`.

V1 sets `shock_all_hits: false`; V2 sets `burn: true`; V3 sets range 5 and removes `ignore_los`; V4 sets Time 9; V5 combines V1 and V2. Production carries printed `shock: 1` onto conducted hits even when `shock_all_hits` is false. The offline engine therefore adapts that override to suppress Shock on every enemy except the aimed primary target, preserving conducted damage and all other rules. A ground/conductor aim has no primary enemy to Shock. This adapter applies only to V1/V5; production is unchanged.

## Tier 2 — standard

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 41.3% | 5 (3–9) | 24 (8–26) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 41.3% | 5 (3–9) | 24 (6–26) | +0.00 [-6.67, +6.00] | -0.29 [-1.18, +0.61] |
| wildfire_halo | 150 | 42.0% | 5 (3–8) | 24 (7–26) | +0.67 [-6.00, +8.00] | +0.45 [-0.29, +1.19] |
| stormstring_shot | 150 | 38.7% | 5 (3–9) | 24 (6–26) | -2.67 [-10.00, +5.33] | -0.05 [-1.01, +0.87] |
| V1 | 150 | 41.3% | 5 (3–9) | 24 (6–26) | +0.00 [-6.67, +6.00] | -0.29 [-1.18, +0.61] |
| V2 | 150 | 41.3% | 5 (3–9) | 24 (6–26) | +0.00 [-6.67, +6.00] | -0.29 [-1.18, +0.61] |
| V3 | 150 | 42.7% | 5 (3–9) | 24 (6–26) | +1.33 [-5.33, +8.00] | -0.43 [-1.21, +0.39] |
| V4 | 150 | 38.0% | 5 (3–8) | 24 (6–26) | -3.33 [-10.67, +3.33] | -0.25 [-1.27, +0.75] |
| V5 | 150 | 41.3% | 5 (3–9) | 24 (6–26) | +0.00 [-6.67, +6.00] | -0.29 [-1.18, +0.61] |

## Tier 2 — warband

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 69.3% | 8.5 (4–18) | 12 (0–25) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 68.0% | 8 (4–26) | 11 (0–24) | -1.33 [-9.80, +7.50] | -0.83 [-2.41, +0.80] |
| wildfire_halo | 150 | 72.7% | 8 (4–20) | 12 (0–24) | +3.33 [-5.84, +12.59] | -0.65 [-2.37, +1.02] |
| stormstring_shot | 150 | 70.7% | 8 (4–15) | 12.5 (0–25) | +1.33 [-7.69, +10.39] | -0.13 [-1.62, +1.33] |
| V1 | 150 | 68.0% | 8 (4–26) | 11 (0–24) | -1.33 [-9.80, +7.50] | -0.83 [-2.41, +0.80] |
| V2 | 150 | 68.0% | 8 (4–26) | 11 (0–25) | -1.33 [-9.80, +7.50] | -0.80 [-2.42, +0.85] |
| V3 | 150 | 68.7% | 8 (4–22) | 11 (0–25) | -0.67 [-9.20, +7.95] | -0.87 [-2.50, +0.82] |
| V4 | 150 | 68.7% | 8 (4–22) | 12 (0–25) | -0.67 [-8.84, +7.97] | -0.18 [-1.79, +1.41] |
| V5 | 150 | 68.0% | 8 (4–26) | 11 (0–25) | -1.33 [-9.80, +7.50] | -0.80 [-2.42, +0.85] |

## Tier 2 — guardian

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 49.3% | 5 (3–8) | 24 (3–26) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 49.3% | 4 (3–7) | 24 (2–26) | +0.00 [-5.81, +6.25] | -0.28 [-1.27, +0.77] |
| wildfire_halo | 150 | 49.3% | 5 (2–8) | 24 (2–26) | +0.00 [-5.41, +5.63] | +0.15 [-0.74, +1.10] |
| stormstring_shot | 150 | 48.7% | 5 (3–8) | 24 (2–26) | -0.67 [-6.25, +5.19] | +0.04 [-0.85, +0.99] |
| V1 | 150 | 49.3% | 4 (3–7) | 24 (2–26) | +0.00 [-5.81, +6.25] | -0.28 [-1.27, +0.77] |
| V2 | 150 | 49.3% | 4 (3–7) | 24 (2–26) | +0.00 [-5.81, +6.25] | -0.27 [-1.26, +0.78] |
| V3 | 150 | 49.3% | 4 (3–7) | 24 (2–26) | +0.00 [-5.81, +6.25] | -0.28 [-1.27, +0.78] |
| V4 | 150 | 51.3% | 5 (3–8) | 24 (2–26) | +2.00 [-3.14, +7.64] | -0.17 [-1.05, +0.73] |
| V5 | 150 | 49.3% | 4 (3–7) | 24 (2–26) | +0.00 [-5.81, +6.25] | -0.27 [-1.26, +0.78] |

## Tier 3 — standard

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 32.7% | 6 (3–12) | 24 (11–26) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 29.3% | 5 (3–11) | 24 (9–26) | -3.33 [-11.33, +4.67] | -0.03 [-1.03, +0.95] |
| wildfire_halo | 150 | 31.3% | 5 (3–11) | 24 (10–26) | -1.33 [-8.67, +5.33] | -0.23 [-0.97, +0.53] |
| stormstring_shot | 150 | 25.3% | 5 (3–11) | 24 (9–26) | -7.33 [-14.67, +0.00] | +0.31 [-0.59, +1.23] |
| V1 | 150 | 29.3% | 5 (3–11) | 24 (9–26) | -3.33 [-11.33, +4.67] | -0.03 [-1.03, +0.95] |
| V2 | 150 | 30.0% | 5 (3–11) | 24 (8–26) | -2.67 [-10.67, +4.67] | -0.07 [-1.05, +0.89] |
| V3 | 150 | 28.0% | 5 (3–11) | 24 (9–26) | -4.67 [-13.33, +3.33] | +0.07 [-0.89, +1.05] |
| V4 | 150 | 26.0% | 5 (3–11) | 24 (11–26) | -6.67 [-15.33, +1.33] | +0.45 [-0.37, +1.31] |
| V5 | 150 | 30.0% | 5 (3–11) | 24 (8–26) | -2.67 [-10.67, +4.67] | -0.07 [-1.05, +0.89] |

## Tier 3 — warband

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 46.0% | 9 (3–21) | 24 (7–26) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 40.0% | 7.5 (3–22) | 24 (6–26) | -6.00 [-14.01, +2.63] | +0.77 [-0.32, +1.88] |
| wildfire_halo | 150 | 44.7% | 8 (3–17) | 24 (6–26) | -1.33 [-8.28, +6.02] | +0.02 [-0.96, +1.03] |
| stormstring_shot | 150 | 44.7% | 7 (3–16) | 24 (6–26) | -1.33 [-8.67, +6.16] | -0.06 [-1.00, +0.92] |
| V1 | 150 | 40.0% | 7.5 (3–22) | 24 (6–26) | -6.00 [-14.01, +2.63] | +0.77 [-0.32, +1.88] |
| V2 | 150 | 38.7% | 7.5 (3–21) | 24 (6–26) | -7.33 [-15.92, +1.43] | +0.72 [-0.41, +1.87] |
| V3 | 150 | 40.0% | 8 (3–20) | 24 (6–26) | -6.00 [-13.87, +2.10] | +0.81 [-0.31, +1.96] |
| V4 | 150 | 35.3% | 7 (3–22) | 24 (5–26) | -10.67 [-17.57, -3.33] | +0.45 [-0.63, +1.51] |
| V5 | 150 | 38.7% | 7.5 (3–21) | 24 (6–26) | -7.33 [-15.92, +1.43] | +0.72 [-0.41, +1.87] |

## Tier 3 — guardian

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 50.0% | 5 (3–8) | 23.5 (3–24) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 52.7% | 5 (2–8) | 22.5 (3–24) | +2.67 [-2.78, +8.11] | -0.76 [-1.81, +0.22] |
| wildfire_halo | 150 | 49.3% | 5 (2–8) | 24 (2–24) | -0.67 [-5.73, +4.41] | -0.97 [-1.90, -0.08] |
| stormstring_shot | 150 | 50.0% | 5 (3–8) | 24 (4–24) | +0.00 [-5.48, +5.66] | -0.07 [-1.10, +0.89] |
| V1 | 150 | 52.7% | 5 (2–8) | 22.5 (3–24) | +2.67 [-2.78, +8.11] | -0.76 [-1.81, +0.22] |
| V2 | 150 | 52.7% | 5 (2–8) | 22.5 (3–24) | +2.67 [-2.78, +8.11] | -0.76 [-1.81, +0.22] |
| V3 | 150 | 52.7% | 5 (2–8) | 22.5 (3–24) | +2.67 [-2.78, +8.11] | -0.78 [-1.85, +0.21] |
| V4 | 150 | 52.0% | 5 (3–8) | 22 (3–24) | +2.00 [-3.42, +7.24] | -0.93 [-1.99, +0.06] |
| V5 | 150 | 52.7% | 5 (2–8) | 22.5 (3–24) | +2.67 [-2.78, +8.11] | -0.76 [-1.81, +0.22] |

## Tier 3 — boss

| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |
|---|---:|---:|---:|---:|---:|---:|
| none | 150 | 34.7% | 6 (3–8) | 24 (11–24) | +0.00 [+0.00, +0.00] | +0.00 [+0.00, +0.00] |
| skybolt | 150 | 34.0% | 6 (3–8) | 24 (5–26) | -0.67 [-8.00, +7.33] | -1.00 [-1.99, +0.01] |
| wildfire_halo | 150 | 31.3% | 5.5 (3–8) | 24 (10–24) | -3.33 [-9.33, +2.67] | -0.33 [-1.06, +0.39] |
| stormstring_shot | 150 | 31.3% | 6 (3–8) | 24 (10–24) | -3.33 [-10.67, +3.33] | -0.26 [-1.12, +0.59] |
| V1 | 150 | 34.0% | 6 (3–8) | 24 (5–26) | -0.67 [-8.00, +7.33] | -1.00 [-1.99, +0.01] |
| V2 | 150 | 34.0% | 6 (3–8) | 24 (5–26) | -0.67 [-8.00, +7.33] | -1.00 [-1.99, +0.01] |
| V3 | 150 | 34.0% | 6 (3–8) | 24 (5–26) | -0.67 [-8.00, +7.33] | -1.00 [-1.99, +0.01] |
| V4 | 150 | 32.7% | 6 (3–8) | 24 (5–26) | -2.00 [-9.33, +6.00] | -0.85 [-1.79, +0.10] |
| V5 | 150 | 34.0% | 6 (3–8) | 24 (5–26) | -0.67 [-8.00, +7.33] | -1.00 [-1.99, +0.01] |

## Skybolt usage

Counts include committed states only; speculative policy branches and intent previews are excluded. Hits include primary and conducted enemies, including blocked or lethal hits, with each footprint counted once. Cancelled attacks count damaging instructions in the intent at the start of an activation restricted by Shock attributed to Skybolt; dead, Frozen or Petrified activations and special actions exempt from Shock are excluded. This counts prohibited attack instructions, not counterfactual hits or HP saved. Kills use the production kill-counter delta during the card action, excluding objective-cleared followers. Range/LOS use the nearest footprint tile/any footprint tile from the casting origin; LOS means physical line of sight, distinct from Umbra visibility. Conduction can carry a hit beyond the primary targeting limits, including for V3. Cast shares count a cast once if any hit qualifies. All ratios use total casts, including fights with zero casts.

| Tier / cohort | Arm | Casts / fight (total) | Enemies / cast | Cancelled attacks / cast | Kills (per fight) | Hits >5 / no LOS | Casts with >5 / no LOS |
|---|---|---:|---:|---:|---:|---:|---:|
| 2 / standard | skybolt | 0.65 (98) | 1.00 | 0.31 | 26 (0.17) | 5 / 15 | 5.1% / 15.3% |
| 2 / standard | V1 | 0.65 (98) | 1.00 | 0.31 | 26 (0.17) | 5 / 15 | 5.1% / 15.3% |
| 2 / standard | V2 | 0.65 (97) | 1.00 | 0.31 | 25 (0.17) | 5 / 15 | 5.2% / 15.5% |
| 2 / standard | V3 | 0.65 (98) | 1.00 | 0.35 | 24 (0.16) | 0 / 0 | 0.0% / 0.0% |
| 2 / standard | V4 | 0.65 (97) | 1.00 | 0.31 | 25 (0.17) | 5 / 15 | 5.2% / 15.5% |
| 2 / standard | V5 | 0.65 (97) | 1.00 | 0.31 | 25 (0.17) | 5 / 15 | 5.2% / 15.5% |
| 2 / warband | skybolt | 0.89 (133) | 1.00 | 0.06 | 77 (0.51) | 14 / 25 | 10.5% / 18.8% |
| 2 / warband | V1 | 0.89 (133) | 1.00 | 0.06 | 77 (0.51) | 14 / 25 | 10.5% / 18.8% |
| 2 / warband | V2 | 0.87 (130) | 1.00 | 0.06 | 75 (0.50) | 14 / 25 | 10.8% / 19.2% |
| 2 / warband | V3 | 0.89 (133) | 1.00 | 0.08 | 77 (0.51) | 1 / 0 | 0.8% / 0.0% |
| 2 / warband | V4 | 0.89 (134) | 1.00 | 0.06 | 76 (0.51) | 14 / 27 | 10.4% / 20.1% |
| 2 / warband | V5 | 0.87 (130) | 1.00 | 0.06 | 75 (0.50) | 14 / 25 | 10.8% / 19.2% |
| 2 / guardian | skybolt | 0.71 (107) | 1.02 | 0.43 | 26 (0.17) | 6 / 1 | 5.6% / 0.9% |
| 2 / guardian | V1 | 0.71 (107) | 1.02 | 0.43 | 26 (0.17) | 6 / 1 | 5.6% / 0.9% |
| 2 / guardian | V2 | 0.71 (107) | 1.02 | 0.43 | 26 (0.17) | 6 / 1 | 5.6% / 0.9% |
| 2 / guardian | V3 | 0.71 (107) | 1.02 | 0.42 | 28 (0.19) | 0 / 0 | 0.0% / 0.0% |
| 2 / guardian | V4 | 0.71 (107) | 1.02 | 0.43 | 26 (0.17) | 6 / 1 | 5.6% / 0.9% |
| 2 / guardian | V5 | 0.71 (107) | 1.02 | 0.43 | 26 (0.17) | 6 / 1 | 5.6% / 0.9% |
| 3 / standard | skybolt | 0.63 (95) | 0.99 | 0.33 | 24 (0.16) | 4 / 20 | 4.2% / 21.1% |
| 3 / standard | V1 | 0.63 (95) | 0.99 | 0.33 | 24 (0.16) | 4 / 20 | 4.2% / 21.1% |
| 3 / standard | V2 | 0.63 (94) | 0.99 | 0.33 | 23 (0.15) | 4 / 20 | 4.3% / 21.3% |
| 3 / standard | V3 | 0.63 (95) | 0.99 | 0.37 | 22 (0.15) | 0 / 0 | 0.0% / 0.0% |
| 3 / standard | V4 | 0.64 (96) | 0.99 | 0.32 | 25 (0.17) | 4 / 21 | 4.2% / 21.9% |
| 3 / standard | V5 | 0.63 (94) | 0.99 | 0.33 | 23 (0.15) | 4 / 20 | 4.3% / 21.3% |
| 3 / warband | skybolt | 0.75 (113) | 1.01 | 0.14 | 54 (0.36) | 12 / 27 | 10.6% / 23.9% |
| 3 / warband | V1 | 0.75 (113) | 1.01 | 0.14 | 54 (0.36) | 12 / 27 | 10.6% / 23.9% |
| 3 / warband | V2 | 0.73 (109) | 1.01 | 0.15 | 53 (0.35) | 12 / 25 | 11.0% / 22.9% |
| 3 / warband | V3 | 0.75 (113) | 1.01 | 0.13 | 53 (0.35) | 0 / 0 | 0.0% / 0.0% |
| 3 / warband | V4 | 0.78 (117) | 1.01 | 0.14 | 54 (0.36) | 13 / 27 | 11.1% / 23.1% |
| 3 / warband | V5 | 0.73 (109) | 1.01 | 0.15 | 53 (0.35) | 12 / 25 | 11.0% / 22.9% |
| 3 / guardian | skybolt | 0.65 (97) | 1.02 | 0.44 | 14 (0.09) | 4 / 6 | 4.1% / 6.2% |
| 3 / guardian | V1 | 0.65 (97) | 1.02 | 0.44 | 14 (0.09) | 4 / 6 | 4.1% / 6.2% |
| 3 / guardian | V2 | 0.64 (96) | 1.01 | 0.45 | 13 (0.09) | 4 / 6 | 4.2% / 6.2% |
| 3 / guardian | V3 | 0.65 (97) | 1.02 | 0.44 | 15 (0.10) | 0 / 0 | 0.0% / 0.0% |
| 3 / guardian | V4 | 0.64 (96) | 1.01 | 0.45 | 13 (0.09) | 4 / 6 | 4.2% / 6.2% |
| 3 / guardian | V5 | 0.64 (96) | 1.01 | 0.45 | 13 (0.09) | 4 / 6 | 4.2% / 6.2% |
| 3 / boss | skybolt | 0.63 (94) | 1.00 | 1.33 | 1 (0.01) | 1 / 0 | 1.1% / 0.0% |
| 3 / boss | V1 | 0.63 (94) | 1.00 | 1.33 | 1 (0.01) | 1 / 0 | 1.1% / 0.0% |
| 3 / boss | V2 | 0.63 (94) | 1.00 | 1.33 | 1 (0.01) | 1 / 0 | 1.1% / 0.0% |
| 3 / boss | V3 | 0.63 (94) | 1.00 | 1.33 | 1 (0.01) | 0 / 0 | 0.0% / 0.0% |
| 3 / boss | V4 | 0.63 (94) | 1.00 | 1.33 | 1 (0.01) | 1 / 0 | 1.1% / 0.0% |
| 3 / boss | V5 | 0.63 (94) | 1.00 | 1.33 | 1 (0.01) | 1 / 0 | 1.1% / 0.0% |

## Comparisons

Across the seven equally sized cohorts, `none` won 46.2%, Skybolt 45.0%, Wildfire Halo 45.8%, and Stormstring Shot 44.2%. V1–V5 won 45.0%, 44.9%, 45.0%, 43.4%, 44.9%, respectively. Cohort-specific paired differences and uncertainty are shown above.
