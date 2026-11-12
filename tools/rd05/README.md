# rd-05 implementation and owner proof

All changes are intentionally uncommitted. No reviewer, signoff, publication,
windowed run, native screenshot or movie was performed by the worker.

## Acceptance mapping

1. `SettingsStore.DEFAULT_BOARD_HEALTH_BARS` is the single default switch.
   `Board health bars` has `Always` / `On hover and aim`, alongside combat speed.
   Normalization migrates older profiles; `apply_settings` updates live boards.
2. The controller gates painting only. The original plate/pill/pip geometry is
   still computed and reserved, keeping intent chips and leader crests fixed.
   Existing enemy order discs move to the footprint front, raised by 0.22 tile
   height; existing status/defense entries form one row at 4px gaps.
3. Body/tile/chip pointer input, rail pointer/focus, board controller focus,
   Details, the selected card's valid-choice union, and actual durability/status
   observations feed visibility. Fades are 0.12s in / 0.20s out. Changes retain
   visibility for the health ghost/heal animation plus 1.2s. Preview-only values
   do not count as real changes. Enemy-area targeting does not reveal the hero
   merely because the hero's tile is inside an enemy-only attack pattern.
4. Rail health numerals use the existing time font and outline, 0.62 times its
   size, TEXT colour, right aligned to the mini bar with baseline 2px above it.
   Hero is current/max; others current. Hidden entries remain numberless.
5. The same input hooks run in compact layout; the proof exercises Steam Deck
   controller board navigation. Native compact visual inspection remains owner
   work, as does all renderer inspection.
6. The visibility clock sleeps at rest. Holds do not invalidate paint. The
   proof compares every board redraw-request category over two matched 120-frame
   windows, with the same normal idle/ambient board work in both.
7. Existing art, layout and palette tokens are reused. UI identity lint is run
   without changing its baseline. Native identity judgment is pending owner work.
8. One permanent settings regression lives in `tests/settings_probe.gd` and is
   called by its existing atomic-write check. It round-trips both values and
   loads a legacy profile with the default while preserving another preference.

`TODO_DESIGN_FRIENDLY_ORDER_BADGE` is empty: today's board HUD has no hero/ally
ordinal disc. Friendly status rows use a zero-width badge anchor at their feet;
no ordinal or friendly disc content was invented. The owner must supply that
content if the requirement is meant to introduce friendly order badges too.

## Headless verification

Run these from this worktree. No full Godot/Python suites are requested.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/godot_task_runner.py --task-id rd-05 --stream -- godot --headless --path . --script tools/rd05/plate_visibility_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/godot_task_runner.py --task-id rd-05 --stream -- godot --headless --path . --script tools/rd05/focused_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/godot_task_runner.py --task-id rd-05 --stream -- godot --headless --path . --script tools/rd05/settings_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/godot_task_runner.py --task-id rd-05 --stream -- godot --headless --path . --script tools/rd05/hit_proof.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rd-05/python-audit
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/rd-05/python-default
```

`focused_checks.gd` runs the existing plate/status/cache, chip placement, enemy
intent continuity, initiative, turn-clock rail and board-hover suites, plus the
settings regression. Legacy board painting checks run under `Always`; the new
real-save proof exercises contextual behavior independently. It awaits the
asynchronous status-cache suite before starting another domain.

The worktree initially had no `.godot` cache. A copy-on-write copy of the brief's
`pt2-export/.godot` baseline seeded it, without an editor scan or asset changes.
A sidecar utility creates UIDs only for this unit's new GDScript files.

## Proof for the design owner

First create/verify the two real saves (these exact commands were run headlessly):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/inspection_fixture.py --task-id rd-05 --run-id rd-05-five --manifest /private/tmp/labyrinth_codex/rd-05/inspection.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,ember_rain,sidestep_slash,brace --player-position 2:4 --enemy-types crawler,warden,crawler,crawler,crawler --enemy-positions 3:3,4:5,4:3,5:4,3:5 --umbra-stage clear --summary 'rd-05 five foe plate visibility proof'
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/inspection_fixture.py --task-id rd-05 --run-id rd-05-zekarion --manifest /private/tmp/labyrinth_codex/rd-05/zekarion.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,ember_rain,sidestep_slash,brace --player-position 2:4 --enemy-types zekarion --enemy-positions 5:3 --umbra-stage clear --summary 'rd-05 Zekarion plate visibility comparison'
```

