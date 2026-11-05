# Run hunt — November 2026

Runs started: 10; processes ended: 10; completed runs: 9 (victory 2, defeat 0, Embrace 7).
Wall clock: 54.96 minutes. Seed base 4; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 2 | 4 | 1 / campfire | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| script error | 26 | 4 | 0 / combat | SCRIPT ERROR: Trying to assign invalid previously freed instance. — /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd:42 |
| script error | 10 | 4 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 13 | 3 / combat | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 9 | 5 / boss | WARNING: ObjectDB instances leaked at exit (run with --verbose for details). — core/object/object.cpp:2641 |
| warning | 1 | 5 | 3 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 11 | 0 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 9 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_coffin_nails, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 5 | 4 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 12 | 2 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 13 | 1 / treasure | WARNING: Relic glossary above-row overflow: RelicChoice_tailwind_fletching, viewport=(1920.0, 1920.0), block=(942.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 9 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1558 -> 2308) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2872) — res://tools/run_hunt.gd:258 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 4, 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 788 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-788-1793856972367923000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 768 | card | pale_spark |
| 769 | ranged | ['(3, 5)'] |
| 770 | move | (3, 7) |
| 771 | move | (2, 7) |
| 772 | card | dull_bolt |
| 773 | ranged | ['(1, 6)'] |
| 774 | card | sidestep_slash |
| 775 | move | ['(1, 7)'] |
| 776 | card | bloody_lunge |
| 777 | move | ['(2, 6)'] |
| 778 | card | waning_pulse |
| 779 | confirm_card | _on_confirm_card_play_pressed |
| 780 | move | (2, 7) |
| 781 | move | (2, 6) |
| 782 | card | waning_pulse |
| 783 | confirm_card | _on_confirm_card_play_pressed |
| 784 | ui | SKIP & RECOVER  +3 HP   9593 → 9596 |
| 785 | map_room | ['(6, 7)'] |
| 786 | side_escape |  |
| 787 | ui | @PanelContainer@99494 |

### 2. script error: SCRIPT ERROR: Trying to assign invalid previously freed instance.

Source: `/private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd:42`. Seeds: 4, 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 47 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-47-1793856972367953000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 27 | card | dull_bolt |
| 28 | ranged | ['(3, 3)'] |
| 29 | move | (1, 3) |
| 30 | move | (2, 3) |
| 31 | card | hamstring_shot |
| 32 | move | ['(2, 5)'] |
| 33 | move | (2, 3) |
| 34 | card | shadow_step |
| 35 | blink | ['(4, 4)'] |
| 36 | card | quick_stab |
| 37 | melee | ['(4, 3)'] |
| 38 | ui | SKIP & RECOVER  +3 HP   9982 → 9985 |
| 39 | map_room | ['(1, 2)'] |
| 40 | equipment | _on_pre_battle_equip_pressed |
| 41 | ui | CloseCharacterOverlay |
| 42 | begin_combat | _on_pre_battle_start_pressed |
| 43 | move | (2, 1) |
| 44 | card | whirlwind_slash |
| 45 | confirm_card | _on_confirm_card_play_pressed |
| 46 | card | patch_up |

### 3. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 4, 5, 6, 7, 8, 9, 10, 11, 12, 13.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-4-1-1793856972367974000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 4. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 13.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 13 --runs 1 --processes 1 --stop-after 2117 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-13-2117-1793856972367980000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2097 | confirm_card | _on_confirm_card_play_pressed |
| 2098 | move | (3, 5) |
| 2099 | card | hamstring_shot |
| 2100 | move | ['(4, 5)'] |
| 2101 | card | sidestep_slash |
| 2102 | move | ['(3, 6)'] |
| 2103 | move | (5, 6) |
| 2104 | card | pale_spark |
| 2105 | ranged | ['(5, 5)'] |
| 2106 | card | waning_pulse |
| 2107 | confirm_card | _on_confirm_card_play_pressed |
| 2108 | move | (5, 5) |
| 2109 | move | (5, 6) |
| 2110 | move | (5, 5) |
| 2111 | move | (4, 5) |
| 2112 | card | pale_spark |
| 2113 | ranged | ['(5, 4)'] |
| 2114 | card | brace |
| 2115 | confirm_card | _on_confirm_card_play_pressed |
| 2116 | move | (2, 5) |

