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
- Superseded by pace-01 (owner, playtest 10, 2026-10-18: actions were too fast to follow): an enemy action's hit reaction and damage numbers play their full authored duration, then `ENEMY_ACTION_SETTLE_SECONDS` = 0.15 s before the next actor; each acting enemy after the first holds its caption `ENEMY_ACTION_LEAD_SECONDS` = 0.25 s before its wind-up. Move-only turns add no wait. The staged round measured Normal 4.267 → 5.364 s, Fast 3.680 → 4.638 s, Fastest 3.098 → 3.817 s (budget ≤ 9.0 s at Normal).
- pace-02 (owner enemy-pacing verdict, 2026-10-19): `ENEMY_ACTION_SPEED_SCALE = 0.80` multiplies combat speed from each enemy action's wind-up through its complete hit reaction and damage numbers. Effective Normal / Fast / Fastest action scales are 0.80 / 1.20 / 1.60. This includes attacks, casts, push/pull, AoE, lightning, ally support, status damage, mechanic views and maquette actions. The existing presentation clock supplies the scale; no authored animation is shortened, repeated or retuned.
- Caption/banner leads and the 0.15 s post-action settle retain ordinary combat speed. Travel, including approach walks embedded in mechanic actions, temporarily restores that speed and resumes the action clock afterward. Hero cards, real-time hit-stop, audio pitch and Reduced Motion behavior retain their existing rules.
- (Before pace-01) Floating feedback advanced using a 0.20 s action-advance beat.
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

Headless verification uses `tests/combat_feel_test.gd`, the existing combat motion timing, floating text and enemy strike trail scripts, and the full `tests/run_tests.gd`. The new suite also checks actual card/round resolver equality, stop release on scene exit/pause/scope changes, retained popup lifetime/base font, surface/death overlap/dependencies, persistence native focus behavior, back-to-back hero hand-offs and retained intent captions. The full `tests/run_tests.gd` now invokes that complete standalone runner (including `combat_pacing_regression_suite`) in an isolated task-runner process.

The probe writes `timeline_normal.json`, `timeline_fast.json`, `timeline_fastest.json` (and `timeline_before_normal.json` for `--baseline`) below its isolated `user://probes/combat_feel/`. Windowed captures are `heavy_hit_minus_1.png`, `heavy_hit_0.png`, `heavy_hit_plus_1.png`, `heavy_hit_plus_4.png`, `heavy_hit_plus_8.png`, `heavy_hit_post_stop_peak.png`, `reduced_motion_hit.png`, and `combat_speed_settings.png`, all 1920×1080 at 100% UI scale. Its generated proof contract is `output/feel-01/proof-contract.json`.

### qa-01 capture determinism and native measurement

The probe renders RunScene in a 1920×1080 `SubViewport` with `UPDATE_ALWAYS`,
matching `movement_undo_probe.gd`, and reads every capture from that target at
100% UI scale. The director's first three native runs passed the timing checks
but emitted 3024×1898 window-backing images, so the runner rejected them. Each
readback now asserts exact 1920×1080 pixels. Offsets and post-stop peak checks
still observe the real `RenderingServer.frame_post_draw` boundary; no capture
is resized or cropped. Fresh accepted runs are required for measurement import.

The old probe disconnected `frame_post_draw` as soon as the action coroutine
finished. The action uses elapsed presentation time; the requested +8 capture
uses rendered-frame count. At a slow draw cadence (including GPU readback/PNG
work), the action can finish before +8. A headless 5 fps reproduction finished
at offset 4 and failed the unchanged capture assertion; at 15 fps it finished
at offset 10 and passed. This establishes a probe lifetime defect.

A separate production regression submits an animation while frozen, then polls
the stop in the same process frame before draw. The old `_release_flashes()`
used routine overlay maintenance, whose already-submitted-frame guard discarded
the white peak. The unchanged HEAD pacing code fails both new release/peak
assertions; the fixed code passes. Stop release now replaces the pending frozen
board submission with its white peak before draw, even if that frame already
received animation state. Routine maintenance retains its existing guard;
modal cancellation, deletion and scene exit cannot force that peak update.
No stop duration, pacing speed, animation, resolver or RNG values changed.

Headless heavy timing now emits its dummy draw completion from a named late
process node, after animation and hit-stop polling, rather than relying on the
earlier `process_frame` boundary. The 5 fps trace captures `[0, 1, 4, 8]` and
85% on the first post-stop draw. This is deterministic scheduling proof;
native renderer correctness still requires the owner runs.

