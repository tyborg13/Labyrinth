# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 21.13 minutes. Seed base 5; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 5 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 1 | 5 | 3 / treasure | ERROR: Parameter "t" is null. — res://scripts/combat_board_view.gd:7048 |
| warning | 1 | 5 | 3 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 5 | 4 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2812) — res://tools/run_hunt.gd:265 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-1-1793841363755406000 --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. script error: ERROR: Parameter "t" is null.

Source: `res://scripts/combat_board_view.gd:7048`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1614 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-1614-1793841363755421000 --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1594 | move | ['(6, 4)'] |
| 1595 | card | lantern_shot |
| 1596 | ranged | ['(6, 3)'] |
| 1597 | pass | _on_pass_turn_pressed |
| 1598 | move | (6, 4) |
| 1599 | card | waning_pulse |
| 1600 | confirm_card | _on_confirm_card_play_pressed |
| 1601 | move | (6, 3) |
| 1602 | card | waning_pulse |
| 1603 | confirm_card | _on_confirm_card_play_pressed |
| 1604 | ui | RelicChoice_ashen_brand |
| 1605 | map_room | ['(14, -9)'] |
| 1606 | side_reduced_motion |  |
| 1607 | ui | Choice3 |
| 1608 | ui | Continue |
| 1609 | map_room | ['(14, -5)'] |
| 1610 | side_escape |  |
| 1611 | side_reduced_motion |  |
| 1612 | ui | RelicChoice_pendulum_weight |
| 1613 | map_room | ['(15, -15)'] |

### 3. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1624 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-1624-1793841363755447000 --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1604 | ui | RelicChoice_ashen_brand |
| 1605 | map_room | ['(14, -9)'] |
| 1606 | side_reduced_motion |  |
| 1607 | ui | Choice3 |
| 1608 | ui | Continue |
| 1609 | map_room | ['(14, -5)'] |
| 1610 | side_escape |  |
| 1611 | side_reduced_motion |  |
| 1612 | ui | RelicChoice_pendulum_weight |
| 1613 | map_room | ['(15, -15)'] |
| 1614 | ui | GearOffer_frostwalkers |
| 1615 | ui | GearOffer_voidsilk_carapace |
| 1616 | ui | ItemOffer_storm_jar |
| 1617 | ui | ItemOffer_storm_jar |
| 1618 | ui | ItemOffer_bitter_tonic |
| 1619 | ui | ItemOffer_storm_jar |
| 1620 | ui | Sell from pack |
| 1621 | ui | GEAR |
| 1622 | leave_browse | _on_merchant_hide_pressed |
| 1623 | map_room | ['(15, -9)'] |

### 4. warning: WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1972 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-1972-1793841363755469000 --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1952 | card | sidestep_slash |
| 1953 | move | ['(1, 5)'] |
| 1954 | move | (2, 6) |
| 1955 | move | (1, 5) |
| 1956 | card | brace |
| 1957 | confirm_card | _on_confirm_card_play_pressed |
| 1958 | pass | _on_pass_turn_pressed |
| 1959 | move | (1, 6) |
| 1960 | move | (2, 6) |
| 1961 | card | hamstring_shot |
| 1962 | move | ['(3, 6)'] |
| 1963 | card | last_light |
| 1964 | confirm_card | _on_confirm_card_play_pressed |
| 1965 | ui | SKIP & RECOVER  +3 HP   9803 → 9806 |
| 1966 | map_room | ['(18, -17)'] |
| 1967 | ui | Choice3 |
| 1968 | ui | Continue |
| 1969 | map_room | ['(18, -13)'] |
| 1970 | side_escape |  |
| 1971 | map_room | ['(18, -9)'] |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2812)

Source: `res://tools/run_hunt.gd:265`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2327 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-2327-1793841363755491000 --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2307 | move | (3, 4) |
| 2308 | card | bloody_lunge |
| 2309 | move | ['(2, 4)'] |
| 2310 | move | (3, 4) |
| 2311 | card | whirlwind_slash |
| 2312 | confirm_card | _on_confirm_card_play_pressed |
| 2313 | card | brace |
| 2314 | confirm_card | _on_confirm_card_play_pressed |
| 2315 | move | (4, 2) |
| 2316 | card | lantern_shot |
| 2317 | ranged | ['(6, 3)'] |
| 2318 | card | rooted_stance |
| 2319 | confirm_card | _on_confirm_card_play_pressed |
| 2320 | card | thorn_skewer |
| 2321 | melee | ['(7, 3)'] |
| 2322 | card | bloody_lunge |
| 2323 | move | ['(4, 3)'] |
| 2324 | move | (4, 2) |
| 2325 | move | (5, 2) |
| 2326 | ui | CONTINUE |

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
| combat | 15 |
| dragon | 5 |
| ember_hoarder | 1 |
| event | 14 |
| graftwright | 0 — NEVER VISITED |
| guardian | 1 |
| hoarder | 1 |
| last_light | 1 |
| scavenger | 5 |
| snare | 0 — NEVER VISITED |
| start | 6 |
| treasure | 6 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
