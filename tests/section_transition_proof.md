# flow-01 implementation handoff

Implementation only; all changes remain uncommitted. The design owner owns native
inspection, peer review, task metadata, commit and publication. No windowed run
was attempted because this worker has no window-server access.

Risk: **high** (reward flow, save/resume, modal input and presentation).
The initial implementation observed an empty owner-managed contract via
`parallel_task.py status`. This handoff records the observable acceptance and
proof without modifying owner-managed task metadata.

1. Non-final dragon CONTINUE starts the descent immediately, without the old
   relic delivery flourish or an intervening map. The Next section control,
   action, visibility/disabled state and controller label/focus branch are gone.
   Final COMPLETE ASCENT retains the existing terminal path. Reward rules and
   payouts are untouched. Pre-section-map legacy runs retain their existing flow.
2. Loading a claimed, cleared boss room starts the same overlay with a resume
   entry tag. The boss save remains the replay source until the destination
   entry saves successfully; loading an entered threshold does not replay it.
3. The overlay implements the approved descent, full-brightness cover-fit
   painting, radial vignette, typography, text rise, title hold and input gate.
   Camera descent moves the board opposite the camera by 140px. As amended by
   feedback 3, normal arrival cross-fades directly to the map at 2.60–3.00s;
   reduced motion uses 1.70–2.00s without movement, and skipping uses 0.12s.
   The destination entry room stays covered until the player closes the map.
   Destinations without an automatic map keep the original room arrival.
   Planning music starts once at handoff; no new sound cue is played.
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
   input. It suppresses the game cursor glyph during transition, then restores it for
   the 120-frame tail (now on the fully open map, per feedback 3). The receipt validator rejects shorter
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

## Director feedback 2

The supplied review was read from local repository history at
`a76c2bbdeb388e5f414a4af23e35e026adf678cc:spec/peer_benchmark/feedback/flow-01_review_cf9d7737a.md`;
that round's starting HEAD was `cf9d7737a`; feedback 3 starts from `f1e041f29`. No review, commit or
publication was run by this worker.

1. `section_transition_reward.gd` migrates old cleared-boss saves before descent,
   preserving known boss/relic identities and reading exact historical payout
   totals from the matching local `reward_offered` milestone. It only writes
   presentation metadata; it does not invoke combat resolution, grants or claim
   transactions. Previously saved empty reward screens are also recognized.
   Fourteen live recovery cases cover new saves, old saves with/without an
   archived offer, and already-broken empty reward saves; they cover retry,
   fresh-scene quit/resume and both motion settings.
2. Test-only instrumentation counts real music `.play()` calls, destination-save
   attempts and claim transactions. Arrival/playback assertions run after the
   complete reveal, deferred callbacks and an audio settling interval. Exact
   failure copy is compared to the independently specified literal. Tests
   explicitly reject already-entered sections and invalid destinations without
   forwarding movement or attempting persistence. Five in-memory mutation
   flags exercise the four requested guards and notice punctuation; checkout
   sources and assertions are never rewritten by mutation runs.
3. `section_map_review_probe.gd` now reaches a real dragon reward, acknowledges
   it with pointer input, checks automatic arrival and then exercises history
   tab/node inspection, keyboard/controller focus and active Scout preservation.
   It contains no references to the removed onward control. The two-choice
   assertion is preserved by selecting an actual generated two-choice fork.
   Existing recovery-fog assertions are preserved using Section VI, where
   revision 5's fog applies. `spec/section_map.md` documents automatic advance.
4. Both the game transition and demo use the existing cursor-glyph suppression
   API. Independent ownership keys preserve other suppressors. Completion,
   cancellation and tree exit restore this transition's suppression; tests
   cover those lifecycles. The demo restores its own suppression on completion
   and exit as well.

Historical-data decision (resolved by feedback 4): reconstructed legacy screens
omit both payout/Moltshard rows. They show the known dragon and recorded relic
with its existing rules, plus CONTINUE. No replacement values or placeholder
copy appear. Both legacy reward TODO constants have been removed. Existing
complete reward summaries retain their authored totals rows.

