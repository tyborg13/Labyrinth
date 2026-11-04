# Run hunt — November 2026

Runs started: 6; processes ended: 6; completed runs: 6 (victory 6, defeat 0, Embrace 0).
Wall clock: 68.31 minutes. Seed base 2; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 6 | 2 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| leak | 1 | 2 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 2997) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 2666) — res://tools/run_hunt.gd:258 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 3095) — res://tools/run_hunt.gd:258 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 2848) — res://tools/run_hunt.gd:258 |
| leak | 1 | 6 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1552 -> 2165) — res://tools/run_hunt.gd:258 |
| leak | 1 | 7 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2433) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 2, 3, 4, 5, 6, 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-2-1-1793733598950085000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. leak: tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 2997)

Source: `res://tools/run_hunt.gd:258`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 2194 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-2-2194-1793733598950097000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2174 | card | hamstring_shot |
| 2175 | move | ['(4, 3)'] |
| 2176 | move | (3, 4) |
| 2177 | card | lantern_shot |
| 2178 | ranged | ['(5, 4)'] |
| 2179 | card | brace |
| 2180 | confirm_card | _on_confirm_card_play_pressed |
| 2181 | card | quick_stab |
| 2182 | melee | ['(4, 5)'] |
| 2183 | card | hamstring_shot |
| 2184 | move | ['(2, 3)'] |
| 2185 | move | (2, 4) |
| 2186 | move | (3, 4) |
| 2187 | card | lantern_shot |
| 2188 | ranged | ['(4, 5)'] |
| 2189 | move | (2, 4) |
| 2190 | card | cinder_fusillade |
| 2191 | ranged | ['(5, 4)'] |
| 2192 | move | (3, 4) |
| 2193 | ui | CONTINUE |

### 3. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 2666)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2319 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-5-2319-1793733598950114000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2299 | confirm_card | _on_confirm_card_play_pressed |
| 2300 | move | (4, 4) |
| 2301 | move | (3, 4) |
| 2302 | move | (5, 4) |
| 2303 | card | quick_stab |
| 2304 | melee | ['(7, 5)'] |
| 2305 | card | lantern_shot |
| 2306 | ranged | ['(7, 5)'] |
| 2307 | move | (4, 4) |
| 2308 | move | (5, 5) |
| 2309 | card | brace |
| 2310 | confirm_card | _on_confirm_card_play_pressed |
| 2311 | card | whirlwind_slash |
| 2312 | confirm_card | _on_confirm_card_play_pressed |
| 2313 | move | (3, 3) |
| 2314 | card | bloody_lunge |
| 2315 | move | ['(4, 4)'] |
| 2316 | card | thorn_skewer |
| 2317 | melee | ['(4, 5)'] |
| 2318 | ui | CONTINUE |

### 4. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 3095)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2147 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-4-2147-1793733598950127000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2127 | card | patch_up |
| 2128 | confirm_card | _on_confirm_card_play_pressed |
| 2129 | pass | _on_pass_turn_pressed |
| 2130 | card | sidestep_slash |
| 2131 | move | ['(2, 1)'] |
| 2132 | move | (4, 1) |
| 2133 | card | whirlwind_slash |
| 2134 | confirm_card | _on_confirm_card_play_pressed |
| 2135 | move | (3, 5) |
| 2136 | card | waning_pulse |
| 2137 | confirm_card | _on_confirm_card_play_pressed |
| 2138 | card | lantern_shot |
| 2139 | ranged | ['(5, 5)'] |
| 2140 | move | (4, 5) |
| 2141 | card | hamstring_shot |
| 2142 | move | ['(5, 3)'] |
| 2143 | move | (5, 4) |
| 2144 | card | pale_spark |
| 2145 | ranged | ['(3, 4)'] |
| 2146 | ui | CONTINUE |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 2848)

Source: `res://tools/run_hunt.gd:258`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2369 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-3-2369-1793733598950140000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2349 | move | ['(3, 4)'] |
| 2350 | pass | _on_pass_turn_pressed |
| 2351 | card | shadow_step |
| 2352 | blink | ['(4, 2)'] |
| 2353 | card | pale_spark |
| 2354 | ranged | ['(5, 3)'] |
| 2355 | card | whirlwind_slash |
| 2356 | confirm_card | _on_confirm_card_play_pressed |
| 2357 | pass | _on_pass_turn_pressed |
| 2358 | pass | _on_pass_turn_pressed |
| 2359 | card | dull_bolt |
| 2360 | ranged | ['(5, 3)'] |
| 2361 | card | bloody_lunge |
| 2362 | move | ['(4, 2)'] |
| 2363 | card | quick_stab |
| 2364 | melee | ['(4, 4)'] |
| 2365 | move | (2, 2) |
| 2366 | card | updraft |
| 2367 | push | ['(4, 2)'] |
| 2368 | ui | CONTINUE |

### 6. leak: tree_nodes grew more than 25% from section 0 to section 5 (1552 -> 2165)

Source: `res://tools/run_hunt.gd:258`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 2292 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-6-2292-1793733598950152000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2272 | card | whirlwind_slash |
| 2273 | confirm_card | _on_confirm_card_play_pressed |
| 2274 | card | quick_stab |
| 2275 | melee | ['(4, 4)'] |
| 2276 | move | (3, 3) |
| 2277 | card | hamstring_shot |
| 2278 | move | ['(2, 2)'] |
| 2279 | pass | _on_pass_turn_pressed |
| 2280 | card | lantern_shot |
| 2281 | ranged | ['(5, 4)'] |
| 2282 | move | (3, 3) |
| 2283 | card | dull_bolt |
| 2284 | ranged | ['(4, 4)'] |
| 2285 | card | patch_up |
| 2286 | confirm_card | _on_confirm_card_play_pressed |
| 2287 | card | guarded_step |
| 2288 | move | ['(3, 4)'] |
| 2289 | card | quick_stab |
| 2290 | melee | ['(5, 4)'] |
| 2291 | ui | CONTINUE |

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2433)

Source: `res://tools/run_hunt.gd:258`. Seeds: 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 7 --runs 1 --processes 1 --stop-after 3133 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-7-3133-1793733598950164000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 3113 | confirm_card | _on_confirm_card_play_pressed |
| 3114 | card | brace |
| 3115 | confirm_card | _on_confirm_card_play_pressed |
| 3116 | move | (4, 6) |
| 3117 | move | (3, 6) |
| 3118 | card | bloody_lunge |
| 3119 | move | ['(4, 6)'] |
| 3120 | card | guarded_step |
| 3121 | move | ['(3, 6)'] |
| 3122 | move | (3, 5) |
| 3123 | card | hamstring_shot |
| 3124 | move | ['(2, 4)'] |
| 3125 | pass | _on_pass_turn_pressed |
| 3126 | card | sidestep_slash |
| 3127 | move | ['(3, 4)'] |
| 3128 | card | waning_pulse |
| 3129 | confirm_card | _on_confirm_card_play_pressed |
| 3130 | card | quick_stab |
| 3131 | melee | ['(4, 3)'] |
| 3132 | ui | CONTINUE |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 6 |
| 1 | 6 |
| 2 | 6 |
| 3 | 6 |
| 4 | 6 |
| 5 | 6 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 36 |
| campfire | 36 |
| combat | 149 |
| dragon | 36 |
| ember_hoarder | 6 |
| event | 62 |
| graftwright | 5 |
| guardian | 15 |
| hoarder | 6 |
| last_light | 3 |
| scavenger | 36 |
| snare | 3 |
| start | 36 |
| treasure | 40 |
| umbral_snare | 3 |
| warband | 5 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
