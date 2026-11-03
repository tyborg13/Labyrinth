# rr-40 adopted feedback 2 — upright board figures

Base: `ad552f543`; branch `codex/rr-40`. All changes are uncommitted. No peer review, Git publication or windowed run was performed. The design owner's two supplied native frames were inspected at their original 1920×1080 size.

## Requirements and root cause

1. **Cause and fix:** strike sampling saves/restores `rig.transform`. Godot can decompose a negative-X reflection into a half-turn plus negative-Y scale. The next separate `rig.position` / `rig.scale` assignments retained that rotation. Actual gameplay tracing before the fix captured `X=(1,0), Y=(0,-1), origin=(447,192)` while the Lancer metadata still said mirrored. This simultaneously inverted the painting and pushed it above/right of its tile; HUD registration remained correct. The live renderer and strike sampler now assign one complete matrix with the required horizontal reflection, a positive vertical basis and the existing canvas offset. This changes no authored rig, paint, pose, timing, scale or floor anchor.
2. **All figures/facings:** Lancer, Gloam, Herald, Seer, Thrall, Mirror, Capacitor, Weaver, Mimic and Mortar each run NE/NW/SE/SW twice, retaining facing history and full-transform restoration. Both ordinary construction and prepared adoption are exercised by the two probes. The fixed code passes all 80 history cases. The same new test on the unchanged rr-39 runtime reports 36 inverted-basis failures, spanning all four directions of nine figures. Capacitor does not reproduce the reflection problem because its accepted adapter suppresses horizontal reflection.
3. **Native regression:** both probes call the same independent geometry oracle. It reads each real renderer viewport's opaque bounds and maps those pixels through the production board destination rect and canvas transform. Bounds must intersect the actual diamond tile polygon and fit within anchor ± logical sprite size. The approved production rest PNG is rendered in an upright TextureRect with only its declared horizontal UV flip; the oracle bypasses both the renderer and rig sampler. Premultiplied native RGBA samples must match the upright rest orientation better than vertical reflection or a half-turn. Every figure/facing also gets deliberate native vertical-flip and off-tile mutations; each image gate must reject them independently of the matrix guard. The native run expects 80 positive cases, 40 orientation-mutation rejections and 40 placement-mutation rejections. Gameplay additionally checks every live standing actor during captures, including the previously missed second Lancer. Authored travel and death poses keep their existing contracts. Native checks are written but cannot execute in this worker's sandbox; no native pass is claimed.
4. **Where it existed:** the same full-transform-restoration sequence reproduces the negative-Y basis on `codex/rr-39` (`086650ae5`) and integration `codex/peer-benchmark` (`bbd2a0dc9`). Integration's Lancer is still its legacy renderer; it also reproduces under that sequence. The original integration reference `1dbcd8fda` and current local `master` (`d96eadf4f`) were checked too, with the same flaw in their available renderers; master has no registered Gloam/Herald. Thus the partial-transform flaw predates rr-40; routing the Lancer into the shared renderer and strike sampling exposed it. These comparisons are headless transform evidence, not baseline native gameplay captures. All snapshots were Git archives under ignored task output; no branch or worktree was changed.

All asset and authoring files remain byte-unchanged. No assertions or tolerances were weakened. No design placeholders were needed.

## Files changed

- `scripts/maquette_cutout_runtime/pixel_presentation.gd`: complete canvas-facing matrix helper.
- `scripts/maquette_cutout_runtime/renderer.gd`: use that matrix for live poses.
- `scripts/maquette_cutout_runtime/strike_points.gd`: use that matrix while sampling; preserve exact prior transforms as before.
- `tests/rr40/board_sprite_geometry.gd` and `.gd.uid`: shared matrix/native image/footprint oracle, independent approved-rest canvases and negative controls.
- `tests/prepared_unit_canvas_equivalence_test.gd`: invoke the new prepared-adoption geometry matrix after the existing 64-case equivalence test.
- `tests/frostglass_lancer_cutout_gameplay_probe.gd`: check live standing actors and invoke the ten-figure geometry matrix.
- `tests/rr40/prepared_canvas_proof_contract.json`, `tests/rr40/gameplay_proof_contract.json`: require all 40 named figure/facing captures in each native run (41/46 total required images respectively).
- `tests/rr40/feedback1_report.md`: mark the prior report historical and point to this one.
- `tests/rr40/feedback2_report.md`: this handoff.

## Headless proof observed

Logs/data use `/private/tmp/labyrinth_codex/rr-40-feedback2-*`.

