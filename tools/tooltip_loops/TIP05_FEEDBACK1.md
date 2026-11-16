# tip-05 feedback 1: restore production terrain paint

Changes are uncommitted. Only recorder/proof files changed. No windowed run,
re-recording, Git write, full suite, peer review or production-code edit occurred.
The director's existing native `.tlw`, sidecar and raw footage remain untouched.

## Cause and fix

The recorder's `_draw_tile_props()` override was an empty method. The production
method draws terrain bodies, including the Outcrop, and their rise/destruction
animation. State and dust/throw effects were present while the body paint was
suppressed. Removed that override, restoring the original production tile canvas,
prop cache, occlusion, rise and depth order. Decorative scene props and HUD remain
masked as before. No production defect was found or changed.

Inspected the supplied 36-frame native raw stream at frames 0/18/35. The diagnosis
sheet is `/private/tmp/labyrinth_codex/tip-05/feedback1-before.png`; it shows the
reported mark/dust/throw without a rock. It is historical diagnosis, not fresh
post-fix renderer proof.

## Required outcomes

1. The production Outcrop paint now reaches the recording board's retained tile
   canvas. Its real raise progresses through intermediate values to 1.0, and
   the airborne Crawler body has a higher z index than the rock's canvas.
2. All sampled units and rock commands satisfy the 4 px framing gate, including
   the existing 1 px conservative allowance. Full rock minimum margin is
   31.834 px; hero 16.269 px; Crawler 31.000 px. No patch, actor, camera, crop,
   dials or motion adjustment was necessary.
3. Headless Upheaval rehearsal remains 37 frames / 1.233 s at 30 fps, lead
   0.366667 s and settled tail 0.033333 s. Rock motion now participates in the
   trim's visible-action clock. The recorder explicitly rejects an Upheaval
   tail over 0.2 s or action over 4.5 s; existing stricter normal-speed cap is
   retained. Native frame count remains for the director to measure.
4. Rehearsal now requires the live Outcrop on the marked tile in the recording
   board's final terrain, actual retained production paint commands in the
   final tile canvas, an intermediate/full rise, above-floor rock coverage,
   proper airborne depth, and frame margins. The final paint has 487 commands
   and covers 845 loop-resolution pixel centres above the tile's top edge.
   This is a headless draw-command coverage proof, not native pixel acceptance.
   A negative probe leaves the terrain state intact while hiding its paint:
   the new checks reject it, then accept the restored production commands.
   Native recording additionally compares the final frame against the identical
   board with only the rock's paint suppressed, requiring changed pixels above
   the tile inside the actual rock polygons. That counterfactual is outside the
   raw action window, restores the paint, and never changes combat state.
5. All sixteen loops were rehearsed and audited. No other loop is affected by
   the suppressed tile-prop path. The other fifteen contain no terrain-body or
   grid-obstacle changes and create/change no crates. Ground uses a separate
   inherited `_draw_board_surface` path, which was never masked:

| Loop | Ground observation |
| --- | --- |
| `burst_ember_tick` | New Fire has its visible production layer |
| `marked_burrow_grub` | New Rubble has its visible production layer |
| `marked_icefall_seer` | All three new Ice tiles have their visible production layers |
| `marked_lob_slag` | All three new Fire tiles have their visible production layers |
| `rule_wildfire` | Both existing Fire tiles and new Fire have visible production layers |
| `rule_frostbite` | Existing Ice draws during its lifetime, before consumption |
| `lightning_strikes` | Both existing Electrified tiles retain visible production layers |
| Remaining eight existing loops | No ground/terrain/grid changes |

No existing stream was re-recorded this round. The known `collision_push`
present jitter was left alone; no performance assertion was relaxed.

## Observed proof

