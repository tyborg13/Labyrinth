# zek-01 measurement

Section 1 (depth 4), ladder-entry loadouts 1–8 from the archived `run_curve_dragons.py` constructor payloads. Each loadout is used with eight combat seeds (stride 1,000,003), for N=64 per cell. All dragons use that same entry-loadout/seed schedule. The room generator builds each dragon's own production arena/roster at depth 4; this changes the selected dragon, not its entry build. No later-section results are implied.

Baseline is the current branch rules with Zekarion's pre-unit data restored in process (HP50, band7, original order). Pattern50 and the HP sweep use scatter9 and the five-slot order. Other dragons' baseline rows are reused in the other scenarios: their definitions and factories are unchanged. Values are relative results from the unchanged ladder bot, not player difficulty estimates. No tuning was performed.

95% intervals are Wilson binomial intervals across combat seeds, conditional on these eight entry loadouts; they do not quantify uncertainty across all player builds. Medians include wins and losses. Health lost is cumulative actual damage received, including healing/recovery between hits. Skybreak strikes are mean registered hits per fight, including hits fully absorbed by Block or Stoneskin; empty strikes are excluded. Overload bolt and Lightning Storm columns report mean actual hero Health lost separately; the combined total is also in the JSON summary.

| Scenario | Dragon | N | Wins (95% interval) | Median turns | Median Health lost | Skybreak hits/fight | Overload bolt HP/fight | Lightning Storm HP/fight |
|---|---|---:|---|---:|---:|---:|---:|---:|
| baseline | vyraketh | 64 | 71.9% (59.9–81.4) | 5 | 20.5 | 0.00 | 0.00 | 0.00 |
| baseline | tharokh | 64 | 90.6% (81.0–95.6) | 12 | 11 | 0.00 | 0.00 | 0.00 |
| baseline | vaeloryx | 64 | 82.8% (71.8–90.1) | 6 | 13.5 | 0.00 | 0.00 | 0.00 |
| baseline | iskaldra | 64 | 78.1% (66.6–86.5) | 7 | 14 | 0.00 | 0.00 | 0.00 |
| baseline | zekarion | 64 | 56.2% (44.1–67.7) | 5 | 23 | 0.33 | 2.16 | 0.80 |
| baseline | noctyrax | 64 | 92.2% (83.0–96.6) | 9 | 10 | 0.00 | 0.00 | 0.00 |
| pattern50 | vyraketh | 64 | 71.9% (59.9–81.4) | 5 | 20.5 | 0.00 | 0.00 | 0.00 |
| pattern50 | tharokh | 64 | 90.6% (81.0–95.6) | 12 | 11 | 0.00 | 0.00 | 0.00 |
| pattern50 | vaeloryx | 64 | 82.8% (71.8–90.1) | 6 | 13.5 | 0.00 | 0.00 | 0.00 |
| pattern50 | iskaldra | 64 | 78.1% (66.6–86.5) | 7 | 14 | 0.00 | 0.00 | 0.00 |
| pattern50 | zekarion | 64 | 48.4% (36.6–60.4) | 5 | 24 | 0.19 | 0.77 | 0.41 |
| pattern50 | noctyrax | 64 | 92.2% (83.0–96.6) | 9 | 10 | 0.00 | 0.00 | 0.00 |
| hp56 | vyraketh | 64 | 71.9% (59.9–81.4) | 5 | 20.5 | 0.00 | 0.00 | 0.00 |
| hp56 | tharokh | 64 | 90.6% (81.0–95.6) | 12 | 11 | 0.00 | 0.00 | 0.00 |
| hp56 | vaeloryx | 64 | 82.8% (71.8–90.1) | 6 | 13.5 | 0.00 | 0.00 | 0.00 |
| hp56 | iskaldra | 64 | 78.1% (66.6–86.5) | 7 | 14 | 0.00 | 0.00 | 0.00 |
| hp56 | zekarion | 64 | 39.1% (28.1–51.3) | 6 | 24 | 0.23 | 0.92 | 0.41 |
| hp56 | noctyrax | 64 | 92.2% (83.0–96.6) | 9 | 10 | 0.00 | 0.00 | 0.00 |
| hp62 | vyraketh | 64 | 71.9% (59.9–81.4) | 5 | 20.5 | 0.00 | 0.00 | 0.00 |
| hp62 | tharokh | 64 | 90.6% (81.0–95.6) | 12 | 11 | 0.00 | 0.00 | 0.00 |
| hp62 | vaeloryx | 64 | 82.8% (71.8–90.1) | 6 | 13.5 | 0.00 | 0.00 | 0.00 |
| hp62 | iskaldra | 64 | 78.1% (66.6–86.5) | 7 | 14 | 0.00 | 0.00 | 0.00 |
| hp62 | zekarion | 64 | 34.4% (23.9–46.6) | 6 | 24 | 0.23 | 1.00 | 0.41 |
| hp62 | noctyrax | 64 | 92.2% (83.0–96.6) | 9 | 10 | 0.00 | 0.00 | 0.00 |
| hp68 | vyraketh | 64 | 71.9% (59.9–81.4) | 5 | 20.5 | 0.00 | 0.00 | 0.00 |
| hp68 | tharokh | 64 | 90.6% (81.0–95.6) | 12 | 11 | 0.00 | 0.00 | 0.00 |
| hp68 | vaeloryx | 64 | 82.8% (71.8–90.1) | 6 | 13.5 | 0.00 | 0.00 | 0.00 |
| hp68 | iskaldra | 64 | 78.1% (66.6–86.5) | 7 | 14 | 0.00 | 0.00 | 0.00 |
| hp68 | zekarion | 64 | 32.8% (22.6–45.0) | 6 | 24 | 0.25 | 1.05 | 0.52 |
| hp68 | noctyrax | 64 | 92.2% (83.0–96.6) | 9 | 10 | 0.00 | 0.00 | 0.00 |
| hp74 | vyraketh | 64 | 71.9% (59.9–81.4) | 5 | 20.5 | 0.00 | 0.00 | 0.00 |
| hp74 | tharokh | 64 | 90.6% (81.0–95.6) | 12 | 11 | 0.00 | 0.00 | 0.00 |
| hp74 | vaeloryx | 64 | 82.8% (71.8–90.1) | 6 | 13.5 | 0.00 | 0.00 | 0.00 |
| hp74 | iskaldra | 64 | 78.1% (66.6–86.5) | 7 | 14 | 0.00 | 0.00 | 0.00 |
| hp74 | zekarion | 64 | 31.2% (21.2–43.4) | 6 | 24 | 0.23 | 1.14 | 0.59 |
| hp74 | noctyrax | 64 | 92.2% (83.0–96.6) | 9 | 10 | 0.00 | 0.00 | 0.00 |

Observed caps: 0 turn-capped fights; 0 decision-capped fights. N=64 guarantees a Wilson half-width below 12 percentage points even at a 50% win rate. The eight entry-loadout clusters remain a practical limitation.
