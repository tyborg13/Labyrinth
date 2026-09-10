# Dust Acolyte cutout in gameplay

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

The Dust Acolyte's open palm and ember must show a readable gather, release and recovery on the live combat board. Preserve the accepted skeletal hood, narrow brown robe, trim, resting hand and grounded hem, while keeping target tiles, HP, intent, turn-clock portrait and existing input paths clear. This is presentation-only: enemy definitions, encounter weights, AI, footprints, rewards, damage, block, healing and append-only analytics remain unchanged. Only enemy id `acolyte` uses this rig; `veilbound_acolyte` keeps its existing art and behavior.

## Editable art and ownership

The fresh maintained case is `experiments/cutouts/acolyte/v01`, initialized with `cutout_workflow.py init`. Its `author.py`, explicit ownership maps and skin recipes reproduce the selected segmentation and layouts. The accepted 255×255 front source remains byte-identical to `assets/placeholders/units/acolyte_anime_trial.png`. Native neutral rendering preserves every fully opaque original painted pixel; partially transparent edge RGB undergoes normal GPU premultiplication and rounding. It is not a claim of byte equality between the original source and a GPU screenshot.

The rear and concealed cloth came from imagegen using that front as the identity reference. `source/generation_requests.json` retains each actual prompt, reference role, selection reason, registration and SHA-256 digest, with all raw generation outputs. The first rear returned an RGB checkerboard, and a background-removal edit still returned RGB. The first output supplies the design reference for that edit; the edited output supplies the selected rear paint. A documented four-connected border flood excludes only achromatic light background from `rear_alpha_attempt.png` (minimum RGB 65, maximum channel spread 26), preserving the character pixels. The full figure crop is uniformly registered to 215px height at source offset (82,20); no part is independently fitted. The selected hidden sleeve output is true RGBA. Its small interior crops sit beneath opaque original paint at the sleeve socket and robe seam.

Each view owns an eight-joint caster graph: root, torso, hood, casting hand, orb, resting hand and two concealed hem contacts. Front has eleven semantic paint parts and rear ten; both have three skinned meshes. The casting sleeve connects torso to the rigid palm. Each robe panel uses a vertical torso-to-own-hem gradient, so its rows preserve width throughout the stride. Separate overlapping panels replace a rejected continuous horizontal weight blend that folded the robe during a crossing step. The hands, hood and trim have explicit owners; there is no Warden weapon or imported Warden skeleton. The reference conceals the feet, so literal bottom hem contacts carry the support proof without inventing boots.

## Motion and runtime

Production owns the selected layouts/paint in `assets/units/acolyte_cutout` and its caster sampler/renderer in `scripts/acolyte_cutout`. The rig extends the established production rig loader. Production never reads experiments or authoring tools. Export presets explicitly include the layout JSON; paint uses raw keep imports.

One persistent 512×512 viewport per actor contains two loaded facing rigs around the existing 255px logical source at (128,128). The padded canvas follows pose changes, while the baked native rest silhouette supplies stable HUD and shadow geometry. Destination echoes share their actor's texture; multiple Acolytes retain independent state. Hidden actors pause idle work, death freezes and dissolves the same texture, and the viewport is freed after removal. No frame-by-frame GPU readback is used for board bounds or shadows. The separate Dust Acolyte turn-clock portrait remains unchanged.

Idle is a restrained 1.8-second, 1.2-source-pixel upper-body translation. Every upper-body rigid basis remains unchanged and both hem contacts stay fixed. Walking uses a 48px stride with 60% stance, 80px source travel per 0.72-second cycle and a 3px concealed-step lift along the existing 2:1 board projection. Pose phase follows actual resolved path distance, including multi-segment movement. The two robe panels retain their width during the grounded stepping motion.

Dust Bolt and Siphon use a 1.2-second cast: the palm draws toward the body, extends at release, then settles. Siphon adds a draw-back after contact before the existing heal presentation. The authored release (18%) and contact (66%) are mapped to the existing default or elemental projectile/result boundaries; only presentation duration and pose change. The projectile launches from the orb socket frozen at release so the recovering hand cannot drag its origin. Reduced motion uses the visible still orb socket and still art, while retaining directional facing. Ward Chant's existing four self-block and Siphon's four damage/two self-heal remain resolver-owned.

The shared `enemy_cutout_facing.gd` policy chooses the closest supported direction toward the player's displayed tile for idle. Walking faces its current resolved segment; casting faces its resolved target. Completed actions and completed player movement restore player-facing idle. Pending destinations do not turn observers early. The protagonist retains camera-facing idle.

Umbra-clipped effects preserve the visible segment's supplied origin, including impact and reduced motion. Those callers already removed the hidden part of the projectile path; replacing their origin with the physical orb would draw the default impact trail back toward a concealed caster. The orb socket is used only when the effect is neither clipped nor a preview. Peer review found this visibility regression, and the focused suite now checks both hidden-impact motion settings through the shared launch-point route. Native proof also exercises the actual RunScene Umbra descriptor with a concealed Dust Acolyte at impact.

## Verification

The affected UI rubric gates are immediate comprehension, hierarchy, gameplay visibility, state/consequence, input completeness, visual cohesion, reduced motion, layout resilience and fresh native proof. Inspect the 1920×1080/100% captures for legible target cells, health/intent panels, separate turn-clock portraits and stable body registration. Input proof covers pointer selection, controller target/cancel and pointer handoff through the existing RunScene paths.

