# Run hunt — November 2026

Runs started: 1; processes ended: 1; completed runs: 0 (victory 0, defeat 0, Embrace 0).
Wall clock: 1.63 minutes. Seed base 7; at most 1 concurrent Godot processes; stop launching after 75 minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.

## Findings

| Severity | Count | First seed | Section / room kind | Error and source |
|---|---:|---:|---|---|
| softlock | 1 | 7 | 0 / combat | Screen exceeded 120 decisions — res://tools/run_hunt.gd:237 |
| script error | 1 | 7 | -1 / startup | ERROR: Condition "ret != noErr" is true. Returning: "" — platform/macos/os_macos.mm:1014 |

### 1. softlock: Screen exceeded 120 decisions

Source: `res://tools/run_hunt.gd:237`. Seeds: 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 7 --runs 1 --processes 1 --stop-after 290 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-7-290-1793582842397745000
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

### 2. script error: ERROR: Condition "ret != noErr" is true. Returning: ""

Source: `platform/macos/os_macos.mm:1014`. Seeds: 7.

Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-16 && LABYRINTH_CEL_LOOK=off python3 tools/run_hunt.py --seed 7 --runs 1 --processes 1 --stop-after 1 --output-dir /private/tmp/labyrinth_codex/qa-16/replay-7-1-1793582842397783000
```

Last 20 decisions:

| Decision | Kind | Input |
|---:|---|---|
| — | startup | No decisions preceded this marker |

## Coverage

| Section (zero based) | Runs reaching section |
|---|---:|
| 0 | 1 |
| 1 | 0 |
| 2 | 0 |
| 3 | 0 |
| 4 | 0 |
| 5 | 0 |

| Room kind | Entries |
|---|---:|
| arcanist | 0 — NEVER VISITED |
| blacksmith | 0 — NEVER VISITED |
| boss | 0 — NEVER VISITED |
| campfire | 0 — NEVER VISITED |
| combat | 3 |
| dragon | 0 — NEVER VISITED |
| event | 1 |
| graftwright | 0 — NEVER VISITED |
| guardian | 0 — NEVER VISITED |
| hoarder | 0 — NEVER VISITED |
| last_light | 0 — NEVER VISITED |
| scavenger | 2 |
| snare | 0 — NEVER VISITED |
| start | 1 |
| treasure | 1 |
| warband | 0 — NEVER VISITED |

Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.

Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.

Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.
