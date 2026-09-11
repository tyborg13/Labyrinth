# Actor travel and fixed room framing

This contract supersedes the travel timing and legacy body offsets in the individual cutout history documents. Production art, attack poses, action results, initiative, rewards and analytics boundaries are unchanged.

## Travel pace

The protagonist remains the baseline. Every cutout resolves movement through its production renderer's `walk_cycle_distance`, `WALK_CYCLE_SECONDS` and `WALK_FRAME_SECONDS`, using the board's actual source-pixel scale. Distance controls pose phase and time together. This also covers Chainbound Gaoler, which previously fell through to the legacy sprite timer. Iskaldra keeps complete support cycles in its pose but uses proportional travel time instead of rounding the duration to whole cycles.

Longer authored strides let the enemies cover more floor without relying on extreme playback speed. The fixed regression band is 0.77–1.20 times protagonist ground speed; the small quick actors are above the baseline and the heavy actors below it. Cycle duration is at least 0.26 seconds. Travel frame quantization is within one 60 Hz frame of the proportional duration.

| Actor | Stride (source px) | Cycle (seconds) | Native two-tile travel (seconds) |
| --- | ---: | ---: | ---: |
| Player, unchanged | 48 | 0.30 | 1.05 |
| Tunnel Crawler | 88 | 0.27 | 0.95 |
| Dust Acolyte | 72 | 0.48 | 1.12 |
| Bone Harrier | 70 | 0.38 | 0.95–0.96 |
| Stone Warden, unchanged | 72 | 0.62 | 1.22 |
| Cinder Ooze | 72 | 0.37 | 1.25 |
| Cinder Droplet | 96 | 0.27 | 0.95–0.96 |
| Shale Bloomer | 84 | 0.47 | 1.30 |
| Chainbound Gaoler | unchanged | 0.64 | 1.28 |
| Grave Surgeon | 72 | 0.45 | 1.12–1.13 |
| Frostglass Lancer | 70 | 0.40 | 1.00 |
| Tharokh | 60 | 0.66 | 1.33 |
| Vyraketh | 64 | 0.72 | 1.29–1.30 |
| Vaeloryx | unchanged glide | 0.70 | 1.02–1.03 |
| Iskaldra | 48 | 0.60 | 1.28 |
| Noctyrax | 56 | 0.68 | 1.19–1.20 |
| Zekarion | 64 | 0.76 | 1.12–1.13 |
| Veilbound Acolyte | 72 | 0.48 | 1.12 |
| Lightning Wisp | unchanged glide | 0.39 | 0.92–0.93 |

Native times include actual RunScene scheduling and capture overhead. They are observations at 1920×1080/100%, not gameplay rule constants. Movement still consumes the resolver's existing path and distance.

## Tile registration and health bars

`ActorPresentation.PROFILES` stores source-space floor anchors separately for front and rear art. Landmarks come from the maintained production layouts: sole centroids for humanoids, authored support/contact points for crawling or quadrupedal actors, and the explicit hover ground projection for airborne actors. Reflection uses `255 - x`. Grave Surgeon's front/rear anchors are `(163.5, 207)` and `(166.5, 200)`: centering its whole 255px canvas or reusing its old −14px art offset cannot center these feet.

The logical body is registered to this floor point before adding the 512px viewport padding. Retained scene-tile draw commands refresh when the floor registration changes, including when only the player moves and the enemy turns in place. Its persistent texture alone cannot update the old draw rectangle. Non-cutout NPC art offsets retain their existing handling.

Health bars use a stable silhouette height, taking the larger front/rear rest height, and retain 10 screen pixels of clearance. Harrier and Warden additionally reserve their raised weapon height so those weapons never pass behind the HP frame. They do not follow idle bob or changing weapon silhouettes. Neutral cached shadows retain their own front-view registration; live animation never requires a per-frame silhouette readback.

## Up-front board fit and transitions

`BoardFraming` captures fixed room props/floor and reserves every supported actor at every legal origin, respecting large footprints. Reserving the complete roster also covers hidden actors and later summons. Source action bounds include both painted views and reflections, sampled across every configured action, plus an 8px source margin. Future art or motion changes must update these profiles with fresh native evidence.

The solver separates scalable body geometry from screen-pixel health bars (142×34 with 10px clearance), then finds the largest tile width inside the available combat rectangle. At 1920×1080 the available rectangle is `(36,126,1848,612)`, reserving the full boss/header HUD plus 8px clearance and the focused hand's vertical extent. The maximum header space is fixed even when boss HP or controller prompts are hidden. The room signature contains fixed grid/room geometry; moving, turning, spawning, hiding, dying, controller focus and reward overlays cannot recalculate its envelope. Explicit navigation zoom/pan and a viewport resize remain supported.

