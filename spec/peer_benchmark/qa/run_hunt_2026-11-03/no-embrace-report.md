# Run hunt — November 2026

Runs started: 4; processes ended: 4; completed runs: 4 (victory 4, defeat 0, Embrace 0).
Wall clock: 48.66 minutes. Seed base 1; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

Findings also include 7 separately verified replay(s); these do not inflate the campaign run totals or coverage below. Their exact private driver paths are preserved in replay commands.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 1 | 4 | 5 / boss | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| script error | 11 | 1 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 1 | 3 | 3 / combat | ERROR: Invalid polygon data, triangulation failed. — res://scripts/combat_art_treatment.gd:186 |
| script error | 1 | 4 | 5 / combat | SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'. — res://scripts/maquette_cutout_runtime/contact_actions.gd:18 |
| leak | 2 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447) — res://tools/run_hunt.gd:258 |
| leak | 1 | 1 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1533 -> 5905) — res://tools/run_hunt.gd:258 |
| leak | 1 | 1 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1533 -> 5905) — res://tools/run_hunt.gd:259 |
| leak | 1 | 2 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7985) — res://tools/run_hunt.gd:259 |
| leak | 1 | 2 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7986) — res://tools/run_hunt.gd:258 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 7482) — res://tools/run_hunt.gd:258 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 7904) — res://tools/run_hunt.gd:258 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447) — res://tools/run_hunt.gd:259 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 7339) — res://tools/run_hunt.gd:258 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 3039 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-4-3039-1793687790182458000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 3019 | move | ['(2, 1)'] |
| 3020 | move | (4, 1) |
| 3021 | card | guarded_step |
| 3022 | move | ['(2, 1)'] |
| 3023 | move | (2, 2) |
| 3024 | card | bottled_gale |
| 3025 | confirm_card | _on_confirm_card_play_pressed |
| 3026 | move | (2, 1) |
| 3027 | card | hamstring_shot |
| 3028 | move | ['(3, 2)'] |
| 3029 | card | shadow_step |
| 3030 | blink | ['(5, 2)'] |
| 3031 | move | (3, 2) |
| 3032 | move | (4, 1) |
| 3033 | card | stormstring_shot |
| 3034 | ranged | ['(2, 4)'] |
| 3035 | card | dull_bolt |
| 3036 | ranged | ['(2, 4)'] |
| 3037 | ui | COMPLETE ASCENT |
| 3038 | ui | Leave nothing |

### 2. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 1, 2, 3, 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 1 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-1-1-1793687790182481000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 3. script error: ERROR: Invalid polygon data, triangulation failed.

Source: `res://scripts/combat_art_treatment.gd:186`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 1617 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-3-1617-1793687790182487000 --no-embrace --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1597 | card | dull_bolt |
| 1598 | ranged | ['(3, 5)'] |
| 1599 | move | (3, 6) |
| 1600 | card | waning_pulse |
| 1601 | confirm_card | _on_confirm_card_play_pressed |
| 1602 | ui | RelicChoice_resonant_clapper |
| 1603 | map_room | ['(14, -12)'] |
| 1604 | ui | ItemOffer_storm_jar |
| 1605 | ui | Sell from pack |
| 1606 | ui | GEAR |
| 1607 | ui | ITEMS |
| 1608 | ui | ALL |
| 1609 | ui | Leave |
| 1610 | map_room | ['(14, -5)'] |
| 1611 | begin_combat | _on_pre_battle_start_pressed |
| 1612 | move | (5, 2) |
| 1613 | card | bloody_lunge |
| 1614 | move | ['(6, 2)'] |
| 1615 | card | sidestep_slash |
| 1616 | move | ['(6, 2)'] |

### 4. script error: SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'.

Source: `res://scripts/maquette_cutout_runtime/contact_actions.gd:18`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2757 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-4-2757-1793687790182507000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2737 | move | (6, 7) |
| 2738 | move | (6, 6) |
| 2739 | card | dull_bolt |
| 2740 | ranged | ['(3, 6)'] |
| 2741 | card | dull_bolt |
| 2742 | ranged | ['(6, 5)'] |
| 2743 | pass | _on_pass_turn_pressed |
| 2744 | card | hamstring_shot |
| 2745 | move | ['(6, 6)'] |
| 2746 | card | waning_pulse |
| 2747 | confirm_card | _on_confirm_card_play_pressed |
| 2748 | move | (6, 7) |
| 2749 | move | (6, 6) |
| 2750 | move | (6, 5) |
| 2751 | card | waning_pulse |
| 2752 | confirm_card | _on_confirm_card_play_pressed |
| 2753 | card | sidestep_slash |
| 2754 | move | ['(7, 4)'] |
| 2755 | move | (7, 2) |
| 2756 | move | (7, 3) |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447)

