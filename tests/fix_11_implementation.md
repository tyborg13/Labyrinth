# fix-11 implementation handoff

Changes are uncommitted on `codex/fix-11`. The design owner owns committing,
peer review, inspection fixtures, capture judgment and publication. No commits,
branch changes, pushes, windowed runs, art generation or protected design-data edits were
performed by this worker.

## Feedback 3 — resolver-owned row forecast and ended-state guard coverage

Both adopted final-round findings are implemented. This round changes only
`scripts/enemy_mechanics/tether_view.gd`,
`tests/suites/fix_11_activation_suite.gd`,
`tests/helpers/fix_11_callout_clock_suite.gd`, `tests/fix_11_mutations.py`
and this handoff. The Feedback 2 preparation/plan-only row path below is
superseded by the complete activation forecast.

1. **Forecast the real activation.** The row deep-copies the board and supplied
   intent, calls `resolve_enemy_turn_with_steps`, and reads the resulting
   Tether step's `no_action_reason`. This runs the actual activation preparation,
   movement allowance, arrival effects, final revalidation and reason function.
   The row exposes that reason only if the existing playback decorator exposes
   it, preserving concealed-mover and final-anchor visibility. No trap details
   or forecast state are published back to the board. The existing bounded
   `CombatPreviewMemo` caches by complete state, actor index, supplied intent and
   engine script; exact owned input snapshots detect in-place state changes.
   Tests count resolver invocations to prove reuse across unchanged redraws
   and invalidation on partner, trap and status edits.

   Both review cases commit `(2,1)` to `(2,4)` and then add an Earth trap at
   `(2,2)`. With a wall at `(3,4)`, the actual endpoint is `(2,3)` and both row
   and playback say `Not in line`. With the partner moved to `(6,3)`, the beam
   fires from `(2,3)` and neither emits a failure reason. Both run with and
   without commit snapshots. The existing partial-movement and lethal-arrival
   cases now assert the row as well. Complete input equality checks preserve
   trap visibility, RNG, held intent and all caller-owned state. A concealed
   moving Thrall has neither a public row nor playback reason.
2. **Already-ended animated state.** A native-clock test supplies an ended
   animated state while the scene's current combat remains live. It requires
   caller completion within one process frame, zero render calls, zero samples
   and zero remaining draw connections. The existing production guard already
   implements this behavior; this round adds effective coverage. The mutation
   that deletes this guard now fails that exact completion assertion. Test
   cleanup cancels a mutated coroutine before freeing its scene.

