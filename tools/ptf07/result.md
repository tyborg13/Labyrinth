# ptf-07 implementation result

The original implementation was committed by the design owner as `ff7edc160`. Feedback 2 changes remain uncommitted on `codex/ptf-07`.
No branch, queue, publication, review or inspection-fixture operations were performed.

## Combined trial failure attribution (branch head 9f0829fb4)

The recreated ptf-07 worktree was clean at `9f0829fb4` before this round. All ten programs named in the request were run on this branch alone. The enemy-tooltip main-suite failures were tested by extracting the unchanged `enemy_intent_continuity_suite.gd` into `tools/ptf07/enemy_intent_continuity_check.gd`; the main/full suite was not started.

“Fails on ptf-07” below means before this round's fixes. A “No” does not assign another unit's root cause; it means that combined-trial failure did not reproduce on isolated ptf-07.

| Program | Fails on ptf-07 | Cause / combined-log evidence | Fix on ptf-07 |
|---|---|---|---|
| `warband_test` | No | Branch: `Warband suite: 0 failures`. Combined log has revision-4/5 layout golden mismatches. | None. |
| `snare_test` | No | Branch: `Snare suite: 0 failures`. Combined log has pre-change layout golden mismatches. | None. |
| `save_resume_boundary_test` | No | Branch: `TEST RESULT: PASS — committed save/resume boundary matrix`. Combined assertion concerns retired vocabulary in repaired saves. | None; expected forced-persistence-error diagnostics remain untouched. |
| `departed_run_cleanup_test` | No | Branch result: 3 cases, `errors: []`, zero orphans. Combined error concerns preserving Save and Quit state. | None. |
| `event_feedback_test` | No | Branch: `Event feedback suite: 0 failures`. Combined log reports Label/TextureRect type mismatch and relic tooltip minimum width. | None. |
| `flurry_retirement_test` | No | Branch: `PASS (8914 checks, 0 failures)`. Combined log reports collectible equipment tooltip construction. | None. |
| `glossary_test` | No | Branch: `PASS (6513 checks, 0 failures)`. Combined log reports collectible equipment tooltip construction. | None. |
| `board_tile_tooltip_test` | No | Branch: `BOARD TILE TOOLTIPS: PASS checks=217 failures=0`. Combined log reports collectible equipment tooltip construction. | None. |
| `suites/full_scene_choices_program` | No | Branch: 772 assertions, `TEST RESULT: PASS`. Combined log reports campfire linger chip/healing assertions. | None. |
| `suites/full_scene_clock_program` | **Yes** | Seven stale forecast pins: old `+?` ribbon/risk text; synthetic summaries missing repeat-name metadata; old Defiance and generic hidden-lap text. | Updated two HUD test suites to the approved `+ ? 2ND MOVE` and exact loss/Defiance/named-repeat lines, and supplied canonical `repeated_enemy_names`. Retest: 1164 assertions, `TEST RESULT: PASS`. |
| Main-suite enemy-tooltip continuity assertions | No | Unchanged existing continuity suite: 44 enemy types, 274 authored intent resolutions; `PTF07 ENEMY CONTINUITY: PASS (1918 checks, 0 failures)`. | Added a standalone focused entry point only; no enemy/board tooltip behavior or assertions changed. |

**Programs persistently failing on this branch but not caused by it: none.** After the test-pin fix, no reproduced failure remains. The nine initially passing programs were not needlessly repeated after changes confined to clock assertions; the affected clock program was rerun. This does not claim the combined branch is green.

### Changes and semantics preserved