Source: `res://tools/run_hunt.gd:258`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2462 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-3-2462-1793687790182521000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2442 | move | (2, 3) |
| 2443 | card | lantern_shot |
| 2444 | ranged | ['(4, 3)'] |
| 2445 | card | sidestep_slash |
| 2446 | move | ['(1, 4)'] |
| 2447 | move | (2, 3) |
| 2448 | move | (1, 4) |
| 2449 | card | guarded_step |
| 2450 | move | ['(2, 4)'] |
| 2451 | card | waning_pulse |
| 2452 | confirm_card | _on_confirm_card_play_pressed |
| 2453 | move | (4, 4) |
| 2454 | card | dull_bolt |
| 2455 | ranged | ['(5, 4)'] |
| 2456 | card | hourglass_sand |
| 2457 | confirm_card | _on_confirm_card_play_pressed |
| 2458 | card | hamstring_shot |
| 2459 | move | ['(4, 3)'] |
| 2460 | move | (2, 3) |
| 2461 | ui | CONTINUE |

### 6. leak: tree_nodes grew more than 25% from section 0 to section 5 (1533 -> 5905)

Source: `res://tools/run_hunt.gd:258`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 1 --runs 1 --processes 1 --stop-after 2530 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-1-2530-1793687790182539000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2510 | card | pale_spark |
| 2511 | ranged | ['(5, 1)'] |
| 2512 | pass | _on_pass_turn_pressed |
| 2513 | card | pale_spark |
| 2514 | ranged | ['(4, 1)'] |
| 2515 | card | dull_bolt |
| 2516 | ranged | ['(4, 1)'] |
| 2517 | pass | _on_pass_turn_pressed |
| 2518 | card | hamstring_shot |
| 2519 | move | ['(3, 1)'] |
| 2520 | move | (3, 2) |
| 2521 | move | (3, 1) |
| 2522 | card | dull_bolt |
| 2523 | ranged | ['(4, 2)'] |
| 2524 | card | waning_pulse |
| 2525 | confirm_card | _on_confirm_card_play_pressed |
| 2526 | move | (4, 1) |
| 2527 | card | whirlwind_slash |
| 2528 | confirm_card | _on_confirm_card_play_pressed |
| 2529 | ui | CONTINUE |

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1533 -> 5905)

Source: `res://tools/run_hunt.gd:259`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 1 --runs 1 --processes 1 --stop-after 2530 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-1-2530-1793687790182552000 --no-embrace --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2510 | card | pale_spark |
| 2511 | ranged | ['(5, 1)'] |
| 2512 | pass | _on_pass_turn_pressed |
| 2513 | card | pale_spark |
| 2514 | ranged | ['(4, 1)'] |
| 2515 | card | dull_bolt |
| 2516 | ranged | ['(4, 1)'] |
| 2517 | pass | _on_pass_turn_pressed |
| 2518 | card | hamstring_shot |
| 2519 | move | ['(3, 1)'] |
| 2520 | move | (3, 2) |
| 2521 | move | (3, 1) |
| 2522 | card | dull_bolt |
| 2523 | ranged | ['(4, 2)'] |
| 2524 | card | waning_pulse |
| 2525 | confirm_card | _on_confirm_card_play_pressed |
| 2526 | move | (4, 1) |
| 2527 | card | whirlwind_slash |
| 2528 | confirm_card | _on_confirm_card_play_pressed |
| 2529 | ui | CONTINUE |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7985)

Source: `res://tools/run_hunt.gd:259`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 2584 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-2-2584-1793687790182566000 --no-embrace --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2564 | move | ['(1, 2)'] |
| 2565 | card | guarded_step |
| 2566 | move | ['(1, 4)'] |
| 2567 | move | (1, 2) |
| 2568 | card | shadow_step |
| 2569 | blink | ['(2, 4)'] |
| 2570 | card | sidestep_slash |
| 2571 | move | ['(2, 4)'] |
| 2572 | card | razor_gale |
| 2573 | ranged | ['(3, 2)'] |
| 2574 | move | (2, 3) |
| 2575 | card | hamstring_shot |
| 2576 | move | ['(2, 4)'] |
| 2577 | move | (2, 3) |
| 2578 | card | pale_spark |
| 2579 | ranged | ['(3, 2)'] |
| 2580 | card | dull_bolt |
| 2581 | ranged | ['(2, 1)'] |
| 2582 | move | (3, 4) |
| 2583 | ui | CONTINUE |

### 9. leak: tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7986)

Source: `res://tools/run_hunt.gd:258`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 2584 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-2-2584-1793687790182578000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2564 | move | ['(1, 2)'] |
| 2565 | card | guarded_step |
| 2566 | move | ['(1, 4)'] |
| 2567 | move | (1, 2) |
| 2568 | card | shadow_step |
| 2569 | blink | ['(2, 4)'] |
| 2570 | card | sidestep_slash |
| 2571 | move | ['(2, 4)'] |
| 2572 | card | razor_gale |
| 2573 | ranged | ['(3, 2)'] |
| 2574 | move | (2, 3) |
| 2575 | card | hamstring_shot |
| 2576 | move | ['(2, 4)'] |
| 2577 | move | (2, 3) |
| 2578 | card | pale_spark |
| 2579 | ranged | ['(3, 2)'] |
| 2580 | card | dull_bolt |
| 2581 | ranged | ['(2, 1)'] |
| 2582 | move | (3, 4) |
| 2583 | ui | CONTINUE |

