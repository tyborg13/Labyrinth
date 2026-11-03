# Run hunt — November 2026

Runs started: 21; processes ended: 21; completed runs: 13 (victory 0, defeat 0, Embrace 13).
Wall clock: 76.91 minutes. Seed base 1; at most 2 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

Findings also include 1 separately verified replay(s); these do not inflate the campaign run totals or coverage below. Their exact private driver paths are preserved in replay commands.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| crash | 9 | 1 | 1 / boss | Godot runner exited 1 (native Godot exit 0; runner detected script errors) — process exit |
| softlock | 5 | 10 | 2 / combat | Fight exceeded 200 decisions — res://tools/run_hunt.gd:237 |
| softlock | 3 | 7 | 0 / combat | Screen exceeded 120 decisions — res://tools/run_hunt.gd:237 |
| script error | 62 | 1 | 1 / boss | SCRIPT ERROR: Invalid access of index '2' on a base object of type: 'Array'. — res://scripts/guardian_combat_rules.gd:222 |
| script error | 22 | 1 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| script error | 10 | 12 | 4 / last_light | SCRIPT ERROR: Invalid access of index '4' on a base object of type: 'Array'. — res://scripts/guardian_combat_rules.gd:222 |
| script error | 5 | 14 | 0 / combat | SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array'. — res://scripts/guardian_combat_rules.gd:222 |
| script error | 4 | 12 | 4 / last_light | SCRIPT ERROR: Invalid access of index '6' on a base object of type: 'Array'. — res://scripts/guardian_combat_rules.gd:222 |

### 1. crash: Godot runner exited 1 (native Godot exit 0; runner detected script errors)

Source: `process exit`. Seeds: 1, 8, 9, 10, 12, 14, 16, 17, 19.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 887 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-887-1793586370986180000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_prior.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 867 | move | (4, 2) |
| 868 | move | (4, 1) |
| 869 | card | waning_pulse |
| 870 | confirm_card | _on_confirm_card_play_pressed |
| 871 | card | pale_spark |
| 872 | ranged | ['(4, 3)'] |
| 873 | move | (4, 2) |
| 874 | card | dull_bolt |
| 875 | ranged | ['(5, 4)'] |
| 876 | pass | _on_pass_turn_pressed |
| 877 | card | quick_stab |
| 878 | melee | ['(5, 4)'] |
| 879 | card | lantern_shot |
| 880 | ranged | ['(4, 4)'] |
| 881 | move | (3, 2) |
| 882 | move | (3, 3) |
| 883 | card | hamstring_shot |
| 884 | move | ['(1, 4)'] |
| 885 | move | (3, 3) |
| 886 | card | waning_pulse |

### 2. softlock: Fight exceeded 200 decisions

Source: `res://tools/run_hunt.gd:237`. Seeds: 10, 12, 16, 18, 21.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 10 --runs 1 --processes 1 --stop-after 1615 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-10-1615-1793586370986214000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 1595 | card | bloody_lunge |
| 1596 | move | ['(6, 2)'] |
| 1597 | card | vacuum_line |
| 1598 | pull | ['(6, 1)'] |
| 1599 | move | (5, 2) |
| 1600 | move | (6, 2) |
| 1601 | move | (5, 3) |
| 1602 | card | pale_spark |
| 1603 | ranged | ['(6, 1)'] |
| 1604 | card | shadow_step |
| 1605 | blink | ['(7, 2)'] |
| 1606 | move | (6, 2) |
| 1607 | move | (5, 2) |
| 1608 | card | bloody_lunge |
| 1609 | move | ['(5, 1)'] |
| 1610 | card | guarded_step |
| 1611 | move | ['(5, 3)'] |
| 1612 | card | hamstring_shot |
| 1613 | move | ['(6, 2)'] |
| 1614 | card | brace |

### 3. softlock: Screen exceeded 120 decisions

Source: `res://tools/run_hunt.gd:237`. Seeds: 7, 8, 11.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 7 --runs 1 --processes 1 --stop-after 290 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-7-290-1793586370986236000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 270 | ui | SkillNode_last_reserve |
| 271 | ui | SkillNode_ghost_stride |
| 272 | ui | SkillNode_deferred_choice |
| 273 | ui | SkillNode_carry_the_guard |
| 274 | ui | SkillNode_borrowed_time |
| 275 | ui | SkillNode_makeshift_tool |
| 276 | ui | SkillNode_true_bearing |
| 277 | ui | SkillNode_sunpath |
| 278 | ui | SkillNode_long_dawn |
| 279 | ui | SkillNode_open_arsenal |
| 280 | ui | SkillNode_makeshift_tool |
| 281 | ui | SkillNode_confluence |
| 282 | ui | SkillNode_rehearsed_escape |
| 283 | ui | SkillNode_last_reserve |
| 284 | ui | SkillNode_living_shadow |
| 285 | ui | SkillNode_deferred_choice |
| 286 | ui | SkillNode_true_bearing |
| 287 | ui | SkillNode_last_reserve |
| 288 | ui | SkillNode_afterglow |
| 289 | ui | SkillNode_prismatic_instinct |

### 4. script error: SCRIPT ERROR: Invalid access of index '2' on a base object of type: 'Array'.

