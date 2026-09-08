# Pass 3: complete source segmentation audit

Both painted facings were reviewed part by part at source-pixel scale. The audit corrected the reported front sleeve/cloak split and other incorrect material boundaries across the collar, wrists, torso, knees, and outline islands. No source art, joints, pivots, or hidden anatomy was added.

Run `python3 experiments/protagonist_2d/segmentation_audit.py` after either asset generator. The report is `assets/segmentation_audit.json`. Each facing also has an `ownership_overview.png` with the unchanged source beside its color-coded exclusive ownership map, a native `ownership_map.png`, and an `exclusive_part_review.png` showing every part before seam overlaps.

The final audit covers all 17 front and 14 rear exclusive base parts. It checks 78 independently selected anatomical/material landmarks, five painted-material boundary regions containing 709 pixels, connected components, every saved cutout's unchanged source RGBA, completeness of its owned pixels, and the absence of unrelated part material in joint overlaps. The front and rear reassign 1,123 and 175 source pixels respectively relative to `6bcc01b2d8b0e05729fe1d217a1006c902ba24e5`; the report records each transfer. These counts include dark contour refinements as well as visibly colored material.

Source reconstruction remains exact for all 17,246 front and 18,722 rear opaque source pixels in rigid-segment, weighted-cape, and weighted-joint assembly modes. Zero reconstruction difference is a source-preservation check; the landmark/material checks and visual reviews establish the segmentation assessment separately.

## Front assessment

| Base part | Source assessment and disposition |
| --- | --- |
| `head` | Hair, face, ear, and face covering form one rigid head silhouette. The lower boundary against the separate brown neck wrap was reviewed and retained. |
| `scarf` | The brown neck wrap follows the neck. Its incorrectly owned green outer-cloak strip now belongs to `cape_full`; the wrap no longer drags green cloth when the neck turns. |
| `cape_full` | The green long drape and opposite shoulder fold belong to the same garment. The main cape no longer owns the exposed brown upper sleeve, forearm, or hand outline. The shoulder fold was recovered from scarf, upper arm, and torso; the green edge beside the chest was also recovered from torso. |
| `torso` | Brown chest armor, harness, and central underarm contour remain together. Removed the opposite green shoulder fold and green drape edge. The lower seam against belt/hips was inspected; source-only seam overlap remains appropriate. |
| `hips` | Belt, pouches, and upper coat/tasset material remain attached to pelvis. Four isolated coat-edge pixels previously attached to the sword were returned here. Neighboring sleeve/hand boundaries were refined against the visible pouch outline. |
| `arm_r` | The visible brown sword-side upper sleeve remains below the shoulder. Green opposite-cloak-fold pixels were removed. Its shoulder and elbow source overlaps remain local to adjacent anatomy. |
| `forearm_r` | The bracer now includes its previously stolen lower band. The rigid sword/hand cut begins near the actual wrist; its shared seam moved from `(95,123), r4` to `(95,126), r3`. |
| `sword_hand_r` | The gripping hand, guard, and complete blade remain one rigid part. The distal bracer band and five unrelated trouser/coat outline pixels were removed. The part is now one connected component. |
| `arm_l` | Most of the shoulder is painted behind the cloak. The small actually visible upper-sleeve strip is retained, including its brown outer edge previously owned by the cape. The final material fence caught and corrected the top brown boundary at `(171,120)`. |
| `forearm_l` | The visible sleeve and broad bracer now move together from the elbow through the green wrist cuff. Removed cape ownership over this painted brown material and recovered bracer material previously assigned to the hand. |
| `hand_l` | The bare hand and adjacent dark outline begin at the actual wrist, around y151. The old y140 cut owned much of the bracer. The shared wrist region moved from `(166,143), r4` to `(166,151), r3`, preserving a small source-only cuff overlap. |
| `thigh_r` | The far thigh retains its trouser band and neighboring outline. Restored its outer contour pixel `(99,153)` from the sword, and inner-knee contour pixels `(133,167..168)` from the opposite thigh. |
| `shin_r` | The far lower-leg band was reviewed against the knee and boot. No new painted-material reassignment was needed; adjoining source overlap remains intact. |
| `foot_r` | The complete far boot, toe, heel, and source silhouette were retained exactly. No pivot or alpha change. |
| `thigh_l` | The near thigh and knee plate now have a coherent lower contour. The prior diagonal shin cut left isolated knee-edge pixels on the thigh and split the painted plate; the boundary now follows the lower knee rim. Removed the opposite knee's two contour pixels. |
| `shin_l` | The near lower-leg armor begins beneath that knee rim and joins the boot through the existing local ankle overlap. One dark upper ankle contour pixel `(151,200)` now follows the shin rather than the rigid boot. |
| `foot_l` | The complete near toe/heel and sole silhouette were retained. Its bounding box and pivot are unchanged; only the single upper ankle contour pixel noted above left the boot. The later walking toe turn was inspected for ankle continuity. |