Focused commands for this round:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/fix_11_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/enemy_no_action_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/en03_enemies_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tests/test_fix_11_labels.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tests/fix_11_mutations.py --task-id fix-11 --output-dir /private/tmp/labyrinth_codex/fix-11-feedback3-mutations
```

Observed focused results (all exit 0):

```text
FIX-11 TEST RESULT: PASS (162 checks, 0 failures)
ENEMY NO ACTION TEST RESULT: PASS (1032 assertions; 0 failures)
EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)
Ran 2 tests in 0.061s
OK
```

The deterministic clock still observes reason frames `66/66/69` for
steady/stalled/hidden draws, and Redirected frames `54/54/57`. Focused logs are
`/private/tmp/labyrinth_codex/fix-11-feedback3-{focused,no-action,en03,labels}.log`.

The mutation runner now repeats all eleven re-review mutations plus the new
preview-only forecast mutation. Each is caught by its intended assertion,
returns exit 1 with no `SCRIPT ERROR`, and restores source bytes in `finally`.
The individual suite lines are:

```text
FIX-11 MUTATION dead_row_guard: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 1 failures)
FIX-11 MUTATION dead_step_guard: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 3 failures)
FIX-11 MUTATION post_align_revalidation: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 5 failures)
FIX-11 MUTATION cancelled_resolution_filter: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 1 failures)
FIX-11 MUTATION early_no_draw_fallback: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 2 failures)
FIX-11 MUTATION lost_first_draw_timestamp: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 3 failures)
FIX-11 MUTATION lost_draw_cleanup: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 6 failures)
FIX-11 MUTATION lost_mode_cancellation: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 2 failures)
FIX-11 MUTATION ignore_initial_combat_outcome: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 3 failures)
FIX-11 MUTATION ignore_current_combat_outcome: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 2 failures)
FIX-11 MUTATION remove_delta_cap: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 1 failures)
FIX-11 MUTATION preview_only_row_forecast: CAUGHT; FIX-11 TEST RESULT: FAIL (162 checks, 11 failures)
FIX-11 MUTATION RESULT: 12/12 caught; all source files restored
```

The mutation table and individual logs are
`/private/tmp/labyrinth_codex/fix-11-feedback3-mutations/mutation-results.json`
and adjacent `<mutation>.log` files; aggregate output is
`/private/tmp/labyrinth_codex/fix-11-feedback3-mutations.log`.
The restored checkout was re-run with exit 0 and
`FIX-11 TEST RESULT: PASS (162 checks, 0 failures)`, recorded in
`/private/tmp/labyrinth_codex/fix-11-feedback3-restored.log`.
`git diff --check` passes. Headless runs retain the sandbox's existing macOS
certificate-store diagnostic; no GDScript error was observed.
No full suite, editor scan, peer review or windowed run was performed this round.
The director's exact windowed command and expected capture paths remain under
"Proof for the design owner" below.

## Feedback 2 — lifecycle, activation geometry and mutation coverage

All four adopted review findings are implemented. This round changes
`scripts/intent_callouts.gd`, `scripts/enemy_mechanics/tether.gd`,
`scripts/enemy_mechanics/tether_view.gd`, and extracts the existing step-cost
check into `scripts/combat_engine.gd`. Tests change in `tests/fix_11_test.gd`
and `tests/suites/fix_11_suite.gd`, with new focused helpers
`tests/helpers/fix_11_callout_clock_suite.gd` and
`tests/suites/fix_11_activation_suite.gd` plus their UID sidecars. The new
`tests/fix_11_mutations.py` reproduces the four requested guard mutations.

1. **Callout lifetime.** The hold begins at the first HUD draw or after exactly
   three process frames without a draw. At deterministic 60 fps, reasons return
   on frame 66 when drawn, frame 69 with no draw; Redirected returns on 54/57.
   A single three-second first-frame stall before drawing preserves all 66
   reason frames, including the complete opaque hold. The real hidden
   CombatBoard also finishes without being shown again. A detached board uses
   the same fallback. Scene removal, freeing, leaving combat mode, and a combat
   outcome during the callout all complete the caller without script errors.
   The tree is captured before waiting, validity is checked across every await,
   and connected draw signals are disconnected on every exit. Tests retain a
   draw owner after freeing its scene to verify that cleanup directly.
2. **Activation restrictions.** The intent row uses the resolver's actual
   `_resolve_enemy_start_of_turn` preparation on a private state, then passes its
   skip, Immobilize and Shock restrictions to the shared plan. The reviewer's
   committed `(2,2)` to `(2,4)` case with partner at `(6,2)` and Immobilize now
   has no geometric failure row and fires from `(2,2)`; playback reports only
   the prevented movement. Forecasts leave their input state unchanged.
3. **Movement allowance.** `_enemy_allowed_step_cost` is the single implementation
   of the resolver's existing flying cost, surface cost, first-step exception
   and remaining-allowance check. Both live movement and Tether's held-path
   preview call it. The reviewer's Rubble at `(2,2)` and `(2,3)` now predicts
   `(2,3)` and shows `Not in line`, matching resolution. Arrival effects still
   resolve live, followed by the existing post-align revalidation.
4. **Guard coverage.** A dead row must return before activation preparation;
   a counter at that engine boundary verifies the early guard. A lethal Fire
   trap mid-align must emit neither a reason field nor a callout for the dead
   actor. A zero-damage Earth trap paints new Rubble during a three-step align
   and stops movement at `(2,3)`, requiring post-align revalidation. A previously
   announced beam disabled by Shock after its partner disappears must emit only
   `Shocked`, never a phantom Redirected callout.

Only the requested focused checks and four mutation runs were executed:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/fix_11_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/enemy_no_action_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/en03_enemies_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tests/test_fix_11_labels.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tests/fix_11_mutations.py --task-id fix-11 --output-dir /private/tmp/labyrinth_codex/fix-11-feedback2-mutations
```

