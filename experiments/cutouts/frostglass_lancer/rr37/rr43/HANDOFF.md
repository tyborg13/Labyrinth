# rr-43 implementation and proof

All work is uncommitted on `codex/rr-43`. No publication, branch operation,
peer review or windowed run was performed. Headless verification is complete.
Exact observed results and log digests are
recorded in `../../rr43_verification.json`; the full suites have the unchanged
checkout failures described below.

## Requirements

1. **Rear v2 identity job.** `spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2/`
   contains the exact supplied raw, prompt, processing recipe and processed
   PNG, the front reference, recorded raw-step bindings and provenance. The
   additive `lancer_rear_v2` replay step executes the audited numerical helper,
   never a job-supplied script. It preserves the supplied native registration
   instead of applying another BOX reduction, palette match or placement.
   `record-steps`, standalone replay and registry checks were run. The case's
   rear input and production rest source binding point to v2. The review sheet
   is `spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2/review_sheet.png`.
   **Director judgment remains pending.** The protected source has
   `edge_light_share=0.10784313725490197` against the existing maximum `0.06`;
   the sheet reports this failure. No exception or judge approval was invented.

2. **Rear re-cut.** The existing registered maquette transformation is retained
   at offset (0,0). Wood and its complete keyed outline belong to the held
   spear, including the supplied floor-end outline at y=245. Cloak/boot pixels
   no longer carry a shaft-shaped fringe through the attack. Removed-flap
   ownership, hidden fills, meshes, donor certificates, masks, density sources
   and production layouts/rests were rebuilt. Both source assemblies match
   their approved painting after transparent-clear normalization at 0 pixels.
   Hidden shaft paint remains narrow and uses the spear's own interior donors.

3. **Rigid front spear.** The old hand cut included wood above and below the
   grip. Those exact visible texels now belong to `spear`; its hidden backing
   and visible drawing use one rigid bone and one presentation anchor. The
   glove draws above the shaft. The old hand backing, which sampled wood when
   the hand owned it, is rebuilt from genuine glove donors within the existing
   three-pixel glove tuck. Required cuff coverage under the arm/shaft is retained; obsolete shaft-tail support and superseded clip writes are retired. The
   original hidden spear paint is preserved; both spear layers share identical
   source canvases and UV geometry, preventing crop-dependent sampling seams.
   Clip additions stay in the shaft's original support. The one
   optional runtime addition is `held_items.source_grip`: the existing hand
   joint marks the wrist, so a measured painted grip must stay in the glove
   while the rigid item's authored world angle is retained. Cases without
   this field keep the existing transform arithmetic. `rr43_spear.py` checks exact ownership, shared transforms
   in every presented frame and raster continuity through the grip. Mutations
   literally split the lower painted shaft onto the glove while retaining identical rest art, split the lower transform/bone, erase a shaft segment, or strand a rear
   outline texel on another piece; each must fail. Native captures also run
   the actual isolated-pixel shaft-gap check through `rr37_gates.py`.

4. **Preservation.** The front painting, rr-39/rr-41 director paint and compiled
   motion files retain their recorded SHA-256 values. Source and production
   front texels are preserved exactly except the required ownership transfer
   and own-glove backing. The front composed production rest retains its old
   bytes. The existing snap origins are frozen at front (27,6), rear (166,32),
   so changed storage crops do not move the existing animation registration.
   Authored motion and timing are unchanged. The rear floor-end landmark is
   measured from the replacement painting; the released rigid item uses that
   new end with the unchanged authored angles/timing. Other rigs and protected
   inputs remain unchanged. Apart from the optional painted-grip branch, no
   generic rig runtime, combat, analytics, saves,
   input, icon identities, UI, font or audio files were changed.

## Files changed

- New rear-v2 art job, its exact input copies/recipe/provenance/review sheet;
  `tools/art_identity_gate.py`, `tools/art_identity_lancer_recolour.py` and the
  corresponding replay documentation in `spec/visual_identity_gate.md`.