The front cape intentionally has **two** exclusive visible components: the long drape and the 224-pixel opposite shoulder fold. Their connecting cloth is concealed by the head/neck wrap in the original art. Both belong to the continuous cape mesh, and the shoulder fold lies in its rigid root-weight region. All other front exclusive parts have one connected component.

## Rear assessment

| Base part | Source assessment and disposition |
| --- | --- |
| `head` | Hair, visible ear, and head contour were reviewed against the collar and retained. |
| `scarf` | The brown rear collar remains rigid on the neck. The lower green cloak hem was traced out of it row by row; its remaining brown edge pixels, including `(106,78)`, `(107,78)`, and `(107,79)`, belong to this collar rather than a detached torso island. |
| `cape_full` | The green collar hem now follows the cloak. The diagonal lower cloak/torso boundary and the full ragged hem were reviewed and retained. The resulting exclusive garment is one connected component. |
| `torso` | Exposed back/side armor and belt buckles stay together. The last isolated collar pixels were removed. Greenish buckle highlights near `(136,131)` are metal on the body, not cloak fabric, and were deliberately retained. |
| `hips` | Coat tails, pelvis, and the visible tasset outline were reviewed against both thighs. Existing full-width waist overlap is intentional source-only material, covering the small pelvis counterrotation. |
| `arm_r` | The round shoulder plate, upper sleeve, and elbow approach follow the right arm. The cape edge follows the painted shoulder occlusion. No material reassignment was needed. |
| `forearm_r` | Bracer, lower sleeve, and cuff were reviewed through the actual y145 wrist; the source split and weighted bend region remain appropriate. |
| `sword_hand_r` | Right hand, guard, and entire sword remain rigid and connected. Unlike the front's old cut, the rear boundary already followed its actual visible wrist. |
| `thigh_l` | The partially cloak-occluded far thigh remains attached to its own knee band, without borrowed cloak material. |
| `shin_l` | The far lower-leg bands were reviewed against thigh and boot; retained. |
| `foot_l` | The far boot, sole, toe contour, and pivot were retained exactly. |
| `thigh_r` | The near thigh and side armor retain their painted boundaries against hips and knee; retained. |
| `shin_r` | The near lower-leg armor and ankle band were reviewed and retained. Its greenish buckle is equipment material, not a stray cloak fragment. |
| `foot_r` | The near boot's complete sole and toe silhouette were retained exactly. Its new walking turn was inspected for ankle continuity. |

The rear left upper arm, forearm, and hand have bones but no cutouts: all three are fully hidden by the painted cloak. Inventing visible pieces for them would not be a source-only segmentation fix. Every rear exclusive visible part is one connected component.

## Animated review and limits

The first pass-3 GPU capture was reviewed as nearest-neighbor enlarged contact sheets covering **all 272 poses**: for each facing, idle 20, walk 24, attack 32, block 36, and hit 24. The review inspected the complete silhouette in every frame, including wrist/cuff contact, collar/shoulder ownership, waist and tasset attachment, thigh/knee/shin boundaries, boot continuity, sword contact, and the cloak's interior and ragged hem. The revised front arm no longer leaves brown sleeve material on the cloak as it swings clear. The front near boot's approximately 63-degree walking turn remains joined at the ankle. No further painted-part ownership defect was found in that pose set.

After that capture, three rear brown collar pixels and the final front upper-sleeve boundary point were corrected. The final pass-3 GPU capture was then compared against the first across all 272 poses, with enlarged inspection of the changed collar and sleeve regions in every frame. No further painted-part ownership defect was found. The final front changes affect at most five rendered pixels per pose. Removing the detached rear collar pixels shortens the torso texture crop; its half-pixel idle plateau also changes some interior nearest-neighbor sampling, which was inspected in full-body A/B images without a new silhouette or seam defect. Those final source-boundary changes preserve every source pixel and do not alter motion or joint positions. Final capture provenance and frame hashes are recorded by the inspection workflow.

The source does not contain hidden upper-arm, under-cloak torso, or fully crossing-leg anatomy. Large motion beyond the inspected range can still reveal those original occlusions. Source black contour pixels around occluded boundaries can be visually ambiguous; the masks follow the adjacent visible garment and continuous silhouette. This audit does not claim to reconstruct unavailable anatomy or a new camera perspective.
