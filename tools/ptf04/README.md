# ptf-04 proof

This implementation worker cannot access the window server. No windowed command
has been attempted. The design owner runs the following once and inspects all
five captures at full resolution. The probe uses production panels, tooltip
callbacks, a real generated guided combat, and the normal defeat settlement.
It asserts a HUD/terminal/marker total of 34 (16 carried + 18 earned mid-fight).

Refresh the approved deterministic cel filter cache if needed (the worker
generated no art):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-04 && python3 tools/cel_look.py build --if-stale
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-04 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id ptf-04 --expect-size 1920x1080 --proof-contract tools/ptf04/proof.json --result-manifest /private/tmp/labyrinth_codex/ptf-04/visual-result.json --overwrite-result-manifest tools/ptf04/probe.gd
```

Captures are under `/private/tmp/labyrinth_codex/ptf-04/`:

1. `01_tutorial_step_2.png`: the inspected crawler's production intent and the
   exact pointer tutorial copy. The same copy is pinned for controller input.
2. `02_map_legend_hover.png`: opened RunScene section map and native Graftwright legend hover tooltip.
3. `03_graftwright_node_hover.png`: the same opened map with a revealed Graftwright node hovered.
4. `04_board_gear_hover.png`: actual combat board gear tooltip, including claim
   and expiry copy.
5. `05_death_midfight_embers.png`: death recap after settling fatal-fight earnings.

No inspection-fixture command is required by this unit brief; the design owner
owns that workflow stage.

## Lesson mapping

Pale Spark (preview and first hit), Quick Stab (follow-up and lethal hit), and
Brace (kill-refunded play and damage absorption) remain unchanged. Guarded Step
and Hamstring Shot remain the two other real starter cards in the opening hand.
Backhand Nick was only a free-play draw, not a lesson card. It belongs to
Sawtooth Knife, not starting equipment. The draw pile now contains exactly the
remaining copies of the real run deck after removing the five staged cards;
this also removes the duplicate Guarded Step, Quick Stab and Brace injections.

## Chosen defaults

Invisible proof inputs are named in `fixtures.gd` and `probe.gd`: seed 90210,
wallet fixtures 16 + 18 and 145 + 7, 1920×1080 / 100% scale, waits 0.35 s for layout, 1 s for native tooltip, and 2.5 s for
the death recap. These do not tune production behavior.

## Threshold copy

The design owner supplied the Threshold/start-node tooltip: "Where this section begins."
There is no remaining Threshold TODO.

## Ember path

`RunEngine.finish_combat` → `set_combat_state` (including recovered Embers) →
defeat branch settles `room_embers` → terminal persistence
`_finalize_terminal_committed_state` / `_process_defeat_loss` →
`ProgressionStore.record_lost_embers` → recovery marker `amount` and
`_defeat_lost_amount` → existing recap `Embers lost …` line. The existing
`held_embers` and `unbanked_embers` snapshot fields now include fatal-fight earnings;
`run_ended.held_embers` includes them when emitted before clearing. No schema,
append-only history, or existing save field is renamed.

## Existing copy counts

The supplied branch already renders U+00D7 in `ui_card_strip.gd` (shared by
Character and Your Kit), `pile_dialog_view.gd`, and Chronicle deck summaries.
The focused checks pin `×2`; no production copy-count rewrite is needed.

## Verification observed

All final commands exited 0. Godot commands used
`python3 tools/godot_task_runner.py --task-id ptf-04 --stream -- godot --headless --path . --script <script>`.

| Check | Observed result | Log under `/private/tmp/labyrinth_codex/ptf-04/` |
| --- | --- | --- |
| `tests/contextual_combat_tutorial_test.gd` | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` | `contextual_combat_tutorial_test.log` |
| `tests/guided_combat_tutorial_integration_test.gd` | `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS` | `tutorial-final.log` |
| `tools/ptf04/checks.gd` (map pointer/legacy mystery, exact tooltips, deck count, badge, wallet/marker/recap/analytics, empty outcome) | `PTF04 FOCUSED CHECKS: 0 failures` | `checks-final.log` |
| `tests/run_end_recap_tests.gd` | `RUN END RECAP TEST RESULT: PASS` | `run_end_recap_tests-verified.log` |
| `tests/event_rules_test.gd -- --rules-only` | `Event rules suite: 0 failures` | `event-rules-final.log` |
| `tests/event_view_test.gd` | `Event view suite: 0 failures` | `event-view-final.log` |
| `tests/event_feedback_test.gd` | `Event feedback suite: 0 failures` | `event-feedback-final.log` |
| `tests/pre_battle_semantics_test.gd` | `PRE-BATTLE SEMANTICS TEST: PASS`; `TEST RESULT: PASS` | `pre-battle-final.log` |
| `tools/ptf04/probe.gd -- --logic-only` | `PTF04 PROBE LOGIC: PASS` | `probe-logic-final.log` |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ptf-04/python-default` | `SELECTED MODULES: 20 of 56`; `Ran 189 tests in 42.566s`; `OK` | `python-default.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 9.819s`; `OK` | `ui-lint.log` |
| `git diff --check` | exit 0, no output | — |

The tutorial integration suite also emits the existing off-tree
`Can't use get_node() with absolute paths from outside the active scene tree`
error from the unchanged `_controller_is_active` call in its hard-gate fixture.
It still prints PASS and the runner exits 0. No assertion was weakened.
macOS headless launches print the platform CA-certificate error; the runners
still exit 0. The Python suite could not update its optional timing cache in
read-only Git metadata; its suite exit remained 0.

