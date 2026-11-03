# bos-03 feedback 1 — director tuning ladders

Cumulative rungs in the director's supplied order. Each measured rung has the same 90 revision-7 rooms as round 0, 30 per natural tier. Policy v2, defaults and decks are unchanged. Tier processes are merged back into round-0 sample order. The first inclusive 35–65% win rate stops a ladder; otherwise its last rung is retained.

Turns and cumulative HP lost include losses and capped runs; values are median (nearest-rank P10–P90). Beat, damage, helper-kill and summon columns are totals over 90 fights, using the same branch-local committed-event counters as round 0.

## last_lamplighter

| Rung | Cumulative addition | Wins | Turns (P10–P90) | HP lost (P10–P90) | Beats | Beat → hero | Beat → enemies | Helper kills | Summons | Band |
|---:|---|---:|---|---|---:|---:|---:|---:|---:|---|
| 0 | Accepted round 0 | 0.0% | 4 (2–4) | 24 (24–26) | 312 | 0 | 2 | 76 | 165 | OUTSIDE |
| 1 | Last Procession melee 8 → 6 | 0.0% | 4 (2–5) | 24 (24–26) | 320 | 0 | 2 | 77 | 171 | OUTSIDE |
| 2 | Lamplighter HP 44 → 36 | 10.0% | 4 (2–5) | 24 (23–26) | 311 | 0 | 2 | 77 | 169 | OUTSIDE |
| 3 | Snuff cap 2 → 1 | 15.6% | 4 (3–6) | 24 (21–26) | 377 | 0 | 2 | 84 | 94 | OUTSIDE |
| 4 | Mourning Hook damage 4 → 3 | 16.7% | 4 (3–6) | 24 (21–26) | 377 | 0 | 2 | 85 | 94 | OUTSIDE |
| 5 | Guardian Wick Shade Grasp / Hooking Grasp melee 2 → 1 | 24.4% | 4 (4–6) | 24 (20–26) | 395 | 0 | 0 | 87 | 96 | OUTSIDE |

Retained rung **5**. No rung reached the band; retained the last rung for the director.

## storm_cantor

| Rung | Cumulative addition | Wins | Turns (P10–P90) | HP lost (P10–P90) | Beats | Beat → hero | Beat → enemies | Helper kills | Summons | Band |
|---:|---|---:|---|---|---:|---:|---:|---:|---:|---|
| 0 | Accepted round 0 | 98.9% | 6.5 (5–8) | 10 (3–17) | 143 | 332 | 868 | 148 | 40 | OUTSIDE |
| 1 | Cantor HP 38 → 46 | 98.9% | 7 (6–9) | 11 (3–19) | 175 | 385 | 997 | 173 | 53 | OUTSIDE |
| 2 | Broken Rhythm melee 5 → 7 | 96.7% | 7 (6–9) | 11 (3–21) | 176 | 385 | 1004 | 173 | 52 | OUTSIDE |
| 3 | Call the Spark cap 1 → 2 | 93.3% | 7 (5–9) | 11 (3–22) | 171 | 364 | 1023 | 179 | 87 | OUTSIDE |
| 4 | Lightning Storm damage 3 → 4 | 97.8% | 7 (6–9) | 12 (4–20) | 172 | 426 | 1238 | 193 | 92 | OUTSIDE |

Retained rung **4**. No rung reached the band; retained the last rung for the director.

## rimejaw

| Rung | Cumulative addition | Wins | Turns (P10–P90) | HP lost (P10–P90) | Beats | Beat → hero | Beat → enemies | Helper kills | Summons | Band |
|---:|---|---:|---|---|---:|---:|---:|---:|---:|---|
| 0 | Accepted round 0 | 27.8% | 4 (2–6) | 24 (16–24) | 326 | 0 | 0 | 89 | 0 | OUTSIDE |
| 1 | Harrowing Pounce melee 7 → 6 | 31.1% | 4 (2–6) | 24 (15–24) | 337 | 0 | 0 | 95 | 0 | OUTSIDE |
| 2 | Rimejaw HP 38 → 34 | 43.3% | 4 (2–5) | 24 (12–24) | 306 | 0 | 0 | 91 | 0 | within |

Retained rung **2**. First rung inside the band.

## Heuristic scope

The card heuristic scores intrinsic player cards against a blank draw; it exposes no enemy-intent scoring API. No synthetic card-equivalent scores were assigned to enemy intents. Its Guardian context/specification is updated with the selected enemy values; intrinsic card coefficients are unchanged.
