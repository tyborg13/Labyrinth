# rd-07 implementation handoff

All changes remain uncommitted on `codex/rd-07`. No preflight, Git mutation,
reviewer, signoff, queue edit, windowed run, native capture or publication was
performed. The design owner owns those completion steps.

## Acceptance criteria

1. Health props have their own `terrain_<id>` controller entries. Pointer
   footprint/body, controller focus, selected-card affectable keys, Details and
   a 1.2s real Health-change hold drive them. Enemy attack-preview tiles do not.
   The baseline reproduction is preserved by `reproduce_props.sh`, which reads
   HEAD without writing Git and temporarily materializes the original board.
   Observed baseline lines:
   ```text
   RD07 BASELINE hover=(3, 4) prop_bars=[] attack_tiles=[]
   RD07 BASELINE hover=(3, 3) prop_bars=[(3, 4)] attack_tiles=[(2, 1), (1, 2), (2, 2), (1, 3), (2, 3), (3, 3), (4, 3), (1, 4), (2, 4), (3, 4)]
   ```
   Cause: terrain was absent from rd-05's visibility controller. Its legacy bar
   predicate used damaged HP, damage previews or `attack_tiles`; enemy hover
   populates the latter. Prop hover had no predicate or controller hook.
2. Statuses and defenses use the exact full-plate layout in all visibility
   states, at full opacity. Health/frame opacity is independent. The former
   feet-row repaint was removed. The full tooltip stays registered at rest;
   empty status descriptions fall back to the existing action/keyword library.
   Status and defense hit regions inspect their owning actor. Terrain uses its
   existing prop frame/insets with the shared status/defense layout helpers.
3. Both ordinal paint entry points are removed. Legacy invisible reservations
   remain to preserve plate positions. Threat-area tags and rail times retain
   their existing behavior.
4. Every matching rail slot follows the visibility controller's inspection
   signal. Its existing slash edge becomes `UiPalette.GOLD_BRIGHT`, full alpha,
   immediately, and returns with a 0.12s quadratic ease-out. No scale or glow.
   The same signal covers player, friendly, enemy and repeated entries.
5. Contextual markers bypass the silhouette solver. They use footprint bounds:
   center x; front y minus 0.12 tile height. Only the existing 32px action disc
   draws at rest, with the original danger/neutral ring computation. The full
   existing tab contents slide right in a clipped child canvas over 0.12s
   quadratic ease-out in either direction. The disc never moves. Inspection,
   rail hover/focus, Details and the hovered card target unfurl it; the whole
   affectable set and change hold do not. `Always` retains its original full
   chip renderer and placement. Existing focused intent/title behavior remains.
6. Full plate geometry stays reserved. The proof compares bar positions across
   settings. rd-03's actor canvases also share the visibility/layout controller;
   statuses and contextual tabs follow the same 50% HUD step-back.
7. No new per-frame board invalidation. Tab clipping/content transforms and rail
   edge tweens change their own canvases. Matched 120-frame idle windows produce:
   ```json
   {"ambient":60,"foreground":60,"ground":16,"hud":60,"overlays":60,"scene_tile":128}
   ```
   The dictionary is identical under both settings; visibility adds zero idle
   invalidations in each. `tools/rd05/proof_board.gd` supplies the same fixed
   debug-only cadence to both runs.
8. UI identity lint passes without raising or changing its baseline. No new
   colour literals, assets, icons, fonts, audio, mechanics or analytics producers.
   Native visual inspection and identity judgment remain owner work.

## Integration and old proof compatibility

The reported `configure` parse failure and subsequent null `get` were reproduced.
This checkout had no `.godot` cache. Seeding the existing
`pt2-export/.godot` cache with a copy-on-write copy resolved it, with no editor
scan or unrelated source change. The original rd-05 proof then passed 103/103
before implementation.

After rd-07, the protected original rd-05 proof passes 102/103: only
`Intent chip geometry unchanged across settings` fails. That assertion conflicts
with requirement 5. `rd05_regression.gd` explicitly adapts only that assertion to
exact contextual footprint anchors and retains all other original checks. The
original proof is unchanged; the adaptation is logged rather than hidden.

