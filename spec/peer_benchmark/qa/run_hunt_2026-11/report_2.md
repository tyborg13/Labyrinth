# Run hunt — November 2026, second campaign

Runs started: 9; processes ended: 9; completed runs: 5 (victory 5, defeat 0, Embrace 0).
Wall clock: 77.00 minutes. Seed base 101; at most 2 concurrent Godot processes; stop launching after 60 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 1 | 101 | 2 / combat | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| softlock | 1 | 101 | 2 / combat | Fight state unchanged for 50 consecutive decisions — res://tools/run_hunt.gd:258 |
| script error | 9 | 101 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 4 | 102 | 2 / warband | ERROR: Parameter "t" is null. — res://scripts/asset_loader.gd:628 |
| script error | 1 | 101 | 0 / combat | SCRIPT ERROR: Trying to cast a freed object. — res://scripts/run_scene.gd:13198 |
| warning | 2 | 104 | 0 / start | Harness stop (initial merchant browse guard): Screen exceeded 120 decisions — res://tools/run_hunt.gd:258 |
| warning | 1 | 108 | 2 / umbral_snare | Fight exploration budget reached 400 decisions — res://tools/run_hunt.gd:258 |
| leak | 1 | 106 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7648) — res://tools/run_hunt.gd:258 |
| leak | 1 | 103 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1545 -> 6531) — res://tools/run_hunt.gd:258 |
| leak | 1 | 109 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1550 -> 6653) — res://tools/run_hunt.gd:258 |
| leak | 1 | 107 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1553 -> 6548) — res://tools/run_hunt.gd:258 |
| leak | 1 | 102 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1554 -> 5617) — res://tools/run_hunt.gd:258 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 101.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 101 --runs 1 --processes 1 --stop-after 640 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-101-640-1793594106386226000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 620 | move | (6, 3) |
| 621 | move | (5, 5) |
| 622 | move | (5, 2) |
| 623 | move | (7, 3) |
| 624 | move | (5, 4) |
| 625 | move | (5, 4) |
| 626 | move | (4, 3) |
| 627 | move | (5, 4) |
| 628 | move | (4, 3) |
| 629 | move | (6, 3) |
| 630 | move | (4, 3) |
| 631 | move | (4, 3) |
| 632 | move | (5, 5) |
| 633 | move | (6, 2) |
| 634 | move | (6, 2) |
| 635 | move | (7, 3) |
| 636 | move | (5, 2) |
| 637 | move | (5, 5) |
| 638 | move | (4, 4) |
| 639 | move | (6, 2) |

### 2. softlock: Fight state unchanged for 50 consecutive decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 101.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 101 --runs 1 --processes 1 --stop-after 640 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-101-640-1793594106386246000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 620 | move | (6, 3) |
| 621 | move | (5, 5) |
| 622 | move | (5, 2) |
| 623 | move | (7, 3) |
| 624 | move | (5, 4) |
| 625 | move | (5, 4) |
| 626 | move | (4, 3) |
| 627 | move | (5, 4) |
| 628 | move | (4, 3) |
| 629 | move | (6, 3) |
| 630 | move | (4, 3) |
| 631 | move | (4, 3) |
| 632 | move | (5, 5) |
| 633 | move | (6, 2) |
| 634 | move | (6, 2) |
| 635 | move | (7, 3) |
| 636 | move | (5, 2) |
| 637 | move | (5, 5) |
| 638 | move | (4, 4) |
| 639 | move | (6, 2) |

### 3. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 101, 102, 103, 104, 105, 106, 107, 108, 109.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 101 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-101-1-1793594106386257000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 4. script error: ERROR: Parameter "t" is null.

Source: `res://scripts/asset_loader.gd:628`. Seeds: 102.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 102 --runs 1 --processes 1 --stop-after 1212 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-102-1212-1793594106386262000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1192 | confirm_card | _on_confirm_card_play_pressed |
| 1193 | card | pale_spark |
| 1194 | ranged | ['(7, 5)'] |
| 1195 | card | dull_bolt |
| 1196 | ranged | ['(7, 4)'] |
| 1197 | move | (5, 4) |
| 1198 | card | brace |
| 1199 | confirm_card | _on_confirm_card_play_pressed |
| 1200 | move | (5, 5) |
| 1201 | move | (7, 5) |
| 1202 | card | waning_pulse |
| 1203 | confirm_card | _on_confirm_card_play_pressed |
| 1204 | card | hamstring_shot |
| 1205 | move | ['(7, 5)'] |
| 1206 | card | riposte_lunge |
| 1207 | move | ['(7, 3)'] |
| 1208 | card | bodkin_arrow |
| 1209 | melee | ['(7, 2)'] |
| 1210 | move | (6, 3) |
| 1211 | move | (6, 2) |

