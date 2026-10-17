# cbt-01 implementation handoff

Changes are intentionally uncommitted on `codex/cbt-01`. No review, publication,
queue updates, or inspection-fixture preparation was performed by this worker.

## Files changed

- Runtime: `scripts/combat_engine.gd`, `scripts/run_scene.gd`,
  `scripts/card_stay_rules.gd`, `scripts/movement_target_keyboard.gd`.
- Data/specification: `data/cards.json`, `data/glossary.json`, `spec/analytics.md`.
- Focused validation: `tests/suites/cbt_01_suite.gd`, `tests/cbt_01_test.gd`,
  `tests/cbt_01_probe.gd`, `tests/cbt_01_enclosed_test.gd`,
  `tests/proof_contracts/cbt_01.json`, `tests/run_tests.gd`,
  `tests/fixtures/cbt_01_presentation_scene.gd`.
- Affected existing validation: `tests/suites/card_pool_overhaul_suite.gd`,
  `tests/suites/card_targeting_audit_suite.gd`, `tests/move_attack_shortcut_probe.gd`,
  `tests/action_step_tracker_probe.gd`, `tests/click_first_combat_probe.gd`,
  `tests/steam_deck_compat_probe.gd`, `tests/runtime_frame_performance_benchmark.gd`,
  `tests/combat_action_cpu_attribution.gd`, `tests/text_budget_test.py`.
- Handoff: `tests/cbt_01_handoff.md`.

## Acceptance criteria

1. **Stay eligibility:** `card_stay_rules.gd` detects non-movement actions and
   movement-attached effects/rewards. `card_play_actions()` stamps eligibility on
   the actual card's Move/Blink actions. Pure movement and independent movement
   have no Stay target.
