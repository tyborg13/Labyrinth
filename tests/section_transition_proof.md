# flow-01 implementation handoff

Implementation only; all changes remain uncommitted. The design owner owns native
inspection, peer review, task metadata, commit and publication. No windowed run
was attempted because this worker has no window-server access.

Risk: **high** (reward flow, save/resume, modal input and presentation).
`parallel_task.py status` reports an empty owner-managed contract in this worktree
despite the brief's bootstrap description. This file records the implementation's
observable contract without modifying that metadata.

1. Non-final dragon CONTINUE starts the descent immediately, without the old
   relic delivery flourish or an intervening map. The Next section control,
   action, visibility/disabled state and controller label/focus branch are gone.
   Final COMPLETE ASCENT retains the existing terminal path. Reward rules and
   payouts are untouched. Pre-section-map legacy runs retain their existing flow.
2. Loading a claimed, cleared boss room starts the same overlay with a resume
   entry tag. The boss save remains the replay source until the destination
   entry saves successfully; loading an entered threshold does not replay it.
3. The overlay implements the brief's descent, full-brightness cover-fit
   painting, radial vignette, typography, text rise, title hold, arrival, input
   containment, skip gate and reduced-motion timing. Camera descent moves the
   board opposite the camera by 140px. Arrival reuses
   `MenuRunTransition.REVEAL_SECONDS` (0.22s, sine in/out), within the normal
   2.60–3.20s arrival interval. Reduced motion is exactly 0.30 + 1.40 + 0.30s;
   the existing reduced-motion room reveal is immediate. Entry retains its existing automatic map
   handoff after reveal; music anticipates that planning context so it starts
   once. No transition or acquisition sound cue is played.
4. The existing newly staged `section_entered` event receives
   `entry: auto_transition` or `entry: resume_transition` before the ordinary
   save-before-JSONL boundary. Existing revision/idempotency keys are unchanged.
5. `tools/demo_clips/section_transition.json` is an extension in the staged
   director format, with a separate driver. Neither protected demo-01 manifest
   changes. The clip uses actual lethal-card and CONTINUE handlers, shows the
   whole transition, and retains exactly 120 frames after completion at 60fps.

## Director feedback 1

1. The destination save remains the commit point. Its failure restores the
   cleared boss room and the original post-claim reward summary under a reverse
   fade, using the existing 0.24s / 0.12s reward-continue duration and exact
   notice: `Could not save. Your rewards are still here; try Continue again.`
   The summary is stored atomically with the claim in `section_transition_reward`;
   retry bypasses the claim transaction, and successful entry removes it.
   A quit save may contain the reconstructed reward screen; load recognizes the
   saved claim and immediately replays with `resume_transition`. Tests inject
   one failing atomic destination write, then exercise retry and a fresh-scene
   quit/resume. Both retain rewards/claim once and one successful entry/music
   handoff. Reduced-motion reversal is also covered.
2. Reward panel, title, banner painting and title effect share the same
   0.24s / 0.12s opacity ramp, with their original modulation restored afterward.
