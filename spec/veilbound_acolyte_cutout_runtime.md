# Veilbound Acolyte cutout in gameplay

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

Veilbound Acolyte (`veilbound_acolyte`) is Noctyrax's existing shadow caster/minion. The board presentation must distinguish its aimed Veil Needle, Closing Shade's advance and short free-hand thrust, and Shroudstep's retreat. The player continues to move, choose cards and Pass through the existing pointer, keyboard and controller paths. Body art is the only roster change: preserve the original front painting, dedicated portrait, logical footprint, HUD, shadow registration, HP, initiative, AI, ranges, damage, statuses, surfaces, rewards, boss/minion lifecycle and analytics boundaries. No balance or icon identity changes are required.

The editable case is `experiments/cutouts/veilbound_acolyte/v01`. Production owns `assets/units/veilbound_acolyte_cutout` and `scripts/veilbound_acolyte_cutout`. The independent Dust Acolyte (`acolyte`) retains its existing body path and routing. No production path loads this case, `experiments/`, or `tools/`.

## Paint, anatomy and registration

`source/front_original.png` and `source/front_registered.png` are unchanged copies of `assets/placeholders/units/acolyte_anime_trial.png`. The current front rest preserves every fully opaque source pixel and the complete source alpha silhouette; GPU premultiplication changes RGB in partially transparent edge pixels. The original paint remains available unchanged.

Built-in ImageGen produced the matching rear three-quarter view. Its raw output, actual prompt/reference role, selection and digests are retained in `source/rear_generated.png`, `rear_request.json` and `generation_digests.json`. Whole-source registration uses a uniform nearest-neighbor scale into the 255px body canvas and preserves selected alpha. The rear ground registration aligns the lower robe with the accepted front: the alpha-weighted native lower-hem center is 133.397px in front and 133.380px in rear. The 18px rear translation follows that grounded body comparison, rather than the orb-inclusive silhouette box. The inferred concealed support landmarks retain distinct near/far heights under the 2:1 projection.

The generated hidden-material output is RGB with a painted checkerboard and retained sleeves. It is rejected as a whole-body replacement. Only recorded interior cloth crops supply concealed torso and sleeve caps; no generated background, face or replacement visible front silhouette enters production. `source/hidden_request.json` records that disposition. `recipes/{front,rear}_hidden.json` records crop-to-source registration and alpha masks. Front hidden patches lie only behind fully opaque accepted paint. Rear hidden material lies beneath the new rear's opaque interior. The free hand's original chest/waist footprint receives torso-owned cloth, so its forward motion cannot uncover a transparent hole. A separately recorded torso outline continues the concealed flank behind the full raised-sleeve stroke; its plain interior crop excludes the generated belt and trim.

Both views have ten joints: logical root, torso, hood, two sleeves/arms, two hand controls, orb, and two concealed supports. Hands and orb remain separate rigid owners; collar and robe trim stay on their owning cloth. The far free hand remains concealed by the body in rear view. Its occupied sleeve and the directed shadow thrust carry that rear-view melee cue; the rig does not invent a visible boot or hand perspective.

The maintained `segment` command preserves exact source ownership and alpha. The maintained `skin` command creates sleeve and robe grids. The lower robe panels use one recorded continuous source-space weight field, with a broad blend across the two concealed supports; this prevents a separating vertical seam or folded cloth triangles at passing. Layouts, original outputs, registration and ownership recipes are retained. `recipes/build_case.py` belongs only to this new case and does not replay a historical character builder.

## Motion and runtime

Idle is a 1.8-second, 1.2px coordinated upper-body bob. All bone bases remain unchanged, with no local idle rotations, scaling or skew. The root and concealed supports stay fixed while the lower robe settles into them. Locomotion uses a 48px shrouded stride, 60% support fraction and 80px source travel per 0.68-second cycle. Phase follows actual resolved board distance, including retreat and multi-segment paths. The supports describe feet concealed by the floor-length robe, not newly painted boots.

Veil Needle uses a 0.9-second aimed open-palm gesture. The retained ember orb acts as the casting focus; a narrow shadow projectile releases at the existing 18% phase and applies the existing result at 66%. Closing Shade retains its movement result, then plays a 0.6-second free-hand thrust with contact at the existing 42% boundary. A small three-finger shadow cue replaces the inappropriate large gold sword slash for this actor alone. It starts with the forward stroke and leaves the preparation and body visible. Resolver results are applied only by the existing RunScene step path. Non-attack state remains restrained idle.

Every living acolyte owns one persistent 512px viewport and two loaded rigs. Reflections supply the other two supported directions. `scripts/enemy_cutout_facing.gd` selects the nearest player-facing idle from displayed tiles; action descriptors keep travel/attack direction until completion. Player movement turns observers only after the completed tile becomes displayed state. The protagonist retains camera-facing idle.

