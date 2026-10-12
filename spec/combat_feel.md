# Combat feel — feel-01

Presentation only. CombatEngine, state, seeds, RNG, saves, analytics event boundaries, card rules and authored attack animations remain authoritative. No art, audio recording or font is added. The design owner commits, reviews, captures the inspection fixture and publishes this implementation.

## Hit-stop

`CombatHitStop` is a child owned by each RunScene, with no autoload. At the first explicit HP-damage or addressed absorption popup, it sets `Engine.time_scale` to zero. Deadlines use `Time.get_ticks_usec()`, never a scaled timer.

| HP damage | Real-time stop |
| --- | ---: |
| No HP lost (block-only) | 35 ms |
| 1–3 | 40 ms |
| 4–7 | 65 ms |
| 8–11 | 85 ms |
| 12 or more | 110 ms |

A kill raises the table duration to at least 100 ms. A hero target adds 20 ms. Reduced Motion halves the resulting duration, including fractional milliseconds. Combat speed never shortens it.

Hits within 120 ms share the first hit's timestamp and the largest duration. A later member cannot restart a full-duration stop. If an earlier, shorter member has already finished, a larger late member can freeze only the remaining part of that original deadline. This preserves the first-origin merge contract without predicting future damage events.

Pausing, leaving combat, opening a blocking overlay or freeing the scene cancels an active stop and restores the current presentation/director scale. Planning, drag/aim, menus and map/reward modes cannot initiate a stop. Popup identities survive attack-to-feedback hand-offs so the same damage never stops twice. Explicit terrain HP damage uses the stop table and board shake without assigning a unit reaction or flash by tile coincidence.

## Board shake and impact flash

| HP damage | Board amplitude at 1080p |
| --- | ---: |
| 0–3 | 2.0 px |
| 4–7 | 3.5 px |
| 8–11 | 5.0 px |
| 12 or more, or a kill | 6.5 px |

A hero hit adds 1.5 px. Duration is `0.18 s + 0.02 s × amplitude in px`. Merged hits retain the largest amplitude and the existing kick's progress. Shake falls off quadratically over its duration. Only the board layer moves; the HUD and room backdrops retain their existing registration. Reduced Motion suppresses shake.

The struck-unit flash is white, peaks on the first frame after hit-stop (85% enemies, 60% hero) and fades over 140 ms with a quadratic ease-out.

## Enemy pacing

`CombatPacing` owns presentation clocks and an off-by-default debug timeline. Each actor records caption, pre-action delay, walk per tile, wind-up, impact, hit reaction/damage number, post-action settle and hand-off; banner and final hero hand-off are separate. Debug output is local probe JSON/console data, not a new analytics event.

- The first caption/action starts after the 0.35 s banner lead. The `<Enemy>: <Intent>` caption survives immediate movement/strike submissions and adds no wait. Hidden intents retain their existing copy without their old 0.16 s caption wait. ENEMY TURN still depends on real scheduled activation selection.
- Enemy travel is bounded by 0.20 s per tile. One existing target-frame interval is reserved for submission so the measured tile interval stays within the bound. Hero travel and authored gait phases/distances remain unchanged. This enemy scheduling cap supersedes the older native enemy travel timings in actor_presentation.md.
- Existing 0.06 s movement settle remains; the extra 0.20 s intent-caption wait is removed.
- Floating feedback advances using the existing 0.20 s action-advance beat. Damage popups and hit reactions retain their own lifetime across the next actor's pre-action; settle after the final reaction/number adds no extra wait.
- Turn-clock transitions are serialized and may coalesce pending order updates while actor actions continue. Final order work settles before the hero UI refresh, avoiding stale child/tween references.
- Independent enemy death dissolves retain their authored durations and overlap subsequent actors. A dying actor or an action targeting its tile waits for the dependency. Hero death retains the established blocking terminal presentation.
- Surface spawns commit their new ground on the first displayed frame and keep independent per-tile feedback clocks: 0.36 s normally and the existing 0.10 s static Reduced Motion beat. Actions whose tiles depend on an unfinished spawn wait; other actors proceed.
- No independent forced-movement body-slide scheduler exists in this baseline. Forced outcomes use the existing attack feedback, and turn-clock slides retain their durations while overlapping actor work. No new slide/animation was invented.

## Combat speed

The Settings panel adds **Combat speed** with **Normal / Fast / Fastest**, persisted as `combat_speed` with values `normal / fast / fastest`. Missing/invalid values normalize to Normal. Scales are 1.0 / 1.5 / 2.0.

The speed scope begins at a committed card's resolution lock and ends when the hand is interactive, or runs while enemies act. Planning, hover, overlays, map and rewards use the normal base scale. Existing trailer slow motion is retained as an external base and multiplied by the selected combat speed. Changes during a stop restore the current speed/base; cleanup does not overwrite an unowned scale.

Authored frame/popup/turn-clock clocks now integrate presentation time, including zero during a stop. Audio pitch/mix are unchanged; duration-limited SFX timers explicitly ignore time scale. The row uses the existing OptionButton, typography and row geometry, with focus scrolling for keyboard/controller navigation. Its secondary copy reads "How quickly enemy turns and card effects play out."

## Measurement and proof

The probe reproduces the approved `b_enemy_turn.gd` and `b_lib.gd` staging from the design owner's `peer-benchmark-capture` checkout: seed 126065, generated Fire combat at depth at least 2, room `(1, 2)`, placement selected through the original scoring/symmetry algorithm. It preserves the four intents (`skitter_strike`, `dust_bolt`, `glass_lunge`, `pelt`), 21 HP, exact opening hand, and the Rite of Noon / Tempest Form preparatory plays through production input.

