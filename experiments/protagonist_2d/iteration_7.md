# Seventh revision: garment connections

The user selected pass six as the strongest direction and requested focused corrections: close the visibly empty reoriented boot collars in both facings, bring boot colors closer to the trousers, remove the doubled/disconnected rear cloak neckline, and conceal hard knee cuts during walk without turning the limbs into rubber. Arms, glove/sword grip, sword artwork and motion timing remain the pass-six reference. Production integration is explicitly deferred until the next visual inspection is satisfactory.

The existing board-first inspector still asks whether the composed character reads as one dressed body during walk and attack. This pass changes attachment coverage and layering, not the controls or gameplay. Pause/step and cloak removal reveal the joints. Preserve pointer/keyboard access and shared UI components. Fresh proof is the real 1920×1080 renderer at 100% UI scale, plus native-scale boot/knee/rear-cloak close-ups and pass-six comparisons at identical registration.

Pass-six assets, references and renders remain intact. The new seam builder reads frozen layouts from the reviewed pass-six commit. It reuses the accepted paint and pose curves, generating only the changed seam assets and layout. Visual acceptance must specifically reject an empty shoe rim, a second hanging cloak collar, exposed flat leg stumps, or newly hidden hand/weapon action; prior connectivity checks did not catch those semantic art failures.

## Final construction

`seam_assets.py` owns this refinement and reads frozen sixth-pass layouts. It generates 15 changed/new images under `assets/pass7`, two runtime layouts, four rest assemblies and their common-scale comparison. All 22 files reproduce byte-identically from retained inputs. `registered_assets.py` remains the sixth-pass builder and supplies only the generic mesh helper to this pass.

Both boots now draw behind the trouser cuffs. Only the reoriented `foot_l` paint is trimmed/recolored in each facing: the front empty rim is removed above source row 199; the rear uses a shaft-local cut that preserves its raised toe. Color multipliers (0.85 red, 0.90 green, 1.10 blue) mute orange while retaining the painted value groups. Cuffs reuse nearby calf columns to fill a short hidden overlap. This changes local detail but does not rotate or reshape the established toe/sole design.

Thigh and shin cut ends use rounded overlap masks. Two rigid painted knee covers per facing follow the existing shin bones; only the outer native pixel blends alpha. Calf hems are rounded, removing pointed cutout remnants. There is no new leg skinning mesh, altered bend curve or whole-asset blur. All 112 authored existing bone matrices, the complete motion script, arm/glove/sword paintings and sleeve/mantle skin data match pass six exactly.

The rear cape drape is translated (-6,-13) in source pixels and drawn at z=72, above shoulder mantles/arms and below scarf/head. This replaces the previous doubled visible collar with the drape's own neckline at the shoulder connection. The upper cloth follows the original cape root; lower weights are re-registered to the lifted paint on the same three cape bones. The front drape is unchanged. Cloak-off still exposes complete shoulders and torso.

## Visual assessment

| Requested correction | Inspection and result |
| --- | --- |
| Empty shoe openings in both views | Same-registration before/after walk crops show the hollow rims removed, a less orange boot tone, and cloth extending into the occupied boot. Checked all 24 walk and 32 attack poses per facing with/without cloak. |
| Disconnected rear cloak | The before/after neckline crop spans rest, extension, raised preparation, cut and recovery. The drape now begins beneath the scarf and hides the old shoulder joins through those poses. Complete pose sheets verify the grip and blade remain visible. |
| Harsh knee cuts | Rounded ends, matching paint overlap and covers soften flat segment boundaries; distal calf spikes are removed. Dark painted bands remain noticeable in deep bends. This is an improvement to cutout coverage, not a claim that all joints become invisible. |
| Preserve arms, sword and gait | Existing arm/glove/sword hashes, joint hierarchy, sleeve/mantle mesh records and all 112 sampled authored bone matrices match the frozen sixth-pass baseline. The motion probe's 257 phases per action/facing retain the previous support/grip measurements. |
| Another preview before game integration | New versioned normal/half-speed walk/attack reels and the same standalone inspector. No production controller, scene routing, combat hooks or save fixture changes. |

`references/pass7/boots_knees_comparison.png` magnifies a fixed lower-body crop by 2.5×; `rear_cloak_comparison.png` magnifies a fixed neckline/body crop by 2×. These are intentionally local views, not proof of complete sword/head bounds. `comparison_manifest.json` records exact source frame hashes and cropping. Full-pose sheets and full-HD board screenshots supply the complete view.

## Verification and handoff scope

Fresh real Metal/Mobile proof covers 224 native 512px poses, exact rest reconstruction, 39 full-HD board stills, 256 board action/travel states and 208 lossless board motion frames at 1920×1080/100% UI scale. All 901 board input hashes match before/after capture. Visual inspection includes all authored poses, all 72 paired three-cycle walk phases, full UI action preparation/cloak-off/focus/detail states, and decoded normal/half-speed reel frames. The primary reel is 936×540 at 72fps, 960 frames/13.33 seconds, using one fixed native-pixel board crop with integer frame holds.

`seam_validation.json` checks the specific old empty-collar regions contain zero rigid boot pixels. The four cuffs have 127, 119, 75 and 168 shared painted pixels at rest; the rear drape overlaps 745 shoulder-level pixels. These measures support the visual evidence but do not determine art quality. `registered_art_validation.json` passes all 224 actual rendered attachments and positive visible mesh geometry. Saved front/rear rigs pass four pixel-identical reload cases. No runtime motion changed during this pass.

The required independent peer review is bound to the committed final HEAD in the task handoff. The standalone `inspection.tscn` remains the user fixture, with a post-review startup check. A production Continue fixture is not applicable: the user explicitly asked to wait before wiring the prototype into gameplay. No publication or production integration is authorized by this visual iteration.
