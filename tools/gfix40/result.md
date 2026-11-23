# gfix-40 Burst teardown proof

Candidate 7 base: `codex/mrg-18`, `647b49092cd1464d5c6339b9808b05973f62a4f4`. The same probe ran on that HEAD before production edits and again with the uncommitted fix. Logs include Godot `--verbose` exit diagnostics.

## 1. Root causes and fixes

| Exact baseline script error | Baseline source and cause | Fix |
| --- | --- | --- |
| `Attempt to call function 'null::_set_ember_reward_display_count (Callable)' on a null instance.` | [ember_reward_feedback.gd:31](../../scripts/ember_reward_feedback.gd#L31). The Ember roll was awaiting the global SceneTree frame signal. It woke after the RunScene had released the callable target. | Roll frames come from CombatPacing. Its exit hook disconnects the SceneTree relay and discards pending consumers. The pulse keeps its existing node-bound tween and releases the local Tween reference before awaiting its signal. |
| `Invalid access to property or key '_combat_pacing' on a base object of type 'previously freed'.` | [combat_playback_samples.gd:11](../../scripts/combat_playback_samples.gd#L11) on the base. An outstanding global frame wait resumed the sample loop after the RunScene was freed. The same wait also resumed playback while the native title transition held the RunScene detached. | The sampler submits through CombatPacing's owned frame relay. Disconnecting the pending frame releases the sampler, its render callback and its completion callback. |
| `Invalid call. Nonexistent function '_record_runtime_animation_clock' in base 'previously freed'.` | [maquette_cutout_runtime/death_sequence.gd:87](../../scripts/maquette_cutout_runtime/death_sequence.gd#L87) on the base. The telemetry continuation awaited the sampler and resumed after its failed call. | Clock recording is the sampler's completion callback. It runs on normal completion, including the existing final required draw boundary. |
| `Cannot call method 'get_stretch_transform' on a null value.` | [board_pixel_surface_layer.gd:141](../../scripts/board_pixel_surface_layer.gd#L141). During [CombatHitStop exit](../../scripts/combat_hit_stop.gd#L74), cancelling an active stop emitted `stop_ended`. CombatPacing's pending flash redrew the board after the sheet lost its viewport. | CombatHitStop restores the engine time scale during exit without emitting presentation signals. Live stop expiry and explicit live cancellations keep their signal behavior. |
| `Cannot call method 'get_stretch_transform' on a null value.` | [board_pixel_surface_layer.gd:126](../../scripts/board_pixel_surface_layer.gd#L126). The same redraw continued into contact synchronization after the board lost its viewport. | The same hit-stop exit cancellation removes the source of this redraw. |

The title paths also exposed downstream awaits and HUD work after the old run detached. Cancelling the sampler prevents that cascade. The parallel Ember reward wait and Turn Clock dissolve/reflow use the same owner-controlled frame signal. The dissolve effect owns its portrait texture and the pending rail samples borrow its object ID. Each normal sample uses the same origin, due-frame calculation, required contacts, hold and frame phase.

### Changed lines in the working tree

| File | Lines and purpose |
| --- | --- |
| [scripts/combat_pacing.gd](../../scripts/combat_pacing.gd) | 4–5, 122–130, 344–350. Demand-driven playback frame relay and exit cancellation. |
| [scripts/combat_playback_samples.gd](../../scripts/combat_playback_samples.gd) | 6–58. Cancellable sampling and completion with the existing schedule. |
| [scripts/maquette_cutout_runtime/death_sequence.gd](../../scripts/maquette_cutout_runtime/death_sequence.gd) | 62, 83, 86–88. Clock and render callbacks for the sampler. |
| [scripts/ember_reward_feedback.gd](../../scripts/ember_reward_feedback.gd) | 11, 35, 39–41. Owned frame wait and pulse signal reference. |
| [scripts/combat_hit_stop.gd](../../scripts/combat_hit_stop.gd) | 54, 56, 63–64, 68, 74–76. Scale restoration and presentation notification control. |
| [scripts/run_scene.gd](../../scripts/run_scene.gd) | 12497–12498, 12525, 12529, 12556, 12706, 22599, 22687–22688. Borrowed dissolve portraits and owned playback waits. |
| [scripts/combat_engine.gd](../../scripts/combat_engine.gd) | No changed lines. |
| [tests/suites/ember_reward_feedback_suite.gd](../../tests/suites/ember_reward_feedback_suite.gd#L91) | 91–92. Test-owned Ember frame wait. |
| [tools/gfix40/departure.gd](departure.gd) | QA-133 seed and checkpoint replay with retained-stamp and in-game variants, built on the QA-131 input and fixture helpers. |

## 2. Before and after by path

The QA application replay requests the RunScene's application-departure preparation, frees the old viewport and opens a fresh scene from disk. The retained-stamp case separately targets the exact redraw boundary. It started a production hit stop and pending flash through CombatPacing because the natural stop had expired at the sampled stamp.

In this build the pause icon and Escape gate on animation lock. The probe verifies the pause icon gate, opens the existing overlay through the fixture, and emits the real **Save and Quit** or **Succumb to the Darkness** button signal. The title transition is processed by the production scene-change helper. Victory and defeat use the production card input and play through the terminal transition. The first Tick's Burst is lethal to the 1-Health hero in the defeat variant, and the second contact still plays.

| Path | Baseline script errors | Patched script errors | Exact patched check summary |
| --- | ---: | ---: | --- |
| Application departure and resume | 3 | 0 | `GFIX40 application: 11 checks, 0 failures` |
| Retained stamp with active hit stop | 5 | 0 | `GFIX40 retained_stamp: 9 checks, 0 failures` |
| Save and Quit to Main Menu | 26 | 0 | `GFIX40 main_menu: 9 checks, 0 failures` |
| Abandon run | 27 | 0 | `GFIX40 abandon: 9 checks, 0 failures` |
| Last kill on second Burst, Victory | 0 | 0 | `GFIX40 victory: 9 checks, 0 failures` |
| Hero dies on first Burst, Defeat | 0 | 0 | `GFIX40 defeat: 9 checks, 0 failures` |

Baseline Abandon reported `GFIX40 abandon: 9 checks, 1 failures` and `has_save:true`. Its detached card continuation could still run checkpoint code after Abandon cleared the save. The patched Abandon reached the title with `has_save:false`; Save and Quit reached it with `has_save:true`. Victory and defeat both recorded `"contacts":[1,2]` on baseline and patched runs. The final modes were `reward` and `defeat`, respectively.

The application replay matched the committed, saved and resumed economy. Candidate 7 granted one Card Play for the direct kill, charged 10 total Time and scheduled the next activation at ETA 24. The journal held one card play, one activation end and one death entry each for actors 1, 2 and 3. These are candidate 7's observed values. QA-133's playtest 25 used three grants and ETA 9.

### Baseline script error census

Victory and defeat emitted no script errors. The following census gives the exact error lines and their baseline call sites for the four interrupted cases. The patched count is zero for every row.

| Exact error line | Exact call site | App | Stamp | Main Menu | Abandon |
| --- | --- | ---: | ---: | ---: | ---: |
| `SCRIPT ERROR: Attempt to call function 'null::_set_ember_reward_display_count (Callable)' on a null instance.` | `at: play (res://scripts/ember_reward_feedback.gd:31)` | 1 | 1 | 0 | 0 |
| `SCRIPT ERROR: Invalid access to property or key '_combat_pacing' on a base object of type 'previously freed'.` | `at: play (res://scripts/combat_playback_samples.gd:11)` | 1 | 1 | 0 | 0 |
| `SCRIPT ERROR: Invalid call. Nonexistent function '_record_runtime_animation_clock' in base 'previously freed'.` | `at: play (res://scripts/maquette_cutout_runtime/death_sequence.gd:87)` | 1 | 1 | 0 | 0 |
| `SCRIPT ERROR: Cannot call method 'get_stretch_transform' on a null value.` | `at: _sync_sheet_size (res://scripts/board_pixel_surface_layer.gd:141)` | 0 | 1 | 4 | 4 |
| `SCRIPT ERROR: Cannot call method 'get_stretch_transform' on a null value.` | `at: sync_contacts (res://scripts/board_pixel_surface_layer.gd:126)` | 0 | 1 | 4 | 4 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: play (res://scripts/combat_playback_samples.gd:28)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Cannot call method 'create_timer' on a null value.` | `at: _animate_defeats_and_terrain_destruction (res://scripts/run_scene.gd:23077)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _animate_turn_order_alongside_defeats (res://scripts/run_scene.gd:12832)` | 0 | 0 | 2 | 2 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _animate_player_action_step (res://scripts/run_scene.gd:24141)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Cannot call method 'create_timer' on a null value.` | `at: _animate_player_card_resolution (res://scripts/run_scene.gd:23331)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Attempt to call function 'empower_glyph_label' in base 'null instance' on a null instance.` | `at: seal_hint (res://scripts/card_empower_controller.gd:66)` | 0 | 0 | 4 | 4 |
| `SCRIPT ERROR: Cannot call method 'get_stretch_transform' on a null value.` | `at: prepare (res://scripts/acquisition_burst.gd:131)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'content_scale_factor' on a base object of type 'null instance'.` | `at: _combat_objective_hud_target_rect (res://scripts/run_scene.gd:11472)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'content_scale_factor' on a base object of type 'null instance'.` | `at: _environment_for (res://scripts/combat_hud_layout.gd:128)` | 0 | 0 | 2 | 2 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _animate_turn_order_shadow_dissolves (res://scripts/run_scene.gd:12556)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _animate_turn_order_transition (res://scripts/run_scene.gd:12706)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _warm_pile_dialog_card_pool (res://scripts/run_scene.gd:29597)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _fit_current_hand_layout_to_visible_width (res://scripts/run_scene.gd:16655)` | 0 | 0 | 1 | 1 |
| `SCRIPT ERROR: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.` | `at: _animate_death_rewards (res://scripts/run_scene.gd:22599)` | 0 | 0 | 0 | 1 |

## 3. Exit diagnostics

The ObjectDB entries are the instance types printed by `--verbose`. The RID and named resource columns record the other QA-133 exit signatures. A dash means the corresponding marker did not appear.

| Path | ObjectDB before | ObjectDB after | RID and resources before | RID and resources after |
| --- | --- | --- | --- | --- |
| Application | 9 GDScriptFunctionState, 2 ImageTexture, 2 Image | 9 GDScriptFunctionState, 1 Tween | 2 dummy texture RIDs | — |
| Retained stamp | 8 GDScriptFunctionState, 2 Tween, 1 SceneTreeTimer | 8 GDScriptFunctionState, 3 Tween, 1 SceneTreeTimer | — | — |
| Main Menu | 3 GDScriptFunctionState, 1 Tween, 1 RefCounted, 2 GDScript, 1 GDScriptNativeClass | 9 GDScriptFunctionState | 2 resources, `board_plate_visibility.gd` and `turn_order_slots.gd` | — |
| Abandon | 1 GDScriptFunctionState, 2 Tween, 1 RefCounted, 2 GDScript, 1 GDScriptNativeClass | 8 GDScriptFunctionState, 2 Tween | 2 resources, `board_plate_visibility.gd` and `turn_order_slots.gd` | — |
| Victory | 2 FontFile, 122 Image, 58 ImageTexture, 56 TextLine, 1 GDScriptFunctionState, 2 WeakRef | Same | 58 dummy texture, 56 shaped text, 2 font, 6 linked-font variation RIDs. 2 resources, `LabyrinthCrumble-UI.tres` and `LabyrinthCrumble-Display.tres` | Same |
| Defeat | — | — | — | — |

The four interrupted paths and Victory still print `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` Victory also retains its baseline font resources and RIDs. The baseline macOS sandbox CA certificate error appears on both builds.

## Tests and probe logs

| Probe | Baseline log | Patched log |
| --- | --- | --- |
| App close and resume | [application.log](/private/tmp/labyrinth_codex/gfix-40/baseline/application.log:734) | [application.log](/private/tmp/labyrinth_codex/gfix-40/after/application.log:734) |
| Retained stamp | [retained_stamp.log](/private/tmp/labyrinth_codex/gfix-40/baseline/retained_stamp.log:734) | [retained_stamp.log](/private/tmp/labyrinth_codex/gfix-40/after/retained_stamp.log:734) |
| Main Menu | [main_menu.log](/private/tmp/labyrinth_codex/gfix-40/baseline/main_menu.log:734) | [main_menu.log](/private/tmp/labyrinth_codex/gfix-40/after/main_menu.log:734) |
| Abandon | [abandon.log](/private/tmp/labyrinth_codex/gfix-40/baseline/abandon.log:734) | [abandon.log](/private/tmp/labyrinth_codex/gfix-40/after/abandon.log:734) |
| Victory | [victory.log](/private/tmp/labyrinth_codex/gfix-40/baseline/victory.log:734) | [victory.log](/private/tmp/labyrinth_codex/gfix-40/after/victory.log:734) |
| Defeat | [defeat.log](/private/tmp/labyrinth_codex/gfix-40/baseline/defeat.log:734) | [defeat.log](/private/tmp/labyrinth_codex/gfix-40/after/defeat.log:734) |

- `python3 tests/test_ui_identity_lint.py` reported `Ran 25 tests in 6.294s` and `OK`.
- `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/gfix-40/python-default` reported `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 36.638s` and `OK`. This includes `PASS: Rules text lint (16 existing hits)`. The runner could not update its Git timing cache under the read-only Git metadata. It wrote the test results to the requested output directory. [Suite log](/private/tmp/labyrinth_codex/gfix-40/python-default/suite.log) · [Summary](/private/tmp/labyrinth_codex/gfix-40/python-default/summary.json)
- All six patched Godot invocations returned 0. Baseline return codes were 1 on the four interrupted paths and 0 on Victory and Defeat. Full Godot and Python suites were outside the proof scope.

## Proof for the design owner

No native capture is needed for this teardown change. The proof is the headless logs and persisted fixture data. To rerun on the reconciled import cache, use a fresh proof directory.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-40 && \
  export LABYRINTH_CEL_LOOK=all LABYRINTH_GFIX40_OUT="$(mktemp -d /private/tmp/labyrinth_codex/gfix-40/proof.XXXXXX)"
for case_name in application retained_stamp main_menu abandon victory defeat; do
  python3 tools/godot_task_runner.py --task-id gfix-40 --stream -- godot \
    --headless --verbose --path . --fixed-fps 60 --script tools/gfix40/departure.gd -- "$case_name" \
    > "$LABYRINTH_GFIX40_OUT/$case_name.log" 2>&1
  printf '%s\n' "$?" > "$LABYRINTH_GFIX40_OUT/$case_name.status"
done
```

The initial worktree cache lacked 96 existing imported artifacts. The matched before and after runs use the copies from the exact baseline's cache in the current worktree's ignored `.godot/imported` directory.

## Chosen defaults

The replay reuses QA seed 131011, 1920×1080, 100% UI scale, normal motion, fastest combat, 60 fixed FPS, a 12-second fixture watchdog and the original targets. The interrupt variants keep the 30-Health Crawler outside the Burst cross. The Victory variant omits that survivor. The Defeat variant starts the hero at 1 Health. The retained-stamp variant uses the fixture-only hit identity `gfix40_exit` with the first Burst's damage and the kill hit-stop profile.

## Open issues

The remaining ObjectDB warnings and Victory resource retention are recorded above. The read-only Git timing cache warning did not affect test results. No design placeholders were needed. All changes are uncommitted.

## Callers

Round 1 audited the GDScript calls, inherited methods, and script adapters in `scripts/`, `tests/`, and active `tools/`. The Ember suite now supplies its fixture's own frame signal.

| Changed signature | Caller | Disposition |
| --- | --- | --- |
| `EmberRewardFeedback.play(..., update_count, next_frame)` | [RunScene Ember reward](../../scripts/run_scene.gd#L22679) | Supplies CombatPacing's owned frame relay. |
| `EmberRewardFeedback.play(..., update_count, next_frame)` | [Ember reward feedback suite](../../tests/suites/ember_reward_feedback_suite.gd#L83) | Supplies a callable returning the fixture's `SceneTree.process_frame`. The suite is preloaded by `snare_ui_test.gd` and `run_tests.gd`. |
| `CombatPlaybackSamples.new(schedule, hold_end_usec, required, render, record).play(pacing) -> Variant` | [DeathSequence](../../scripts/maquette_cutout_runtime/death_sequence.gd#L88) | Uses the instance sampler with the render and telemetry callbacks. This is the sole caller of the sampler. |
| `DeathSequence.play(scene, clock, render) -> Variant` | [RunScene death playback](../../scripts/run_scene.gd#L23084) | The existing `await` handles its completion signal or immediate return. The BRS01 fixture delegates through the unchanged RunScene method. |
| `DeathSequence.play(scene, clock, render) -> Variant` | [RR46 fixture](../../tests/rr46/death_clock_scene.gd#L17) | The existing `await` handles the same return contract. The runnable `death_clocks.gd` probe exercises it. |
| `CombatHitStop.cancel(notify: bool = true)` | [CombatHitStop exit hook](../../scripts/combat_hit_stop.gd#L76) | Passes `false` for silent exit. |
| `CombatHitStop.cancel(notify: bool = true)` | [CombatPacing scale restoration](../../scripts/combat_pacing.gd#L276), [CombatPacing process](../../scripts/combat_pacing.gd#L322) | Default `true` preserves live notifications. |
| `CombatHitStop.cancel(notify: bool = true)` | [Combat feel suite](../../tests/suites/combat_feel_suite.gd#L296) at lines 296, 419, and 449, [enemy action clock suite](../../tests/suites/combat_enemy_action_clock_suite.gd#L75), [enemy hurry test](../../tests/enemy_hurry_test.gd#L101), [gfix40 stamp probe](departure.gd#L136) | Default `true` preserves live notifications in every fixture. |
| `CombatHitStop._restore(notify: bool = true)` | [CombatHitStop.poll](../../scripts/combat_hit_stop.gd#L52), [CombatHitStop.cancel](../../scripts/combat_hit_stop.gd#L56) | Poll uses the live default. Cancel forwards the caller's preference. |

The hit-stop timing adapters in `tests/helpers/presentation_test_clock.gd` and `tools/demo_clips/instrument.gd` preserve the production cancellation functions when substituting the clock. `tools/fx15/native_capture.gd` inherits cancellation from CombatHitStop. Ember event playback uses the existing Ember roll and tween helpers directly.

### Round 1 matched headless checks

The baseline used the candidate 7 project at `647b49092cd1464d5c6339b9808b05973f62a4f4`. All checks ran through `python3 tools/godot_task_runner.py --task-id gfix-40 --stream -- godot --headless` with `LABYRINTH_CEL_LOOK=all`. The RR46 scene is a test fixture, so its SceneTree entry point is `tests/rr46/death_clocks.gd`. For `run_tests.gd`, the parse harness uses the same `load` and `can_instantiate` pattern as `tools/rd07/parse_check.gd`. It compiles the suite and its preloads without executing the suite or triggering the full-suite import preamble. [Parse harness](/private/tmp/labyrinth_codex/gfix-40/round-1/parse_run_tests.gd)

| Check | Before | After | Exact result on both |
| --- | --- | --- | --- |
| `tests/snare_ui_test.gd` | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/before/snare_ui.log) | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/after/snare_ui.log) | `Snare UI/fixture suite: 0 failures` |
| `tests/snare_ui_test.gd -- --ember-feedback` | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/before/snare_ui_ember.log) | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/after/snare_ui_ember.log) | `Ember reward feedback suite: 0 failures` and `Snare UI/fixture suite: 0 failures` |
| `tests/brs01_test.gd` | [Exit 124](/private/tmp/labyrinth_codex/gfix-40/round-1/before/brs01.log) | [Exit 124](/private/tmp/labyrinth_codex/gfix-40/round-1/after/brs01.log) | `SCRIPT ERROR: Parse Error: Cannot find member "FORCE_TILE_GLOW_ALPHA" in base "CombatBoardView".` at `tests/helpers/brs01_feedback_cases.gd:24`, then `error: command timed out after 30 seconds.` |
| `tests/rr46/death_clocks.gd` | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/before/rr46_death_clocks.log) | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/after/rr46_death_clocks.log) | `RR46 MIXED DEATH CLOCKS: PASS (12 blocking/overlap cases; three speeds; 12 authored event crossings)` |
| `tests/run_tests.gd` compile check | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/before/run_tests_parse.log) | [Exit 0](/private/tmp/labyrinth_codex/gfix-40/round-1/after/run_tests_parse.log) | `RUN_TESTS PARSE: PASS` |
| `tests/combat_feel_test.gd` | [Exit 1](/private/tmp/labyrinth_codex/gfix-40/round-1/before/combat_feel_writable.log) | [Exit 1](/private/tmp/labyrinth_codex/gfix-40/round-1/after/combat_feel.log) | `FLOATING COMBAT TEXT TEST RESULT: FAIL` and `COMBAT FEEL TEST RESULT: FAIL`. Matching 30 script errors and one assertion failure. |

Both combat-feel logs contain 29 instances of `SCRIPT ERROR: Invalid call. Nonexistent 'bool' constructor.` in `_refresh_overlays`. They each also contain one `enemy_fire_start_losses` argument type error in `overlap_surface` and the assertion `ERROR: Surface lifetime fixture starts actual overlapping feedback`. BRS01 and combat feel were left for their owning fixes.

The direct baseline combat-feel run hit an additional proof-contract write error because it ran against the read-only sibling worktree. The matched baseline run used the same project sources and import cache from a temporary project with its own writable `output/`. It wrote the proof contract successfully. [Direct baseline log](/private/tmp/labyrinth_codex/gfix-40/round-1/before/combat_feel.log) · [Baseline proof contract](/private/tmp/labyrinth_codex/gfix-40/round-1/base-project/output/feel-01/proof-contract.json)

Round 1 changed the test caller and this report. The accepted production implementation and signatures stayed as submitted. `git diff --check` passed, and the working tree remains uncommitted.
