# ptf-09 feedback 2

Implemented against the owner's merge `089433b5f`, with release production
reference `c9121c833`. Re-import completed first through the task runner (exit 0).
Everything remains uncommitted. No windowed/native run, peer review, Git write,
publication or branch operation was performed.

## Depth findings

The highlight is now an ordinary **relative-Z 0 floor decal**, immediately after
`_action_floor_render_layer`. It has no absolute-Z override or maximum-Z value,
and hover no longer moves it to the last sibling. The lift is **3 px**. The
3 px black 50% drop rim remains on the true tile edge. Every other feedback-1
core, edge, glow, wash, pulse, tone and invalid-alpha value is unchanged.

`_sync_scene_render_layers()` restores the floor-decal slot before matching or
rebuilding layers, and inserts every scene layer after that slot.
`_scene_render_layers_match()` accounts for the optional border child in its
exact indices. This preserves the match fast path, rather than forcing a rebuild
on every unchanged submission. Placement runs at creation and existing scene
re-sync boundaries; the board's process loop does not call it. The proof confirms
zero placement calls across ten board-process ticks. No new hover A/B was run.

The retained-layer audit read the actual `_draw_*_render_layer` functions:

| Order relative to border | Actual drawing |
|---|---|
| Below | Root/static-cache floor art; ambient firelight/particles; overlay washes and move/ability/attack target outlines/pulses; ground loot/traps; impact decals; world Umbra wash; elemental spell/trap **action-floor** effects. |
| Below, but empty for paths | `_draw_path_render_layer()` explicitly has no path drawing; paths are painted per scene tile instead. |
| Above | Every `SceneTileBackEffect_*`, `SceneTile_*`, `SceneTileFrontEffect_*`; foreground; telegraphs; effects; HUD health/intent/status plates and callouts. |
| Above within scene tile | Standing scene props, walls/pillars, crate bodies and ground shadows, and unit bodies/ground shadows. |

**Existing floor-level drawing after the requested slot, left unchanged:**

- `SceneTile_*._draw_scene_tile_render_layer()` calls `_draw_board_surface()`
  before its props/bodies. Elemental ground, rubble, surface feedback and retained
  surface children therefore paint after the border.
- The same layer calls `_draw_path_depth_pass()`: player movement routes,
  displacement paths, and applicable enemy path previews paint after the border.
- `_draw_enemy_threat_depth_pass()` paints ranged/illusion preview curves there,
  and `_draw_noctyrax_refuge_tile()` paints the refuge floor markings there.
- Scene back/front effect passes call `_draw_elemental_scene_depth_pass()`;
  depth-authored trap/dragon/elemental effects, including ground-burst portions,
  can paint after the border.

No other layer or draw call was moved. The explicit requested slot takes
precedence over the general wish to be above every surface/path. Cards, hand and
tooltip presentation keep their existing higher UI/popup layers.

## Flicker root cause

**Harness timing artifact, not alternating hover or selection state.** The
crate is a legal Dull Bolt target, so the production overlay has both:

```text
draw_colored_polygon(crate diamond, ATTACK_HIGHLIGHT)
_draw_attack_target_pulse(crate tile)
```

The first is the constant dim attack wash. The second is the existing gold
attack-target ring, driven by `_draw_attack_target_pulse()` at **1.45 Hz** using
`presentation_clock.gd`. Its alpha, width and scale change with the sine clock;
no target-selection state flips.

The old capture saved one PNG after viewport readback/encoding plus a wall-clock
`create_timer(1/30)`. The supplied frames 46–55 were actually saved **314–372 ms**
apart (mean **344.843 ms**, median **350.124 ms**). Half a 1.45 Hz cycle is
**344.828 ms**. The sampler therefore nearly alternated between opposite pulse
phases on consecutive saved frames. Playing those PNGs at 30 fps sped game time
up by about **10.35×**, turning the smooth gold pulse into the reported even/odd
flash. The targeted border's own 1.4 s pulse was sped up by the same sampler.

