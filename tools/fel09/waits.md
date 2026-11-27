# Enemy-turn waits

Source audit for the fel-09 worktree. Line numbers refer to the production files outside `tools/fel09`. The interval is activation of the retained Pass control through the next usable hero input boundary. A caller that awaits a helper inherits the helper's clock. Durations below are authored seconds unless specified.

## Speed and clock ownership

- Options exposes **Combat speed**, with Normal (1.0×), Fast (1.5×) and Fastest (2.0×). See `scripts/settings_panel.gd:351–360` and `scripts/settings_store.gd:112,429–436`. There is no separate persistent fast-enemy-turn or animation-speed setting.
- `scripts/combat_pacing.gd:131–164,208–228,271–283` applies Combat speed via `Engine.time_scale` in the enemy and card scopes. Enemy action wind-up through retained feedback also uses 0.80×. Travel suspends that action multiplier. Caption lead, settle and rail therefore advance at the scale of whichever scope and action phase owns the elapsed time. Holding Hurry (Space by default), left mouse or controller A during the enemy scope multiplies that scope by 2.0. Pass and a pre-held input do not trigger this multiplier. See `scripts/combat_pacing.gd:166–188,458–476` and `scripts/key_bindings.gd:7,15`.
- **P** below means accumulated presentation time (`combat_pacing.gd:108–120`). **T** means ordinary SceneTree timers/tweens. Both advance with the current engine scale and stop during hit stop. **F** means a process or post-draw boundary. The boundary itself has no authored duration and has no speed multiplier. **W** means unscaled wall time.
- Hit stop separately holds the presentation clock in `scripts/combat_hit_stop.gd:19–47,50–73`. It lasts 35/40/65/85/110 ms by damage, with a 100 ms lethal minimum and another 20 ms for the hero, halved by Reduced motion. Hits in its 120 ms merge window extend to the largest duration measured from the first hit. Combat speed and Hurry leave the wall deadline unchanged.
- The enemy scope drains and restores its scale before the final pickups, hero-start fire/fatigue, and draw (`scripts/run_scene.gd:24346–24427`). Those beats use the restored scale. Earlier rail motion, timers and sampled playback can cross action-scale changes within a single span.

## Round and pacing waits