The initial missing class cache prevented RunScene parsing. A headless `--import`
bootstrap produced the class cache, after which those checks were rerun. The
bulk asset import was interrupted (exit 130) rather than finishing the entire
asset tree; this is not claimed as a passing import check. No windowed run or
full suite was performed. The pre-battle windowed test's badge expectations and
the map-flow probe's tooltip line-count assertion were updated but not executed
as renderer proof.

## Files changed

- Runtime: `scripts/contextual_combat_tutorial.gd`,
  `scripts/guided_combat_scenario.gd`, `scripts/section_map_panel.gd`,
  `scripts/item_preview_builders.gd`, `scripts/run_scene.gd`,
  `scripts/pre_battle_view.gd`, `scripts/run_engine.gd`, `scripts/event_view.gd`.
- Documentation: `spec/analytics.md`.
- Pinned tests/probes: `tests/contextual_combat_tutorial_test.gd`,
  `tests/suites/guided_combat_tutorial_suite.gd`,
  `tests/suites/section_map_v2_suite.gd`, `tests/pre_battle_view_test.gd`,
  `tests/section_map_flow_probe.gd`.
- Unit tooling: this README, `fixtures.gd`, `checks.gd`, `probe.gd`, their `.uid`
  sidecars and `proof.json` in `tools/ptf04/`.

No provided design data, art, icons, audio or fonts were edited. No new Python
module was added; the default runner completed its 56-module isolation audit.
Existing committed combat snapshots keep their saved intents; the corrected
guided payload and hand apply when a new guided fight is prepared. The scenario
schema version remains unchanged so existing authored saves remain recognized.

## Feedback 1: map capture guards

The map proof now loads a non-tutorial fixture with a revealed Graftwright and
uses RunScene's `_open_large_map`, rather than hiding RunScene and adding a
separate panel. Each map capture reads its exact semantic requirements from
`proof.json.runtime_assertions`: the production map scrim and panel must be
visible, the canonical tooltip text must match exactly, and the displayed
Label/RichTextLabel content must match exactly (including the shared title's
uppercase formatting). Windowed legend proof requires an actual visible native
TooltipPanel popup; node proof requires the visible RoomPreview. Missing map,
missing popup, or wrong text marks the probe failed and skips the capture.
Headless logic validates legend factory content without claiming native popup
or renderer proof.

Feedback 1 validation (headless only, task runner; no other suites rerun):

- `tools/ptf04/probe.gd -- --logic-only`:
  `PTF04 PROBE LOGIC: PASS` (`feedback1-probe-logic-final.log`).
- `tests/section_map_v2_test.gd`:
  `Section map v2 suite: 0 failures (seeds 0..64 x 6 sections)`
  (`feedback1-section-map.log`).

The capture command includes `--overwrite-result-manifest` so the design owner
can rerun against the existing manifest path. The two map PNGs are removed at
windowed probe startup; a rejected map state cannot leave an old map capture
masquerading as new evidence. No additional defaults or design TODOs were added.

## Combined trial 456e3e579: standalone regression audit

Audited this unit's recreated, initially clean branch at `8f69a8742` against the
combined gate log. Ran the ten named failing programs individually through the
task runner, plus invocation-only adapters for the main suite's enemy-intent and
shared tooltip suites. No full suite was run. All initially passed except the
clock partition's two cold-cache portrait identity assertions. Those differ
from the combined branch's forecast-copy failures.