Current maintained case proof is `experiments/cutouts/acolyte/v01/proof_v02`. It retains 400 native idle/walk/Dust Bolt/Siphon frames in both views, fixed-canvas bounds, support measurements and eight pixel-identical saved-scene reload comparisons, plus editable Skeleton2D/mesh/AnimationPlayer scenes. Maximum planted support drift is 0.0000342 source pixels, with zero rigid-basis error. Current `verify-render` passes with 995 input hashes and 1,007 output hashes, binding the case and full renderer dependency closure to the retained outputs.

Current production/gameplay proof is `experiments/cutouts/acolyte/runtime_v02`. The asset probe compares 564 front/rear/reflected rest/idle/walk/Dust Bolt/Siphon poses pixel-for-pixel against the maintained case and verifies both production rest bakes. The gameplay probe uses real RunScene Pass, targeting, movement and death flow. Every four-sided attack fixture begins on valid floor at range six, requires actual walking before the cast, checks the quiet second actor, then verifies the result. Dust Bolt removes five HP; Siphon removes four HP and heals its caster from eight to ten; Ward Chant grants four block. Reduced motion, death dissolve, controller cancel and completed player repositioning are included.

The accepted gameplay run retains **19 clips, 1,939 samples and 59 native PNG keyframes**. All four native and reflected walking directions are present. Its largest frame interval is 0.0464 seconds, and every clip finishes with input unlocked. Within-stride support comparisons range from 178 to 353 per attack traversal, with maximum world-space drift **0.000173 pixels**. The fresh Siphon northeast sequence completes in 6.611 seconds and passes its heal, damage, facing and support checks.

`gameplay/acolyte_gameplay_full_speed.mp4` retains the complete real RunScene capture: 73.5376 source seconds encoded as 73.5333 seconds. `gameplay/acolyte_casting_preview.mp4` is a compact front-facing idle/walk/Dust Bolt/Siphon preview. Encoding uses actual wall-clock sample intervals, repeats frames at 60fps without synthesizing poses, checks each clip's duration within one frame and fully decodes the reel. Native keyframes, sample state/timestamps, per-source-frame digests, 1,475 current runtime input hashes and 661 retained-output hashes remain beside the videos. The `inspection` folder retains inspected contact sheets and the native UI/art audit.

One discarded capture contained a one-second scheduling gap during Siphon. It exposed two probe defects: comparing different planted strides after skipped frames, and treating a brief unlocked interval between actions as final completion. The probe now identifies each unwrapped stride, requires more than ten within-stride support comparisons for every traversal/cast clip, and requires the complete finish hold to stay unlocked. The original drift tolerance, twelve-second clip guard and native execution watchdog remain unchanged. `rejected_capture.json` retains the rejected result and correction rationale; its frames are not used in the accepted preview.

The focused suite, full game suite and production-only PCK smoke pass. The PCK executes on the unmodified macOS Godot 4.6.1 export template with `editor=false`, without experiment/tool assets, loose source art or an imported cache. This verifies cutout packaging, not a complete platform release or Windows execution. Full-suite logs retain the established ambiguous-save migration and ObjectDB shutdown warnings; headless macOS logs also contain the environment's system-CA-certificate diagnostic.

The maintained render helper now accepts optional `--gui-lease-timeout` forwarding, matching the concurrently reviewed Tharokh helper change. Its omitted default and all native startup/execution watchdogs remain unchanged. This allows final proof to wait for the shared renderer without bypassing the lease. All sixteen existing workflow tests and a focused default/explicit forwarding comparison pass; the latter confirms the native command differs only by the requested lease argument.

Reproduce from the task worktree:

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/acolyte/v01
python3 tools/cutout_workflow.py verify-render experiments/cutouts/acolyte/v01 --output experiments/cutouts/acolyte/v01/proof_v02
python3 tools/godot_task_runner.py --task-id dust-acolyte-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/acolyte_cutout_test.gd
python3 tools/godot_task_runner.py --task-id dust-acolyte-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/acolyte_cutout_gameplay_probe.gd --task-id dust-acolyte-editable-cutout-and-gameplay-animation --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 --timeout 210 --gui-lease-timeout 600
python3 tools/visual_probe_runner.py tests/acolyte_cutout_asset_probe.gd --task-id dust-acolyte-editable-cutout-and-gameplay-animation --no-headless --rendering-method mobile --rendering-driver metal --expect-size 512x512 --expect-size 255x255 --timeout 210 --gui-lease-timeout 600
```

## Playable inspection

After exact-HEAD peer signoff, the self-healing fixture regenerates and independently reloads a pre-action combat save before opening the game. Choose Continue, inspect the coordinated idle, then use Pass through the opening turns to see Dust Bolt, Ward Chant and Siphon in the existing initiative order. The first caster starts wounded so Siphon's healing is visible. Player movement reveals all four facings; Brace and Patch Up support additional turns. The branch is `codex/animate-acolyte-cutout`, based on local master `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`.

```sh
cd /Users/borgerding/.codex/worktrees/78fb/Labyrinth && python3 tools/inspection_fixture.py --task-id dust-acolyte-editable-cutout-and-gameplay-animation --run-id acolyte-runtime-v02-inspection --manifest /private/tmp/acolyte-runtime-v02-inspection.json --launch --scenario combat --summary "Dust Acolyte: inspect idle, then Pass for Siphon, Dust Bolt and Ward Chant" --player-position 3:6 --player-hp 40 --player-max-hp 40 --enemy-types acolyte,acolyte,acolyte --enemy-positions 3:1,6:4,1:3 --enemy-intents siphon,dust_bolt,ward_chant --enemy-hp 8 --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

Remaining limits: shadows intentionally use the static rest silhouette; the reference's feet stay concealed under the robe. Alternate resolutions/UI scales, physical controller hardware and Windows execution were not exercised. Combat mechanics, balance assumptions, analytics and icon identities are unchanged. Publication awaits user inspection and explicit approval of the reviewed commit.
