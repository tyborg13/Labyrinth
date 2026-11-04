# Run hunt — November 2026

Runs started: 6; processes ended: 6; completed runs: 5 (victory 5, defeat 0, Embrace 0).
Wall clock: 67.01 minutes. Seed base 2; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 6 | 2 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 2 | 2 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 5 | 5 / boss | WARNING: ObjectDB instances leaked at exit (run with --verbose for details). — core/object/object.cpp:2641 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2268) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 3183) — res://tools/run_hunt.gd:258 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2855) — res://tools/run_hunt.gd:258 |
| leak | 1 | 6 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1559 -> 2172) — res://tools/run_hunt.gd:258 |
| leak | 1 | 7 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2440) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 2, 3, 4, 5, 6, 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-2-1-1793753050605167000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1322 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-2-1322-1793753050605180000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1302 | move | ['(6, 6)'] |
| 1303 | move | (7, 5) |
| 1304 | card | waning_pulse |
| 1305 | confirm_card | _on_confirm_card_play_pressed |
| 1306 | card | sidestep_slash |
| 1307 | move | ['(6, 5)'] |
| 1308 | move | (5, 6) |
| 1309 | move | (4, 6) |
| 1310 | move | (4, 7) |
| 1311 | card | dull_bolt |
| 1312 | ranged | ['(7, 7)'] |
| 1313 | card | dull_bolt |
| 1314 | ranged | ['(7, 7)'] |
| 1315 | move | (5, 7) |
| 1316 | card | pale_spark |
| 1317 | ranged | ['(5, 4)'] |
| 1318 | move | (6, 7) |
| 1319 | card | bloody_lunge |
| 1320 | move | ['(6, 5)'] |
| 1321 | card | pale_spark |

### 3. warning: WARNING: ObjectDB instances leaked at exit (run with --verbose for details).

Source: `core/object/object.cpp:2641`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2746 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-5-2746-1793753050605196000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2726 | melee | ['(4, 4)'] |
| 2727 | card | waning_pulse |
| 2728 | confirm_card | _on_confirm_card_play_pressed |
| 2729 | move | (2, 3) |
| 2730 | card | hamstring_shot |
| 2731 | move | ['(4, 3)'] |
| 2732 | card | quick_stab |
| 2733 | melee | ['(6, 4)'] |
| 2734 | card | lantern_shot |
| 2735 | ranged | ['(6, 4)'] |
| 2736 | card | sidestep_slash |
| 2737 | move | ['(3, 4)'] |
| 2738 | move | (4, 3) |
| 2739 | card | waning_pulse |
| 2740 | confirm_card | _on_confirm_card_play_pressed |
| 2741 | card | whirlwind_slash |
| 2742 | confirm_card | _on_confirm_card_play_pressed |
| 2743 | card | waning_pulse |
| 2744 | confirm_card | _on_confirm_card_play_pressed |
| 2745 | ui | COMPLETE ASCENT |

### 4. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2268)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2895 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-4-2895-1793753050605210000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2875 | move | (6, 2) |
| 2876 | move | (5, 2) |
| 2877 | card | dull_bolt |
| 2878 | ranged | ['(6, 3)'] |
| 2879 | card | waning_pulse |
| 2880 | confirm_card | _on_confirm_card_play_pressed |
| 2881 | move | (5, 5) |
| 2882 | card | whirlwind_slash |
| 2883 | confirm_card | _on_confirm_card_play_pressed |
| 2884 | card | quick_stab |
| 2885 | melee | ['(6, 6)'] |
| 2886 | pass | _on_pass_turn_pressed |
| 2887 | card | lantern_shot |
| 2888 | ranged | ['(3, 7)'] |
| 2889 | card | sidestep_slash |
| 2890 | move | ['(2, 6)'] |
| 2891 | move | (1, 5) |
| 2892 | card | dull_bolt |
| 2893 | ranged | ['(4, 3)'] |
| 2894 | ui | CONTINUE |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 3183)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2208 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-5-2208-1793753050605223000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2188 | pass | _on_pass_turn_pressed |
| 2189 | move | (5, 5) |
| 2190 | card | bloody_lunge |
| 2191 | move | ['(5, 6)'] |
| 2192 | move | (5, 5) |
| 2193 | card | waning_pulse |
| 2194 | confirm_card | _on_confirm_card_play_pressed |
| 2195 | card | sidestep_slash |
| 2196 | move | ['(2, 5)'] |
| 2197 | card | hamstring_shot |
| 2198 | move | ['(3, 5)'] |
| 2199 | move | (3, 4) |
| 2200 | move | (3, 5) |
| 2201 | move | (4, 3) |
| 2202 | card | lantern_shot |
| 2203 | ranged | ['(5, 2)'] |
| 2204 | move | (5, 3) |
| 2205 | card | thorn_skewer |
| 2206 | melee | ['(5, 2)'] |
| 2207 | ui | CONTINUE |

### 6. leak: tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2855)

Source: `res://tools/run_hunt.gd:258`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2369 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-3-2369-1793753050605235000 --no-embrace
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

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1559 -> 2172)

Source: `res://tools/run_hunt.gd:258`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 2292 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-6-2292-1793753050605247000 --no-embrace
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

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2440)

Source: `res://tools/run_hunt.gd:258`. Seeds: 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 7 --runs 1 --processes 1 --stop-after 3133 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-7-3133-1793753050605259000 --no-embrace
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
| 3 | 5 |
| 4 | 5 |
| 5 | 5 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 32 |
| campfire | 32 |
| combat | 135 |
| dragon | 32 |
| ember_hoarder | 5 |
| event | 60 |
| graftwright | 5 |
| guardian | 11 |
| hoarder | 5 |
| last_light | 3 |
| scavenger | 30 |
| snare | 4 |
| start | 33 |
| treasure | 38 |
| umbral_snare | 4 |
| warband | 5 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