- `tests/suites/turn_clock_hud_suite.gd`: exact ribbon and risk suffix pins now say `+ ? 2ND MOVE`; synthetic repeating-foe summaries carry `repeated_enemy_names`.
- `tests/suites/turn_clock_hud_review_suite.gd`: same metadata/copy correction; exact Defiance tooltip is now `Before your next turn: −5 Health`, then `Defiance: spend 1 charge and return at 24/24 Health.`, then `Tunnel Crawler acts twice before you. Its second move is hidden.`
- Both tests still require the same crimson known-loss ink, violet suffix ink, gold pending-Wait lead/bullet, suffix-cell flag, UNKNOWN precedence and DEFEAT precedence. No colour/tonal assertion was removed or loosened.
- `tools/ptf07/focused_tests.gd`: directly invokes both existing forecast-copy checks so these pins are covered by the normal PTF07 focused command. It now has 627 assertions.
- `tools/ptf07/enemy_intent_continuity_check.gd` and UID: reproducible focused entry point calling the existing continuity suite verbatim, with no full-suite launch.
- This report records attribution and commands. **No production code changed.** `card_pool_overhaul_suite.gd` and `run_tests.gd` were not changed this round: they appear in finalization backtraces, while the stale assertions themselves reside in the two HUD suites above.

### Commands and evidence

All commands were run from `/Users/borgerding/workspace/Labyrinth.worktrees/ptf-07`.

```sh
python3 tools/program_suite_runner.py --project . --task-id ptf-07-attribution --jobs 2 --result-file /private/tmp/labyrinth_codex/ptf-07/combined-failures-before.json --suite warband_test --suite snare_test --suite save_resume_boundary_test --suite departed_run_cleanup_test --suite event_feedback_test --suite flurry_retirement_test --suite glossary_test --suite board_tile_tooltip_test --suite suites/full_scene_choices_program --suite suites/full_scene_clock_program
python3 tools/program_suite_runner.py --project . --task-id ptf-07-clock-fixed --jobs 1 --result-file /private/tmp/labyrinth_codex/ptf-07/combined-failures-after.json --suite suites/full_scene_clock_program
python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script tools/ptf07/enemy_intent_continuity_check.gd
python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script tools/ptf07/forecast_cases.gd
python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script tools/ptf07/focused_tests.gd
```

The selected-program scheduler invokes `tools/godot_task_runner.py` separately for every program, with unique task-local HOME/user storage/logs, `--headless` and a 300-second cap. It ran exactly the ten selected programs, not its default/full inventory. Before report: nine exits 0 and clock exit 1 (seven failed pins). After report: clock exit 0, no retries.

Final focused results (all exit 0):

```text
PTF07 ENEMY CONTINUITY: PASS (1918 checks, 0 failures)
PTF07 RESULT: PASS (335 checks, 0 failures)
PTF07 FOCUSED RESULT: PASS (627 assertions, 0 failures)
MAIN DOMAIN ASSERTIONS full_scene_clock_program: 1164
TEST RESULT: PASS
```

Full before/after program output and isolated engine logs are under `/private/tmp/labyrinth_codex/ptf-07/combined-failures-before.logs/` and `combined-failures-after.logs/`; the JSON reports record each program's exit status and log path. The passing continuity run's engine log is `/private/tmp/labyrinth-godot-home/ptf-07-1794365931160343000-35881/godot.log`.

Environment note: the recreated worktree lacked `.godot`. Its ignored compiled-asset cache and class index were copied from the combined checkout; `git diff 9f0829fb4 456e3e579 -- assets fonts` is empty. Production scripts were always loaded from this worktree. An initial continuity process started before that class-index copy finished and hit the missing-cache `configure` compile error; the same unchanged suite then passed on the warm cache, as recorded above. This transient bootstrap attempt is not classified as a branch behavior failure. Stable UID metadata for the new focused script was generated with `bootstrap_sidecars.gd`; no editor scan, full suite or windowed run was used. Expected macOS CA-certificate diagnostics were not treated as successes or assertion failures; runner exit codes were checked.

No new Python test module, dependency, asset or gameplay value was added. `git diff --check` passed. **Chosen defaults:** two selected programs concurrently, then one for the clock retest; existing 300-second cap and existing fixtures/assertions. **TODO_DESIGN:** none. No commit, push, merge, rebase, stash, branch change, peer review or publication was attempted. All changes remain uncommitted.


## Feedback 2: Defiance end-state explanation