Source: `res://scripts/guardian_combat_rules.gd:222`. Seeds: 1, 8, 9, 10, 12, 16, 17, 19.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 865 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-865-1793586370986266000 --script /private/tmp/labyrinth_codex/qa-16/run_hunt_prior.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 845 | ui | Choice3 |
| 846 | ui | Continue |
| 847 | map_room | ['(3, 7)'] |
| 848 | ui | @PanelContainer@83652 |
| 849 | side_reduced_motion |  |
| 850 | map_room | ['(8, 0)'] |
| 851 | begin_combat | _on_pre_battle_start_pressed |
| 852 | card | bloody_lunge |
| 853 | move | ['(2, 4)'] |
| 854 | card | waning_pulse |
| 855 | confirm_card | _on_confirm_card_play_pressed |
| 856 | move | (2, 3) |
| 857 | move | (2, 4) |
| 858 | card | sidestep_slash |
| 859 | move | ['(2, 2)'] |
| 860 | move | (3, 3) |
| 861 | card | whirlwind_slash |
| 862 | confirm_card | _on_confirm_card_play_pressed |
| 863 | card | pale_spark |
| 864 | ranged | ['(2, 1)'] |

### 5. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 1 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-1-1-1793586370986290000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 6. script error: SCRIPT ERROR: Invalid access of index '4' on a base object of type: 'Array'.

Source: `res://scripts/guardian_combat_rules.gd:222`. Seeds: 12, 19.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 12 --runs 1 --processes 1 --stop-after 2235 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-12-2235-1793586370986297000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2215 | ui | SkillNode_dawnbrand |
| 2216 | ui | CloseCharacterOverlay |
| 2217 | begin_combat | _on_pre_battle_start_pressed |
| 2218 | move | (2, 4) |
| 2219 | card | hamstring_shot |
| 2220 | move | ['(3, 4)'] |
| 2221 | card | pale_spark |
| 2222 | ranged | ['(5, 4)'] |
| 2223 | card | brace |
| 2224 | confirm_card | _on_confirm_card_play_pressed |
| 2225 | move | (4, 4) |
| 2226 | card | quick_stab |
| 2227 | melee | ['(3, 5)'] |
| 2228 | move | (4, 4) |
| 2229 | card | patch_up |
| 2230 | confirm_card | _on_confirm_card_play_pressed |
| 2231 | move | (3, 4) |
| 2232 | card | guarded_step |
| 2233 | move | ['(2, 3)'] |
| 2234 | pass | _on_pass_turn_pressed |

### 7. script error: SCRIPT ERROR: Invalid access of index '1' on a base object of type: 'Array'.

Source: `res://scripts/guardian_combat_rules.gd:222`. Seeds: 14.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 14 --runs 1 --processes 1 --stop-after 82 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-14-82-1793586370986318000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 62 | card | bloody_lunge |
| 63 | move | ['(2, 1)'] |
| 64 | ui | SKIP & RECOVER  +3 HP   9962 → 9965 |
| 65 | map_room | ['(-2, 1)'] |
| 66 | side_settings |  |
| 67 | begin_combat | _on_pre_battle_start_pressed |
| 68 | move | (2, 3) |
| 69 | card | sidestep_slash |
| 70 | move | ['(2, 4)'] |
| 71 | card | pale_spark |
| 72 | ranged | ['(2, 1)'] |
| 73 | card | whirlwind_slash |
| 74 | confirm_card | _on_confirm_card_play_pressed |
| 75 | move | (2, 3) |
| 76 | card | lantern_shot |
| 77 | ranged | ['(2, 1)'] |
| 78 | move | (2, 2) |
| 79 | card | quick_stab |
| 80 | melee | ['(2, 1)'] |
| 81 | pass | _on_pass_turn_pressed |

### 8. script error: SCRIPT ERROR: Invalid access of index '6' on a base object of type: 'Array'.

Source: `res://scripts/guardian_combat_rules.gd:222`. Seeds: 12.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 12 --runs 1 --processes 1 --stop-after 2242 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-12-2242-1793586370986340000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| 2222 | ranged | ['(5, 4)'] |
| 2223 | card | brace |
| 2224 | confirm_card | _on_confirm_card_play_pressed |
| 2225 | move | (4, 4) |
| 2226 | card | quick_stab |
| 2227 | melee | ['(3, 5)'] |
| 2228 | move | (4, 4) |
| 2229 | card | patch_up |
| 2230 | confirm_card | _on_confirm_card_play_pressed |
| 2231 | move | (3, 4) |
| 2232 | card | guarded_step |
| 2233 | move | ['(2, 3)'] |
| 2234 | pass | _on_pass_turn_pressed |
| 2235 | card | bloody_lunge |
| 2236 | move | ['(2, 3)'] |
| 2237 | move | (2, 1) |
| 2238 | card | shadow_step |
| 2239 | blink | ['(4, 1)'] |
| 2240 | card | sidestep_slash |
| 2241 | move | ['(4, 3)'] |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 21 |
| 1 | 9 |
| 2 | 6 |
| 3 | 3 |
| 4 | 1 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 19 |
| campfire | 32 |
| combat | 147 |
| dragon | 19 |
| ember_hoarder | 3 |
| event | 78 |
| graftwright | 5 |
| guardian | 12 |
| hoarder | 3 |
| last_light | 7 |
| scavenger | 24 |
| snare | 4 |
| start | 40 |
| treasure | 40 |
| umbral_snare | 4 |
| warband | 3 |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.

## Validation and census scope

Native Godot crashes: **0**. The nonzero runner-status group consists of script-error scans after native exit 0 (eight campaign runs plus the separately verified replay).

The 75-minute cutoff stopped new launches; existing runs drained. The final launch was 4105.41 seconds after the first, below the 4500-second cutoff.

All 21 campaign seeds were launched before the recursive census correction. Their `tree_nodes` field counts public children; every entry also retains Godot’s total-node `nodes` and `orphans` monitors. The final driver includes internal nodes and passed a direct SceneTree census check. Section 5 was never reached, so no section-0-to-5 leak comparison was completed.

Focused proof, the planted fault, exact result lines, chosen defaults and retained private replay paths are recorded in [validation.md](validation.md). No findings were fixed.
