# Run hunt — November 2026

Runs started: 9; processes ended: 9; completed runs: 8 (victory 1, defeat 0, Embrace 7).
Wall clock: 54.55 minutes. Seed base 4; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 9 | 4 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 1 | 10 | 1 / event | ERROR: Parameter "t" is null. — /servers/rendering/dummy/storage/texture_storage.h:84 |
| warning | 1 | 9 | 1 / umbral_snare | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 5 | 3 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 11 | 0 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 5 | 4 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 12 | 2 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1580 -> 2890) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 4, 5, 6, 7, 8, 9, 10, 11, 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-4-1-1793894856035184000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. script error: ERROR: Parameter "t" is null.

Source: `/servers/rendering/dummy/storage/texture_storage.h:84`. Seeds: 10.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 10 --runs 1 --processes 1 --stop-after 774 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-10-774-1793894856035199000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 754 | pass | _on_pass_turn_pressed |
| 755 | card | lantern_shot |
| 756 | ranged | ['(1, 6)'] |
| 757 | card | brace |
| 758 | confirm_card | _on_confirm_card_play_pressed |
| 759 | card | waning_pulse |
| 760 | confirm_card | _on_confirm_card_play_pressed |
| 761 | move | (2, 5) |
| 762 | move | (2, 6) |
| 763 | move | (2, 5) |
| 764 | card | quick_stab |
| 765 | melee | ['(2, 4)'] |
| 766 | card | sidestep_slash |
| 767 | move | ['(3, 6)'] |
| 768 | pass | _on_pass_turn_pressed |
| 769 | ui | RelicChoice_resonant_clapper |
| 770 | map_room | ['(7, -2)'] |
| 771 | ui | Choice3 |
| 772 | ui | Continue |
| 773 | map_room | ['(7, 3)'] |

### 3. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 9.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 9 --runs 1 --processes 1 --stop-after 1134 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-9-1134-1793894856035225000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1114 | pass | _on_pass_turn_pressed |
| 1115 | pass | _on_pass_turn_pressed |
| 1116 | pass | _on_pass_turn_pressed |
| 1117 | pass | _on_pass_turn_pressed |
| 1118 | pass | _on_pass_turn_pressed |
| 1119 | pass | _on_pass_turn_pressed |
| 1120 | pass | _on_pass_turn_pressed |
| 1121 | pass | _on_pass_turn_pressed |
| 1122 | pass | _on_pass_turn_pressed |
| 1123 | pass | _on_pass_turn_pressed |
| 1124 | pass | _on_pass_turn_pressed |
| 1125 | pass | _on_pass_turn_pressed |
| 1126 | pass | _on_pass_turn_pressed |
| 1127 | pass | _on_pass_turn_pressed |
| 1128 | pass | _on_pass_turn_pressed |
| 1129 | pass | _on_pass_turn_pressed |
| 1130 | pass | _on_pass_turn_pressed |
| 1131 | pass | _on_pass_turn_pressed |
| 1132 | pass | _on_pass_turn_pressed |
| 1133 | pass | _on_pass_turn_pressed |

### 4. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1624 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-1624-1793894856035245000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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

### 5. warning: WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 11.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 11 --runs 1 --processes 1 --stop-after 118 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-11-118-1793894856035269000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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

### 6. warning: WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1972 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-1972-1793894856035289000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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

### 7. warning: WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 846 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-12-846-1793894856035310000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 826 | melee | ['(2, 7)'] |
| 827 | move | (2, 5) |
| 828 | card | dull_bolt |
| 829 | ranged | ['(2, 4)'] |
| 830 | card | pale_spark |
| 831 | ranged | ['(3, 5)'] |
| 832 | move | (1, 5) |
| 833 | ui | SKIP & RECOVER  +3 HP   9667 → 9670 |
| 834 | map_room | ['(10, -5)'] |
| 835 | side_map |  |
| 836 | ui | Browse wares |
| 837 | ui | GearOffer_doppel_doll |
| 838 | ui | Buy · 150 Embers |
| 839 | ui | GearOffer_hobnail_grips |
| 840 | ui | GearOffer_sawtooth_knife |
| 841 | ui | ItemOffer_bone_ward_charm |
| 842 | ui | GearOffer_hobnail_grips |
| 843 | ui | › |
| 844 | leave_browse | _on_merchant_hide_pressed |
| 845 | map_room | ['(10, 0)'] |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1580 -> 2890)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2327 --output-dir /private/tmp/labyrinth_codex/qa-56/replay-5-2327-1793894856035330000 --script /private/tmp/labyrinth_codex/qa-56/run_hunt_cache_observed.gd
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
| 0 | 9 |
| 1 | 6 |
| 2 | 4 |
| 3 | 1 |
| 4 | 1 |
| 5 | 1 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 14 |
| campfire | 21 |
| combat | 71 |
| dragon | 14 |
| ember_hoarder | 3 |
| event | 47 |
| graftwright | 4 |
| guardian | 9 |
| hoarder | 3 |
| last_light | 4 |
| scavenger | 19 |
| snare | 3 |
| start | 22 |
| treasure | 24 |
| umbral_snare | 3 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
