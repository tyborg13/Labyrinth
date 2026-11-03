# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 14.04 minutes. Seed base 10; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 1 | 10 | 2 / combat | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| softlock | 1 | 10 | 2 / combat | Fight exceeded 200 decisions — res://tools/run_hunt.gd:237 |
| script error | 9 | 10 | 1 / guardian | SCRIPT ERROR: Invalid access of index '2' on a base object of type: 'Array'. — res://scripts/guardian_combat_rules.gd:222 |
| script error | 1 | 10 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 10.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 10 --runs 1 --processes 1 --stop-after 1615 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-10-1615-1793585042898863000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1595 | card | bloody_lunge |
| 1596 | move | ['(6, 2)'] |
| 1597 | card | vacuum_line |
| 1598 | pull | ['(6, 1)'] |
| 1599 | move | (5, 2) |
| 1600 | move | (6, 2) |
| 1601 | move | (5, 3) |
| 1602 | card | pale_spark |
| 1603 | ranged | ['(6, 1)'] |
| 1604 | card | shadow_step |
| 1605 | blink | ['(7, 2)'] |
| 1606 | move | (6, 2) |
| 1607 | move | (5, 2) |
| 1608 | card | bloody_lunge |
| 1609 | move | ['(5, 1)'] |
| 1610 | card | guarded_step |
| 1611 | move | ['(5, 3)'] |
| 1612 | card | hamstring_shot |
| 1613 | move | ['(6, 2)'] |
| 1614 | card | brace |

### 2. softlock: Fight exceeded 200 decisions

Source: `res://tools/run_hunt.gd:237`. Seeds: 10.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 10 --runs 1 --processes 1 --stop-after 1615 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-10-1615-1793585042898886000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1595 | card | bloody_lunge |
| 1596 | move | ['(6, 2)'] |
| 1597 | card | vacuum_line |
| 1598 | pull | ['(6, 1)'] |
| 1599 | move | (5, 2) |
| 1600 | move | (6, 2) |
| 1601 | move | (5, 3) |
| 1602 | card | pale_spark |
| 1603 | ranged | ['(6, 1)'] |
| 1604 | card | shadow_step |
| 1605 | blink | ['(7, 2)'] |
| 1606 | move | (6, 2) |
| 1607 | move | (5, 2) |
| 1608 | card | bloody_lunge |
| 1609 | move | ['(5, 1)'] |
| 1610 | card | guarded_step |
| 1611 | move | ['(5, 3)'] |
| 1612 | card | hamstring_shot |
| 1613 | move | ['(6, 2)'] |
| 1614 | card | brace |

### 3. script error: SCRIPT ERROR: Invalid access of index '2' on a base object of type: 'Array'.

Source: `res://scripts/guardian_combat_rules.gd:222`. Seeds: 10.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 10 --runs 1 --processes 1 --stop-after 857 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-10-857-1793585042898900000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 837 | map_room | ['(6, 5)'] |
| 838 | ui | RelicChoice_pitch_gloves |
| 839 | map_room | ['(7, -7)'] |
| 840 | side_resume |  |
| 841 | side_escape |  |
| 842 | begin_combat | _on_pre_battle_start_pressed |
| 843 | card | shadow_step |
| 844 | blink | ['(4, 4)'] |
| 845 | card | bloody_lunge |
| 846 | move | ['(4, 4)'] |
| 847 | move | (3, 4) |
| 848 | move | (4, 4) |
| 849 | card | waning_pulse |
| 850 | confirm_card | _on_confirm_card_play_pressed |
| 851 | card | brace |
| 852 | confirm_card | _on_confirm_card_play_pressed |
| 853 | move | (5, 3) |
| 854 | card | vacuum_line |
| 855 | pull | ['(6, 4)'] |
| 856 | card | whirlwind_slash |

### 4. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 10.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 10 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-10-1-1793585042898917000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

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
| combat | 13 |
| dragon | 2 |
| event | 7 |
| graftwright | 0 — NEVER VISITED |
| guardian | 1 |
| hoarder | 0 — NEVER VISITED |
| last_light | 0 — NEVER VISITED |
| scavenger | 1 |
| snare | 0 — NEVER VISITED |
| start | 3 |
| treasure | 3 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