This is the latest handoff status; the previous feedback sections below document earlier rounds. The owner accepted the renderer captures before this round. No windowed run or full suite was performed for feedback 2.

1. When `defiance_spent` is positive, the tooltip now adds the approved sentence immediately after “Before your next turn”. It uses the actual charge count, singular/plural wording, and projected ending Health/max Health. Umbra's existing unknown-Health convention remains `?`, so privacy sentinels are never displayed as negative Health.
2. `tests/run_tests.gd` now asserts the exact full tooltip including the `4/24 Health` sentence. `tools/ptf07/forecast_cases.gd` adds actual combat fixtures for one charge with a later hit, two charges, and a hidden Umbra follow-up; the existing Fatigue/Defiance fixture also prints its explanation. All known cases compare forecast Health and charges with live resolution. Observed fixture text is saved at `/private/tmp/labyrinth_codex/ptf-07/feedback2-defiance-tooltips.txt`.
3. Requested checks all passed, exit 0:

| Check | Exact result |
|---|---|
| PTF07 | `PTF07 RESULT: PASS (335 checks, 0 failures)` |
| Focused forecasts | `PTF07 FOCUSED RESULT: PASS (619 assertions, 0 failures)` |
| Python default | `Ran 189 tests in 30.428s` / `OK` |
| UI identity lint | `Ran 25 tests in 3.599s` / `OK` |
| Diff whitespace | `git diff --check`, exit 0 |

Commands, run from this worktree:

```sh
python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script tools/ptf07/forecast_cases.gd
python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script tools/ptf07/focused_tests.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-07/feedback2-python-default
python3 tests/test_ui_identity_lint.py
```

Default selected only 20 default-group modules; resource audit covered 56 modules. The shared Git timing-cache update remained denied at `/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json` (`Operation not permitted`); the suite itself passed. No assertion, timeout, simulation, balance value or save/analytics behavior was changed.

The exact single-charge fixture text is:

```text
Ending now leaves 2 card plays unused: +10 Time.
Before your next turn: −7 Health
Defiance: spend 1 charge and return at 4/24 Health.
```

The two-charge fixture prints:

```text
Ending now leaves 2 card plays unused: +10 Time.
Before your next turn: −11 Health
Defiance: spend 2 charges and return at 6/24 Health.
```

Files changed this round: `scripts/run_scene.gd`, `tests/run_tests.gd`, `tools/ptf07/forecast_cases.gd`, and this report. **TODO_DESIGN:** none. **Chosen defaults:** `TEST_SECOND_LETHAL_DAMAGE = 7` is test-only, causing the second real Defiance trigger; all other fixture values reuse the existing fixture. **Open issues:** none for this follow-up. No commit, peer review or publication was attempted.


## Requirements

1. The existing tooltip surface now presents the unchanged unused-plays sentence, Block/Health loss (or no damage), up to two enemy repeat warnings plus the prescribed overflow sentence, Umbra warning, then next-draw Fatigue. Hover and focus share one retained in-scene `UiTooltipPanel`; native PASS popups are suppressed. It always sits above PASS, right-aligned, at absolute maximum HUD z-order. Zero-valued loss parts are omitted. The safety-limit copy is now “Too many moves ahead to forecast them all.”
2. The forecast ribbon and action-context risk use `+ ? 2ND MOVE` instead of `+?`. Revealed damage remains visible; repeat uncertainty cannot have a safe tone. The existing UNKNOWN and DEFEAT precedence is preserved.
3. The loss-only cursor projects the next-player-turn start. A strict ordinary-combat guard projects Block expiry plus the production draw resolver; other mechanics use full production preparation on an owned snapshot. This includes Block expiry, ground contact, Meteorfall, draw/Fatigue, survival skills, Defiance and subsequent turn-start effects. Its receipts feed projected Health, losses, DEFEAT and Defiance. Gross Health loss comes from the existing damage counter so subsequent recovery cannot erase Fatigue from the warning. Full-state/non-PASS previews retain their original pre-turn-start horizon.
4. The audit is below. Unknown second moves and future arrivals are not applied as known damage; the cursor continues past them to collect other announced actors and the known next draw. Unseen reinforcements retain the original uncertainty boundary, including possible changes to other actors’ paths before the arrival’s own activation. Activation-end damage is included from the scheduled snapshot. The bounded partial result becomes UNKNOWN instead of SAFE.
5. There is no new `_process` work, timer or per-frame callback. Existing cache/prewarm invalidation is preserved. Tooltip focus work runs only on existing refresh and focus events. Simulation cost is measured below with the existing runtime interval sink.