### 10. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 7482)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2388 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-4-2388-1793687790182590000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2368 | move | (3, 6) |
| 2369 | card | lantern_shot |
| 2370 | ranged | ['(3, 4)'] |
| 2371 | card | dull_bolt |
| 2372 | ranged | ['(3, 3)'] |
| 2373 | card | dull_bolt |
| 2374 | ranged | ['(2, 4)'] |
| 2375 | move | (3, 5) |
| 2376 | card | whirlwind_slash |
| 2377 | confirm_card | _on_confirm_card_play_pressed |
| 2378 | move | (3, 6) |
| 2379 | move | (3, 7) |
| 2380 | card | hamstring_shot |
| 2381 | move | ['(3, 5)'] |
| 2382 | card | bloody_lunge |
| 2383 | move | ['(3, 3)'] |
| 2384 | move | (7, 2) |
| 2385 | card | dull_bolt |
| 2386 | ranged | ['(3, 2)'] |
| 2387 | ui | CONTINUE |

### 11. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 7904)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2365 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-4-2365-1793687790182600000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2345 | card | pale_spark |
| 2346 | ranged | ['(5, 2)'] |
| 2347 | card | brace |
| 2348 | confirm_card | _on_confirm_card_play_pressed |
| 2349 | pass | _on_pass_turn_pressed |
| 2350 | card | meteorfall |
| 2351 | meteor_marks | ['(6, 2)'] |
| 2352 | move | (4, 2) |
| 2353 | move | (3, 2) |
| 2354 | card | lantern_shot |
| 2355 | ranged | ['(7, 3)'] |
| 2356 | move | (3, 5) |
| 2357 | move | (3, 4) |
| 2358 | card | whirlwind_slash |
| 2359 | confirm_card | _on_confirm_card_play_pressed |
| 2360 | card | shadow_step |
| 2361 | blink | ['(5, 3)'] |
| 2362 | card | pale_spark |
| 2363 | ranged | ['(7, 4)'] |
| 2364 | ui | CONTINUE |

### 12. leak: tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 5447)

Source: `res://tools/run_hunt.gd:259`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2464 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-3-2464-1793687790182611000 --no-embrace --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2444 | move | (2, 3) |
| 2445 | card | lantern_shot |
| 2446 | ranged | ['(4, 3)'] |
| 2447 | card | sidestep_slash |
| 2448 | move | ['(1, 4)'] |
| 2449 | move | (2, 3) |
| 2450 | move | (1, 4) |
| 2451 | card | guarded_step |
| 2452 | move | ['(2, 4)'] |
| 2453 | card | waning_pulse |
| 2454 | confirm_card | _on_confirm_card_play_pressed |
| 2455 | move | (4, 4) |
| 2456 | card | dull_bolt |
| 2457 | ranged | ['(5, 4)'] |
| 2458 | card | hourglass_sand |
| 2459 | confirm_card | _on_confirm_card_play_pressed |
| 2460 | card | hamstring_shot |
| 2461 | move | ['(4, 3)'] |
| 2462 | move | (2, 3) |
| 2463 | ui | CONTINUE |

### 13. leak: tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 7339)

Source: `res://tools/run_hunt.gd:258`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2539 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-3-2539-1793687790182623000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2519 | card | sidestep_slash |
| 2520 | move | ['(1, 3)'] |
| 2521 | card | hamstring_shot |
| 2522 | move | ['(2, 3)'] |
| 2523 | move | (3, 3) |
| 2524 | move | (3, 4) |
| 2525 | pass | _on_pass_turn_pressed |
| 2526 | card | bloody_lunge |
| 2527 | move | ['(3, 3)'] |
| 2528 | card | pale_spark |
| 2529 | ranged | ['(4, 3)'] |
| 2530 | move | (3, 1) |
| 2531 | pass | _on_pass_turn_pressed |
| 2532 | card | lantern_shot |
| 2533 | ranged | ['(4, 2)'] |
| 2534 | card | dull_bolt |
| 2535 | ranged | ['(4, 1)'] |
| 2536 | move | (2, 2) |
| 2537 | pass | _on_pass_turn_pressed |
| 2538 | ui | CONTINUE |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 4 |
| 1 | 4 |
| 2 | 4 |
| 3 | 4 |
| 4 | 4 |
| 5 | 4 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 24 |
| campfire | 24 |
| combat | 90 |
| dragon | 24 |
| ember_hoarder | 6 |
| event | 45 |
| graftwright | 6 |
| guardian | 10 |
| hoarder | 6 |
| last_light | 3 |
| scavenger | 21 |
| snare | 5 |
| start | 24 |
| treasure | 28 |
| umbral_snare | 5 |
| warband | 2 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