The owner's original real-renderer benchmark was approximately 10.3 s. A headless original-HEAD scheduling trace measured 9.969 s from Pass to YOUR TURN; its action order was Crawler, Harrier, Acolyte, Lancer. The initial banner interval was 0.966 s; consecutive enemy hand-offs were 0.965 / 0.965 / 0.971 s. The original caption waits were 0.20 s each. Headless traces emit the dummy renderer's draw-completion signal exactly as the existing turn-clock banner suite does. They establish scheduling/state equivalence, not renderer proof.

The initial after trace was Normal 4.772 s, Fast 3.351 s and Fastest 2.637 s. Normal's first actor started at 0.351 s; consecutive hand-offs were 0.005 / 0.006 / 0.007 s. Actor intervals were 0.977 / 0.772 / 1.304 / 0.801 s, each below 1.4 s. The final trace passed at **Normal 4.765 s / Fast 3.352 s / Fastest 2.628 s**, against the final original-HEAD trace of **9.964 s**. The final Normal tile walk stayed below 0.20 s, all four actor intervals stayed below 1.4 s, the intent caption stayed visible during action submissions, and all three speeds matched the exact resolver state/RNG. Raw JSON and console logs are saved in `output/feel-01/timelines/` and `output/feel-01/logs/`. Native captures/timing remain pending because the implementation sandbox cannot access the macOS window server.

Headless verification uses `tests/combat_feel_test.gd`, the existing combat motion timing, floating text and enemy strike trail scripts, and the full `tests/run_tests.gd`. The new suite also checks actual card/round resolver equality, stop release on scene exit/pause/scope changes, retained popup lifetime/base font, surface/death overlap/dependencies, persistence native focus behavior, back-to-back hero hand-offs and retained intent captions. It is a separate runner because `tests/run_tests.gd` is outside this unit's owned files; no existing assertions were rewritten.

The probe writes `timeline_normal.json`, `timeline_fast.json`, `timeline_fastest.json` (and `timeline_before_normal.json` for `--baseline`) below its isolated `user://probes/combat_feel/`. Windowed captures are `heavy_hit_minus_1.png`, `heavy_hit_0.png`, `heavy_hit_plus_1.png`, `heavy_hit_plus_4.png`, `heavy_hit_plus_8.png`, `heavy_hit_post_stop_peak.png`, `reduced_motion_hit.png`, and `combat_speed_settings.png`, all 1920×1080 at 100% UI scale. Its generated proof contract is `output/feel-01/proof-contract.json`.

### Proof for the design owner

Run in the implementation worktree:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/feel-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id feel-01 --timeout 120 --expect-size 1920x1080 --proof-contract output/feel-01/proof-contract.json --result-manifest output/feel-01/probe-result.json tests/combat_feel_probe.gd
```

The 120-second budget covers all three rounds, six preparatory card plays, two heavy-hit fixtures and settings capture; the startup watchdog is unchanged. Inspect every capture, especially the first post-stop white peak, frozen frames, reduced-motion state and focused speed row. No windowed attempt was made here.

The director captures clips in their capture worktree after integrating this unit:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark-capture && python3 tools/trailer_director/capture.py b_enemy_turn --task-id feel-01 --render-scale 1 --out output/feel-01/clips --opt takes=round,round_clean
cd /Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark-capture && python3 tools/trailer_director/capture.py b_quick_strike --task-id feel-01 --render-scale 1 --out output/feel-01/clips
```

The capture tool is absent from this implementation checkout. The owner prepares the inspection fixture; this brief requests no worker-owned inspection_fixture.py invocation.

### Chosen defaults (non-player values only)

- Headless test/probe fixture damage 12 and range 10 for the existing heavy-hit presentation; integration observation 125 ms.
- Test real-stop tolerance 80 ms and timeout 2 s; committed-card timeout 6 s; probe action/round watchdog 18 s; layout settle 30 frames; test cleanup 20 frames.
- Proof validation uses the existing board region `[36, 62, 1848, 676]`, minimum luminance range 50 and deviation 3 to reject blank renders. The no-enemy fixture places its activation at Time 1000.
- Internal white-flash shader profile 8, the next free UV profile lane. No palette/art values were chosen.
- Temporary before-timeline instrumentation derives from local HEAD and disables new feel; its generated script is deleted after loading.

The shake decay rate, flash easing curve and row secondary copy remain owner decisions. Renderer proof, clip inspection, commit, peer review, inspection-fixture preparation and publication are owned by the design owner.

Final headless checks all exited 0: `COMBAT FEEL TEST RESULT: PASS`, `COMBAT MOTION TIMING TEST RESULT: PASS`, `FLOATING TEXT LAYOUT TESTS: PASS`, `ENEMY STRIKE TRAIL TEST RESULT: PASS`, `COMBAT FEEL PROBE TEST RESULT: PASS` (before and after), and full `TEST RESULT: PASS`. Source hashes and logs are indexed in `output/feel-01/verification.json`. Existing macOS certificate, expected analytics-acknowledgment and ObjectDB exit messages also occurred on the unchanged baseline. Native proof is not claimed.

## Scope cleanup regression contract

A scope begun inside a scope-less hit-stop adopts the stop's saved positive base,
not the frozen engine scale. Applying speed, ending a scope and restoring a stop
fall back to 1.0 for a nonpositive base. Scope-end clears retained presentation
feedback and requests the scene's normal stage refresh. Overlay maintenance runs
only inside a scope and defers its submission until normal animation submissions
have had an opportunity to render, so overlay refresh never adds a second render in the same process frame.
Both committed movement/card victory paths end pacing before the victory beat.
