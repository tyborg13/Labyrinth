# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 1 (victory 1, defeat 0, Embrace 0).
Wall clock: 21.75 minutes. Seed base 12; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 10 | 12 | 5 / combat | ERROR: Condition "(uint32_t)buff.size() != len" is true. Returning: Variant() — res://scripts/progression_store.gd:559 |
| script error | 1 | 12 | 5 / combat | ERROR: Condition "len < 4" is true. Returning: ERR_INVALID_DATA — res://scripts/progression_store.gd:559 |
| script error | 1 | 12 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 1 | 12 | 5 / combat | ERROR: Error when trying to encode Variant. — res://scripts/progression_store.gd:559 |
| script error | 1 | 12 | 5 / combat | ERROR: Failed to persist committed run boundary: enemy_round_complete — res://scripts/progression_store.gd:578 |
| script error | 1 | 12 | 5 / combat | ERROR: Failed to persist committed run boundary: player_card — res://scripts/progression_store.gd:578 |
| leak | 1 | 12 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 3022) — res://tools/run_hunt.gd:259 |

### 1. script error: ERROR: Condition "(uint32_t)buff.size() != len" is true. Returning: Variant()

Source: `res://scripts/progression_store.gd:559`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2617 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2617-1793734937327642000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2597 | move | ['(2, 3)'] |
| 2598 | move | (2, 2) |
| 2599 | card | brace |
| 2600 | confirm_card | _on_confirm_card_play_pressed |
| 2601 | card | guarded_step |
| 2602 | move | ['(2, 3)'] |
| 2603 | move | (3, 3) |
| 2604 | card | pale_spark |
| 2605 | ranged | ['(5, 3)'] |
| 2606 | card | quick_stab |
| 2607 | melee | ['(3, 2)'] |
| 2608 | ui | SKIP & RECOVER  +3 HP   9655 → 9658 |
| 2609 | map_room | ['(22, -21)'] |
| 2610 | begin_combat | _on_pre_battle_start_pressed |
| 2611 | card | dull_bolt |
| 2612 | ranged | ['(1, 2)'] |
| 2613 | card | sidestep_slash |
| 2614 | move | ['(1, 3)'] |
| 2615 | move | (2, 3) |
| 2616 | move | (3, 3) |

### 2. script error: ERROR: Condition "len < 4" is true. Returning: ERR_INVALID_DATA

Source: `res://scripts/progression_store.gd:559`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2617 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2617-1793734937327664000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2597 | move | ['(2, 3)'] |
| 2598 | move | (2, 2) |
| 2599 | card | brace |
| 2600 | confirm_card | _on_confirm_card_play_pressed |
| 2601 | card | guarded_step |
| 2602 | move | ['(2, 3)'] |
| 2603 | move | (3, 3) |
| 2604 | card | pale_spark |
| 2605 | ranged | ['(5, 3)'] |
| 2606 | card | quick_stab |
| 2607 | melee | ['(3, 2)'] |
| 2608 | ui | SKIP & RECOVER  +3 HP   9655 → 9658 |
| 2609 | map_room | ['(22, -21)'] |
| 2610 | begin_combat | _on_pre_battle_start_pressed |
| 2611 | card | dull_bolt |
| 2612 | ranged | ['(1, 2)'] |
| 2613 | card | sidestep_slash |
| 2614 | move | ['(1, 3)'] |
| 2615 | move | (2, 3) |
| 2616 | move | (3, 3) |

### 3. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-1-1793734937327677000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 4. script error: ERROR: Error when trying to encode Variant.

Source: `res://scripts/progression_store.gd:559`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2617 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2617-1793734937327682000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2597 | move | ['(2, 3)'] |
| 2598 | move | (2, 2) |
| 2599 | card | brace |
| 2600 | confirm_card | _on_confirm_card_play_pressed |
| 2601 | card | guarded_step |
| 2602 | move | ['(2, 3)'] |
| 2603 | move | (3, 3) |
| 2604 | card | pale_spark |
| 2605 | ranged | ['(5, 3)'] |
| 2606 | card | quick_stab |
| 2607 | melee | ['(3, 2)'] |
| 2608 | ui | SKIP & RECOVER  +3 HP   9655 → 9658 |
| 2609 | map_room | ['(22, -21)'] |
| 2610 | begin_combat | _on_pre_battle_start_pressed |
| 2611 | card | dull_bolt |
| 2612 | ranged | ['(1, 2)'] |
| 2613 | card | sidestep_slash |
| 2614 | move | ['(1, 3)'] |
| 2615 | move | (2, 3) |
| 2616 | move | (3, 3) |

### 5. script error: ERROR: Failed to persist committed run boundary: enemy_round_complete

Source: `res://scripts/progression_store.gd:578`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2617 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2617-1793734937327694000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2597 | move | ['(2, 3)'] |
| 2598 | move | (2, 2) |
| 2599 | card | brace |
| 2600 | confirm_card | _on_confirm_card_play_pressed |
| 2601 | card | guarded_step |
| 2602 | move | ['(2, 3)'] |
| 2603 | move | (3, 3) |
| 2604 | card | pale_spark |
| 2605 | ranged | ['(5, 3)'] |
| 2606 | card | quick_stab |
| 2607 | melee | ['(3, 2)'] |
| 2608 | ui | SKIP & RECOVER  +3 HP   9655 → 9658 |
| 2609 | map_room | ['(22, -21)'] |
| 2610 | begin_combat | _on_pre_battle_start_pressed |
| 2611 | card | dull_bolt |
| 2612 | ranged | ['(1, 2)'] |
| 2613 | card | sidestep_slash |
| 2614 | move | ['(1, 3)'] |
| 2615 | move | (2, 3) |
| 2616 | move | (3, 3) |

### 6. script error: ERROR: Failed to persist committed run boundary: player_card

Source: `res://scripts/progression_store.gd:578`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2619 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2619-1793734937327704000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2599 | card | brace |
| 2600 | confirm_card | _on_confirm_card_play_pressed |
| 2601 | card | guarded_step |
| 2602 | move | ['(2, 3)'] |
| 2603 | move | (3, 3) |
| 2604 | card | pale_spark |
| 2605 | ranged | ['(5, 3)'] |
| 2606 | card | quick_stab |
| 2607 | melee | ['(3, 2)'] |
| 2608 | ui | SKIP & RECOVER  +3 HP   9655 → 9658 |
| 2609 | map_room | ['(22, -21)'] |
| 2610 | begin_combat | _on_pre_battle_start_pressed |
| 2611 | card | dull_bolt |
| 2612 | ranged | ['(1, 2)'] |
| 2613 | card | sidestep_slash |
| 2614 | move | ['(1, 3)'] |
| 2615 | move | (2, 3) |
| 2616 | move | (3, 3) |
| 2617 | card | bloody_lunge |
| 2618 | move | ['(3, 4)'] |

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 3022)

Source: `res://tools/run_hunt.gd:259`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2446 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2446-1793734937327715000 --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
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

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 1 |
| 1 | 1 |
| 2 | 1 |
| 3 | 1 |
| 4 | 1 |
| 5 | 1 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 6 |
| campfire | 6 |
| combat | 26 |
| dragon | 6 |
| event | 10 |
| graftwright | 0 — NEVER VISITED |
| guardian | 3 |
| hoarder | 0 — NEVER VISITED |
| last_light | 0 — NEVER VISITED |
| scavenger | 7 |
| snare | 1 |
| start | 6 |
| treasure | 7 |
| umbral_snare | 1 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
