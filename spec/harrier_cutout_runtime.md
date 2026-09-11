# Bone Harrier cutout runtime

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

Bone Harrier uses its own 18-joint front/rear skeleton and segmented paint. Rush is a forward spear thrust. Pelt and Darting Pelt raise the gripped spear and cast from its tip. Retreat Step uses a guarded travel pose. The accepted thin skeleton, skull crest, wraps, worn waistcloth, spear, and dedicated turn portrait remain its identity.

## Sources and authoring

The accepted front source is unchanged: `assets/placeholders/units/harrier_anime_trial.png`, SHA-256 `8b4b9e01f62a564b1205d4cb3bec1d762bb31d28197f9fc62f20be2fb153f224`. Source registration remains 255×255. All 8,999 original opaque front pixels match the native assembly after its uniform translation. The runtime takes a uniform translation to center the sole midpoint; it does not crop, stretch, or repaint the accepted front.

`experiments/cutouts/harrier/v01` is the initial creature case; its retained native proof is historical. The final case is `experiments/cutouts/harrier/v02/cutout.json`, with front/rear `*_final_skinned.json` layouts. Both views have 18 joints, 20 parts, and 10 skinned meshes. Head, hands, feet and spear retain rigid bases. The spear is a separate child of the right hand, so contact and casting never detach its grip. The arm and leg meshes share continuous source-space weight fields. Leg depth order changes with the projected ground contacts.

The selected generated rear shows the back of the skull, spine, cloth and heels. `v02/source/generation_requests.json` retains the tool, exact prompts, per-request reference roles, decisions and source digests. Rejected front-like rear and painted-checker outputs are retained as rejected sources; none supplies runtime pixels. The front hidden-body source and transparent rear pelvis component provide concealed anatomy. Explicit semantic ownership and component-fitting recipes preserve the visible source owners. `recipes/repair_hidden_registration.py` records source/target landmarks for concealed pelvis, spine and proximal femurs. Rear opacity is typically 252–253, so the rear coverage mask accepts alpha ≥250; the front mask uses only original alpha 255. Applying a front-only alpha rule to the rear erased its hidden material and was rejected during inspection.

`recipes/promote_runtime.py` copies the current layout closure into `assets/units/harrier_cutout/` and the motion into `scripts/harrier_cutout/`. Historical builders encode their version's inputs and must not be rerun over a finished case. To extend this rig, fork the current v02 case through `tools/cutout_workflow.py fork`, modify the new case, and use `segment`, `skin`, `validate`, `render`, and `verify-render`. The final native proof contains editable front/rear scenes with AnimationPlayer clips and pixel-identical save/reload comparisons.

## Motion and registration

All views use one sole midpoint at source coordinate `(127.5, 209.5)`, directly on the horizontal reflection pivot. `Motion.registration_offset()` computes a uniform root translation after solving the native anatomy. The public support-foot targets include that translation. Turning therefore keeps the ground anchor fixed without changing original joint/paint coordinates.

Idle is a coordinated 1.15-source-pixel upper-body bob over 1.45 seconds; every bone basis stays unchanged and both legs remain planted. There are no independent idle rotations or ripples. Walk and retreat use 54 source pixels of stride, 62% stance, 6 pixels of lift and 87.0968 source pixels of travel per 0.48-second cycle. Runtime phase comes from actual traveled board distance divided by source scale and cycle distance. A support foot countertranslates the actor's ground movement. The feet keep their painted projected orientation; reflection supplies the opposite diagonal.

Rush uses 39 frames at 60 Hz, or 0.65 seconds. Its pose curve puts the forward thrust at phase 0.55 on the existing melee feedback progress 0.42. The actor stays on its resolved tile, with a short linear thrust accent. Preparation, contact, hold and recovery use creature-specific hand/elbow targets, not Stone Warden's mace choreography.

Ranged attacks add 18 preparation frames at 60 Hz before the existing effect clock. For the default effect, that clock remains six 0.04-second frames, projectile release progress 0.18 and feedback/contact progress 0.66. Elemental styles retain their own existing anticipation and travel boundaries. `action.gd` maps each boundary into the casting pose. The projectile launch point uses the fixed release-pose spear tip, so recovery never drags an in-flight projectile origin. The spear remains gripped: this is a spear-directed cast of the existing bone projectile. The authoring cast preview spans the default 0.54 seconds and uses the matching phase curve. Rear preparation places the hand at `(195, 52)` and elbow at `(173, 82)` so the raised spear clears the fixed health-bar ornament; an earlier narrower preparation grazed that frame and was rejected during gameplay inspection.

## Runtime boundaries

`renderer.gd` retains two loaded rigs and one 512×512 viewport texture per actor. The board draws that padded viewport around its 255×255 logical body. The baked native front rest supplies stable HUD and shadow bounds. The 255-pixel rear rest is a logical reference crop; full rear paint, including the spear tip outside that crop, always renders on the padded canvas. The shared enemy facing helper selects the nearest of four isometric facings toward the player when an action ends; a Harrier waits until animated player movement finishes before turning. The protagonist's own front idle is unchanged.

Movement destination echoes use their actual actor's texture. Separate Harriers have independent renderers. Hidden actors pause idle work. Death freezes and dissolves the same current pose, then releases the renderer. Reduced motion displays the new still rig in the correct facing and preserves existing instant-resolution behavior. Pointer/controller target selection, cancel, hover, and input handoff remain on the existing routes.

No enemy definition, AI choice, targeting/range, path, damage, block, status, initiative or reward changes. The existing resolver supplies all outcomes. Harrier's weighted intent-cycle value remains 13.4 under `spec/card_balance_heuristic.md`; this presentation change does not rescore mechanics. Combat analytics still use the existing resolved action/event boundaries and append-only JSONL schema. The extra preparation changes presentation duration only.

Production owns its JSON, raw PNG and runtime scripts. JSON is explicitly included in all export presets. The isolated production-only PCK test boots an unmodified macOS debug export template with no experiment, toolkit or imported image cache present. Generic rig construction is reused from the production protagonist loader; Harrier's source layout and motion do not depend on protagonist anatomy.

## Verification and inspection

The task's proof is retained under `experiments/cutouts/harrier/`. Historical failures are labeled in their logs and are not acceptance evidence. Final structural validation, native proof, runtime comparisons, gameplay outcomes, focused/full Godot tests and the production-only export test are mapped in [the completion report](../experiments/cutouts/harrier/completion_report.md). Final native authority is `runtime_v3/assets`, `runtime_v3/gameplay`, and `v02/proof_01`; the latter passes 608 samples and 14 pixel-identical saved-scene comparisons.

The gameplay probe drives actual RunScene End Turn for all four intents in all four directions, checks exact engine outcomes and visible feedback boundaries, and exercises reduced motion, independent actors, lethal dissolve, target preview, controller cancel, pointer handoff, and real player movement. Captures use the native Metal renderer at 1920×1080 and 100% UI scale. Native asset comparisons cover complete front/rear/reflected cycles on the entire fixed 512-pixel canvas. Timed videos use source timestamps or the authored playback curves, never an invented uniform speed for gameplay samples.

After peer signoff, the inspection helper generates and independently verifies a pre-action combat fixture exposing the four intents with enough player HP to watch several turns. Its manifest belongs to the exact reviewed commit and is delivered with the handoff. Publication remains a separate user decision after inspection.
