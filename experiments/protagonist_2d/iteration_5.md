# Fifth revision: animation-ready anatomy

The user authorized new artwork, alternate poses and components while asking for the closest possible resemblance to the canonical sprite. The deliverable remains two editable front/rear rigs, all five clips, and an actual-board reel.

The inspection surface asks whether the recognizable Reaver can move convincingly through idle, a fast grounded walk, overhead attack, block and hit. Existing board-first hierarchy, UiSkin/UiTypography, pointer and keyboard controls, pause and frame-step stay in use. Fresh proof targets all ten action/facing combinations at 1920x1080 and 100% UI scale.

Art direction: retain the original head, scarf, torso, belt, cloak and chipped sword as identity anchors. Generate full sleeves, gloves, trousers, shins and boots with hidden joint material and appropriate front/rear foot perspective. Reject softer, brighter or noisy candidate art before rig integration; prompts and candidate assessments live in references/pass5/prompts.json.

Working design: continuous skinned sleeves/trousers with complete joint material; rigid gloves and boots overlap their adjoining meshes. Painted feet already face into the travel direction, avoiding the large rotations imposed on earlier combat-stance boot views. The canonical original remains the static identity comparison; the new assembled neutral image is a distinct reconstruction target.


## Final art selection and construction

The full new master changed too much of the face, costume values and pixel texture. Retaining the canonical identity regions proved the closer match. Two initial limb candidates were rejected for fake transparency, smooth shading and fine noise. The final front/rear atlases were reviewed as native-size pieces, an assembled character and full motion. The limbs preserve subdued brown material and coarse highlight groups; each pair has the appropriate painted toe/heel direction. All new paint comes from built-in ImageGen. The importer only keys, crops, resizes, partitions and assembles it.

Complete thighs alone exposed the lack of a hidden pelvis, so a separately painted underlay now fills the body beneath the belt/flaps. A compound fist/blade forced wrist folds in the large attack/block rotations; separate generated gloves and grip shafts let the weapon pivot with the wrist while the glove follows the forearm. The blade and guard retain the existing pixels. These are reusable structural lessons: complete overlap material, full proximal caps, rigid terminal collars, and distinct hand/weapon transforms should be authored before tuning animation.

The new boot views remove the need for large perspective-simulating rotations. The walk remains 36fps, 24 poses, with a slightly longer 34px stride and gait-matched travel. Upper-arm lift strengthens the blade preparation; the cut remains down and forward. The front cloak covers the hidden shoulder and the forearm draws in front. Sleeve pieces share source-space topology and weights at overlaps, and the two leg skins run continuously into rigid boots.

## Results and proof

Both 21-bone rigs reconstruct their new assembled neutral targets within one 8-bit color code, with exact alpha. The canonical front and prior rear remain separate static identity comparisons. Complete anatomy intentionally changes their neutral pose and silhouette.

All 272 authored poses were visually inspected, alongside all 40 native board regions and 72 front/rear travel pairs. Metal/Mobile proof at 1920×1080 and 100% UI scale checked 416 poses/travel states and captured 368 lossless frames. Ten saved/reloaded action comparisons are pixel-identical. The new contract verifies preserved identity hashes, normalized weights, common sleeve overlap, rigid glove/boot attachment and no collapsed/reversed opaque limb triangles. All rendered poses have one major connected body component. Numeric validation supplements art review; it does not define art quality.

The primary board reel contains all five actions, both facings, two normal-speed runs and one half-speed run each. Its 1,920 frames last 26.67 seconds at 72fps, preserving authored 24/36fps timing by integer duplication. One fixed board crop contains every sword pose and all three travel cycles. Fourteen MP4 outputs passed complete decode/dimension/timing checks. The 39 generated art/layout files reproduced byte-identically from the retained inputs.

The UI rubric passes: the board remains the main inspection surface, with shared skin/typography, legible selected and keyboard-focus states, original/live comparison, separate detail bones and pause/frame-step. Full pose retains the complete motion canvas; the deliberately original-sized comparison crop can clip an extended sword. The production static shadow is reused. Rear hair/cloak highlights still reflect the earlier painted interpretation. New limbs look slightly more relaxed and slimmer than the original combat stance; continuous turning and production animation routing remain outside this study.
