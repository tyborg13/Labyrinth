# gfix-55 gear rest bake on synchronous resume

## 1. Cause and player impact

The saved fight is installed synchronously in `RunScene._ready()`. During the stage refresh, the hero renderer asks for the uncached gear signature. The release baker records the job in `_jobs`, then calls `tree.root.add_child(job)` while root is still setting up the scene. Godot rejects the attachment. The queued `_bake()` still executes and reaches `get_tree().process_frame` with no tree. The coroutine stops before `_finish()` and later requests for the signature return the same unattached job.

Both native receipts show the rejected `add_child()`, the null `data.tree`, and the error accessing `process_frame`. [9a098_tut01.log](/private/tmp/labyrinth_codex/native_inserts/9a098_tut01.log:36315), [9a062_mrg18.log](/private/tmp/labyrinth_codex/native_inserts/9a062_mrg18.log:15)

The on-board hero body uses the live cutout viewport texture with the equipped parts. Shadows, HUD placement, and obstruction use `assets/units/protagonist_cutout/front/front_assembled_rest_v9.png`. A gear change can show a different signature's rest texture. Returning to the failed signature restores the fallback because the original request stays in `_jobs` for the process lifetime. [Live body texture](../../scripts/combat_board_view.gd#L15937), [static source](../../scripts/combat_board_view.gd#L11758), [obstruction mask](../../scripts/board_occlusion_sources.gd#L76), [renderer fallback](../../scripts/protagonist_cutout/renderer.gd#L96)

## 2. Fix and focused verification

The baker returns a shared pending job immediately so callers can connect to `baked`. One deferred call attaches the job and starts the bake after checking that it entered the tree. Attachment, rig loading, and canvas readback failures all clear the entry before emitting the failed result. A job leaving the tree also drops its entry if that entry still points to the job. The bake was already deferred for idle requests, so its frame synchronization and texture cache behavior are preserved.

- Parse via Godot `--check-only --script tools/gfix55/focused.gd`. Exit 0.
- `GFIX55 ATTACHMENT CLEANUP: PASS (3 checks)`. An unattached job emits a null result, drops its signature before notifying subscribers, and is queued for deletion.
- `PROTAGONIST GEAR SUITES: 628126 checks, 12 failures` on both revisions. Runs `protagonist_gear_suite.gd`, `protagonist_gear_motion_suite.gd`, `protagonist_full_gear_motion_suite.gd`, and `protagonist_gear_carry_suite.gd`. The same 12 layout and carry assertions fail on the release archive. Logs `.godot/gfix55/focused.log` and `.godot/gfix55/release-focused.log`.
- `VYRAKETH CUTOUT SUITE: 2176 checks, 0 failures` on both revisions.
- `HERO FACING TEST: PASS (76 checks)`.
- `PROTAGONIST CUTOUT GAMEPLAY PROBE: FAIL` on both revisions. The Quick Stab and reduced-motion melee damage assertions match the release archive.
- `PROTAGONIST RANGED GAMEPLAY PROBE: FAIL` on both revisions. The `razor_gale` exact damage assertion matches the release archive.
- `board_startup_manifest_probe.gd` stopped at line 35 on both revisions with `SCRIPT ERROR: Invalid cast: could not convert value to 'Dictionary'.`
- `FIX18 DRAW ORIGIN: PASS (10 actor checks; 0 failures)` and `REAL FIGHT CAPTURE VALIDATION: PASS`. Runs `tests/fix18/draw_origin_test.gd` and its shared capture and travel checks in validation mode. Receipt `.godot/gfix55/draw-origin/gfix55.json`.
- Python default selected 23 modules. `Ran 196 tests in 28.621s`, `OK`. Results in `.godot/gfix55/python-default/summary.json`. Git metadata permissions prevented writing the optional learned timing cache.
- `PASS: Rules text lint (16 existing hits)`.

## 3. Boot log and native proof

Headless resumed the saved checkpoint and confirmed the live rig, static fallback, and zero GPU readbacks. `GFIX55 DRY RUN: PASS` on both revisions. Both reported the sandbox macOS certificate lookup error at `get_system_ca_certificates`. One release dry run also logged an ObjectDB warning and two resources in use at exit. The GPU readback and clean native boot log need a window-server session.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-55 && tools/gfix55/native.sh --before
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-55 && tools/gfix55/native.sh
```

The script prints the board PNG path and counts errors and warnings in the Godot log. Each run writes under `.godot/gfix55/before.*` or `.godot/gfix55/after.*`. The fixed run requires one gear rest readback, a populated texture cache, and `GFIX55 BOOT ERRORS: 0` plus `GFIX55 BOOT WARNINGS: 0`. The release control stages the original `codex/release` revision `e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a` and records the same run with the retained failed job. Its script error is expected by the wrapper and rejected by the visual runner.

## Chosen defaults

- The proof reuses the debug boss checkpoint with `war_maul` and `ward_kite` equipped, and its saved profile has the tutorials dismissed.
- The sampler waits eight frames before capture. The visual contract checks the center of the frame for a luminance range of at least 20 and standard deviation of at least 3.
- The extra headless draw-origin validation uses the existing Iskaldra fight builder with seed 7262026, hero tile (4, 4), and a Frostglass Lancer at (4, 2).

No `TODO_DESIGN` placeholders.
