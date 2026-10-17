# rr-05 feedback 8 — per-joint seam underlays

**Not ready for native acceptance.** The full-silhouette backing was removed from both cases and the active compiler/gates/probes. Local seam bands are installed for the unambiguous pairs. The strict new gates report failures; all exact poses, pixel counts and nearby joints are in the TODO_DESIGN JSON files. No motion or feature data was changed.

## Requirements and files

1. **Local underlays:** `tools/maquette_motion/joint_seams.py` derives shared unit-edge boundaries (≥3 px), sampled separation and clipped two-region bands; copies nearest parent-edge RGBA excluding features; attaches nodes to the parent bone beneath every material part. Case data is `seams.json` and `seams/{front,rear}/*.png`. Equal-depth independent siblings carry `TODO_DESIGN_seam_parent_*`, rather than an invented parent. Incremental/transactional derivation in `seam_builder.py` preserves every existing material PNG and the accepted 1,376-texel bleed.
2. **Hard gates:** `seam_pose.py` applies the 1 px eroded-rest interior test and strict 2 px outward-extent test to CPU and saved native layers. Natural negative space is measured but cannot fail the gate. Existing detached, source-transform, feature and shimmer checks remain. The old enclosed-hole metric is retained only as a labelled historical/construction diagnostic.
3. **Integration/proof:** `maquette_cutout_polish.py`, `maquette_cutout_build.py`, paired Python/GDScript proof-input bindings, `native_capture.gd` and `seam_capture.gd` carry the new nodes/data and independent all-clip native surfaces. Promotion rejects unresolved/invalid seams. `continuity.py`, `features.py`, and `feature_builder.py` exclude support bands from ownership and feature donation. The rejected `backing.py`, `backing_capture.gd`, backing tests and both case backing folders/data were removed.
4. **Preservation:** rest identity, features, physical PNGs, original motion and accepted native/production outputs are checked in `preservation.json`. The idle key remains the director’s `(0.5, 5)`. No production adoption, commits, peer review, windowed runs or inspection launch were performed.

## Results

- **shale_bloomer:** 29/48 seam nodes installed; 19 parent choices pending. 896/1008 poses have interior tears; 786 exceed 2 px protrusion; 915 distinct failing poses. Detached poses: 0. Pixel gate: FAIL (3406 errors, including repeated derive/pose diagnostics).
  CPU shimmer raw-continuous held/boundary → stepped/snapped: 759410/72292 → 0/0.
- **lightning_wisp:** 8/8 seam nodes installed; 0 parent choices pending. 667/750 poses have interior tears; 318 exceed 2 px protrusion; 667 distinct failing poses. Detached poses: 0. Pixel gate: FAIL (1970 errors, including repeated derive/pose diagnostics).
  CPU shimmer raw-continuous held/boundary → stepped/snapped: 995951/41304 → 0/0.

Full per-clip CPU-before/after, historical native-before, natural negative-space and protrusion maxima: [per_clip.md](per_clip.md). Detached-component comparisons: [detached.md](detached.md). Feature-by-feature pixels, single nodes, owner bones and sample counts: [features.md](features.md).
Files: [files.md](files.md). Saved-native alpha correction: [native_alpha.md](native_alpha.md). Necessary-condition certificates: [constraint_certificates.md](constraint_certificates.md).

Bloomer’s `front/seam_trunk_root_tip_c` and `rear/seam_trunk_core` bands each have two 8-connected components after clipping to the prescribed two-region union; this remains `TODO_DESIGN_seam_connectivity`. No bridge outside the band/union or feature masks was invented. The 19 unresolved sibling pairs are listed separately in `shale-seam_parents.json`.

The separate [design_questions.json](design_questions.json) records `TODO_DESIGN_seam_band_width_semantics`; the candidate uses total centred width with closed pixel-centre coverage. The early clarification remains unanswered.

