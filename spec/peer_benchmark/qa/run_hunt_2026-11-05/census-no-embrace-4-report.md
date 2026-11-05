# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 23.15 minutes. Seed base 4; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 4 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2862) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-1-1793862408952586000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_replay.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. leak: tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2862)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2147 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-2147-1793862408952601000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_replay.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2127 | card | patch_up |
| 2128 | confirm_card | _on_confirm_card_play_pressed |
| 2129 | pass | _on_pass_turn_pressed |
| 2130 | card | sidestep_slash |
| 2131 | move | ['(2, 1)'] |
| 2132 | move | (4, 1) |
| 2133 | card | whirlwind_slash |
| 2134 | confirm_card | _on_confirm_card_play_pressed |
| 2135 | move | (3, 5) |
| 2136 | card | waning_pulse |
| 2137 | confirm_card | _on_confirm_card_play_pressed |
| 2138 | card | lantern_shot |
| 2139 | ranged | ['(5, 5)'] |
| 2140 | move | (4, 5) |
| 2141 | card | hamstring_shot |
| 2142 | move | ['(5, 3)'] |
| 2143 | move | (5, 4) |
| 2144 | card | pale_spark |
| 2145 | ranged | ['(3, 4)'] |
| 2146 | ui | CONTINUE |

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
| boss | 5 |
| campfire | 5 |
| combat | 22 |
| dragon | 5 |
| event | 9 |
| graftwright | 1 |
| guardian | 1 |
| hoarder | 0 — NEVER VISITED |
| last_light | 1 |
| scavenger | 5 |
| snare | 0 — NEVER VISITED |
| start | 6 |
| treasure | 5 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