RunScene owns a fixed viewport-sized board canvas, independent of VBox hand/reward allocation. Noncombat presentation moves the floor center to the viewport center at the same scale, using a 0.42-second cubic ease. Initial presentation, viewport resizing and reduced motion snap directly to their intended positions. Returning to combat restores the original position. The existing defeat recap reframe owns its transition and cancels any competing centering tween.

## Reproduction and review

The owning regressions are `tests/suites/actor_presentation_suite.gd`, the affected cutout/layout suites and the full `tests/run_tests.gd` runner. `tests/actor_presentation_probe.gd` exercises live RunScene two-tile walks for the player and all 18 enemies, four facings, top-row placement, complete sampled action bounds and both normal/reduced mode transitions. The `LABYRINTH_PRESENTATION_ACTORS` filter permits bounded groups without weakening any actor checks. Header-framing verification also checks the actual boss and controller HUD rectangles, including top-row controller states. `tests/actor_weapon_clearance_probe.gd` verifies zero opaque weapon pixels behind the HP frames at the maximum-height Harrier/Warden poses. `tests/board_transition_probe.gd` adds actual card targeting and final-enemy defeat through victory/reward reveal, controller cancel and pointer handoff. All native proof uses `tools/visual_probe_runner.py` at 1920×1080, 100% UI scale.

The animation cases were forked from the current maintained cases into `/private/tmp/labyrinth-presentation-motion-v1`, preserving the accepted paint/layout baselines. Motion and clip timing were changed in those forks before production promotion. Focused final renders contain complete front/rear travel cycles, editable saved scenes, support/rigid checks, real-duration preview reels and input/output hashes. The original historical cases remain intact. Gait capture hashes are bound to commit `696631c0`; the later header-clearance correction only changes RunScene framing. Fresh all-roster gameplay captures verify that final framing, while all actor motion and renderer sources remain identical to the gait captures.

To reproduce a focused editable case, fork the actor's maintained case (`v02` for Harrier, otherwise `v01`), copy the current production `scripts/<actor>_cutout/motion.gd` into the fork's configured motion path, and update its travel clip duration from the table above. Keep the relevant walk/retreat clips and sample at least 36 phases per cycle. Run `cutout_workflow.py validate <case> --protect art`, `render <case> --output <proof> --task-id <task>`, then `verify-render <case> --output <proof>`. The native gameplay probe remains the authority for live movement scheduling and board registration.

Applicable UI rubric gates: comprehension/hierarchy (stable ring registration and clear HP), gameplay visibility (up-front complete actor envelope), input completeness (pointer targeting/controller cancel/handoff), state/consequence (actual victory and selectable rewards), motion/visual cohesion (authored support and measured pace), layout resilience (fixed scale through focus/modes), and fresh native-renderer evidence. Rules text and resolver/analytics behavior are unchanged; balance scoring does not apply.

Proof and review status is recorded in `spec/proofs/actor-presentation/verification.json`. Native visual proof is from macOS Metal; physical controller hardware, Windows execution and other resolutions/UI scales were not part of this pass.

## UI rubric record

The player should be able to identify the occupied tile, read HP, and follow movement or victory without the camera changing the spatial context. Existing rings, HP frames, card targets and reward cards provide the evidence; controls and detailed rules retain their existing hierarchy. Pointer, keyboard/controller targeting and cancellation remain supported. The proof matrix covers four views, live travel, top-row actors, focused targeting, victory/reward reveal and reduced motion at 1920×1080/100%.

| Gate | Result | Evidence |
| --- | --- | --- |
| Immediate comprehension | Pass | Actor support remains over the tile ring; HP stays directly associated with its actor. |
| Visual hierarchy | Pass | Combat hand/turn rail and reward choices retain their established foreground hierarchy. |
| Gameplay visibility | Pass | Initial room fit reserves complete actor actions and HP before movement or summons. |
| Compact, precise copy | Pass | Existing rules and labels are unchanged. |
| State and consequence | Pass | Targeting, lethal resolution, victory and selectable rewards are exercised by the live input probe. |
| Interaction completeness | Pass | Existing focus/activation/cancel contracts pass; native target/cancel/pointer-handoff states are captured. |
| Visual cohesion | Pass | Existing paint, rings, HP frames, typography, cards and controls are reused. |
| Accessibility | Pass | Static end states and reduced-motion transitions remain clear; type is unchanged. |
| Layout resilience | Pass | Fresh required-size capture includes all facings, top-row placement, focus and reward states. |
| Visual proof | Pass | Native Metal frames and timed travel/reward traces, linked by the verification index. |