The 255px body rectangle and existing `art_offset_y=-16` remain the geometry source. Transparent action padding is added after logical death/echo scaling. Destination echoes reuse the actor's texture, hidden actors pause idle, death freezes and dissolves the same texture, and removal releases only that actor's renderer. Fresh native rest bakes supply cached HUD and neutral shadow geometry, with no per-frame GPU readback. Reduced motion retains the new directional still art. The dedicated `assets/art/portraits/veilbound_acolyte.png` remains the turn-clock portrait.

## Verification and inspection

Current evidence belongs to `v01/proof` and `runtime_v1`; earlier scratch captures are not current proof. The task-specific `recipes/capture_case.py` uses the maintained validator, native preview, packer and verifier with a measured 180-second capture allowance. The first default 100-second attempt reached 299 of 352 authored poses before timing out. Startup remains at the normal watchdog; the shared GUI lease serializes capture with the other enemy tasks.

Final native case proof passes structural validation and `verify-render`, binding 1,002 inputs and 879 outputs. The eight front/rear clips contain 352 board frames, with all 240 distinct cycle poses visually inspected. All eight saved-scene reload comparisons are pixel-identical. Fixed 512px bounds pass, rigid-basis error is zero, and maximum concealed-support drift is 0.000035px. The native case reel runs for 12.933 seconds against 12.92 seconds of authored duration and fully decodes. `runtime_v1/case_visual_review.json` records the inspected files and measurements.

The production asset probe compares 242 native case/runtime frames pixel-for-pixel, including both shipped rest bakes. Actual RunScene proof contains 24 clips, 2,067 captured samples and 78 inspected native screenshots at 1920x1080/100%. Four cycle contact sheets additionally show 128 samples across every reflected idle, travel, cast and thrust direction. All three intents pass exact damage, initiative and movement outcomes; live release sockets, player repositioning, independent minions, controller cancel/pointer handoff, reduced motion and death pass. Maximum gameplay support drift is 0.000137px. The 79.033-second gameplay reel uses measured capture timing, repeats captured frames where necessary, synthesizes no poses, and rounds each clip by less than one 60Hz frame. Its source mappings and full-decode result are retained in `runtime_v1/gameplay/video_timeline.json`.

The focused suite passes checks for every idle basis and support transform, no folded/collapsed animated cloth triangles, texture lifetime, art routing and zero ember rewards. The final full suite passes, including the existing Noctyrax/Eclipse/minion contracts. Production-only PCK proof loads both rigs and the shadow feedback script with the unmodified macOS 4.6.1 export runtime (`editor=false`), without loose experiment/tool or import-cache dependencies. `runtime_v1/export_proof.json` records the runtime and pack digests and reproducible commands. Unchanged contract hashes confirm the accepted body source, dedicated portrait, enemy definitions, resolver, room generator and shared facing policy match the task base.

The affected UI rubric gates are immediate comprehension, hierarchy, gameplay visibility, state/consequence, interaction completeness, visual cohesion, reduced motion, layout resilience and native visual proof at 1920x1080/100%. Exact rules text, controls and icon identities are unchanged.

Reproduce from this task worktree:

```sh
python3 tools/godot_task_runner.py --task-id animate-veilbound-acolyte-cutout --stream -- godot --headless --path . --script tests/veilbound_acolyte_cutout_test.gd
python3 tools/godot_task_runner.py --task-id animate-veilbound-acolyte-cutout --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/veilbound_acolyte_cutout_asset_probe.gd --task-id animate-veilbound-acolyte-cutout --no-headless --rendering-method mobile --rendering-driver metal --expect-size 512x512 --expect-size 255x255 --timeout 120 --gui-lease-timeout 1800
python3 tools/visual_probe_runner.py tests/veilbound_acolyte_cutout_gameplay_probe.gd --task-id animate-veilbound-acolyte-cutout --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 --timeout 240 --gui-lease-timeout 1800
python3 experiments/cutouts/veilbound_acolyte/v01/recipes/capture_case.py --output /private/tmp/veilbound-acolyte-fresh-case-proof
python3 tools/cutout_workflow.py verify-render experiments/cutouts/veilbound_acolyte/v01 --output experiments/cutouts/veilbound_acolyte/v01/proof
```

Inspection uses a fresh pre-action combat fixture with all three existing intents. Choose Continue, inspect the idle, move around the acolytes to see the four facings, then Pass to see the scheduled casts, advance/strike and retreat. Publication and cleanup require user inspection and explicit approval of the exact reviewed commit.

Remaining limits: neutral shadows use a static silhouette; rear free-hand paint and both feet remain concealed by the accepted robe anatomy. Native proof targets macOS at 1920x1080/100%, not Windows execution, physical controller hardware or alternate scales. Windows-compatible typed array assignments are retained. The full suite may retain the existing ambiguous-save migration and ObjectDB shutdown warnings; test pass does not claim a warning-free shutdown.
