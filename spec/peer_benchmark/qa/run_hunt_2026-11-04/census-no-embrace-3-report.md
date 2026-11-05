# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 1 (victory 1, defeat 0, Embrace 0).
Wall clock: 23.01 minutes. Seed base 3; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.
No Embrace / terminal choices: True. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| script error | 1 | 3 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |
| warning | 1 | 3 | 1 / scavenger | WARNING: Relic glossary above-row overflow: RelicChoice_hourglass_awl, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0 — res://scripts/card_focus_tooltip_stack.gd:325 |
| leak | 1 | 3 | 5 / start | tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2858) — res://tools/run_hunt.gd:261 |

### 1. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task_verbose.py --seed 3 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-1-1793841476981828000 --no-embrace --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census_full.gd
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

### 2. warning: WARNING: Relic glossary above-row overflow: RelicChoice_hourglass_awl, viewport=(1920.0, 1920.0), block=(624.0, 88.0), top=1864.0, row_top=1964.0

Source: `res://scripts/card_focus_tooltip_stack.gd:325`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task_verbose.py --seed 3 --runs 1 --processes 1 --stop-after 768 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-768-1793841476981844000 --no-embrace --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census_full.gd
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

### 3. leak: tree_nodes grew more than 25% from section 0 to section 5 (1556 -> 2858)

Source: `res://tools/run_hunt.gd:261`. Seeds: 3.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-43 && LABYRINTH_CEL_LOOK=off python3 /private/tmp/labyrinth_codex/qa-43/run_hunt_task_verbose.py --seed 3 --runs 1 --processes 1 --stop-after 2369 --output-dir /private/tmp/labyrinth_codex/qa-43/replay-3-2369-1793841476981868000 --no-embrace --script /private/tmp/labyrinth_codex/qa-43/run_hunt_census_full.gd
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
| boss | 6 |
| campfire | 6 |
| combat | 25 |
| dragon | 6 |
| ember_hoarder | 1 |
| event | 10 |
| graftwright | 1 |
| guardian | 3 |
| hoarder | 1 |
| last_light | 0 — NEVER VISITED |
| scavenger | 5 |
| snare | 1 |
| start | 6 |
| treasure | 8 |
| umbral_snare | 1 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
