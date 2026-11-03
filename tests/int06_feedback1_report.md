# int-06 feedback 1 — raw Lob inspection

Round 0 remains accepted at `45b673ad8`. This follow-up fixes the enc-04 raw-action formatter crash. Changes remain uncommitted; no peer review, publication, full suite or windowed run was performed.

## Cause and acceptance

Pre-battle known moves passed the raw `lob_mark` catalog action to `ActionIcons.rows_for_actions`. That action intentionally lacks damage fields: the landing resolver supplies them. The numeric token therefore read a missing `center_damage` key, and its text-only summary also omitted arm damage.

| Director requirement | Implementation and proof |
|---|---|
| Resolve known Lob moves before formatting; match the board | `Lob.presentation_intent` installs the inspected move on a private combat snapshot and calls `presentation_action`. A not-yet-revealed landing forecasts its marking move with the production planner, including captain retreat and clipped crosses. Both phases use resolved centre/arm values; a revealed landing retains its saved damage and held cross count. |
| Never crash on a raw pre-battle action | Inspection resolves each Lob intent before `build_move`. The existing roster test also covers ID-less definition records without inventing an actor position. Non-Lob moves keep their existing path. |
| Audit compass, intent badges, Grimoire and tooltips | Compass now sends both Lob phases through `presentation_action`. Intent-badge build and projected attacks already do so. Board rows, callouts and tile tooltips use `LobView`'s resolver; playback captions use the resolved action and committed geometry carried by the combat step. Grimoire and pre-battle threat tags read only the glossary/icon identity, with no Lob damage formatting. Card/action-step formatters have no Lob data input; Mimic copies supported player attacks and Refraction has its own non-Lob action. |
| Show centre and arm values in the inspection | The Lob token's plain-text override reuses the exact existing `lob_text` sentence. The numeric badge still displays centre damage. No new wording, layout, art or tuning is introduced. |
| Regression must fail before the fix, one and two crosses | `int06_lob_inspection_cases.gd`, reached by the registered pre-battle semantics driver, checks both phases against the board's exact copy at the existing depth-6 and depth-18 bands, one and two crosses. It starts with Brace declared, then separately checks held landings after a changed scaling context. State, declared intent and RNG must remain unchanged. Before the fix the test logs the original `center_damage` crash and `PRE-BATTLE SEMANTICS TEST: FAIL`. |

## Files changed

- `scripts/enemy_mechanics/lob.gd`: known-move presentation resolver.
- `scripts/pre_battle_inspection_view.gd`: route known intents through that resolver.
- `scripts/action_icon_library.gd`: preserve existing full Lob copy on text-only surfaces.
- `scripts/enemy_intent_compass.gd`: resolve both Lob phases.
- `tests/helpers/int06_lob_inspection_cases.gd`: regression cases.
- `tests/pre_battle_semantics_test.gd`: execute the cases; `--lob-only` isolates the regression reproduction.
- `tests/int06_feedback1_report.md`: this evidence and handoff.

## Focused proof

All logs are under `/private/tmp/labyrinth_codex/int-06/r1/`. The red reproduction is `regression-before.log`; the initial green regression-only run is `regression-after.log`.

| Focused test | Exact result line | Log |
|---|---|---|
| Warband UI, including pre-battle captain inspection | `Warband UI semantics: 0 failures` | `warband_ui.log` |
| Pre-battle semantics, including the new regression and original roster/UI cases | `PRE-BATTLE SEMANTICS TEST: PASS`; `TEST RESULT: PASS` | `pre_battle_semantics.log` |
| enc-03 Slag mechanics and formatters | `ENC03 SLAG TEST: PASS (730 checks; 0 failures)` | `enc03_slag.log` |
| enc-03 production fixture and enc-04 playback, check-only/headless | `ENC03 LOB PROBE: PASS (5 states; 0 failures)` | `enc03_fixture.log` |
| enc-04 forecast matrix | `ENC04 FORECAST TEST: PASS (128 configurations; 1354 checks; 0 failures)` | `enc04_forecast.log` |
| Lob/en-04 enemy formatters and mechanics | `EN04 ENEMIES TEST RESULT: PASS (420 checks, 0 failures)` | `en04_enemies.log` |

The final logs contain no script/assertion failures. Godot prints the existing macOS certificate diagnostic `get_system_ca_certificates` in these headless launches; the task runner accepts the completed tests. `git diff --check` also passes.

Every Godot command uses this prefix:

```sh
python3 tools/godot_task_runner.py --task-id int-06 --stream -- godot --headless --path . --script
```

The script arguments are `tests/warband_ui_test.gd`, `tests/pre_battle_semantics_test.gd`, `tests/enc03_slag_test.gd`, `tests/enc03_fixture_test.gd`, `tests/enc04_forecast_test.gd`, and `tests/en04_enemies_test.gd`. The red/green isolated regression appends `-- --lob-only` to the pre-battle driver.

## TODO_DESIGN, chosen defaults and open issues

No TODO_DESIGN placeholders. No new player-visible defaults. The regression's named `TEST_DEPTHS=[6,18]` reuses enc-03's existing proof bands; its other fixtures reuse existing enemy and Warband suites. No test thresholds or engine timeouts were changed. No new Python test module or dependency was added.

No windowed proof or inspection-fixture command is required for this focused correction; no capture was generated. Both full suites remain assigned to the director at merge, as requested in feedback 1.

Open issues: none in this follow-up. Focused failure list: empty.
