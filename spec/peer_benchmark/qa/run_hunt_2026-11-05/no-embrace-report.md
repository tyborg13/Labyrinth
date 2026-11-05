# Run hunt — November 2026

Runs started: 5; processes ended: 5; completed runs: 4 (victory 4, defeat 0, Embrace 0).
Wall clock: 66.81 minutes. Seed base 4; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 5 | 4 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 7 | 2 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 6 | 1 / treasure | WARNING: Relic glossary above-row overflow: RelicChoice_ember_siphon, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 8 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2431) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2456) — res://tools/run_hunt.gd:258 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2862) — res://tools/run_hunt.gd:258 |
| leak | 1 | 6 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1566 -> 2232) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 4, 5, 6, 7, 8.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-1-1793860981019948000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 7 --runs 1 --processes 1 --stop-after 1885 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-7-1885-1793860981019962000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1865 | card | quick_stab |
| 1866 | melee | ['(5, 5)'] |
| 1867 | card | pale_spark |
| 1868 | ranged | ['(6, 5)'] |
| 1869 | card | waning_pulse |
| 1870 | confirm_card | _on_confirm_card_play_pressed |
| 1871 | pass | _on_pass_turn_pressed |
| 1872 | move | (5, 5) |
| 1873 | move | (4, 5) |
| 1874 | card | dull_bolt |
| 1875 | ranged | ['(6, 5)'] |
| 1876 | card | hamstring_shot |
| 1877 | move | ['(5, 5)'] |
| 1878 | card | waning_pulse |
| 1879 | confirm_card | _on_confirm_card_play_pressed |
| 1880 | card | whirlwind_slash |
| 1881 | confirm_card | _on_confirm_card_play_pressed |
| 1882 | move | (3, 5) |
| 1883 | card | hamstring_shot |
| 1884 | move | ['(4, 5)'] |

### 3. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ember_siphon, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 541 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-6-541-1793860981019980000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 521 | ranged | ['(5, 3)'] |
| 522 | move | (4, 3) |
| 523 | card | pale_spark |
| 524 | ranged | ['(4, 5)'] |
| 525 | card | brace |
| 526 | confirm_card | _on_confirm_card_play_pressed |
| 527 | move | (3, 3) |
| 528 | card | dull_bolt |
| 529 | ranged | ['(3, 1)'] |
| 530 | card | dull_bolt |
| 531 | ranged | ['(3, 1)'] |
| 532 | card | sidestep_slash |
| 533 | move | ['(3, 2)'] |
| 534 | card | quick_stab |
| 535 | melee | ['(3, 1)'] |
| 536 | ui | SKIP & RECOVER  +3 HP   9888 → 9891 |
| 537 | map_room | ['(6, 3)'] |
| 538 | side_escape |  |
| 539 | side_reduced_motion |  |
| 540 | map_room | ['(5, 6)'] |

### 4. leak: tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2431)

Source: `res://tools/run_hunt.gd:258`. Seeds: 8.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 8 --runs 1 --processes 1 --stop-after 2452 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-8-2452-1793860981020002000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2432 | card | hamstring_shot |
| 2433 | move | ['(1, 6)'] |
| 2434 | move | (1, 5) |
| 2435 | move | (1, 4) |
| 2436 | card | pale_spark |
| 2437 | ranged | ['(1, 2)'] |
| 2438 | move | (4, 6) |
| 2439 | card | lantern_shot |
| 2440 | ranged | ['(3, 2)'] |
| 2441 | card | galvanize |
| 2442 | confirm_card | _on_confirm_card_play_pressed |
| 2443 | move | (3, 7) |
| 2444 | move | (3, 6) |
| 2445 | card | guarded_step |
| 2446 | move | ['(2, 6)'] |
| 2447 | card | dull_bolt |
| 2448 | ranged | ['(3, 3)'] |
| 2449 | card | bloody_lunge |
| 2450 | move | ['(2, 5)'] |
| 2451 | ui | CONTINUE |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2456)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2283 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-5-2283-1793860981020017000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2263 | confirm_card | _on_confirm_card_play_pressed |
| 2264 | card | bloody_lunge |
| 2265 | move | ['(2, 1)'] |
| 2266 | move | (4, 1) |
| 2267 | card | brace |
| 2268 | confirm_card | _on_confirm_card_play_pressed |
| 2269 | card | whirlwind_slash |
| 2270 | confirm_card | _on_confirm_card_play_pressed |
| 2271 | card | dull_bolt |
| 2272 | ranged | ['(5, 2)'] |
| 2273 | card | quick_stab |
| 2274 | melee | ['(6, 2)'] |
| 2275 | move | (4, 3) |
| 2276 | move | (4, 2) |
| 2277 | card | waning_pulse |
| 2278 | confirm_card | _on_confirm_card_play_pressed |
| 2279 | move | (3, 1) |
| 2280 | card | last_light |
| 2281 | confirm_card | _on_confirm_card_play_pressed |
| 2282 | ui | CONTINUE |

### 6. leak: tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2862)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2147 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-2147-1793860981020030000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1566 -> 2232)

Source: `res://tools/run_hunt.gd:258`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 2292 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-6-2292-1793860981020043000 --no-embrace --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2272 | card | whirlwind_slash |
| 2273 | confirm_card | _on_confirm_card_play_pressed |
| 2274 | card | quick_stab |
| 2275 | melee | ['(4, 4)'] |
| 2276 | move | (3, 3) |
| 2277 | card | hamstring_shot |
| 2278 | move | ['(2, 2)'] |
| 2279 | pass | _on_pass_turn_pressed |
| 2280 | card | lantern_shot |
| 2281 | ranged | ['(5, 4)'] |
| 2282 | move | (3, 3) |
| 2283 | card | dull_bolt |
| 2284 | ranged | ['(4, 4)'] |
| 2285 | card | patch_up |
| 2286 | confirm_card | _on_confirm_card_play_pressed |
| 2287 | card | guarded_step |
| 2288 | move | ['(3, 4)'] |
| 2289 | card | quick_stab |
| 2290 | melee | ['(5, 4)'] |
| 2291 | ui | CONTINUE |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 5 |
| 1 | 5 |
| 2 | 5 |
| 3 | 4 |
| 4 | 4 |
| 5 | 4 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 26 |
| campfire | 26 |
| combat | 110 |
| dragon | 26 |
| ember_hoarder | 4 |
| event | 48 |
| graftwright | 3 |
| guardian | 10 |
| hoarder | 4 |
| last_light | 3 |
| scavenger | 29 |
| snare | 2 |
| start | 27 |
| treasure | 29 |
| umbral_snare | 2 |
| warband | 4 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
