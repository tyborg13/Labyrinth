# bos-01 feedback 1 implementation proof

Revision under review: `adad4e1ae`. Changes remain uncommitted on `codex/bos-01`.
The director owns the queued rendered proof. No windowed run, peer review, commit or publication was performed here.

## Assigned findings

1. **Announced Gust direction / preview switches**
   - `dispatcher.gd` saves the announced direction before the private resolver and returns that saved value.
   - Rule forecasts and the Gust primitive preview mark their owned copies with `HalfHealth.PREVIEW_KEY`.
     The damage-boundary switch refuses these copies, leaving dials, cadence, held direction and latch unchanged.
     The Gust preview removes its private marker before returning a standalone result.
   - The exact source `(5,5)`, hero `(5,2)`, 26/50-HP source moved to `(5,9)` case now forecasts and resolves Down.
     Collision takes the source to 24 Health by the existing 2-damage primitive. Only the committed beat switches.
     A test engine observes the private preview at the damage boundary to verify that the switch was not simulated.
   - Landing assertions independently verify that hero movement after announcement cannot relock the Gust. This also
     keeps the original resolution-time-aim mutation effective after the direction-read fix.
   - View collision markers omit the raw event `sequence`: an omitted hypothetical switch changes bookkeeping,
     not the predicted collision. Committed surface events and analytics sequences are unchanged.
2. **Banner cursor across combats**
   - Reset the helper's sequence cursor at the existing normal combat-entry boundary in `run_scene.gd`.
     Continue keeps its `_load_run_state` saved baseline; the banner style, text, timing and cue are unchanged.
   - The production scene test enters two fights without using Continue between them: the first switch is at
     sequence 21, the second at sequence 1. Both show their banner. Continuing the second fight does not replay it.
3. **Independent guard fixtures**
   - A mark at `(5,4)` leaves floor connectivity and source exits intact but blocks the sole declared objective exit.
     Planning skips that mark and retains `(4,4),(6,4)`; resolution also rejects the held exit mark.
   - An eight-cell ring surrounds the wall at `(3,3)`. A source at `(2,2)` is on a held mark with two structural exits.
     Erupt would move it to `(3,2)`, where raising its old tile leaves only one exit. Both rise and displacement
     are rejected. The forecast shows neither a rise nor movement.
   - The mutation driver removes each guard independently and requires its specific assertion to fail.
4. **Shared unweighted path performance**
   - `SnarePressureRules.walking_paths` uses a FIFO cursor when unweighted, retaining the same neighbor loop and
     deterministic parents. Weighted Rubble selection retains Dijkstra's cost/step/discovery tie order.
   - An optional goal dictionary stops at the first reached exit. An all-blocked goal set returns immediately.
     `Upheaval.leaves_exit` calls this shared path; no additional connectivity implementation was added.
   - Tests compare the complete FIFO result to unweighted-cost Dijkstra, verify early exit and blocked-goal
     short-circuiting, and retain the two-cost Rubble departure check.

The original review's rendered-proof finding remains assigned to the director and is outside this feedback pass.

## Files changed

- `scripts/battlefield_rules/dispatcher.gd`, `gust.gd`, `half_health.gd`, `outcomes.gd`, `upheaval.gd`.
- `scripts/run_scene.gd`, `scripts/snare_pressure_rules.gd`.
- `spec/peer_benchmark/element_rules/design.md` documents preview suppression, marker metadata, cursor lifetime and FIFO.
- `tests/suites/bos01_feedback1_suite.gd` and its engine-generated `.uid` contain the regressions and timing fixture.
- `tests/suites/bos01_rules_suite.gd` calls the feedback suite and adds independent held-direction landing assertions.
- `tests/bos01_rule_scene_test.gd` exercises two normal fight entries and a subsequent Continue.
- `tests/bos01_rule_mutations.py` retains the five original mutations and adds four regression mutations.
- This file is `tests/bos01_feedback1_proof.md`.

Production encounter data and the director-provided fixture sentences remain untouched. No new design placeholders.

## Verification

