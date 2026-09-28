# Dragon feedback inspection — 2026-09-27

These commands recreate an isolated pre-action save, reload and verify it, then open the game. Choose **Continue**. Close the game before opening another case. Each launch resets that case; it does not replace the normal player profile.

The fight fixtures use the same depth and build families as the native studies: balanced for the five elemental dragons, skirmisher for Noctyrax. They retain the normal shuffle and acquired earlier trophies. Reward fixtures begin at the unclaimed milestone. These are staged inspection states, not full descents or proof of difficulty across every build.

The game binary used for the native studies is the official Godot 4.6.1 build packaged locally as `LabyrinthDragonPlaytest.app`. Commands require that local binary and this task worktree to remain available.

## Fights

Inspect the marked area and turn clock before spending cards. Each encounter includes ordinary movement, card targeting and supported input paths. Gust Step is available in the natural deck; select it and click one enemy to resolve the movement and pull.

### Vyraketh fight

```sh


cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-vyraketh-encounter --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/vyraketh-encounter.json --launch --scenario dragon --dragon-id vyraketh --dragon-depth 4 --dragon-build balanced --dragon-case encounter --summary 'Vyraketh depth 4: natural acquired-build opening'
```

### Tharokh fight

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-tharokh-encounter --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/tharokh-encounter.json --launch --scenario dragon --dragon-id tharokh --dragon-depth 8 --dragon-build balanced --dragon-case encounter --summary 'Tharokh depth 8: natural acquired-build opening'
```

### Iskaldra fight

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-iskaldra-encounter --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/iskaldra-encounter.json --launch --scenario dragon --dragon-id iskaldra --dragon-depth 12 --dragon-build balanced --dragon-case encounter --summary 'Iskaldra depth 12: natural acquired-build opening'
```

### Vaeloryx fight

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-vaeloryx-encounter --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/vaeloryx-encounter.json --launch --scenario dragon --dragon-id vaeloryx --dragon-depth 16 --dragon-build balanced --dragon-case encounter --summary 'Vaeloryx depth 16: natural acquired-build opening'
```

### Zekarion fight

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-zekarion-encounter --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/zekarion-encounter.json --launch --scenario dragon --dragon-id zekarion --dragon-depth 20 --dragon-build balanced --dragon-case encounter --summary 'Zekarion depth 20: natural acquired-build opening'
```

### Noctyrax fight

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-noctyrax-encounter --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/noctyrax-encounter.json --launch --scenario dragon --dragon-id noctyrax --dragon-depth 24 --dragon-build skirmisher --dragon-case encounter --summary 'Noctyrax depth 24: natural acquired-build opening'
```

## Rewards

Continue from the reward to inspect the relic acquisition animation and map fade. Noctyrax instead delivers Eclipse Mantle for the next run and completes the ascent. The five later-gate fixtures already represent the first-dragon Moltshard earned earlier in that run.

### Vyraketh reward

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-vyraketh-reward --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/vyraketh-reward.json --launch --scenario dragon --dragon-id vyraketh --dragon-depth 4 --dragon-build balanced --dragon-case reward --summary 'Vyraketh depth 4: unclaimed dragon milestone and relic delivery'
```

### Tharokh reward

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-tharokh-reward --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/tharokh-reward.json --launch --scenario dragon --dragon-id tharokh --dragon-depth 8 --dragon-build balanced --dragon-case reward --summary 'Tharokh depth 8: unclaimed dragon milestone and relic delivery'
```

### Iskaldra reward

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-iskaldra-reward --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/iskaldra-reward.json --launch --scenario dragon --dragon-id iskaldra --dragon-depth 12 --dragon-build balanced --dragon-case reward --summary 'Iskaldra depth 12: unclaimed dragon milestone and relic delivery'
```

### Vaeloryx reward

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-vaeloryx-reward --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/vaeloryx-reward.json --launch --scenario dragon --dragon-id vaeloryx --dragon-depth 16 --dragon-build balanced --dragon-case reward --summary 'Vaeloryx depth 16: unclaimed dragon milestone and relic delivery'
```

### Zekarion reward

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-zekarion-reward --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/zekarion-reward.json --launch --scenario dragon --dragon-id zekarion --dragon-depth 20 --dragon-build balanced --dragon-case reward --summary 'Zekarion depth 20: unclaimed dragon milestone and relic delivery'
```

