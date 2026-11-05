# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 16.75 minutes. Seed base 9; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 9 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 9 | 1 / umbral_snare | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task_verbose.py --seed 9 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-9-1-1793863414090026000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task_verbose.py --seed 9 --runs 1 --processes 1 --stop-after 1134 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-9-1134-1793863414090038000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1114 | pass | _on_pass_turn_pressed |
| 1115 | pass | _on_pass_turn_pressed |
| 1116 | pass | _on_pass_turn_pressed |
| 1117 | pass | _on_pass_turn_pressed |
| 1118 | pass | _on_pass_turn_pressed |
| 1119 | pass | _on_pass_turn_pressed |
| 1120 | pass | _on_pass_turn_pressed |
| 1121 | pass | _on_pass_turn_pressed |
| 1122 | pass | _on_pass_turn_pressed |
| 1123 | pass | _on_pass_turn_pressed |
| 1124 | pass | _on_pass_turn_pressed |
| 1125 | pass | _on_pass_turn_pressed |
| 1126 | pass | _on_pass_turn_pressed |
| 1127 | pass | _on_pass_turn_pressed |
| 1128 | pass | _on_pass_turn_pressed |
| 1129 | pass | _on_pass_turn_pressed |
| 1130 | pass | _on_pass_turn_pressed |
| 1131 | pass | _on_pass_turn_pressed |
| 1132 | pass | _on_pass_turn_pressed |
| 1133 | pass | _on_pass_turn_pressed |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 1 |
| 1 | 1 |
| 2 | 0 |
| 3 | 0 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 1 |
| campfire | 1 |
| combat | 9 |
| dragon | 1 |
| event | 1 |
| graftwright | 0 — NEVER VISITED |
| guardian | 0 — NEVER VISITED |
| hoarder | 0 — NEVER VISITED |
| last_light | 0 — NEVER VISITED |
| scavenger | 0 — NEVER VISITED |
| snare | 1 |
| start | 2 |
| treasure | 1 |
| umbral_snare | 1 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