The main native contract now requires 18 named captures: the prior 14 plus
normal/reduced legacy-save reversal and restored-reward samples. Its existing
minimum-image floor is unchanged; all 18 required patterns are enforced.
The updated map review contract requires 14 captures. No fresh windowed run
was attempted by this worker.

## Feedback 3 — direct title-to-map handoff

The title card now hands directly to the live map at 2.60s. Over 0.40s,
cubic in-out, the text/band fade out, the painting dims to the existing
`Color(0.56, 0.54, 0.59)`, and all live map chrome fades in. The normal painting
lands on the map's actual content-field rectangle, cover-fit and scale 1.00;
its vignette also resolves to the map's unmodified backdrop. The actual map
controls temporarily draw in the transition layer, then return synchronously
to their original parent and sibling position. An opaque backing covers the
entry room throughout. Map hover, pointer picking and controller focus are suppressed until
completion, alongside the existing transition-only input and cursor gate.

Reduced motion cross-fades the stationary title into the map over 0.30s;
skips use 0.12s. Destination persistence and the single planning-track start
happen at the beginning of the cross-fade. A destination that cannot auto-open
its map keeps the former black arrival and room reveal. The existing failed-save
reversal, reward retry/resume matrix and final ascent remain covered.

Frame-level tests advance the real scene at 60 Hz, including the entry/save
frame and overlay teardown. They check opaque board coverage, live map drawing
order, input suppression/restoration, cubic midpoint/quarter-point opacity,
exact final framing and one music playback after deferred callbacks. Native
captures now include midpoint/full-open pairs at 2.80/3.00s normal and
1.85/2.00s reduced. The contract requires 21 named images; the existing minimum
floor remains unchanged. The demo emits `map_fully_open` and keeps that map
visible for exactly 120 more frames after its natural death, reward hold and
real-pointer CONTINUE path.

The numbered implementation notes above describe earlier rounds; this owner
feedback supersedes their entry-room reveal and 3.20s map-path timing.

## Feedback 4 — known-only legacy rewards and scoped array audit

Review source: `54a704357:spec/peer_benchmark/feedback/flow-01_review_63c1f11ba.md`
(the file is absent from this worktree). This round starts at `63c1f11ba`.

1. The revision-5 generator freeze and `main_menu_resume_test` timeout belong to
   fix-05. `section_map_graph.gd` is untouched. The director will rerun the full
   Godot suite after that fix lands; this round runs the requested transition,
   probe semantics and Python suites.
2. Newly reconstructed summaries carry `legacy_summary: true`. Their screen
   omits both totals rows entirely, even if an old local offer still retains
   exact deltas. Relic presentation requires its identity in the save's owned
   relics or matching local offer; absent identities produce no relic artwork,
   name, destination or rules rows. Existing old placeholder-bearing summaries
   also omit missing totals, since presentation no longer consumes the old
   `payout_text`/`shard_text` overrides. Both TODO constants are removed.
   Independent live assertions inspect visible labels for the literal
   `TODO_DESIGN`, require omitted nodes to be absent, and verify the known
   dragon/relic, rules and CONTINUE. The recovery matrix now includes 18 cases:
   the former 14 plus missing-relic and previously persisted-placeholder saves,
   each with retry and quit/resume. Rewards and claim counts remain unchanged.
3. The 117 typed declaration literal initializers in 13 owned GDScript files
   remain unchanged under the director's clarification. One conditional literal
   feeding `Array[String].append_array` in `_add_surface_skill_choices` is now
   explicit relocation/creation branches using `choices.assign([...])`; values
   and order are identical. No bare literal assignment to an already declared
   typed variable was found. Remaining bare reassignments in `run_scene.gd`
   target untyped `Array` variables, and its remaining typed conditionals return
   typed arrays on both branches. Audit log:
   `/private/tmp/flow-01-feedback4-array-audit.log`.
