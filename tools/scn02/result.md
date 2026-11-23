# scn-02 room census evidence

The dark room captures reproduce with production room entry and with a game-written checkpoint. The reward case isolates the failure at Continue. The live victory uses a 1920 × 738 fit area and a 163.93 px tile width. Continuing the save from that victory uses a 1920 × 1 fit area and a 1 px tile width, matching the original inspection fixture.

## Requirement 1. Live entry and fixture comparison

The probe opens the production RunScene at 1920 × 1080 and 100% UI scale. It prepares the cleared room immediately before the target, resolves its real board door, and emits the board's normal tile-click signal. For reward it opens the pre-battle panel through the threshold door, starts combat, then plays a legal Pale Spark to finish the prepared encounter. The game resolves the damage, victory, and reward. The probe then opens a fresh RunScene via Continue on the game-written checkpoint for each case.

The settled board was visible both locally and in the scene tree in every sample. Its `combat_state` was populated in every sample. The rect is the production projected visual bounds `(x, y, width, height)` in screen pixels. The remaining 142 px in a collapsed board are explained by fixed-size HUD geometry. The fit size and tile width expose the scale of the actual board.

| Case | Path | Mode | Visible / empty | Scene props | Hero tile | Board rect (px) | Active doors | Message |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| reward | Live entry | `reward` | true / false | — | (4, 7) | 386.23, 202.69, 1147.54, 620.36 | (8, 4) | Unclaimed gear crumbles into dust.<br>Added 7 entries to the Grimoire. |
| reward | Continue on live save | `reward` | true / false | — | (4, 7) | 887.50, 503.87, 142.00, 37.86 | (8, 4) | Unclaimed gear crumbles into dust.<br>Added 7 entries to the Grimoire. |
| reward | Original fixture | `reward` | true / false | — | (4, 7) | 887.50, 503.87, 142.00, 37.86 | (8, 4) | Inspection fixture: post-combat reward reveal. |
| reward | Updated fixture | `reward` | true / false | — | (4, 7) | 887.50, 503.87, 142.00, 37.86 | (8, 4) | Unclaimed gear crumbles into dust. |
| campfire | Live entry | `campfire` | true / false | `campfire_bonfire` at (4, 4) | (1, 4) | 887.50, 361.37, 142.00, 39.28 | (4, 0) | — |
| campfire | Continue on live save | `campfire` | true / false | `campfire_bonfire` at (4, 4) | (1, 4) | 887.50, 361.37, 142.00, 39.28 | (4, 0) | — |
| campfire | Original fixture | `campfire` | true / false | `campfire_bonfire` at (4, 4) | (1, 4) | 887.50, 361.37, 142.00, 39.28 | (4, 0) | Inspection fixture: campfire. |
| campfire | Updated fixture | `campfire` | true / false | `campfire_bonfire` at (4, 4) | (1, 4) | 887.50, 361.37, 142.00, 39.28 | (4, 0) | — |
| treasure | Live entry | `treasure` | true / false | `relic_chest` at (4, 4) | (1, 4) | 887.50, 502.37, 142.00, 39.28 | (4, 0), (8, 4) | — |
| treasure | Continue on live save | `treasure` | true / false | `relic_chest` at (4, 4) | (1, 4) | 887.50, 502.37, 142.00, 39.28 | (4, 0), (8, 4) | — |
| treasure | Original fixture | `treasure` | true / false | `relic_chest` at (4, 4) | (1, 4) | 887.50, 502.37, 142.00, 39.28 | (4, 0), (8, 4) | Inspection fixture: relic cache. |
| treasure | Updated fixture | `treasure` | true / false | `relic_chest` at (4, 4) | (1, 4) | 887.50, 502.37, 142.00, 39.28 | (4, 0), (8, 4) | — |
| scavenger | Live entry | `room` | true / false | `scavenger_stall` at (5, 4) | (4, 1) | 890.50, 500.95, 142.00, 41.31 | (8, 4) | — |
| scavenger | Continue on live save | `room` | true / false | `scavenger_stall` at (5, 4) | (4, 1) | 890.50, 500.95, 142.00, 41.31 | (8, 4) | — |
| scavenger | Original fixture | `room` | true / false | `scavenger_stall` at (5, 4) | (1, 4) | 887.50, 500.95, 142.00, 41.31 | (8, 4) | — |
| scavenger | Updated fixture | `room` | true / false | `scavenger_stall` at (5, 4) | (4, 1) | 890.50, 500.95, 142.00, 41.31 | (8, 4) | — |

Fit area and tile width from the instrumented runs. The original fixture report recorded only the projected board bounds.

| Case | Live entry | Continue on live save | Updated fixture |
| --- | --- | --- | --- |
| reward | 1920 × 738 / 163.93 px | 1920 × 1 / 1.00 px | 1920 × 1 / 1.00 px |
| campfire | 1920 × 2 / 1.00 px | 1920 × 1 / 1.00 px | 1920 × 1 / 1.00 px |
| treasure | 1920 × 2 / 1.00 px | 1920 × 1 / 1.00 px | 1920 × 1 / 1.00 px |
| scavenger | 1920 × 2 / 1.00 px | 1920 × 2 / 1.00 px | 1920 × 2 / 1.00 px |

The four live probes emitted `LIVE_ENTRY_DOOR`, `LIVE_ENTRY_RESULT`, and `LIVE_RESUME_RESULT`. [Campfire](/private/tmp/labyrinth_codex/scn-02/proof-campfire.log) · [Treasure](/private/tmp/labyrinth_codex/scn-02/proof-treasure.log) · [Reward](/private/tmp/labyrinth_codex/scn-02/proof-reward.log) · [Scavenger](/private/tmp/labyrinth_codex/scn-02/proof-scavenger.log)

