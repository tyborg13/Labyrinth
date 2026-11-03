# Run hunt — November 2026

Runs started: 12; processes ended: 12; completed runs: 11 (victory 0, defeat 0, Embrace 11).
Wall clock: 50.90 minutes. Seed base 1; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

Findings also include 5 separately verified replay(s); these do not inflate the campaign run totals or coverage below. Their exact private driver paths are preserved in replay commands.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 2 | 5 | 5 / campfire | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| script error | 17 | 1 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 2 | 5 | 5 / combat | SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'. — res://scripts/maquette_cutout_runtime/contact_actions.gd:18 |
| warning | 1 | 12 | 2 / umbral_snare | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 12 | 2 / umbral_snare | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:259 |
| leak | 2 | 2 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 6765) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 5380) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 5380) — res://tools/run_hunt.gd:259 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2710 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-5-2710-1793687789906842000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2690 | cancel_card | _on_board_cancel_requested |
| 2691 | card | prism_sight |
| 2692 | confirm_card | _on_confirm_card_play_pressed |
| 2693 | move | (4, 3) |
| 2694 | card | lantern_shot |
| 2695 | ranged | ['(4, 5)'] |
| 2696 | move | (3, 3) |
| 2697 | card | frostbolt |
| 2698 | ranged | ['(1, 3)'] |
| 2699 | move | (2, 3) |
| 2700 | card | dull_bolt |
| 2701 | ranged | ['(2, 1)'] |
| 2702 | card | glassbone_guard |
| 2703 | confirm_card | _on_confirm_card_play_pressed |
| 2704 | move | (2, 2) |
| 2705 | card | thorn_skewer |
| 2706 | melee | ['(2, 1)'] |
| 2707 | ui | SKIP & RECOVER  +3 HP   9286 → 9289 |
| 2708 | map_room | ['(23, -5)'] |
| 2709 | ui | @PanelContainer@360505 |

### 2. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 1 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-1-1-1793687789906869000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 3. script error: SCRIPT ERROR: Invalid access to property or key 'actor_key' on a base object of type 'Dictionary'.

Source: `res://scripts/maquette_cutout_runtime/contact_actions.gd:18`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2476 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-5-2476-1793687789906874000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2456 | ui | RelicChoice_leaden_pommel |
| 2457 | map_room | ['(22, -7)'] |
| 2458 | map_room | ['(22, -7)'] |
| 2459 | map_room | ['(22, -8)'] |
| 2460 | equipment | _on_pre_battle_equip_pressed |
| 2461 | ui | CloseCharacterOverlay |
| 2462 | begin_combat | _on_pre_battle_start_pressed |
| 2463 | pass | _on_pass_turn_pressed |
| 2464 | move | (3, 7) |
| 2465 | move | (4, 7) |
| 2466 | card | brace |
| 2467 | confirm_card | _on_confirm_card_play_pressed |
| 2468 | card | lantern_shot |
| 2469 | ranged | ['(4, 5)'] |
| 2470 | card | thorn_skewer |
| 2471 | melee | ['(3, 7)'] |
| 2472 | card | sidestep_slash |
| 2473 | move | ['(3, 6)'] |
| 2474 | move | (4, 5) |
| 2475 | move | (4, 6) |

### 4. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 1218 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-12-1218-1793687789906889000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1198 | move | ['(7, 2)'] |
| 1199 | move | (6, 2) |
| 1200 | move | (6, 1) |
| 1201 | pass | _on_pass_turn_pressed |
| 1202 | move | (4, 1) |
| 1203 | pass | _on_pass_turn_pressed |
| 1204 | card | brace |
| 1205 | confirm_card | _on_confirm_card_play_pressed |
| 1206 | move | (3, 1) |
| 1207 | move | (2, 1) |
| 1208 | pass | _on_pass_turn_pressed |
| 1209 | card | hamstring_shot |
| 1210 | move | ['(3, 1)'] |
| 1211 | pass | _on_pass_turn_pressed |
| 1212 | card | lantern_shot |
| 1213 | confirm_card | _on_confirm_card_play_pressed |
| 1214 | move | (4, 1) |
| 1215 | move | (3, 1) |
| 1216 | pass | _on_pass_turn_pressed |
| 1217 | card | bloody_lunge |

