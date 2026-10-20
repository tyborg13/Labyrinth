# rr-29 — director feedback 2 implementation

Code-only follow-up to `052a20fb8`, left uncommitted on `codex/rr-29`.
Accepted motion, paintings, cuts and production assets are unchanged from the
start of this pass, including the director's existing native rest/density/
shadow updates. No windowed process, full suite or peer review was run.
The preceding feedback-1 verification remains in this file's history and in
`proof/verification.json` at `052a20fb8`.

## Numbered feedback

1. **Native producer crash.** Every one of the eight joint meshes per view
   lacked `transform` in all 504 sampled poses per view: `leg_far`,
   `leg_far_hidden`, `leg_near`, `leg_near_hidden`, `sleeve_far`,
   `sleeve_far_hidden`, `sleeve_near`, `sleeve_near_hidden`. The sampler now
   records each real Polygon2D source-space transform, alpha and depth.
   These node transforms are distinct from their skinned vertex positions.
   All 15,928 native isolated-piece transforms match the regenerated samples
   exactly over 724 presented frames (maximum difference 0.0). The generic
   native gate is unchanged and no longer crashes.

   Replay exposed an additional producer defect: promoted front `block`
   parts share z=14, and the old manifest lists sleeve before hand whereas
   Godot draws bone sprites before its rig-child meshes. The native producer
   now records scene-tree order through `tests/rr29/paint_order.gd`; the
   headless samples also record that actual tree order. An independent
   reconstruction of the existing GPU surfaces matches **all 724 frames
   exactly**, resolving the old-order mismatches at front `block` frames
   **10–40 inclusive** without changing runtime drawing or any pixel input.

   The unmodified authoritative gate on the **original** capture reports
   `RR29 NATIVE GATES: FAIL (32 errors)`: one stale input receipt plus those
   31 old-manifest composite mismatches. Its original receipt and images
   are preserved; no failures are waived and no replacement renderer capture
   is claimed. Fresh director capture is required to certify the repaired
   producer. The diagnostic is explicitly not native certification.
2. **Far-arm runtime fixture.** `tests/rr29/far_arm_fixture.gd` loads actual
   production rigs and moves an overlapping far wrist across the torso
   midline. It calls runtime ordering and checks both the Sprite2D hand and
   Polygon2D sleeve: promotion, restoration across the midline while still
   overlapping, restoration outside the torso, rest and rear exclusion.
   It passes 26 checks. A headless mutated copy disabling far promotion
   fails both hand and sleeve checks; production runtime bytes are untouched.
3. **Certified rear revision.** The existing `revision_prompt_*` fields now
   participate in the ordered base→r2 generation hash. Certification verifies
   both captured prompts against their hashes and canonical maquette copies.
   The revision remains chained after `prompt_rear_mq11.md`; changing its
   captured bytes, canonical source bytes or chain order fails certification.
   Opt-in implementation leaves all other jobs' hashes and rules unchanged.
   Only the rear kit version, its own registry binding and sheet provenance
   were refreshed; approved prompt and painting bytes are unchanged.
4. **Immutable preservation base.** Verification compares to
   `8b6cf8d063bf4a8a5de973bae2e28251c4f57f0a`, including committed, staged,
   unstaged and untracked figure changes. Disposable-repository regressions
   commit foreign rig/case edits, assert the working tree is clean, and
   require failure; later Mimic commits cannot hide them. Shared registry
   mutations and new foreign files are covered too. The production tree
   passes all five preservation checks against this integration base.

## Observed proof

- Final focused tests: `Ran 129 tests in 56.805s`; `OK`;
  `RR29 PYTHON FOCUSED: PASS (4 Godot invocations forced to rr-29)`.
- Icons: `Ran 7 tests in 0.060s`; `OK`.
- `RR29 FAR ARM RUNTIME: PASS (26 checks)`.
- `RR29 FAR ARM MUTATION: PASS (disabled far promotion rejected for hand and sleeve; production bytes untouched)`.
- `RR29 BONE SAMPLES: PASS (1008 poses; headless transforms only)`.
- `ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)`.
- `RR29 OTHER FIGURES: PASS (5 checks)`.
- The original-capture authoritative replay fails as explained above; the
  source-space/material/rigid/draw-depth checks report no other errors.

Exact result lines, paths, input differences and file inventory are in
`proof/verification.json`. Full logs, the unchanged native images and
read-only diagnostic receipts stay under this case's ignored `proof/`.

## Changed files

- Producers/fixtures: `tests/rr29/{samples,native_probe,paint_order,far_arm_fixture}.gd`.
- Tests: `tests/test_rr29_mimic.py`, `tests/test_rr29_historical_ranges.py`.
- Certification: `tools/art_identity_gate.py`, `tools/art_identity_prompts.py`;
  `spec/art_identity/jobs/hollow_mimic/mq11_rear/{kit.json,sheet_pair.png}`;
  only that rear entry's kit version in `spec/art_identity/registry.json`.
- Preservation/diagnostics: `experiments/cutouts/hollow_mimic/rr29_preservation.py`,
  `experiments/cutouts/hollow_mimic/rr29_native_diagnostics.py`.
- Handoff: this README and `proof/verification.json`.

## TODO_DESIGN placeholders and chosen defaults

No new or unresolved TODO_DESIGN fields. The director accepted art/motion.
New values are fixture-only named constants: `FIXTURE_ORIGIN=(128,128)`,
`FIXTURE_SCALE=(2,2)`, `CROSSING_OFFSET_PX=1`, `OUTSIDE_GAP_PX=10`.
Transform diagnostics reuse the existing `TRANSFORM_TOLERANCE=0.0001`.
All other values remain those of the approved data or prior proof contracts.

## Headless reproduction

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 tests/rr29_python_suite.py tests.test_rr29_mimic tests.test_rr29_historical_ranges tests.test_art_identity_gate
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 tools/godot_task_runner.py --task-id rr-29 --stream -- godot --headless --path . --script tests/rr29/far_arm_fixture.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && python3 tools/godot_task_runner.py --task-id rr-29 --stream -- godot --headless --path . --script tests/rr29/samples.gd -- --case experiments/cutouts/hollow_mimic/rr29 --output experiments/cutouts/hollow_mimic/rr29/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 PYTHONPATH=tools python3 experiments/cutouts/hollow_mimic/rr29_gates.py --native experiments/cutouts/hollow_mimic/rr29/proof/native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 PYTHONPATH=tools python3 experiments/cutouts/hollow_mimic/rr29_native_diagnostics.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && PYTHONPATH=tools python3 experiments/cutouts/hollow_mimic/rr29_preservation.py
```

## Proof for the design owner

Windowed captures at 1920×1080 and 100% UI scale, then review MP4:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-29 && sh experiments/cutouts/hollow_mimic/rr29_proof.sh review
```

The script names the mandated runners, contracts and manifests. Outputs:
`proof/native/`, `proof/production_native/{front,rear}/{whirlwind_slash,quick_stab,hurl_spear}/`,
`proof/hollow_mimic_review.mp4`. No inspection_fixture.py command was requested;
these probes construct their fixtures. The director owns the inspection phase.

Open issue: the old native capture cannot certify the changed proof producers.
Its 32 failures are fully diagnosed; a fresh windowed capture remains pending.