No gameplay numbers, rules, analytics events, saves, icons or assets were changed. The new resolution occurs only on isolated preview snapshots. Balance scoring and icon-registry changes are not applicable.

## SAFE audit

Every row has a named fixture in `forecast_cases.gd`; fixture output includes projected and live Health and whether the result is uncertain. Comparisons use `advance_to_next_player_turn_with_steps`, including the actual next draw, rather than the earlier enemy-phase-only boundary.

| Case / fixture | Before this change | Current result and live comparison |
|---|---|---|
| Ordinary safe / `safe` | Counted | SAFE; projected/live 24 Health. |
| Ordinary announced hit / `danger` | Counted | 5 Health loss; projected/live 19. |
| Fatigue / `fatigue` | Omitted next draw | 15 Health loss bypasses 50 Block; projected/live 9. |
| Lethal Fatigue / `fatigue_lethal` | Could show SAFE | DEFEAT; projected/live 0; warning names the 15-Health draw cost. Loss receipt is clamped to the 5 Health actually available. |
| Fatigue with Defiance / `fatigue_defiance` | Omitted | One charge spent; projected/live 6 Health. |
| Full hand / `fatigue_full_hand` | No next-draw simulation | No shuffle and no Fatigue, matching live resolution. |
| No discard / `fatigue_empty` | No next-draw simulation | No shuffle and no Fatigue, matching live resolution. |
| Prior cycles / `fatigue_cycles` | Omitted | Correct 17-Health next-draw cost; projected/live 7. |
| Unrevealed second activation / `second_move` | Counts first hit, bare `+?`, then stops | Known loss 5; live loss 9. Explicit `+ ? 2ND MOVE`, warning tone and named enemy sentence. The second intent remains hidden. |
| Three repeating foes / `many_repeats` | Stops at first repeat | Known loss 15; live defeat. Three foes recorded; two sentences followed by `+1 more foes act twice.` |
| Another foe after a hidden repeat / `later_known` | Omits later announced hit | Known loss 7 instead of 5; live loss 11. Repeat warning remains. |
| Recovery after Fatigue / `fatigue_heal` | Net snapshot differences could erase earlier Health loss | Synthetic test-only recovery restores Health to 24, but the forecast still counts 15 Health lost and uses danger tone, matching the production gross damage counter. |
| Block expiry before ground hit / `block_start` | Stops before turn-start clearing/contact | 50 Block expires before Fire; counts 3 Health loss; projected/live 21. All enemy hits earlier in the queue still use the Block available at their actual time. |
| Expose bonus / `expose` | Counted by shared hit resolver | Counts 8 rather than 5; projected/live 16. |
| Chilled bonus / `chilled` | Counted by shared hit resolver | Counts 7 rather than 5 on Ice; projected/live 17. |
| Bleed / `bleed` | Shared announced enemy action resolver; player Pass does not trigger a Bleed action tick | Same live/preview Health, 19. Player Bleed clears on ending the activation; enemy action ticks still resolve. |
| Burn/Fire / `burn` | Announced-action ticks counted; next player ground tick omitted | Counts the next-turn Fire contact, 3 Health; projected/live 21. The legacy scalar `burn` field does not independently tick in current production rules. |
| Survival reinforcements / `reinforcements` | Rolls back and stops at any spawn | Future intents remain unknown. Live loss 3; tooltip gives Umbra uncertainty, no invented damage or ending Health. Other known effects continue to be processed. |
| Arrivals after the player / `reinforcements_after` | Stops at the arrival | Retains uncertainty because hidden occupancy can change other actors’ paths; known loss 5, live Health 19. No precise ending Health is disclosed. |
| Announced summon / `summon` | Summon resolves through shared resolver | Production reaction window schedules minions after the player; projected/live 24, no false unknown flag. |
| Death spawns / `death_spawn` | Stops at newly spawned actor; no specific explanation | Unknown future spawn intent flagged through Umbra warning. Live loss 9; no exact Health forecast is disclosed. |
| Meteorfall / `meteor` | Omitted player-turn-start impacts | Announced hit 5 plus impact 4; projected/live 15. |
| Activation-end room pressure / `activation_end` | Scheduled state already contained damage, but no receipt was summed | Counts 2 pressure plus 5 announced hit; projected/live 17. |
| Activation-end defeat / `activation_end_lethal` | Could omit displayed loss when preview starts already ended | DEFEAT; 2 Health lost, projected/live 0; no later draw is invented. |
| Stale/missing queue ID / `dead_queue` | Skipped, correctly | Both resolvers skip the nonexistent actor, then count the living foe; projected/live 19. |
| Dead actor / `dead_actor` | Initial-intent collection and dequeue skip dead actors, correctly | Same projected/live 19; no dead-actor damage or repeat sentence. |
| Empty/missing initial intent / `missing_intent` | Stops with generic uncertainty | UNKNOWN with hidden-presence warning; no intent or damage invented. Live ends at 24 in this fixture. |
| Initiative tie / `player_tie` | Player wins ties, correctly | Player starts before equal-clock enemy hit; projected/live 24. |
| Umbra-hidden action / `umbra` | Hidden receipts excluded | Still UNKNOWN, no hidden damage/name disclosed; approved Umbra sentence. |
| Safety ceiling / `safety_limit` | Can truncate at 100 activations and return SAFE or a partial loss | Now UNKNOWN with `forecast_limit_reached`; debug fixture predicts no known loss while live resolution can defeat the hero. Approved copy is “Too many moves ahead to forecast them all.” |

