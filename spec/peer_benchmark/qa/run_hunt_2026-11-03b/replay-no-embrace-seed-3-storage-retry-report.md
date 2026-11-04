# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 20.19 minutes. Seed base 3; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 3 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 2848) — res://tools/run_hunt.gd:263 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-3-1-1793736460603480000 --no-embrace --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census_bounded.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. leak: tree_nodes grew more than 25% from section 0 to section 5 (1549 -> 2848)

Source: `res://tools/run_hunt.gd:263`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-25 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-25/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2369 --output-dir /private/tmp/labyrinth_codex/qa-25/replay-3-2369-1793736460603555000 --no-embrace --script /private/tmp/labyrinth_codex/qa-25/run_hunt_census_bounded.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2349 | move | ['(3, 4)'] |
| 2350 | pass | _on_pass_turn_pressed |
| 2351 | card | shadow_step |
| 2352 | blink | ['(4, 2)'] |
| 2353 | card | pale_spark |
| 2354 | ranged | ['(5, 3)'] |
| 2355 | card | whirlwind_slash |
| 2356 | confirm_card | _on_confirm_card_play_pressed |
| 2357 | pass | _on_pass_turn_pressed |
| 2358 | pass | _on_pass_turn_pressed |
| 2359 | card | dull_bolt |
| 2360 | ranged | ['(5, 3)'] |
| 2361 | card | bloody_lunge |
| 2362 | move | ['(4, 2)'] |
| 2363 | card | quick_stab |
| 2364 | melee | ['(4, 4)'] |
| 2365 | move | (2, 2) |
| 2366 | card | updraft |
| 2367 | push | ['(4, 2)'] |
| 2368 | ui | CONTINUE |

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
| combat | 20 |
| dragon | 5 |
| ember_hoarder | 1 |
| event | 6 |
| graftwright | 1 |
| guardian | 3 |
| hoarder | 1 |
| last_light | 0 — NEVER VISITED |
| scavenger | 5 |
| snare | 1 |
| start | 6 |
| treasure | 7 |
| umbral_snare | 1 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