The probe now retains the fixture and pacing scope until all exact offsets
`[0, 1, 4, 8]` and the post-stop draw are observed, with a 3 s watchdog after
action completion. It reads back only requested samples after impact and encodes
PNGs after disconnecting the draw callback. The original capture assertion stays,
and additional checks verify each exact offset, restored positive time scale,
and the first post-stop enemy flash at the approved 85% peak (capture tolerance
0.025). `heavy_hit_trace.json` and `reduced_hit_trace.json` record draw offsets,
process frames, monotonic timestamps, stop state, scale, flash opacity and the
action-completion offset. Headless `--heavy-timing-only --max-fps 5` is a
scheduling regression; it creates no PNGs and is not native proof.

<!-- qa-01-native-measurements:start -->
Native qa-01 measurements from three consecutive validated windowed runs
at 1920×1080 / 100% UI scale, Pass to YOUR TURN:

| Speed | Run 1 | Run 2 | Run 3 | Median |
| --- | ---: | ---: | ---: | ---: |
| Normal | 4.809 s | 4.815 s | 4.808 s | 4.809 s |
| Fast | 3.394 s | 3.388 s | 3.394 s | 3.394 s |
| Fastest | 2.696 s | 2.706 s | 2.686 s | 2.696 s |

All three probes passed the frame-offset, post-stop peak, resolver state/RNG
and Normal-round budget assertions. Source manifests (SHA256):

- `/private/tmp/qa01-feel-feedback1-1.json` — `5252481830364f814de3260800703089ef9f20d7aeaf1ba072fbe6acc51d0bce`; captures/timelines: `/private/tmp/labyrinth-godot-home/qa-01-1791857040191800000-18217-combat_feel_probe-1/Library/Application Support/Escape the Umbra Visual Probe qa-01-1791857040191800000-18217-combat_feel_probe-1/probes/combat_feel`
- `/private/tmp/qa01-feel-feedback1-2.json` — `8df3f295b5cf11e2f6baee73cc2450877f7a5aca32639fcc718d66cb2c835b18`; captures/timelines: `/private/tmp/labyrinth-godot-home/qa-01-1791857081638524000-18360-combat_feel_probe-1/Library/Application Support/Escape the Umbra Visual Probe qa-01-1791857081638524000-18360-combat_feel_probe-1/probes/combat_feel`
- `/private/tmp/qa01-feel-feedback1-3.json` — `618094f94a4e5392c047d0f73cacdf65d516fba3a4be6185d701791340a1ea5c`; captures/timelines: `/private/tmp/labyrinth-godot-home/qa-01-1791857122328493000-18458-combat_feel_probe-1/Library/Application Support/Escape the Umbra Visual Probe qa-01-1791857122328493000-18458-combat_feel_probe-1/probes/combat_feel`
<!-- qa-01-native-measurements:end -->

### Proof for the design owner

Run these three commands consecutively in the implementation worktree. Each
manifest must be fresh and each command must pass before running the next:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id qa-01 --timeout 180 --expect-size 1920x1080 --proof-contract output/feel-01/proof-contract.json --result-manifest /private/tmp/qa01-feel-feedback1-1.json tests/combat_feel_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id qa-01 --timeout 180 --expect-size 1920x1080 --proof-contract output/feel-01/proof-contract.json --result-manifest /private/tmp/qa01-feel-feedback1-2.json tests/combat_feel_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id qa-01 --timeout 180 --expect-size 1920x1080 --proof-contract output/feel-01/proof-contract.json --result-manifest /private/tmp/qa01-feel-feedback1-3.json tests/combat_feel_probe.gd
```

The 180-second budget covers all three rounds, preparatory card plays, both
heavy-hit fixtures and settings capture; the startup watchdog is unchanged.
The manifests list the isolated capture directories, which also contain all
three timeline JSON files and the heavy-hit traces. Inspect every image and the
first post-stop white peak. No windowed attempt was made in the sandbox.
After the three passes, import their measured medians and per-run values:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-01 && python3 tools/record_combat_feel_measurements.py --manifests /private/tmp/qa01-feel-feedback1-1.json /private/tmp/qa01-feel-feedback1-2.json /private/tmp/qa01-feel-feedback1-3.json
```

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
- qa-01 proof defaults: `SLOW_DRAW_REGRESSION_FPS = 5`, `HEAVY_CAPTURE_TIMEOUT_MS = 3000`, `PEAK_OPACITY_TOLERANCE = 0.025`, and dummy draw `DRAW_PROCESS_PRIORITY = 100000`. These affect tests/probes only.
- Temporary before-timeline instrumentation derives from local HEAD and disables new feel; its generated script is deleted after loading.

The shake decay rate, flash easing curve and row secondary copy remain owner decisions. Renderer proof, clip inspection, commit, peer review, inspection-fixture preparation and publication are owned by the design owner.

