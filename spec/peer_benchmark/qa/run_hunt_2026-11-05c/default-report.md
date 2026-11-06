# Run hunt — November 2026

Runs started: 9; processes ended: 9; completed runs: 9 (victory 1, defeat 0, Embrace 8).
Wall clock: 56.54 minutes. Seed base 4; at most 2 concurrent Godot processes; stop launching after 45 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: False. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 9 | 4 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 5 | 3 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 11 | 0 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_borrowed_hourglass, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 4 | 3 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_briar_vambrace, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 5 | 4 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| warning | 1 | 12 | 2 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_reinforced_shield, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 8 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1575 -> 2740) — res://tools/run_hunt.gd:258 |
| leak | 1 | 5 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1581 -> 2892) — res://tools/run_hunt.gd:258 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 4, 5, 6, 7, 8, 9, 10, 11, 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-4-1-1793918061407364000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: WARNING: Relic glossary above-row overflow: RelicChoice_ashen_phylactery, viewport=(1920.0, 1920.0), block=(1326.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1624 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-5-1624-1793918061407383000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
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
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 11 --runs 1 --processes 1 --stop-after 118 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-11-118-1793918061407416000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
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

### 4. warning: WARNING: Relic glossary above-row overflow: RelicChoice_briar_vambrace, viewport=(1920.0, 1920.0), block=(624.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 4.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 4 --runs 1 --processes 1 --stop-after 1346 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-4-1346-1793918061407441000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1326 | card | quick_stab |
| 1327 | melee | ['(3, 7)'] |
| 1328 | card | whirlwind_slash |
| 1329 | confirm_card | _on_confirm_card_play_pressed |
| 1330 | ui | SKIP & RECOVER  +3 HP   9901 → 9904 |
| 1331 | map_room | ['(13, -4)'] |
| 1332 | side_escape |  |
| 1333 | ui | Choice1 |
| 1334 | ui | Continue |
| 1335 | map_room | ['(14, -13)'] |
| 1336 | ui | Choice2 |
| 1337 | ui | Continue |
| 1338 | map_room | ['(14, -8)'] |
| 1339 | side_reduced_motion |  |
| 1340 | ui | Purge a spell |
| 1341 | ui | MagicDeckRow_pale_spark |
| 1342 | ui | Purge for 50 Embers |
| 1343 | ui | MagicDeckRow_icebound_chains |
| 1344 | ui | Leave |
| 1345 | map_room | ['(14, -2)'] |

### 5. warning: WARNING: Relic glossary above-row overflow: RelicChoice_copper_shod_staff, viewport=(1920.0, 1920.0), block=(1326.0, 109.0), top=1843.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 1972 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-5-1972-1793918061407464000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
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
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 12 --runs 1 --processes 1 --stop-after 846 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-12-846-1793918061407485000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
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

### 7. leak: tree_nodes grew more than 25% from section 0 to section 5 (1575 -> 2740)

Source: `res://tools/run_hunt.gd:258`. Seeds: 8.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 8 --runs 1 --processes 1 --stop-after 2699 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-8-2699-1793918061407509000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2679 | card | hamstring_shot |
| 2680 | move | ['(4, 3)'] |
| 2681 | move | (3, 3) |
| 2682 | card | dull_bolt |
| 2683 | ranged | ['(2, 4)'] |
| 2684 | move | (3, 2) |
| 2685 | card | waning_pulse |
| 2686 | confirm_card | _on_confirm_card_play_pressed |
| 2687 | move | (2, 2) |
| 2688 | move | (4, 3) |
| 2689 | card | dull_bolt |
| 2690 | ranged | ['(4, 4)'] |
| 2691 | card | lantern_shot |
| 2692 | ranged | ['(5, 5)'] |
| 2693 | move | (2, 5) |
| 2694 | card | pale_spark |
| 2695 | ranged | ['(2, 7)'] |
| 2696 | card | whirlwind_slash |
| 2697 | confirm_card | _on_confirm_card_play_pressed |
| 2698 | ui | CONTINUE |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1581 -> 2892)

Source: `res://tools/run_hunt.gd:258`. Seeds: 5.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --seed 5 --runs 1 --processes 1 --stop-after 2327 --output-dir /private/tmp/labyrinth_codex/qa-60/replay-5-2327-1793918061407527000 --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
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
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 4 | 2 |
| 5 | 2 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 17 |
| campfire | 25 |
| combat | 91 |
| dragon | 17 |
| ember_hoarder | 3 |
| event | 56 |
| graftwright | 4 |
| guardian | 6 |
| hoarder | 3 |
| last_light | 3 |
| scavenger | 22 |
| snare | 4 |
| start | 25 |
| treasure | 28 |
| umbral_snare | 4 |
| warband | 1 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