- Lancer case builders/registration/ownership, layouts, derived paint, hidden
  fills and proof masks under `experiments/cutouts/frostglass_lancer/`; new
  `rr43_spear.py`, `rr43_repair.py`, `rr43_preview.py` and `rr37/rr43/` preservation/density inputs.
- `assets/units/frostglass_lancer_cutout/humanoid_v2/` derived layouts, paint,
  rest and integration records; only Lancer density/identity records and
  source files, and its two entries in the shared shadow cache.
- Lancer gates/frame checks, narrow rr-39/rr-41 partition validator updates,
  `tests/test_rr43_lancer.py`, and preservation assertions updated for the
  explicitly requested rear replacement and front ownership transfer. Historical rejection tests keep their exact reviewer coordinates and assertions against the immutable rr-39 archive; rear-v2 has independent current fringe mutations. The generic density edge test now uses the existing hash-bound source-partition authority, preserving prior viewed RGB when a re-cut exposes former interior texels.
- The optional eight-line painted-grip branch in
  `scripts/maquette_cutout_runtime/humanoid_motion.gd`, documented in
  `spec/cutout_workflow.md`. It avoids changing the approved hand bind/motion
  or repainting the front to match the maquette's wrist point.

## Observed headless proof

- rr-43 tests: `Ran 8 tests in 48.035s` / `OK`. Director replay,
  all-frame rigid shaft/grip, preservation, retired glove backing, rear outline
  ownership and split/erased-shaft mutations pass.
- Current production frames: `RR37 FRONT PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)` and
  `RR37 REAR PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)`.
  Both reports have zero `action_canvas_edge_pixels`; all uncovered metrics are
  zero. Reports: `rr37/proof/logs/rr43_front_frames.json`,
  `rr37/proof/logs/rr43_rear_frames.json`. The final front check includes the
  repaired death-frame-34 five-pixel cuff pocket.
- Source and treated-production structural gates: `RR37 ALL GATES: PASS
  (0 unique errors; native=False)` in both cases. Actual runtime transforms:
  `RR37 BONE SAMPLES: PASS (1396 poses; headless transforms only)`.
- Reference sets: `Ran 168 tests in 285.261s` / `OK`. Historical rejection,
  retained-binding and native-tie selection: `Ran 11 tests in 151.355s` / `OK`;
  `RR39 NATIVE UNCOVERED TIES: PASS (64 resolved: 33 outline, 31 missing; 0 remaining; exact retained native pixels)`.
- Identity suite: `Ran 111 tests in 87.964s` / `OK`. New-job replay:
  `ART IDENTITY REPLAY: PASS spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2/kit.json`.
  Registry: `ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)`.
  These do not approve the review sheet's metric failure.
- `FROSTGLASS GAMEPLAY PROBE: PASS`; `V2 BOARD SPRITE GEOMETRY` reports
  80 cases, `errors: []`, `native: false`. `RR37 NATIVE PROBE LOAD: PASS`
  is a headless load-only check; it captures no native pixels.
- `TEST REGISTRATION AUDIT: PASS (854 scripts; full suite=500, quarantined=29, windowed probe=325)`.
  `RR37 PRESERVATION: PASS (5555 protected files; other rigs byte-identical)`.
  Shared identity/density registries were compared with HEAD: every non-Lancer
  entry remains unchanged. `RR37 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)`.
- Density: `CHECK-OK`; `RR41 DIRECTOR PARTITION: PASS (2498 painted; 1529 air; cape_far=2498 cape_near=0; outside source=398px production=403px)`.
  The outside counts are the previously approved rr-41 repairs, checked exactly;
  no blanket preservation exemption was added. `RR41 PRODUCTION REST SEAL: PASS
  (front=0px rear=0px; native-equivalent CPU; windowed proof pending)`.
- Full-suite final outcomes are recorded in `../../rr43_verification.json`.
  Logs retain their exact result lines and SHA-256 digests. Construction previews
  are explicitly software rasters; retained native pixels are historical
  negative controls or tie regressions, never current renderer proof.