| Source | Holds until | Clock and settings |
|---|---|---|
| `scripts/run_scene.gd:28871` | Complete the Pass round, including the checkpoints and UI publication below. | Inherits the round's clocks. |
| `scripts/run_scene.gd:24191` | Each activation-end battlefield-rule beat in order. | See rule playback below. |
| `scripts/run_scene.gd:24199` | The input-frame lock/tuck has drawn. Skipped if rule playback supplied the boundary. | F. |
| `scripts/run_scene.gd:24206,10127,10130,10132`, `scripts/locked_hand_render_cache.gd:123` | Capture the locked hand, wait for its slide if still live and recapture. Capture waits for a rendered viewport texture. | F and the hand slide's completion. `scripts/hand_fan_container.gd:84,130,188` uses `CLOSE_SLIDE_SECONDS` or `SPREAD_EASE_SECONDS` in scaled process delta. The locked cache may be reused without yielding. |
| `scripts/run_scene.gd:24212,24231,24252,24263` | Draw after lock/cache, before checkpoint staging, after checkpoint hold, and after first-activation simulation, respectively. | One F each when reached. |
| `scripts/run_scene.gd:24269,24273,24275` | Residual activation-end enemy loss, hero loss and defeats before first actor playback. | Floating feedback and death clocks below. |
| `scripts/run_scene.gd:24303` | Yield a draw if multiple same-frame enemy slices exceed the CPU budget. | F. The budget is CPU time. |
| `scripts/run_scene.gd:24335` | The current activation slice's full foreground playback. | Inherits the step dispatch waits below. |
| `scripts/combat_pacing.gd:412` | A referenced actor or destination's death animation, or a touched tile's active retained surface. | F polls a P deadline. Death duration comes from unit clocks or frames × cadence. Surface duration 0.36, reduced 0.10. See lines 661–748. |
| `scripts/combat_pacing.gd:398,427` | Intent lead for a slice with an action. First enemy uses the remaining time to the original banner clock + `BANNER_LEAD_SECONDS` (0.35). Subsequent leads use `ENEMY_ACTION_LEAD_SECONDS` (0.25). | P at current combat/hurry scale, with no Reduced motion shortening. |
| `scripts/combat_pacing.gd:398,451` | After-action retained feedback, including retained/staggered popups, death and surface deadlines, and flash (0.140). | P at action scale. Reduced motion changes some component clocks. |
| `scripts/combat_pacing.gd:398,455` | `ENEMY_ACTION_SETTLE_SECONDS` (0.15) after feedback. | P at combat/hurry scale, with no Reduced motion shortening. |
| `scripts/run_scene.gd:24346`. `scripts/combat_pacing.gd:250,254` | Final rail finishes, then remaining bounded feedback drains. | F polls rail completion or P deadline. Reduced motion abbreviates/skips individual visuals. |
| `scripts/run_scene.gd:24359` | Any forced-movement board pickup flair. | See pickup clock below. |
| `scripts/run_scene.gd:24369,24374,24377,24437,24442` | Conditional combat-ending branches: residual defeats, missed equipment, victory/reward playback, or terminal UI refresh. | Helper-owned. These branches did not occur in the 12 measured turns. Missed equipment uses 0.24, sampled pickup flight and 0.08 at lines 23375,23381,23393. |
| `scripts/run_scene.gd:24413,24416,24422` | Hero start-of-turn Fire, fatigue, then actual new hand deal. | See hand-off clocks below. |

`scripts/enemy_round_handoff.gd:17,27,33,39,56,64,93` yields preparation slices in the background while the draw is playing. See `scripts/run_scene.gd:18817,18820` for the post-draw yields. Publication at line 114 is synchronous. Preparation may fall back to synchronous work if the cached data is incomplete. No extra timer keeps input locked after publication. Similarly, checkpoint, simulation, HUD preparation and analytics can consume wall time between yields without a timer.

## Enemy dispatch sites and effects