The focused suite's two `Umbra keeps the still Unknown Presence texture`
failures also reproduce on the read-only HEAD comparison prepared by
`prepare_baseline.py`. Do not rewrite those assertions as part of rd-07.

## Headless commands

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rd-07`.
Every Godot command remains under the task runner. No full suite is requested.

```sh
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/board_ui_proof.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/rd05_regression.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd03/aim_focus_proof.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd05/focused_checks.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/tooltip_checks.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd05/settings_checks.gd
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/capture.gd -- --check-only
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/capture.gd -- --check-only --zekarion
python3 tools/godot_task_runner.py --task-id rd-07 --stream -- godot --headless --path . --script tools/rd07/capture.gd -- --check-only --clip --fixed-fps 30
python3 tests/test_ui_identity_lint.py
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rd-07/python-audit
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/rd-07/python-default
```

No new Python test modules were added; the isolation audit accepts all 56
existing modules. The default run selects 20 modules, not the full suite.

## Proof for the design owner

These fixtures were generated and certified headlessly. The first is five
ordinary Section I foes and a wooden box with Health; the second is Zekarion's
production arena, including its authored encounter context. Recreate exactly:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && python3 tools/inspection_fixture.py --task-id rd-07 --run-id rd-07-combat --manifest /private/tmp/labyrinth_codex/rd-07/combat.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,ember_rain,sidestep_slash,brace --player-position 2:3 --enemy-types crawler,warden,crawler,crawler,crawler --enemy-positions 3:3,5:5,4:3,6:3,3:5 --terrain wooden_box@3:4 --umbra-stage clear --summary 'rd-07 board UI five foes and Health prop'
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && python3 tools/inspection_fixture.py --task-id rd-07 --run-id rd-07-dragon --manifest /private/tmp/labyrinth_codex/rd-07/dragon.json --scenario dragon --dragon-id zekarion --hand quick_stab,brace --player-position 3:4 --umbra-stage clear --summary 'rd-07 Zekarion real arena board UI'
```

Native commands below have **not** been run. All use Metal/mobile, cel look,
1920x1080, 100% UI scale, and timeout 300. `capture_native.sh` executes the same
commands with logs and rejects `Cel look variant unavailable` in the log.
It also finalizes the movie when invoked with `movie`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --godot tools/rd07/native_capture.sh --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd07/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-07/stills_manifest.json tools/rd07/capture.gd --task-id rd-07
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --godot tools/rd07/native_capture.sh --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd07/zekarion_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-07/zekarion_manifest.json tools/rd07/capture.gd --task-id rd-07 -- --zekarion
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --godot tools/rd07/movie_capture.sh --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd07/movie_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-07/movie_manifest.json tools/rd07/capture.gd --task-id rd-07 -- --clip --fixed-fps 30
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && python3 tools/rd07/finalize_movie.py
```

Convenient guarded equivalents:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && sh tools/rd07/capture_native.sh stills
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && sh tools/rd07/capture_native.sh zekarion
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && sh tools/rd07/capture_native.sh movie
```

Expected capture paths, all below `/private/tmp/labyrinth_codex/rd-07/`:

- `stills/01_rest_always.png`, `02_rest_on_hover_and_aim.png`.
- `stills/03_enemy_hover.png`: unfurled marker, plate and rail highlight.
- `stills/04_crate_hover.png`, `05_enemy_beside_crate.png`.
- `stills/06_hero_block_rest.png`, `07_hero_block_hover.png`: identical icon positions.
- `stills/08_status_tooltip.png`, `09_ranged_aim.png`, `09_details.png`.
- `zekarion/10_zekarion_rest.png`, `11_zekarion_hover.png`.
- `clip/frames/hover_000.png` through `hover_089.png`, 90 consecutive native
  MovieWriter frames at 30 fps (3 seconds). No resampling. Startup frames are
  removed by `finalize_movie.py`; timestamps and draw-frame continuity are checked.
- Each capture directory includes `semantics.json`; headless `--check-only`
  emits setup semantics and never claims pixels. The native run replaces it.