## Proof for the design owner

Run the following windowed commands at 1920×1080, 100% UI scale. Inspect the
rear in every clip at 2–4×, front lunge rise/recovery (frames 56–62), and the
identity review sheet. The sandbox has no window-server access; none of these
commands was attempted by this worker.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && LABYRINTH_TASK_ID=rr-43 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh review
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-43 && python3 tools/visual_probe_runner.py --task-id rr-43 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract experiments/cutouts/frostglass_lancer/rr41_gameplay_contract.json --result-manifest experiments/cutouts/frostglass_lancer/rr37/proof/logs/rr43-gameplay-result.json --overwrite-result-manifest tests/frostglass_lancer_cutout_gameplay_probe.gd -- --output res://experiments/cutouts/frostglass_lancer/rr37/proof/rr43_gameplay_native
```

Capture paths: `rr37/proof/native_rest/`, `native/`, `contact_sheets/`,
`frostglass_lancer_review.mp4`, and `rr43_gameplay_native/`. The 16 inspected
construction previews are under `rr37/proof/rr43_software/`; these are software
rasters, not native proof. The headless gameplay manifest is under
`rr37/proof/rr43_gameplay_logic/`. Existing native proof is stale after the art
change and must be recaptured. No inspection-fixture command was requested;
the design owner owns fixture preparation, commits, review and publication.

## TODO_DESIGN placeholders

None. All player-facing inputs came from the supplied paintings or existing
approved motion/rig data. The sheet's metric failure is an open director
judgment, not permission to repaint the protected source.

## Chosen defaults

Only test/proof values were chosen: test subprocess timeout 180 seconds; split
mutation translation 4 pixels; erased source rows [140,145); proof comparison
epsilon 0.0001 (existing precision); software preview canvas 640 pixels,
NEAREST scale 2, fallback clip phase 0.5, repair progress logging every
64 frames, transparent-clear RGBA (0,0,0,0), and the reused four-pixel empty
texture padding. The full Godot wrapper uses the existing 900-second suite
budget. Preview lunge frames 56–62 come
from the brief. Ownership boundaries, fringe width and registration landmarks
are measurements of the supplied/existing art, not new player-facing tuning.

## Open verification issues

- Fresh native renderer proof and director sheet judgment remain outstanding.
- Final Godot round: `TEST RESULT: FAIL (4 failure(s))`; `MAIN BODY ASSERTIONS: 495562`;
  `FULL SUITE RUNTIME: 767.692 seconds (budget 900 seconds)`. All 226 program
  suites completed. The failures are unchanged SPX emblem import-cache errors,
  undefined `GameData` in `enemy_no_action_suite.gd` (exit 124 after 180 seconds),
  and its two FIX-11 dependents (exit 1). Their files and assertions were not
  changed.
- Full Python: `Ran 1999 tests in 7265.985s` /
  `FAILED (errors=2, skipped=66)`. No Lancer test failed. Both errors are
  unchanged `test_rr21_review.py` setup failures: the Briar Weaver
  `mq9/proof/logs` parent does not exist. The tests fail while creating
  `review_stale_*` and `review_clean_*` temporary directories. Their source
  files remain byte-identical to task-base HEAD.
- `RR41 ALL FRONT ROUNDING: PASS (2048 UV/pose cases; 512 poses x 4 choices; every clip including move; no fresh native capture)`.
  `RR41 FRONT PAINT PROVENANCE: PASS (512 frames; every clip; 0 procedural leg texels)`.
  All cloak-lining ownership, air, boundary, missing-paint, walk and
  disabled-guard mutations passed in final discovery.

Full changed-file inventory: `changed_files.txt`. Completed stdout/stderr logs
are preserved under `rr37/proof/logs/rr43_final/` (ignored proof output). The
verification record binds the uncommitted file contents to task-base HEAD; it
does not substitute for the design owner’s later commit or review.