The body-following rest-mask test counts uncovered outer petal/tail rest area as well as seam cracks. A clarification was requested; no narrower acceptance region was substituted. Band width uses the literal total-width reading of the brief; that interpretation was also surfaced to the director. Protrusion width is distance from exposed underlay to the posed paint, without rounding or tolerance changes.

CPU evidence: `output/rr-05/feedback8/cpu-evidence/contact_sheet.png` (columns: parts; parts+seams; interior tears; exposed underlay; natural negative space). Rows: Bloomer front_move 0019, front_shell 0017, rear_death 0049, front_death 0077; Wisp front_idle 0078, front_death 0065. This is CPU diagnostic replay, not renderer proof. Corresponding coordinates and spatial joint attribution are in `*-evidence.json` and full TODO files.

## Verification

The final full Godot run took 905.899s and failed the unchanged 900s budget: `sfx_sync_harness` exited 124, then the suite stopped before `section_map_v2_test`. All eight interrupted/unstarted programs subsequently passed separately. The full suite remains FAIL; no assertions or budgets were changed. Exact cause lines are in [full_godot_result.json](full_godot_result.json).

Exact commands, exit codes, durations and result lines are in [verification.json](verification.json). The finished-source `post_alpha`, `final_logic` and `manual_final` results below supersede preliminary runs made while correcting the native-alpha model. The obsolete first Godot attempt was interrupted; it has no completed suite result. The final Python run includes all 53 focused Python tests.

### post_alpha

- `shale_derive_alpha` (exit 1): `MAQUETTE DERIVATION: FAIL (2 errors)`; `MAQUETTE DERIVED POSES: FAIL; see TODO_DESIGN and run the pixel gates`
- `wisp_derive_alpha` (exit 0): `MAQUETTE DERIVATION: PASS (0 errors)`; `MAQUETTE DERIVED POSES: FAIL; see TODO_DESIGN and run the pixel gates`
- `shale_pixel_gate_alpha` (exit 1): `MAQUETTE PIXEL GATES: FAIL (3406 errors)`
- `shale_native_parse_alpha` (exit 0): `MAQUETTE NATIVE CAPTURE PARSE: PASS`
- `wisp_pixel_gate_alpha` (exit 1): `MAQUETTE PIXEL GATES: FAIL (1970 errors)`
- `wisp_native_parse_alpha` (exit 0): `MAQUETTE NATIVE CAPTURE PARSE: PASS`
- `alpha_regression` (exit 0): `Ran 3 tests in 0.776s`; `OK`; `MAQUETTE REFERENCE MASKS: PASS (8 Godot image-operation masks = independent Pillow; no renderer claim)`; `MAQUETTE NATIVE ALPHA: PASS (death/0069 and /0070: 0px mask diff; old /0070 model invented 13007px)`
- `seam_tests_alpha` (exit 0): `Ran 11 tests in 1.059s`; `OK`
- `silhouette_tests_alpha` (exit 0): `Ran 6 tests in 0.262s`; `OK`
- `evidence_alpha` (exit 0): 
- `final_evidence_alpha` (exit 0): `ORIGINAL NODE POSES: PASS [('shale_bloomer', 35784), ('lightning_wisp', 7875)]`
- `python_full_final` (exit 0): `MAQUETTE REFERENCE MASKS: PASS (8 Godot image-operation masks = independent Pillow; no renderer claim)`; `MAQUETTE NATIVE ALPHA: PASS (death/0069 and /0070: 0px mask diff; old /0070 model invented 13007px)`; `MAQUETTE CROP ANCHOR: PASS (504 front poses; maximum source-affine residual 0.000027135)`; `Ran 663 tests in 649.594s`; `OK (skipped=61)`; `MAQUETTE FEATURE DERIVATION: PASS (isolated one-pixel fixture; both approved views reconstruct exactly)`
- `godot_full_final` (exit 1): `TEST RESULT: FAIL (2 failure(s))`
- `final_checks_alpha` (exit 0): `FINAL PRESERVATION/CLOSURE: PASS`
- `output_gdignore_check` (exit 0): `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`
- `remaining_godot` (exit 0): `run_end_recap_tests 0 ['RUN END RECAP TEST RESULT: PASS']`; `main_menu_resume_test 0 ['TEST RESULT: PASS — main menu resume safety']`