Observed focused results (all exit 0):

```text
FIX-11 TEST RESULT: PASS (133 checks, 0 failures)
ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)
EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)
Ran 2 tests in 0.058s
OK
```

The mutation runs intentionally fail the focused suite and count as caught only
when the intended assertion fails, the suite returns 1, and there is no script
error. Source bytes are restored in a `finally` block after every mutation:

```text
FIX-11 MUTATION dead_row_guard: CAUGHT; FIX-11 TEST RESULT: FAIL (133 checks, 1 failures)
FIX-11 MUTATION dead_step_guard: CAUGHT; FIX-11 TEST RESULT: FAIL (133 checks, 2 failures)
FIX-11 MUTATION post_align_revalidation: CAUGHT; FIX-11 TEST RESULT: FAIL (133 checks, 2 failures)
FIX-11 MUTATION cancelled_resolution_filter: CAUGHT; FIX-11 TEST RESULT: FAIL (133 checks, 1 failures)
FIX-11 MUTATION RESULT: 4/4 caught; all source files restored
```

Logs are `/private/tmp/labyrinth_codex/fix-11-feedback2-{focused,no-action,en03,labels}.log`.
Each mutation log and `mutation-results.json` are in
`/private/tmp/labyrinth_codex/fix-11-feedback2-mutations/`.
The restored checkout was re-run after all mutations and reported
`FIX-11 TEST RESULT: PASS (133 checks, 0 failures)` with exit 0, in
`/private/tmp/labyrinth_codex/fix-11-feedback2-restored.log`.
UID sidecars were generated with Godot ResourceUID through the task runner.
No editor scan, full suite, peer review, or windowed run was performed this
round. The director's windowed command below remains unchanged.

## Feedback 1 — committed-partner reason policy

The design owner's decision is implemented in the shared reason function:
committed beams diagnose only their committed partner, including `no_partner`
when that partner dies or disappears. Uncommitted beams retain nearest-distance,
then id selection. Neither targeting nor re-picking rules changed. The design
placeholder is removed.

This round changes only `scripts/enemy_mechanics/tether.gd`,
`tests/suites/fix_11_suite.gd`, `spec/analytics.md`, and this handoff.

Two constructed engine regressions cover the committed partner being pushed
out of line or dying while a second Thrall remains aligned and reachable. The
push uses the engine's real Push action. Each runs with and without commit
snapshots and verifies the resolver reason, exact intent-row token, and exact
playback callout text without a spurious Redirected callout. An additional
assertion covers a removed committed partner. Existing uncommitted nearest/id
checks remain.

