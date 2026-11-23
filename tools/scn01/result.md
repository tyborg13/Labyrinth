# scn-01 real-game screen census

The current catalog omits Blacksmith and Arcanist. New runs generate the Scavenger instead. Shot numbers 16 and 17 remain reserved so existing capture filenames stay stable. The results below describe the original scn-01 census.

## Candidate 4 extension (pol-67)

The candidate 4 plan has 71 shots. It removes the legacy Blacksmith and
Arcanist fixtures and adds combat inspection and forecast states, visited and
unvisited map previews, the title-to-first-room flow, merchant and prize
states, withdrawal, the Chronicle, and a consumable hover on Character Gear.
The New Run path uses a saved checkpoint and a profile with the depth picker
unlocked, so it includes the replacement confirmation, picker, loading cover
and all three pages of the entry dialogue.

The driver measures the same live Control tree at the headless and native
capture boundary. The layout report carries exact paths and rectangles,
including overlapping Control regions and off-screen extents. Text dimensions
come from Godot shaping and theme metrics. Hand fanning, decorative
overscan, and the partially visible end of a scroll list can produce geometry
observations. Custom canvas drawing and nonrectangular input masks are
outside the Control geometry measurement.

Run both native sizes from a logged-in macOS session.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-67 && /private/tmp/labyrinth_codex/pol-67/native.sh
```

The launcher prepares fixtures through the task runner and validates a batch
of PNGs per size through the visual runner. Each shot retains a fresh engine
process and save home. Both modes wait for stable Control geometry and
finished tweens before sampling. Under the printed run root, each size
has its PNGs, contact sheets, logs and manifest. The paired
Markdown and JSON reports sit at the run root. A settled or capped shot with a
valid capture succeeds. A failed shot makes the completed run exit nonzero.
Both sizes share a 29-minute budget. The next two commands run the headless census and regenerate its reports.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-67 && /private/tmp/labyrinth_codex/pol-67/native.sh --dry-run --out /private/tmp/labyrinth_codex/pol-67/headless
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-67 && python3 tools/scn01/census.py --report-from /private/tmp/labyrinth_codex/pol-67/headless/1920x1080/manifest.json /private/tmp/labyrinth_codex/pol-67/headless/1280x800/manifest.json
```

## Original scn-01 census

The catalog has 50 shots. It includes all 23 inspection scenario entries, six named dragons, two named guardians, three named events, and 16 four-enemy combat and reward states. The fixture produces a save, profile and settings in an isolated Godot home. The census installs copies into a second isolated home and uses RunScene's Continue checkpoint loader and live controls.

The windowed probe reads pixels from a SubViewport at the requested size. It waits for two equal rendered frames with no running SceneTree tweens and flags the latest matching frame if the six-second limit expires. The headless probe exercises the same checkpoints and input. It compares visible control layout and text, since the dummy renderer provides no pixels. Continuous treasure sparkles are outside the headless layout comparison.

## Proof for the design owner

