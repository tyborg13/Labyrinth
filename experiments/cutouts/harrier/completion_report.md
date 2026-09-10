# Bone Harrier implementation and proof

The Bone Harrier now uses an editable front/rear skeletal cutout in production combat. Its planted bob, grounded walk and guarded retreat, forward Rush thrust, and overarm Pelt/Darting Pelt casting preserve the accepted thin skeleton, crest, wraps, worn cloth, gripped spear, and portrait. Combat rules and engine outcomes remain unchanged.

Task: `animate-harrier-cutout`; branch: `codex/animate-harrier-cutout`; base: local `master` at `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`. The adopted contract is high risk. Publication requires user inspection and explicit approval for the exact peer-reviewed commit. This report records implementation evidence; peer review and the final inspection fixture are supplied separately against that commit.

## Requirement and proof map

| Requirement | Implementation and final evidence |
| --- | --- |
| Preserve accepted front and create a matching rear | `v02/source/generation_requests.json` retains prompts, reference roles, selected/rejected sources and digests. Layout ownership, registration and hidden-body recipes are in `v02/recipes`. `runtime_v3/front_source_preservation.json` proves all 8,999 accepted opaque front pixels unchanged after uniform registration. |
| Editable anatomical rig, rigid spear and continuous cloth-hidden body | `v02/cutout.json`, front/rear final layouts, 18 joints, 20 parts and 10 weighted meshes per view. `v02/proof_01/front.tscn` and `rear.tscn` retain Skeleton2D and AnimationPlayer. All ten complete cloth-hidden cycles were visually inspected; record: `runtime_v3/case_inspection/inspection_review.json`. |
| Native complete motion in four facings without clipped paint | `runtime_v3/assets/comparison.json`: 772 full 512×512 poses, production/case pixel equality, no errors. Twenty complete-cycle contact sheets and reflection audit are beside the capture. One-pixel reflected edge variation is explicitly measured and explained. |
| Saved scenes reproduce authored animation | `v02/proof_01/render_manifest.json`: 608 native samples, 14 pixel-identical save/reload comparisons. Maximum support drift 0.000087 pixels, target error 0.000063 and rigid-basis error 0.0000006. `runtime_v3/verify_render.json`: 1,070 inputs and 1,431 outputs verified. |
| Actual combat animation and unchanged outcomes | `runtime_v3/gameplay/manifest.json`: 29 clips, all four intents in all four facings. Actual RunScene outcomes match player/enemy HP, block, position, statuses and initiative. Release/contact boundaries, fixed ranged origin and actual movement-driven facing pass. Maximum planted drift 0.000137 board pixels; actual health-frame intersection is zero. |
| Accessibility, input and lifecycle | Gameplay proof includes four reduced-motion intents, independent actors, preview echoes, controller targeting/cancel, pointer handoff, actual player movement and lethal same-pose dissolve. Focused suite covers hidden idle pause, stable texture ownership, ground anchoring and animation boundaries. |
| Correctly timed native preview | `runtime_v3/gameplay/video_timeline.json`: 90.6-second replay, source timestamps and 60 Hz frame repetition. `v02/proof_01/videos/encoding.json`: 12.033-second authored reel. Both pass per-clip duration checks and full decode. |
| Production ownership and exports | `assets/units/harrier_cutout/` and `scripts/harrier_cutout/` own the runtime closure. `runtime_v3/export_build.log`, `export_runtime.log`, and `export_sha256.json` prove raw PNG/JSON in an isolated PCK running under the unmodified non-editor macOS debug template, without experiments, toolkit or imported image cache. |
| Regression and structural checks | `runtime_v3/focused.log`, `full_suite.log`, `structural.json`, and `toolkit_tests.log` all pass. The 16 toolkit Python tests were run after the only toolkit change and their unchanged log is retained from that run. |

## Visual inspection

The final 772 native production poses were inspected as complete cycles. The late rear casting clearance correction changed 42 casting frames only; comparison with the preceding capture confirms the remaining 730 poses are pixel-identical. The final rear casting cycles were inspected in full after that correction. All 71 retained native gameplay stills were inspected through 18 unscaled board/HUD contact pages, with full original 1920×1080 rear preparation and front Rush contact screens. The corrected spear clears the actual health ornament. Full native cloth-hidden scenes, all ten cloth-hidden cycle sheets, cast study screens and keyboard-focus screen were also inspected. No unresolved anatomy, grip, ground contact, clipping, facing or feedback alignment defect was found.

The final image preview is `runtime_v3/assembled_native.png`. The actual gameplay replay is `runtime_v3/gameplay/videos/harrier_gameplay_review.mp4`. The editable-scene replay is `v02/proof_01/videos/cutout_review.mp4`.

## Scope and limitations

Shared edits are limited to Harrier presentation routing in `combat_board_view.gd` and `run_scene.gd`, raw JSON export inclusion, suite registration, and forwarding the optional existing GUI lease timeout through the cutout workflow. The timeout change leaves startup and runtime watchdogs unchanged. No enemy data, AI, ranges, action resolver, status/damage boundaries or analytics schema changed. The intent-cycle balance remains 13.4.

The logical 255-pixel rear rest is a reference crop and clips the far spear tip; the production and native proof render the complete spear on the padded 512-pixel canvas. The front rest alone supplies stable HUD/shadow bounds. Reflection can select neighboring subpixel texels while staying within one source pixel of the expected silhouette. Native runtime export was tested on macOS; Windows-compatible typed array assignments are retained, but a Windows executable was not run. The headless macOS certificate warning and full-suite ObjectDB shutdown warning precede successful test completion and are recorded in the logs.

Historical versions and labeled failed/withdrawn attempts remain available, but final acceptance uses only the authority paths above. Per-frame gameplay JPEGs remain local; videos, selected native stills, manifests and raw-frame SHA-256 witnesses are portable. All final native case pose images and saved scenes are retained. Reproduction commands are in `README.md`.
