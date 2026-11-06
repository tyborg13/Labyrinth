# Run hunt — November 2026

Runs started: 2; processes ended: 2; completed runs: 1 (victory 0, defeat 0, Embrace 1).
Wall clock: 19.42 minutes. Seed base 13; at most 2 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 2 | 13 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 13 | 3 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 13 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_tailwind_fletching, viewport=(1920.0, 1920.0), block=(942.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 13, 14.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 13 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-13-1-1793899562629132000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 13.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 13 --runs 1 --processes 1 --stop-after 2233 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-13-2233-1793899562629145000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2213 | move | (4, 5) |
| 2214 | move | (4, 6) |
| 2215 | card | guarded_step |
| 2216 | move | ['(4, 5)'] |
| 2217 | card | waning_pulse |
| 2218 | confirm_card | _on_confirm_card_play_pressed |
| 2219 | card | bloody_lunge |
| 2220 | move | ['(4, 4)'] |
| 2221 | card | waning_pulse |
| 2222 | confirm_card | _on_confirm_card_play_pressed |
| 2223 | move | (4, 5) |
| 2224 | move | (4, 4) |
| 2225 | card | whirlwind_slash |
| 2226 | confirm_card | _on_confirm_card_play_pressed |
| 2227 | card | sidestep_slash |
| 2228 | move | ['(4, 6)'] |
| 2229 | move | (4, 7) |
| 2230 | move | (4, 6) |
| 2231 | card | sidestep_slash |
| 2232 | move | ['(4, 5)'] |

### 3. warning: WARNING: Relic glossary above-row overflow: RelicChoice_tailwind_fletching, viewport=(1920.0, 1920.0), block=(942.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 13.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 13 --runs 1 --processes 1 --stop-after 644 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-13-644-1793899562629161000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 624 | card | lantern_shot |
| 625 | ranged | ['(4, 6)'] |
| 626 | card | waning_pulse |
| 627 | confirm_card | _on_confirm_card_play_pressed |
| 628 | move | (4, 4) |
| 629 | card | hamstring_shot |
| 630 | move | ['(4, 5)'] |
| 631 | card | sidestep_slash |
| 632 | move | ['(4, 5)'] |
| 633 | card | dull_bolt |
| 634 | ranged | ['(5, 5)'] |
| 635 | ui | SKIP & RECOVER  +3 HP   9854 → 9857 |
| 636 | map_room | ['(6, -3)'] |
| 637 | ui | Choice3 |
| 638 | ui | Continue |
| 639 | map_room | ['(6, 2)'] |
| 640 | side_reduced_motion |  |
| 641 | ui | ItemOffer_smelling_salts |
| 642 | ui | Leave |
| 643 | map_room | ['(6, 5)'] |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 2 |
| 1 | 1 |
| 2 | 1 |
| 3 | 1 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 3 |
| campfire | 4 |
| combat | 19 |
| dragon | 3 |
| event | 12 |
| graftwright | 1 |
| guardian | 1 |
| hoarder | 0 — NEVER VISITED |
| last_light | 1 |
| scavenger | 3 |
| snare | 1 |
| start | 5 |
| treasure | 5 |
| umbral_snare | 1 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
