# bos-03 implementation and proof

Implementation contract: the owner-approved unit brief (2026-10-27), including director feedback 1, 2 and 3, with `boss_rules_draft.md` Guardian tables and director decisions as its base. This record copies the brief’s exact six panel sentences for validation; it introduces no design decisions.

| Guardian | Rule | Cadence | Dials | Panel sentence |
|---|---|---|---|---|
| ashen_reaver | wildfire | `{"anchor": "after_player_turn", "every": 2}` | `{"spread": "toward_player"}` | After every second turn of yours, the Reaver's Fire spreads 1 tile toward you. |
| rimejaw | frostbite | `{"anchor": "after_player_turn", "every": 1}` | `{"damage": 0}` | After each of your turns, Rimejaw's Frostbite Freezes everyone standing on Ice. |
| storm_cantor | lightning_storm | `{"anchor": "on_intent", "intent": "peal"}` | `{"damage": 3, "chain": 2}` | When the Cantor uses Peal, lightning strikes every Electrified tile for 3, with Chain 2. |
| gallows_roc | gust | `{"anchor": "after_player_turn", "every": 1}` | `{"tiles": 1, "direction": "toward_source"}` | After each of your turns, the Roc's wind Pushes everyone 1 tile toward it. |
| craghide | upheaval | `{"anchor": "after_source_turn", "every": 2}` | `{"pattern": "line_between", "length": 3, "health": 2}` | After every second Craghide turn, the marked tiles rise as Outcrops. |
| last_lamplighter | shadowstep | `{"anchor": "after_player_turn", "every": 1}` | `{"blink": 1, "who": ["wick_shade"]}` | After each of your turns, hidden Wick Shades Blink 1 tile toward you. |

Finite initial helpers retain their oriented (2,3)/(6,3) slots. Only authored Call the Spark (Wisp cap 2) and Snuff (Shade cap 1) bring helpers back. Both retain sum-01’s +1 Card Play on arrival. Peal keeps only Move 1; Crag Heave keeps only Move 2. Display names Rime Bite and Crag Heave preserve ids `frostbite` and `upheaval`. Cantor/Roc initiatives are 11/9; Tender/Fledgling Guardian overrides are 12; Wisp stays 19. Roc is Anchored. Other identities, arenas, relics, intents, traps and helper numbers stay as authored, except the director's feedback-1 rungs described below.

Feedback 1 retained Rimejaw rung 2 (HP 34, Harrowing Pounce 6), Cantor rung 4 (HP 46, Broken Rhythm 7, Wisp cap 2, Lightning Storm 4), and Lamplighter rung 5 (Procession 6, HP 36, Shade cap 1, Mourning Hook 3, Guardian Shade Grasp / Hooking Grasp 1). The Shade override applies before ordinary depth scaling in combat and pre-battle inspection; its regular-encounter and Grimoire base remains 2. No unrequested tuning is applied.

Feedback 2 retains Rimejaw rung 2 unchanged, Cantor rung 8 (Choir 6 linked tiles, HP 56, Broken Rhythm 9, Lightning Storm 4 with Chain 3), and Lamplighter rung 6 (HP 30). Lamplighter keeps Procession 6 and one initial Shade; later rungs are not applied. [Extended ladders](measurements/bos-03-feedback-2/ladders.md) and the [updated three-variant table](measurements/bos-03-feedback-2/report.md) retain accepted earlier evidence. The [golden field audit](measurements/bos-03-feedback-2/golden-structured-diff.json) found 54 standard rooms, zero Guardian rooms, and only 108 additive zero summon counters. No golden hashes were re-pinned; int-06 owns that integration repair.

Feedback 3 retains Cantor rung 12: HP 66, Broken Rhythm 11, and Guardian Bell Tender Staff Bolt 4 (ordinary Staff Bolt remains 3), with the approved Peal rule restored to damage 3 / Chain 2. Rimejaw rung 2 and Lamplighter rung 6 remain decided. The Choir count override was loaded, but its shortest path stopped at the hero after 2–3 tiles in real arenas. `guardian_fill_count` now spends the remainder through adjacent legal nonconductive ground; all four arena orientations forecast, resolve and play back six fresh tiles. Other connectors keep their caps. Exhausted ground may yield fewer. [Final ladder](measurements/bos-03-feedback-3/ladders.md), [all-six three-variant table](measurements/bos-03-feedback-3/report.md), and [synced exact golden audit](measurements/bos-03-feedback-3/golden-audit.md) carry the evidence. Final suite results and the six verified inspection saves are recorded in the [round-3 handoff](../../../output/bos-03-feedback-3/handoff.md).

