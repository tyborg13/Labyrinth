# Motion, variants and production integration

## Own the new case's motion

`seed-protagonist` copies the current production paint, layouts and `motion.gd`, then records a hash baseline. It snapshots playback timing from the current renderer, including the attack's phase mapping. `fork` copies another case's runtime/source closure without copying its old previews. Change the case-owned files; do not edit the production sampler merely to experiment.

A sampler implements `static sample_pose(clip, phase, layout, facing) -> Dictionary`. Joint definitions are global source-pixel bind positions; returned bone positions are local to their parents. Rotation is radians, with optional scale/skew. Unspecified overrides use the bind pose. Define a new clip in both the sampler and `cutout.json` with its actual duration, frame count and loop behavior. The case selector/renderer includes each configured clip without editing a global action list.

For animation-only work, `validate --protect art` checks the baseline layouts and paint while allowing motion/clip timing to change. `--protect all` proves an untouched clone. Use `verify-render` after the final edit; stale proof is rejected. Keep unrelated accepted actions protected through pose comparison or an appropriate focused regression test.

Saved `<facing>.tscn` scenes contain the Skeleton2D, parts, weighted meshes and editable AnimationPlayer tracks. Open them in Godot to inspect keys. They are sampled authoring exports; changing the case sampler does not update an already exported scene. Rerender/save after edits. The native pipeline compares a non-neutral sample of each saved/reloaded action against the live case and requires pixel equality.

## Timing lessons

Separate authored pose phase from playback time. The protagonist's historical sampler clip metadata still describes earlier authoring speeds; actual game playback comes from `scripts/protagonist_cutout/renderer.gd`. The maintained case configuration is explicit about duration and phase mapping so a preview cannot silently present a different speed.

For the approved protagonist:

- Idle: a 0.84-second, two-source-pixel coordinated body bob with a slightly delayed sword hand. Counter-translate thighs against hip bob before leg IK so the legs stay rigid/planted. A chain of tiny periodic rotations read as shimmering cloth rather than breathing.
- Walk: 48px stride, 60% support fraction, 80px source travel per 0.30-second cycle. The longer stride reduced cadence while increasing board speed. These are a reference for this body, not a universal creature gait.
- Attack: the accepted preparation/cut/recovery poses remain unchanged. Single-target playback is 0.50 seconds, with the fast cut around 42% contact. The existing self-centered melee sweep retains its 0.24-second/38% contact behavior. Treat those gameplay event boundaries independently from animation phase.
- Home facing: every protagonist idle returns to unmirrored front after its action. New enemies may need a different facing policy; preserve the requested actor behavior rather than imposing this player preference on them.

For a new action, give preparation, contact and recovery distinct readable timing. Check clearance against the board HP bar as well as the canvas edge: a temporary salute passed bounds checks while its raised rear blade disappeared behind the HP bar. A sword tip traveling far is insufficient: verify that the blade rises/prepares in the requested direction, cuts through the intended space and avoids feet/body. Use separate front/rear poses when their painted geometry differs.

## Walking and support

During stance, a foot moves backward relative to the body at the same speed that the body moves forward on the floor. Tie root travel to the gait's projected source-pixel displacement and duration. Do not independently speed up the sprite animation and tile interpolation.

For the current humanoid sampler, `walk_cycle_info(layout, facing)` supplies `travel_per_cycle`; `walk_foot_state(phase, foot, layout, facing)` supplies target, contact and cycle phase. Cases mark a traveling clip with `"travel": "motion"` and declare the relevant `contact_feet`. The preview adds root travel and checks uninterrupted support intervals for drift. New locomotion can use these interfaces with its own anatomy or omit them for an in-place study until a support model is implemented; do not claim grounded traversal without that proof.

Account for the painted sole contour when a rigid boot changes angle. A pivot staying at constant height does not guarantee the sole stays on the floor. Let projected leg length change within an anatomically justified range while preserving paint width and a rigid boot basis. Inspect the full cycle for overreach, inverted knees, inward-curling toes and stretched cuffs.

The timed reel uses the case's declared playback duration and native rendered frames; its 60fps encoding repeats frames, verifies decoded frame counts/duration, and allows at most one output-frame rounding at clip boundaries. Never cap encoded output with the source frame count after changing frame rate; that truncates recovery when the source sampling rate is below 60fps. It is a character-study preview. Full gameplay speed and actual triggers still need the real RunScene capture after integration.

## Production integration

The generic authoring adapter reuses the production rig loader; it is not an automatically registered enemy renderer. Enemy integration remains a deliberate task using `$create-labyrinth-enemy` and `$create-labyrinth-ui` where relevant.

The approved production example is:

- `scripts/protagonist_cutout/rig.gd`: topology/paint loader.
- `scripts/protagonist_cutout/motion.gd`: phase-based poses and projected locomotion.
- `scripts/protagonist_cutout/renderer.gd`: persistent viewport/texture, facing/reflection and actual playback timing.
- `scripts/combat_board_view.gd`: logical body registration, viewport padding, stable art selection and HUD/shadow anchors.
- `scripts/run_scene.gd` and `scripts/attack_fx_library.gd`: action descriptors, duration/contact mapping and effects.
- `tests/suites/protagonist_cutout_suite.gd`, `tests/protagonist_cutout_gameplay_probe.gd`, `tests/protagonist_cutout_pack_test.gd`: focused rules, actual action/render proof and package loading.

Promote reviewed case art/layout/motion into production-owned paths and register the requested actor explicitly. Do not introduce a broad actor-system refactor unless the requested integration requires it. Update that enemy's portrait/turn-clock path independently; a valid body animation does not establish a valid portrait.

Keep a persistent viewport texture between actions/facings. Every state—idle, travel, attack, spell, block, hit, Blink, defeat, equipment view and resumed save—must continue to use the intended art. Don't restore the old whole-body sprite when one animation ends. Reduced motion should retain the same new art in a still pose with the intended facing policy.

The logical body is 255×255 inside a padded 512×512 action canvas. Body, HP, obstruction and tile geometry use the logical rectangle; padding belongs only to texture submission. Apply squash/echo/death scaling to the logical rectangle before adding transparent padding. Otherwise feet drift when the effect anchors to the padded edge. An extended sword should use the padding without shrinking/recentering the actor every frame.

Use a freshly baked neutral silhouette for cached HUD/shadow geometry. Avoid reading the live viewport back each frame or building a new silhouette cache for each pose. A static shadow is an explicit remaining choice, not a dynamic limb shadow.

Keep action-result and analytics boundaries unchanged when changing presentation only. Do not accidentally apply damage twice, delay resolver contact or convert targeted casting into melee. When outcomes/status timing change intentionally, update the analytics specification/instrumentation together as the repository requires.

Export the layout JSON explicitly and use the project's raw `keep` PNG import/AssetLoader path. A source-worktree render can hide missing exports or imported caches; use a production-only PCK with the unmodified non-editor runtime to verify packaging. Do not make production depend on `experiments/` or `tools/`, which export presets exclude.

## Proof and handoff

Use `render` and inspect all relevant phases, exposed anatomy and actual board-scale states. For a meaningful change to selected bones or gear, compare before/after at the same registration. Keep full-canvas bounds and fixed camera framing; never fit each frame independently to hide bad movement. Numeric contracts complement visual judgment.

For integration, rerun the affected focused/gameplay suites and fresh real-renderer 1920×1080/100% action sequences, including the supported input path and reduced-motion transitions. Select broader checks by risk. Retain logs, input/output hashes, true playback timing and residual limits. Complete the normal committed exact-HEAD peer review and verified pre-action fixture before handing the task back for inspection.