| `scripts/run_scene.gd` await line(s) | What is awaited | Duration and modifiers |
|---|---|---|
| 24460,24903 | Unstaged burst or loss feedback and defeat cleanup at the end of a slice. | `scripts/enemy_mechanics/burst_playback.gd:103–104` delegates to floating feedback and defeat paths. |
| 24488,24902 | Turn-completion hero loss if it still needs a beat. | `scripts/hero_loss_playback.gd:38` delegates to floating feedback. |
| 24502,24531 | Deferred reaction/cascade and death playback. | `scripts/enemy_mechanics/deferred_death_view.gd:18–19` delegates to floating feedback and defeat paths. |
| 24506,24515 | Pacing's dependency check and eligible lead. | `combat_pacing.gd:412,427` above. |
| 24507 | Intent reason or redirected-intent popup. | `scripts/intent_callouts.gd:10–13,264–284`: 1.10 for a no-action reason (0.80 hold + 0.30 fade), 0.90 for a redirect. W between process frames with long-first-draw correction. Reduced motion removes drift and leaves lifetime. |
| 24511 | Battlefield-rule presentation within a slice. | Rule playback below. |
| 24524 | Hidden Umbra step and any recursive visible substeps. | `run_scene.gd:25014,25019,25021,25045,25047,25048,25049,25050` awaits visible move/action, summon lead, feedback, summon reward, defeat, 0.06 T and pacing settle. Reduced motion changes the inherited visuals. |
| 24527 | Traced charge/status application. | `scripts/enemy_mechanics/traced_status_view.gd:14–15` delegates to floating feedback and defeat paths. |
| 24544 | Per-case rig adapter or shared cutout contact playback. | `scripts/maquette_cutout_runtime/contact_actions.gd:16,42,68,69`: possible approach move, protected clip `seconds` and `contact`, remaining popup tail and defeat. Reduced motion generally uses one sampled frame. The clip/adapter owns any alternate timing. |
| 24551 | Mirror beam. | `scripts/enemy_mechanics/reflect_view.gd:283,295`: `BEAM_SECONDS` (0.30) with reduced-motion direct feedback, then popup feedback. |
| 24555,24556 | Bramble or lob adapter. | `scripts/enemy_mechanics/lob_view.gd:294,301,306,307`: 0.45 arc + 0.25 splash (arc skipped and splash sampled once in Reduced motion), remaining popups/defeats. `scripts/enemy_mechanics/bramble_view.gd:109` uses `TRANSITION_SECONDS` (0.25) when motion is enabled. |
| 24561 | Chain discharge. | `scripts/enemy_mechanics/capacitor_view.gd:129,137,164,175`: `HOP_SECONDS` (0.12) by hop, or clip duration plus remaining unplayed hops. Reduced motion skips/collapses clip movement. |
| 24570,24574,24575 | Hoarfrost Seer adapter, legacy Icefall or Gust. | `assets/units/hoarfrost_seer_cutout/actions.gd:42,62,64` uses protected clip duration/contact, then defeat and remaining popup tail. `scripts/enemy_mechanics/icefall_view.gd:129,141,148,149` uses `FALL_SECONDS` (0.18) then `PUFF_SECONDS` (0.30), popups and defeats. Reduced motion skips the fall and uses one puff frame. `scripts/enemy_mechanics/wind_view.gd:487,494,495` awaits forced travel, floating feedback and defeats. `scripts/forced_displacement_view.gd:6` uses `MOVE_STEP_FRAMES * MOVE_FRAME_SECONDS`, or a single frame in Reduced motion. |
| 24581,24585 | Stalker veil and Burrow Grub burrow/erupt. | `scripts/enemy_mechanics/stalker_view.gd:11,17`: default attack clock, then any recursive strike. `scripts/enemy_mechanics/burrow_view.gd:135,142,151,154,163,164`: rig or `RISE_SECONDS` (0.25), forced flight, surface and defeats. Reduced motion changes the rig rise and removes some displacement motion. |
| 24592 | Reinforcements reveal and arrival. | `run_scene.gd:24991,25002`: chosen arrival frame count/cadence with a `TileBurstFx.reveal_seconds` cue, then 0.08 T. Reduced motion uses the short/single-frame arrival when applicable. |
| 24616 | Relit braziers label, when any relight. | Floating feedback. |
| 24619 | Ordinary movement. | `run_scene.gd:25260,25279,25289,25296,25596`: path frames, possible ground/trap/loss feedback and defeat, then 0.06 T. Walk is P at combat/hurry scale (no 0.80× action factor). `combat_pacing.gd:458–476` caps ordinary enemy cadence using `ENEMY_TILE_SECONDS` (0.20) minus one target frame. Rig-specific travel uses authored movement data. Reduced motion changes travel sampling/visual treatment. |
| 24622,24625,24631,24633,24637 | Summon wind-up/reveal, then any card-play gain popup. | `run_scene.gd:23667` polls `TileBurstFx.reveal_seconds("summon", reduced)` on P. `summon_card_play_rules.gd:61` awaits floating feedback. Guardian/dragon clocks below. |
| 24640,24648 | Guardian surface or retained/fallback ground playback. | `run_scene.gd:34959,34970` delegates forced throw or 18 × 0.02 P, reduced 1 × 0.10. `combat_pacing.gd:705–728` usually overlaps surfaces in enemy scope (0.36 P, reduced 0.10). Only a later dependency or final drain holds the next beat. |
| 24650 | Worldspine pulse. | `scripts/worldspine_pulse_view.gd:16–17` awaits floating feedback and defeats. |
| 24653 | Delayed Meteorfall landing. | `scripts/meteorfall_landing_view.gd:34,53,55`: 60 Hz authored samples from `START_PROGRESS` to contact and the longer of the FX/floating-text tail. Reduced motion contacts immediately. Then defeats/remaining burst slice. |
| 24658,24662,24666,24669,24671,24673 | Capacitor, Seer, Grub, generic cutout, Guardian, and dragon utility. | Case `actions.gd` clips use protected durations/contact markers. `scripts/maquette_cutout_runtime/action.gd:144` uses authored clip frames at 60 Hz. Guardian at `run_scene.gd:35160,35173,35180` awaits summon lead or surface fallback, or clip frames × `GuardianCutout.ATTACK_FRAME_SECONDS`. Dragon at lines 24928,24942 uses 48 × 1/60 P, reduced 1 × 0.22, then remaining popup feedback (normal 0.38 elapsed credit). |
| 24680,24681,24684,24692 | Status tick, Block, Heal, or Stoneskin feedback and defeat. | Ground plus defeat or floating feedback plus defeat, as above. |
| 24700,24701 | Harrier and Iskaldra attack preparation. | `scripts/harrier_cutout/action.gd:32` uses 18 × 1/60 P. `scripts/iskaldra_cutout/action.gd:47` uses `PREPARE_SECONDS` by clip (0.32 Talon, 0.24 Lance, 0.36 Storm). Reduced motion skips both preparations. |
| 24792,24875,24886,24897 | Ordinary attack clip, trap or remaining contact feedback, then defeat. | Lines 24709–24767 select frames × cadence. The generic fallback is `ATTACK_FRAMES` × `ATTACK_FRAME_SECONDS` (6 × 0.04), with FX and cutout overrides. Large dragon area spell uses 66 × 1/60 normally, 1 × 0.22 reduced. Many other attacks collapse to one frame in Reduced motion. Popup feedback has elapsed credit where the strike already showed it. |
| 24528,24532,24548,24552,24557,24562,24572,24576,24582,24586,24626,24643,24654,24659,24663,24667,24674,24682,24898 | Each applicable branch's after-step pacing. | `combat_pacing.gd:451,455`: retained deadline then 0.15 settle. |