The installed launcher links to the worktree's `tools/scn01/native.sh`. Run from a logged-in desktop session. The driver uses `tools/visual_probe_runner.py` for every PNG. The visual runner validates the exact size and writes a per-shot proof JSON beside the logs. The driver prints the PNG paths and writes numbered contact sheets through the existing contact-sheet helper.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/scn-01 && /private/tmp/labyrinth_codex/scn-01/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/scn-01 && /private/tmp/labyrinth_codex/scn-01/native.sh --size 1280x800
cd /Users/borgerding/workspace/Labyrinth.worktrees/scn-01 && /private/tmp/labyrinth_codex/scn-01/native.sh --only combat_card_aim,combat_enemy_turn
```

By default, each run writes to `/private/tmp/labyrinth_codex/scn-01/<UTC stamp>/`. A successful native run produces numbered shot PNGs, `manifest.json` and contact sheets with up to 12 shots in four columns. The process continues after a bad shot and exits successfully when at least 90% of selected shots succeed. Both windowed sizes are pending desktop verification. The headless runs produce manifests and logs.

## Chosen defaults

- Fixture seed `7262026` except `reach_exit`, which uses seed `3`. The original default seed cannot reach that encounter along the fixture's route. The manifest also records the effective seed loaded by the game when the fixture resolves its own seed.
- The additional guardian is `last_lamplighter`. Named events are `lost_cartographer`, `bloodletters_basin` and `ossuary_gamblers`. Noctyrax uses the fixture-required depth 24.
- The shared combat fixture uses hero tile `2:4`, Crawler at `4:4`, Acolyte at `5:2`, Harrier at `5:5`, and Warden at `4:6`. The hand contains Pale Spark, Quick Stab, Guarded Step and Sidestep Slash. Hover and aim use Pale Spark. The keyword shot uses Quick Stab. The reward fixture uses its three default card choices after resolving that encounter.
- Each Godot process has a 60-second watchdog. The visual runner has a 70-second watchdog. The input-state deadline is 12 seconds, and headless runs use 60 frames per second with three isolated jobs. Hand hover samples the visible part of the existing card using the fan's hit test. The enemy-turn shot holds the production frame once an enemy is active on the turn-order strip.
- The terminal shots add the production analytics identity to the isolated copy of each fixture before Continue. This lets the game take its existing pending-settlement recovery path with the authored terminal state.

## Other checks

- Python default group, `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/scn-01/python-default`. Observed `INPUT GROUP default: always run`, `Ran 192 tests in 33.928s`, and `OK`. The sandbox denied the optional write to Git's learned timing cache after the tests passed. [Log](/private/tmp/labyrinth_codex/scn-01/python-default.log)
- Windows typed-array scan, `python3 tools/qa105/typed_array_scan.py --base HEAD`. Observed `TYPED ARRAY SCAN: 2 scripts; 0 new; 0 pre-existing`. [Log](/private/tmp/labyrinth_codex/scn-01/typed-array-final.log)
- Rules text lint, `python3 tests/test_rules_text_lint.py`. Observed `Ran 3 tests`, `OK`, and `PASS: Rules text lint (455 existing hits)`. [Log](/private/tmp/labyrinth_codex/scn-01/rules-text.log)
- Temporary driver checks verified 50 distinct shots covering 23 fixture entries, the 9/10 and 8/10 exit thresholds, and contact-sheet pagination with 13 inputs. [Log](/private/tmp/labyrinth_codex/scn-01/driver-checks.log)

The census introduces no `TODO_DESIGN_*` placeholders.

## Headless dry-run results

- 1920x1080 at 100% UI scale, exit 0. `CENSUS RESULT: PASS; 48/50 shots succeeded; 0 capped` [Log](/private/tmp/labyrinth_codex/scn-01/final-1920x1080.log) · [Manifest](/private/tmp/labyrinth_codex/scn-01/final-1920x1080/manifest.json)
- 1280x800 at 100% UI scale, exit 0. `CENSUS RESULT: PASS; 48/50 shots succeeded; 0 capped` [Log](/private/tmp/labyrinth_codex/scn-01/final-1280x800.log) · [Manifest](/private/tmp/labyrinth_codex/scn-01/final-1280x800/manifest.json)

The two legacy merchant scenarios are still in the fixture catalog. Current world generation supplies Scavenger, and Continue migrates legacy Blacksmith and Arcanist rooms to Scavenger. The census leaves both attempts visible in the manifests. Both runs recorded zero GDScript errors and zero settle caps. No PNGs were emitted in headless mode.

| Shot | Loaded seed | 1920×1080 | 1280×800 |
| --- | ---: | --- | --- |
| 01 `snare` | 7262026 | Settled at frame 129 | Settled at frame 130 |
| 02 `warband` | 7262026 | Settled at frame 130 | Settled at frame 131 |
| 03 `last_light` | 7262026 | Settled at frame 129 | Settled at frame 129 |
| 04 `ember_hoarder` | 7262026 | Settled at frame 130 | Settled at frame 130 |
| 05 `dragon` | 7262027 | Settled at frame 130 | Settled at frame 130 |
| 06 `guardian` | 7262026 | Settled at frame 132 | Settled at frame 131 |
| 07 `start` | 7262026 | Settled at frame 140 | Settled at frame 140 |
| 08 `pre_battle` | 7262026 | Settled at frame 136 | Settled at frame 135 |
| 09 `combat` | 7262026 | Settled at frame 131 | Settled at frame 130 |
| 10 `reach_exit` | 3 | Settled at frame 131 | Settled at frame 130 |
| 11 `guided_tutorial` | 7262026 | Settled at frame 131 | Settled at frame 130 |
| 12 `reward` | 7262026 | Settled at frame 152 | Settled at frame 151 |
| 13 `campfire` | 7262026 | Settled at frame 137 | Settled at frame 137 |
| 14 `treasure` | 7262026 | Settled at frame 150 | Settled at frame 150 |
| 15 `character` | 7262026 | Settled at frame 52 | Settled at frame 53 |
| 16 `blacksmith` | — | inspection fixture exit 1; Could not find a blacksmith room for inspection. | inspection fixture exit 1; Could not find a blacksmith room for inspection. |
| 17 `arcanist` | — | inspection fixture exit 1; Could not find a arcanist room for inspection. | inspection fixture exit 1; Could not find a arcanist room for inspection. |
| 18 `scavenger` | 7262026 | Settled at frame 136 | Settled at frame 137 |
| 19 `graftwright` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 20 `boss` | 90429 | Settled at frame 130 | Settled at frame 129 |
| 21 `victory` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 22 `defeat` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 23 `event` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 24 `dragon_tharokh` | 7262026 | Settled at frame 129 | Settled at frame 129 |
| 25 `dragon_vyraketh` | 7262027 | Settled at frame 130 | Settled at frame 129 |
| 26 `dragon_vaeloryx` | 7262031 | Settled at frame 129 | Settled at frame 129 |
| 27 `dragon_iskaldra` | 7262028 | Settled at frame 131 | Settled at frame 129 |
| 28 `dragon_zekarion` | 7262029 | Settled at frame 131 | Settled at frame 130 |
| 29 `dragon_noctyrax` | 7262026 | Settled at frame 131 | Settled at frame 130 |
| 30 `guardian_ashen_reaver` | 7262026 | Settled at frame 131 | Settled at frame 130 |
| 31 `guardian_last_lamplighter` | 7262026 | Settled at frame 131 | Settled at frame 131 |
| 32 `event_lost_cartographer` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 33 `event_bloodletters_basin` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 34 `event_ossuary_gamblers` | 7262026 | Settled at frame 136 | Settled at frame 136 |
| 35 `combat_idle` | 7262026 | Settled at frame 130 | Settled at frame 129 |
| 36 `combat_hand_hover` | 7262026 | Settled at frame 131 | Settled at frame 129 |
| 37 `combat_card_aim` | 7262026 | Settled at frame 124 | Settled at frame 124 |
| 38 `combat_keyword_popup` | 7262026 | Settled at frame 127 | Settled at frame 126 |
| 39 `combat_large_map` | 7262026 | Settled at frame 47 | Settled at frame 48 |
| 40 `combat_pause` | 7262026 | Settled at frame 55 | Settled at frame 55 |
| 41 `combat_settings_audio` | 7262026 | Settled at frame 46 | Settled at frame 49 |
| 42 `combat_settings_display` | 7262026 | Settled at frame 50 | Settled at frame 51 |
| 43 `combat_settings_accessibility` | 7262026 | Settled at frame 50 | Settled at frame 51 |
| 44 `combat_settings_controls` | 7262026 | Settled at frame 50 | Settled at frame 50 |
| 45 `combat_grimoire` | 7262026 | Settled at frame 55 | Settled at frame 54 |
| 46 `combat_character_gear` | 7262026 | Settled at frame 52 | Settled at frame 53 |
| 47 `combat_character_magic` | 7262026 | Settled at frame 49 | Settled at frame 49 |
| 48 `combat_character_skills` | 7262026 | Settled at frame 47 | Settled at frame 46 |
| 49 `combat_reward_three_cards` | 7262026 | Settled at frame 152 | Settled at frame 152 |
| 50 `combat_enemy_turn` | 7262026 | Settled at frame 2 | Settled at frame 2 |