Only the three requested focused programs ran this round:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/fix_11_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/en03_enemies_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/godot_task_runner.py --task-id fix-11 --stream -- godot --headless --path . --script tests/enemy_no_action_test.gd
```

Observed results, all exit 0:

```text
FIX-11 TEST RESULT: PASS (94 checks, 0 failures)
EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)
ENEMY NO ACTION TEST RESULT: PASS (1041 assertions; 0 failures)
```

Logs are `/private/tmp/labyrinth_codex/fix-11-feedback1-focused.log`,
`fix-11-feedback1-en03.log`, and `fix-11-feedback1-no-action.log`.
`git diff --check` passes. No full suite or windowed proof was run this round.
The director's capture command below is unchanged.

## Files changed

- `scripts/enemy_mechanics/tether.gd`: shared geometric failure reason, retained
  safe align path, post-move validation and additive step reason.
- `scripts/combat_engine.gd`: existing movement-allowance check extracted into
  one helper shared by live movement and Tether preview (feedback 2).
- `scripts/enemy_mechanics/tether_view.gd`: reason text tokens, Shock/death row
  suppression and removal of the retired cancellation banner.
- `scripts/guardian_combat_rules.gd`: only the empty-footprint label and reason
  on its animation step; internal `interrupted` stays available.
- `scripts/intent_callouts.gd`: two text entries without icons, the Tether
  snapshot for final-anchor decoration, and a first-draw presentation clock.
- `scripts/run_scene.gd`: additive recognition of cancelled Tether
  `lightning_strikes` steps in its existing playback adapter. Firing beams retain
  their existing dispatch and visuals.
- `spec/analytics.md`: the additive reason values and guardian behavior.
- `tests/suites/en03_enemies_suite.gd`: replaces only the intentionally retired
  Tether label expectation with its resolver reason.
- `tests/suites/fix_11_suite.gd`, `tests/fix_11_test.gd` and their UID sidecars:
  constructed-state, analytics, deterministic-clock and live-playback tests.
- `tests/fix_11_probe.gd`, its UID sidecar, `tests/fix_11_proof.json`: the two
  requested real-renderer captures and a headless contract mode.
- `tests/headless_test_programs.json`, `tests/test_fix_11_labels.py`: registration
  and repository-wide guards against the retired labels.
- `tests/helpers/fix_11_callout_clock_suite.gd`,
  `tests/suites/fix_11_activation_suite.gd`, their UID sidecars, and
  `tests/fix_11_mutations.py`: feedback 2 lifetime, geometry and guard coverage.
- This file: implementation and proof handoff.

## Numbered requirements / acceptance

1. **Tether resolver.** `failure_reason` diagnoses from the final plan anchor,
   using the committed partner when one exists. Only an uncommitted Tether
   chooses the nearest living partner by Manhattan distance, then id. It
   distinguishes no partner, neither shared axis, excessive length, and wall or
   terrain occlusion. The resolver validates again after the align move. Shock
   remains its sole reason; a Thrall dead before acting emits no callout.
   Feedback 1 resolves the valid-alternate-partner case against the committed
   partner: dead or gone is `no_partner`; displaced out of line is `not_aligned`.
2. **Tether presentation.** The intent row reads a cached real activation's
   reason step and the shared text table. The existing callout decoration defers feedback
   until the embedded move has completed. Decoration consumes `en03_after` so
   the callout uses the final anchor. Live scene playback tests check both a
   stationary failure and move-then-failure. Neither scripts nor banners retain
   `Cancelled`.
3. **Guardian.** Empty live footprints carry `no_line_of_sight`, retain the
   internal `interrupted` field and play the shared held callout. The old label
   is empty. Summon-blocked labels and footprint/rules code are unchanged.
4. **Clock.** The actual retained HUD draw signal acknowledges the first drawn
   frame, with a three-process-frame fallback if no draw occurs. Thereafter
   each unscaled frame delta is capped at the brief's 0.1 s.
   A HUD paint also completes the clock when an existing status step's actor
   has departed, avoiding a wait for text that cannot be drawn. No Fire/Bleed
   resolver or reason path is changed.
   Integer microseconds avoid accumulating floating-point error at exact frame
   boundaries. Hold/fade curves, reduced motion, the 1.1 s reason duration and
   0.9 s Redirected duration remain unchanged. At 60 fps the next actor returns
   on frames 66 and 54 respectively. A single three-second first-frame stall preserves all
   66/54 drawn frames. The parent playback method fails both stall regressions.
5. **Analytics.** Existing `enemy_action_resolved` extraction consumes the
   resolver's additive `no_action_reason` directly. Tests verify both new values,
   existing geometric values, empty losses, and the guardian legacy flag.

## Round 0 verification (historical)

Logs are under `/private/tmp/labyrinth_codex/fix-11-*.log`.

```text
FIX-11 TEST RESULT: PASS (73 checks, 0 failures)
FIX-11 PROBE CONTRACT: PASS (62 checks; 1920x1080, UI scale 100%)
EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)
ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)
THREATS AT REST TEST RESULT: PASS (612 assertions; includes compass suite)
ENEMY INTENT CONTINUITY TEST RESULT: PASS (1882 checks, 0 failures)
FIX-11 CLOCK: reason=true stalled=false drawn_frames=66 next_actor_frame=66
FIX-11 CLOCK: reason=true stalled=true drawn_frames=66 next_actor_frame=70
FIX-11 CLOCK: reason=false stalled=false drawn_frames=54 next_actor_frame=54
FIX-11 CLOCK: reason=false stalled=true drawn_frames=54 next_actor_frame=58
```

The parent-clock mutation run intentionally reports:

```text
FIX-11 CLOCK: reason=true stalled=true drawn_frames=0 next_actor_frame=1
FIX-11 CLOCK: reason=false stalled=true drawn_frames=0 next_actor_frame=1
FIX-11 TEST RESULT: FAIL (73 checks, 2 failures)
FIX-11 PARENT CLOCK EXPECTED FAILURE EXIT: 1
```

This restores only HEAD's original `play` method in an in-memory test script;
it does not edit production files. The two failures are the stall cases.

Python checks observed `OK`: UI identity lint (25 tests), retired labels (2
tests), Godot sidecars (19 tests), icon identity policy (8 tests). The production scan reports
`PASS: UI identity lint (1594 sites within baseline + exceptions)`.
Registration reports `TEST REGISTRATION AUDIT: PASS (822 scripts; full suite=468,
quarantined=29, windowed probe=325)`. `git diff --check` passes.

The complete Godot suite completed with its documented 900 s cap:

```text
MAIN BODY RUNTIME: 286.188 seconds
MAIN BODY ASSERTIONS: 495455
PROGRAM SUITE fix_11_test: PASS
PROGRAM SUITE fix_11_probe: PASS
FULL SUITE RUNTIME: 615.077 seconds (budget 900 seconds)
TEST RESULT: FAIL (1 failure(s))
```

208 of 209 isolated programs passed. The sole failing child was the unchanged
`special_encounter_test`, whose two assertions report:

```text
Approved emblem imports load through Godot’s real resource loader
Director-staged emblem sidecars load through Godot’s real resource loader
SPX special encounter suite: 2 failures
```

Its resource errors include the missing imported `last_light` emblem `.ctex`.
These are the same missing-import assertions documented in
`tests/fb_01_implementation.md`; neither the assertions nor their assets were
changed. The complete log is
`/private/tmp/labyrinth_codex/fix-11-full-godot.log`.

All Godot invocations use `python3 tools/godot_task_runner.py --task-id fix-11
--stream -- godot --headless --path . --script <script>`. Scripts executed:

- `tests/fix_11_test.gd`
- `tests/fix_11_probe.gd -- --check-only`
- `tests/en03_enemies_test.gd`
- `tests/enemy_no_action_test.gd`
- `tests/threats_at_rest_test.gd`
- `tests/enemy_intent_continuity_test.gd`
- `tests/run_tests.gd` (runner additionally uses `--timeout 900`)

The initial fb-01 run could not resolve the existing global `GameData` class in
the fresh worktree; it was stopped. Ignored `.godot` class/import caches were
copied from the local main checkout without changing tracked sources or assets.
No editor scan was used. Early complete-suite attempts were stopped during
implementation; only the final completed run below is claimed. Several runs print
the sandbox's macOS certificate-store diagnostic; headless EN03 also prints the
existing dummy-texture diagnostic. Some live tests print an ObjectDB leak
warning at shutdown. These are recorded in the logs, not asserted away.

## Proof for the design owner

No windowed command was attempted and no fresh PNGs were produced here, because
this sandbox has no macOS window-server access. Run exactly:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-11 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/fix_11_probe.gd --task-id fix-11 --expect-size 1920x1080 --proof-contract tests/fix_11_proof.json --result-manifest /private/tmp/labyrinth_codex/fix-11-visual-proof.json
```