Other grep exits are completion, empty state/queue, missing enemy index and combat outcome. Completion/empty state have no further damage horizon; empty queue takes the ordinary player-turn start. Missing indices are covered by stale/dead fixtures. Victory/defeat suppress subsequent preparation exactly as production does. Every announced action still uses the production resolver, including movement, collisions, trap contact, status bonuses, retaliation and enemy-source battlefield effects; no independent damage arithmetic replaces those rules.

## Feedback 1 implementation

1. Placement is always `Vector2(PASS.right - panel.width, PASS.top - panel.height)`. Absolute `RenderingServer.CANVAS_ITEM_Z_MAX` puts the panel above the other controls in the HUD canvas, including piles. No size-dependent side selection remains.
2. Pointer-enter/exit and keyboard/controller focus update the same retained panel. The PASS-specific button subclass suppresses native popup creation while retaining `tooltip_text`. The windowed probe now requires the panel to be visible in both input modes, requires matching bounds, and rejects a hover capture that still has keyboard focus. These conditions are listed in `proof_contract.json` and enforced by `forecast_probe.gd::require_panel`.
3. Loss parts are built only for positive values: Health-only, Block-only, both, or “no damage”. Focused/audit checks cover these strings.
4. The constant is now `FORECAST_LIMIT_WARNING`, with the exact approved sentence. No TODO_DESIGN placeholder remains.
5. The loaded three-pair benchmark meets the requested neutral criterion after cutting added simulation work; measurements and the failed first attempt are below.
6. Requested PTF07/focused/default checks were rerun. No full suites, windowed run, peer review, commit or publication occurred.

I inspected all six owner-generated captures from the first proof. Fresh captures remain for the design owner to run; those original images are not proof of these changes.

## Performance

