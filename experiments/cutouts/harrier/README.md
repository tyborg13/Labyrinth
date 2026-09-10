# Bone Harrier cutout

The implementation and motion contract are documented in [the runtime specification](../../../spec/harrier_cutout_runtime.md). The final editable source case is `v02/cutout.json`; production owns a copy of its layout and material closure in `assets/units/harrier_cutout/`.

## Proof authority

`runtime_v3/assets` is the final native production/case comparison: 772 identical full-canvas renders, four facings, all five clips, fresh input digests and no errors. It includes a small outward correction to rear casting preparation after retained gameplay exposed a spear/health-frame overlap. Exactly 42 rear casting frames changed from `runtime_v2`; all other 730 frames are pixel-identical. The new rear cycles were inspected in full. `runtime_v3/inspection_sheets` assembles all final rendered poses, and `hud_clearance_asset_audit.json` confirms zero casting paint overlap with the health rectangle at the gameplay fixture scale.

`runtime_v3/front_source_preservation.json` verifies all 8,999 original opaque front pixels. `reflection_audit.json` distinguishes exact reflected pixels from nearest-neighbor subpixel edge differences; all silhouettes agree within one source pixel. The documented one-pixel adjustment to an image flip follows Godot's geometry pivot and image pixel-center convention.

The focused Harrier suite, affected full Godot suite, 16 toolkit Python tests, structural validation, and isolated production-only PCK execution pass. Their logs and export digests are in `runtime_v3`; the unchanged toolkit test log is retained from its earlier run. The non-editor runtime loads raw production PNG/JSON without experiments, toolkit scripts, or imported image caches. The macOS certificate warning in the headless runtime log is unrelated to the cutout and precedes the explicit export PASS.

`runtime_v3/gameplay` passes all 29 native clips at 1920×1080 and 100% UI scale. All four intents match the existing engine outcomes in all four facings. Maximum measured support-foot drift is 0.000137 pixels, and casting paint never intersects the actual health-bar rectangle. Projectile origins stay fixed through recovery. Reduced motion, independent actors, death, controller cancel, pointer handoff and actual player repositioning pass. All 71 retained native stills were inspected using unscaled board/HUD crops, including full original screens for the corrected casting clearance. The 90.6-second replay passes recorded-timestamp duration and full-decode checks.

`v02/proof_01` is the final editable-scene proof: 608 native samples, all 14 pixel-identical save/reload comparisons, and a 12.033-second preview that passes duration and full-decode checks. `verify-render` accepts all 1,070 inputs and 1,431 outputs. Maximum support drift is 0.000087 source pixels, target error is 0.000063, and rigid-basis error is 0.0000006. All ten complete front/rear cloth-hidden cycles were inspected in `runtime_v3/case_inspection`, together with full native board and keyboard-focus screens. The study uses a generic 30-HP proxy; the actual Harrier gameplay captures establish production HUD clearance.

See [the completion report](completion_report.md) for the requirement-to-proof map and remaining inspection boundary.

## Retained history

`v01` preserves the first segmentation and native proof. `runtime_v1` preserves intermediate bakes, the earlier gameplay replay, and explicitly named failure logs. These are historical evidence, not final acceptance. In particular, the earlier gameplay checks passed, but an import-sidecar change made that capture unsuitable as the final source witness. The complete earlier native sequence remains locally available and its timestamped videos and raw-frame hashes are retained.

`runtime_v2/gameplay_withdrawn_for_renderer_coordination` records the waiting request withdrawn at the coordinating task's instruction. It never launched Godot. Its exact command and input hashes are preserved for resumption.

The task-local `.gitignore` excludes only per-frame gameplay JPEG sequences from Git. They remain on disk for frame-level review; timestamped 60 Hz videos, selected native stills, manifests, source hashes and raw-frame hashes form the portable gameplay package. All native case proof frames remain part of the portable saved-scene proof.

## Reproduce

Run these in this worktree with its configured Godot environment and the repository runners. Use fresh output directories. Keep only one GUI request active or queued for this task.

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/harrier/v02
python3 experiments/cutouts/harrier/capture_runtime.py assets experiments/cutouts/harrier/runtime_v4/assets
python3 experiments/cutouts/harrier/package_assets.py experiments/cutouts/harrier/runtime_v4/assets
python3 experiments/cutouts/harrier/capture_runtime.py gameplay experiments/cutouts/harrier/runtime_v4/gameplay
python3 experiments/cutouts/harrier/package_gameplay.py experiments/cutouts/harrier/runtime_v4/gameplay
python3 tools/cutout_workflow.py render experiments/cutouts/harrier/v02 --output experiments/cutouts/harrier/v02/proof_02 --task-id animate-harrier-cutout --backend metal --gui-lease-timeout 1800
python3 tools/cutout_workflow.py verify-render experiments/cutouts/harrier/v02 --output experiments/cutouts/harrier/v02/proof_02
```

The optional `--gui-lease-timeout` forwarding is the only maintained-tool change: it allows the shared enemy batch to wait for the existing renderer lease without changing startup or capture watchdogs.