Before evidence:

- The owner's original `captures/sweep_048.png`–`sweep_055.png` were inspected;
  they are unchanged. `feedback2/legacy_sampling.json` records ten original PNG
  paths, file timestamps and nine measured intervals.
- A scratch copy of the old harness was run headlessly against exact production
  RunScene/CombatBoard scripts extracted from **release `c9121c833`, without
  ptf-09** (only the board's duplicate global class declaration is stripped for
  side-by-side loading). The same crate attack wash and gold-pulse draw plan is
  present there. Thus the source animation and sampling problem also occur on
  release; ptf-09 did not introduce that pulse.
- Both old-harness traces retain hover `(4,3)`, controller focus `(-1,-1)` and the
  same crate draw plan for sweep frames 48–55. No crate hover entry occurs. The
  selected action is ranged, so the move-attack approach path is not involved.
- The old native harness's manual `frame_post_draw.emit()` was guarded to
  headless only; it did not cause the owner's native alternating frames. The
  old duplicate pointer injection also did not alternate these selectors.

The new harness uses one production GUI input path, including normal
last-pointer bookkeeping. It resumes a real inspection save and records the
clip through **Godot movie mode, `--write-movie`, `--fixed-fps 30`**. It contains
no wall-clock timer or manual native render-signal emission. Every native clip
sample asserts a 1/30-second presentation-clock step. PNG writing latency can no
longer accelerate the clip's game clock.

`tools/ptf09/flicker_check.gd` checks ten consecutive pointer-sweep frames that
never visit the crate. Its logical tile selectors and complete crate draw plan
must remain identical; the intentionally animated pulse phase is not mistaken
for a targeting-state change. The headless test injects movie startup arguments
into the unchanged production clock, as existing movie-clock tests do, without
recording dummy pixels.

```text
PTF09 FLICKER release_before: FAIL (10 identical crate presentations; 9 timing/input failures)
PTF09 FLICKER release_after: PASS (10 identical crate presentations; 0 timing/input failures)
PTF09 FLICKER candidate_after: PASS (10 identical crate presentations; 0 timing/input failures)
```

The before failure is intentional: it replays the original PNG timestamp
intervals against the fixed-30-fps requirement. After cases use movie-clock time.
This is headless state/timing reproduction; no native release replay was attempted.

## Verification

```text
PTF09 HIGHLIGHT: PASS (3655 checks, 0 failures)
PTF09 FOCUSED: PASS (61323 checks, 0 failures)
BOARD TILE TOOLTIPS: PASS checks=217 failures=0
PTF09 REAL CAPTURE: PASS (6 states, 1920x1080, 100% UI)
PTF09 MOVIE CONTRACT: 120 consecutive frames / 30 fps = 4 seconds; 6 sweep tiles
PTF09 REAL CAPTURE: PASS (120 states, 1920x1080, 100% UI)
Python default: Ran 189 tests in 34.964s / OK
UI identity: Ran 25 tests in 6.165s / OK
CEL_STATUS current
```

The highlight proof checks unit movement/re-sync, a rendered tile-row addition
and removal, framing change, exact matching indices, relative Z 0, and the earlier
hover/tone/click/controller/reduced-motion behavior. Focused checks cover hover,
input, shortcuts, targeting audit and intent continuity. Both full suites were
omitted. No new Python test module was added, so no resource-table entry changed.
New GDScript helpers have UID sidecars. Python tool syntax and shell syntax pass.
The native movie finalizer is prepared but cannot be run without owner PNGs.

Logs, before/after traces and headless capture semantics are under
`/private/tmp/labyrinth_codex/ptf-09/feedback2/`. Re-import logged existing duplicate
placeholder UID/certificate-store warnings; headless UI initialization logs
existing anchor-size warnings. Successful runs have no script/parse failures.
The default Python suite passed despite its optional Git timing-cache write being
denied by the read-only metadata sandbox.

## Proof for the design owner

