# Board surfaces v4 — runtime and playtest synthesis

The core smoke test covers all 159 cards, 249 legal action executions, and all 62 intents across 18 enemies. Ordinary resolution equals presentation-trace resolution and preserves the input state in every case. Focused semantics cover independent layers, shared contact, large footprints, Freeze support consumption, Chain reach/relays, cardinal discharge, atomic Detonate, exact enemy fuel denial, weighted movement, source-aware rewards, and multi-action event retention.

## Seeded controlled runs

Each run uses six authored common spells, normal starter equipment, default progression and HP, seeded rooms/enemies, real card payment and initiative, heal rewards, and the first offered relic. The modest greedy policy uses immediate board value and the actual next activation forecast. It has no long-horizon setup search or reward/loadout optimization. Seeds differ between builds, so the rows are not a comparative win-rate experiment.

| Loadout | Seed | Combat wins | Player activations | Defeat depth |
|---|---:|---:|---:|---:|
| mixed | 9062621 | 3 | 13 | 2 |
| fire | 9062622 | 5 | 17 | 3 |
| earth | 9062623 | 4 | 17 | 3 |
| ice | 9062624 | 5 | 17 | 3 |
| air | 9062625 | 3 | 10 | 2 |
| lightning | 9062626 | 2 | 10 | 2 |

All six ended in actual defeat: 22 combat wins and 84 player activations in total, with no script failure or stalled objective. All six final verification replays matched their first final-pass run exactly, including every policy-summary field: endpoint, decision count, activation count, HP, card frequencies, surface-event counts and room/HP journey. Logs retain the known host CA-certificate diagnostic; it did not interrupt execution. Early driver prototypes exposed its missing Reach Exit/escape handling and were corrected before the six recorded runs; those prototype endpoints are not counted.

The recorded runs include 30 enemy Fire-damage events, one Freeze that consumed its Ice support, and two electrical component discharges. The final greedy matrix did not successfully use Detonate; exact Detonate semantics and useful shared detonation are established by focused tests rather than invented playtest observations. Fire/element replacement and shared trap wakes also occurred. The electrical discharges involved single occupied tiles; these runs did not demonstrate a deliberately built multi-tile relay network. Focused tests establish that route correctness, while a future human Lightning-focused test should assess how naturally players build those routes.

The six deaths do not establish a difficulty regression. The policy leaves defensive and setup opportunities on the table, freezes its six-spell loadout, and takes healing instead of building stronger combinations. The mixed policy changed after the final movement correction: its result remains three wins and a depth-2 defeat, but it now takes 58 decisions and 13 activations, compared with the archived 90/29. A diagnostic subclass restoring only the previous enemy walker's missing per-step allowance validation reproduced the entire archived mixed summary exactly. Correct movement changes an early greedy forecast after Earth-trap setup and therefore subsequent choices; this is an explained correctness change, not evidence for a balance adjustment. The other five builds match the earlier gameplay summaries exactly.

## Deliberate manual mixed run

Seed 9062630 used the same six common mixed spells. I originally selected commands from the real printed board, target lists, movement previews and initiative forecast; the final replay re-executes all 54 recorded decisions through current manual command APIs, including card targets, optional movement skips and the explicit push direction. No combat-state edits, health grants, forced draws or scripted enemy arrangements. All 25 card plays match the original gameplay payload fields exactly; only the intended richer source/surface metadata differs. The run won three generated combats, then used the offered campfire to bank 86 embers at 19/24 HP. This is a real retreat endpoint, not a first-boss completion claim.

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

Current proof artifacts are `playtest/board_surface_v4_<build>_final_verified/` and `playtest/board_surface_v4_manual_mixed_final_verified/`: runner logs, notes, analytics JSONL, exact session save, progression and summary. The earlier directories and first final-pass runs remain intact. `PLAYTEST_RESULTS.json` aggregates current receipts; `FINAL_PLAYTEST_SOURCES.json` records runtime/data/harness fingerprints. Do not overwrite these directories on a later pass.

Replay the recorded manual choices without injecting old tactical state or action definitions:

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tools/board_surface_manual_replay.gd -- --seed 9062630 --build mixed --output-dir res://playtest/a_new_manual_comparison
```

`playtest/board_surface_manual_replay.json` stores the 54 input decisions extracted from the original notes and analytics. The diagnostic `output/board-surface-refactor/mixed_walk_diagnostic.gd` and its explicitly named output directory emulate the superseded enemy-movement bug solely to explain the old/new mixed-policy divergence; they are not current gameplay proof.

## Implementation notes and limits for integration review

- Surface events retain a bounded 256-event encounter tail and a monotonic sequence; every consumer must select sequence deltas. This preserves earlier actions in a multi-action card without unbounded save growth.
- The final verification runs include the card-source and independent-review fixes plus the corrected Zekarion/Wisp paid-only Shock data. Stable card identity is now present in real replay surfaces and damage, while the focused real-card regression also covers Flurry, serialized ground, passive deaths, and anonymous-action behavior. The revision caveat on the earlier archived runs is resolved by the current reruns.
- Fire causal ownership comes from the first newly contacted burning footprint tile in deterministic footprint order. Active-card causality remains separate so a passive start kill can satisfy an explicit Fire-heal relic without banking future plays. Mixed-owner large-footprint contact is deterministic rather than multiplicative.
- Detonate damage sources carry `source_kind: detonate`, and still use the direct-damage rules. Terminal player-dead batches cannot revive the player through an enemy-death healing reward.
- Chain displacement forecasting applies target-surface, Light, Sunder and target relic modifiers before determining the next resolved launch square. Ordinary attacks allocate no Chain snapshots.
- Illusions share Fire/Ice contact and direct Chilled/Frozen vulnerability; Ice hits consume their supporting Ice too.
- Enemy fuel, movement and all intent primitives were exercised in smoke tests, not a complete boss campaign. The seeded and manual runs here ended before the first boss. The parent task remains responsible for full-suite integration, renderer proof, final review and publication.

The ten authored enemy proof encounters are mapped to executable cases in `ENEMY_ACCEPTANCE_RECEIPT.md`. The new `enemy_surface_acceptance_test.gd` passes all 11 focused scenarios, supplementing the whole-pool smoke, existing boss tests and generated/manual playtests.
