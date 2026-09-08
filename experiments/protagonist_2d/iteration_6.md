# Sixth revision: coherent composable character

The canonical sprite is concept art, not an immutable torso/head onto which new limbs are attached. All visible character paint for this revision must be new and coherent. Scope is two facings, challenging static poses, and walk/attack only. Prior pass-five evidence is frozen in renders/pass5.

The existing board inspection surface asks whether each assembled pose preserves the Reaver identity, plausible anatomy and board perspective. The primary action remains switching facing/action and pausing or stepping. Keep board-first hierarchy and existing pointer/keyboard controls. Fresh proof is 1920x1080 at 100% UI scale, covering both facings, walk contact/passing, overhead preparation/forward cut, and cloak-off anatomy.

Acceptance uses the canonical image as the global style reference and the assembled new master as the within-character consistency reference. Every part must share logical pixel scale, leather/cloth/metal material values, contour thickness, light direction and body proportions. Shoulder-to-chest attachment, hip coverage, hand backs/palms, boot top/sole perspective and near/far overlap receive separate visual judgments. No aggregate numeric score can overrule a failed visual criterion.

Calibration negative: pass five is rejected for narrow limb widths against broad torso/head, finer limb texture than canonical body, implausible shoulder connection and free-hand viewing angle. Its improved foot direction is a positive subcriterion only. Connectivity and non-inverted triangles do not establish good anatomy.

Generation proceeds from a coherent new master with all appendages visible. Export independently articulated head/chest/pelvis/limbs and complete hidden joint material, plus layered cloak and any pose-specific replacement drawings needed. Judge the complete assembly before investing in the final reels.

## User corrections during the art gate

The initial multi-part atlases failed source-derived dimensions: the common-scale import reduced the head to 48 px wide versus the 73 px full traced source head envelope, and changed limb/body relationships. The original prompt also imposed inappropriate generic adult proportions. Both atlases are rejected. The user specifically requested manual splitting or individually generated components with dimension validation; no further generated collections are used.

The first guide incorrectly treated horizontal image rows as anatomical cross-body alignment. The user correctly pointed out the character is turned in isometric perspective. The corrected guide uses the production 2:1 board basis, separate near/far landmarks, and explicit uncertainty where the cloak conceals a joint. Bounding boxes are crop metadata, never proof of projected anatomy. The later whole-character projected candidate shortened the far leg beyond the reference and was rejected. The closer complete front/rear paintings are retained as paint sources for manual segmentation and individual component fitting, not accepted final rest poses.

## Final assembly and acceptance review

The final assembly uses two new coherent master paintings, manually split by authored ownership polygons and precise pixel overrides. The final rendered neutral pose is distinct from those master paint sources: new chest/back coverage, hidden shoulder/pelvis material, fitted boot/trouser pieces, removable cape and an independently held new blade complete it. All 19 runtime attachments per facing live under `assets/pass6`; none imports the old canonical head/body as runtime paint. The canonical front and earlier rear image remain concept comparisons.

The accepted head is 71×70 native pixels, close to the source's roughly 73×75 traced envelope. The masters retain a compact 214px painted height rather than the generic adult proportions of the rejected atlases. Near/far shoulders, hips, knees and soles are registered separately. The near boot's longer image-space leg is a perspective relationship, not an error to flatten onto a horizontal guide. The rebuilt rear trousers use explicit hip/knee/ankle landmarks to shorten a generated lower segment before assembly.