Every Godot check used the task runner:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tools/godot_task_runner.py --task-id bos-01 --stream -- godot --headless --path . --script <script>
```

Observed result lines are recorded below; the final mutation controls also rerun the mechanics and production-scene tests.

```text
BOS01 RULES TEST RESULT: PASS (286 checks, 0 failures)
BOS01 RULE SCENE RESULT: PASS (16 checks, 0 failures)
BATTLEFIELD RULES TEST RESULT: PASS (591 checks, 0 failures)
Warband suite: 0 failures
WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)
SPX07 WIND LOCK RESULT: PASS (114 checks, 0 failures)
Snare suite: 0 failures
ELEMENT RETROFIT TEST RESULT: PASS (939 checks, 0 failures)
EL04 RULE VIEWS RESULT: PASS (0 failures)
EN04 ENEMIES TEST RESULT: PASS (353 checks, 0 failures)
BOS01 PROBE CONTRACT: PASS (3 fixture fights, 6 captures, 1920x1080, UI scale 100%)
```

Corresponding scripts: `tests/bos01_rules_test.gd`, `tests/bos01_rule_scene_test.gd`, `tests/battlefield_rules_test.gd`,
`tests/warband_test.gd`, `tests/warband_orders_test.gd`, `tests/warband_wind_lock_test.gd`, `tests/snare_test.gd`,
`tests/element_retrofit_test.gd`, `tests/el04_rule_views_test.gd`, `tests/en04_enemies_test.gd`, and
`tests/bos01_rules_probe.gd -- --check-only`.

Additional observed checks:

```text
python3 tests/test_ui_identity_lint.py: Ran 25 tests / OK
ISOLATION AUDIT: 227 modules; /private/tmp/labyrinth_codex/bos-01/feedback1-python-audit/isolation-audit.md
TEST REGISTRATION AUDIT: PASS (876 scripts; full suite=515, quarantined=29, windowed probe=332)
BOS01 F1 SIDECAR CHECK: PASS (new suite UID present; no collision with tracked UIDs)
```

The Python isolation command was `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir
/private/tmp/labyrinth_codex/bos-01/feedback1-python-audit`. The registration audit wrote
`/private/tmp/labyrinth_codex/bos-01/feedback1-registration.{json,md}`. No new Python discovery module was added.
No full suites were run.

## Mutation and timing evidence

Reproduce the opt-in serial mutation proof with:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tests/bos01_rule_mutations.py --log-dir /private/tmp/labyrinth_codex/bos-01/feedback1-mutations
```

The nine mutations cover clockwise rotation, resolution-time toward-source aim, repeated switch, counter reset,
structural line guard, objective exit guard, post-displacement guard, private preview switch, and combat banner cursor.
Each mutation restores exact source bytes in `finally`. Mechanics and production-scene controls run before and after.
Final observed result/timing lines from the restored controls:

```text
BOS01 MUTATION RESULT: PASS (9/9 killed; controls pass; exact sources restored)
BOS01 F1 64x64 PREPARE: min=90.276 median=95.274 max=103.913 ms (5 samples, five marks, one exit)
BOS01 RULES TEST RESULT: PASS (286 checks, 0 failures)
BOS01 RULE SCENE RESULT: PASS (16 checks, 0 failures)
```

Logs are in `/private/tmp/labyrinth_codex/bos-01/feedback1-mutations/`, including both mechanics and scene controls.
`git diff --check` also returned exit 0 with no output.

The timing fixture is an open 64×64 board with border walls, source `(5,5)`, hero `(32,32)`, exit `(62,62)`, five
line marks and five samples. It measures `Upheaval.prepare`, including both guards and their shared traversal.
The review reported 1.55–1.75 seconds on its synthetic 64×64 fixture; its exact positions were not supplied here,
so this is an explicit new fixture measurement rather than a claimed matched speedup.

## Chosen defaults and remaining proof

All new values are test-only named constants or fixture fields: the benchmark size/samples/positions above, the
ring coordinates from `(2,2)` to `(4,4)`, the first fight's cursor prefix at sequence 20, and the hypothetical
replacement `tiles: 2`, `every: 2` used to verify both dictionaries stay unchanged in preview. The exact reviewed
26/50 Health and source/hero positions are preserved. No player-facing values were selected.

No new `TODO_DESIGN` placeholder was introduced. Rendered captures remain queued with the director. The existing
windowed capture and interactive commands are in `tests/bos01_proof.md`; they were not run or retried here.
Headless runs emitted the existing macOS `get_system_ca_certificates` diagnostic; result exits are reported above.
