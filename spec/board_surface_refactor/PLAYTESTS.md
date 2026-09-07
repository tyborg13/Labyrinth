# Board surfaces v4 — runtime and playtest synthesis

Historical v4 receipt. Current feedback-pass results are in PLAYTESTS_V5.md;
the recorded outcomes below have not been relabeled as v5 verification.

The core smoke test covers all 159 cards, 249 legal action executions, and all 62 intents across 18 enemies. Ordinary resolution equals presentation-trace resolution and preserves the input state in every case. Focused semantics cover independent layers, shared contact, large footprints, Freeze support consumption, Chain reach/relays, cardinal discharge, atomic Detonate, exact enemy fuel denial, weighted movement, source-aware rewards, and multi-action event retention.

## Seeded controlled runs

Each run uses six authored common spells, normal starter equipment, default progression and HP, seeded rooms/enemies, real card payment and initiative, heal rewards, and the first offered relic. The modest greedy policy uses immediate board value and the actual next activation forecast. It has no long-horizon setup search or reward/loadout optimization. Seeds differ between builds, so the rows are not a comparative win-rate experiment.

| Loadout | Seed | Combat wins | Player activations | Defeat depth |
|---|---:|---:|---:|---:|
| mixed | 9062621 | 3 | 29 | 2 |
| fire | 9062622 | 5 | 17 | 3 |
| earth | 9062623 | 3 | 17 | 2 |
| ice | 9062624 | 3 | 12 | 2 |
| air | 9062625 | 3 | 10 | 2 |
| lightning | 9062626 | 2 | 10 | 2 |

These results include the AI route-survival correction and its full-movement-budget followup. All six ended in actual defeat: 19 combat wins, 95 player activations and 391 decisions in total, with no script failure or stalled objective. Fire, air and lightning match their prior verification summaries exactly. Mixed, earth and ice changed after survival ranking; each received an exact same-seed repeat that matches every policy-summary field and every gameplay analytics event after excluding generated event/install/session IDs and timestamps (179, 156 and 139 events respectively). The full-budget followup matches all six survival-corrected summaries and all gameplay events exactly. Logs retain the known host CA-certificate diagnostic; it did not interrupt execution. Early driver prototypes exposed its missing Reach Exit/escape handling and were corrected before the recorded runs; those prototype endpoints are not counted.

The current runs include 34 enemy Fire-damage events, 12 Chilled applications, one Detonate consumption, and two electrical component discharges. The mixed run's Cinderline Tempo consumed Fire after its direct shot killed the occupant; this does not establish a useful multi-actor blast. The current matrix did not execute a consuming Freeze, although the archived pre-survival-fix matrix did so once. Exact Freeze consumption and useful shared detonation remain covered by focused tests. Fire/element replacement and shared trap wakes also occurred. The electrical discharges involved single occupied tiles; these runs did not demonstrate a deliberately built multi-tile relay network. Focused tests establish that route correctness, while a future human Lightning-focused test should assess how naturally players build those routes.

The six deaths do not establish a difficulty regression. The policy leaves defensive and setup opportunities on the table, freezes its six-spell loadout, and takes healing instead of building stronger combinations.

Two separate corrections explain the archived result changes. Before the survival fix, the movement-allowance correction changed mixed from 90 decisions/29 activations to 58/13 while retaining three wins and a depth-2 defeat. A diagnostic subclass restoring only the previous enemy walker's missing per-step allowance validation reproduced that earlier archived mixed summary exactly; the other five builds were unchanged at that stage. Those pre-survival-fix verification results totaled 22 wins/84 activations and remain in the `_final_verified` directories.

The subsequent survival fix ranks same-turn attack routes by actual survival and finite movement/hazard cost, accounting for live defenses and trap-created ground. It changes mixed to 91 decisions/29 activations, earth from four wins/82 decisions to three/67, and ice from five wins/95 decisions to three/58. Early forecast differences alter the greedy policy: mixed passes after its opening Quarry Step instead of playing Brace; earth's Shadow Step forecast changes before its subsequent choices diverge; ice passes after Icicle Lance instead of playing Guarded Step. A diagnostic restoring exactly the two previous attack-candidate methods from `0cc1ac0`, in both the console engine and RunEngine's combat-creation engine, reproduces every old mixed/earth/ice summary exactly. No other runtime rule was reverted. Together with the exact current repeats, this reconciles the outcome changes to the intended AI correction rather than suggesting a balance adjustment.

