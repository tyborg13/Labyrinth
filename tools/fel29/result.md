# fel-29 loading reveal

Implemented in `codex/fel-29`. The worktree changes are uncommitted.

## Root causes

Take 00065 at waypoint `(1, -1)` and take 00072 after the event both show
the loading screen, a dim backdrop, the room, then the map. The two supplied
contact sheets show the board absent during the dim interval and restored
under the crossfade.

The deferred auto-open was treating the initial map as an in-play modal.
`_open_large_map()` made the opaque scrim visible. The map's covered-board
optimization then suppressed the board's render item immediately.
`_maybe_present_section_map()` called `fade_in()`, resetting the map alpha
to zero. The disabled RunScene prevented the map's process callback from
restoring the board and prevented the tween from advancing. The loading
cover began its fade over the resulting dim backdrop. At handoff, processing
restored the board and advanced the map's separate 0.32-second fade.

The old cover also inherited one alpha on every child draw. Its art, tint,
scrims and label each blended with the destination. Those operations could
darken the result below a blend of the two assembled screens. The cover now
uses Godot's transparent canvas grouping during the existing readiness wait.
The reveal tweens only the composite alpha and holds the last loading-dot pose.
[Godot 4.6 CanvasGroup implementation](https://github.com/godotengine/godot/blob/4.6-stable/scene/2d/canvas_group.cpp)

## Requirements

| Requirement | Implementation and evidence |
|---|---|
| 1. One dissolve and input handoff | The loading cover owns the original 0.22-second reveal across all landing screens. Gameplay processing, GUI input and the existing music handoff resume together on the completion frame. The already-open landing map covers the board, HUD and title. Reduced motion cuts on the handoff frame. The existing in-play map fade is 320 ms in both builds. Native verification owns the pixel, frame-time and 1.2-second waypoint expectations. |
| 2. Diagnose the dim interval and flash | The map alpha changed after board suppression. Both were waiting on a disabled scene. The cover's inherited child alpha was a separate compositing problem. |
| 3. Quit and save | The cover retains ownership of quit cancellation until handoff. The focused startup teardown and save/resume tests exercise cancellation and durable boundaries. |
| 4. Windows arrays and UI identity | The new tween list is explicitly typed and probe arrays have typed declarations or use plain `Array`. The UI identity ratchet passed without a baseline update. |

The normal map decision and focus routines still run. The pre-battle entry
tween is completed under the cover only for a saved pre-battle screen. The existing
opening-dialogue entrance starts on the run's own clock, and a saved section
transition keeps its original entry and arrival. Loading phases, the loading
copy and its dots cycle, room cuts, audio and music timing constants, persistence,
analytics and guided gates retain their existing implementation.

## First screens

| Entry | First screen and path | Proof case |
|---|---|---|
| Continue at a waypoint or other eligible room | Opaque section map under the cover, using the existing auto-open policy. | `map`, `reduced` |
| Continue in a fight | Installed combat board and settled hand and dock. | `combat` |
| Continue from the saved pre-battle boundary | Existing preview and focus gate settle under the cover. | `prebattle` |
| Continue with a pending event | Existing event view at its completed entrance pose. | `event` |
| Continue in the Scavenger | Existing shop controls over the room. | `shop` |
| Continue at a rest site | Existing campfire board and choices. | `rest` |
| Continue with unclaimed treasure | The existing chest tween reaches its final pose and publishes relic choices under the cover. | `treasure` |
| New Game | Opening room with the dialogue prepared at its existing first pose. The dialogue entrance and text progression run after handoff. The ordinary room path owns openings without dialogue. | `new_game` |
| Continue after a committed dragon claim and before section entry | The saved claim starts the existing section transition. Its opening pose is covered by the loading layer until its clock can run. | `section` |
| Open an auto-presented map during play | The clear-event action returns to the map with the existing 0.32-second fade. | `play_map` |

Pending combat, reward and escape continuations use their existing resume
paths. The cover adds no rule, save or input decision to those continuations.

## Files

- `scripts/menu_run_transition.gd` composites the loading cover and keeps
  it above a resumed section transition.
- `scripts/run_scene.gd` presents the initial map without the in-play
  crossfade and settles the saved pre-battle, event and chest entrances before reveal.
- `tools/fel29/probe.gd`, `tools/fel29/reveal_metrics.gd` and their
  `.gd.uid` files drive the actual title input and observe readiness.
- `tools/fel29/native.sh`, `tools/fel29/native_report.py` and
  `tools/fel29/proof_contract.json` capture, analyze and pair native takes.
- `tools/fel29/result.md` records the implementation and proof.

## Chosen defaults

- The probe borrows the seed-15 census checkpoints. Take 00065 uses
  checkpoint 00063, combat uses 00019, and the section case uses the claimed
  dragon fixture from the existing section transition suite.
- The harness uses a 60 fps cap, three title layout frames, a 30-second
  observation deadline and a 750 ms audio tail. The native runner allows
  90 seconds per take. The mid-reveal quit waits for five blend samples.
- A map frame must cover the viewport within one logical pixel and be within
  0.001 of unit alpha. Review strips use six columns of 320×180 thumbnails.
- The cover canvas takes the next layer above section travel, 101.
  Canvas grouping uses Godot's 5 px clear margin.

## Design placeholders

No `TODO_DESIGN` values were added.

## Proof for the design owner

Run with the native renderer and default audio driver. The wrapper uses the
1920×1080 proof contract, 100% UI scale and `LABYRINTH_CEL_LOOK=all`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-29 && bash tools/fel29/native.sh /Users/borgerding/workspace/Labyrinth.worktrees/release "$PWD/output/fel29/native"
```

The wrapper uses the fel-20 descent checkpoints in the sibling worktree.
Set `FEL29_CHECKPOINTS` to the same checkpoint directory at an alternate
location if needed. Each take (`map`, `combat`, `new_game`) produces
`release-left.mp4` with separate release and branch audio tracks.
Each build keeps `reveal-30fps.png`, `renderer-proof.png`,
`visual-proof.json`, `00001.json`, and its runner and measurement logs.
Input is injected through the viewport. Raw luminance samples use a
six-level tolerance on a 0–255 scale. Room-frame measurements use the
presented map opacity, coverage and room-title state.

The sandbox provides headless presentation samples. Native luminance and
timing remain open for the owner's real-renderer run. Headless
`unsafe_blend_frames` detects unsafe composition from draw state. The
headless clock includes cold asset preparation, so it supplies no native
1.2-second timing evidence. The reference take 00065 JSON recorded
1216.007 ms to input and the contact sheets show the map continuing to fade
after that input was already available.

The media postprocessor was exercised using the supplied 00065 video and
audio with fixture timestamps. It produced a 3840×1080 pair with two audio
streams and a 1920×540 review strip under
`output/fel29/media-fixture/`.

## Headless commands

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-29
release=/Users/borgerding/workspace/Labyrinth.worktrees/release
checkpoints=/Users/borgerding/workspace/Labyrinth.worktrees/fel-20/tools/fel20/captures/headless-descent/checkpoints
proof="$PWD/output/fel29/verified"
mkdir -p "$proof"
export LABYRINTH_CEL_LOOK=all

python3 tools/godot_task_runner.py --task-id fel-29 --project "$release" --stream --timeout 240 -- godot --headless --path "$release" --script "$PWD/tools/fel29/probe.gd" -- --output-dir "$proof/release" --checkpoints "$checkpoints"
python3 tools/godot_task_runner.py --task-id fel-29 --stream --timeout 240 -- godot --headless --path . --script tools/fel29/probe.gd -- --output-dir "$proof/branch" --checkpoints "$checkpoints" --before "$proof/release/metrics.json"
```

Use fresh output directories for repeated runs. Release is the negative
control and exits 1 after writing metrics.

The following additional runs used `out="$PWD/output/fel29/final"`.
The navigation runs take their comparison values from the pointer baseline.
The keyboard run uses Tab both to focus Continue and to seed focus in the map.
The controller run presses A and checks the map's initial focus owner.

```bash
out="$PWD/output/fel29/final"
for device in keyboard controller; do
  python3 tools/godot_task_runner.py --task-id fel-29 --project "$PWD" --stream --timeout 240 -- godot --headless --path "$PWD" --script "$PWD/tools/fel29/probe.gd" -- --output-dir "$out/$device" --checkpoints "$checkpoints" --case map --map-input "$device" --before "$out/release/metrics.json"
done
for point in start mid; do
  python3 tools/godot_task_runner.py --task-id fel-29 --project "$release" --stream --timeout 240 -- godot --headless --path "$release" --script "$PWD/tools/fel29/probe.gd" -- --output-dir "$out/release-quit-$point" --checkpoints "$checkpoints" --case map --quit-at "$point"
  python3 tools/godot_task_runner.py --task-id fel-29 --project "$PWD" --stream --timeout 240 -- godot --headless --path "$PWD" --script "$PWD/tools/fel29/probe.gd" -- --output-dir "$out/branch-quit-$point" --checkpoints "$checkpoints" --case map --quit-at "$point"
  cmp "$out/release-quit-$point/map/run.save" "$out/branch-quit-$point/map/run.save"
done
```

### Release negative control

Full log in `output/fel29/verified/release.log`.

```text
FEL29 map unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 map room_frames before=unmeasured after=33 FAIL
FEL29 map fades before=unmeasured after=2 FAIL
FEL29 map covered_first_screen before=unmeasured after=false FAIL
FEL29 map ready_ms before=unmeasured after=3715 PASS
FEL29 map reveal_ms before=unmeasured after=232 PASS
FEL29 map max_frame_ms before=unmeasured after=23.6 PASS
FEL29 combat unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 combat room_frames before=unmeasured after=0 PASS
FEL29 combat fades before=unmeasured after=1 PASS
FEL29 combat covered_first_screen before=unmeasured after=true PASS
FEL29 combat ready_ms before=unmeasured after=1392 PASS
FEL29 combat reveal_ms before=unmeasured after=235 PASS
FEL29 combat max_frame_ms before=unmeasured after=22.2 PASS
FEL29 event unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 event room_frames before=unmeasured after=0 PASS
FEL29 event fades before=unmeasured after=2 FAIL
FEL29 event covered_first_screen before=unmeasured after=false FAIL
FEL29 event ready_ms before=unmeasured after=1543 FAIL
FEL29 event reveal_ms before=unmeasured after=238 PASS
FEL29 event max_frame_ms before=unmeasured after=23.3 PASS
FEL29 new_game unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 new_game room_frames before=unmeasured after=0 PASS
FEL29 new_game fades before=unmeasured after=1 PASS
FEL29 new_game covered_first_screen before=unmeasured after=true PASS
FEL29 new_game ready_ms before=unmeasured after=3349 PASS
FEL29 new_game reveal_ms before=unmeasured after=231 PASS
FEL29 new_game max_frame_ms before=unmeasured after=17.9 PASS
FEL29 reduced unsafe_blend_frames before=unmeasured after=0 PASS
FEL29 reduced room_frames before=unmeasured after=8 FAIL
FEL29 reduced fades before=unmeasured after=1 FAIL
FEL29 reduced covered_first_screen before=unmeasured after=false FAIL
FEL29 reduced ready_ms before=unmeasured after=1056 PASS
FEL29 reduced reveal_ms before=unmeasured after=1 PASS
FEL29 reduced max_frame_ms before=unmeasured after=20.1 PASS
FEL29 play_map gameplay_fade_ms before=unmeasured after=320 PASS
FEL29 play_map gameplay_fade_wall_ms before=unmeasured after=303 PASS
FEL29 prebattle unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 prebattle room_frames before=unmeasured after=0 PASS
FEL29 prebattle fades before=unmeasured after=2 FAIL
FEL29 prebattle covered_first_screen before=unmeasured after=false FAIL
FEL29 prebattle ready_ms before=unmeasured after=1696 FAIL
FEL29 prebattle reveal_ms before=unmeasured after=234 PASS
FEL29 prebattle max_frame_ms before=unmeasured after=20.4 PASS
FEL29 rest unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 rest room_frames before=unmeasured after=0 PASS
FEL29 rest fades before=unmeasured after=1 PASS
FEL29 rest covered_first_screen before=unmeasured after=true PASS
FEL29 rest ready_ms before=unmeasured after=1529 PASS
FEL29 rest reveal_ms before=unmeasured after=232 PASS
FEL29 rest max_frame_ms before=unmeasured after=19.3 PASS
FEL29 shop unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 shop room_frames before=unmeasured after=0 PASS
FEL29 shop fades before=unmeasured after=1 PASS
FEL29 shop covered_first_screen before=unmeasured after=true PASS
FEL29 shop ready_ms before=unmeasured after=1505 PASS
FEL29 shop reveal_ms before=unmeasured after=237 PASS
FEL29 shop max_frame_ms before=unmeasured after=19.6 PASS
FEL29 treasure unsafe_blend_frames before=unmeasured after=13 FAIL
FEL29 treasure room_frames before=unmeasured after=0 PASS
FEL29 treasure fades before=unmeasured after=1 PASS
FEL29 treasure covered_first_screen before=unmeasured after=false FAIL
FEL29 treasure ready_ms before=unmeasured after=2111 FAIL
FEL29 treasure reveal_ms before=unmeasured after=232 PASS
FEL29 treasure max_frame_ms before=unmeasured after=28.1 PASS
FEL29 section unsafe_blend_frames before=unmeasured after=12 FAIL
FEL29 section room_frames before=unmeasured after=0 PASS
FEL29 section fades before=unmeasured after=1 PASS
FEL29 section covered_first_screen before=unmeasured after=false FAIL
FEL29 section ready_ms before=unmeasured after=1554 PASS
FEL29 section reveal_ms before=unmeasured after=218 PASS
FEL29 section max_frame_ms before=unmeasured after=20.5 PASS
FEL29 FAIL cases=11 failed=10
```

### Branch headless proof

Full log in `output/fel29/verified/branch.log`.

```text
FEL29 map unsafe_blend_frames before=13.0 after=0 PASS
FEL29 map room_frames before=33.0 after=0 PASS
FEL29 map fades before=2.0 after=1 PASS
FEL29 map covered_first_screen before=false after=true PASS
FEL29 map ready_ms before=3715.0 after=3987 PASS
FEL29 map reveal_ms before=232.0 after=236 PASS
FEL29 map max_frame_ms before=23.6 after=19.5 PASS
FEL29 combat unsafe_blend_frames before=13.0 after=0 PASS
FEL29 combat room_frames before=0.0 after=0 PASS
FEL29 combat fades before=1.0 after=1 PASS
FEL29 combat covered_first_screen before=true after=true PASS
FEL29 combat ready_ms before=1392.0 after=1360 PASS
FEL29 combat reveal_ms before=235.0 after=232 PASS
FEL29 combat max_frame_ms before=22.2 after=18.8 PASS
FEL29 event unsafe_blend_frames before=13.0 after=0 PASS
FEL29 event room_frames before=0.0 after=0 PASS
FEL29 event fades before=2.0 after=1 PASS
FEL29 event covered_first_screen before=false after=true PASS
FEL29 event ready_ms before=1543.0 after=1367 PASS
FEL29 event reveal_ms before=238.0 after=230 PASS
FEL29 event max_frame_ms before=23.3 after=20.7 PASS
FEL29 new_game unsafe_blend_frames before=13.0 after=0 PASS
FEL29 new_game room_frames before=0.0 after=0 PASS
FEL29 new_game fades before=1.0 after=1 PASS
FEL29 new_game covered_first_screen before=true after=true PASS
FEL29 new_game ready_ms before=3349.0 after=2722 PASS
FEL29 new_game reveal_ms before=231.0 after=231 PASS
FEL29 new_game max_frame_ms before=17.9 after=19.9 PASS
FEL29 reduced unsafe_blend_frames before=0.0 after=0 PASS
FEL29 reduced room_frames before=8.0 after=0 PASS
FEL29 reduced fades before=1.0 after=0 PASS
FEL29 reduced covered_first_screen before=false after=true PASS
FEL29 reduced ready_ms before=1056.0 after=1150 PASS
FEL29 reduced reveal_ms before=1.0 after=1 PASS
FEL29 reduced max_frame_ms before=20.1 after=16.0 PASS
FEL29 play_map gameplay_fade_ms before=320.0 after=320 PASS
FEL29 play_map gameplay_fade_wall_ms before=303.0 after=301 PASS
FEL29 prebattle unsafe_blend_frames before=13.0 after=0 PASS
FEL29 prebattle room_frames before=0.0 after=0 PASS
FEL29 prebattle fades before=2.0 after=1 PASS
FEL29 prebattle covered_first_screen before=false after=true PASS
FEL29 prebattle ready_ms before=1696.0 after=1381 PASS
FEL29 prebattle reveal_ms before=234.0 after=234 PASS
FEL29 prebattle max_frame_ms before=20.4 after=18.8 PASS
FEL29 rest unsafe_blend_frames before=13.0 after=0 PASS
FEL29 rest room_frames before=0.0 after=0 PASS
FEL29 rest fades before=1.0 after=1 PASS
FEL29 rest covered_first_screen before=true after=true PASS
FEL29 rest ready_ms before=1529.0 after=2140 PASS
FEL29 rest reveal_ms before=232.0 after=234 PASS
FEL29 rest max_frame_ms before=19.3 after=29.8 PASS
FEL29 shop unsafe_blend_frames before=13.0 after=0 PASS
FEL29 shop room_frames before=0.0 after=0 PASS
FEL29 shop fades before=1.0 after=1 PASS
FEL29 shop covered_first_screen before=true after=true PASS
FEL29 shop ready_ms before=1505.0 after=1925 PASS
FEL29 shop reveal_ms before=237.0 after=235 PASS
FEL29 shop max_frame_ms before=19.6 after=21.2 PASS
FEL29 treasure unsafe_blend_frames before=13.0 after=0 PASS
FEL29 treasure room_frames before=0.0 after=0 PASS
FEL29 treasure fades before=1.0 after=1 PASS
FEL29 treasure covered_first_screen before=false after=true PASS
FEL29 treasure ready_ms before=2111.0 after=1603 PASS
FEL29 treasure reveal_ms before=232.0 after=243 PASS
FEL29 treasure max_frame_ms before=28.1 after=23.5 PASS
FEL29 section unsafe_blend_frames before=12.0 after=0 PASS
FEL29 section room_frames before=0.0 after=0 PASS
FEL29 section fades before=1.0 after=1 PASS
FEL29 section covered_first_screen before=false after=true PASS
FEL29 section ready_ms before=1554.0 after=1571 PASS
FEL29 section reveal_ms before=218.0 after=234 PASS
FEL29 section max_frame_ms before=20.5 after=19.3 PASS
FEL29 PASS cases=11
```

### Keyboard focus

Full log in `output/fel29/final/keyboard.log`.

```text
FEL29 map unsafe_blend_frames before=13.0 after=0 PASS
FEL29 map room_frames before=33.0 after=0 PASS
FEL29 map fades before=2.0 after=1 PASS
FEL29 map covered_first_screen before=false after=true PASS
FEL29 map ready_ms before=4103.0 after=4122 PASS
FEL29 map reveal_ms before=233.0 after=234 PASS
FEL29 map max_frame_ms before=30.4 after=19.8 PASS
FEL29 PASS cases=1
```

### Controller focus

Full log in `output/fel29/final/controller.log`.

```text
FEL29 map unsafe_blend_frames before=13.0 after=0 PASS
FEL29 map room_frames before=33.0 after=0 PASS
FEL29 map fades before=2.0 after=1 PASS
FEL29 map covered_first_screen before=false after=true PASS
FEL29 map ready_ms before=4103.0 after=3954 PASS
FEL29 map reveal_ms before=233.0 after=233 PASS
FEL29 map max_frame_ms before=30.4 after=20.5 PASS
FEL29 PASS cases=1
```

### Close during reveal

The probe emitted the real window close signal at the start and during the dissolve. The durable save files matched release byte for byte at both points.

```text
FEL29 QUIT start SHA256=8e2a4929cf65b543caf0d3156757d614587afbf3543dad819b864e1e3673d657
FEL29 QUIT start SHA256=8e2a4929cf65b543caf0d3156757d614587afbf3543dad819b864e1e3673d657
FEL29 QUIT start byte-for-byte save match PASS
FEL29 QUIT mid SHA256=8e2a4929cf65b543caf0d3156757d614587afbf3543dad819b864e1e3673d657
FEL29 QUIT mid SHA256=8e2a4929cf65b543caf0d3156757d614587afbf3543dad819b864e1e3673d657
FEL29 QUIT mid byte-for-byte save match PASS
```

## Focused tests

From the task worktree, each test below ran through the task runner.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-29
for test in main_menu_input_test main_menu_resume_test save_resume_boundary_test section_transition_test section_map_v2_test section_history_preparation_test opening_boon_test opening_boon_recovery_test combat_hud_dialogue_input_test guided_combat_tutorial_integration_test contextual_combat_tutorial_test pre_battle_view_test pre_battle_semantics_test; do
  python3 tools/godot_task_runner.py --task-id fel-29 --stream -- godot --headless --path . --script "tests/$test.gd"
done
python3 tests/test_ui_identity_lint.py
python3 tools/ui_identity_lint.py check
python3 tests/test_rules_text_lint.py
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$PWD/output/fel29/verified/python-default"
bash -n tools/fel29/native.sh
git diff --check
```

| Test | Exact result |
|---|---|
| `main_menu_input_test.gd` | `TEST RESULT: PASS — main menu input and startup transitions` |
| `main_menu_resume_test.gd` | `TEST RESULT: PASS — main menu resume safety` |
| `save_resume_boundary_test.gd` | `TEST RESULT: PASS — committed save/resume boundary matrix` |
| `section_transition_test.gd` | `SECTION TRANSITION RESULT: 0 failures` |
| `section_map_v2_test.gd` | `Section map v2 suite: 0 failures (seeds 0..64 x 6 sections)` |
| `section_history_preparation_test.gd` | `TEST RESULT: PASS` |
| `opening_boon_test.gd` | `OPENING BOON TEST RESULT: PASS` |
| `opening_boon_recovery_test.gd` | `OPENING BOON RECOVERY TEST RESULT: PASS` |
| `combat_hud_dialogue_input_test.gd` | `COMBAT HUD DIALOGUE INPUT TEST: PASS` |
| `guided_combat_tutorial_integration_test.gd` | `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS` |
| `contextual_combat_tutorial_test.gd` | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` |
| `pre_battle_view_test.gd` | `PRE-BATTLE VIEW TEST: PASS` |
| `pre_battle_semantics_test.gd` | `PRE-BATTLE SEMANTICS TEST: PASS` |
| UI identity unit tests | `Ran 25 tests in 6.242s`, `OK` |
| UI identity ratchet | `PASS: UI identity lint (1386 sites within baseline + exceptions)` |
| Rules text lint | `Ran 3 tests in 0.086s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| Python default | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 33.031s`, `OK` |

The focused Godot logs are under `output/fel29/focused/`. The final reruns
of the menu input and resume matrix tests and both pre-battle checks are
under `output/fel29/verified/`. The first Python default run reported
`FAILED (failures=1)` with `Child did not start` in the Godot runner's five-second
child-start test. The quiet rerun passed all 196 tests. The timing-cache
write was denied by the read-only Git metadata.

The existing `start_room_map_suite.gd` also ran headless through a temporary
launcher that calls `Suite.run()` and `Suite.run_live()`.

```bash
python3 tools/godot_task_runner.py --task-id fel-29 --stream -- godot --headless --path . --script output/fel29/focused/start_room_map_suite.gd
python3 tools/godot_task_runner.py --task-id fel-29 --project "$release" --stream -- godot --headless --path "$release" --script "$PWD/output/fel29/focused/start_room_map_suite.gd"
```

Both builds emitted `START ROOM MAP RESULT: 3 failures` with
`Pointer/keyboard hint uses exact authored text` for all three assertions.
Release already adds the key binding to that hint while the suite compares
the bare template. The other narration, map focus, dismissal, travel hash
and save/load checks completed. See
`output/fel29/focused/start_room_map_suite.log` and
`output/fel29/verified/start_room_map_release.log`.

## Open issues

- Native captures, pixel luminance, timing and inspection are pending for
  the design owner. The 29.8 ms largest headless frame gap is a presentation
  sample rather than a native renderer measurement.
- Three existing first-room map hint assertions fail identically on release
  and the branch.