### Noctyrax reward

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-noctyrax-reward --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/noctyrax-reward.json --launch --scenario dragon --dragon-id noctyrax --dragon-depth 24 --dragon-build skirmisher --dragon-case reward --summary 'Noctyrax depth 24: unclaimed dragon milestone and relic delivery'
```

## Emaciated Man

Press **Continue** on the main menu and finish the awakening introduction that opens automatically. **Awaken Power** then appears as its own room action. Open it to exchange a Moltshard or level up. Leave and select **Speak** again to check that ordinary dialogue remains separate. This fixture has two Moltshards and 100 Embers so the exchange and level-up can both be inspected.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-man --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/man.json --launch --scenario start --moltshards 2 --embers 100 --summary 'Emaciated Man: first awakening story, separate repeat service, Moltshard exchange and level-up'
```

## Focused card and relic interactions

These two small combat fixtures use an authored hand, positions and relic selection to expose the changed interactions immediately. They are inspection demonstrations, separate from the realistic boss playtests.

### Winter’s Hourglass and Stormroad Coil

Play Frostbolt through the Electrified relay, then inspect the stored Time counter and discounted Pale Spark. Play Pale Spark at the same enemy to see the two relay legs and exact Time payment.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-hourglass-coil --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/hourglass-coil.json --launch --scenario combat --player-position 2:1 --enemy-types crawler --enemy-positions 6:1 --relics winters_hour,stormroad_coil --hand frostbolt,pale_spark,brace --surfaces electrified@4:1 --summary 'Winter’s Hourglass and Stormroad Coil interaction inspection'
```

### Gust Step and Worldheart

Select Gust Step and click the enemy once to approach and pull. Play Brace, then Pass to inspect Worldheart’s conversion of at most two Block into Stoneskin and its adjacent pulse.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-inspect-gust-worldheart --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-feedback-inspection/final-v2/gust-worldheart.json --launch --scenario combat --player-position 2:1 --enemy-types warden --enemy-positions 5:1 --relics worldheart --hand gust_step,brace,stone_plate --summary 'Gust Step and Worldheart interaction inspection'
```

## Scope of the evidence

The [acceptance index](dragon_feedback_revision_20260927.md) links the native turn ledger, full regression result, semantic renderer proofs and final cutout receipts. Later acquired trophies materially help the tested builds. Vaeloryx and Zekarion retain some forgiving escape windows; those limits are part of the assessment.

All 15 recipes passed generation and reload verification in the initial batch retained under `/private/tmp/dragon-feedback-inspection/final-v1/`. The initial two interaction recipes encountered existing crates; the corrected commands above use clear row 1. Their successful correction and original logs remain preserved. The final source revision now has all 15 successful generation/reload receipts in `/private/tmp/dragon-feedback-inspection/final-v2/` (batch session 84927, exit 0). `generate-results.json` records every standard verifier result and log.

Read-only runtime checks of those saved fixtures confirm both Coil relay legs (2:1 → 4:1 → 6:1), Frostbolt storing 3 Time, Pale Spark costing 1 and leaving 1 stored Time, and Gust Step moving 2:1 → 3:1 before pulling the enemy 5:1 → 4:1. Those engine checks left the persisted pre-action saves unchanged. Subsequent native checks have now passed both interactions and the full Man introduction/exchange/level-up/ordinary-dialogue flow; see the final interaction section of the native journal. Their completed saves and analytics are preserved under `/private/tmp/dragon-feedback-inspection/native-checks-v1/`. All 15 fixtures, including the three played saves, are freshly reset. Post-commit standard re-verification is recorded in `final-v2/verify-results.json`; the independent exact-HEAD review and final clean-tree binding are in `exact-head-review.md` and `final-handoff.json` beside it. Those external receipts must pass on the same HEAD before handoff. Use the reset commands above instead of reopening an already played save. Publication requires explicit user approval of the reviewed commit.