The probe observes the real HUD draw and captures production playback 0.4 s
into the opaque hold. It asserts exact text, no icon, opacity, actor wait,
HUD clearance, 1920x1080 and 100% UI scale. The runner prints the absolute
isolated `user://probes/fix-11/` directory and validates:

- `no_partner_1920x1080.png`
- `not_aligned_1920x1080.png`

The director judges these images. No worker inspection-fixture command was
requested; fixture preparation is assigned to the design owner.

## TODO_DESIGN placeholders

None. Feedback 1 supplies the committed-partner reason policy; the placeholder
has been removed. Another Thrall that could link does not change the reason.

## Chosen defaults

Only constructed tests/proof and test scheduling have chosen values:

| Named fields/constants | Values |
| --- | --- |
| `ACTOR_TILE`, `PARTNER_TILE`, `MISALIGNED_TILE`, `WALL_TILE` | `(2,4)`, `(6,4)`, `(6,5)`, `(4,4)` |
| `ALIGN_START`, `ALIGN_END` | `(2,2)`, `(2,4)` |
| `RANGE_LIMIT_FOR_TEST`, `TERRAIN_TEST_HP` | `2`, `3` |
| `NEAR_PARTNER_ID`, `NEAR_PARTNER_TILE`, `TIED_PARTNER_TILE` | `4`, `(3,5)`, `(4,6)` |
| `ALTERNATE_PARTNER_TILE` | `(2,6)` |
| `PUSH_HERO_TILE`, test-only `push_action` | `(6,3)`; type `push`, range `1`, damage `0`, amount `1` |
| `GUARDIAN_ID`, `GUARDIAN_CYCLE_SLOT`, `GUARDIAN_TILE` | `ashen_reaver`, `1`, `(1,1)` |
| Fixture source fields | Existing EN03 `TEST_SEED=41027`, `TEST_HERO_HP=30`, 9×9 grid, ids 1/2 and approved Tether/Arc Jab; guardian suite's seed 92; no content changes |
| `STEP_SECONDS`, `FIRST_FRAME_STALL_SECONDS`, `FIRST_DRAW_SUBMISSION` | `1/60`, `3.0`, `5` |
| `SETTLE_FRAMES`, `PLAYBACK_TIMEOUT_SECONDS`, `HOLD_SAMPLE_END_SECONDS` | `8`, `6.0`, `0.75` |
| Proof inherited scheduling fields | `SETTLE_FRAMES=8`, `MID_HOLD_SECONDS=0.4`, `PLAYBACK_TIMEOUT_SECONDS=6.0`, `AUDIO_DRAIN_SECONDS=0.1`; existing fb-01 bootstrap seed 126065 |
| `FIX11_OUTPUT_DIR` | `user://probes/fix-11` |
| Feedback 2 lifecycle test fields | `PLAYBACK_TIMEOUT_SECONDS=3.0`, `LIFECYCLE_WAIT_FRAMES=4`; deterministic draw flags in the test-only PlaybackScene |
| Feedback 2 partial-movement fields | `PARTIAL_START=(2,1)`, `PARTIAL_TRAP_TILE=(2,2)`, actual stop `(2,3)`; Earth trap damage `0`; Fire trap damage equals fixture actor HP |
| Feedback 2 mutation runner fields | `timeout=180` seconds, `WRAPPER_CLEANUP_SECONDS=10` |
| Feedback 3 test fixture fields | Review-specified `TRAP_WALL_TILE=(3,4)`, `TRAP_RELOCATED_PARTNER=(6,3)`, `TRAP_TEST_DAMAGE=1`; test-only `HIDDEN_HERO_TILE=(7,7)` |
| Feedback 3 test counters | `render_calls=0`, `turn_calls=0`; one-frame completion bound is specified by the design owner |

The 1920x1080 viewport, 100% UI scale, 0.1 s cap, 0.8 s hold and 0.3 s fade
are specified values, not newly chosen production defaults.

## Open issues / intentionally untouched paths

- Director renderer capture/judgment and the owner's later workflow steps remain.
- Fire/Bleed deaths, unmet surface requirements, special/held attacks with an
  unusable aim, and non-attack no-ops retain existing behavior outside this unit.
- The full suite retains the existing special-encounter emblem-import failure
  above. No unrelated assertion or protected asset was changed.
