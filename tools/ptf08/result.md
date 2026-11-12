# ptf-08c implementation result

## Feedback 3 — final recovery and lethal-Fatigue ruling

**Implemented the director ruling. No TODO_DESIGN remains in the ptf08 forecast implementation or checks.** Round 2's accepted lethal Bleed, Stoneskin and pointer-exit behavior is retained. All work remains uncommitted on `codex/ptf-08c` (HEAD `c02779020` plus the accepted working changes). No engine combat rule, content, save, analytics, icon, font, layout or animation timing changed. No full suite, windowed run, peer review or Git mutation was performed.

### Final behavior and evidence

The old fallback could not distinguish an applied Fatigue cost from the HP it actually removed. It consequently omitted preceding Bleed when Fatigue was lethal, omitted the Fatigue-only death arrow, and could display a Health loss larger than current HP after a Defiance gain.

The forecast-only turn-start helper now records actual HP removed by the existing draw resolver, separately from the unchanged `fatigue_loss` cost. The summary derives non-Fatigue Health from the known simulation's HP change minus that actual draw loss, nets healing, and clamps it to `[0,current HP]`. Only a positive value produces a Health part. Public healing is netted even when the final HP projection must stay unknown. Raw/gross loss fields remain available to existing semantic consumers.

The full turn-start receipt path calls the same engine rule helpers in the same order as `CombatEngine._prepare_next_player_turn_in_place`, measuring the draw boundary without changing live engine code. Eight added checks compare the **entire resulting state** with production preparation; all pass. There is no extra runtime turn simulation. The preparation-order comment and equality checks document its maintenance contract.

The terminal arrow is added to Health when that part exists, otherwise to Fatigue. Successful Defiance has no terminal arrow; its existing projection uses `projected_hp` and `projected_max_hp`. The director's recovery rule removes Health when healing fully offsets it; Fatigue, Block or Stoneskin still prevent `Safe`.

| Observed fixture | Final panel behavior |
| --- | --- |
| 5 HP, lethal Fatigue 15, no other loss | No Health part; Fatigue `−15 → 0` |
| 10 HP, Bleed 1 before lethal Fatigue | Health `−1 → 0`; Fatigue `−15` |
| 10 HP, turn-start fire 3 before lethal Fatigue | Health `−3 → 0`; Fatigue `−15` |
| 5 incoming damage, healing 5 | No Health part; `Safe`; HP 24 → 24 |
| 5 incoming damage, healing 2 | Health `−3`; HP 24 → 21 |
| Public full healing with an opaque enemy horizon | No Health part; existing `?` retained; projected HP stays unknown |
| Healing offsets the Health decline while Fatigue 15 applies | No Health part; Fatigue `−15`; no `Safe` |
| Defiance raises HP 1 → 4 | No Health part; Defiance `−1 → 4/24`; no terminal arrow |
| Fatigue with Defiance, HP 5 → 6 | Fatigue `−15`; Defiance `−1 → 6/24`; no terminal arrow |

The checks enforce the survivor sum for ordinary known loss windows, exactly one terminal arrow and projected HP 0 for defeat, and matching Defiance projections for saves. Recovery that offsets Fatigue is checked against the explicit recovery ruling: Health clamps to zero while the applied Fatigue cost stays visible. It is not tested against the superseded signed-sum requirement.

### Verification

Current functional checks all pass. Logs are under `/private/tmp/labyrinth_codex/ptf-08c/feedback3/`.