### Shared playback clocks

| Source | Holds until | Clock and settings |
|---|---|---|
| `scripts/run_scene.gd:22966,22978,22992,23014` | The sampled clip finishes. `frame_count × frame_seconds`. At zero cadence, the sampler submits the final pose and yields once. | P. One F at zero cadence. Reduced motion is chosen by callers. |
| `scripts/run_scene.gd:22793,22831,27404` | Floating feedback. `GENERIC_PRESENTATION_SECONDS` (0.18) without text, or `ANIMATION_DURATION_SECONDS` (0.48) + 0.07 per peak stagger slot with optional delay/elapsed credit. Text can overlap some actions. Authored special effects may extend the duration. | Empty path T, animated path P. Reduced motion changes placement and some caller delays. |
| `scripts/run_scene.gd:12836,23028,23082,23084,23088–23094`, `scripts/warband_view.gd:111` | Warband break (`BREAK_BEAT_SECONDS` 0.40), defeat/terrain frames × cadence, optional separate burst/dissolve clock, then 0.04 T settle (may run during defeat preparation). | P/T. Case data and Reduced motion affect visuals and some clips. Enemy-only independent dissolves overlap when eligible. |
| `scripts/maquette_cutout_runtime/death_sequence.gd:62` | Longest hold/dissolve among active units and scheduled death bursts. | Unit clocks or shared frame duration. The sampler waits on P through `scripts/combat_playback_samples.gd:45–54`. |
| `scripts/displacement_throw.gd:115,167` | Upheaval rise or forced-flight/landing. | P, using `LAUNCH_SECONDS` 0.06, `FLIGHT_SECONDS` 0.36 and `SURFACE_SECONDS` 0.36 at landing as applicable. Reduced motion changes sampling. |
| `scripts/battlefield_rules/playback.gd:60–62,76,80,82,86,89,92,93,116,133,151,170` | Rule feedback/defeats before the rule, then Gust, Lightning Storm, caption/Upheaval, and any new loss/arrival-defeat feedback. | `CAPTION_ONLY_HOLD_SECONDS` 0.60 P even with Reduced motion. Gust and displacement above. Lightning Storm uses `CHAIN_JUMP_SECONDS` 0.12 per hop and the scheduled authored strike/lingering FX tail. Reduced motion compresses that visual path. |

