# rd-06 startup obstruction cache

Owned production change: `scripts/combat_board_view.gd`, layout settlement in
`set_combat_state`. All tools in this directory are proof-only. Changes remain
uncommitted. No peer review or windowed run is performed by this worker.

## Reproduction and focused proof

Start in this worktree. Fixture commands, including both complete
`tools/inspection_fixture.py` invocations, are in `prepare_fixture.sh`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && sh tools/rd06/prepare_fixture.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && python3 tools/rd06/baseline.py python3 tools/godot_task_runner.py --task-id rd-06 --stream -- godot --headless --path . --script tools/rd06/stale_occlusion_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && python3 tools/godot_task_runner.py --task-id rd-06 --stream -- godot --headless --path . --script tools/rd06/stale_occlusion_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && python3 tools/godot_task_runner.py --task-id rd-06 --stream -- godot --headless --path . --script tools/rd06/stale_occlusion_check.gd -- --phase fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && python3 tools/godot_task_runner.py --task-id rd-06 --stream -- godot --headless --path . --script tools/rd06/stale_occlusion_check.gd -- --phase briefing
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && python3 tools/godot_task_runner.py --task-id rd-06 --stream -- godot --headless --path . --script tools/rd06/focused_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/rd-06/python-default
```

`baseline.py` reads the exact brief base `14a369b61` with `git show`, removes
only its global class declaration, and temporarily installs it on the real board
node. Git metadata is never written. The identical check must fail on the base
and pass on the fix. The baseline helper removes its temporary source and UID.

The resume case uses `tools/ptf09/real_fixture.gd` to install and boot the certified
combat save. Fresh entry creates a fight through production RunEngine from the
certified pre-battle save, using a tool-only boot hook. Briefing uses the real
production modal and Begin callback. `entry_engine.gd` places the generated hero
and encounter on the same proof tiles as the combat save, exclusively in these
two tests. No production save or owner fixture is modified.

Headless boundaries certify submitted geometry/tints and full redraw scheduling;
they do not certify rendered pixels. Native mode observes `frame_pre_draw` and
captures `frame_post_draw`, without an initial settle delay. Both modes wait
for the first nondegenerate fight projection (tile width above BoardFraming's
one-pixel startup fallback), rather than counting that temporary empty fit as
a rendered combat. The comparison
captures after selecting hand card zero. The ordinary headless baseline returns
failure for the regression; native baseline mode records the expected mismatch
without rejecting the owner's capture.

## Proof for the design owner

Copy the approved `cel_look_variants/` first. Do not accept a log containing
`Cel look variant unavailable`. Generate the two certified saves with the fixture
command above. Then run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && sh tools/rd06/capture_native.sh base
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-06 && sh tools/rd06/capture_native.sh fix
```

`capture_native.sh` contains the exact expanded commands. Both use
`LABYRINTH_CEL_LOOK=all`, Metal/mobile, a 300-second probe timeout, a 240-second
startup timeout, 1920x1080, and saved 100% UI scale. Neither command was run by the
worker. Outputs are `/private/tmp/labyrinth_codex/rd-06/{base,fix}/first.png` and
`selected.png`; manifests are `base-capture.json` and `fix-capture.json`.

## Chosen defaults

Proof-only: seed 7262026, room (1,0), hero (2,4), enemy positions
(3,5), (5,6), (6,2), (7,3), (1,1), hand Dull Bolt / Quick Stab / Brace;
16 settle frames after the first boundary and card selection; 120 idle frames;
1800-frame boot guard; 300-second native timeout and 240-second startup timeout.
Tint controls use a synthetic 100x100 rectangle at (100,100) and tiles (0,0)/(1,1).
These affect only test state and proof timing. No TODO_DESIGN values are needed.

## Acceptance criteria

1. Real certified save regression compares the first combat boundary, settled
   state and production card refresh; the exact base must fail. Root cause and
   observed results are recorded below after verification.
