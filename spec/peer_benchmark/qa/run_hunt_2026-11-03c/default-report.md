# Run hunt — November 2026

Runs started: 11; processes ended: 11; completed runs: 11 (victory 3, defeat 0, Embrace 8).
Wall clock: 55.24 minutes. Seed base 2; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 11 | 2 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 2 | 3 | 0 / campfire | WARNING: ObjectDB instances leaked at exit (run with --verbose for details). — core/object/object.cpp:2641 |
| leak | 1 | 9 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1551 -> 2251) — res://tools/run_hunt.gd:258 |
| leak | 1 | 12 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 3029) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 3096) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-2-1-1793749029910227000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: WARNING: ObjectDB instances leaked at exit (run with --verbose for details).

Source: `core/object/object.cpp:2641`. Seeds: 3, 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 470 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-3-470-1793749029910235000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 450 | confirm_card | _on_confirm_card_play_pressed |
| 451 | card | waning_pulse |
| 452 | confirm_card | _on_confirm_card_play_pressed |
| 453 | move | (5, 4) |
| 454 | card | pale_spark |
| 455 | ranged | ['(4, 4)'] |
| 456 | ui | SKIP & RECOVER  +3 HP   9583 → 9586 |
| 457 | map_room | ['(-3, 0)'] |
| 458 | side_map |  |
| 459 | ui | @PanelContainer@46488 |
| 460 | ui | MagicDeckRow_dull_bolt |
| 461 | ui | Back |
| 462 | ui | X |
| 463 | ui | @PanelContainer@46668 |
| 464 | ui | MagicDeckRow_dull_bolt |
| 465 | ui | Back |
| 466 | ui | MagicDeckRow_pale_spark |
| 467 | ui | Back |
| 468 | ui | X |
| 469 | ui | @PanelContainer@46785 |

### 3. leak: tree_nodes grew more than 25% from section 0 to section 5 (1551 -> 2251)

Source: `res://tools/run_hunt.gd:258`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 2744 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-9-2744-1793749029910251000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2724 | card | hamstring_shot |
| 2725 | move | ['(7, 3)'] |
| 2726 | card | grave_dust_satchel |
| 2727 | aoe | ['(6, 3)'] |
| 2728 | pass | _on_pass_turn_pressed |
| 2729 | move | (4, 3) |
| 2730 | card | bloody_lunge |
| 2731 | move | ['(4, 4)'] |
| 2732 | card | shadow_step |
| 2733 | blink | ['(2, 3)'] |
| 2734 | card | waning_pulse |
| 2735 | confirm_card | _on_confirm_card_play_pressed |
| 2736 | move | (6, 1) |
| 2737 | card | guarded_step |
| 2738 | move | ['(6, 2)'] |
| 2739 | card | sidestep_slash |
| 2740 | move | ['(7, 2)'] |
| 2741 | card | pale_spark |
| 2742 | ranged | ['(7, 3)'] |
| 2743 | ui | CONTINUE |

### 4. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 3029)

Source: `res://tools/run_hunt.gd:258`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2446 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-12-2446-1793749029910263000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2426 | surface | ['(4, 2)'] |
| 2427 | card | lantern_shot |
| 2428 | ranged | ['(1, 2)'] |
| 2429 | card | dull_bolt |
| 2430 | ranged | ['(3, 2)'] |
| 2431 | move | (2, 2) |
| 2432 | move | (2, 1) |
| 2433 | card | pale_spark |
| 2434 | ranged | ['(3, 2)'] |
| 2435 | card | sidestep_slash |
| 2436 | move | ['(3, 2)'] |
| 2437 | move | (4, 1) |
| 2438 | card | quick_stab |
| 2439 | melee | ['(6, 2)'] |
| 2440 | move | (5, 4) |
| 2441 | card | patch_up |
| 2442 | confirm_card | _on_confirm_card_play_pressed |
| 2443 | card | hamstring_shot |
| 2444 | move | ['(5, 5)'] |
| 2445 | ui | CONTINUE |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 3096)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-30 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-30/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2327 --output-dir /private/tmp/labyrinth_codex/qa-30/replay-5-2327-1793749029910273000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2307 | move | (3, 4) |
| 2308 | card | bloody_lunge |
| 2309 | move | ['(2, 4)'] |
| 2310 | move | (3, 4) |
| 2311 | card | whirlwind_slash |
| 2312 | confirm_card | _on_confirm_card_play_pressed |
| 2313 | card | brace |
| 2314 | confirm_card | _on_confirm_card_play_pressed |
| 2315 | move | (4, 2) |
| 2316 | card | lantern_shot |
| 2317 | ranged | ['(6, 3)'] |
| 2318 | card | rooted_stance |
| 2319 | confirm_card | _on_confirm_card_play_pressed |
| 2320 | card | thorn_skewer |
| 2321 | melee | ['(7, 3)'] |
| 2322 | card | bloody_lunge |
| 2323 | move | ['(4, 3)'] |
| 2324 | move | (4, 2) |
| 2325 | move | (5, 2) |
| 2326 | ui | CONTINUE |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 11 |
| 1 | 5 |
| 2 | 4 |
| 3 | 4 |
| 4 | 3 |
| 5 | 3 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 22 |
| campfire | 30 |
| combat | 111 |
| dragon | 22 |
| ember_hoarder | 5 |
| event | 56 |
| graftwright | 6 |
| guardian | 10 |
| hoarder | 5 |
| last_light | 4 |
| scavenger | 31 |
| snare | 4 |
| start | 30 |
| treasure | 34 |
| umbral_snare | 4 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
