# Run hunt — November 2026

Runs started: 7; processes ended: 7; completed runs: 6 (victory 0, defeat 0, Embrace 6).
Wall clock: 13.79 minutes. Seed base 17; at most 2 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 7 | 17 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 18 | 0 / umbral_snare | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 17, 18, 19, 20, 21, 22, 23.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 17 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-17-1-1793923928161211000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 18.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 18 --runs 1 --processes 1 --stop-after 465 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-18-465-1793923928161227000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 445 | pass | _on_pass_turn_pressed |
| 446 | pass | _on_pass_turn_pressed |
| 447 | pass | _on_pass_turn_pressed |
| 448 | pass | _on_pass_turn_pressed |
| 449 | pass | _on_pass_turn_pressed |
| 450 | pass | _on_pass_turn_pressed |
| 451 | pass | _on_pass_turn_pressed |
| 452 | pass | _on_pass_turn_pressed |
| 453 | pass | _on_pass_turn_pressed |
| 454 | pass | _on_pass_turn_pressed |
| 455 | pass | _on_pass_turn_pressed |
| 456 | pass | _on_pass_turn_pressed |
| 457 | pass | _on_pass_turn_pressed |
| 458 | pass | _on_pass_turn_pressed |
| 459 | pass | _on_pass_turn_pressed |
| 460 | pass | _on_pass_turn_pressed |
| 461 | pass | _on_pass_turn_pressed |
| 462 | pass | _on_pass_turn_pressed |
| 463 | pass | _on_pass_turn_pressed |
| 464 | pass | _on_pass_turn_pressed |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 7 |
| 1 | 0 |
| 2 | 0 |
| 3 | 0 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 0 — NEVER VISITED |
| campfire | 6 |
| combat | 22 |
| dragon | 0 — NEVER VISITED |
| ember_hoarder | 1 |
| event | 9 |
| graftwright | 1 |
| guardian | 2 |
| hoarder | 1 |
| last_light | 2 |
| scavenger | 3 |
| snare | 3 |
| start | 7 |
| treasure | 6 |
| umbral_snare | 3 |
| warband | 2 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
