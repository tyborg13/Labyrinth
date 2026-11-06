# Run hunt — November 2026

Runs started: 4; processes ended: 4; completed runs: 3 (victory 3, defeat 0, Embrace 0).
Wall clock: 58.87 minutes. Seed base 4; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 4 | 4 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 1 | 5 | 0 / start | ERROR: Parameter "t" is null. — res://scripts/board_layer_slices.gd:59 |
| warning | 1 | 7 | 2 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 6 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ember_siphon, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 5 | 4 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_venom_signet, viewport=(1920.0, 1920.0), block=(1260.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 5 | 5 / start | orphans grew more than 25% from section 0 to section 5 (0 -> 4) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1580 -> 2404) — res://tools/run_hunt.gd:258 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1580 -> 2874) — res://tools/run_hunt.gd:258 |
| leak | 1 | 6 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1584 -> 2250) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 4, 5, 6, 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-4-1-1793898388416927000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. script error: ERROR: Parameter "t" is null.

Source: `res://scripts/board_layer_slices.gd:59`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 7 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-7-1793898388416939000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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

### 3. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 7 --runs 1 --processes 1 --stop-after 1885 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-7-1885-1793898388416952000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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

### 4. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ember_siphon, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 541 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-6-541-1793898388416969000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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

### 5. warning: WARNING: Relic glossary above-row overflow: RelicChoice_venom_signet, viewport=(1920.0, 1920.0), block=(1260.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2036 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-2036-1793898388416985000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2016 | card | sidestep_slash |
| 2017 | move | ['(3, 4)'] |
| 2018 | card | hamstring_shot |
| 2019 | move | ['(3, 2)'] |
| 2020 | move | (4, 2) |
| 2021 | card | bloody_lunge |
| 2022 | move | ['(5, 2)'] |
| 2023 | card | frostbolt |
| 2024 | ranged | ['(4, 4)'] |
| 2025 | move | (5, 1) |
| 2026 | move | (5, 3) |
| 2027 | card | waning_pulse |
| 2028 | confirm_card | _on_confirm_card_play_pressed |
| 2029 | card | thorn_skewer |
| 2030 | melee | ['(5, 4)'] |
| 2031 | ui | SKIP & RECOVER  +3 HP   9519 → 9522 |
| 2032 | map_room | ['(18, -14)'] |
| 2033 | ui | GearOffer_hunting_spear |
| 2034 | ui | Leave |
| 2035 | map_room | ['(18, -10)'] |

### 6. leak: orphans grew more than 25% from section 0 to section 5 (0 -> 4)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2273 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-2273-1793898388417001000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2253 | pass | _on_pass_turn_pressed |
| 2254 | card | bloody_lunge |
| 2255 | move | ['(5, 4)'] |
| 2256 | card | waning_pulse |
| 2257 | confirm_card | _on_confirm_card_play_pressed |
| 2258 | move | (5, 2) |
| 2259 | card | quick_stab |
| 2260 | melee | ['(3, 1)'] |
| 2261 | card | whirlwind_slash |
| 2262 | confirm_card | _on_confirm_card_play_pressed |
| 2263 | card | frostbolt |
| 2264 | ranged | ['(3, 2)'] |
| 2265 | move | (4, 1) |
| 2266 | card | frostbolt |
| 2267 | ranged | ['(5, 2)'] |
| 2268 | move | (5, 1) |
| 2269 | move | (4, 1) |
| 2270 | card | whirlwind_slash |
| 2271 | confirm_card | _on_confirm_card_play_pressed |
| 2272 | ui | CONTINUE |

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1580 -> 2404)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2273 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-2273-1793898388417015000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2253 | pass | _on_pass_turn_pressed |
| 2254 | card | bloody_lunge |
| 2255 | move | ['(5, 4)'] |
| 2256 | card | waning_pulse |
| 2257 | confirm_card | _on_confirm_card_play_pressed |
| 2258 | move | (5, 2) |
| 2259 | card | quick_stab |
| 2260 | melee | ['(3, 1)'] |
| 2261 | card | whirlwind_slash |
| 2262 | confirm_card | _on_confirm_card_play_pressed |
| 2263 | card | frostbolt |
| 2264 | ranged | ['(3, 2)'] |
| 2265 | move | (4, 1) |
| 2266 | card | frostbolt |
| 2267 | ranged | ['(5, 2)'] |
| 2268 | move | (5, 1) |
| 2269 | move | (4, 1) |
| 2270 | card | whirlwind_slash |
| 2271 | confirm_card | _on_confirm_card_play_pressed |
| 2272 | ui | CONTINUE |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1580 -> 2874)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2141 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-4-2141-1793898388417032000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2121 | card | lantern_shot |
| 2122 | ranged | ['(6, 1)'] |
| 2123 | card | shadow_step |
| 2124 | blink | ['(4, 2)'] |
| 2125 | move | (2, 2) |
| 2126 | card | pale_spark |
| 2127 | ranged | ['(4, 1)'] |
| 2128 | card | bloody_lunge |
| 2129 | move | ['(4, 4)'] |
| 2130 | move | (4, 3) |
| 2131 | move | (4, 2) |
| 2132 | card | pale_spark |
| 2133 | ranged | ['(4, 3)'] |
| 2134 | card | quick_stab |
| 2135 | melee | ['(4, 3)'] |
| 2136 | move | (4, 5) |
| 2137 | move | (4, 4) |
| 2138 | card | molten_reach |
| 2139 | aoe | ['(5, 5)'] |
| 2140 | ui | CONTINUE |

### 9. leak: tree_nodes grew more than 25% from section 0 to section 5 (1584 -> 2250)

Source: `res://tools/run_hunt.gd:258`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 2292 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-6-2292-1793898388417045000 --no-embrace --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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
| 0 | 4 |
| 1 | 4 |
| 2 | 4 |
| 3 | 3 |
| 4 | 3 |
| 5 | 3 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 20 |
| campfire | 20 |
| combat | 82 |
| dragon | 20 |
| ember_hoarder | 4 |
| event | 40 |
| graftwright | 3 |
| guardian | 8 |
| hoarder | 4 |
| last_light | 2 |
| scavenger | 21 |
| snare | 3 |
| start | 21 |
| treasure | 22 |
| umbral_snare | 3 |
| warband | 3 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
