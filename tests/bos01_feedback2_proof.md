# bos-01 feedback 2 handoff

Changes are uncommitted on `codex/bos-01`, based on reviewed HEAD `73ddd1338`.
No encounter data, approved fixture sentences, art, tuning or input paths were changed.

## 1. Committed acceptance owns the half-Health switch

`HalfHealth.check` has one production caller: `scripts/battlefield_rules/committed.gd:accept`.
The damage resolver, Wind cleanup, rule forecasts and Gust previews have no switch hook or preview marker.
The marker constant and all marker writes/cleanup were removed. No transient context is stored in combat state.

The acceptance helper records the switch event in the accepted action's existing surface/analytics event stream.
GUI and console card commits accept each selected action before the next one; accepted enemy activations use the
same callback after each complete action and before the following action/beat. Within an action, all hits, forced
movement, statuses and reactions retain the old dials. Accepted activation preparation and beats use that same
boundary before further actions. The existing beat counter, latch and source lifetime remain intact.

For a declared half-Health rule, a committed card replays its selected action/target plan from the original board,
accepting actions in order. Other fights retain the existing pre-resolved card commit path. The measurement bot
retains its selected targets in an outer candidate plan and accepts only the chosen plan; candidate scoring and
ordering are unchanged. Candidate metadata is never merged into a combat snapshot or save.

Enemy resolver APIs accept an optional live acceptance callback. Raw resolver/query callers pass none. This is
not preview context: the default resolver remains pure with respect to switching, and only actual live clients
supply the commit acceptance point. Presentation replay uses accepted action snapshots so the panel/clock can
show the replacement before the next presented action; the cursor still suppresses duplicate banners.

The six-rule regression uses hero `(5,5)`, source `(5,4)`, source Health `26/50`, and a 2-damage melee hit:

- Engine hover, provisional resolution, activation forecasts, on-intent turn-clock checks and PASS previews keep
  the old dials/cadence/sentence, emit no switch event and do not latch.
- Production hover and provisional card targeting cover all six rules too.
- At-rest wind queries are exercised with live/pending wind. Observed private boards never switch; a source that
  dies on a private prediction may legitimately clear its rule. The saved input and Gust's held Up direction remain
  unchanged. Existing pending Call announcements retain their separate projection behavior.
- The same hit through committed acceptance switches all six rules.
- A multi-hit hero action observes `[false,false]` for its two hits, then the next action observes `true`.
- An enemy action crossing half through Bleed keeps its old dials through that action, then its second action and
  the following beat see the switched cadence.

The reviewer's original reproduction script was also run unchanged through the task runner. Its six hover rows,
production hover/targeting and PASS rows report `switched=false`, `switch_events=0`, unchanged cadence and the
original held Gust direction. Log: `/private/tmp/labyrinth_codex/bos-01/feedback2-review-reproduction.log`.

## 2. Fresh-scene Continue coverage

The production scene test explicitly commits a switch, writes a run save, reloads it, verifies it contains the
latch/event, then loads it into a newly instantiated production scene whose helper has never observed the event.
The switched sentence survives and no fiercer banner replays. Removing `_load_run_state`'s Continue baseline
fails this test. The earlier back-to-back live-fight coverage remains.

## Changed files

- New `scripts/battlefield_rules/committed.gd` and its `.uid`: one switch acceptance point and live action/card/beat/
  activation adapters.
- `scripts/battlefield_rules/{dispatcher,gust,half_health}.gd`: remove resolver switch/marker behavior and connect
  accepted beats. `switch_presentation.gd`: redraw from the accepted displayed action state.
- `scripts/combat_engine.gd`: action/start/end/beat acceptance callbacks between complete actions.
- `scripts/run_scene.gd`, `tools/headless_playtest.gd`, `tools/encounter_bot.gd`: actual GUI, console and chosen bot
  transitions use acceptance; their query paths keep using raw resolvers.
- `spec/peer_benchmark/element_rules/design.md`, `spec/analytics.md`: document the committed action timing and absence
  of preview state.
- New `tests/suites/bos01_feedback2_suite.gd` and `.uid`: six-rule preview matrix, committed positives, action timing.
- `tests/bos01_rule_scene_test.gd`: production preview paths and a switched save loaded into a fresh scene.
- `tests/suites/bos01_rules_suite.gd`, `tests/suites/bos01_feedback1_suite.gd`, `tests/bos01_rules_probe.gd`: existing
  committed fixtures now explicitly cross acceptance; their existing assertions remain.
- `tests/helpers/{turn_clock_round_engine,fix_15_resolver_recorder}.gd`: forward the added optional callback parameters.
- `tests/bos01_rule_mutations.py`: replace marker mutation with a resolver-hook mutation, add fresh Continue mutation.
- This file: `tests/bos01_feedback2_proof.md`.

## Observed verification

All Godot commands used `python3 tools/godot_task_runner.py --task-id bos-01 --stream -- godot --headless --path . --script <script>`.
The mutation controls reran mechanics and production-scene checks after restoring every source byte.