Native captures, **not run here**. Each pair freezes the complete production
scene at one gameplay/presentation frame, switches only the setting and settles
its opacity. Native renderer is explicitly OpenGL, with no ANGLE or fallback.
Cel look is on, viewport 1920×1080, UI scale 100%.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3 --timeout 120 --expect-size 1920x1080 --proof-contract tools/rd05/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-05/stills_manifest.json tools/rd05/capture.gd --task-id rd-05
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3 --timeout 120 --expect-size 1920x1080 --proof-contract tools/rd05/zekarion_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-05/zekarion_manifest.json tools/rd05/capture.gd --task-id rd-05 -- --zekarion
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --godot tools/rd05/movie_capture.sh --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3 --timeout 120 --expect-size 1920x1080 --proof-contract tools/rd05/movie_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-05/movie_manifest.json tools/rd05/capture.gd --task-id rd-05 -- --clip --fixed-fps 30
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && python3 tools/rd05/finalize_movie.py
```

Expected outputs:

- `stills/01_five_foe_rest_{always,on_hover_and_aim}.png`
- `stills/02_ranged_aim_hover_{always,on_hover_and_aim}.png`
- `stills/03_area_aim_{always,on_hover_and_aim}.png`
- `stills/04_foe_hover_{always,on_hover_and_aim}.png`
- `stills/05_details_{always,on_hover_and_aim}.png`
- `zekarion/06_zekarion_rest_{always,on_hover_and_aim}.png`
- `stills/07_rail_crop.png` with its native source rectangle in `rail_crop.json`.
  It is cropped from the full-size Details capture, without scaling.
- `clip/frames/hit_000.png` … `hit_119.png`: 120 consecutive native MovieWriter
  frames at 30fps, four game seconds, with startup frames removed. Frame 6 selects
  the ranged card; frame 12 chooses its target and frame 14 confirms the real
  hit and removes pointer focus. Metadata
  records HP, ghost and opacity each frame and checks the hold/fade completes.

All output paths above are below `/private/tmp/labyrinth_codex/rd-05/`.
Inspect native stills and movie before judging the prototype. No native evidence
is claimed by the worker.

## Playable normal-profile launch

The owner-only wrapper restores the caller's original home and clears the task
namespace and isolated application-data overrides. The outer runner retains
process supervision and a task-local engine log. Steam is enabled for this
normal-profile play session. This command was not run here.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-05 && RD05_NORMAL_HOME="$HOME" LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id rd-05 --timeout 0 --allow-steam --stream -- tools/rd05/normal_profile.sh --path . --windowed --resolution 1920x1080 --rendering-driver opengl3
```

## Chosen defaults

Only fixture/proof values were chosen: seed 7262026; generated combat room (1,0);
hero (2,4); five-foe roster/positions and four-card hand in the fixture commands;
Zekarion (5,3); clear Umbra; source fixture/profile copy paths; proof startup and
idle settling 30 frames, capture settling 20 frames, aim settling two frames;
manual fade settling 0.25s, overlapping-change sample delay 0.1s, and fully
settled sampling 3s; fixed debug-only board
delta 1/60s; pointer outside the board at (-1000,-1000); clip selection/commit at
frames 6/12/14; capture timeout 120s; output folders under the task's temporary root.
The 120 idle frames and 120 movie frames at 30fps are brief requirements.

## Open work

Native screenshots, movie execution, visual inspection and identity judgment are
pending the design owner. The owner also commits, reviews and publishes.
