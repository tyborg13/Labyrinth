# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 6.36 minutes. Seed base 1; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 1 | 1 | 1 / boss | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| script error | 11 | 1 | 1 / boss | SCRIPT ERROR: Invalid access of index '2' on a base object of type: 'Array'. — res://scripts/guardian_combat_rules.gd:222 |
| script error | 1 | 1 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 887 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-887-1793582077077910000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_prior.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 867 | move | (4, 2) |
| 868 | move | (4, 1) |
| 869 | card | waning_pulse |
| 870 | confirm_card | _on_confirm_card_play_pressed |
| 871 | card | pale_spark |
| 872 | ranged | ['(4, 3)'] |
| 873 | move | (4, 2) |
| 874 | card | dull_bolt |
| 875 | ranged | ['(5, 4)'] |
| 876 | pass | _on_pass_turn_pressed |
| 877 | card | quick_stab |
| 878 | melee | ['(5, 4)'] |
| 879 | card | lantern_shot |
| 880 | ranged | ['(4, 4)'] |
| 881 | move | (3, 2) |
| 882 | move | (3, 3) |
| 883 | card | hamstring_shot |
| 884 | move | ['(1, 4)'] |
| 885 | move | (3, 3) |
| 886 | card | waning_pulse |

### 2. script error: SCRIPT ERROR: Invalid access of index '2' on a base object of type: 'Array'.

Source: `res://scripts/guardian_combat_rules.gd:222`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 865 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-865-1793582077077945000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_prior.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 845 | ui |  |
| 846 | ui | Continue |
| 847 | map_room | ['(3, 7)'] |
| 848 | ui |  |
| 849 | side_reduced_motion |  |
| 850 | map_room | ['(8, 0)'] |
| 851 | begin_combat | _on_pre_battle_start_pressed |
| 852 | card | bloody_lunge |
| 853 | move | ['(2, 4)'] |
| 854 | card | waning_pulse |
| 855 | confirm_card | _on_confirm_card_play_pressed |
| 856 | move | (2, 3) |
| 857 | move | (2, 4) |
| 858 | card | sidestep_slash |
| 859 | move | ['(2, 2)'] |
| 860 | move | (3, 3) |
| 861 | card | whirlwind_slash |
| 862 | confirm_card | _on_confirm_card_play_pressed |
| 863 | card | pale_spark |
| 864 | ranged | ['(2, 1)'] |

### 3. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 1.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-1-1793582077077971000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_prior.gd
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
| 2 | 0 |
| 3 | 0 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 2 |
| campfire | 2 |
| combat | 8 |
| dragon | 2 |
| event | 3 |
| graftwright | 1 |
| guardian | 1 |
| hoarder | 0 — NEVER VISITED |
| last_light | 0 — NEVER VISITED |
| scavenger | 2 |
| snare | 0 — NEVER VISITED |
| start | 2 |
| treasure | 2 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