3. The full-width black band peaks at 50% alpha at y505 (the two authored line
   centres' midpoint) and fades linearly to zero at y375/y635. It rises/fades with
   the text. The 24px letter-spaced numeral uses `UiPalette.GOLD_BRIGHT`; both
   lines copy the existing restrained reward-banner shadow. Centres stay y470
   and y540. Fresh claimed-room resumes resolve that same shadow role.
4. The demo awaits the complete production lethal-card/death/reward-reveal
   coroutine, holds the finished reward screen for exactly 120 frames (2.0s),
   warps the real pointer to CONTINUE and sends native viewport press/release
   input. It hides the OS cursor during transition, then restores it for the
   existing 120-frame entry-room tail. The receipt validator rejects shorter
   reward holds and tails.
5. The existing final-claim assertion is untouched:
   `tests/dragon_rewards_test.gd:159`,
   `Final Continue transfers the claim to the profile before clearing the run`.
   It still fails in the feedback check, as it did against the pre-change HEAD.

The director's original ten-capture PASS and clip evidence at
`output/flow-01/director_r0/` were inspected and remain untouched. They precede
these fixes. The updated probe has **14** captures: the original ten plus
normal/reduced reverse-fade midpoint and restored-reward samples. Fresh native
capture is assigned to the director because this worker has no window server.

## Proof for the design owner

Run from the final merged implementation. Use fresh output/receipt paths if any
of these paths already exist. The native movie wrapper uses the existing demo
capture settings, GUI lease, disk guard, renderer verification and ffmpeg tools.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/visual_probe_runner.py --task-id flow-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/section_transition.json --result-manifest /private/tmp/flow-01-owner-feedback1-proof.json tests/section_transition_probe.gd
```

This emits the requested 0.3, 0.9, 1.5, 2.4 and 3.0s strip, reduced-motion
captures, Section VI and four save-failure recovery images. Images and `timeline.json` are in the isolated
`user://probes/section_transition/`; the proof receipt lists absolute PNG paths.
The probe draws the real scene and overlay at exact presentation times; it
does not substitute a mockup or generated art. Independently inspect the images
at 1920×1080, 100% UI scale. Windowed capture/judging remains pending.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/demo_clips/section_transition.py validate --output /private/tmp/flow-01-owner-feedback1-demo-validation
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/demo_clips/section_transition.py record --validation /private/tmp/flow-01-owner-feedback1-demo-validation --output /private/tmp/flow-01-owner-feedback1-demo
```

Native outputs: `/private/tmp/flow-01-owner-feedback1-demo/section_transition.mp4`,
`movie.avi`, untouched PCM `movie.wav`, `events.json`, `godot.log` and
`recording.json`. Listen to the music handoff. No inspection-fixture command was
requested by this unit brief; the design owner prepares the final fixture.

## TODO_DESIGN placeholders

`TODO_DESIGN_SECTION_ENTRY_SAVE_FAILURE` is resolved by feedback 1 and removed.
No new design placeholders. The pre-existing
`StartRoomMapFlow.TODO_DESIGN_SECTION_START_NARRATION` remains unchanged.

## Chosen defaults

Only invisible implementation/proof values were selected:

- Overlay canvas ordering: layer 100, following the existing loading overlay.
- Headless fixture seed 410; eight settling frames; 12s wait watchdog.
- Boundary checks sample 0.01s to either side of authored phase boundaries.
  Extra proof samples are reduced motion at 0.15, 0.9, 1.5 and 2.1s, and
  Section VI at 1.5s. Title-region proof uses `[360, 440, 1200, 160]`, with
  minimum luma range 20 and standard deviation 5 (proof checks only).
- Recovery proof samples at half of each existing reverse fade and 0.01s after
  completion. Recovery fixtures use run-index offsets 2, 3 and 4 to isolate
  analytics receipts.
- Demo staging: 30 frames; 1800-frame watchdog; 180s process watchdog; 30s GUI
  lease timeout. The 2.0s reward hold comes from director feedback, not a default. Existing demo Movie Maker
  quality/encoding settings are reused.
- Test-only lethal fixture: boss HP 1, Block/Stoneskin 0, hero one tile left of
  the dragon, Quick Stab in hand, Umbra radius 99 and a traversable hero tile.
  These values live in the clip's named fixture fields and never change game
  tuning. Production encounter art, camera, card rules and reward rules remain.

## Observed verification

Logs live under `/private/tmp/flow-01-*.log`.

Feedback 1 focused results (current source):

- `flow-01-feedback1-transition-handoff.log`: exit 0,
  `SECTION TRANSITION RESULT: 0 failures` (including normal/reduced save failure,
  retry, fresh-scene quit/resume, no repeated claim/payout, banner fade, band,
  bright numeral and reused shadow).
- `flow-01-feedback1-start-room-map.log`: exit 0,
  `START ROOM MAP RESULT: 0 failures`.
- `flow-01-feedback1-ui-lint-final.log`: `Ran 25 tests in 4.204s` / `OK`.
- `flow-01-feedback1-clip-tests-final.log`: `Ran 4 tests in 0.001s` / `OK`.
- `flow-01-feedback1-demo-final.log`:
  `DEMO CLIP section_transition: PASS (685 frames)` for each take;
  `SECTION TRANSITION DEMO VALIDATION: PASS (two identical headless takes)`.
  Receipt and traces: `/private/tmp/flow-01-feedback1-demo-validation-final/`.
  Reward appears at frame 281, pointer CONTINUE at 401, arrival at 575,
  transition completion at 594 and entry-room tail completion at 714.
- `flow-01-feedback1-probe-check-final.log`: parser-only probe check exits 0.
  The updated 14-capture renderer contract has **not** run in this worker;
  use the exact native command above. No native success is claimed.
- `flow-01-feedback1-python-suite.log`: full Python discovery exits 0,
  `Ran 674 tests in 659.745s` / `OK (skipped=63)`.
  The existing optional-dependency/native-bridge skips are unchanged.
- The final demo validation receipt was checked against current source hashes:
  `DEMO HANDOFF INPUT HASHES: MATCH`.
- `flow-01-feedback1-godot-suite.log`: full Godot attempt exits **124**,
  `error: command timed out after 900 seconds.` It completed the monolithic
  checks and serial suites through `threats_at_rest_test` (612 assertions),
  with no reported failed assertion before timeout. This is **not a full-suite
  PASS**. The director's feedback explicitly accepts a budget timeout alone
  while qa-07 repairs the serial runner. Focused transition coverage ran
  separately and passed, including the final-ascent path.
- `flow-01-feedback1-dragon-rewards.log`: exit 1, unchanged baseline assertion
  `ERROR: Final Continue transfers the claim to the profile before clearing the run`
  at `tests/dragon_rewards_test.gd:159`.

The following are earlier implementation-round results, retained as history;
feedback full-suite results are recorded above.

- `flow-01-section_transition_test.log`: `SECTION TRANSITION RESULT: 0 failures` (live
  CONTINUE, all skip inputs/gate, load/replay, rewards, final ascent, analytics,
  exact title centres, music stability and failed destination save).
- `flow-01-start-room-map.log`: `START ROOM MAP RESULT: 0 failures`.
- `flow-01-ui-lint-verified.log`: `Ran 25 tests in 3.347s` / `OK`.
- `flow-01-clip-tests-verified.log`: `Ran 4 tests in 0.001s` / `OK`.
- `flow-01-demo-validation-handoff-final.log`: `DEMO CLIP section_transition: PASS
  (566 frames)` for both takes / `SECTION TRANSITION DEMO VALIDATION: PASS
  (two identical headless takes)`. Reports:
  `/private/tmp/flow-01-demo-validation-handoff-final/{take-a,take-b}/events.json`;
  provenance: `validation.json` beside those take directories.
  Its input hashes were compared to the final source: `DEMO HANDOFF INPUT
  HASHES: MATCH`.
- `flow-01-python-suite.log`: `Ran 670 tests in 575.701s` /
  `OK (skipped=63)`. Skips: 6 pinned Python 3.12 audio checks, 16 optional
  classical-music dependency checks, 39 optional sound-lab dependency checks,
  2 native Blender checks requiring the director bridge. The four new clip-tool
  tests were added after discovery began and passed separately above.
- Parser-only checks for `scripts/run_scene.gd`, `scripts/section_transition.gd`
  and `tests/section_transition_probe.gd` exited 0 through the task runner.
- `git diff --check` passed.
- First full Godot attempt (`flow-01-godot-suite.log`) exited 124 with
  `error: command timed out after 900 seconds.` It had completed the monolithic
  checks and completed isolated suites through `sfx_sync_bank_test`; no failed
  assertion was reported. Python discovery and additional engine checks ran
  concurrently for much of this attempt. A second full run uses the same
  900-second limit with those other workloads finished.
- The second full Godot attempt (`flow-01-godot-suite-final.log`) also exited
  124 with `error: command timed out after 900 seconds.` It again completed
  isolated suites through `sfx_sync_bank_test` without a reported failed
  assertion. The full-run timing acceptance criterion is **not met**.
- Every remaining scheduled suite was then run separately through the task
  runner with the existing 180s per-suite limit, and all exited 0:

  ```text
  SFX SYNC HARNESS RESULT: PASS (4010 observations, 0 failures)
  Section map v2 suite: 0 failures (64 seeds x 6 sections)
  EN01 ENEMIES TEST RESULT: PASS
  EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)
  EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)
  MAGIC DECK INPUT TEST: PASS
  RUN END RECAP TEST RESULT: PASS
  TEST RESULT: PASS — main menu resume safety
  SECTION TRANSITION RESULT: 0 failures
  ```

  Their logs are `/private/tmp/flow-01-<suite-script-stem>.log`. Thus every
  scheduled Godot suite completed successfully across the runs; the aggregate
  full runner must still be reported as timed out, not PASS. The transition
  suite was rerun after the final reduced-motion and skip timing correction.

Existing failure, not rewritten: standalone `tests/dragon_rewards_test.gd`
exits 1 with `ERROR: Final Continue transfers the claim to the profile before
clearing the run` (`flow-01-rewards.log`). Repeating the same assertions against
the pre-change HEAD's `run_scene.gd` reproduced that exact failure and exit 1
(`flow-01-rewards-baseline.log`); temporary baseline copies were removed.
The focused live flow-01 final-ascent path passes.

The macOS headless engine also prints its existing `get_system_ca_certificates`
error. Intentional save-failure tests print failed-persistence diagnostics.
Some live scene runs print `ObjectDB instances leaked at exit`; no clean native
render or audio result is claimed by these headless runs.

## Files changed

- Runtime: `scripts/run_scene.gd`, `scripts/section_map_panel.gd`,
  `scripts/start_room_map_flow.gd`, new `scripts/section_transition.gd`.
- Analytics contract: `spec/analytics.md`.
- Tests and proof: `tests/helpers/program_sub_suites.gd`,
  `tests/section_transition_test.gd`, `tests/suites/section_transition_suite.gd`,
  `tests/section_transition_probe.gd`, `tests/proof_contracts/section_transition.json`,
  `tests/test_section_transition_clip.py`, this `tests/section_transition_proof.md`.
- Demo extension: `tools/demo_clips/section_transition.gd`, `.json`, `.py`, `.tscn`.
