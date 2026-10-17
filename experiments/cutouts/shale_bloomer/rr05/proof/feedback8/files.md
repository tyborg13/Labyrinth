# Feedback 8 file scope

|Files|Change|
|---|---|
|`tools/maquette_motion/joint_seams.py`|Shared-edge bands from logical rest ownership (including feature ownership), parent-depth decisions, exact nearest-parent edge paint, clipped feature-free coverage, derive validation.|
|`tools/maquette_motion/seam_builder.py`|Transactional incremental installation and provenance; retains every existing paint PNG and the 1,376 bleed texels.|
|`tools/maquette_motion/seam_pose.py`|CPU/native interior tears, report-only negative space, 2px outward extent; actual native reference-mask validation.|
|`tools/maquette_motion/pixels.py`, `silhouette.py`|Native RGBA8 alpha coverage correction; detached checks preserved; old enclosed-hole counts labelled legacy construction/history only.|
|`tools/maquette_motion/continuity.py`, `features.py`, `feature_builder.py`|Support nodes excluded from ownership and donation; feature ordering unchanged.|
|`tools/maquette_cutout_polish.py`, `maquette_cutout_build.py`|Derive/gate/promote integration, protected-input preservation, unresolved-design rejection.|
|`tools/maquette_motion/gates.py`, `tests/maquette_cutout/proof_inputs.gd`|Matching runtime/source closure, including optional director seam-parent decisions.|
|`tests/maquette_cutout/native_capture.gd`, `seam_capture.gd`, `reference_masks.gd`|Private, independent posed parts/seams/rest/interior capture surfaces. Reference masks never enter the review composition.|
|`tests/maquette_cutout/reference_mask_test.gd`|Headless Godot image-operation proof for all eight reference masks.|
|`tests/test_maquette_joint_seams.py`, `test_maquette_native_alpha.py`, `test_maquette_silhouette.py`|Band/ownership/paint mutations, native-fade regression, independent erosion verification, and preserved legacy silhouette diagnostics.|
|`tests/maquette_cutout/alpha_fixtures/`|Two immutable PNG copies and sampled transforms from the supplied Wisp native captures; source paint hashes pinned.|
|Both case layouts/config/baseline, `seams.json`, `seams/{front,rear}/*.png`, hidden-fill index, continuity/feature provenance|Derived local support and exact proof/source bindings. Existing paint, features and motion remain unchanged.|
|`rr05/README.md`, `rr05/proof/feedback8/**`|Current results, per-clip tables, per-feature outcomes, explicit TODO_DESIGN, certificates, commands and verification.|

Removed: the rejected `tools/maquette_motion/backing.py`, `tests/maquette_cutout/backing_capture.gd`, backing tests, and both case `backing/` folders and `backing.json` files. Historical feedback7 evidence remains available.

The owner proof driver remains in derive → native review → promote → density adoption → rest rebake order, with headless acceptance before native and production capture after rebake. Its existing `--from-native`, `--from-adopt` and `--creature` support and adoption-block stub tests are retained. No inspection launch is present.

`scope.json` records the whole uncommitted worktree status, including pre-existing rr-05/owner work. No shrike paths changed. Accepted native videos/captures and production outputs are checked against their prior hashes in `preservation.json`.