The fixture already generated and verified successfully. It uses the **existing
`--terrain wooden_crate@3:4` flag**; no new fixture option or test-board layout was
added. The seed-generated chamber, production scene, loadout, HUD and input path
are retained. The only inspection overrides are the named existing fixture flags
below. Resume occurs before boot, so there is no Emaciated Man startup dialogue
or “Live Move Attack Shortcut Test” title. The capture process copies the certified
profile/save to its isolated user directory, preserving the owner's fixture save.

Run from the task worktree, in order:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && LABYRINTH_CEL_LOOK=all python3 tools/inspection_fixture.py --task-id ptf-09 --run-id ptf-09-feedback2 --manifest /private/tmp/labyrinth_codex/ptf-09/feedback2/inspection.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,guarded_step,brace --player-position 2:4 --enemy-types crawler,warden --enemy-positions 3:3,4:5 --terrain wooden_crate@3:4 --umbra-stage clear --summary 'ptf-09 depth and input proof'
```

Six native stills at 1920×1080, 100% UI scale, cel look:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/ptf09/capture_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-09/feedback2/stills_manifest.json tools/ptf09/capture.gd --task-id ptf-09
```

Files under `feedback2/stills/`:

1. `01_dull_bolt_foe_behind_crate.png`: valid attack; crate partly covers the foe's
   border. Headless composition confirms partial projected-diamond overlap.
2. `02_empty_behind_tall_unit.png`: empty tile behind the Warden; body covers the
   floor decal. Actor bounds overlap the empty tile's center.
3. `03_unit_feet.png`: valid attack on the Warden's own floor tile, body/shadow
   above the decal around its feet.
4. `04_valid_move.png`: a real valid movement destination among reachable tiles.
5. `05_invalid_tile.png`: the occupied foe tile during movement selection.
6. `06_controller_foe.png`: controller focus on the foe.

Movie-mode PNG recording of the six-tile, four-second sweep:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --godot tools/ptf09/movie_capture.sh --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/ptf09/movie_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-09/feedback2/movie_manifest.json tools/ptf09/capture.gd --task-id ptf-09 -- --clip --fixed-fps 30 --output-dir /private/tmp/labyrinth_codex/ptf-09/feedback2/clip
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-09 && python3 tools/ptf09/finalize_movie.py
```

The wrapper supplies engine `--write-movie .../movie.png --fixed-fps 30
--resolution 1920x1080`; the user-argument FPS also supports engines that consume
that option before `presentation_clock.gd` reads it. Each recording uses a fresh
raw directory. The finalizer copies the final 120 consecutive MovieWriter frames
without changing pixels or timing, omitting startup/fixture setup frames. It checks
the native frame count, 1/30 clock increments and PNG dimensions. Deliverable:
`feedback2/clip/frames/sweep_000.png` … `sweep_119.png`, **30 fps, 4 game seconds**.
The owner can make the slowed copy separately.

**Native proof remains pending:** the worker did not run these windowed commands
or fabricate renderer evidence. Inspect actual crate/body occlusion and floor
anchoring in the fresh stills, and smooth pulses at game speed in the movie.

## Chosen defaults and scope

No new design values or TODO_DESIGN placeholders. Debug/fixture defaults are:
seed 7262026, generated room (1,0), hero (2,4), crawler (3,3), Warden (4,5), crate
(3,4), empty tile (4,4); the three-card inspection hand above; six sweep centers
(2,3), (3,3), (4,3), (4,4), (5,4), (4,5); setup 16 frames and still settling 6;
ten-frame stability path (4,4)→(5,4); fixed clip 120 frames at 30 fps (director
requirement); a 120-second native-run timeout for recording/readback; fresh raw
movie directories and the `feedback2/` evidence folder. Game tuning and assets
were not changed.

Changed production files: `scripts/combat_board_view.gd` and
`scripts/targeted_tile_highlight.gd`. Task-local proof/capture files under
`tools/ptf09/` contain the remaining changes; no other unit's files were edited.
