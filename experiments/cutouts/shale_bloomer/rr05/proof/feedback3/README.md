# Director feedback 3: Wisp core attachment and triangle coverage

The director's second native run passes Bloomer capture, verification and the
1,212-frame MP4. These outputs are preserved byte for byte, pinned by
`bloomer_outputs.sha256.json` (25,376 files). Only the failed Wisp capture
folder is removed after retaining this diagnosis, original manifests, log and
four small immutable native regression PNGs.

## Diagnosis

There are two independent defects. Neither is a tolerance issue.

1. Runtime: `pixel_presentation.gd` snapped each crop origin independently,
   including multiple logical details explicitly mapped to the same core bone.
   Converting the captured sprite matrices back to a common source origin
   (`painted * translate(-crop_offset)`) proves this introduces relative motion.
   At rear idle frame 12, core translation is `(1.5039256, -1.6309085)` while
   `arc_left` is `(0.8322407, -1.8386466)`: a relative displacement of
   `(-0.6716849, -0.2077381)` source pixels. The linear components are identical.
   Front frame 12 likewise gives different translations for core and eye. These
   are native captured transforms, not an inference from the CPU sampler.
2. Verifier: floating barycentric coverage can reject a pixel from both
   triangles along their shared diagonal. It also included bottom/right outer
   edges, which native top-left raster coverage excludes. For front eye frame
   0, model and captured bounds both equal `[238,274,252,288)` but the model
   paints 162 pixels versus the captured 166: four missing diagonal pixels at
   `(241,277), (243,279), (246,282), (248,284)`. At rear arc_left frame 12,
   model bounds are `[237,236,317,302)` while native bounds are
   `[237,236,317,301)`. The model adds 13 pixels on row 301 (x=239..251).
   Its rounded bottom edge is exactly y=301.5, through pixel centers. Top-left
   coverage excludes that bottom row. Full matrices, RGBA differences, source
   and capture hashes are in `diagnosis.json` and the immutable Wisp fixture
   manifest under `tests/maquette_cutout/native_fixtures/`.

The eye rest failure is a coverage-model defect: its captured frame-0 source
transform already equals core's. Runtime attachment errors occur at other
poses, so fixing only the model would leave the explicit rr-04 rule violated.

## Fix and regressions

- Bones carrying several authored logical parts use their existing owner crop
  as the single snapping anchor. All attached detail, feature and hidden-fill
  crops preserve their source-space offsets under that exact affine transform.
  The Wisp core's presentation is preserved. One-logical-part bones, including
  Bloomer, retain their already verified path. Child crop origins may be
  fractional under the owner's scale/rotation; rounding each one independently
  again would recreate the bug. The owner's source origin is whole-pixel and
  its rotation still quantizes to 1.5 degrees. The board canvas remains aligned.
- The independent oracle checks owner snapping and exact shared source mapping.
  It still validates raw authored transforms, full-rate actions and all poses.
- Raster coverage now uses exact integer edge equations on the existing
  8-fractional-bit vertex grid, with top-left inclusion. No epsilon, changed
  raster constants, relaxed assertions or increased tolerances were added.
- Red regressions: native fixture suite fails two subchecks (4 and 13 pixels);
  actual headless core-attachment regression fails 5,366 pose/part subchecks.
  Logs: `output/rr-05/feedback3/*_regression_before.log`. Both pass after fixing.
  Restoring independent crop snapping is rejected for eye and both-view veins.
- Correcting raster coverage alone, while replaying the original per-crop
  runtime/oracle, clears all 14 original Wisp errors: held residual 0, boundary
  residual 9 pixels total, within the unchanged 1% gate. This historical replay
  is archived as `pre_fix_runtime_corrected_raster_replay.json`; it is not proof
  of the corrected runtime. Fresh Wisp native proof is still required.

Current verification is complete in `verification.json`: both headless feature/
shimmer gates pass; runtime 16,430 checks pass; integration and all focused
mutations pass. Full Godot reports `FULL SUITE RUNTIME: 868.307 seconds (budget
900 seconds)` and `TEST RESULT: PASS`. Full Python reports `Ran 635 tests in
536.887s` and `OK (skipped=61)`. Both runners exit 0. Closing hashes reconfirm
the protected inputs, all Bloomer outputs and case baselines unchanged.

No masks, owners, reasons, source art, director motion, compiled tracks or
production assets were edited for feedback 3. TODO_DESIGN: none. Chosen defaults:
`COMMAND_STUB_TIMEOUT_SECONDS = 10` bounds the inert shell control-flow test.
Integer top-left inclusion follows the saved native coverage. Existing proof
tolerances and the 8-bit vertex grid are unchanged.

## Proof for the design owner

Run the selected creature from native review, under the director lock:

```sh
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature lightning_wisp
```

The checked-in script expands to the exact native capture/verified MP4 command,
then promote, selected density adoption, native rest rebake, density recording,
shared shadow-cache generation/audit, and selected production capture/gates.
The shared cache is one global resource; it is rebuilt once after selected
rests, without recapturing Bloomer or rewriting its MP4. `--creature` also works
without `--from-native` to include just that creature's derive. No inspection
launch is included. Windowed commands have not been attempted by the worker.