### 5. script error: SCRIPT ERROR: Trying to cast a freed object.

Source: `res://scripts/run_scene.gd:13198`. Seeds: 101.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 101 --runs 1 --processes 1 --stop-after 188 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-101-188-1793594106386276000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 168 | ui | SkillNode_last_door |
| 169 | ui | SkillNode_true_bearing |
| 170 | ui | SkillNode_last_door |
| 171 | ui | SkillNode_borrowed_time |
| 172 | ui | SkillNode_salvager |
| 173 | leave_browse | _on_progression_overlay_close_pressed |
| 174 | map_room | ['(-2, 1)'] |
| 175 | side_map |  |
| 176 | ui | RelicChoice_anchor_chain |
| 177 | map_room | ['(-2, -2)'] |
| 178 | map_room | ['(-2, -2)'] |
| 179 | map_room | ['(-1, -2)'] |
| 180 | side_escape |  |
| 181 | begin_combat | _on_pre_battle_start_pressed |
| 182 | card | sidestep_slash |
| 183 | move | ['(4, 3)'] |
| 184 | card | bloody_lunge |
| 185 | move | ['(4, 3)'] |
| 186 | move | (4, 4) |
| 187 | move | (5, 4) |

### 6. warning: Harness stop (initial merchant browse guard): Screen exceeded 120 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 104, 105.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 104 --runs 1 --processes 1 --stop-after 123 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-104-123-1793594106386290000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 103 | leave_browse | _on_merchant_hide_pressed |
| 104 | leave_browse | _on_merchant_hide_pressed |
| 105 | leave_browse | _on_merchant_hide_pressed |
| 106 | leave_browse | _on_merchant_hide_pressed |
| 107 | leave_browse | _on_merchant_hide_pressed |
| 108 | leave_browse | _on_merchant_hide_pressed |
| 109 | leave_browse | _on_merchant_hide_pressed |
| 110 | leave_browse | _on_merchant_hide_pressed |
| 111 | leave_browse | _on_merchant_hide_pressed |
| 112 | leave_browse | _on_merchant_hide_pressed |
| 113 | leave_browse | _on_merchant_hide_pressed |
| 114 | leave_browse | _on_merchant_hide_pressed |
| 115 | leave_browse | _on_merchant_hide_pressed |
| 116 | leave_browse | _on_merchant_hide_pressed |
| 117 | leave_browse | _on_merchant_hide_pressed |
| 118 | leave_browse | _on_merchant_hide_pressed |
| 119 | leave_browse | _on_merchant_hide_pressed |
| 120 | leave_browse | _on_merchant_hide_pressed |
| 121 | leave_browse | _on_merchant_hide_pressed |
| 122 | leave_browse | _on_merchant_hide_pressed |

### 7. warning: Fight exploration budget reached 400 decisions

Source: `res://tools/run_hunt.gd:258`. Seeds: 108.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 108 --runs 1 --processes 1 --stop-after 1507 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-108-1507-1793594106386303000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1487 | blink | ['(5, 7)'] |
| 1488 | card | guarded_step |
| 1489 | move | ['(7, 7)'] |
| 1490 | pass | _on_pass_turn_pressed |
| 1491 | card | storm_beacon |
| 1492 | ranged | ['(7, 4)'] |
| 1493 | card | bloody_lunge |
| 1494 | move | ['(7, 6)'] |
| 1495 | move | (6, 5) |
| 1496 | card | hamstring_shot |
| 1497 | move | ['(7, 6)'] |
| 1498 | move | (7, 7) |
| 1499 | move | (6, 7) |
| 1500 | pass | _on_pass_turn_pressed |
| 1501 | card | sidestep_slash |
| 1502 | move | ['(5, 7)'] |
| 1503 | move | (4, 7) |
| 1504 | move | (3, 7) |
| 1505 | card | brace |
| 1506 | confirm_card | _on_confirm_card_play_pressed |

### 8. leak: tree_nodes grew more than 25% from section 0 to section 5 (1542 -> 7648)