### 5. warning: WARNING: ObjectDB instances leaked at exit (run with --verbose for details).

Source: `core/object/object.cpp:2641`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 3485 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-9-3485-1793856972367996000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 3465 | ranged | ['(6, 3)'] |
| 3466 | card | lantern_shot |
| 3467 | ranged | ['(6, 4)'] |
| 3468 | move | (5, 3) |
| 3469 | card | dull_bolt |
| 3470 | ranged | ['(4, 2)'] |
| 3471 | move | (5, 5) |
| 3472 | pass | _on_pass_turn_pressed |
| 3473 | card | hamstring_shot |
| 3474 | move | ['(6, 7)'] |
| 3475 | card | flash_powder |
| 3476 | aoe | ['(6, 4)'] |
| 3477 | move | (6, 6) |
| 3478 | move | (6, 5) |
| 3479 | card | waning_pulse |
| 3480 | confirm_card | _on_confirm_card_play_pressed |
| 3481 | move | (6, 4) |
| 3482 | card | quick_stab |
| 3483 | melee | ['(6, 2)'] |
| 3484 | ui | COMPLETE ASCENT |

### 6. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1624 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-5-1624-1793856972368012000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 7. warning: WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 11.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 11 --runs 1 --processes 1 --stop-after 118 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-11-118-1793856972368032000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 8. warning: WARNING: Relic glossary above-row overflow: RelicChoice_coffin_nails, viewport=(1920.0, 1920.0), block=(942.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 724 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-9-724-1793856972368048000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 9. warning: WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1972 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-5-1972-1793856972368065000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 10. warning: WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 840 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-12-840-1793856972368082000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 11. warning: WARNING: Relic glossary above-row overflow: RelicChoice_tailwind_fletching, viewport=(1920.0, 1920.0), block=(942.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 13.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 13 --runs 1 --processes 1 --stop-after 644 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-13-644-1793856972368098000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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

### 12. leak: tree_nodes grew more than 25% from section 0 to section 5 (1558 -> 2308)

Source: `res://tools/run_hunt.gd:258`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 2743 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-9-2743-1793856972368116000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2723 | card | hamstring_shot |
| 2724 | move | ['(7, 3)'] |
| 2725 | card | grave_dust_satchel |
| 2726 | aoe | ['(6, 3)'] |
| 2727 | pass | _on_pass_turn_pressed |
| 2728 | move | (4, 3) |
| 2729 | card | bloody_lunge |
| 2730 | move | ['(4, 4)'] |
| 2731 | card | shadow_step |
| 2732 | blink | ['(2, 3)'] |
| 2733 | card | waning_pulse |
| 2734 | confirm_card | _on_confirm_card_play_pressed |
| 2735 | move | (6, 1) |
| 2736 | card | guarded_step |
| 2737 | move | ['(6, 2)'] |
| 2738 | card | sidestep_slash |
| 2739 | move | ['(7, 2)'] |
| 2740 | card | pale_spark |
| 2741 | ranged | ['(7, 3)'] |
| 2742 | ui | CONTINUE |

### 13. leak: tree_nodes grew more than 25% from section 0 to section 5 (1562 -> 2872)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-45/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2327 --output-dir /private/tmp/labyrinth_codex/qa-45/replay-5-2327-1793856972368131000 --script /private/tmp/labyrinth_codex/qa-45/run_hunt_observed.gd
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
| 1 | 7 |
| 2 | 5 |
| 3 | 4 |
| 4 | 2 |
| 5 | 2 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 22 |
| campfire | 29 |
| combat | 104 |
| dragon | 22 |
| ember_hoarder | 4 |
| event | 63 |
| graftwright | 7 |
| guardian | 11 |
| hoarder | 4 |
| last_light | 5 |
| scavenger | 29 |
| snare | 4 |
| start | 30 |
| treasure | 34 |
| umbral_snare | 4 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
