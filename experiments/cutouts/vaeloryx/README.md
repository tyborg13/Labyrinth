# Vaeloryx cutout

The editable source of the production candidate is [`v01/cutout.json`](v01/cutout.json).
It uses the accepted front image, a generated registered rear image, and fifteen
bones for dragon wings, forelimbs/claws, tucked hindlimb, neck/head and tail.
The maintained entry point is `$create-labyrinth-cutout`; do not rebuild this case
by replaying another enemy's historical experiment generators.

| Path | Role |
| --- | --- |
| `v01/source` | Original art, all generated sources, exact prompts/reference roles/dispositions and registration |
| `v01/recipes` | Explicit anatomy, ownership repairs, shared skin fields and concealed-joint paint recipes |
| `v01/layouts` | Editable part/bone registration and the selected front/rear meshes |
| `v01/motion.gd` | Bob-only hover, travel, dive, outward gale, inward pull and guard sampler |
| `production_promotion.json` | Case-to-production paint mapping and digests |
| `native_v01` | Current maintained native render: 480 authored samples, 12 pixel-identical saved-scene reloads, editable scenes and timed study reel |
| `author_v01`, `author_v02` | Preliminary anatomy iterations; **not final runtime proof** |
| `runtime_v01/full_suite.log` | Passing full Godot regression suite |
| `runtime_v01/focused_suite.log` | Passing cutout/runtime contracts |
| `runtime_v01/gameplay_logic_v06` | Latest passing 27-case RunScene logic audit, including four-direction Gale displacement and a blocked corner; headless draw signals are explicitly advanced, so this is **not native visual proof** |
| `runtime_v01/gameplay_logic`, `gameplay_logic_v03`, `gameplay_logic_v04` | Earlier logic audits, superseded by `gameplay_logic_v06` |
| `runtime_v01/gameplay_layout_iteration` | First native capture passed runtime assertions; visual review rejected its observer placement and identified the adjacent-pull slash fallback |
| `runtime_v01/package_proof.json` | Production-only PCK and unmodified export-template identity |
| `runtime_v01/gameplay` | Final 27-case native RunScene capture: 118 PNGs, timed complete action videos, outcomes and analytics |
| `runtime_v01/assets`, `runtime_v01/asset_review` | 772 native case/production comparisons, exact shipped-rest equality and 24 inspected full-cycle sheets |
| `runtime_v01/visual_review.md` | Actual visual inspection findings and affected UI rubric ratings |
| `runtime_v01/inspection_draft.json` | Independently reloaded draft fixture; final inspection is regenerated after reviewer signoff |

`source_preservation.json` establishes byte-identical original front art and exact
RGBA preservation through registration and the final ownership reconstruction.
The hidden scales are only used under opaque source paint at rest. The large
front wing and rear near wing obscure most of the head in the accepted sources;
the anatomy recipe records that limit instead of treating wing paint as a face.

The selected front layout includes the thorax/back-fin ownership correction and
a small concealed back patch. `author_v02` predates that last hidden patch; use
fresh native proof for final judgment. Rejected rear generation attempts remain
for provenance and do not supply runtime pixels.

The live wiring and verification contract are described in
[`spec/vaeloryx_cutout_runtime.md`](../../../spec/vaeloryx_cutout_runtime.md).
Native captures and editable-scene reload proof are complete. Exact-commit peer
signoff and the final verified inspection fixture accompany the task handoff.
