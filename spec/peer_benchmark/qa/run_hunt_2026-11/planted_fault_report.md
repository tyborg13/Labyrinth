# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 0.16 minutes. Seed base 1; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 1 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 1 | 1 | 0 / combat | ERROR: QA16_PLANTED_FAULT: report pipeline proof — /private/tmp/labyrinth_codex/qa-16/run_hunt_planted_final.gd:188 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-1-1793585786439838000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_planted_final.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. script error: ERROR: QA16_PLANTED_FAULT: report pipeline proof

Source: `/private/tmp/labyrinth_codex/qa-16/run_hunt_planted_final.gd:188`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 13 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-13-1793585786439847000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_planted_final.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1 | dialogue | ['InputEventMouseButton: button_index=1, mods=none, pressed=true, canceled=false, position=((0.0, 0.0)), button_mask=0, double_click=false'] |
| 2 | dialogue | ['InputEventMouseButton: button_index=1, mods=none, pressed=true, canceled=false, position=((0.0, 0.0)), button_mask=0, double_click=false'] |
| 3 | dialogue | ['InputEventMouseButton: button_index=1, mods=none, pressed=true, canceled=false, position=((0.0, 0.0)), button_mask=0, double_click=false'] |
| 4 | dialogue | ['InputEventMouseButton: button_index=1, mods=none, pressed=true, canceled=false, position=((0.0, 0.0)), button_mask=0, double_click=false'] |
| 5 | dialogue | ['InputEventMouseButton: button_index=1, mods=none, pressed=true, canceled=false, position=((0.0, 0.0)), button_mask=0, double_click=false'] |
| 6 | map_room | ['(1, 0)'] |
| 7 | begin_combat | _on_pre_battle_start_pressed |
| 8 | side_deck |  |
| 9 | ui | Skip Tutorial |
| 10 | move | (4, 4) |
| 11 | card | pale_spark |
| 12 | ranged | ['(4, 3)'] |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 1 |
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
| campfire | 0 — NEVER VISITED |
| combat | 1 |
| dragon | 0 — NEVER VISITED |
| event | 0 — NEVER VISITED |
| graftwright | 0 — NEVER VISITED |
| guardian | 0 — NEVER VISITED |
| hoarder | 0 — NEVER VISITED |
| last_light | 0 — NEVER VISITED |
| scavenger | 0 — NEVER VISITED |
| snare | 0 — NEVER VISITED |
| start | 1 |
| treasure | 0 — NEVER VISITED |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
