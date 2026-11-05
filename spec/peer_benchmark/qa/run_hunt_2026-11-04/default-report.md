# Run hunt — November 2026

Runs started: 10; processes ended: 10; completed runs: 10 (victory 3, defeat 0, Embrace 7).
Wall clock: 61.59 minutes. Seed base 3; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 10 | 3 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 5 | 3 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 11 | 0 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 9 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_coffin_nails, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 5 | 4 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 12 | 2 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 9 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1551 -> 2254) — res://tools/run_hunt.gd:258 |
| leak | 1 | 12 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2762) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2812) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 3, 4, 5, 6, 7, 8, 9, 10, 11, 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 3 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-1-1793840127098693000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1624 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-1624-1793840127098713000
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

### 3. warning: WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 11.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 11 --runs 1 --processes 1 --stop-after 118 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-11-118-1793840127098741000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 98 | card | bloody_lunge |
| 99 | move | ['(2, 4)'] |
| 100 | move | (3, 4) |
| 101 | pass | _on_pass_turn_pressed |
| 102 | card | whirlwind_slash |
| 103 | confirm_card | _on_confirm_card_play_pressed |
| 104 | card | sidestep_slash |
| 105 | move | ['(3, 5)'] |
| 106 | move | (3, 4) |
| 107 | card | waning_pulse |
| 108 | confirm_card | _on_confirm_card_play_pressed |
| 109 | card | shadow_step |
| 110 | blink | ['(1, 5)'] |
| 111 | move | (1, 6) |
| 112 | card | dull_bolt |
| 113 | ranged | ['(1, 5)'] |
| 114 | ui | SKIP & RECOVER  +3 HP   9927 → 9930 |
| 115 | map_room | ['(2, 0)'] |
| 116 | side_escape |  |
| 117 | map_room | ['(-1, 2)'] |

### 4. warning: WARNING: Relic glossary above-row overflow: RelicChoice_coffin_nails, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 724 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-9-724-1793840127098761000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 704 | move | ['(2, 6)'] |
| 705 | move | (3, 7) |
| 706 | card | shadow_step |
| 707 | blink | ['(3, 7)'] |
| 708 | card | lantern_shot |
| 709 | confirm_card | _on_confirm_card_play_pressed |
| 710 | move | (3, 6) |
| 711 | move | (2, 6) |
| 712 | pass | _on_pass_turn_pressed |
| 713 | move | (1, 6) |
| 714 | pass | _on_pass_turn_pressed |
| 715 | move | (1, 5) |
| 716 | move | (1, 6) |
| 717 | pass | _on_pass_turn_pressed |
| 718 | move | (3, 6) |
| 719 | pass | _on_pass_turn_pressed |
| 720 | move | (4, 7) |
| 721 | ui | SKIP & RECOVER  +3 HP   9547 → 9550 |
| 722 | side_escape |  |
| 723 | map_room | ['(5, 6)'] |

### 5. warning: WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1972 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-1972-1793840127098779000
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

### 6. warning: WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 840 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-12-840-1793840127098796000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 820 | card | lantern_shot |
| 821 | ranged | ['(2, 4)'] |
| 822 | move | (2, 6) |
| 823 | pass | _on_pass_turn_pressed |
| 824 | card | quick_stab |
| 825 | melee | ['(2, 7)'] |
| 826 | move | (2, 5) |
| 827 | card | dull_bolt |
| 828 | ranged | ['(2, 4)'] |
| 829 | card | pale_spark |
| 830 | ranged | ['(3, 5)'] |
| 831 | move | (1, 5) |
| 832 | ui | SKIP & RECOVER  +3 HP   9667 → 9670 |
| 833 | map_room | ['(10, -5)'] |
| 834 | side_map |  |
| 835 | ui | Browse wares |
| 836 | ui | GearOffer_doppel_doll |
| 837 | ui | Buy · 150 Embers |
| 838 | ui | Leave |
| 839 | map_room | ['(10, 0)'] |

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1551 -> 2254)

Source: `res://tools/run_hunt.gd:258`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 2744 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-9-2744-1793840127098818000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2724 | card | hamstring_shot |
| 2725 | move | ['(7, 3)'] |
| 2726 | card | grave_dust_satchel |
| 2727 | aoe | ['(6, 3)'] |
| 2728 | pass | _on_pass_turn_pressed |
| 2729 | move | (4, 3) |
| 2730 | card | bloody_lunge |
| 2731 | move | ['(4, 4)'] |
| 2732 | card | shadow_step |
| 2733 | blink | ['(2, 3)'] |
| 2734 | card | waning_pulse |
| 2735 | confirm_card | _on_confirm_card_play_pressed |
| 2736 | move | (6, 1) |
| 2737 | card | guarded_step |
| 2738 | move | ['(6, 2)'] |
| 2739 | card | sidestep_slash |
| 2740 | move | ['(7, 2)'] |
| 2741 | card | pale_spark |
| 2742 | ranged | ['(7, 3)'] |
| 2743 | ui | CONTINUE |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2762)

Source: `res://tools/run_hunt.gd:258`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 2446 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-12-2446-1793840127098834000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2426 | surface | ['(4, 2)'] |
| 2427 | card | lantern_shot |
| 2428 | ranged | ['(1, 2)'] |
| 2429 | card | dull_bolt |
| 2430 | ranged | ['(3, 2)'] |
| 2431 | move | (2, 2) |
| 2432 | move | (2, 1) |
| 2433 | card | pale_spark |
| 2434 | ranged | ['(3, 2)'] |
| 2435 | card | sidestep_slash |
| 2436 | move | ['(3, 2)'] |
| 2437 | move | (4, 1) |
| 2438 | card | quick_stab |
| 2439 | melee | ['(6, 2)'] |
| 2440 | move | (5, 4) |
| 2441 | card | patch_up |
| 2442 | confirm_card | _on_confirm_card_play_pressed |
| 2443 | card | hamstring_shot |
| 2444 | move | ['(5, 5)'] |
| 2445 | ui | CONTINUE |

### 9. leak: tree_nodes grew more than 25% from section 0 to section 5 (1555 -> 2812)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2327 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-5-2327-1793840127098851000
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
| 0 | 10 |
| 1 | 5 |
| 2 | 4 |
| 3 | 4 |
| 4 | 3 |
| 5 | 3 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 22 |
| campfire | 29 |
| combat | 109 |
| dragon | 22 |
| ember_hoarder | 4 |
| event | 54 |
| graftwright | 6 |
| guardian | 9 |
| hoarder | 4 |
| last_light | 4 |
| scavenger | 29 |
| snare | 5 |
| start | 29 |
| treasure | 33 |
| umbral_snare | 5 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