Final headless checks all exited 0: `COMBAT FEEL TEST RESULT: PASS`, `COMBAT MOTION TIMING TEST RESULT: PASS`, `FLOATING TEXT LAYOUT TESTS: PASS`, `ENEMY STRIKE TRAIL TEST RESULT: PASS`, `COMBAT FEEL PROBE TEST RESULT: PASS` (before and after), and full `TEST RESULT: PASS`. Source hashes and logs are indexed in `output/feel-01/verification.json`. Existing macOS certificate, expected analytics-acknowledgment and ObjectDB exit messages also occurred on the unchanged baseline. Native proof is not claimed.

## Scope cleanup regression contract

A scope begun inside a scope-less hit-stop adopts the stop's saved positive base,
not the frozen engine scale. Applying speed, ending a scope and restoring a stop
fall back to 1.0 for a nonpositive base. Enemy hand-off waits for the longest
remaining bounded overlay lifetime while the scope is active, allowing the final
damage numbers and death dissolves to finish. Its terminal submission retires
numbers and presents the final dissolve frame even if a render frame was skipped. Scope-end then clears retained feedback and requests the normal stage
refresh only when the scene is unlocked, attached and not being deleted. Overlay maintenance runs
only inside a scope and defers its submission until normal animation submissions
have had an opportunity to render, so overlay refresh never adds a second render in the same process frame. An explicit hit-stop release with a pending white flash replaces the frozen submission before the same renderer draw; this exception adds no wait and does not permit additional routine maintenance submissions.
Both committed movement/card victory paths restore only time scale before the
real victory beat, retaining scope bookkeeping until normal cleanup. A restored
scale remains at the positive base during subsequent scope processing. Deferred
refresh callbacks recheck attachment, deletion and animation-lock state, and
exiting pacing never queues a stage refresh.

## pace-02 verification and director capture

Headless `pass_to_hero_banner` measurements against merged pace-01 (`4e874c34f`):

| Speed | Before | After |
| --- | ---: | ---: |
| Normal | 5.326 s | 6.010 s |
| Fast | 4.600 s | 5.053 s |
| Fastest | 3.805 s | 4.115 s |

Both probes passed resolver state/RNG equality at all three speeds. Normal
remains within 9.0 s. These are scheduling measurements, not renderer proof.
Logs and isolated timeline directories are indexed by the probe output in
`output/pace-02/logs/before-baseline-final.log` and `after-final.log`.

The action-clock suite exercises every action kind, all three speeds and both
Reduced Motion settings, including 12 real mechanic routes (en02/en04/en05/en06,
Seer, Thrall and other maquettes), nested travel, hero cards, modal restore,
director scale and hit-stop restore. Timed presentations must reach their final
authored frame without replay and retain their complete authored duration.
Mutations reject restored 1.0 action speed, slowed movement, stretched caption
lead and stretched settle, alongside the four existing pacing mutations.
Review feedback 1 additionally checks identical Fade/Ambush blinks and an
unaligned Dive at all three speeds, with Reduced Motion on and off. Blink and
approach submissions use movement speed; the following strike/flight uses the
0.80 action multiplier. A mutation removes both production path-animation
movement guards and must fail the independently observed approach-scale check.

All five SFX frame profiles run at 1.0 / 1.5 / 2.0 and 0.8 / 1.2 / 1.6.
Each added scale inherits every count floor of its corresponding combat speed;
the approved sync baseline is unchanged. The added runs pair fixture RNG inputs
with the original runs. Synthetic stagger fixtures submit their final resolved
board after the authored attack, as production callers do, so coarse sampling
cannot drop a target. Cue-frame, sample-length and onset checks remain intact.

Proof for the design owner (windowed; fresh output directories):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pace-02 && python3 tests/capture_pace_round.py --before --output-dir output/pace-02/captures/before
cd /Users/borgerding/workspace/Labyrinth.worktrees/pace-02 && python3 tests/capture_pace_round.py --output-dir output/pace-02/captures/after
```

The helper uses `tools/visual_probe_runner.py` with
`tests/pace_round_proof_contract.json` at 1920×1080, 100% UI scale, 60 fps,
retaining game audio. Each directory contains its `before.mp4` or `after.mp4`,
`capture.json` and `renderer-manifest.json`; the manifest locates the validated
`round_start.png` / `round_end.png` captures. Inspect both clips. No windowed run
was attempted in the implementation sandbox. Full suites, the inspection
fixture, commit, peer review and publication remain assigned to the director.

Chosen defaults (test-only): authored clock sample 0.08 s, real sample tolerance
0.025 s, external director fixture scale 0.5, authored-duration rounding tolerance
0.001 s, and nested movement offset `(0, 1)`. Mechanic cases reuse existing engine
fixtures and authored intents; no player-visible value or asset was chosen.
No `TODO_DESIGN_` placeholder was needed.