4. `section_transition_probe.gd --semantics-only` runs the same live state/label
   assertions and timeline without reading a renderer texture or writing PNGs.
   Native mode still requires the real windowed renderer. Its legacy captures
   now stage an old cleared-boss save without a reward summary or local offer.
   The existing 21-image native contract and capture names remain unchanged.

New fixture-only data: recovery run offsets now span 2–19; the additional cases
remove the recorded relic or carry obsolete placeholder fields. No new
player-facing default or design placeholder was introduced.

## Proof for the design owner

Run from the final merged implementation. Use fresh output/receipt paths if any
of these paths already exist. The native movie wrapper uses the existing demo
capture settings, GUI lease, disk guard, renderer verification and ffmpeg tools.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/visual_probe_runner.py --task-id flow-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/section_transition.json --result-manifest /private/tmp/flow-01-owner-feedback4-proof.json tests/section_transition_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/visual_probe_runner.py --task-id flow-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/section_map_review.json --result-manifest /private/tmp/flow-01-owner-feedback4-map-review-proof.json tests/section_map_review_probe.gd
```

This emits the requested 0.3, 0.9, 1.5, 2.4 and 3.0s strip, the additional
normal 2.8s and reduced 1.85/2.0s handoff captures, the other reduced-motion
samples, Section VI and eight save-failure recovery images. Images and `timeline.json` are in the isolated
`user://probes/section_transition/`; the proof receipt lists absolute PNG paths.
The probe draws the real scene and overlay at exact presentation times; it
does not substitute a mockup or generated art. Independently inspect the images
at 1920×1080, 100% UI scale. Windowed capture/judging remains pending.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/demo_clips/section_transition.py validate --output /private/tmp/flow-01-owner-feedback4-demo-validation
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/demo_clips/section_transition.py record --validation /private/tmp/flow-01-owner-feedback4-demo-validation --output /private/tmp/flow-01-owner-feedback4-demo
```

Native outputs: `/private/tmp/flow-01-owner-feedback4-demo/section_transition.mp4`,
`movie.avi`, untouched PCM `movie.wav`, `events.json`, `godot.log` and
`recording.json`. Listen to the music handoff. No inspection-fixture command was
requested by this unit brief; the design owner prepares the final fixture.

## TODO_DESIGN placeholders

`TODO_DESIGN_SECTION_ENTRY_SAVE_FAILURE` is resolved by feedback 1 and removed.
Both legacy historical-total placeholders were resolved and removed in feedback 4.
The pre-existing
`StartRoomMapFlow.TODO_DESIGN_SECTION_START_NARRATION` remains unchanged.

## Chosen defaults

Only invisible implementation/proof values were selected:

- Overlay canvas ordering: layer 100, following the existing loading overlay.
- Headless fixture seed 410; eight settling frames; 12s wait watchdog.
- Boundary checks sample 0.01s to either side of authored phase boundaries.
  Extra proof samples include normal 2.8s and reduced motion at 0.15, 0.9,
  1.5, 1.85, 2.0 and 2.1s, and
  Section VI at 1.5s. Title-region proof uses `[360, 440, 1200, 160]`, with
  minimum luma range 20 and standard deviation 5 (proof checks only).
- Recovery proof samples at half of each existing reverse fade and 0.01s after
  completion. Recovery fixtures use run-index offsets 2 through 19 to isolate
  analytics receipts.
- Frame observations use `FRAME_SECONDS = 1.0 / 60.0`,
  `FRAMING_EPSILON_PX = 0.1`, `COLOR_EPSILON = 0.0001`, and
  `SCALE_EPSILON = 0.001`.
  These are test-only sampling/tolerance fields. Text drawing order is derived
  from the live map scrim z-index plus one, not a separate visual decision.
- Audio-count observations wait 1.0s plus the existing eight settling frames;
  this is test-only, covering deferred context refresh and music fades.
- Map review's fog fixture uses section index 5, with a real marked route
  through prior sections. Its isolated pickup uses the player's actor turn,
  and sight/range 99; the ordinary resolver awards the actual 23
  lost Embers. These are fixture fields only. Generated two-choice topology
  supplies the navigation fixture without changing generator rules.
- Demo staging: 30 frames; 1800-frame watchdog; 180s process watchdog; 30s GUI
  lease timeout. The 2.0s reward hold comes from director feedback, not a default. Existing demo Movie Maker
  quality/encoding settings are reused.
- Test-only lethal fixture: boss HP 1, Block/Stoneskin 0, hero one tile left of
  the dragon, Quick Stab in hand, Umbra radius 99 and a traversable hero tile.
  These values live in the clip's named fixture fields and never change game
  tuning. Production encounter art, camera, card rules and reward rules remain.

## Observed verification

Feedback 4 current results (logs under `/private/tmp/flow-01-feedback4-*`):

- `transition-delivery.log`: exit 0, `SECTION TRANSITION RESULT: 0 failures`
  (18 recovery cases plus the existing transition/arrival/frame/input/analytics
  checks, after the final array cleanup).
- `probe-semantics-delivery.log`:
  `SECTION TRANSITION PROBE SEMANTICS: 0 failures; no renderer captures`.
- `map-review.log`: `SECTION MAP REVIEW PROBE: PASS` (headless semantics).
- `start-room-map.log`: `START ROOM MAP RESULT: 0 failures`.
- `ui-delivery.log`: `Ran 25 tests in 3.993s` / `OK`.
- `demo-delivery.log`: two `DEMO CLIP section_transition: PASS (672 frames)` results;
  `SECTION TRANSITION DEMO VALIDATION: PASS (two identical headless takes)`.
  Receipt: `/private/tmp/flow-01-feedback4-demo-validation-delivery/validation.json`.
- `array-audit.log`: `WINDOWS ARRAY AUDIT: 13 owned files; 117 permitted typed
  declaration literal initializers unchanged from HEAD`.
  One conditional literal input was changed to explicit `assign` branches;
  no bare literal assignment to an already declared typed variable was found.
  This is a source-form audit, not a substitute Windows execution or parser check.
- `probe-parser.log`: parser-only check exits 0; the final live semantic run
  also compiles and executes the final probe.
- `python-suite.log`: exit 0, `Ran 702 tests in 660.137s` /
  `OK (skipped=63)`.
- `git diff --check`: clean. No windowed probe was attempted. The native
  commands above will update the existing 21-image contract with the new legacy
  known-only reward states. Full Godot is assigned to the director after fix-05,
  as stated in feedback 4; the earlier full-suite results below are historical.

Reproduce the headless probe semantics without producing renderer evidence:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/godot_task_runner.py --task-id flow-01 --stream -- godot --headless --path . --script tests/section_transition_probe.gd -- --semantics-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/flow-01 && python3 tools/godot_task_runner.py --task-id flow-01 --stream -- godot --headless --path . --script tests/section_map_review_probe.gd
```

