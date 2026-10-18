# Files changed

- Generic seam derivation: `tools/maquette_motion/joint_seams.py`; report-only metrics and compact evidence: `seam_pose.py`, `seam_builder.py`, `silhouette.py`.
- Exact current rest comparison and zero boundary threshold: `pixels.py`, `tools/maquette_cutout_polish.py`. Read-only promotion prerequisites: `tools/maquette_cutout_build.py`.
- Focused tests: joint seams, owner proof script, pixel presentation.
- Derived Bloomer/Wisp seam PNGs, layouts, baseline hashes and current case proofs. Original paint, feature declarations/masks and motion are unchanged.
- Resumable owner script comment and final rr05 summary/report files.
- Earlier 189 evidence files archived byte-for-byte; tracked originals deleted.

Tracked changes (D = archived original):

```text
M	experiments/cutouts/lightning_wisp/mq4/baseline.sha256.json
M	experiments/cutouts/lightning_wisp/mq4/hidden_fills/index.json
M	experiments/cutouts/lightning_wisp/mq4/layouts/front.json
M	experiments/cutouts/lightning_wisp/mq4/layouts/rear.json
M	experiments/cutouts/lightning_wisp/mq4/proof/continuity.json
M	experiments/cutouts/lightning_wisp/mq4/proof/continuity_samples.json
M	experiments/cutouts/lightning_wisp/mq4/proof/feature_derivation.json
M	experiments/cutouts/lightning_wisp/mq4/seams.json
M	experiments/cutouts/lightning_wisp/mq4/seams/front/seam_core_arc_left.png
M	experiments/cutouts/lightning_wisp/mq4/seams/front/seam_core_arc_right.png
M	experiments/cutouts/lightning_wisp/mq4/seams/front/seam_core_crown.png
M	experiments/cutouts/lightning_wisp/mq4/seams/front/seam_core_tail.png
M	experiments/cutouts/lightning_wisp/mq4/seams/rear/seam_core_arc_left.png
M	experiments/cutouts/lightning_wisp/mq4/seams/rear/seam_core_arc_right.png
M	experiments/cutouts/lightning_wisp/mq4/seams/rear/seam_core_crown.png
M	experiments/cutouts/lightning_wisp/mq4/seams/rear/seam_core_tail.png
M	experiments/cutouts/shale_bloomer/mq3/baseline.sha256.json
M	experiments/cutouts/shale_bloomer/mq3/hidden_fills/index.json
M	experiments/cutouts/shale_bloomer/mq3/layouts/front.json
M	experiments/cutouts/shale_bloomer/mq3/layouts/rear.json
M	experiments/cutouts/shale_bloomer/mq3/proof/continuity.json
M	experiments/cutouts/shale_bloomer/mq3/proof/continuity_samples.json
M	experiments/cutouts/shale_bloomer/mq3/proof/feature_derivation.json
M	experiments/cutouts/shale_bloomer/mq3/seams.json
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_petal_near_l_tendril_high_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_petal_near_r_tendril_high_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_root_stem_c_root_tip_c.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_root_stem_r_root_tip_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_root_stem_r_root_tip_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_tendril_high_l_root_tip_c.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_tendril_low_l_root_tip_c.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_petal_near_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_petal_near_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_root_stem_c.png
D	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_root_tip_c.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_root_tip_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_tendril_high_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_tendril_high_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_tendril_low_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_tendril_low_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_petal_far_l_tendril_high_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_root_stem_l_root_tip_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_tendril_high_l_root_tip_c.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_core.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_petal_far_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_petal_far_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_root_stem_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_root_tip_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_tendril_high_l.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_tendril_high_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_tendril_low_r.png
M	experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_trunk_tendril_mid_l.png
M	experiments/cutouts/shale_bloomer/rr05/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/case_validation.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/director_inputs.sha256.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/features.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/focused_results.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/godot_full.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/integration.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/living_foes.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/output_gdignore.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/pixel_tests.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/protected_inputs.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/python_full.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/runtime.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/semantic_tests.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale-authored-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale-derive.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale-logic-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale-pixel-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_authored.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_authored_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_logic.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_logic_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_native_parse.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_pixel_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/shale_pixels.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/suite_results.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp-authored-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp-derive.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp-logic-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp-pixel-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_authored.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_authored_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_logic.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_logic_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_native_parse.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_pixel_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback1/wisp_pixels.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/capture_cleanup.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/direct_inverse_comparison.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/director_evidence_sha256.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/director_run1_frames.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/director_run1_pixel_frames.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/director_run1_pixel_gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/director_run1_pixel_samples.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/director_windowed_run1.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/features.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/final_checks.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/focused_results.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/godot_full.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/initial_mismatches.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/integration.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/living_foes.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/native_matrix_comparison.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/native_regression.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/native_regression_before.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/output_gdignore.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/owner_script_control_flow.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/pixel_tests.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/protected_inputs.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/python_full.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/runtime.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/saved_capture_replay.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/saved_native_transform_oracle.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/semantic_tests.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale-authored-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale-logic-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale-pixel-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_authored.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_authored_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_logic.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_logic_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_native_parse.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_pixel_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/shale_pixels.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/suite_results.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp-authored-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp-logic-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp-pixel-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_authored.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_authored_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_logic.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_logic_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_native_parse.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_pixel_gate.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback2/wisp_pixels.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/bloomer_native_replay.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/bloomer_outputs.sha256.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/capture_cleanup.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/diagnosis.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/director_run2_wisp_frames.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/director_run2_wisp_pixel_frames.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/director_run2_wisp_pixel_gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/director_run2_wisp_pixel_samples.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/director_windowed_run2.log
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/pre_fix_runtime_corrected_raster_replay.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/preservation_and_attachment.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback3/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/TODO_DESIGN.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/before_after.csv
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/before_after.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/before_after.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/preservation.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/scratch_cleanup.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/wisp_native_before.sha256.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback4/wisp_native_raster_diagnosis.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/TODO_DESIGN.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/TODO_summary.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/amendment_evidence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/before_after.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/before_continuity.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/chosen_defaults.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/features.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/features.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/preservation.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/python_failures.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/scope.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/scratch_cleanup.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/shimmer.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback6/wisp_runtime_equivalence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/chosen_defaults.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/features.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/features.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/historical_native_before.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/owner_commands.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/per_clip.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/preservation.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/results.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/scope.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/scratch_cleanup.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/shale-TODO_DESIGN.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/shale-evidence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/shimmer.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/wisp-TODO_DESIGN.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/wisp-evidence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback7/wisp_runtime_equivalence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/README.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/chosen_defaults.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/constraint_certificates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/constraint_certificates.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/design_questions.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/detached.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/features.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/features.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/files.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/full_godot_result.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/motion_preservation.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/native_alpha.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/original_pose_equivalence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/owner_commands.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/per_clip.md
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/preservation.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/results.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/scope.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/scratch_cleanup.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/shale-TODO_DESIGN.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/shale-evidence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/shale-seam_parents.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/wisp-TODO_DESIGN.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/wisp-evidence.json
D	experiments/cutouts/shale_bloomer/rr05/proof/feedback8/wisp-seam_parents.json
D	experiments/cutouts/shale_bloomer/rr05/proof/gaoler_rebuild.log
D	experiments/cutouts/shale_bloomer/rr05/proof/godot_full.log
D	experiments/cutouts/shale_bloomer/rr05/proof/godot_full_initial.log
D	experiments/cutouts/shale_bloomer/rr05/proof/godot_full_seed_failure.log
D	experiments/cutouts/shale_bloomer/rr05/proof/pixel_tests.log
D	experiments/cutouts/shale_bloomer/rr05/proof/pre_mask_verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/python_full.log
D	experiments/cutouts/shale_bloomer/rr05/proof/python_full_initial.log
D	experiments/cutouts/shale_bloomer/rr05/proof/runtime.log
D	experiments/cutouts/shale_bloomer/rr05/proof/seeded_foes.log
D	experiments/cutouts/shale_bloomer/rr05/proof/shale-pixel-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/shale-production-logic-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/shale_logic.log
D	experiments/cutouts/shale_bloomer/rr05/proof/shale_native_parse.log
D	experiments/cutouts/shale_bloomer/rr05/proof/verification.json
D	experiments/cutouts/shale_bloomer/rr05/proof/wisp-pixel-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/wisp-production-logic-gates.json
D	experiments/cutouts/shale_bloomer/rr05/proof/wisp_logic.log
D	experiments/cutouts/shale_bloomer/rr05/proof/wisp_native_parse.log
M	experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh
M	tests/test_maquette_joint_seams.py
M	tests/test_maquette_owner_proof.py
M	tests/test_maquette_pixel_polish.py
M	tools/maquette_cutout_build.py
M	tools/maquette_cutout_polish.py
M	tools/maquette_motion/joint_seams.py
M	tools/maquette_motion/pixels.py
M	tools/maquette_motion/seam_builder.py
M	tools/maquette_motion/seam_pose.py
M	tools/maquette_motion/silhouette.py
```

New unit files:

```text
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_core_petal_far_l.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_core_petal_far_r.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_core_petal_near_l.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_core_petal_near_r.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_petal_far_l_petal_far_r.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_petal_near_l_petal_far_l.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_petal_near_l_petal_near_r.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_petal_near_r_petal_far_r.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_tendril_high_r_tendril_low_r.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_root_tip_c_component_01.png
experiments/cutouts/shale_bloomer/mq3/seams/front/seam_trunk_root_tip_c_component_02.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_core_petal_far_l.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_core_petal_far_r.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_core_petal_near_l.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_core_petal_near_r.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_petal_near_l_petal_far_l.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_petal_near_l_petal_near_r.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_petal_near_r_petal_far_r.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_root_stem_l_root_stem_r.png
experiments/cutouts/shale_bloomer/mq3/seams/rear/seam_tendril_low_l_root_stem_l.png
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/README.md
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/archive_manifest.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/chosen_defaults.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/features.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/features.md
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/files.md
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/native_boundary_evidence.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/owner_commands.md
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/per_clip.md
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/preservation.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/protected_inputs.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/repo_size.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/results.json
experiments/cutouts/shale_bloomer/rr05/proof/feedback9/verification.json
```
