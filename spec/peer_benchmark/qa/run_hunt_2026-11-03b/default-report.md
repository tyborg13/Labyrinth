# Run hunt — November 2026

Runs started: 18; processes ended: 16; completed runs: 13 (victory 1, defeat 0, Embrace 12).
Wall clock: 47.28 minutes. Seed base 2; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 16 | 2 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 3 | 13 | 3 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| leak | 1 | 12 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 3022) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 2, 3, 4, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-2-1-1793729500053971000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 13, 18, 19.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 13 --runs 1 --processes 1 --stop-after 2117 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-13-2117-1793729500053986000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2097 | confirm_card | _on_confirm_card_play_pressed |
| 2098 | move | (3, 5) |
| 2099 | card | hamstring_shot |
| 2100 | move | ['(4, 5)'] |
| 2101 | card | sidestep_slash |
| 2102 | move | ['(3, 6)'] |
| 2103 | move | (5, 6) |
| 2104 | card | pale_spark |
| 2105 | ranged | ['(5, 5)'] |
| 2106 | card | waning_pulse |
| 2107 | confirm_card | _on_confirm_card_play_pressed |
| 2108 | move | (5, 5) |
| 2109 | move | (5, 6) |
| 2110 | move | (5, 5) |
| 2111 | move | (4, 5) |
| 2112 | card | pale_spark |
| 2113 | ranged | ['(5, 4)'] |
| 2114 | card | brace |
| 2115 | confirm_card | _on_confirm_card_play_pressed |
| 2116 | move | (2, 5) |

### 3. leak: tree_nodes grew more than 25% from section 0 to section 5 (1548 -> 3022)

Source: `res://tools/run_hunt.gd:258`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2446 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-12-2446-1793729500054003000
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
| 0 | 16 |
| 1 | 3 |
| 2 | 2 |
| 3 | 2 |
| 4 | 1 |
| 5 | 1 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 10 |
| campfire | 22 |
| combat | 85 |
| dragon | 10 |
| ember_hoarder | 4 |
| event | 45 |
| graftwright | 4 |
| guardian | 7 |
| hoarder | 4 |
| last_light | 4 |
| scavenger | 22 |
| snare | 7 |
| start | 25 |
| treasure | 26 |
| umbral_snare | 7 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.

## Capacity interruption

The model-capacity interruption stopped two in-flight seeds without terminal or exit-status evidence. Completed seeds were retained and never rerun. The campaign continued with unused seeds after the pause, for the remaining launch budget inferred from the last trace write. Interrupted seeds and the exact segment commands are retained in capacity-recovery.json and campaign-default-continuation-execution.json. Their partial room coverage is reported separately; they are not classified as product crashes.