`prepare_baseline.py` reads the three original preview-cursor functions from pinned base `7cf181c7e26428b39d3350b52b2586ac89f2bf94` into a temporary adapter. Its exact-Script optimization guard delegates to a real production engine so the guard retains its cost and result. `compare_cost.gd` uses existing runtime interval instrumentation, 20 warmups per arm and 1,000 samples per arm in each pair. Each sample is interleaved A/B, then B/A in the second pair, then A/B in the third. A is the base; B is the candidate. The host remains shared with the other Codex units; no quiet-host condition is assumed.

All numbers below are milliseconds; the A and B cells show median / p99.

| Pair | Order | A base | B candidate | Median delta | p99 delta |
|---|---|---|---|---|---|
| 1 | A/B | 0.954 / 4.231 | 0.986 / 4.161 | +0.032 | -0.070 |
| 2 | B/A | 0.936 / 4.184 | 0.980 / 4.398 | +0.044 | +0.214 |
| 3 | A/B | 0.895 / 3.514 | 0.923 / 3.810 | +0.028 | +0.296 |

`PTF07 COST GATE: PASS (median <= +300us in every pair; p99 deltas straddle zero)`

This meets the owner's **neutral** criterion: all median deltas are below +0.3 ms, and the p99 deltas include both signs. It measures uncached simulation, not renderer or entire hover-to-paint latency. Raw per-arm samples and per-pair results: `/private/tmp/labyrinth_codex/ptf-07/cost_pairs.json`.

The first loaded set failed: median/p99 deltas were +0.278/+0.666, +0.227/+1.830, +0.231/+0.306 ms. Raw samples remain in `cost_pairs_before_optimization.json`. Removing only a duplicate snapshot did not pass the gate; those measurements remain in `cost_pairs_clone_cut.json`. The final change cuts the added work rather than accepting that regression:

- Full preparation now has an owned-state entry point, eliminating an extra full-board clone in the loss cursor; ordinary live callers still get the same defensive copy and rules.
- Cursor reads borrow canonical enemy records instead of cloning intents/status payloads merely to inspect ID/HP or schedule them. Partial legacy records retain the normalizer fallback.
- A strict health-only guard accepts only ordinary combat with no relic, skill, item, Rite, room, surface, trap, Meteorfall or terrain hook. It resolves Block expiry and calls the actual draw/Fatigue/Defiance resolver. All other inputs use full preparation. This compact loss result is never committed or animated.
- Tests compare each projected durability field and draw-cycle count with full production preparation, and verify that the retained before-state is unchanged.

The new turn-start phase fell from about 0.138–0.146 ms median to 0.019–0.020 ms. No per-frame work was added.

Reproduce:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-07 && python3 tools/ptf07/prepare_baseline.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-07 && python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script tools/ptf07/compare_cost.gd
```

## Headless validation (feedback 1)

All Godot commands use `python3 tools/godot_task_runner.py --task-id ptf-07 --stream -- godot --headless --path . --script <script>` from this worktree.

| Check / script | Observed result |
|---|---|
| `tools/ptf07/forecast_cases.gd` | `PTF07 RESULT: PASS (303 checks, 0 failures)` |
| `tools/ptf07/focused_tests.gd` | `PTF07 FOCUSED RESULT: PASS (619 assertions, 0 failures)` |
| `tools/ptf07/check_probe.gd` | `PTF07 PROBE COMPILE: PASS` |
| `tools/ptf07/compare_cost.gd` | `PTF07 COST GATE: PASS` |
| Python default group | `Ran 189 tests in 29.653s` / `OK` |
| UI identity lint | `Ran 25 tests in 5.138s` / `OK` |
| Python resource audit | 56 modules; exit 0 |
| `git diff --check` | exit 0 |

Default-group command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-07 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-07/feedback1-python-default
```

It selected only `default`, 20 modules out of 56. Full logs and individual IDs are in that output directory. The initial handoff's two launch failures did not recur. Writing the shared Git timing cache is still denied by the sandbox; tests complete normally and no Git metadata workaround is used.