The owner play command uses the separate profile **Escape the Umbra Playtest
rd-07**. It was not run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-07 && RD07_PROFILE_HOME="$HOME" LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id rd-07 --timeout 0 --allow-steam --stream -- tools/rd07/play_profile.sh --path . --windowed --resolution 1920x1080 --rendering-driver metal --rendering-method mobile
```

## TODO_DESIGN and chosen defaults

No `TODO_DESIGN_*` placeholders were necessary. Runtime geometry, colour,
contents, timing and easing come from the brief or the existing full plates and
chips. No art or design-owner data was rewritten.

Only debug/proof defaults were chosen: fixture seed 7262026, room (1,0), the
roster/positions/hands in the commands above and clear Umbra; hero Block 7,
enemy Bleed 2/Expose 1 in the in-memory status proof/capture fixture; 30 startup
frames, two input-settling frames, 0.25s deterministic fade settling, 3s hold
settling, 0.16s edge/tab settling and 0.8s tooltip wait; outside pointer
(-1000,-1000); movie pointer enters at frame 15 and leaves at 60, traveling six
frames over two tile widths; task-local output/copy paths. The inherited fixed
proof delta is 1/60s; idle sampling resets its cached frame indices along with
the clock so both windows start at the same presentation phase. A one-tile
world-position offset is used only to prove marker interpolation. Required 120 idle frames, 1920x1080, 100% UI, 90 movie
frames/30fps and 300s native timeout are brief values.

## Open issues

Native execution, visual inspection, movie viewing and the UI identity judge
are pending the design owner, as required by the sandbox/task split. The original
rd-05 cross-setting-geometry assertion needs the owner's update at integration.
Existing Unknown Presence failures are preserved. Full Godot/Python suites,
commit, peer review, inspection handoff and publication remain owner work.

## Observed verification results

Logs and JSON are under `/private/tmp/labyrinth_codex/rd-07/`.

| Check | Observed result |
| --- | --- |
| `board_ui_proof.gd` | `RD07 BOARD UI: PASS (153 checks, 0 failures)` |
| Final real composition | Hero clear; all five ordinary foes clear; one Health box |
| Real danger coverage | `enemy_1` dangerous; `enemy_2` through `enemy_5` neutral |
| rd-03 integration | `RD03 AIM FOCUS: PASS (658 checks, 0 failures)` |
| rd-05 adapted regression | `RD05 RD07 REGRESSION: PASS (103 checks, 0 failures)` |
| Original rd-05, unchanged | `RD05 PLATE VISIBILITY: FAIL (103 checks, 1 failures)`; incompatible cross-setting chip-equality assertion |
| Focused existing suite | `RD05 FOCUSED: FAIL (75377 checks, 2 failures)`; identical two Unknown Presence failures on HEAD |
| Tooltip consistency | `RD07 TOOLTIP CONSISTENCY: PASS (72 checks, 0 failures)` |
| Board tile tooltips | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` |
| Settings | `TEST RESULT: PASS` |
| Stills setup | `RD07 CAPTURE SETUP: PASS (10 samples, headless; no images)` |
| Zekarion setup | `RD07 CAPTURE SETUP: PASS (2 samples, headless; no images)` |
| Movie setup | `RD07 CAPTURE SETUP: PASS (90 samples, headless; no images)` |
| UI identity | `Ran 25 tests`; `OK`; baseline unchanged |
| Python isolation audit | `ISOLATION AUDIT: 56 modules`; selected default: 20 modules |
| Python default group | `Ran 189 tests in 66.069s`; `FAILED (failures=1)` |
| Isolated retry | `Ran 1 test in 4.025s`; `OK` |
| Shell/Python helper syntax and whitespace | Exit 0 for `sh -n`, `py_compile` with task-local pycache, and `git diff --check` |

The Python default failure was
`test_godot_task_runner.GodotTaskRunnerTests.test_killing_runner_mid_godot_test_leaves_no_godot_child`:
`AssertionError: False is not true : Child did not start`. It passed unchanged in
isolation after the concurrent jobs, as recorded in `python-isolated.log`.
The group itself is still recorded as failed; it was not rerun wholesale.
Its optional timing-cache write also reports the expected Git-metadata sandbox
restriction. No test assertion or timeout was changed.

The headless engine logs include the sandbox's macOS CA-certificate diagnostic;
board tooltip checks also retain existing missing-glossary warnings for bramble
and ice_pillar. None is claimed fixed by rd-07.