### final_logic

- `shale_authored_closed` (exit 0): `MAQUETTE MOTION SAMPLES: PASS (276 bone poses)`
- `shale_authored_gate_closed` (exit 0): `MAQUETTE MOTION GATES: PASS (0 errors)`
- `shale_logic_closed` (exit 0): `MAQUETTE PRODUCTION LOGIC: PASS (1171 frames)`
- `shale_logic_gate_closed` (exit 0): `MAQUETTE MOTION GATES: PASS (0 errors)`
- `wisp_authored_closed` (exit 0): `MAQUETTE MOTION SAMPLES: PASS (180 bone poses)`
- `wisp_authored_gate_closed` (exit 0): `MAQUETTE MOTION GATES: PASS (0 errors)`
- `wisp_logic_closed` (exit 0): `MAQUETTE PRODUCTION LOGIC: PASS (1149 frames)`
- `wisp_logic_gate_closed` (exit 0): `MAQUETTE MOTION GATES: PASS (0 errors)`
- `final_preservation` (exit 0): `FINAL PRESERVATION/CLOSURE: PASS`
- `output_gdignore_final` (exit 0): `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`
- `handoff` (exit 0): 

### manual_final

- `sfx_sync_harness_finished_source` (exit 0): `SFX SYNC HARNESS RESULT: PASS (4010 observations, 0 failures)`
- `runtime_finished_source` (exit 0): `MAQUETTE CUTOUT: PASS (22130 checks, 0 failures; headless logic only)`
- `integration_finished_source` (exit 0): `MAQUETTE INTEGRATION: PASS (0 failures)`
- `living_foes_finished_source` (exit 0): `TEST RESULT: PASS`
- `final_preservation_all` (exit 0): `FINAL PRESERVATION/CLOSURE: PASS`
- `output_gdignore_all` (exit 0): `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`
- `handoff_all` (exit 0): 

### remaining_godot

- `section_map_v2_test` (exit 0): `Section map v2 suite: 0 failures (64 seeds x 6 sections)`
- `en01_enemies_test` (exit 0): `EN01 ENEMIES TEST RESULT: PASS`
- `en02_enemies_test` (exit 0): `EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)`
- `en03_enemies_test` (exit 0): `EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)`
- `magic_deck_input_test` (exit 0): `TEST RESULT: PASS`
- `run_end_recap_tests` (exit 0): `RUN END RECAP TEST RESULT: PASS`
- `main_menu_resume_test` (exit 0): `TEST RESULT: PASS — main menu resume safety`

## TODO_DESIGN, defaults, open issues

Every failing sampled pose is retained under `TODO_DESIGN_interior_tear_*` and/or `TODO_DESIGN_seam_protrusion_*`, with clip, frame, pixel count and nearby joint. `TODO_DESIGN_interior_reference_constraints` records six concrete poses where the root-following eroded-rest target contains pixels more than 2px from the fixed posed material union: no admissible underlay can cover those pixels under the chosen outward-extent metric. No motion amplitudes were reduced. Equal-depth sibling ownership and the two disconnected bands need director decisions. Strict gates currently prevent the native/adoption pass from proceeding.

Chosen defaults: no new player-facing defaults. Named synthetic fixture/debug values, derivation conventions, reference/measurement conventions and runner fields are recorded in [chosen_defaults.json](chosen_defaults.json). Director thresholds remain 3 px shared boundary, separation+1 px band width, 1 px erosion, and 2 px maximum protrusion.

Proof for the design owner: [owner_commands.md](owner_commands.md). Native-after captures, review MP4 regeneration, promotion, density adoption and production rebake remain windowed owner work; the command remains resumable and filtered.