| Program | Fails on ptf-04 alone? | Cause/evidence | Fix in this unit |
| --- | --- | --- | --- |
| `warband_test` | No | Combined-only full-layout golden mismatches; standalone goldens pass. | None. |
| `snare_test` | No | Shares the combined layout-golden mismatch; standalone passes. | None. |
| `save_resume_boundary_test` | No | Combined log fails the retired-vocabulary scan; standalone repair matrix passes. Combined adds default omen Grimoire IDs, including `omen:tithe_of_ash`, which can match the test's broad retired `ash*` regex (source-based diagnosis). | None; do not weaken the scan here. |
| `departed_run_cleanup_test` | No | Standalone completes all three routes with `errors:[]` and `orphans:0`. Combined profile/save equality mismatch was not isolated further; it is not reproduced with this unit's fatal-fight wallet change. | None. |
| `event_feedback_test` | No | Combined-only Label/TextureRect assignment error and relic preview minimum-width assertion. Standalone reports zero failures. | None. |
| `flurry_retirement_test` | No | Combined keyword wrapper changes equipment tooltip root to HBoxContainer; shared assertion still demands PanelContainer. | None. |
| `glossary_test` | No | Same shared tooltip-root assertion in combined. | None. |
| `board_tile_tooltip_test` | No | Same shared tooltip-root assertion in combined. | None. |
| `suites/full_scene_choices_program` | No | Combined Linger healing changes from 4 to 6; inherited tests still pin `+4 HP` and 14 final HP. Standalone passes 772 assertions. | None. |
| `suites/full_scene_clock_program` | Yes initially; no after cache setup | Two unchanged `Umbra keeps the still Unknown Presence texture` assertions failed because the fresh worktree loaded an ImageTexture without resource_path. This is not the combined seven forecast copy/colour assertions. | Restored only the matching generated Umbra texture cache; no source/test change. Rerun passes 1,164 assertions. |
| Main suite enemy-intent checks | No | Exact suite invocation passes all 1,918 checks. Combined changes pointer hit geometry while its fixture still hovers tile centres; that is a candidate combined-only cause, not a proven ptf-04 regression. | None. |
| Main suite shared tooltip checks | No | Exact suite invocation passes all 72 checks; same combined wrapper/root-type difference described above. | None. |

The `.bind(false, true)` is only registered on the board's callback. The equipment
menu calls the builder without the pickup argument. Added production-callback
coverage in `checks.gd`: an actual RunScene board tooltip contains the claim and
expiry footer without the combat lock; the combat equipment-menu tooltip
contains the lock without the pickup footer. These checks pass. No production
code, gameplay values, or old decided-behavior assertions were changed.

The generated cache restoration compared both `umbra_presence.png` and its
`.import` sidecar byte-for-byte against the combined worktree, then copied only
the matching `.ctex` and `.md5` into this worktree's ignored `.godot/imported/`.
The canonical PNG SHA-256 is
`c495594e8a860ee48238dc5f90ffc99a9fba703d6f0ffde845a793719c9350e0`.
The initial class-cache bootstrap was interrupted after producing the class
cache, rather than importing every repository asset. No asset source or sidecar
was rewritten, and the cache repair does not represent a production fix.

Reproduction tools (execution-only pool default: two isolated Godot workers):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-04 && python3 tools/ptf04/run_regressions.py --phase standalone
cd /Users/borgerding/workspace/Labyrinth.worktrees/ptf-04 && python3 tools/ptf04/run_regressions.py --phase focused --focused
```

Observed records under `/private/tmp/labyrinth_codex/ptf-04/combined-failures/`:

- `before/results.json`: original standalone runs, including the initial
  cold-cache clock failure.
- `imported-cache/results.json`: clock-only rerun, exit 0, `TEST RESULT: PASS`.
- `focused/results.json`: seven focused programs, all exit 0. These cover the
  contextual tutorial, guided integration, map/tooltip/badge/wallet/event checks,
  run-end recap, event view, event rules (`--rules-only`) and probe logic.
- `before/main_enemy_intent.log`: `PTF04 ENEMY INTENT: 0 failures (1918 checks)`.
- `before/main_tooltip_consistency.log`: `PTF04 TOOLTIP CONSISTENCY: 0 failures (72 checks)`.
- `before/departed_run_cleanup_test.log`: three cases, empty errors, zero orphans.

Programs failing on this branch but not caused by this unit: only the initial
cold-cache clock partition failure above. After cache restoration, no listed
program remains failing. The listed combined-only failures require integration
or their owning units; no test assertion was weakened here.