| Criterion | Final judgment and evidence |
| --- | --- |
| Whole character against concept | Red spiky hair, large compact head, brown scarf/leather, muted green cloak and heavy chipped blade remain recognizable. The pose is more open to expose limbs. The face is a close redraw, not a pixel-identical source cutout. Compare `references/pass6/assembly_review.png`. |
| Parts against whole | Head, chest, sleeves, trousers and boots use dark contours and clustered warm highlights at a shared native scale. The front boot's highlight is stronger than the calf; it still reads as the same worn leather. Rear chest/sleeves have broader and warmer highlight bands than the front, an acknowledged variation. Parts sheets show this without separately normalizing sizes. |
| Shoulder/hip continuity | Complete under-cloak chest/back and hidden shoulder caps fill the raised-arm opening. Pelvis material overlaps moving thighs. Cloak-off review reveals complete torso coverage across walk and overhead preparation. |
| Hands and wrist | Gloves are rigid terminal drawings, with the weapon grip separate from the palm. The free glove's thumb/knuckle silhouette reads as a closed hand from the current view. No new palm view is synthesized during these clips; the hand view remains fixed. |
| Knees, boots and floor | Rigid overlapping thigh/shin paint avoids the rejected folded mesh. Boots retain their shape, toe direction and sole plane. Stance samples stay planted during board travel, with a restrained lifted swing and 2:1 travel direction. |
| Cloak | Mantle and drape are distinct removable attachments. Gray-green collar pixels are assigned to the cloak rather than left on the head/chest. The new drape is narrower and less windblown than the source; it remains behind the appropriate arms in both views. |
| Blade | The narrow bright serrated candidate was rejected. The final new blade has broad, dull iron planes with large chips/pits, closer to the concept's weight and wear. It is not an exact copy of the original notch pattern. |
| Difficult poses | All 224 native rendered states (112 authored poses with/without cloak) were visually checked. Raised preparation, extended cut, maximum walk compression and boot passing retain attached readable silhouettes. Rear sleeve bands still reveal 2D deformation, and some knee contour overlap is visible at extreme phases. Neither produces a detached limb or folded-back boot in these clips. |

These judgments permit presenting this experiment for user inspection. They do not establish final production art approval. Numeric connectivity, pixel counts and mesh determinants cannot override a failed visual criterion; pass five remains the calibration negative despite its earlier mechanical checks.

## Motion and composability

The rig retains editable `Bone2D` and `AnimationPlayer` scenes, 21 bones and two clips per facing. Head, scarf, torso, hips, gloves, boots, blade, mantle and drape have separate assets; sleeves use complete weighted meshes and trouser sections overlap. Equipment-slot metadata groups head/neck/chest/legs/gloves/boots/cloak/weapon. Cloak visibility is demonstrated in the live inspector; swapping arbitrary production equipment is outside the implementation.

A first leg-mesh attempt was rejected for pinched/reversed opaque triangles, and a rigid two-dimensional IK setup forced an excessive pelvis dip to cover isometric travel depth. The final leg pose uses view-dependent projected segment lengths, keeps transverse paint width constant and solves a rigid boot transform at the desired contact. Godot local position/rotation/scale/skew tracks preserve those transforms after saving. This is a controlled 2D foreshortening approximation, not reconstructed 3D anatomy.

Walk retains 24 poses at 36fps with a 30px stride and 50px displacement per cycle; front and rear share the same speed and opposite 2:1 board vectors. Maximum swing lift is 7px and pelvis bob spans 3.4px. Attack uses 32 poses at 24fps, with a near-vertical preparation and faster forward/downward cut. It deliberately tests the separated shoulder/elbow/wrist/blade, with restrained torso movement; it is not a full-body combat performance. No extra idle, block or hit clips are included in this pass.

## Final proof

`renders/pass6/registered_art_validation.json` checks exact visible-pixel reconstruction of the manually split masters, current asset paths/slots, painted cuff/knee coverage, non-inverted visible geometry and rendered attachment connectivity. `motion_validation.json` samples 257 phases per clip/facing and records actual-layout foot contact, sole plane, boot basis/limb width, wrap behavior and weapon path. These checks supplement the visual reviews described above.

The final native renderer produced 224 posed frames and two assembled rest frames. Four saved-rig reload cases are pixel-identical. All 89 generator outputs reproduced byte-identically from retained sources in isolation. The fresh 1920×1080, 100% UI board proof has 39 PNGs, 256 action/travel checks and 208 lossless captured video frames. The before/after/current runtime hash set contains 886 unchanged files. Contact review covers all native poses, all board screenshot regions and all 72 paired travel phases. The decoded primary reel shows each action twice at normal speed and once at half speed with fixed framing and exact source timing.

See `renders/pass6/inspection_review.json`, `proof_manifest.json`, the versioned `board/videos/` manifests and [inspection.md](inspection.md). The verified inspection fixture is the task-local standalone scene; a production Continue save is not applicable because no production routing selects this rig.