Feedback-2 validation and exact pending windowed commands are recorded in the [round-2 handoff](../../../output/bos-03-feedback-2/handoff.md). Round 2 ran focused checks only. Round 3 runs both full suites after the director's int-06 sync; the director runs the windowed captures. Historical full-suite results below describe round 0.

Old Guardian saves receive the missing data instance at Continue. The migration preserves current intent ids and Time, removes retired injected summons and Peal/raise payloads, updates the two display names, and preserves remaining held geometry. Existing analytics history is untouched. New saves with an installed instance retain their counters and marks.

Round-0 measurement remains frozen: [three-variant report](measurements/bos-03/report.md). Feedback 1: [ordered ladders](measurements/bos-03-feedback-1/ladders.md) and [updated three-variant report](measurements/bos-03-feedback-1/report.md). Revision-7 rooms, policy v2, 30 runs per natural tier per Guardian per measured rung; exact matched sample keys, unchanged defaults and tier decks. Before/pace-only and unaffected after rows retain round-0 evidence.

Chosen defaults (offline/test/proof only): `RUNS_PER_TIER=30`, `WORKERS=6`, measurement `FIRST_SEED=1`; proof `PROOF_SEED=7262026`, `MAX_PROOF_ACTIVATIONS=8`, `PLAYBACK_TIMEOUT_MSEC=45000`; isolated `SAVE_PATH=user://bos-03-legacy.save`; named test fuel/Shadow positions in `guardian_rules_suite.gd`. Captures use the prescribed 1920×1080 and 100% UI scale. The proof boundary walks the ordinary clock and retains a real player turn immediately before its next beat. It changes no combat numbers.

No TODO_DESIGN placeholders were needed. No art, icons, fonts, sound or policy scores were created or changed.

Proof for the design owner (window server required; not run in the implementation sandbox):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id bos-03 --timeout 360 --expect-size 1920x1080 --proof-contract tests/proof_contracts/guardian_rules.json --result-manifest output/bos-03-feedback-3/guardian-rules-visual.json tests/guardian_rules_probe.gd
```

This captures `<guardian>_forecast.png` and `<guardian>_beat.png` for all six fights under the runner-isolated `user://probes/guardian_rules/`; the result manifest resolves their absolute paths. Inspect at native size. The runtime manifest also records rule ids, before/after beat counts and playback errors.

Regenerate, verify and launch one real beat-turn inspection save per Guardian (the six commands are independent):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/inspection_fixture.py --project . --task-id bos-03 --run-id bos-03-r3-ashen_reaver-beat --manifest output/bos-03-feedback-3/fixtures/ashen_reaver-beat.json --scenario guardian --guardian-id ashen_reaver --guardian-case beat --seed 7262026 --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/inspection_fixture.py --project . --task-id bos-03 --run-id bos-03-r3-rimejaw-beat --manifest output/bos-03-feedback-3/fixtures/rimejaw-beat.json --scenario guardian --guardian-id rimejaw --guardian-case beat --seed 7262026 --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/inspection_fixture.py --project . --task-id bos-03 --run-id bos-03-r3-storm_cantor-beat --manifest output/bos-03-feedback-3/fixtures/storm_cantor-beat.json --scenario guardian --guardian-id storm_cantor --guardian-case beat --seed 7262026 --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/inspection_fixture.py --project . --task-id bos-03 --run-id bos-03-r3-gallows_roc-beat --manifest output/bos-03-feedback-3/fixtures/gallows_roc-beat.json --scenario guardian --guardian-id gallows_roc --guardian-case beat --seed 7262026 --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/inspection_fixture.py --project . --task-id bos-03 --run-id bos-03-r3-craghide-beat --manifest output/bos-03-feedback-3/fixtures/craghide-beat.json --scenario guardian --guardian-id craghide --guardian-case beat --seed 7262026 --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-03 && python3 tools/inspection_fixture.py --project . --task-id bos-03 --run-id bos-03-r3-last_lamplighter-beat --manifest output/bos-03-feedback-3/fixtures/last_lamplighter-beat.json --scenario guardian --guardian-id last_lamplighter --guardian-case beat --seed 7262026 --launch
```

The director owns preflight, contract, Git commit, publication and windowed inspection. This implementation worker leaves changes uncommitted and supplies test evidence and verified fixture commands.

Validation evidence: [implementation handoff](../../../output/bos-03/handoff.md) and `output/bos-03/validation_summary.json`. The 1,620-run table is complete. Focused Guardian/beat/summon/boss-bar/clock/analytics checks pass. Full Python completed 2,236 tests with 10 failures, 8 errors and 66 skips; full Godot timed out at 900 seconds. Existing failing assertions and protected art inputs were preserved. Real-renderer proof remains assigned to the design owner.
