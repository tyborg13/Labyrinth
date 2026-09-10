# Lightning Wisp cutout in gameplay

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

The Wisp's combat-board body now communicates a floating electrical threat: idle watches the player, Spark Dart gathers then darts along the target lane, and Static Lash/Capacitor Arc gather their outer lightning before releasing the existing projectile. The player still decides where to move, which card to use, and when to Pass through the established pointer, keyboard and controller paths. The existing 0.68 art scale, 255px logical body, HUD, turn clock, target tiles, shadow anchor and rewards remain stable. Native 1920×1080/100% proof covers the full cycles and actual RunScene triggers, outcomes, input handoff, reduced motion, facing and death. No enemy data, AI, damage, initiative, ranges, statuses, surfaces, spawn pools or analytics boundaries change.

## Art and editable anatomy

The current case is `experiments/cutouts/lightning_wisp/v01`, created with the maintained `tools/cutout_workflow.py init`. The untouched accepted `assets/placeholders/units/lightning_wisp.png` remains the front source. It is a floating dark energy core with a forward golden aperture and an outer lightning envelope; it has no humanoid limbs or equipment. The six-bone graph has a stable root, one rigid core and four electrical branches. Four weighted meshes blend each branch into its fixed core attachment. The rigid core owns its aperture and internal filaments. No concealed anatomy is exposed by the requested motion, so no invented limb or hidden-fill paint is needed.

The built-in image generator supplied a matching rear view. `source/generation.json` retains the actual prompts, reference roles, source digests and selected/rejected dispositions. Both untouched generator results are retained. The failed alpha-repair result supplies no runtime pixels. The selected rear drawing was uniformly registered with nearest sampling, then the maintained `segment` command assigned its painted checkerboard to an excluded background owner. `source/rear_background_ownership.json` retains every selected pixel; `source/register_rear.py` and `source/registration.json` retain the full recipe. No foreground RGB was repainted. Front paint is copied exactly through ownership segmentation. Reflections use the two real views.

Native rest bakes supply static geometry caches. The accepted front source contains extensive partial alpha. A Wisp-owned second persistent viewport converts the rig canvas from premultiplied to straight alpha entirely on the GPU, avoiding a second alpha multiplication when the board draws it. This changes texture representation, not source paint. Native comparison against the accepted front over an opaque background measures a maximum one-level difference in 8-bit color from rounding. It requires no per-frame image readback and does not change the Warden or protagonist renderers.

Production owns `assets/units/lightning_wisp_cutout` and `scripts/lightning_wisp_cutout`. The production skeleton loader is reused. Export presets explicitly include the new layout JSON, PNGs use raw keep imports, and the runtime never loads case/tool files. The existing dedicated `assets/art/portraits/lightning_wisp.png` remains registered in the turn clock.

## Motion and action boundaries

Idle uses a 1.6-second coherent 2.4-source-pixel hover. Every painted bone keeps the same basis, scale and local orientation; only the complete core/envelope translates. Flight uses the existing `walk` routing name with 160:80 source travel per 0.48-second cycle, driven by actual projected route distance. It has no footsteps or pretend ground contacts.

Spark Dart takes 0.6 seconds: a short backward gathering pose precedes an 18:9-source-pixel dart at the existing 42% melee contact, then recovery. The legacy whole-sprite lunge is suppressed for this actor so motion is applied once. The existing melee result/effect path remains intact.

Both ranged intents use the same electrical action family. A 0.22-second preparation contracts the outer branches toward the rigid core. The original 0.345-second lightning effect follows. The authored release coincides with its 4/30 anticipation boundary, and damage remains at the original 8/30 effect boundary. Static Lash still places electrified ground, and Capacitor Arc still retreats and applies its conducted Shock bonus. Preparation never invokes the combat resolver. Reduced motion skips it and displays the same new art in a still pose.

`enemy_cutout_facing.gd` selects the closest of four directions toward the player at idle. Action descriptors retain their own resolved direction. Observers wait for completed player movement before turning; the protagonist keeps camera-facing idle. Each Wisp has independent rigs, clocks and textures. Preview echoes share their actor's texture. Hidden actors stop idle work; death freezes the last pose and the existing dissolve removes only that actor. Cached shadows intentionally use the neutral silhouette.

## Verification and inspection

Proof results and the inspected gameplay preview are retained under `experiments/cutouts/lightning_wisp/runtime_v1`; editable scenes and native study proof are under `v01/proof`. The actual RunScene capture contains 26 clips, 2,155 timed samples and 90 native screenshots. Its 81.77-second reel preserves recorded playback timing. It covers all three intents in four directions, long-range advance and retreat, conducted damage with visible Shock feedback and the exact next-activation restriction, actual Call Wisps summons, reduced motion, death and input handoff. `experiments/cutouts/lightning_wisp/INSPECTION.md` contains the self-healing launch and reproduction commands; the runtime proof record lists the verification evidence.

Affected UI rubric gates: immediate comprehension, hierarchy, gameplay visibility, state/consequence, interaction completeness, visual cohesion, accessibility, layout resilience and native visual proof. The body remains below its health/intent UI, electrical releases retain their actual target, and cards/Pass remain visible. Pointer targeting, controller Cancel and pointer handoff are exercised in the live scene. No icons or rules text change.

Residual limits: shadows use a static neutral silhouette; the rear is newly generated paint; the native authoring adapter shows its intermediate premultiplied canvas, while gameplay applies the Wisp-specific straight-alpha conversion. Alternate resolutions/scales, physical controller hardware and Windows execution are outside this proof. Windows-compatible typed-array construction is retained. The production-only package test proves the cutout resource closure with an unmodified macOS export runtime, not a full platform release.

Publication and cleanup require the user's inspection and explicit approval of the exact reviewed commit.
