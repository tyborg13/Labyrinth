# Run hunt — November 2026

Runs started: 2; processes ended: 2; completed runs: 2 (victory 0, defeat 0, Embrace 2).
Wall clock: 21.37 minutes. Seed base 24; at most 2 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 2 | 24 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 24 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_echoing_blade, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 24 | 2 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_thunder_relay, viewport=(1920.0, 1920.0), block=(306.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 24, 25.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 24 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-24-1-1793925213437154000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: WARNING: Relic glossary above-row overflow: RelicChoice_echoing_blade, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 24.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 24 --runs 1 --processes 1 --stop-after 815 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-24-815-1793925213437171000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 795 | pass | _on_pass_turn_pressed |
| 796 | card | dull_bolt |
| 797 | ranged | ['(7, 3)'] |
| 798 | ui | RelicChoice_cragbound_gauntlet |
| 799 | map_room | ['(6, 5)'] |
| 800 | equipment | _on_loadout_button_pressed |
| 801 | ui | CloseCharacterOverlay |
| 802 | map_room | ['(6, 5)'] |
| 803 | side_settings |  |
| 804 | ui | Browse wares |
| 805 | ui | Purge a spell |
| 806 | ui | MagicDeckRow_pale_spark |
| 807 | ui | MagicDeckRow_waning_pulse |
| 808 | ui | Back |
| 809 | ui | MagicDeckRow_waning_pulse |
| 810 | ui | Purge for 50 Embers |
| 811 | ui | MagicDeckRow_dull_bolt |
| 812 | ui | ItemOffer_thunderstone |
| 813 | ui | Leave |
| 814 | map_room | ['(4, 6)'] |

### 3. warning: WARNING: Relic glossary above-row overflow: RelicChoice_thunder_relay, viewport=(1920.0, 1920.0), block=(306.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 24.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 24 --runs 1 --processes 1 --stop-after 1230 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-24-1230-1793925213437203000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1210 | move | (3, 7) |
| 1211 | card | sidestep_slash |
| 1212 | move | ['(3, 7)'] |
| 1213 | move | (3, 6) |
| 1214 | card | sidestep_slash |
| 1215 | move | ['(4, 6)'] |
| 1216 | card | bloody_lunge |
| 1217 | move | ['(2, 6)'] |
| 1218 | move | (3, 6) |
| 1219 | card | pale_spark |
| 1220 | ranged | ['(5, 6)'] |
| 1221 | card | lantern_shot |
| 1222 | ranged | ['(2, 6)'] |
| 1223 | move | (2, 6) |
| 1224 | card | whirlwind_slash |
| 1225 | confirm_card | _on_confirm_card_play_pressed |
| 1226 | ui | SKIP & RECOVER  +3 HP   9741 → 9744 |
| 1227 | map_room | ['(10, -1)'] |
| 1228 | side_escape |  |
| 1229 | map_room | ['(10, 4)'] |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 2 |
| 1 | 2 |
| 2 | 2 |
| 3 | 1 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 5 |
| campfire | 7 |
| combat | 30 |
| dragon | 5 |
| ember_hoarder | 1 |
| event | 7 |
| graftwright | 2 |
| guardian | 4 |
| hoarder | 1 |
| last_light | 2 |
| scavenger | 6 |
| snare | 0 — NEVER VISITED |
| start | 7 |
| treasure | 8 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