2. **Pointer:** the engine appends the hero tile to ordinary destinations, so the
   existing board highlight applies. Hover uses the existing board chip with the
   exact label `Stay`; the board shows the information-safe automatic support
   effects. The existing click resolver commits that tile and continues the card.
   Hover reuses the existing movement-only continuation, including later riders
   after an omitted attack (Riposte Lunge's Retaliate has a focused regression).
3. **Keyboard/controller:** existing target order is retained. Keyboard arrows
   use the existing board cursor; Enter and controller A use the target-click
   resolver. Headless integration checks use real key/button events.
4. **Rules:** the engine resolves Stay before movement/arrival hooks. It does
   not dispatch walk/Blink presentation or pay movement Bleed, traverse, paint trails, trigger traps/Skate, or run
   movement relics. Only the starting-state reward attached to the action is
   retained; Hotfoot grants 4 Block/draw 1 when the activation began on Fire.
   Immobilized actions retain their previous availability rules. Tests include
   actual-movement positive controls and limited-Umbra preview safety.
5. **Skip Step removal:** the dead method, handler, controller label/branch, and
   tutorial spotlight path were removed. Related tests/probes no longer call
   them; benchmark walks stop when no interaction target remains.
6. **Glossary:** Move and Blink each append exactly
   `Pick your own tile to stay put.`
7. **Analytics:** the resolver's monotonic `card_stay_sequence` records actual
   Stay decisions; RunScene and headless playtests both merge `stayed: true` only when it advances.
   Zero net distance from walking away and back does not report Stay. Documented
   in `spec/analytics.md`; previews write no events.

**Immolation:** the description and first AoE action exactly match the brief;
original Detonate is unchanged and Empower modifies action 1. The neutral score
is **3.00**. The existing adjacent Fire test now expects 3 + 8 damage. Detonate's
ordinary splash remains unchanged, including splash onto neighboring enemies.

## Verification

Observed results (logs are outside repository artifacts; no windowed commands
were attempted):

| Check | Exact result | Log |
| --- | --- | --- |
| Focused engine/UI integration | `CBT-01 TESTS: PASS (0 failures)` | `/tmp/cbt-01-focused.log` |
| Probe semantics, headless `--logic-only` | `CBT-01 PROBE: PASS (0 failures)` | `/tmp/cbt-01-probe-logic.log` |
| UI identity lint | `Ran 25 tests` / `OK` | `/tmp/cbt-01-ui-lint.log` |
| Original full Python run | `Ran 617 tests in 576.473s` / `FAILED (failures=3, skipped=61)` | `/tmp/cbt-01-python.log` |
| Focused current copy/budget checks | `Ran 6 tests in 0.053s` / `FAILED (failures=1)` (Move 22 > 20) | `/tmp/cbt-01-text-budget.log` |
| Untouched art replay | `Ran 1 test in 13.109s` / `FAILED (failures=1)` | `/tmp/cbt-01-art-baseline.log` |
| First full Godot run | `PROGRAM SUITE en03_enemies_test: PASS`, then `error: command timed out after 900 seconds.` (exit 124) | `/tmp/cbt-01-godot-full.log` |
| Final full Python run | `Ran 617 tests in 492.001s` / `FAILED (failures=2, skipped=61)` | `/tmp/cbt-01-python-final.log` |
| Intermediate Godot run (superseded by continuation fix) | `FULL SUITE RUNTIME: 854.067 seconds (budget 900 seconds)` / `TEST RESULT: FAIL (1 failure(s))` (old enclosed auto-skip expectation) | `/tmp/cbt-01-godot-final.log` |
| Intermediate Godot run (before presentation guard) | `FULL SUITE RUNTIME: 878.643 seconds (budget 900 seconds)` / `TEST RESULT: FAIL (1 failure(s))` (same old enclosed auto-skip expectation) | `/tmp/cbt-01-godot-verified.log` |
| Full Godot run before enclosed-regression update | `FULL SUITE RUNTIME: 874.589 seconds (budget 900 seconds)` / `TEST RESULT: FAIL (1 failure(s))` (same old enclosed auto-skip expectation) | `/tmp/cbt-01-godot-complete.log` |
| Final full Godot run | `FULL SUITE RUNTIME: 849.272 seconds (budget 900 seconds)` / `TEST RESULT: PASS` (exit 0) | `/tmp/cbt-01-godot-acceptance.log` |
| Enclosed Stay integration | `CBT-01 ENCLOSED TEST: PASS (0 failures)` | `/tmp/cbt-01-enclosed.log` |

The original Python run reported two glossary-source mismatches and the art
replay mismatch. The updated text test recognizes the exact new approved
sentence while preserving the existing 20-word limit; its sole remaining
copy/budget failure is the named design TODO below.

JSON parsing passed for cards, glossary and proof contract. A HEAD comparison
also verified only Immolation changed in `cards.json`, with its original
Detonate dictionary identical. `output_gdignore.py --check` and
`git diff --check` passed. Both touched-card and full-pool heuristics ran;
Immolation's observed score changed 2.24 → 3.00.

The completed intermediate Godot run found one obsolete expectation that an
unavailable Move on enclosed Guarded Step auto-skips. The updated regression
requires an explicit hero-tile Stay target, then confirms the card applies Block
and is consumed. The focused enclosed runner passed. Its combat fixture now
enters combat mode before exercising real input, rather than testing only a
preview query. This changes the test to the brief's intended behavior; no
pre-existing failing assertion was relaxed.

An attempted termination of an obsolete test runner was sandbox-denied:
`kill 224 failed: operation not permitted`. The process was left to finish with
its original 900-second limit; no escalation or alternate process control was
used.

Headless `--check-only` exited 0 for the updated action-step, click-first,
Steam Deck compatibility and move-attack shortcut probes. The performance
benchmark and its dependent CPU-attribution script retain the pre-existing
parse failure documented below.

## Proof for the design owner

One real-renderer invocation captures both requested states at 1920x1080, 100%:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/cbt-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id cbt-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/cbt_01.json --result-manifest /private/tmp/labyrinth-inspection-manifests/cbt-01-visual.json tests/cbt_01_probe.gd
```

Capture paths (the runner prints their absolute isolated-home location):

- `user://probes/cbt_01/1920x1080_ui100/guarded_step_stay_hover.png`
- `user://probes/cbt_01/1920x1080_ui100/immolation_no_fire_preview.png`

The script asserts Stay chip/Block preview and no-Fire innate damage before
saving. The proof contract requires both captures, exact dimensions, and the
existing board-region luminance thresholds. It still needs the owner's visual
inspection; headless semantics do not substitute for rendered proof. Inspection
fixtures and independent review remain assigned to the owner.

## TODO_DESIGN

`TODO_DESIGN_MOVE_GLOSSARY_WORD_BUDGET`: appending the required exact sentence
makes Move's definition **22 words**, against the existing **20-word** cap.
Blink is exactly 20 words. `tests/text_budget_test.py` recognizes the brief's
approved sentence over the older UX-04 copy, retains the original cap, and emits
this named failure. The design-owner source artifact was not rewritten. Neither
Move nor Immolation was shortened, and no budget was increased.

## Chosen defaults

All new defaults are test/proof-only named fields:

- `FIXTURE_SEED = 90101`, `FIXTURE_GRID_SIZE = (9, 7)`, `HERO = (4, 3)`;
  `FIXTURE_PLAYER_HP = 30`, `FIXTURE_ENEMY_HP = 40`.
- Fixture dictionary fields use room coordinate `(1, 0)`, depth 1, existing
  `Cinder Crossing`/Crawler/stone/wall identities, enemy ids 1/2 at one/two tiles
  east with initiative 9, a trap id 90 with damage 6, and test Bleed 2. The deck
  contains the tested card and Brace, with Quick Stab/Brace available to draw.
- `KEYBOARD_APPROACH_OFFSET = (-1, -1)`, `SETTLE_FRAMES = 3`, and the standard
  invalid target `NO_TARGET = (-1, -1)`.
- `PROOF_SIZE = (1920, 1080)` and `PROOF_SCALE = 1.0` are mandated by the brief.
  `PROOF_OUTPUT` names only the isolated capture destination. Contract pixel
  checks reuse the existing `[420,170,1080,610]` board region with luminance range
  75 and standard deviation 10.

## Open issues

- Renderer screenshots could not be produced in this sandbox; run the command
  above and inspect both captures.
- `parallel_task.py status` reported empty acceptance/proof/inspection fields
  (`contract_ready: false`), despite the bootstrap described in the brief. The
  worker did not alter the owner's task metadata or rerun Git preflight.
- The full Python suite and a focused replay both reproduced the untouched art
  job mismatch in `spec/art_identity/jobs/frostglass_lancer/mq4_rear`:
  actual `7879c813af25b39f68fd4084275d1e239dd873e09bc551145a285c00948031e7`,
  approved `a74bc9cdd606bc813de6535235524f89ec5cc488bfd8d51ab9d0119b5fe47288`.
  The test, art tool, and job files are unchanged from HEAD; the assertion and
  approved pixels were left untouched.
- Compile-only checks found the existing benchmark failure:
  `Identifier "GameData" not declared in the current scope` at
  `tests/runtime_frame_performance_benchmark.gd:2018`. The unchanged HEAD version
  reproduced it in `/tmp/cbt-01-baseline-benchmark.log`. The dependent
  `combat_action_cpu_attribution.gd` cannot resolve that class. No unrelated
  benchmark code/assertions were changed to hide this failure.
