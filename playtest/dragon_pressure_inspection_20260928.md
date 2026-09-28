# Dragon pressure v3 inspection — DRAFT, 2026-09-28

**Draft recipes only.** These v3 fixtures have not yet been generated or verified for a final commit. Reviewed HEAD, generation/reload receipts and final native acceptance are pending. The [previous inspection guide](dragon_feedback_inspection_20260927.md), including the user's blank lines, is unchanged.

After handoff, choose one reset command below, then **Continue** in the game. Quit before opening another case. Each command regenerates and verifies that case's isolated starting save before launching; it replaces progress in that case only. The normal player profile and older v2 inspection saves use different namespaces.

The six fights use the current production encounter, natural shuffle and **balanced** acquired-build family at depths 4/8/12/16/20/24. Earlier trophies, normal skill budgets, equipment progression and one ordinary healing item are retained; there is no authored winning hand or extra health. These are staged gate encounters, not full descents. Inspect at 1920×1080 and 100% UI scale. Commands depend on this worktree and the existing local Godot 4.6.1 app.

## What to inspect

Across **all six dragons**, try keeping both offensive plays and relying on ordinary movement. Look for repeated decisions about defense, movement cards, Time, displacement or dismantling the encounter's field. A good counterplay win may avoid damage; the question is whether it repeatedly costs useful choices. Check that every announced layer and its clock agree with resolution, including after moving the boss or resuming a save.

| Fight | Main focus |
| --- | --- |
| Vyraketh, depth 4 | Held fire marks plus body attacks; decide when to clear fuel, defend, displace or spend extra movement. |
| Tharokh, depth 8 | Breakable spires plus body pressure; compare breaking a spire against attacking the boss and watch Faultline consume the remaining field. |
| Iskaldra, depth 12 | Crystal Mantle followed by Shatter; reducing Mantle and managing Ice/trail pressure should affect the next decision. |
| Vaeloryx, depth 16 | Dive wake, Gale and the close/outer Eye choices; movement must respond to both the body and held field. |
| Zekarion, depth 20 | Persistent charged terrain, Overload and live shots; check meaningful charge denial and repeated positional pressure. |
| Noctyrax, depth 24 | Brazier darkness protection plus separately announced ground sweeps at the player's declared position; relighting alone should not solve every layer. Inspect the new smoky shadow FX, actor readability and reduced-motion setting. |

## Reset and open a fight

### Vyraketh

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-vyraketh --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/vyraketh.json --launch --scenario dragon --dragon-id vyraketh --dragon-depth 4 --dragon-build balanced --dragon-case encounter --summary 'Pressure v3: Vyraketh depth 4 balanced opening'
```

### Tharokh

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-tharokh --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/tharokh.json --launch --scenario dragon --dragon-id tharokh --dragon-depth 8 --dragon-build balanced --dragon-case encounter --summary 'Pressure v3: Tharokh depth 8 balanced opening'
```

### Iskaldra

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-iskaldra --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/iskaldra.json --launch --scenario dragon --dragon-id iskaldra --dragon-depth 12 --dragon-build balanced --dragon-case encounter --summary 'Pressure v3: Iskaldra depth 12 balanced opening'
```

### Vaeloryx

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-vaeloryx --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/vaeloryx.json --launch --scenario dragon --dragon-id vaeloryx --dragon-depth 16 --dragon-build balanced --dragon-case encounter --summary 'Pressure v3: Vaeloryx depth 16 balanced opening'
```

### Zekarion

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-zekarion --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/zekarion.json --launch --scenario dragon --dragon-id zekarion --dragon-depth 20 --dragon-build balanced --dragon-case encounter --summary 'Pressure v3: Zekarion depth 20 balanced opening'
```

### Noctyrax

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-noctyrax --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/noctyrax.json --launch --scenario dragon --dragon-id noctyrax --dragon-depth 24 --dragon-build balanced --dragon-case encounter --summary 'Pressure v3: Noctyrax depth 24 balanced opening and shadow FX'
```

## Reset and inspect exchange feedback

Continue, finish the awakening introduction, then choose **Awaken Power**. With two Molt Shards and 100 Embers, trade once: the balance should become 350, one shard should remain, and a brief `+250 Embers` glow and sound should play. Repeated activation during the cue must not spend the second shard. Move the highlight to Leave during the cue and check it stays there; Leave or Level Up should remain usable. Repeat with reduced motion if desired. Existing dialogue wording is outside this revision.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-exchange --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/exchange.json --launch --scenario start --moltshards 2 --embers 100 --summary 'Pressure v3: durable Molt Shard exchange fanfare and service focus'
```

## Reset and inspect Stormroad Coil

Hover or focus the Coil relic badge. Its short rules should retain single-target ranged attacks, one Electrified relay and normal range on each leg, without redundant visibility prose. Play Frostbolt at the crawler to inspect the two relay legs (2:1 → 4:1 → 6:1). This focused authored hand is a targeting/copy demonstration, separate from the natural boss builds.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/inspection_fixture.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-coil --godot /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --manifest /private/tmp/dragon-pressure-inspection/v3/coil.json --launch --scenario combat --player-position 2:1 --enemy-types crawler --enemy-positions 6:1 --relics stormroad_coil --hand frostbolt,pale_spark,brace --surfaces electrified@4:1 --summary 'Pressure v3: concise Coil rules and two-leg relay'
```

## Resume without resetting

The commands above **reset** the chosen case. To continue a case already played, use its same `--run-id` with the task runner directly, then choose Continue. For example, this resumes Vyraketh's current autosave and does not regenerate it:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/godot_task_runner.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-pressure-inspect-v3-vyraketh --stream --timeout 0 -- /private/tmp/LabyrinthDragonPlaytest.app/Contents/MacOS/Godot --path .
```

Substitute any run ID from this guide to resume that case. The unlimited interactive timeout lasts until the game is closed; generation and verification retain their bounded runner timeouts. A resumed, modified save is not the certified pre-action inspection state. Use the matching reset command for a clean comparison.

## Handoff status

Pending: all-six completed native assessment, final commit, exact-HEAD independent review, generation/reload verification for these eight recipes, and receipt binding. The inspected shadow material revision is accepted; native Earth completion and the visible-terrain shortcut repair are recorded in the journal. Integrated full regression currently passes; rerun affected checks after any further implementation changes. Current implementation evidence lives in the [pressure ledger](dragon_pressure_revision_20260928.md), [native journal](dragon_pressure_native_20260928.md) and [presentation receipt](dragon_pressure_presentation_20260928.md). No publication approval is implied by this draft.