| Check | Exact observed result | Log |
| --- | --- | --- |
| Original defects | `PTF08 ORIGINAL DEFECT RESULT: PASS (85 assertions, 0 failures)` | `defects.log` |
| Earlier privacy/action defect set | `PTF08 PRIOR DEFECT RESULT: PASS (216 assertions, 0 failures)` | `defects.log` |
| Accepted round 2 | `PTF08 ROUND2 DEFECT RESULT: PASS (309 assertions, 0 failures)` | `defects.log` |
| Expanded ruling/privacy checks | `PTF08 DEFECT RESULT: PASS (342 assertions, 0 failures)` | `defects.log` |
| Action checks | `PTF08 ACTION RESULT: PASS (53 assertions, 0 failures)` | `actions.log` |
| Movement/preview checks | `PTF08 PREVIEW RESULT: PASS (110 assertions, 0 failures)` | `preview.log` |
| Focused checks, including row helper | `PTF08 FOCUSED RESULT: PASS (650 assertions, 0 failures)` | `focused.log` |
| Cases, including eight full-state comparisons | `PTF08 CASES RESULT: PASS (355 checks, 0 failures)` | `cases.log` |
| Probe/capture script compilation | `PTF08 PROBE COMPILE: PASS` | `compile.log` |
| Source metadata | `PTF08 SIDECARS: PASS` | `sidecars.log` |
| Real-input movie headless rehearsal | `PTF08 ACTION REHEARSAL RESULT: PASS` | `rehearsal.log` |
| Rehearsal still checks | `PTF08 HEADLESS STILL ["kill"]: PASS`, `PTF08 HEADLESS STILL ["non_kill"]: PASS`, `PTF08 HEADLESS STILL ["block_confirmation"]: PASS`, `PTF08 HEADLESS STILL ["shortcut_hover"]: PASS` | `rehearsal.log` |
| Python default group, quiet run | `Ran 189 tests in 36.113s` / `OK` | `python-quiet.log`, `python-quiet/summary.json` |
| UI identity lint | `Ran 25 tests in 37.596s` / `OK` | `ui.log` |
| Placeholder/whitespace checks | `PTF08 TODO CHECK: PASS (no TODO_DESIGN remains in forecast code or checks)`; `git diff --check`: exit 0 | terminal |

The movement and attack benchmark checks also ran headless, sequentially after the other jobs. Each used 20 warmups and 200 measured samples. Movement observed median 4076 µs / p99 15243 µs; attack observed median 4071 µs / p99 10004 µs, with verified kill and non-kill targets. Both retained PASS/parent geometry `(1638,870,270,100)`. These are smoke/timing observations, not an A/B performance or renderer claim. Logs/results: `hover.log`/`hover.json`, `attack.log`/`attack.json` in the feedback directory.

