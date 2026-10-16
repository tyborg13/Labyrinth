# rr-04 review round 1 — implementation proof

Based on reviewed HEAD `7aa3d17ab`; all fixes remain uncommitted.
Risk tier: standard runtime presentation; native production capture required. No peer review,
publication, or inspection-fixture launch was run. Protected design/art data and
Shrike files are unchanged.

## Acceptance and regressions

1. Keep travel facing through move phase 1; apply player-facing only when idle is
   submitted. `presentation.gd` excludes the entire move clip from idle direction
   decoration. Actual RunScene movement submissions exercise all four directions
   for both rigs, the exact endpoint, the following idle, and resolver-generated
   Wisp `blinding_arc:move_away`.
2. Texture origin is independent from actor center. The same channel evaluator
   supplies both the rig pose and its eased/lifted screen root offset. Only the
   texture uses the segment origin; actor center, shadow, health bar and HUD
   clearance follow the visible root. Footprint interpolation retains the existing
   floor/depth path. Reduced motion retains board interpolation of still art.
   Every actual movement callback compares drawn Bone2D root to actor center and
   verifies shadow, health and HUD geometry within 0.005px.
3. Removed both unreachable preparation branches, the Bloomer wrapper/helper and
   unused frame constants, and the Wisp preparation script/import. The regression
   rejects the old RunScene preparation method and old Wisp import/call.

`tests/maquette_cutout/movement_suite.gd` and `movement_scene.gd` observe actual
production callbacks rather than replacing the motion, draw, shadow or HUD code.
They run from the focused maquette test and existing full-suite creature suites.
The exact final tests were run against reviewed HEAD in a temporary source
overlay, without modifying this checkout: 1,710 checks, 58 failures, covering all
three findings. With the fixes applied, all 1,710 checks pass.

## Verification and limits

See `results.json` for exact commands/result lines and retained log filenames.
Full Godot: `FULL SUITE RUNTIME: 789.105 seconds (budget 900 seconds)` and
`TEST RESULT: PASS`. Full Python: `Ran 552 tests in 408.502s`,
`OK (skipped=61)`. Both production logic recorders and gates pass on fresh captures. The two native
production probes were attempted once each, failed the eight-second startup
watchdog before a Godot log was created, and were not retried. Their failed
result manifests are retained. Old native captures in output/rr-04 were preserved
and are not claimed as proof of these fixes. Native gates cannot run without new
native frames. No playable inspection fixture was launched.

For the design owner with window-server access, run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && bash experiments/cutouts/shale_bloomer/mq3/proof/round1/production_proof.sh
```

This is the original proof script's production-capture/gate sequence, with fresh
output/rr-04/round1-owner paths and no inspection-fixture --launch command. The
script has been syntax-checked only.

## Design and defaults

No TODO_DESIGN placeholders or player-visible tuning were added. Test-only
settings are eight settling frames, the existing fixture seed/HP/grid and fixed
6000us presentation clock, 0.005px geometry tolerance, and a 1px endpoint
continuity bound (allows authored lift recovery but rejects reflected travel).
