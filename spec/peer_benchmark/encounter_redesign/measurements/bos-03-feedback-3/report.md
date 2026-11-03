# bos-03 feedback 3 — updated three-variant table

Parent `dd68771d9822d58fbbf9f3362c67912c7008ba9f` plus the uncommitted bos-03 implementation. Revision 7; frozen policy v2 `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`. Each variant uses the first 30 natural rooms per Guardian per tier, starting at seed 1 (90 per Guardian, 1,620 total). Sample keys are asserted identical across variants. Starting HP 24, tier decks, search limits and all other meas-02 defaults are unchanged.

Before restores the captured integration definitions and automatic replacements. Pace only changes Cantor 11, Roc 9 and the Bell Tender/Fledgling Guardian overrides to 12. After uses production bos-03. The before adapter preserves sum-01’s automatic-replacement exclusion. After uses the director-selected cumulative rungs: storm_cantor rung 12, rimejaw rung 2, last_lamplighter rung 6. Before/pace-only and the five unaffected after datasets are retained from accepted round 2; selected after samples come from the measured ladders.

Turns and cumulative HP lost include losses and capped runs. Values are median (nearest-rank P10–P90). Beat/helper/summon columns are totals over all runs. Helper kills count actual actor_death events, excluding departed/outcome-cleared helpers; summons count arrivals, excluding initial helpers. Beat damage is actual HP lost by team from battlefield_rule_fired events, including collisions and ground contact. Branch-local event cursors exclude speculative policy transitions.

| Guardian | Variant | N | Wins | Turns (P10–P90) | HP lost (P10–P90) | Beats | Beat → hero | Beat → enemies | Helper kills | Summons | 35–65% band |
|---|---|---:|---:|---|---|---:|---:|---:|---:|---:|---|
| ashen_reaver | before | 90 | 25.6% | 4 (2–5) | 24 (16–26) | 0 | 0 | 0 | 235 | 162 | OUTSIDE |
| ashen_reaver | pace_only | 90 | 25.6% | 4 (2–5) | 24 (16–26) | 0 | 0 | 0 | 235 | 162 | OUTSIDE |
| ashen_reaver | after | 90 | 37.8% | 4 (2–5) | 24 (12–26) | 164 | 0 | 0 | 154 | 0 | within |
| rimejaw | before | 90 | 23.3% | 4 (2–6) | 24 (16–24) | 0 | 0 | 0 | 111 | 68 | OUTSIDE |
| rimejaw | pace_only | 90 | 23.3% | 4 (2–6) | 24 (16–24) | 0 | 0 | 0 | 111 | 68 | OUTSIDE |
| rimejaw | after | 90 | 43.3% | 4 (2–5) | 24 (12–24) | 306 | 0 | 0 | 91 | 0 | within |
| storm_cantor | before | 90 | 98.9% | 6 (5–8) | 6 (0–15) | 0 | 0 | 0 | 121 | 75 | OUTSIDE |
| storm_cantor | pace_only | 90 | 83.3% | 6 (5–9) | 14 (3–24) | 0 | 0 | 0 | 171 | 136 | OUTSIDE |
| storm_cantor | after | 90 | 68.9% | 10 (6–12) | 20 (8–24) | 232 | 569 | 1455 | 257 | 162 | OUTSIDE |
| gallows_roc | before | 90 | 97.8% | 5 (4–8) | 6 (2–17) | 0 | 0 | 0 | 163 | 94 | OUTSIDE |
| gallows_roc | pace_only | 90 | 27.8% | 4 (3–6) | 24 (12–26) | 0 | 0 | 0 | 165 | 116 | OUTSIDE |
| gallows_roc | after | 90 | 41.1% | 4 (3–6) | 24 (12–26) | 348 | 178 | 140 | 112 | 0 | within |
| craghide | before | 90 | 47.8% | 6 (4–8) | 24 (8–26) | 0 | 0 | 0 | 170 | 124 | within |
| craghide | pace_only | 90 | 47.8% | 6 (4–8) | 24 (8–26) | 0 | 0 | 0 | 170 | 124 | within |
| craghide | after | 90 | 64.4% | 6 (4–8) | 16 (6–26) | 225 | 0 | 6 | 130 | 0 | within |
| last_lamplighter | before | 90 | 0.0% | 4 (2–4) | 24 (24–26) | 0 | 0 | 0 | 85 | 169 | OUTSIDE |
| last_lamplighter | pace_only | 90 | 0.0% | 4 (2–4) | 24 (24–26) | 0 | 0 | 0 | 85 | 169 | OUTSIDE |
| last_lamplighter | after | 90 | 44.4% | 4 (3–6) | 24 (13–24) | 356 | 0 | 0 | 85 | 79 | within |

Raw gzipped records retain each natural tier, seed, entrance and coordinate. `summary.json` also includes per-run metric distributions and tier counts.

Reproduce: `python3 tools/guardian_tuning.py --round 3`; rebuild: `python3 tools/guardian_tuning.py --round 3 --report-only`.


Cantor after includes the Lay the Choir tile-budget repair; historical before/pace-only rows retain their original connector behavior.


Ordered rung results: [ladders.md](ladders.md).
