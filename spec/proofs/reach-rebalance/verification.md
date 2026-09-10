# Reach revision verification

Revision `short_reach_v1`; base `e7ea04093f6596be111cc352a5d047156ca96ec9`.
Task: `rebalance-attack-reach-and-enemy-approach-intents`.

## Acceptance and results

- Ordinary enemy reach is short, counting advance plus attack shape. Mobile roles retain dependable move-3 weak neutral melee approaches, and slower anchors can reposition. Strong signatures win when they can connect. Revealed approaches cannot upgrade their attacks after moving.
- The complete 159-definition player pool (158 active) was audited across starter, reward, equipment and consumable sources. 77 definitions change, comprising 80 action-field changes plus matching descriptions. Player damage, card Time and the independent movement-2 pool are preserved. [Full field/score audit](card-audit.json).
- Boss actions, room geometry/generation, surface fuel hooks, Umbra visibility and warning behavior, objectives, rewards, base initiative and progression remain unchanged. Setup-earned Chain/conduction/Detonate extensions remain legal.
- Saves retain revealed intents and paid checkpoints until normal next selection. Fresh cards use the new definitions. Additive revision/transition analytics distinguish the boundary without destructive migration.
- Full Godot suite and focused reach suite pass on final production code. The seven existing Python heuristic tests pass. `git diff --check` passes. The full-suite log contains the expected ambiguous legacy-save test warning and existing ObjectDB-at-exit warning, with `TEST RESULT: PASS` and no script/parser errors.

## Repeatable commands

Run from the task worktree. All Godot processes use isolated runtime storage.

```sh
python3 tools/godot_task_runner.py --task-id rebalance-attack-reach-and-enemy-approach-intents --stream -- godot --headless --path . --script tests/reach_rebalance_test.gd
python3 tools/godot_task_runner.py --task-id rebalance-attack-reach-and-enemy-approach-intents --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_card_heuristic*.py'
python3 tools/card_heuristic.py --json
python3 tools/godot_task_runner.py --task-id rebalance-attack-reach-and-enemy-approach-intents --stream -- godot --headless --path . --script tools/reach_playability_probe.gd -- /private/tmp/labyrinth-reach-proof/legal-action-snapshots.json
python3 tools/godot_task_runner.py --task-id rebalance-attack-reach-and-enemy-approach-intents --stream -- godot --headless --path . --script tools/reach_pursuit_probe.gd
python3 tools/visual_probe_runner.py --task-id rebalance-attack-reach-and-enemy-approach-intents --script tests/reach_rebalance_probe.gd --no-headless --display-driver macos --audio-driver Dummy --manifest /private/tmp/labyrinth-reach-proof/visual-proof-final.json
```

The paired run command is the same runner plus `--script tools/board_surface_playtest.gd -- --seed SEED --build BUILD --output-dir OUTPUT`. Baseline was run before edits at the base commit. Candidate output folders are `final-BUILD-SEED`. The six boss screens substitute `tools/reach_boss_playtest.gd` and add `--boss ID` at seed 9102601. Raw session saves, manual notes, logs and append-only analytics remain in `/private/tmp/labyrinth-reach-proof`; compact evidence and screenshots are committed here.

## Structural legality and scoring

[Legal-action snapshots](legal-action-snapshots.json) cover 48 seeded room setups: six elements, depths 1/3/9/19 and seeds 9102601/9102602. All unoccupied interior anchors are tested independently in Clear, Deep and Heart: 1,570 anchors per fog cohort, 4,710 total. The test uses actual target legality including occupancy, line of sight and fog; it does not award each card the shared movement pool.

Clear legal-any-enemy fractions for ranges 1–7 are 0.334 / 0.656 / 0.827 / 0.920 / 0.966 / 0.981 / 0.989. Deep plateaus at 0.827 beyond range 3 and Heart at 0.656 beyond range 2. These are structural availability anchors with fixed seeded enemy positions, not combat hit rates, and not independent random observations. They justify distinguishing short-range scorer bins. Melee retains its separately documented conservative commitment/routing factors.

The score model's mean old/new values are 3.179/2.997 for 14 starters, 4.076/3.561 for 56 rewards, 3.350/3.094 for 78 equipment cards, and 2.654/2.407 for 10 consumables. These shifts combine reach changes and scorer recalibration; they are not measured damage or a reason to auto-compensate every card. Each full old/new breakdown remains in the audit for subsequent human balance iteration.

## Paired playtests

The existing bounded legal-action policy, controlled six-spell builds, starter gear, no progression skills, heal rewards and identical seeds were used. [Paired summaries](playtest-summary.json) join `combat_ended` to `combat_started` and match rooms by coordinate, rather than treating reward-screen visits as combat victories.