Source: `res://tools/run_hunt.gd:258`. Seeds: 106.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 106 --runs 1 --processes 1 --stop-after 2780 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-106-2780-1793594106386314000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2760 | move | (4, 2) |
| 2761 | card | brace |
| 2762 | confirm_card | _on_confirm_card_play_pressed |
| 2763 | move | (3, 2) |
| 2764 | move | (3, 4) |
| 2765 | card | riposte_lunge |
| 2766 | move | ['(3, 3)'] |
| 2767 | pass | _on_pass_turn_pressed |
| 2768 | card | bodkin_arrow |
| 2769 | melee | ['(4, 4)'] |
| 2770 | card | patch_up |
| 2771 | confirm_card | _on_confirm_card_play_pressed |
| 2772 | move | (2, 2) |
| 2773 | card | ice_sculpture |
| 2774 | illusion | ['(2, 1)'] |
| 2775 | move | (2, 4) |
| 2776 | card | hamstring_shot |
| 2777 | move | ['(2, 3)'] |
| 2778 | pass | _on_pass_turn_pressed |
| 2779 | ui | CONTINUE |

### 9. leak: tree_nodes grew more than 25% from section 0 to section 5 (1545 -> 6531)

Source: `res://tools/run_hunt.gd:258`. Seeds: 103.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 103 --runs 1 --processes 1 --stop-after 2406 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-103-2406-1793594106386325000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2386 | card | quick_stab |
| 2387 | melee | ['(6, 5)'] |
| 2388 | card | pale_spark |
| 2389 | ranged | ['(6, 6)'] |
| 2390 | pass | _on_pass_turn_pressed |
| 2391 | pass | _on_pass_turn_pressed |
| 2392 | card | bloody_lunge |
| 2393 | move | ['(4, 5)'] |
| 2394 | card | dull_bolt |
| 2395 | ranged | ['(6, 6)'] |
| 2396 | move | (4, 4) |
| 2397 | pass | _on_pass_turn_pressed |
| 2398 | card | waning_pulse |
| 2399 | confirm_card | _on_confirm_card_play_pressed |
| 2400 | card | dull_bolt |
| 2401 | ranged | ['(7, 4)'] |
| 2402 | move | (5, 4) |
| 2403 | move | (5, 3) |
| 2404 | pass | _on_pass_turn_pressed |
| 2405 | ui | CONTINUE |

### 10. leak: tree_nodes grew more than 25% from section 0 to section 5 (1550 -> 6653)

Source: `res://tools/run_hunt.gd:258`. Seeds: 109.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 109 --runs 1 --processes 1 --stop-after 2196 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-109-2196-1793594106386337000 --no-embrace
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2176 | card | sidestep_slash |
| 2177 | move | ['(2, 3)'] |
| 2178 | card | glacier_salts |
| 2179 | surface | ['(2, 5)'] |
| 2180 | move | (3, 3) |
| 2181 | move | (3, 5) |
| 2182 | move | (4, 5) |
| 2183 | card | lantern_shot |
| 2184 | ranged | ['(5, 4)'] |
| 2185 | card | quick_stab |
| 2186 | melee | ['(5, 3)'] |
| 2187 | move | (6, 7) |
| 2188 | move | (2, 2) |
| 2189 | card | bloody_lunge |
| 2190 | move | ['(3, 4)'] |
| 2191 | card | guarded_step |
| 2192 | move | ['(3, 3)'] |
| 2193 | card | whirlwind_slash |
| 2194 | confirm_card | _on_confirm_card_play_pressed |
| 2195 | ui | CONTINUE |

### 11. leak: tree_nodes grew more than 25% from section 0 to section 5 (1553 -> 6548)

Source: `res://tools/run_hunt.gd:258`. Seeds: 107.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 107 --runs 1 --processes 1 --stop-after 2538 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-107-2538-1793594106386347000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_merchant_fixed.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2518 | card | lantern_shot |
| 2519 | ranged | ['(2, 6)'] |
| 2520 | card | crack_the_whip |
| 2521 | melee | ['(2, 5)'] |
| 2522 | move | (2, 4) |
| 2523 | pass | _on_pass_turn_pressed |
| 2524 | pass | _on_pass_turn_pressed |
| 2525 | card | lash |
| 2526 | pull | ['(2, 5)'] |
| 2527 | card | hamstring_shot |
| 2528 | move | ['(2, 4)'] |
| 2529 | move | (2, 3) |
| 2530 | move | (2, 4) |
| 2531 | card | sidestep_slash |
| 2532 | move | ['(2, 2)'] |
| 2533 | move | (2, 1) |
| 2534 | move | (2, 2) |
| 2535 | card | dull_bolt |
| 2536 | ranged | ['(2, 6)'] |
| 2537 | ui | CONTINUE |