### Rail, camera, and final hand-off

| Source | Holds until | Clock and settings |
|---|---|---|
| `scripts/combat_pacing.gd:235–250`, `scripts/run_scene.gd:12612,12637,12648,12650` | Superseded rail finishes immediately. A style update yields for layout then awaits parallel scale/tint tween or fallback timer. Holds the rail's next beat and can hold final hero hand-off. | F plus T, `TURN_ORDER_STYLE_SECONDS` (0.20). Reduced motion replaces the transition with direct entries. No actor waits for ordinary rail motion in enemy scope. |
| `scripts/run_scene.gd:12660,12676,12706,12710` | Layout, death echo delay, parallel removal slide/dissolve. Tween definitions at 12702–12704. | F, `TURN_ORDER_DEFEAT_ECHO_DELAY_SECONDS` (0.16 T), `TURN_ORDER_REMOVE_SECONDS` (0.22 T), `TURN_ORDER_DEFEAT_DISSOLVE_SECONDS` (0.56 P with a frame wait at 12567). |
| `scripts/run_scene.gd:12717,12756,12758,12777` | Submitted rail layout, reposition/style, new portrait entry. Tween definitions at 12736,12744–12745,12773–12775. | F plus `TURN_ORDER_REFLOW_SECONDS` (0.30 T), `TURN_ORDER_STYLE_SECONDS` (0.20 T) or `TURN_ORDER_INSERT_SECONDS` (0.24 T). Reduced motion skips these rail phases. |
| `scripts/run_scene.gd:28446,28486,28504,28505` | Sequential acquisition flair for collected equipment/items. | T. Reduced popup hold 0.45. The normal icon sequence is 0.18 + 0.20. Acquisition ray waits one F (line 28602), `LOADOUT_ACQUISITION_RAY_SECONDS` (0.42) + 0.04 at 28636, then two 0.12 + 0.16 destination pulse loops (28637,28673–28675). Banner alpha tween 0.08 + 0.24 + 0.14 overlaps the icon. |
| `scripts/run_scene.gd:23261,23307` | Hero turn-start fatigue / Fire numbers run their full duration. | P at restored scale, using `FloatingCombatText.total_duration`. Reduced motion changes animation treatment, with no hard-coded shorter lifetime here. |
| `scripts/run_scene.gd:22354,22384,22433`, tween at 7335 | Hand deal completes when its last incoming tween finishes. | T at restored scale, `DRAW_FRAME_SECONDS` (0.32) × 0.62 in Reduced motion, plus `DRAW_STAGGER_SECONDS` (0.16) per preceding card. Empty draws return immediately. |
| `scripts/turn_banner.gd:62–72` | Nonblocking turn banner tween, included for visual attribution. | T. Normal reveal max(0.16, 0.34) then 0.62 hold then 0.34 fade. Reduced 0.75 hold. Caption or boss bar can suppress it and an incoming action caption can dismiss it early. |
| `scripts/combat_board_view.gd:11039–11054`, `scripts/run_scene.gd:3792–3794` | Nonblocking camera kick/rumble and room centering. | T. `combat_pacing.gd:90–92` defines kick duration as 0.18 + amplitude × 0.02, or a caller-supplied rumble duration. Centering is 0.42. Reduced motion suppresses displacement. |