Feedback 3 current results (logs under `/private/tmp/flow-01-feedback3-*`):

- `transition-delivery.log`: exit 0, `SECTION TRANSITION RESULT: 0 failures`.
  Includes the frame-by-frame opaque coverage check, exact terminal crop/tint,
  cubic quarter/midpoint samples, map input/focus restoration, teardown,
  one playback/arrival after deferred work, fallback room arrival, all skip
  inputs, save migration/recovery, final ascent and unchanged rewards.
- `map-review-delivery.log`: `SECTION MAP REVIEW PROBE: PASS` (headless logic).
- `start-room-map.log`: exit 0, `START ROOM MAP RESULT: 0 failures`.
- `ui-final.log`: `Ran 25 tests in 3.717s` / `OK`.
- `clip-tests-final.log`: `Ran 4 tests in 0.001s` / `OK`.
- `demo-delivery.log`: both takes report
  `DEMO CLIP section_transition: PASS (672 frames)`;
  `SECTION TRANSITION DEMO VALIDATION: PASS (two identical headless takes)`.
  Current-source receipt:
  `/private/tmp/flow-01-feedback3-demo-validation-delivery/validation.json`.
  `DEMO HANDOFF INPUT HASHES: MATCH`. Event frames: reward 281, pointer
  CONTINUE 401, arrival 557, map fully open 581, tail finished 701.