| Build / seed | Baseline combat victories | Candidate combat victories | Baseline / candidate activations |
| --- | ---: | ---: | ---: |
| Mixed / 9102601 | 2 | 7 | 8 / 28 |
| Fire / 9102601 | 6 | 6 | 23 / 19 |
| Earth / 9102601 | 3 | 5 | 15 / 23 |
| Ice / 9102601 | 6 | 5 | 22 / 21 |
| Air / 9102601 | 4 | 5 | 20 / 16 |
| Lightning / 9102601 | 2 | 2 | 6 / 8 |
| Mixed / 9102602 | 3 | 4 | 11 / 21 |
| Mixed / 9102603 | 3 | 6 | 10 / 50 |

All eventually ended in defeat. None of the final candidates hit the 90-activation stalemate cap. An earlier candidate exposed a healthy last Surgeon repeatedly guarding itself; the final AI correction makes it pursue, with a dedicated regression and all eight runs repeated afterward.

Five candidates clear more combats, two tie and one clears fewer. This supports proceeding to human inspection; it does not establish a win rate or balance across rarities. There are 32 matched room coordinates, but player health, loot and subsequent route choices diverge, so later differences are not isolated causal effects.

The saved source hashes identify the exact files used per run. After these runs, three equipment ranges were finished: Lodestone Reversal, Anchor Slam and Rimeplate Lock. Their absence from every candidate combat deck and play log was checked before retaining these results. A subsequent engine edit only extracted the same lexicographic support comparison into a helper; save/analytics changes add transition context. The full suite was rerun on final production code. No claim is made that the earlier playtests share the final whole-tree hash.

The manual policy's existing analytics omit per-enemy action resolution and leave objective/fog context empty. These logs therefore cannot measure approach utilization or Umbra-specific outcomes. Focused intent tests, the separate pursuit probe and explicit real-renderer fog checks cover those narrower claims.

## Pursuit, bosses and remaining balance risk

[Pursuit probe](pursuit.json): 12 scenarios, each up to 24 activations, compare open and cluttered boards for Crawler, Acolyte, Harrier, Wisp, their mixed mobile squad, and Warden/Surgeon. A deliberately optimistic move/pass policy scores every legal free-movement endpoint by exact next-player-return HP, then separation. It plays no cards.

Every isolated mobile enemy can be avoided on the open board. Clutter kills the Crawler test player after 17 activations and allows Harrier/Wisp damage; Acolyte and the Warden/Surgeon pairing remain avoidable. The mixed mobile squad kills the player after 14 open-board and 15 cluttered-board activations. This exposes the limits of solo pressure and shows that free movement does not provide universal squad safety. The user-approved two-tile pool remains intact.

All six production boss arenas were exercised at their actual seeded depths with starter gear and 24 HP. The first isolated boss encounter yielded:

| Boss | Depth | Result | HP remaining | Player turn |
| --- | ---: | --- | ---: | ---: |
| Iskaldra | 4 | Victory | 1 | 16 |
| Tharokh | 8 | Victory | 18 | 18 |
| Zekarion | 12 | Defeat | 0 | 6 |
| Vaeloryx | 16 | Defeat | 0 | 5 |
| Vyraketh | 20 | Defeat | 0 | 32 |
| Noctyrax | 24 | Defeat | 0 | 5 |

The inherited route policy continues after some boss victories. The table deliberately reports the first `combat_ended`, not the later run endpoint. These screens demonstrate executed boss interactions, not appropriately geared late-game balance. Noctyrax uses six Radiance spells. Human inspection should still assess melee exposure, expensive-card cadence, AOE clustering, support attrition and progression-equipped late fights.

## Inspected renderer proof

The [visual manifest](visual-proof.json) records six native Metal captures, each 1920×1080 at 100% UI scale. Every capture was visually inspected. This is a data/behavior change using existing board/card widgets and icons; no new icon identity or art was introduced, and the frame/role texture cache does not bake the numeric fields.

1. [Range-two poke](01_poke_range_two.png): an enemy three tiles away is unavailable.
2. [Range-three shot](02_shot_range_three.png): the same enemy is legal with printed range 3 and a visible targeting line.
3. [Click resolution](03_clicked_shot_resolved.png): Dull Bolt resolves once, reducing the target from 40 to 36 HP and spending one play.
4. [Distant weak approach](04_distant_weak_approach.png): Acolyte shows move 3 with neutral melee damage 2 and cannot connect from five tiles away.
5. [Heart fog](05_heart_fog_preserved.png): show-all-intents preserves hidden identity/attack information; the timeline shows Unknown Presence.
6. [Drag selection](06_drag_target.png): the existing drag path starts and cancels without changing target HP. This capture is cancellation proof; click resolution is separately exercised above. Existing full-suite input coverage remains in place.

The playable inspection fixture is generated after exact-commit peer signoff by the standard two-process save/reload verifier. It is a pre-action combat with short pokes, dedicated shots, mobility and several ordinary enemy roles. Publication awaits user inspection and explicit approval.
