# Contextual cutout animation pass

## Scope and presentation

The combat board now gives the player and all 31 enemy identities authored hit and terminal collapse poses. The protagonist also braces an absorbed blow. These communicate the resolved result beside the actor; damage numbers, HP, targeting, effects and controls retain their existing roles. Reduced motion keeps the neutral hit/guard view and shows a fixed collapsed death endpoint. No new gameplay rule, result boundary, input action, or analytics event is introduced.

The cutout skill owns anatomy and source registration. Each sampler uses the current production art and its own joint graph. Humanoids give at the knees/waist, supported dragons lower their bodies and heads, and the remaining creatures settle according to their anatomy. Feet/claws, weapons and hard terminal pieces remain rigid. Existing idle direction stays a coordinated bob with planted supports; the NPC audit removes independent idle undulation from the Scavenger and Graftwright while retaining the deliberate graft action.

Zekarion's original jaw and hidden jaw cap now share a registered head-to-jaw skin field. The proximal cheek stays attached as the distal jaw opens for lightning breath; no new overlay or stretched paint hides the tear. See [the Zekarion source contract](zekarion_cutout_runtime.md).

## Runtime ownership

- `scripts/cutout_context.gd` maps explicitly addressed resolved popup entries to existing family motion dictionaries. Hit playback lasts 0.36 seconds; the player's guard response lasts 0.30 seconds. The popup's existing elapsed time carries the reaction across attack-to-feedback and overlapping-popup handoffs, including status, trap and multi-hit damage.
- Actor identities and `hit`/`block` semantics are tagged at outcome-feedback construction. Terrain damage, healing and generic text do not infer reactions from text or tile coincidence. HP damage takes priority over partial absorption. A lingering popup does not cancel a new deliberate action or detach its projectile socket.
- An explicitly marked death descriptor overrides other poses. Living reinforcements reuse the dissolve presentation in reverse and retain their previous arrival pose. Collapse reaches its authored endpoint at 62% of the existing dissolve timeline (0.64232 seconds of the 1.036-second enemy effect), then holds while the original shadow dissolve finishes. No extra wait is added.
- `scripts/cutout_reaction_playback.gd` retains the actor's facing and persistent viewport texture. A short blend from actual preceding bone transforms avoids snapping from a swing/recoil into the neutral beginning of a reaction. Hidden actors remain paused; death rigs accept explicit terminal phases while their ordinary idle processing stays disabled.
- Both player and enemy attacks retain defeated actors on the board from lethal contact through the remaining attack feedback. A zero-HP display snapshot includes a frame-zero death descriptor until the terminal timeline takes ownership; the actor must never disappear and then return for the collapse. Trap-delayed feedback keeps its existing detonation boundary.
- The player uses the authored collapse inside the current defeat treatment. The board no longer adds a second whole-body squash to a cutout death. Logical body registration, HUD anchors and cached rest shadows stay fixed.

## Authoring and verification

The task uses isolated current-production cases and records before/after source hashes. Raw real-renderer cycle audits cover both painted views, retained clips, new reactions, extreme bends and exposed joints. Final native cutout proofs include editable scenes, save/reload comparison, fixed-canvas bounds and timed reels. Production does not depend on these authoring outputs.

Focused `tests/contextual_cutout_test.gd` checks all 32 combat bodies through normal and reduced-motion hit/death transitions, persistent textures, frozen reaction facing, outcome identity, recovery, death precedence and lack of resolver mutation. It also runs from the full Godot suite. The production-only PCK smoke includes all 32 bodies, both facings and both reaction clips.

`tests/player_defeat_continuity_test.gd` observes every actual enemy-playback board submission through an instrumented RunScene subclass. Real resolver steps cover Zekarion melee, breath and targeted lightning, plus Storm Cantor trap conduction, in normal and reduced motion. It requires continuous player inclusion until death completes, a frame-zero pose through attack contact/recovery, the resolved lethal tile, unchanged inputs, and exactly the resolved final player state.

`tests/contextual_cutout_gameplay_probe.gd` uses actual card and End Turn inputs at 1920×1080 / 100%. It observes player/enemy hits, guard, player/enemy deaths, retained shadow dissolve, reduced motion, controller cancel and pointer handoff. End Turn outcomes are compared with the combat resolver and the target's card damage is checked for exactly one application. Normal and reduced-motion lethal player sequences compare resolver-derived terminal outcome, HP, run statistics and room layout, and assert actual board draw-list continuity on every observed frame through the terminal death pose. A renderer clip alone is insufficient evidence because a persistent renderer may continue animating while its actor is absent from the board. Ordinary and reduced-motion reinforcement captures exercise the actual spawn presentation path and verify that living arrivals retain idle/rest while their original dissolve plays.

Generated evidence and fresh authoring studies live under the task's `output/contextual-animation-polish/` directory and are excluded from Git. The verification record and reproduction commands are retained with the task handoff. The task remains local until exact-HEAD peer review, user inspection and publication approval.

## UI acceptance record

The player's decision remains the current combat action. Reactions communicate its resolved consequence on the actor, while persistent HP, damage numbers, initiative and the existing targeting affordances retain their hierarchy. Primary actions remain card play, movement and End Turn. No new control or copy is introduced. Pointer, keyboard and controller routes retain their existing actions; the real-scene probe exercises controller cancellation and return to pointer input.

All affected rubric rows pass at the required 1920×1080 / 100% configuration:

| Gate | Evidence and result |
| --- | --- |
| Immediate comprehension | Hit recoil, sword guard and terminal collapse accompany existing numeric/status feedback. |
| Visual hierarchy | Character responses stay on the board; existing cards, targets and End Turn remain primary. |
| Gameplay visibility | Full gameplay sequences show no added panels, displaced HUD anchors or obscured controls. |
| Compact, precise copy | No player-facing copy changed. |
| State and consequence | Actual card/End Turn captures distinguish HP loss, absorption and defeat. |
| Interaction completeness | Actual targeting/cancel and controller-to-pointer handoff remain operable; input unlock and resolver state are asserted. |
| Visual cohesion | Current production paint, bone registration and persistent renderer canvases are retained. |
| Accessibility | Reduced motion suppresses recoil/guard movement and uses a fixed collapsed death endpoint; HP and outcome text still communicate the result. |
| Layout resilience | Fresh full 1080p captures retain the combat layout and control reachability. |
| Visual proof | Full real-renderer gameplay sequences and both-view authoring cycles were inspected, including joint extremes and final collapse poses. |

No exceptions are required. The input probe simulates supported controller actions; it does not constitute a physical-device usability session.
