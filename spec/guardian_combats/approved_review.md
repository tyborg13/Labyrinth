# Visual inspection record — pass 03

**14 September 2026 · Static design/art review; no game integration**

The review covered all thirteen front/rear pairs, all portraits, six map emblems, six relic icons, four prop states and the new command/category icons. Character paint was compared with current Chainbound Gaoler, Frostglass Lancer, Tunnel Crawler and protagonist sprites. Map and relic art used their existing production families as references.

## Character audit

| Character | Inspection and disposition |
|---|---|
| Ashen Reaver | Rebuilt the front with a closed helmet, covered arms, broad steel planes and coarse pixels. Derived a matching rear, portrait and bronze map head. The sword and large shoulder remain on the same anatomical side. |
| Rimejaw | Checked the four limbs, long skull/tusks, horn pair, spinal plates and tail. Retained the rear three-quarter paint; registered both views to the same body height. |
| Storm Cantor | Checked back wraps, forked helm, spear hand and feet against the front. Retained the paint; centered the body independently of the spear's silhouette. |
| Gallows Roc | Rejected rear paint with ambiguous wing orientation and front-facing talons. Rebuilt a more direct dorsal view with visible back mantle/wing roots and rear toes. Tightened the portrait to the head. Ground registration uses the feet, not the trailing tail tip. |
| Craghide | Rebuilt the rear around a nearer rump and small hind paws, with large digging foreclaws farther away. Checked short tail, four-limb attachments, scutes and bulk. |
| Last Lamplighter | Rebuilt the whole rear, including hood, back, elbows, calf/heel view and lantern arm. The lantern stays in the anatomical left hand. No front mask or knee plates pasted onto a back-facing torso. |
| Ash Hound | Checked four legs, backward head orientation, haunches and tail attachment. Retained the paint; matched body height. |
| Rime Whelp | Checked four limbs and the smaller skull/tusks/ice growths. Retained the paint; corrected the apparent size increase from independent bounds fitting. |
| Rime Spitter | Rejected the ambiguous extra-leg rear. Rebuilt with two near hind legs, forelegs farther away and the far foreleg occluded. Restored the short icy-tipped tail without adding a limb. The throat sac stays under the head. |
| Bell Tender | Checked staff grip, hood back, robe and boots. Retained the rear and matched scale. |
| Roc Fledgling | Rebuilt a clear back view with short wings rooted at the shoulders and rear-facing feet. Matched body height; the rear can be narrower because of the camera angle. |
| Stoneback Mite | Checked the three leg pairs, shell overlap and absence of a front mandible face on the rear. Retained the paint; perspective occlusion is allowed. |
| Wick Shade | Checked hood, clawed arms, two feet and cloth silhouette. The small wick opening appears only at the front. Retained the corrected identity and rear. |

The four large anatomy contact sheets are [page 1](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/review/audit_0.png), [page 2](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/review/audit_1.png), [page 3](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/review/audit_2.png), and [page 4](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/review/audit_3.png).

## Export and presentation checks

- Native generated paint is retained. Most sources used an explicit magenta matte; Raised Cover returned real alpha. Baked checkerboard attempts were rejected.
- Technical preparation only removes the supplied matte, cleans its narrow edge contamination, uniformly resamples and positions the art. ImageGen performed all anatomy and design repainting.
- Each character pair shares a body-height target and foot baseline. Explicit body-center landmarks keep a held weapon from shifting the actor between views. The lit/dark brazier shares an identical transform.
- Unit/prop exports are 255×255, portraits 128×128, relic/command/category icons 96×96, and map components/emblems 256×256. Transparent padding is retained; no final export may clip its paint.
- Inspected the assembled guardian, helper, map, relic, prop and scale sheets, including small portrait/icon samples. Current production map art is circularly clipped in the size study, following the map's existing presentation.
- File, alpha, uniqueness, pair-registration and checksum results are recorded in [validation.json](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/validation.json). These checks do not prove anatomy; the visual observations above are the separate art review.

## Scope of this result

This pass supplies proposed rules and static source paint for user inspection. It does not claim animated cutout readiness, measured encounter balance, a playable fixture, or real-renderer UI proof. Hidden joints, segmentation, clips and runtime draw order must be authored from the selected paint during implementation. Any pose corrections discovered there should preserve the reviewed identities.

No runtime code, production assets, data registries or icon registrations changed. Game tests and the icon identity registry test are not applicable to this staged artifact pass. The implementation pass will need the repository workflow, peer signoff, meaningful combat/input tests and fresh 1920×1080 / 100% renderer proof.