```text
BOS01 RULES TEST RESULT: PASS (380 checks, 0 failures)
BOS01 RULE SCENE RESULT: PASS (122 checks, 0 failures)
BOS01 MUTATION RESULT: PASS (10/10 killed; controls pass; exact sources restored)
BATTLEFIELD RULES TEST RESULT: PASS (591 checks, 0 failures)
Warband suite: 0 failures
WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)
SPX07 WIND LOCK RESULT: PASS (114 checks, 0 failures)
Snare suite: 0 failures
ELEMENT RETROFIT TEST RESULT: PASS (939 checks, 0 failures)
TURN CLOCK HUD TEST RESULT: PASS
EL04 RULE VIEWS RESULT: PASS (0 failures)
BOS01 PROBE CONTRACT: PASS (3 fixture fights, 6 captures, 1920x1080, UI scale 100%)
```

These correspond to `tests/bos01_rules_test.gd`, `tests/bos01_rule_scene_test.gd`, the mutation driver,
`tests/battlefield_rules_test.gd`, `tests/warband_test.gd`, `tests/warband_orders_test.gd`,
`tests/warband_wind_lock_test.gd`, `tests/snare_test.gd`, `tests/element_retrofit_test.gd`,
`tests/turn_clock_hud_test.gd`, `tests/el04_rule_views_test.gd` and `tests/bos01_rules_probe.gd -- --check-only`.

`tests/surface_preview_equivalence_test.gd` exited 0 and its JSON result had `"semantic_errors":[]`.
The UI identity lint ran 25 tests, `OK`; the binding element-rule contract ran 2 tests, `OK`.

```text
ISOLATION AUDIT: 227 modules; /private/tmp/labyrinth_codex/bos-01/feedback2-python-audit/isolation-audit.md
TEST REGISTRATION AUDIT: PASS (877 scripts; full suite=516, quarantined=29, windowed probe=332)
BOS01 F2 SIDECAR CHECK: PASS (new GDScripts have stable UIDs)
```

No new Python discovery module was added. The isolation check used `--shards 4 --audit-only`; no full suites ran.
`git diff --check` returned exit 0, no output. The new script UIDs were generated by Godot without an editor scan.
Headless runs emitted the existing macOS certificate diagnostic. The el04 check also emitted an ObjectDB teardown
warning while exiting 0; the new scene/mutation controls have no script errors.

## Mutation proof

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tests/bos01_rule_mutations.py --log-dir /private/tmp/labyrinth_codex/bos-01/feedback2-mutations
```

All ten mutations are caught: rotation, late toward-source aim, repeated switch, reset counter, structural line
guard, objective-exit guard, post-displacement guard, switch restored inside the damage resolver, fresh Continue
baseline removal, and previous-fight banner cursor retention. The resolver-hook mutant specifically fails the
six-rule hover regression. Fresh Continue baseline removal fails the fresh production-scene assertion. Both
controls pass after exact byte restoration. Logs include the final 380-check and 122-check controls.

## Measurement failure on reviewed bos-01 HEAD (superseded diagnosis)

Correction from feedback 3: the comparison below used a bos-01 HEAD, not the integration baseline, so it did
not establish a pre-existing failure. The original integration reference passes. The complete field diff and
fix are recorded in `tests/bos01_feedback3_proof.md`: two default false event fields were unintended; one
Briar Weaver `line_between` mark is intentionally skipped by the generic route guard.

The additional `tests/encounter_measurement_test.gd` run reported:

```text
FAIL: pre-change golden maps, rooms, combat transitions and save roundtrips match
ENCOUNTER MEASUREMENT: FAIL (2662 checks; 1 failures)
```

Its run-save checks, small sweeps, bot defense/dodge, Skybolt overrides and determinism checks passed. The frozen
golden assertion was left untouched. A focused comparison temporarily loaded the reviewed HEAD source bytes,
ran only the same golden computation/normalizer, restored the exact working bytes, and ran the current computation.
Both disagree with the frozen expected fixture, and both produce identical output:

```text
BOS01 GOLDEN reviewed_HEAD EXIT: 1
BOS01 GOLDEN working_changes EXIT: 1
BOS01 GOLDEN HEAD/CURRENT OUTPUTS IDENTICAL: True
```

Evidence: `/private/tmp/labyrinth_codex/bos-01/feedback2-golden/{reviewed_HEAD,working_changes}.{json,log}`.
No branch, index, assertion or golden fixture was changed by that comparison.

## Chosen defaults, design placeholders and remaining proof

All new values are test-only constants/dictionary fields: the reviewer's exact Health/positions/hit; initial cadence
3 replaced by 2; Gust clockwise/2 tiles, Wildfire all, Frostbite damage 0, Lightning chain 2, Upheaval health 4,
Shadowstep blink 2; a two-target hero hit at offsets `(0,-1),(1,0)` with a 50-Health helper at `(6,5)`; enemy Bleed 2
then Block 1 at the existing fixture Time 4; and a private `user://bos01-fresh-continue.save` file removed after the
fresh-scene test. These values make the mutation observable and do not tune encounters.
The provided fixture half-Health sentence remains unchanged. No new `TODO_DESIGN` placeholder was introduced.

The two assigned findings are implemented and covered. Rendered proof remains director-owned; no windowed run,
reviewer agent, commit, push or publication was performed. Existing exact capture/interactive commands remain in
`tests/bos01_proof.md`, with output under `user://probes/bos01/`. Feedback 3 resolves the measurement golden mismatch
and authorizes both full suites; its proof addendum records those results.