The first Python default run overlapped the Godot jobs and failed two launch-deadline checks (`approved_content_manifest` exit 124 and runner cancellation's `Child did not start`). The unchanged quiet rerun passed all 189 tests. No assertions or timeouts were changed. Godot's existing macOS CA-certificate diagnostic and the Python runner's denied optional Git timing-cache update remain environmental output.

The historical `baseline_umbra_check.gd` was attempted but is **not applicable to the current implementation**: its old `/private/tmp/labyrinth_codex/ptf-08/baseline_*.gd` snapshots reference removed `turn_clock_forecast_line.gd` and `retained_pass_preview.forecast_unchanged()`. It could not instantiate that old scene and was stopped (exit 130). `baseline-umbra.log` preserves the exact errors. No historical snapshots, tool assertions or current runtime were rewritten to force that diagnostic to pass.

Commands use the task runner from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/defect_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/forecast_cases.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-08c/feedback3/python-quiet
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tests/test_ui_identity_lint.py
```

The same Godot prefix ran `action_checks.gd`, `preview_checks.gd`, `focused_tests.gd`, `check_probe.gd`, `bootstrap_sidecars.gd`, and `action_capture.gd -- --rehearsal`. The headless benchmark scripts used `-- --output ../ptf-08c/feedback3/hover` and `-- --output ../ptf-08c/feedback3/attack`. No capture script changed and no new windowed command is needed. No new PNGs were generated; the headless movie plan is `/private/tmp/labyrinth_codex/ptf-08c/capture/plan.json`.

### Files and defaults

This round changed `scripts/pass_forecast_focus_tooltip.gd`, `scripts/pass_forecast_turn_start.gd`, the summary function in `scripts/run_scene.gd`, `tools/ptf08/defect_checks.gd`, `tools/ptf08/forecast_cases.gd`, and this report. Earlier accepted uncommitted changes are retained.

Chosen values are test-only: 10 HP / 1 Bleed, 10 HP / fire at the hero tile, heal amounts 5/2 after the existing 5-damage fixture, 1 HP for the existing Defiance fixture, and opaque queue Time 1 for the fog recovery control. A fresh ordinary engine per ruling fixture isolates the synthetic Rite effect inputs. Runtime values and text follow the director ruling and existing engine results; no new player-facing default was chosen.

**TODO_DESIGN: none. No unresolved design or functional issue remains for this unit.** The historical diagnostic limitation is recorded above; full suites and publication remain assigned to the owner.

---

## Feedback 2 — loss rows and pointer exit (accepted history; ruling resolved in feedback 3)

The owner accepted these changes. The remaining recovery/Fatigue decision recorded at the end of this round is now resolved by feedback 3 above. All earlier repro and pointer fixes remain in place. No full suite, windowed run, peer review, Git write or publication was performed. The movie script and proof contracts were unchanged.

### Finding 1: root causes and before/after

`pass_forecast_focus_tooltip.rows()` considered only Block and Health receipts when choosing `Safe`; it omitted Stoneskin and did not gate `Safe` on Fatigue/defeat. Movement paid Bleed before producing the post-action forecast source, so the later phase's receipts could contain no Health loss even when that action had just killed the hero. Fatigue was included in gross `hp_loss` and rendered again in its own row.

The source now retains the committed initial HP only when the action changes it, and the summary uses that public initial value for `source_hp`. Unchanged sources retain their previous identity, including targetless confirmation. The row helper uses the known HP decline for the Health/Fatigue split; engine summary/gross receipt consumers remain unchanged. Fatigue is excluded from the Health part, including uncertain and pending-ruling cases. Stoneskin uses the existing `stoneskin` icon and the ink returned by `_pass_preview_damage_entries({"stoneskin":1})` (`ElementData.EARTH`). Loss parts are ordered Block, Stoneskin, Health. A positive Health loss on a final defeat appends the approved ` → 0`; a successful Defiance save has no death arrow. `Safe` requires zero displayed defense/Health loss, zero Fatigue and no defeat. Existing uncertainty rows are preserved.

| Fixture | Parent rows | Fixed rows / observed HP |
| --- | --- | --- |
| 1 HP / 1 Bleed, movement to `(2,3)` | `Safe`, despite forecast and actual defeat | Health `−1 → 0`; before 1, after 0; actual commit also reaches 0 |
| 6 Stoneskin, PASS | `Safe`, despite `stoneskin_loss=5` | Stoneskin `−5`, no `Safe` |
| Bleed-only move | `Safe`, despite HP 10 → 9 | Health `−1` |
| Fatigue, HP 24 → 9 | Health `−15` plus Fatigue `−15` | Fatigue `−15` only |
| Defiance save, HP 5 → 4 | Health `−7` plus the Defiance row | Health `−1`, same Defiance row, no `→ 0` |
| Block + Stoneskin + Health | Stoneskin omitted | Block `−1`, Stoneskin `−1`, Health `−3`, in that order |

The expanded check parses the actual panel rows and verifies the sum against pre-action HP minus projected HP for hit-only, Bleed-only, Burn tick, Fatigue, Block+Health, Stoneskin+Health, all three defenses/Health, lethal Bleed and a Defiance save. It also checks the Safe predicate, Stoneskin ink and part order.

### Finding 2: root cause and before/after

RunScene's shared `_input` exit path ran only for `_click_card_targeting_active()` and depended on the move/attack approach owner. Movement and surface-skill selections therefore never cleared a retained board hover when HUD controls consumed the next GUI motion. Native `NOTIFICATION_WM_MOUSE_EXIT` cleared hand hover but no board preview.

The existing shared pointer path now includes movement and surface-skill ownership and calls `_clear_pointer_board_preview()`. The same helper handles native window exit. It clears both the board's own hover and RunScene's target, causing the normal board presentation refresh and existing 0.12 s panel/badge fade. Returning to the same legal tile emits a fresh entry. The helper explicitly excludes controller ownership; controller input without pointer motion does not trigger an exit.

Before: movement/skill retained the old tile with alpha 1.0 after 250 ms over the map button. After: for movement, surface skill and the card control, HUD, hand and native window exits all produce tile `(-1,-1)`, alpha 0.0 and hidden/faded badges after 250 ms. Return checks pass for each route. An active controller target survives native window exit for all three action owners.

### Baseline and final verification

Before runtime edits, the parent runtime failed the new repro/matrix: `PTF08 DEFECT RESULT: FAIL (297 assertions, 37 failures)`, while `PTF08 PRIOR DEFECT RESULT: PASS (216 assertions, 0 failures)` confirmed all earlier checks. The final script additionally checks all-three loss-part ordering/ink and active controller controls; its final result is 309 passing assertions.

All final commands exited 0. Logs are under `/private/tmp/labyrinth_codex/ptf-08c/feedback2/`.

| Check | Exact observed result | Log |
| --- | --- | --- |
| Earlier original defects | `PTF08 ORIGINAL DEFECT RESULT: PASS (85 assertions, 0 failures)` | `defects.log` |
| Earlier complete defect set | `PTF08 PRIOR DEFECT RESULT: PASS (216 assertions, 0 failures)` | `defects.log` |
| Expanded defects / sum / real input / controller | `PTF08 DEFECT RESULT: PASS (309 assertions, 0 failures)` | `defects.log` |
| Actions | `PTF08 ACTION RESULT: PASS (53 assertions, 0 failures)` | `actions.log` |
| Preview | `PTF08 PREVIEW RESULT: PASS (110 assertions, 0 failures)` | `preview.log` |
| Focused | `PTF08 FOCUSED RESULT: PASS (650 assertions, 0 failures)` | `focused.log` |
| Cases | `PTF08 CASES RESULT: PASS (347 checks, 0 failures)` | `cases.log` |
| Python default group (20/56 modules) | `Ran 189 tests in 30.461s` / `OK` | `python-final.log`, `python-final/summary.json` |
| UI identity lint | `Ran 25 tests in 6.020s` / `OK` | `ui-final.log` |
| Whitespace | `git diff --check`: exit 0 | terminal |

Godot emitted the existing macOS CA-certificate diagnostic. The Python runner's optional Git timing-cache write was denied with `[Errno 1] Operation not permitted`; tests exited 0. No new Python test module or resource manifest entry was needed. No existing failing master assertion was rewritten. The legacy row-test ink helper now supplies the existing Stoneskin ink; its assertion count is unchanged.

Godot commands use `python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/<script>.gd`, for `defect_checks`, `action_checks`, `preview_checks`, `focused_tests` and `forecast_cases`, from this worktree. Python used `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-08c/feedback2/python-final` and `python3 tests/test_ui_identity_lint.py`.

### Files changed

- `scripts/pass_forecast_focus_tooltip.gd`: ordered loss parts, safe/death presentation and a single Health/Fatigue row-value helper.
- `scripts/pass_forecast_presentation.gd`: supply existing Stoneskin ink.
- `scripts/pass_forecast_action_source.gd`: public pre-action HP metadata when the action changes Health.
- `scripts/run_scene.gd`: consume initial HP and extend the shared pointer/window exit path.
- `tools/ptf08/defect_checks.gd`: baseline repros, parsed-row sum fixtures, pointer exit/return/badges and controller controls.
- `tools/ptf08/row_tests.gd`: supply Stoneskin ink for existing shared row checks.
- `tools/ptf08/result.md`: this record; prior records retained below.

### Recovery decision at that stage (resolved)

Round 2 left the recovery/lethal-Fatigue display policy pending. The director supplied the final ruling in feedback 3: net and cap the non-Fatigue Health part, preserve the applied Fatigue cost, put the sole terminal arrow on Health or otherwise Fatigue, and keep successful Defiance as the only HP projection. The placeholder has been removed. No decision remains open; the feedback 3 record above is authoritative.

### Chosen defaults and proof

Only test fixtures/timing changed: 1 HP / 1 Bleed and 6 Stoneskin from the supplied repros; Bleed-only HP 10, Block 2, Stoneskin 2, combined Block 1/Stoneskin 1; 200/250 ms pointer settle/exit proof; 3 input frames and 6 layout-settle frames; native-window-exit notification and explicit controller modality/focus controls. None is player-facing tuning. The existing Stoneskin PNG was inspected. No art, icon, font, engine rule, save or analytics change was made. No movie script changed, so there is no changed capture command for this feedback.

---

## Feedback 1 — unseen floor content (base `f9bef6280`)

Implemented in the existing worktree; this feedback's changes remain uncommitted. The five earlier fixes are retained. The owner reports that their re-review, windowed movie and still inspection passed on the parent. No full suite, windowed run, peer review, Git write or publication was performed for this feedback.

### Root cause and corrected numbers

`_surface_preview_information_state` filtered enemies, traps, terrain and surfaces but left floor loot intact. Movement therefore collected an undisclosed item while resolving the supposedly known action, changing the hypothetical hand/deck before Fatigue was calculated. Removing the item after resolution could not undo that change. In addition, `_visibility_safe_preview_display_state` restores committed loot for board presentation, and the forecast previously retained that restored collection. Idle PASS also returned the unfiltered combat state.

The shared known-state builder now lives in `pass_forecast_action_source.information_state`; the existing RunScene function delegates to it. Every caller filters causes before action resolution. It omits unseen loot, traps, terrain, enemies, illusions and NPCs, filters unseen surface entries/history, and clips multi-tile Meteorfall marks to their visible portion. Public grid geometry and the board's guardian brazier markers are preserved. The forecast display boundary retains the already-filtered/resolved loot and trap collections, and idle PASS uses the same known-state boundary. There is no per-action loot fix and no change to combat rules, content or committed pickups.

| Review scenario, hero `(2,4)` moving to hidden `(2,2)`, six cards / empty draw | Parent | Fixed |
| --- | --- | --- |
| No item | Health loss **15**, Fatigue **15** | Health loss **15**, Fatigue **15** |
| Unseen Crimson Draught | Health loss **0**, Fatigue **0** (`Safe`) | Health loss **15**, Fatigue **15**, identical rows |
| Visible Crimson Draught at `(2,3)` (positive control) | — | Health loss **0**, Fatigue **0**, item retained in hypothetical hand |

The parent also re-marked an announced enemy intent as hidden when the hypothetical movement changed sight. The forecast now retains a set of committed disclosed actors for interpreting both intent uncertainty and damage receipts. Moving onto empty unseen ground does not itself add `?`; genuinely opaque queue entries and new arrivals keep the existing uncertainty horizon. A ranged positive control confirms that an announced 6-damage attack against 2 Block plus 15 Fatigue still forecasts **19 Health loss / 2 Block loss / 15 Fatigue**, without false Umbra uncertainty.

### Mutation and source proof

`tools/ptf08/defect_checks.gd` retains the original 85 assertions and adds:

- Real movement-path enumeration for destinations `(2,2)` and `(2,1)`. Every unseen intermediate/destination tile receives separate add/change/remove mutations of a floor item, trap and surface (27 combinations). Rows remain identical, the panel remains active, and none of these mutations adds Umbra uncertainty.
- Source and row comparisons for idle PASS, targetless Brace, targeted Bone Dart and Prismatic Instinct with combined hidden loot/trap/surface/terrain/mark content.
- Shared-builder checks for hidden positional actors, mixed visible/hidden Meteorfall marks, retained public geometry and caller immutability.
- Visible-pickup and announced-ranged-damage positive controls.

The same floor mutation/source matrix was run against the actual parent versions of the two runtime files, with the working regression script: `PTF08 DEFECT RESULT: FAIL (214 assertions, 47 failures)`. The original checkpoint still passed all 85 assertions. Parent log: `/private/tmp/labyrinth_codex/ptf-08c/feedback1/baseline.log`. The ranged positive control was added afterward; the final expanded script passes 216 assertions. Runtime files were restored byte-for-byte to the implementation after the baseline run, without Git metadata changes.

### Final observed checks

All final commands exited 0. Logs are under `/private/tmp/labyrinth_codex/ptf-08c/feedback1/`.

| Check | Exact observed result | Log |
| --- | --- | --- |
| Original defects | `PTF08 ORIGINAL DEFECT RESULT: PASS (85 assertions, 0 failures)` | `defects.log` |
| Expanded defects | `PTF08 DEFECT RESULT: PASS (216 assertions, 0 failures)` | `defects.log` |
| Actions | `PTF08 ACTION RESULT: PASS (53 assertions, 0 failures)` | `actions.log` |
| Preview | `PTF08 PREVIEW RESULT: PASS (110 assertions, 0 failures)` | `preview.log` |
| Focused | `PTF08 FOCUSED RESULT: PASS (650 assertions, 0 failures)` | `focused.log` |
| Cases | `PTF08 CASES RESULT: PASS (347 checks, 0 failures)` | `cases.log` |
| Python default group (20/56 modules) | `Ran 189 tests in 33.414s` / `OK` | `python-final.log`, `python-final/summary.json` |
| UI identity lint | `Ran 25 tests in 6.187s` / `OK` | `ui-final.log` |
| Whitespace | `git diff --check`: exit 0 | terminal |

Godot still prints its existing macOS CA-certificate diagnostic. The Python runner's optional Git timing-cache update was denied with `[Errno 1] Operation not permitted`; tests exited 0. No new Python test module was added, so no resource manifest entry is needed; the default runner performed its isolation audit.

Commands used (Godot scripts: `defect_checks.gd`, `action_checks.gd`, `preview_checks.gd`, `focused_tests.gd`, `forecast_cases.gd`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/defect_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-08c/feedback1/python-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tests/test_ui_identity_lint.py
```

### Files, defaults and remaining work

Changed only `scripts/pass_forecast_action_source.gd`, the forecast/known-state functions in `scripts/run_scene.gd`, `tools/ptf08/defect_checks.gd`, and this report. Presentation, badge, prewarm and approved capture files are unchanged.

`TODO_DESIGN`: none. Chosen defaults are test-only: `FLOOR_DESTINATIONS = [(2,2),(2,1)]`, `FLOOR_PROOF_MOVEMENT = 4` (a test engine override keeps every mutated path selectable), `FLOOR_PROOF_ID = 77`; changed item Mossglass Elixir; trap damage 4/12 and fire/ice variants; fire/ice+rubble surface variants; a hidden 30-HP wooden box, 12-damage Meteorfall marks; and the announced ranged fixture's 2 Block, range 8, damage 6 and Time 10. No player-facing default was chosen.

Open issues: none known for this feedback. Full suites and further review remain with the owner as assigned. No new renderer proof was requested or run.

---

## Initial ptf-08c implementation record (retained)

Base: `52ed97d387cc8a296b065abf0af274991f2410d7`, branch `codex/ptf-08c`.
Risk: high. All implementation changes are uncommitted in the supplied worktree.
No preflight, commit, peer review, publication, queue change, full suite or windowed run was performed. The design owner owns those workflow stages.

## Acceptance criteria and before/after evidence

The core five-defect check ran against the unchanged base runtime first:
`PTF08 DEFECT RESULT: FAIL (25 assertions, 7 failures)`.
Each of defects 1–5 failed. The expanded final check reports
`PTF08 DEFECT RESULT: PASS (85 assertions, 0 failures)`.
Evidence: `/private/tmp/labyrinth_codex/ptf-08c/baseline.log`, `core-after.log`, and `defects.log`.

1. **Hidden actor isolation.** `visibility_safe` restored entire undisclosed enemy records, with only intents cleared. Visible Root Mend could therefore select an unseen damaged ally. Before: changing unseen HP 14 → 5 changed Health loss 1 → 0. After: undisclosed enemies and their queue records are excluded from numeric simulation. Only queue Time/sequence metadata survives for the existing `?` horizon; no hidden HP, position, status or intent survives as an actor. Known traps stay filtered too, rather than being restored by the display-state helper. In the review's Weaver/Patch Up scenario, Health loss remains 1 and Block loss remains 2. The final mutation matrix independently changes HP, position (including its queue position), intent and real status fields for each of two hidden actors; all displayed rows are identical, and every numeric source contains only the disclosed Weaver. The original action checks also confirm the hidden-before-player horizon still produces `?` and unknown projected Health.

2. **Winning kills and limited-sight victory.** The board's `_preview_opaque_enemies` flag deliberately prevents an information-filtered board from asserting victory. Carrying it into the Pass simulation also prevented an actual winning kill from stopping end-turn effects. Before: Quick Stab's actual victory at 10 HP forecast Health loss 10, Fatigue 15, and defeat. After: the forecast-only snapshot clears that flag so known victory stops scheduling/draw effects. Limited-sight victory is presented as the existing Umbra `?`, with no `Safe` row, disclosed victory, projected Health, Fatigue or Health loss. The same panel rows appear with and without a hidden surviving foe. Full-sight victory retains the accurate safe result. No combat engine rules changed.

3. **Shortcut hover.** The presentation trigger checked ordinary `target_tiles` only, although the forecast source already resolved shortcut plans. Before: Sidestep Slash at foe `(4,4)` had a valid plan, but `trigger=false`, `panel=false`. After: a valid `_shortcut_plan_for_tile` also activates the panel. The test checks that its source includes both movement and damage and that displayed rows match that source's summary. The movie now includes real pointer selection and shortcut hover, with its own still.

4. **Every preview exit fades.** Visibility had no lifecycle observer: after `_commit_surface_skill_tile` cleared aim and set the lock, no refresh ran during the animation. Before: after 200 ms, `lock=true active=true alpha=1.0`. After: `lock=true active=false alpha=0.0`. A presentation-only child observes lifecycle gates while the panel is active, starts the existing 0.12 s fade on the next presentation frame, and uses the existing FadeDriver to fade panel and rail badges together. It performs no forecasting, targeting or per-frame simulation. Cancel and refresh paths retain their synchronous presentation refreshes.

   Entry-point audit: `_cancel_card_selection` and `_clear_active_card_preview_state` cover card cancel/deselect; `_cancel_player_movement_selection` and `_cancel_surface_skill_selection` cover the other owners. `_play_player_card`, `_commit_player_movement`, `_commit_surface_skill_tile`, `_commit_quick_wits` and `_commit_encore` start commit locks; `_resolve_enemy_round` starts the turn handoff (including `_lock_existing_pass_preview`). Fight-ending committed actions enter those same locks before their outcome presentation, and the observer also checks combat outcome, run mode and current actor. Remaining lock writers are graft, campfire, reward, combat-entry, room-transition and checkpoint presentation; the same lock/mode gate covers them without separate hooks. Dialogue and drag also dismiss the preview. The final regression explicitly tests cancel, deselect, direct lock, turn end, fight end, dialogue and drag without requiring hover refresh, with real repeat badges and a 0.12 s fade sample.

5. **Stationary pointer at targetless confirmation.** The root cause is the retained dock's visibility sequence, not a hand-hover suppression or competing tooltip refresh: `choice_refresh.gd` hides `_pass_preview_overlay`, then refreshes/builds the chip while that ancestor is hidden, then makes the overlay visible again. Presentation's `chip.is_visible_in_tree()` check made the intermediate refresh inactive. Targetless confirmation has no changing board target, so `_pass_preview_hover_can_change()` does not schedule another refresh when the pointer remains on the hand. The old headless test masked this by calling `_refresh_selected_card_forecast` directly after selection. After: the chip's actual visibility transition requests a deferred refresh, after layout/choice presentation completes. The new test selects Brace with real mouse motion and press/release events, leaves the pointer there and calls no selection/forecast refresh methods during that input path. Before: `selected=0 confirm=true active=false visible=false alpha=0.0`. After: `selected=0 confirm=true active=true visible=true alpha=1.0`, with Block loss 6. The movie exercises that same stationary-pointer path.

## Files changed

- `scripts/pass_forecast_action_source.gd`: hidden-free numeric snapshots, public durability retention, queue-only uncertainty metadata and horizon lookup.
- `scripts/pass_forecast_presentation.gd`: shortcut trigger, shared lifecycle/visibility observer, existing `?` presentation for limited-sight terminal outcomes.
- `scripts/run_scene.gd`: forecast summary reads uncertainty metadata and suppresses disclosure of a limited-sight terminal outcome. Only forecast functions changed.
- `tools/ptf08/defect_checks.gd` and `.uid`: five repro checks, two-actor mutation matrix, hidden-presence comparison, lifecycle/badge checks and real pointer confirmation.
- `tools/ptf08/action_capture.gd`: headless rehearsal of the same real input and still assertions; new shortcut beat; task-local fixture/output paths. Headless rehearsal skips only renderer image readback.
- `tools/ptf08/action_movie_godot.sh`: task-local movie output directory.
- `tools/ptf08/action_proof_contract.json`: requires the shortcut still and input beat.
- `tools/ptf08/result.md`: this handoff.

Existing prewarm caching and badge fade propagation are reused; no changes to `pass_preview_prewarm.gd` or `turn_order_slots.gd` were needed. No board drawing, hand layout, engine rule, content data, analytics, saves, names, tuning, art, icons, fonts or audio changed.

## Observed verification

All logs below are under `/private/tmp/labyrinth_codex/ptf-08c/`. Every final command exited 0.

| Check | Exact observed result | Log |
| --- | --- | --- |
| Five defects plus mutations/lifecycle | `PTF08 DEFECT RESULT: PASS (85 assertions, 0 failures)` | `defects.log` |
| Existing action checks | `PTF08 ACTION RESULT: PASS (53 assertions, 0 failures)` | `actions.log` |
| Existing movement checks | `PTF08 PREVIEW RESULT: PASS (110 assertions, 0 failures)` | `movement.log` |
| Existing focused checks | `PTF08 FOCUSED RESULT: PASS (650 assertions, 0 failures)` | `focused.log` |
| Existing cases | `PTF08 CASES RESULT: PASS (347 checks, 0 failures)` | `cases.log` |
| Python default group, 20/56 modules | `Ran 189 tests in 37.022s` / `OK` | `python.log`, `python/summary.json` |
| UI identity lint | `Ran 25 tests in 6.597s` / `OK` | `ui.log` |
| Fixture generation and verification | `Inspection fixture verified.` | `fixture.log`, `fixture.json` |
| Real-input headless movie rehearsal | `PTF08 ACTION REHEARSAL RESULT: PASS` | `rehearsal.log` |
| Rehearsal still checks | `PTF08 HEADLESS STILL ["kill"]: PASS`, `PTF08 HEADLESS STILL ["non_kill"]: PASS`, `PTF08 HEADLESS STILL ["block_confirmation"]: PASS`, `PTF08 HEADLESS STILL ["shortcut_hover"]: PASS` | `rehearsal.log` |
| Source metadata | `PTF08 SIDECARS: PASS` | `sidecars.log` |
| Shell syntax, JSON syntax, whitespace | `sh -n`, `python3 -m json.tool`, `git diff --check`: exit 0 | terminal |

The movie's headless plan is `/private/tmp/labyrinth_codex/ptf-08c/capture/plan.json`. No PNGs or movie frames were generated headless. The supplied failure screenshot `/private/tmp/labyrinth_codex/ptf-08/feedback3-capture/block_confirmation.png` was inspected before implementation.

The movement check retained PASS and parent geometry `(1638,870,270,100)` at 1920×1080. Existing action/movement assertions also passed their zero-additional-simulation warm-hover checks.

Godot emitted its existing macOS CA-certificate diagnostic. The Python runner's optional untracked Git timing-cache update was denied (`[Errno 1] Operation not permitted`); the default group completed successfully with exit 0 and no metadata workaround. No new Python test module was added, so no resource manifest entry is needed; the default runner performed its isolation audit.

Reproduce focused checks from the task worktree (each Godot script goes through the task runner):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/defect_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/action_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/preview_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/focused_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/forecast_cases.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-08c/python
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && python3 tests/test_ui_identity_lint.py
```

## Proof for the design owner

The fixture below was generated and verified headless. Its two foes give a Bone Dart kill and non-kill, Brace confirmation, and a Sidestep Slash shortcut hover. This is proof-only setup, not a game-content change.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && LABYRINTH_CEL_LOOK=all python3 tools/inspection_fixture.py --task-id ptf-08c --run-id ptf-08c-proof --scenario combat --seed 123 --room-coord 0,13 --hand bone_dart,brace,sidestep_slash --player-position 2:4 --enemy-types crawler,crawler --enemy-positions 3:4,4:4 --enemy-intents lunge,lunge --enemy-hp 3 --summary 'ptf-08c all-action forecast proof' --manifest /private/tmp/labyrinth_codex/ptf-08c/fixture.json
```

The following rehearsal was run and passed. It uses real pointer/key events and the movie's own still checks, including full panel alpha. It does not substitute rendered image proof.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id ptf-08c --stream -- godot --headless --path . --script tools/ptf08/action_capture.gd -- --rehearsal
```

Exact **windowed command, not run here**, at 1920×1080, 100% UI scale, fixed 30 FPS:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/ptf08/action_capture.gd --task-id ptf-08c --godot /Users/borgerding/workspace/Labyrinth.worktrees/ptf-08c/tools/ptf08/action_movie_godot.sh --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tools/ptf08/action_proof_contract.json --result-manifest /private/tmp/labyrinth_codex/ptf-08c/visual-proof.json --overwrite-result-manifest -- --fixed-fps 30
```

The wrapper supplies `--write-movie /private/tmp/labyrinth_codex/ptf-08c/capture/frames/movie.png --fixed-fps 30` before the user-argument separator. Expected renderer outputs, **not generated here**:

- `/private/tmp/labyrinth_codex/ptf-08c/capture/kill.png`
- `/private/tmp/labyrinth_codex/ptf-08c/capture/non_kill.png`
- `/private/tmp/labyrinth_codex/ptf-08c/capture/block_confirmation.png`
- `/private/tmp/labyrinth_codex/ptf-08c/capture/shortcut_hover.png`
- `/private/tmp/labyrinth_codex/ptf-08c/capture/frames/` movie frames.

## TODO_DESIGN placeholders

None. No perceivable decision was missing from the brief or existing approved implementation.

## Chosen defaults

Only proof/test values changed: `SETTLE_FRAMES = 20`; hidden-actor mutation fixture IDs 2/3, positions `(5,4)`/`(6,5)` with alternate `(7,4)`, HP 14/5, queue times 100/101, and Bleed 12/Stagger 9; proof seed 123 and room `(0,13)` (retained), hand slot 2 uses Sidestep Slash, the second proof foe is at `(4,4)`; headless rehearsal caps `Engine.max_fps` at the existing movie `FPS = 30` so wall-clock fades settle. Shortcut selection/hold/travel reuse the existing movie timing fields. Runtime player-facing dimensions, timing, text, colours, tuning and content have no newly chosen values.

## Open issues

No known failing headless acceptance criterion. The sandbox has no window server, so the owner must run the exact windowed command, inspect the four fresh captures/movie and perform their assigned review/publication workflow. The headless rehearsal cannot prove rendered appearance or occlusion.