- `facing-before.log`: nine figures each show 12 negative-Y samples; Capacitor has none. `facing-after.log`: `FACING TRANSFORM PROBE: []`.
- `gameplay-trace.log`: actual before-fix gameplay hits the negative-Y Lancer matrix during lunge, confirming the save/restore history is reached by production playback.
- `rr39.json`, `integration-peer.json`, `integration-original.json`, `integration.json`: per-figure baseline adapter paths and faulty matrices. Their runner exits are 0; bad matrices are explicit probe observations, not claimed passes.
- `matrix-before-clean.log`: new 80-case regression on rr-39 exits 1 with 36 basis failures and no script errors. The first incomplete scratch fixture attempt lacked an unrelated movement-suite dependency and timed out; the clean run supplies the exact fixture-state function and exercises unchanged runtime code.
- `prepared-final.log`: `V2 BOARD SPRITE GEOMETRY: {"cases":80,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}`; `PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}`. Native mutation counts are zero because native checks were not run.
- `gameplay-final.log`: the same 80-case geometry result; `FROSTGLASS GAMEPLAY PROBE: PASS`.
- `image-math.log`: `REST IMAGE ORIENTATION MATH: {"checks":40,"errors":[],"native":false}`. Approved front/rear rest images and in-memory flipped test copies validate the comparator; this is not renderer proof.
- `geometry-math-final.log`: `REST FOOTPRINT CALIBRATION: {"cases":40,"errors":[],"native":false}` using approved rest-image bounds and the production board rect/tile APIs.
- `references.log`: `Ran 184 tests in 398.800s`; `OK`.
- `pre_battle_semantics_test.log`, `pre_battle_true_scale_test.log`, `pre_battle_view_test.log`: `TEST RESULT: PASS` each.
- `suites-full_scene_cutouts_program.log`: `MAIN DOMAIN ASSERTIONS full_scene_cutouts_program: 646895`; `TEST RESULT: PASS`.
- `rr37-runtime_checks.log`: `RR37 RUNTIME: PASS (282 checks; headless registration, views, portraits and clocks)`.

`perf.log`: `PERF03 FRAME RESULT: PASS (0 failures)`; 18 cases; final `orphan_nodes=0`. `PERF03 BUDGET RESULT: FAIL (5 misses)` (headless budgets remain reported, not enforced): hover ordinary 6.467ms/p95 0.501; air T2 9.716/0.906; lightning T3 8.838/0.551; trap lightning kill 20.089/0.399; trap fire kill 20.287/0.399. Full data: `rr-40-feedback2-perf.json`; compact summary: `rr-40-feedback2-perf-summary.json`. No timing budget or runtime tuning changed.

Full Godot (`rr-40-feedback2-godot-full.log`): `FULL SUITE RUNTIME: 603.385 seconds (budget 900 seconds)`; `TEST RESULT: PASS`; exit 0; all 206 programs pass; failure list `[]`; zero script-error/load-error markers. Main body: 495455 assertions. The inherited nonfatal ObjectDB shutdown warning remains. `fix_12_test` is absent from this worktree, so no pass or timeout is claimed and no exemption was used.

Full Python (`rr-40-feedback2-python-full.log`): `Ran 1893 tests in 3599.498s`; `OK (skipped=66)`; exit 0; failure/error lists `[]`. The 66 existing environment/opt-in skips comprise 63 audio-environment requirements, two opt-in Blender proofs and one unadopted rr-27 Tether study. No dependencies were added. The full suites ran serially, once at the end on the final implementation.

Final hygiene: `git diff --check` passes; `OUTPUT GDIGNORE: PASS (16 folders; 6 referenced roots)`; asset/authoring trees are unchanged. HEAD remains `ad552f543e76a1c2a5dc6653b6f8bc2a1c312b20` on `codex/rr-40`; the eleven changed/new files listed above remain uncommitted.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && python3 tools/godot_task_runner.py --task-id rr-40 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && LABYRINTH_TASK_ID=rr-40 python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Proof for the design owner

No windowed run was attempted: this sandbox has no macOS window-server access. Both commands retain 1920×1080 and 100% UI scale. They now include the native regression and its negative controls:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && python3 tools/visual_probe_runner.py --task-id rr-40 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/rr40/prepared_canvas_proof_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-40-feedback2-prepared.json tests/prepared_unit_canvas_equivalence_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-40 && python3 tools/visual_probe_runner.py --task-id rr-40 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr40/gameplay_proof_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/rr-40-feedback2-gameplay.json tests/frostglass_lancer_cutout_gameplay_probe.gd
```

Capture destinations:

- Prepared: `user://prepared_unit_canvas.png`; `user://prepared_sprite_geometry/{figure}_{NE|NW|SE|SW}.png`; `geometry.json` alongside the matrix captures.
- Gameplay: existing `user://probes/frostglass_gameplay_v01/` action/input captures, plus `sprite_geometry/{figure}_{NE|NW|SE|SW}.png` and `sprite_geometry/geometry.json`.

No new native captures exist from this worker. No inspection-fixture command was requested in this brief; fixture preparation remains with the owner.

## TODO_DESIGN and chosen defaults

TODO_DESIGN: none. Only test/proof values were chosen: `HISTORY_CYCLES=2`, `PLAYER_DISTANCE_TILES=2`, `SETTLE_FRAMES=2`, `HISTORY_PHASE=0.3`, `ORIENTATION_SAMPLE_SIDE=32` (32×32 image-comparison sampling). Matrix fixtures reuse the existing runtime-suite state and the required 1920×1080 proof size. No player-facing numeric value changed. The existing 180s/300s owner probe caps and 900s full-Godot cap are retained.

## Open issues

Native placement/orientation and the negative controls remain unexecuted here, requiring the two owner commands above. Both full suites are green with empty failure lists. The five reported headless perf-budget misses and inherited shutdown warnings remain documented rather than retuned.