Independent review of `71019d0` then found a bounded forecast error: using a route's initial cost as its allowance could discard a legal Move 4 route whose third step became cost four after an Earth trap created Rubble. The planner now forwards the action's full movement allowance. A focused fixture proves Move 4 reaches melee at eight HP, Move 3 stops at the same intermediate square as execution, and the fresh Move 1 first-Rubble-step exception still works. Fresh runs of all six seeds and the manual sequence preserve all preceding summaries and gameplay events exactly (1,057 events across all seven runs). No changed gameplay row required another repeat or causal diagnostic for this followup.

## Deliberate manual mixed run

Seed 9062630 used the same six common mixed spells. I originally selected commands from the real printed board, target lists, movement previews and initiative forecast; the final replay re-executes all 54 recorded decisions through current manual command APIs, including card targets, optional movement skips and the explicit push direction. No combat-state edits, health grants, forced draws or scripted enemy arrangements. All 25 card plays match the original gameplay payload fields exactly; only the intended richer source/surface metadata differs. The run won three generated combats, then used the offered campfire to bank 86 embers at 19/24 HP. This is a real retreat endpoint, not a first-boss completion claim.

The post-survival-fix replay and its exact repeat preserve this endpoint. All 25 full card payloads, including surface metadata, and all 133 analytics events match the pre-survival-fix verification after excluding generated event/install/session IDs and timestamps. Every shared manual-summary field also matches; the older receipt has additional synthesized metadata, which is not a gameplay difference.

The full-movement-budget replay also preserves all 54 steps, 25 full card payloads, 133 gameplay events, and the same retreat endpoint.

- **Bleak Antechamber:** used fast lethal sequencing, the enemy-death play refund, movement, Block and a push. Won at 20/24 HP and healed to 23. Fire setup arrived too late to affect this fight; the modest mixed loadout contains only one broad Fire painter, so draw order still matters.
- **Sooted Vault:** shot a Fire trap to paint the Warden's tile, then added Rubble with Quarry Step. A Crawler crossed the Fire and lost exactly the point needed to make Quick Stab lethal. Fire dealt six cumulative start damage to the stationary Warden and secured the last kill while the player collected equipment. Won at 20/24 and healed to 23. The two layers coexisted correctly; this stationary guard did not test the movement surcharge itself.
- **Quiet Hall:** painted a Fire route with an AOE that hit an empty trap, used Brace to absorb the player's own Fire crossings, then explicitly pushed a surviving Harrier right onto Fire. Slipstream dealt six direct plus one entry damage, leaving two HP for the next Fire start. The Surgeon acted first and cleared that tile while guarding the ally, preventing the expected kill. This created a real support-enemy priority decision, rather than a guaranteed combo. Finished the threats directly, collected and used healing, then won at 16/24 and healed to 19. I also lost four avoidable HP by stepping onto and lingering on my own Fire; the preview disclosed the risk, and retreat-square planning mattered.

The manual sample supports the intended board-oriented identity: ground changes lethal thresholds, interacts with movement and Block, stays relevant after a kill, and gives enemy support actions meaningful counterplay. It also shows that the automatic force direction is not a substitute for choosing a tactical push; manual direction input is now available in the console. No claim is made here that the art/feedback is polished, that every build is balanced, or that persistent ground cannot produce awkward long fights. Those require the parent task's visual inspection and broader human play.

## Operational use