- `mutations.log`: all six mutants exit 1 with behavioral assertions and zero
  script/parser errors: arrival guard 33 failures, already-entered guard 1,
  destination validation 2, claimed retry bypass 12, notice punctuation 14,
  opaque-board-coverage removal 44. Mutants are in-memory only.
- `probe-parser-delivery.log`: final parser-only probe check exits 0. Contract negative
  checks reject previous evidence missing `normal_2800`, `reduced_1850` and
  `reduced_2000`. Fresh native rendering and the 21-image contract remain
  assigned to the director. No windowed run or native movie was attempted.
- `dragon-rewards.log`: exit 1, the unchanged pre-existing assertion
  `Final Continue transfers the claim to the profile before clearing the run`
  at `tests/dragon_rewards_test.gd:159`.
- `python-suite.log`: exit 0, `Ran 674 tests in 616.717s` /
  `OK (skipped=63)`.
- `godot-suite.log`: exit **124**, `error: command timed out after 900 seconds.`
  The monolithic checks and completed children passed through
  `PROGRAM SUITE sfx_sync_bank_test: PASS`; no failed assertion or script/parser
  error was reported before timeout. This is **not** a full Godot PASS. The
  director explicitly accepts a budget timeout alone while qa-07 repairs the
  serial runner. The final transition suite ran separately and passed.
- `git diff --check`: clean.

The headless transition suite retains the existing macOS certificate diagnostic,
injected save-failure errors and detached reward-control focus errors. Deferred
controller-focus attempts while the map is intentionally disabled also emit
focus warnings; input/focus restoration assertions pass. Some runs emit existing
ObjectDB cleanup warnings. No native-renderer or audible-music success is inferred
from these headless results.

Older results below are retained as history and are not a claim about fresh captures.

Logs live under `/private/tmp/flow-01-*.log`.

Feedback 2 current results:

- `flow-01-feedback2-transition-verified.log`: exit 0,
  `SECTION TRANSITION RESULT: 0 failures`.
- `flow-01-feedback2-map-final.log`: exit 0,
  `SECTION MAP REVIEW PROBE: PASS` (headless logic, no new captures).
- `flow-01-feedback2-start-verified.log`: exit 0,
  `START ROOM MAP RESULT: 0 failures`.
- `flow-01-feedback2-python-suite.log`: exit 0,
  `Ran 674 tests in 589.488s` / `OK (skipped=63)`.
- `flow-01-feedback2-ui-lint-final.log`: `Ran 25 tests in 2.869s` / `OK`.
- `flow-01-feedback2-clip-tests-final.log`: `Ran 4 tests in 0.001s` / `OK`.
- `flow-01-feedback2-demo-final.log`: two
  `DEMO CLIP section_transition: PASS (685 frames)` results and
  `SECTION TRANSITION DEMO VALIDATION: PASS (two identical headless takes)`.
  Current-source receipt: `/private/tmp/flow-01-feedback2-demo-validation-final/validation.json`;
  `DEMO HANDOFF INPUT HASHES: MATCH`.
- `flow-01-feedback2-transition-probe-check.log`: parser-only check exits 0.
  The contract was also checked against the director's previous 14 images:
  `TRANSITION PROOF CONTRACT: previous 14 captures rejected; all 18 named captures required`.
  Fresh renderer execution remains assigned to the director.
- Each `flow-01-feedback2-mutant-<name>-verified.log` exits 1 with expected
  behavioral assertion failures, not parser errors:

  | Mutation | Observed result |
  | --- | --- |
  | `arrival_guard` | `SECTION TRANSITION RESULT: 7 failures` |
  | `entered_guard` | `SECTION TRANSITION RESULT: 1 failures` |
  | `destination_guard` | `SECTION TRANSITION RESULT: 2 failures` |
  | `retry_bypass` | `SECTION TRANSITION RESULT: 12 failures` |
  | `notice_literal` | `SECTION TRANSITION RESULT: 14 failures` |

  Reproduce through the regular task runner, adding e.g.
  `-- --mutant=arrival_guard` after `--script tests/section_transition_test.gd`.
  Mutation resources are compiled in memory; the production checkout is untouched.