```text
TIP01 SEMANTICS rule_upheaval: PASS
TIP02 PLAYBACK rule_upheaval: PASS (37 frames at 30 fps; 1.233 s; speed=normal)
TIP01 REHEARSAL RESULT: PASS (0 failures)
TIP03 DESIGN PENDING: 0 loops (excluded from recording)
TIP05 TERRAIN AUDIT: PASS (16 loops; only rule_upheaval affected by suppressed tile props; other 15 need no re-recording)
TIP05 OUTCROP PAINT: PASS (487 draw commands; 845 above-floor pixel centres; full raise; airborne body above rock; margin 31.834 px)
TIP05 TERRAIN NEGATIVE: PASS (state retained; hidden paint rejected; production paint restored)
TIP05 SIDECARS: PASS
TIP05 PRODUCTION SCOPE: PASS (production code and rule data unchanged)
```

All final runner commands exited 0. UI identity: `Ran 25 tests in 4.541s` / `OK`.
Both wrapper `--check-only` commands and `git diff --check` exited 0. No new Python
test module or permanent test was added. The existing macOS CA-certificate message
appeared. An exploratory hierarchy-inspection probe emitted teardown warnings;
the final rehearsal and negative probe completed without script/test failures.

Evidence:

- `/private/tmp/labyrinth_codex/tip-05/feedback1/final-all-loops/rule_upheaval_timing.json`
- `/private/tmp/labyrinth_codex/tip-05/feedback1/final-all-loops/terrain-audit.json`
- `/private/tmp/labyrinth_codex/tip-05/feedback1/final-all-loops/media-sha256.json`
- Temporary negative probe: `/private/tmp/labyrinth_codex/tip-05/proof/terrain_negative.gd`

Headless reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all TOOLTIP_LOOP_IDS=rule_upheaval TIP01_OUT=/private/tmp/labyrinth_codex/tip-05/feedback1/upheaval python3 tools/godot_task_runner.py --task-id tip-05 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all TIP01_OUT=/private/tmp/labyrinth_codex/tip-05/feedback1/final-all-loops python3 tools/godot_task_runner.py --task-id tip-05 --stream -- godot --headless --path . --script tools/tooltip_loops/record.gd -- --rehearsal
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tip-05 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/tip-05/proof/terrain_negative.gd
```

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && python3 tools/tooltip_loops/record.py --loops rule_upheaval
cd /Users/borgerding/workspace/Labyrinth.worktrees/tip-05 && LABYRINTH_CEL_LOOK=all python3 tools/tooltip_loops/capture.py
```

Both use `visual_probe_runner.py` at 1920x1080, 100% UI scale. Only Upheaval is
re-recorded. Recording outputs remain `/private/tmp/labyrinth_codex/tip-05/record/`:
source start/first-motion/end PNGs, timing JSON (including `patch_visibility.terrain`),
raw stream, provenance and compression report. New diagnostic PNG:
`rule_upheaval_without_rock_1920x1080.png`, outside the recorded footage.
Native acceptance requires `native_pixels_above_floor > 0` in the timing report.
Capture outputs remain `/private/tmp/labyrinth_codex/tip-05/capture/{freeze-first,freeze-last}/`
with the existing 31-image contract. No inspection-fixture command is requested.

## Files and defaults

- `record_board.gd`: restore tile props; native counterfactual paint switch;
  include terrain changes in visible-state accounting.
- New `terrain_checks.gd` and UID: retained-command, coverage, rise, depth,
  margins, ground-lifetime, and native final-pixel proof.
- `patch_checks.gd`: continuous terrain audit integration.
- `record.gd`: final terrain proof, native counterfactual, timing limits and hash.
- This handoff and the link in `TIP05.md`.

No active TODO_DESIGN. No placement or player-perceivable defaults changed.
Debug-only fields reuse the existing 282x168 loop grid and 2/255 channel tolerance;
`proof_hidden_terrain_tile=(-1,-1)` means no paint is suppressed. The temporary
negative probe waits three frames for deferred paint/teardown, outside footage.
Open issue: fresh native acceptance of the restored rock and pixel comparison
awaits the director's two commands above.