### 5. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:259`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 1218 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-12-1218-1793687789906901000 --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1198 | move | ['(7, 2)'] |
| 1199 | move | (6, 2) |
| 1200 | move | (6, 1) |
| 1201 | pass | _on_pass_turn_pressed |
| 1202 | move | (4, 1) |
| 1203 | pass | _on_pass_turn_pressed |
| 1204 | card | brace |
| 1205 | confirm_card | _on_confirm_card_play_pressed |
| 1206 | move | (3, 1) |
| 1207 | move | (2, 1) |
| 1208 | pass | _on_pass_turn_pressed |
| 1209 | card | hamstring_shot |
| 1210 | move | ['(3, 1)'] |
| 1211 | pass | _on_pass_turn_pressed |
| 1212 | card | lantern_shot |
| 1213 | confirm_card | _on_confirm_card_play_pressed |
| 1214 | move | (4, 1) |
| 1215 | move | (3, 1) |
| 1216 | pass | _on_pass_turn_pressed |
| 1217 | card | bloody_lunge |

### 6. leak: tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 6765)

Source: `res://tools/run_hunt.gd:258`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 2822 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-2-2822-1793687789906914000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2802 | blink | ['(6, 2)'] |
| 2803 | move | (6, 1) |
| 2804 | move | (6, 2) |
| 2805 | card | sidestep_slash |
| 2806 | move | ['(5, 2)'] |
| 2807 | card | hamstring_shot |
| 2808 | move | ['(6, 2)'] |
| 2809 | move | (5, 3) |
| 2810 | card | dull_bolt |
| 2811 | ranged | ['(7, 3)'] |
| 2812 | card | whirlwind_slash |
| 2813 | confirm_card | _on_confirm_card_play_pressed |
| 2814 | move | (4, 3) |
| 2815 | move | (5, 3) |
| 2816 | card | waning_pulse |
| 2817 | confirm_card | _on_confirm_card_play_pressed |
| 2818 | card | quick_stab |
| 2819 | melee | ['(7, 4)'] |
| 2820 | move | (5, 1) |
| 2821 | ui | CONTINUE |

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 5380)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2290 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-5-2290-1793687789906928000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2270 | confirm_card | _on_confirm_card_play_pressed |
| 2271 | card | sidestep_slash |
| 2272 | move | ['(3, 2)'] |
| 2273 | card | bloody_lunge |
| 2274 | move | ['(3, 5)'] |
| 2275 | card | waning_pulse |
| 2276 | confirm_card | _on_confirm_card_play_pressed |
| 2277 | move | (2, 6) |
| 2278 | pass | _on_pass_turn_pressed |
| 2279 | card | dull_bolt |
| 2280 | ranged | ['(6, 4)'] |
| 2281 | card | lantern_shot |
| 2282 | ranged | ['(6, 4)'] |
| 2283 | move | (5, 4) |
| 2284 | card | hamstring_shot |
| 2285 | move | ['(5, 5)'] |
| 2286 | card | thorn_skewer |
| 2287 | melee | ['(7, 5)'] |
| 2288 | move | (5, 7) |
| 2289 | ui | CONTINUE |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 5380)

Source: `res://tools/run_hunt.gd:259`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-23 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-23/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2290 --output-dir /private/tmp/labyrinth_codex/qa-23/replay-5-2290-1793687789906942000 --script /private/tmp/labyrinth_codex/qa-23/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2270 | confirm_card | _on_confirm_card_play_pressed |
| 2271 | card | sidestep_slash |
| 2272 | move | ['(3, 2)'] |
| 2273 | card | bloody_lunge |
| 2274 | move | ['(3, 5)'] |
| 2275 | card | waning_pulse |
| 2276 | confirm_card | _on_confirm_card_play_pressed |
| 2277 | move | (2, 6) |
| 2278 | pass | _on_pass_turn_pressed |
| 2279 | card | dull_bolt |
| 2280 | ranged | ['(6, 4)'] |
| 2281 | card | lantern_shot |
| 2282 | ranged | ['(6, 4)'] |
| 2283 | move | (5, 4) |
| 2284 | card | hamstring_shot |
| 2285 | move | ['(5, 5)'] |
| 2286 | card | thorn_skewer |
| 2287 | melee | ['(7, 5)'] |
| 2288 | move | (5, 7) |
| 2289 | ui | CONTINUE |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 12 |
| 1 | 7 |
| 2 | 4 |
| 3 | 2 |
| 4 | 2 |
| 5 | 2 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 17 |
| campfire | 28 |
| combat | 99 |
| dragon | 17 |
| ember_hoarder | 4 |
| event | 60 |
| graftwright | 3 |
| guardian | 9 |
| hoarder | 4 |
| last_light | 7 |
| scavenger | 29 |
| snare | 4 |
| start | 29 |
| treasure | 32 |
| umbral_snare | 4 |
| warband | 2 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