Use the task runner, a unique output directory and an explicit seed:

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --timeout 0 --stream -- godot --headless --path . --script tools/board_surface_playtest.gd -- --seed 9062630 --build mixed --manual --output-dir res://playtest/a_new_manual_surface_run
```

Omit `--manual` for the bounded policy. Supported builds: mixed, fire, earth, ice, air, lightning. Add `--resume` with the same output directory to resume the exact saved console session. During a pending push/pull card, `force up|right|down|left` selects the remaining force rider; normal target geometry still applies. `continue` follows a secured exit and starts its pre-battle encounter. Surface skill input is `skill SKILL_ID KIND x,y [origin_x,origin_y]`. The manual strategy guide documents shared Fire, Ice, Rubble, conduction, trap wakes, objectives and these commands.

Current proof artifacts are `playtest/board_surface_v4_<build>_dynamic_budget/` and `playtest/board_surface_v4_manual_mixed_dynamic_budget/`: notes, analytics JSONL, exact session save, progression and summary. Runner logs and the current aggregate `RESULTS.json` are in `output/board-surface-refactor/ai-dynamic-budget-playtest-refresh/`, alongside `COMPARISON.json`, `GAMEPLAY_COMPARISON.json`, and identical before/after runtime/data/harness fingerprints in `SOURCES.json` and `SOURCES_AFTER.json`.

The preceding `_ai_survival` and `_ai_survival_repeat` directories remain intact. Their runner logs, aggregate, exact-repeat and historical causal receipts are in `output/board-surface-refactor/ai-survival-playtest-refresh/`. The `_final_verified` directories, `output/board-surface-refactor/PLAYTEST_RESULTS.json`, and `FINAL_PLAYTEST_SOURCES.json` remain intact as pre-survival-fix evidence. Do not overwrite these directories on a later pass.

Replay the recorded manual choices without injecting old tactical state or action definitions:

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tools/board_surface_manual_replay.gd -- --seed 9062630 --build mixed --output-dir res://playtest/a_new_manual_comparison
```

`playtest/board_surface_manual_replay.json` stores the 54 input decisions extracted from the original notes and analytics. The diagnostic `output/board-surface-refactor/mixed_walk_diagnostic.gd` and its explicitly named output directory emulate the superseded enemy-movement bug solely to explain the old/new mixed-policy divergence; they are not current gameplay proof.

For the later survival correction, `output/board-surface-refactor/ai-survival-playtest-refresh/previous_attack_playtest_all_engines.gd` restores the previous candidate methods solely for causal comparison. `DIAGNOSTIC_ALL_ENGINES_COMPARISON.json` records exact old-summary reproduction for all three changed builds. The first diagnostic, which replaced only the console engine, restored ice but left mixed/earth changed because combat creation uses RunEngine's separate engine; its retained partial comparison is not the final causal receipt.

## Implementation notes and limits for integration review

- Surface events retain a bounded 256-event encounter tail and a monotonic sequence; every consumer must select sequence deltas. This preserves earlier actions in a multi-action card without unbounded save growth.
- The current runs include the card-source and independent-review fixes, the corrected Zekarion/Wisp paid-only Shock data, and the AI survival/full-movement-budget corrections. Stable card identity is present in real replay surfaces and damage, while focused regressions cover Flurry, serialized ground, passive deaths, anonymous actions, safe same-turn attack routes, unavoidable hazards, finite hazard costs, live defenses, large-footprint contact, dynamic trap-created Rubble and minimum progress. Runtime/data/harness source fingerprints were unchanged across the current runs.
- Fire causal ownership comes from the first newly contacted burning footprint tile in deterministic footprint order. Active-card causality remains separate so a passive start kill can satisfy an explicit Fire-heal relic without banking future plays. Mixed-owner large-footprint contact is deterministic rather than multiplicative.
- Detonate damage sources carry `source_kind: detonate`, and still use the direct-damage rules. Terminal player-dead batches cannot revive the player through an enemy-death healing reward.
- Chain displacement forecasting applies target-surface, Light, Sunder and target relic modifiers before determining the next resolved launch square. Ordinary attacks allocate no Chain snapshots.
- Illusions share Fire/Ice contact and direct Chilled/Frozen vulnerability; Ice hits consume their supporting Ice too.
- Enemy fuel, movement and all intent primitives were exercised in smoke tests, not a complete boss campaign. The seeded and manual runs here ended before the first boss. The parent task remains responsible for full-suite integration, renderer proof, final review and publication.

The ten authored enemy proof encounters are mapped to executable cases in `ENEMY_ACCEPTANCE_RECEIPT.md`. The new `enemy_surface_acceptance_test.gd` passes all 11 focused scenarios, supplementing the whole-pool smoke, existing boss tests and generated/manual playtests.