The board fit reads `desktop_hand_top` from the HUD budget. Fresh Continue into campfire, treasure, or reward cannot capture a budget because the capture guard accepts only `combat` and `room`. The fit height clamps to 1. The room-entry probes entered campfire and treasure from resumed, already-cleared predecessors, so they carried a 2 px fit height from those rooms. They still rendered at the solver's 1 px tile minimum. The live reward retained the fit measured during combat until Continue. These are headless framing measurements. Native pixel confirmation is outstanding. [RunScene framing](../../scripts/run_scene.gd#L3843) · [HUD budget](../../scripts/board_hud_budget.gd#L13)

## Requirements 2–4. Tool changes

- **2. Room entry.** Campfire and treasure already submit the same board state, props, hero pose, and doors as the observed live transition. The ordinary reward fixture already calls the production combat finish and preserves the resulting reward board. The one-pixel scale persists on the game's own checkpoint. Per the unit scope, the game framing repair is open. The generated Scavenger fixture now follows the generated route and calls the real room-entry transition, which fixes its hero entry tile from `(1, 4)` to `(4, 1)` for the census seed. The production choice panels and the authored inspection choices stay in use.
- **3. Messages.** The three choice fixtures keep the engine's notice instead of writing a fixture notice. The census also strips the fixture marker from its isolated copy before Continue, including for old fixture types. The live reward trial shows the real unclaimed-gear and Grimoire notices from that play. The census reward fixture shows the unclaimed-gear notice generated by its prepared combat. The Grimoire notice in the live trial comes from discoveries during the earlier live pre-battle and combat screens.
- **4. Legacy rooms.** The production section map generates `scavenger` and has no Blacksmith or Arcanist types. Old saves migrate both merchants to the Scavenger. The catalog and `--help` now describe the legacy omission and all 48 retained PNG names keep their original numbering. [Generation](../../scripts/section_map_graph.gd#L44) · [Save repair](../../scripts/run_engine.gd#L429)

## Proof for the design owner

Run in a desktop session. The driver uses the existing visual runner and per-shot size contracts. The launcher prints a fresh output folder containing the four PNGs, logs, and manifest.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/scn-02 && /private/tmp/labyrinth_codex/scn-02/native.sh
```

The additional reward variant uses the existing census entry point.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/scn-02 && SCN01_TASK_ID=scn-02 python3 tools/scn01/census.py --size 1920x1080 --only combat_reward_three_cards
```

## Headless checks

- Original census with the five affected shots. `CENSUS RESULT: PASS; 5/5 shots succeeded; 0 capped` [Manifest](/private/tmp/labyrinth_codex/scn-02/before/manifest.json)
- Director launcher with `--dry-run`. `CENSUS RESULT: PASS; 4/4 shots succeeded; 0 capped` [Log](/private/tmp/labyrinth_codex/scn-02/native-verified.log) · [Manifest](/private/tmp/labyrinth_codex/scn-02/20261123T111610391212Z/manifest.json)
- Additional three-card reward census. `CENSUS RESULT: PASS; 1/1 shots succeeded; 0 capped` [Log](/private/tmp/labyrinth_codex/scn-02/three-card-reward-verified.log) · [Manifest](/private/tmp/labyrinth_codex/scn-02/three-card-reward-verified/manifest.json)
- Existing fixture tests. `Ran 12 tests in 34.379s` and `OK`. [Log](/private/tmp/labyrinth_codex/scn-02/inspection-fixture-final.log)
- Python default group. `INPUT GROUP default: always run`, `Ran 192 tests in 84.687s`, and `FAILED (failures=4)`. Two program-runner checks hit the 15-second parent timeout. The Godot runner cleanup check reported `Child did not start`. All three passed in the targeted recheck with `Ran 3 tests in 13.680s` and `OK`. The fourth failure reports the two missing tracked scn-01 UIDs. Those sidecars are supplied in the worktree and the same inventory assertion passes when they and the new probe sidecars are included. The tracked-files check requires their addition to Git by the design owner. The sandbox also denied the timing-cache write. [Default group](/private/tmp/labyrinth_codex/scn-02/python-default.log) · [Runner recheck](/private/tmp/labyrinth_codex/scn-02/runner-recheck.log)
- Rules text lint in the default group. `PASS: Rules text lint (455 existing hits)`. Windows typed arrays. `TYPED ARRAY SCAN: 6 scripts; 0 new; 13 pre-existing`. [Typed array log](/private/tmp/labyrinth_codex/scn-02/typed-arrays-final.log)

The headless runs produced manifests and logs. The historical screenshots were inspected from [the original scn-01 census](/private/tmp/labyrinth_codex/scn-01/20261123T103226618634Z/manifest.json). No new PNG was captured.

## Chosen defaults

- The headless probe uses the census seed `7262026` and the four original room coordinates. Debug preparation advances the generated route to the cleared predecessor.
- The last-hit proof puts the first foe at `(3, 6)` with 1 Health and 0 Block, marks the other foes defeated, and puts Pale Spark in hand. The scene receives the normal card and tile inputs.
- Headless proof uses a 60 fps frame cap, a 12-second condition deadline, and the existing visual scale. The scn-02 launcher uses a 180-second headless engine watchdog after observed cold startups exceeded the scn-01 60-second watchdog.

There are no `TODO_DESIGN_*` placeholders.