- `flow-01-feedback2-godot-suite.log`: full Godot attempt exits 124,
  `error: command timed out after 900 seconds.` It passed serial child suites
  through `en03_enemies_test`; no failed assertion or script failure was
  reported before timeout. This is **not a full-suite PASS**, and falls under
  the director's explicit budget-timeout exception.
- `flow-01-feedback2-dragon-rewards.log`: exit 1 at the unchanged baseline
  `tests/dragon_rewards_test.gd:159` assertion,
  `ERROR: Final Continue transfers the claim to the profile before clearing the run`.
- `git diff --check`: clean. All feedback 2 changes remain uncommitted.

Feedback 1 focused results (earlier implementation round):

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

Feedback 2 modifies `scripts/run_scene.gd`, `scripts/section_transition.gd`,
`scripts/start_room_map_flow.gd`, `spec/analytics.md`, `spec/section_map.md`,
`tests/section_map_review_probe.gd`, `tests/section_transition_probe.gd`,
`tests/section_transition_test.gd`, `tests/suites/section_transition_suite.gd`,
`tests/proof_contracts/section_transition.json`, this handoff and
`tools/demo_clips/section_transition.gd` / `.py`. It adds
`scripts/section_transition_reward.gd`,
`tests/helpers/section_transition_observer.gd`,
`tests/helpers/section_transition_mutations.gd` and
`tests/proof_contracts/section_map_review.json`.
Feedback 2 left the clip-tool assertions unchanged; feedback 3 updates only
the authored transition duration, completion event and required capture samples.
The existing dragon-reward assertions remain unchanged.

- Runtime: `scripts/run_scene.gd`, `scripts/section_map_panel.gd`,
  `scripts/start_room_map_flow.gd`, new `scripts/section_transition.gd`.
- Analytics contract: `spec/analytics.md`.
- Tests and proof: `tests/helpers/program_sub_suites.gd`,
  `tests/section_transition_test.gd`, `tests/suites/section_transition_suite.gd`,
  `tests/section_transition_probe.gd`, `tests/proof_contracts/section_transition.json`,
  `tests/test_section_transition_clip.py`, this `tests/section_transition_proof.md`.
- Demo extension: `tools/demo_clips/section_transition.gd`, `.json`, `.py`, `.tscn`.


Feedback 3 changes (relative to `f1e041f29`, all uncommitted):

- Runtime: `scripts/section_transition.gd`, `scripts/start_room_map_flow.gd`,
  `scripts/section_map_panel.gd` (shared existing tint and backdrop accessor only).
- Behavior/proof: `tests/suites/section_transition_suite.gd`,
  `tests/helpers/section_transition_mutations.gd`,
  `tests/section_transition_probe.gd`, `tests/section_map_review_probe.gd`,
  `tests/proof_contracts/section_transition.json`,
  `tests/test_section_transition_clip.py`, and this handoff.
- Demo: `tools/demo_clips/section_transition.gd`,
  `tools/demo_clips/section_transition.py`.
- Owning specification: `spec/section_map.md`.

Feedback 3 left the prior owner capture directories, approved assets, protected
demo manifests, `run_scene.gd`, existing dragon-reward assertions, analytics
schema and task queue unchanged in that round. New invisible defaults are the frame
sampling/tolerances listed above; the narrated non-map fixture reuses the
existing Emaciated Man identity. No new design placeholder was introduced.


Feedback 4 changes (relative to `63c1f11ba`, all uncommitted):
`scripts/section_transition_reward.gd`, `scripts/run_scene.gd` (dragon-reward
stack and one scoped conditional-array cleanup), `spec/analytics.md`, `tests/suites/section_transition_suite.gd`,
`tests/section_transition_probe.gd`, and this handoff. No array declaration initializers,
map-generation code, assets, protected data, task metadata or assertions of
existing failures were changed. No new design TODO remains from this round;
the pre-existing section-start narration TODO is unchanged.
