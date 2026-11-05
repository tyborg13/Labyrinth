# Run hunt — November 2026

Runs started: 4; processes ended: 4; completed runs: 4 (victory 4, defeat 0, Embrace 0).
Wall clock: 51.25 minutes. Seed base 3; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 4 | 3 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 3 | 5 / boss | WARNING: ObjectDB instances leaked at exit (run with --verbose for details). — core/object/object.cpp:2641 |
| warning | 1 | 6 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ember_siphon, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 3 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_hourglass_awl, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2427) — res://tools/run_hunt.gd:258 |
| leak | 1 | 4 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2802) — res://tools/run_hunt.gd:258 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2852) — res://tools/run_hunt.gd:258 |
| leak | 1 | 6 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1559 -> 2174) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 3, 4, 5, 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-1-1793840127251116000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: WARNING: ObjectDB instances leaked at exit (run with --verbose for details).

Source: `core/object/object.cpp:2641`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2951 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-2951-1793840127251136000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2931 | blink | ['(3, 4)'] |
| 2932 | move | (4, 4) |
| 2933 | card | waning_pulse |
| 2934 | confirm_card | _on_confirm_card_play_pressed |
| 2935 | card | dull_bolt |
| 2936 | ranged | ['(7, 5)'] |
| 2937 | move | (5, 4) |
| 2938 | card | whirlwind_slash |
| 2939 | confirm_card | _on_confirm_card_play_pressed |
| 2940 | card | dull_bolt |
| 2941 | ranged | ['(6, 4)'] |
| 2942 | pass | _on_pass_turn_pressed |
| 2943 | card | pale_spark |
| 2944 | ranged | ['(7, 5)'] |
| 2945 | card | guarded_step |
| 2946 | move | ['(5, 5)'] |
| 2947 | move | (5, 3) |
| 2948 | card | quick_stab |
| 2949 | melee | ['(7, 4)'] |
| 2950 | ui | COMPLETE ASCENT |

### 3. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ember_siphon, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 541 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-6-541-1793840127251160000 --no-embrace
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

### 4. warning: WARNING: Relic glossary above-row overflow: RelicChoice_hourglass_awl, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 768 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-768-1793840127251181000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 748 | move | (1, 3) |
| 749 | move | (1, 4) |
| 750 | card | patch_up |
| 751 | confirm_card | _on_confirm_card_play_pressed |
| 752 | card | shadow_step |
| 753 | blink | ['(1, 2)'] |
| 754 | card | waning_pulse |
| 755 | confirm_card | _on_confirm_card_play_pressed |
| 756 | ui | SKIP & RECOVER  +3 HP   9770 → 9773 |
| 757 | map_room | ['(6, 3)'] |
| 758 | ui | GearOffer_dust_tabi |
| 759 | ui | MagicOffer_molten_reach |
| 760 | ui | MagicOffer_revealing_glare |
| 761 | ui | ItemOffer_smoke_bomb |
| 762 | ui | ItemOffer_pitch_firebomb |
| 763 | ui | GearOffer_lodestone_buckler |
| 764 | ui | ItemOffer_smoke_bomb |
| 765 | ui | Buy · 25 Embers |
| 766 | leave_browse | _on_merchant_hide_pressed |
| 767 | map_room | ['(5, 6)'] |

### 5. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2427)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2319 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-2319-1793840127251203000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2299 | confirm_card | _on_confirm_card_play_pressed |
| 2300 | move | (4, 4) |
| 2301 | move | (3, 4) |
| 2302 | move | (5, 4) |
| 2303 | card | quick_stab |
| 2304 | melee | ['(7, 5)'] |
| 2305 | card | lantern_shot |
| 2306 | ranged | ['(7, 5)'] |
| 2307 | move | (4, 4) |
| 2308 | move | (5, 5) |
| 2309 | card | brace |
| 2310 | confirm_card | _on_confirm_card_play_pressed |
| 2311 | card | whirlwind_slash |
| 2312 | confirm_card | _on_confirm_card_play_pressed |
| 2313 | move | (3, 3) |
| 2314 | card | bloody_lunge |
| 2315 | move | ['(4, 4)'] |
| 2316 | card | thorn_skewer |
| 2317 | melee | ['(4, 5)'] |
| 2318 | ui | CONTINUE |

### 6. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2802)

Source: `res://tools/run_hunt.gd:258`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 2147 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-4-2147-1793840127251224000 --no-embrace
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

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2852)

Source: `res://tools/run_hunt.gd:258`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 2369 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-2369-1793840127251241000 --no-embrace
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

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1559 -> 2174)

Source: `res://tools/run_hunt.gd:258`. Seeds: 6.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 6 --runs 1 --processes 1 --stop-after 2292 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-6-2292-1793840127251256000 --no-embrace
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
| 3 | 4 |
| 4 | 4 |
| 5 | 4 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 24 |
| campfire | 24 |
| combat | 99 |
| dragon | 24 |
| ember_hoarder | 4 |
| event | 43 |
| graftwright | 3 |
| guardian | 9 |
| hoarder | 4 |
| last_light | 2 |
| scavenger | 25 |
| snare | 2 |
| start | 24 |
| treasure | 27 |
| umbral_snare | 2 |
| warband | 2 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