2. Fit-only layout changes refresh actor obstruction geometry before binding
   retained canvases. Resume, fresh production creation, and briefing Begin each
   run the same check. Existing actor-registration, resize and navigation refresh
   paths remain in place.
3. Tint constants, overlap policy, pillar paint, silhouettes and rings are
   unchanged. The check exercises actor, ordinary object, clear pillar and
   non-tall controls using the production policy.
4. Compare the existing full-dynamic-redraw counter across 120 idle frames on
   both exact base and fix. No process callback or frame polling is added to
   production code.

The first/settled checkpoints also compare every cached actor rectangle with
its current production draw rectangle; equal tints alone cannot mask a stale
cache on a pillar that happens to receive the same opacity.

## Root cause

The first combat submission runs before the HUD fit budget settles. With the
startup fit, BoardFraming legitimately resolves its minimum one-pixel tile width;
the submission cache records hero width 1.03 px and enemy widths about 0.66 px.
Those are correct for that temporary layout, not broken actor art. A later
`set_room_framing` submission changes the fit and resolves board-sized actor
rectangles, but `_rebuild_submission_caches` refreshes obstruction entries for
combat/roster/scene/visibility or moving-unit changes only. A fit-only submission
retains that earlier array, and `_draw_scene_tile_render_layer` consumes it
without validating the layout fingerprint. Thus board-sized pillars are tested
against tiny rectangles near y=19. Selecting a card submits preview/unit geometry;
its moving-entry refresh sees the layout fingerprint mismatch and falls back to
a full obstruction rebuild, making the already-existing fade work.

The fix refreshes the entries once at the layout-change boundary, after layout
resolution and before retained bindings. Separately, a newly ready protagonist
rest texture now publishes its obstruction entries with the asset/HUD update.
The existing actor-registration boundary now falls back to a full rebuild if
its incremental update rejects changed layout geometry. Resize/navigation and
room-entry source rebuilds continue through their existing paths. No process or
draw-loop code, fade value, prop policy, silhouette, ring or save format changed.

## Observed final results

Logs and JSON are under `/private/tmp/labyrinth_codex/rd-06/`.

- `base-final.log`: exact `14a369b61`, `RD06 STALE OCCLUSION: FAIL (3 failures)`.
  First and settled actor rectangle checks fail, and first combat tint differs
  from card-refresh tint. Pillar (2,5): 1.0 initially, 0.32 after selection.
- `fix-resume-final.log`, `fix-fresh-final.log`, `fix-briefing-final.log`:
  each `RD06 STALE OCCLUSION: PASS (0 failures)`. Pillar (2,5): 0.32 at the first
  nondegenerate combat boundary and after selection; actor rectangles are current.
  Both certified fixture manifests report `verified: true`.
- Base and all three fixed cases: `RD06 IDLE: 0 full redraws / 120 frames`.
- `focused-final.log`: `RD06 HOVER: 52316 checks, 0 failures` and
  `RD06 HOVER + ENEMY INTENT: 54234 checks, 0 failures`.
- `python-default.log`: `Ran 189 tests in 30.672s` / `OK` (default group only).
- `sidecars.log`: `Ran 19 tests in 5.001s` / `OK`.
- Resource audit, shell syntax, Python compilation (task-local pycache), and
  `git diff --check` pass. No new Python test module or resource-table row.

The first unbootstrapped scene launch could not resolve an imported class;
headless import completed and all final runs have zero script errors. Godot
prints its existing macOS certificate-store diagnostic (`ret != noErr`), and
production layout emits existing opposite-anchor warnings. The default Python
suite could not update the read-only Git timing cache after passing. No Git
write workaround was attempted, and no test assertion was weakened.

No worker-native captures exist. The outstanding proof is the owner's Metal
first/selected PNG capture and inspection with the approved cel variants.
No TODO_DESIGN placeholders; no implementation or test failures remain.