The focused entry point overrides the full harness entry point and runs only turn-clock Wait, enemy-intent preview, lethal preview, existing Pass coverage and the new shared-panel assertions. The full harness/program-suite pool does not run.

Additional commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-07 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-07 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ptf-07/feedback1-python-audit
```

No new Python test module was added. The PASS-specific button's script UID was generated with the task-owned `bootstrap_sidecars.gd` metadata helper. Godot continues to emit the environment's CA-certificate diagnostic while successful runners exit 0. No full suite or windowed run occurred.

## Proof for the design owner

Run this one windowed command to produce all three requested states, with separate focus and hover captures. It requests cel look, 1920×1080 and 100% UI scale. The script checks the label, visible in-scene panel, above/right-aligned bounds, maximum absolute z-order and native-popup suppression before saving every focus and hover image. Hover additionally requires actual pointer-hover state and no keyboard focus; its bounds must match focus. The proof contract lists these semantic assertions and checks all six filenames, dimensions and HUD regions. The windowed renderer, native hover placement and full-size visual fit remain unverified here.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-07 && LABYRINTH_ART_LOOK=cel python3 tools/visual_probe_runner.py tools/ptf07/forecast_probe.gd --task-id ptf-07 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/ptf07/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-07/visual-proof.json --overwrite-result-manifest
```

Expected captures (not produced in this sandbox):

- `/private/tmp/labyrinth_codex/ptf-07/captures/second_move_focus.png`
- `/private/tmp/labyrinth_codex/ptf-07/captures/second_move_hover.png`
- `/private/tmp/labyrinth_codex/ptf-07/captures/fatigue_focus.png`
- `/private/tmp/labyrinth_codex/ptf-07/captures/fatigue_hover.png`
- `/private/tmp/labyrinth_codex/ptf-07/captures/safe_focus.png`
- `/private/tmp/labyrinth_codex/ptf-07/captures/safe_hover.png`

No inspection-fixture command was requested by the unit brief; fixture preparation and independent visual review remain with the design owner.

## Files changed

- `scripts/run_scene.gd`: ordered explanation, repeat label/tone, richer loss summary and focus hooks.
- `scripts/combat_engine.gd`: loss-only forecast horizon, repeat tracking, arrival/limit uncertainty and initial snapshot evidence.
- `scripts/pass_forecast_turn_start.gd` and UID: guarded turn-start projection, production fallback, loss receipts and approved limit copy.
- `scripts/combat_preview_known_losses.gd`: read-only canonical enemy record helper.
- `scripts/pass_forecast_focus_tooltip.gd` and UID: one above-PASS panel for hover/focus, event-driven refresh/dismissal.
- `scripts/pass_forecast_tooltip_button.gd` and UID: suppress native PASS popup.
- `scripts/retained_pass_preview.gd`: instantiate that PASS-specific button.
- `tests/run_tests.gd`: only forecast expectations updated for approved new copy.
- `tools/ptf07/`: fixtures, headless audit/focused/probe-compile entry points, renderer probe, proof contract, baseline preparation, cost benchmarks, their script UIDs and this report.

## TODO_DESIGN, chosen defaults and open issues

- **TODO_DESIGN:** none; the owner supplied the limit sentence in feedback 1.
- Chosen test-only defaults remain the existing 8×8/24-Health crawler fixture and deterministic seeds 7826/123; 50 Block, lethal Health 5/2, prior cycles 2, late clock 12/20/1000, three repeat foes and 101 actors for the limit test. Meteor damage 4, pressure damage 2, later announced damage 2 and synthetic post-draw recovery 15 are proof data only. Performance now uses 20 warmups and 1,000 samples per arm per pair with orders A/B, B/A, A/B. The headless placement test uses a 270×100 control at (1650, 870). Probe viewport 1920×1080, UI scale 1.0 and hover settle 1 second are unchanged. No gameplay tuning changed.
- Open: fresh owner-run renderer captures and visual inspection. Loaded performance meets the specified neutral gate; no full-suite claim is made. No commit, peer review or publication was attempted.