### 12. leak: tree_nodes grew more than 25% from section 0 to section 5 (1554 -> 5617)

Source: `res://tools/run_hunt.gd:258`. Seeds: 102.

Replay from a fresh profile to this decision (the full context and trace are retained in `/private/tmp/labyrinth_codex/qa-18/report_2.findings.json`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-18 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 102 --runs 1 --processes 1 --stop-after 2335 --output-dir /private/tmp/labyrinth_codex/qa-18/replay-102-2335-1793594106386357000 --no-embrace --script /private/tmp/labyrinth_codex/qa-18/run_hunt_campaign_initial.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2315 | move | (3, 3) |
| 2316 | card | riposte_lunge |
| 2317 | move | ['(3, 2)'] |
| 2318 | card | dull_bolt |
| 2319 | ranged | ['(5, 3)'] |
| 2320 | pass | _on_pass_turn_pressed |
| 2321 | card | hamstring_shot |
| 2322 | move | ['(1, 3)'] |
| 2323 | move | (1, 5) |
| 2324 | card | patch_up |
| 2325 | confirm_card | _on_confirm_card_play_pressed |
| 2326 | move | (2, 5) |
| 2327 | card | dull_bolt |
| 2328 | ranged | ['(3, 5)'] |
| 2329 | move | (1, 3) |
| 2330 | card | pale_spark |
| 2331 | ranged | ['(5, 2)'] |
| 2332 | card | battle_rhythm |
| 2333 | confirm_card | _on_confirm_card_play_pressed |
| 2334 | ui | CONTINUE |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 9 |
| 1 | 7 |
| 2 | 7 |
| 3 | 5 |
| 4 | 5 |
| 5 | 5 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 34 |
| campfire | 34 |
| combat | 135 |
| dragon | 34 |
| ember_hoarder | 3 |
| event | 66 |
| graftwright | 3 |
| guardian | 22 |
| hoarder | 3 |
| last_light | 6 |
| scavenger | 31 |
| snare | 5 |
| start | 38 |
| treasure | 38 |
| umbral_snare | 5 |
| warband | 3 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.

## Campaign interpretation

All six sections reached: **YES**. Completed-process traces contain 17,212 decisions. No recurrence of the committed-plan invalid-index error was observed. No Embrace outcome occurred. The last launch was at 3,455.95 seconds, below the 3,600-second cap; interval auditing observed a peak of two processes. Active seeds drained to 77.00 minutes.

The crash row is a nonzero runner scan after native Godot exit 0, not a native crash. The freed-object cast is in the existing turn-order dissolve. The null-texture errors come from the dummy headless rendering backend through `texture_source_image`; no windowed inference is made. The node-growth rows are threshold flags, not confirmed leaks; endpoint orphan counts remain in the raw room samples. New gameplay/rendering findings remain unfixed for director triage.

The initial merchant-browse guard used a persistent shop-open flag without verifying a merchant room. Seeds 104 and 105 repeatedly dispatched Leave in the start room and hit the generic screen budget. These two verified harness stops are classified as warnings here, not player softlocks. The raw evidence is unchanged. The guard was corrected to require a real merchant kind; seeds 101–106 loaded the initial policy, and seed 107 uses the merchant-corrected policy. A later completeness audit also excluded the actual desktop-exit menu callback for seeds 108 onward; no desktop-exit dispatch had occurred. All three policy versions and exact replay drivers are retained. Both versions and the cutover timestamp/hashes are retained in `/private/tmp/labyrinth_codex/qa-18/campaign-policy-correction.json`. Replays of findings in the initial cohort explicitly use the retained initial driver.

A prior two-seed attempt was interrupted by task continuation before either process finished; its partial evidence is retained in `whole-runs/` and excluded from this campaign. This campaign retains the original seed-101 start and 60-minute launch deadline across the merchant-guard correction.

The unchanged-fight detector compares the settled combat-state dictionary across consecutive fight decisions; browse decisions are excluded. A flag shows a bot making no combat-state progress, and does not by itself prove a human cannot recover. Reaching the 400-decision exploration budget is a warning, not a softlock. Browse exits cover loadout/skills, piles, grimoire, settings/menu, purge, merchants and Graftwright.

## Stale-plan investigation and repair

**Yes: this produced wrong player-facing behaviour, beyond logging an error.** The stored `enemy_index` was read at all six cited sites in `current_plan`. Its in-range case borrowed another living enemy's body for warning geometry or live-body replanning. Its out-of-range case aborted the plan function, leaving missing warning data.

One correction to the director's reading: ordinary combat does **not** remove the dead enemy from its real enemy array. `is_enemy_visible_to_player` excludes dead enemies, and `RunScene._surface_preview_information_state` filters them (and concealed enemies) out before forecasting whenever sight is limited. That information-safe copy shifts the remaining indices. The production filter was exercised directly: after killing enemy 1, the copy contained two enemies with enemy 2 at index 0. The original combat still held the dead enemy at index 0. Concealing an earlier living enemy can cause the same positional mismatch.

The deterministic regression commits plans for three enemies, kills the first through the production damage function, and checks the second both before and after removing the dead entry in a forecast copy. Test-only positions are enemy 1 `(7,7)`, enemy 2 `(4,2)`, enemy 3 `(7,6)`, hero `(4,5)`. The third body has Charge 2 to expose borrowing the wrong body's status-dependent range. The test intent has Move 2 followed by a one-tile committed line for 3 damage. Both held-path and `live_body` variants are checked, including legacy saved indices, the last shifted enemy's out-of-range threat, and absence of a dead/removed actor's plan.

| Scenario | Correct second-enemy warning | Base warning after filtering | Real second-enemy turn on base and fix |
|---|---|---|---|
| Held path | `(4,5)` | `(4,5), (4,6), (4,7)` | Moves to `(4,4)`; hero HP 24 → 21 |
| Live body | `(4,5)` | `(6,6), (6,7)` | Moves to `(4,4)`; hero HP 24 → 21 |

A player could see an overlong warning, or a warning away from the hero while the real enemy still hit the hero's tile. The real unfiltered turn retains matching array positions and passes its current index to `_resolve_enemy_action`; it did not activate the third enemy in this scenario. Calling real turn resolution on the compacted test copy also retained the expected second-enemy movement and damage. These observations establish wrong previews, without claiming a wrong real actor was observed.

The repair resolves the supplied enemy's stable ID in the current snapshot and rejects dead/absent bodies before planning. New committed plans store `enemy_id` rather than an array position; legacy indices are ignored. Returned plans receive only the current index, and private action replay reacquires the same ID after each action. The audit found no other reads of a stored plan's `enemy_index`: combat-engine activation paths pass their current actor index, while Guardian coordination reads stored geometry only. No change to combat_engine.gd was necessary. Declared geometry, movement replay, RNG, actions, timing, damage, Guardian data, analytics emitters and saves' existing actor IDs are unchanged.

## Focused validation and outcome comparison

- Base regression: `QA18 REGRESSION: FAIL (20 checks, 15 failures)`, with an invalid-index script error and the wrong in-range warnings above.
- Fixed regression: `QA18 REGRESSION: PASS (20 checks, 0 failures)`.
- Focused existing combat suites: `QA18 FOCUSED COMBAT: PASS (704 checks, 0 failures)`; registered entry point: `GUARDIAN RULES TEST RESULT: PASS (381 checks, 0 failures)`. Both exited 0 on the final source. The standalone fixed regression took 3.896 seconds including startup.
- Python default input group: `Ran 178 tests in 30.721s`, `OK`. No full Python or Godot suites were run.
- Existing encounter-policy hash check: `ENCOUNTER POLICY HASH: PASS c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`.
- Paired bounded encounter CLI batch: 8 revision-7 standard/tier-1 rooms from seeds 101–102 (seed 101's six sections and seed 102's first two). **0 changed records and 0 changed outcomes**; 7 victories and 1 defeat on both sides. Every result field matched. Neither batch logged a script error. These whole-combat measurements retain real enemy arrays; they do not reproduce the information-filter mismatch. No outcome exception was needed.

Raw regression, batch, parser and Python proofs are retained under `/private/tmp/labyrinth_codex/qa-18/`; details and exact commands are in [validation_2.md](validation_2.md). No windowed Godot, captures, full suites or peer review were run. All changes remain uncommitted for the design owner.
