# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 9.36 minutes. Seed base 2; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 2 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 2 | 2 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:259 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-2-1-1793734193956088000 --no-embrace --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:259`. Seeds: 2.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 2 --runs 1 --processes 1 --stop-after 1322 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-2-1322-1793734193956102000 --no-embrace --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census.gd
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

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 1 |
| 1 | 1 |
| 2 | 1 |
| 3 | 0 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 2 |
| campfire | 2 |
| combat | 9 |
| dragon | 2 |
| ember_hoarder | 1 |
| event | 8 |
| graftwright | 1 |
| guardian | 1 |
| hoarder | 1 |
| last_light | 0 — NEVER VISITED |
| scavenger | 3 |
| snare | 0 — NEVER VISITED |
| start | 3 |
| treasure | 3 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
