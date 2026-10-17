# cbt-01 feedback 2 handoff

Base: `ef8a46144`, branch `codex/cbt-01`. This revision changes only
`tests/suites/cbt_01_suite.gd` and this handoff; changes remain uncommitted.
No production code, data, assets, probe or proof contract changed.

## Cancellation and reselection regression

The live suite first keyboard-targets Stay and verifies settled focus on `(4,3)`.
It sends Escape, checks the card is deselected without committing combat state,
and requires the keyboard ownership metadata to be removed. It then reselects
Guarded Step through the card handler, without a mouse event or new keypress.
After ten physics frames and three process frames, keyboard ownership must stay
inactive and both rendered controller focus and scene hover must stay invalid.
A new keypress then restores the hero focus, arrow and Stay preview before the
existing Enter-confirm test continues.

Removing only the cleanup in `_clear_active_card_preview_state()` was tested:
`CBT-01 TESTS: FAIL (3 failures)`, exit 1. All three failures match the reviewer's
cancellation/reselection experiment. Production was restored byte for byte,
then the focused suite was rerun successfully.

## Focused verification

| Check | Exact result | Log |
| --- | --- | --- |
| Focused suite after restoring production | `CBT-01 TESTS: PASS (0 failures)` | `/tmp/cbt-01-feedback2-focused.log` |
| Cleanup-removal mutation | `CBT-01 TESTS: FAIL (3 failures)` (expected) | `/tmp/cbt-01-feedback2-mutation.log` |
| Enclosed Stay integration | `CBT-01 ENCLOSED TEST: PASS (0 failures)` | `/tmp/cbt-01-feedback2-enclosed.log` |
| Headless probe semantics | `CBT-01 PROBE: PASS (0 failures)` | `/tmp/cbt-01-feedback2-probe-logic.log` |
| UI identity lint | `Ran 25 tests in 3.182s` / `OK` | `/tmp/cbt-01-feedback2-ui-lint.log` |
| Copy budgets | `Ran 6 tests in 0.070s` / `OK` | `/tmp/cbt-01-feedback2-text-budget.log` |
| Output import hygiene | `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)` | `/tmp/cbt-01-feedback2-output-ignore.log` |

The full suites were not rerun, as requested for this test-only revision.
The delta review accepted the director's fresh three-image renderer proof;
no new windowed capture was requested or attempted. No new TODO_DESIGN
placeholder, chosen default or open issue was introduced. The prior unrelated
Python art replay failure remains documented in the historical record below.

---

The following is the feedback 1 record. Its pending-renderer note was resolved
by the director's accepted capture run before feedback 2.

# cbt-01 feedback 1 handoff

Base: `5e20c1099`, branch `codex/cbt-01`. All feedback changes are uncommitted.
The worker did not commit, publish, alter the queue, prepare an inspection
fixture, or run a peer review. Director captures already supplied under
`output/cbt-01/director_r0/` were inspected; their files were preserved.

## Files changed

- `scripts/movement_target_keyboard.gd`: keyboard focus ownership, geometry
  refresh, and release on pointer/controller activity or selection reset.
- `scripts/run_scene.gd`: five integration points for that helper; net four
  additional lines, outside the opening-boon overlay region.
- `tests/suites/cbt_01_suite.gd`: physics-frame focus/arrow regression, input
  handoff checks, and successive-Stay analytics with serialized replay.
- `tests/cbt_01_probe.gd`: settled keyboard capture and real mouse placement.
- `tests/proof_contracts/cbt_01.json`: require all three captures.
- `tests/cbt_01_handoff.md`: this current handoff and reproduction commands.

## Feedback acceptance

1. **Keyboard focus across frames:** arrow-key navigation reaches `(4,3)` in
   keyboard/pointer modality. After ten physics frames and three process frames,
   the regression requires the scene hover and rendered board focus to remain
   on `(4,3)`, the Stay chip and Block preview to remain present, and the visible
   targeting arrow to end on the hero. Only then does Enter commit Stay.
   The helper refreshes the endpoint as existing board layout settles. Neutral
   joystick noise preserves keyboard focus; mouse input releases it. Completing
   the card clears keyboard ownership. Controller A still resolves Blink Stay.
2. **Renderer probe:** `guarded_step_stay_keyboard.png` is captured after the
   same ten-physics-frame wait and focus/arrow assertions. Pointer proof waits
   for the existing centering tween, warps the real OS cursor onto the hero tile,
   and forwards the position into the capture viewport. It also asserts the
   pointer arrow endpoint. The previous Stay hover and no-Fire Immolation
   captures remain required at 1920x1080 and UI scale 1.0. Fresh windowed proof
   is assigned to the director; no windowed launch was attempted in this sandbox.
3. **Successive-Stay analytics:** two distinct Guarded Step card plays each
   finish their card and must report `stayed: true` in both the live event
   payload and shared headless summary. The sequence must advance from 0 to 1
   to 2. The same pair is replayed through the production-compatible Variant
   serialization codec, including a snapshot between the two plays; both states
   and both payloads must exactly match the live pair. The reset-to-1 mutation
   was executed and caught, then the resolver was restored byte for byte.

The previous Stay/Immolation behavior remains covered by the focused suite.
Immolation's current heuristic score is **3.00**. No card, glossary, protected
source data, balance number, art, font, or audio changed in this feedback pass.

## Verification

| Check | Exact observed result | Log |
| --- | --- | --- |
| Focused engine/UI integration | `CBT-01 TESTS: PASS (0 failures)` | `/tmp/cbt-01-feedback1-focused.log` |
| Enclosed Stay integration | `CBT-01 ENCLOSED TEST: PASS (0 failures)` | `/tmp/cbt-01-feedback1-enclosed.log` |
| Probe semantics, headless `--logic-only` | `CBT-01 PROBE: PASS (0 failures)` | `/tmp/cbt-01-feedback1-probe-logic.log` |
| Sequence-reset mutation | `CBT-01 TESTS: FAIL (6 failures)`; second live and serialized `stayed` assertions fail, expected exit 1 | `/tmp/cbt-01-feedback1-mutation.log` |
| UI identity lint | `Ran 25 tests in 2.753s` / `OK` | `/tmp/cbt-01-feedback1-ui-lint.log` |
| Copy/budget checks | `Ran 6 tests in 0.053s` / `OK` | `/tmp/cbt-01-feedback1-text-budget.log` |
| Output import hygiene | `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)` | `/tmp/cbt-01-feedback1-output-ignore.log` |
| Full Godot suite | `FULL SUITE RUNTIME: 867.657 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; wall time **873.348s**, exit 0 | `/tmp/cbt-01-feedback1-godot-full.log` |
| Full Python suite | `Ran 617 tests in 518.866s` / `FAILED (failures=1, skipped=61)`; wall time **519.449s**, exit 1 | `/tmp/cbt-01-feedback1-python-full.log` |

Focused commands (all run from this worktree):

```bash
python3 tools/output_gdignore.py
python3 tools/godot_task_runner.py --task-id cbt-01 --stream -- godot --headless --path . --script tests/cbt_01_test.gd
python3 tools/godot_task_runner.py --task-id cbt-01 --stream -- godot --headless --path . --script tests/cbt_01_enclosed_test.gd
python3 tools/godot_task_runner.py --task-id cbt-01 --stream -- godot --headless --path . --script tests/cbt_01_probe.gd -- --logic-only
python3 tests/test_ui_identity_lint.py
python3 tests/text_budget_test.py
python3 tools/card_heuristic.py --card-id immolation
```

Full-suite commands, measured with a monotonic wall clock:

```bash
python3 tools/godot_task_runner.py --task-id cbt-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Proof for the design owner

Run this exact windowed command from the task worktree:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/cbt-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id cbt-01 --expect-size 1920x1080 --proof-contract tests/proof_contracts/cbt_01.json --result-manifest /private/tmp/labyrinth-inspection-manifests/cbt-01-feedback1-visual.json tests/cbt_01_probe.gd
```

The runner prints the isolated absolute output directory. Required files:

- `user://probes/cbt_01/1920x1080_ui100/guarded_step_stay_hover.png`
- `user://probes/cbt_01/1920x1080_ui100/guarded_step_stay_keyboard.png`
- `user://probes/cbt_01/1920x1080_ui100/immolation_no_fire_preview.png`

Already supplied and inspected, before this fix:

- `output/cbt-01/director_r0/guarded_step_stay_hover.png`
- `output/cbt-01/director_r0/immolation_no_fire_preview.png`

The headless probe run validates semantics and writes no screenshots.
Inspection-fixture preparation and visual review remain assigned to the owner.

## TODO_DESIGN placeholders

None introduced by this feedback pass. The baseline's approved glossary copy
passes the existing word-budget checks.

## Chosen defaults

Only new test/proof values:

- `KEYBOARD_SETTLE_PHYSICS_FRAMES = 10`: required minimum settled-focus sample.
- `ARROW_ENDPOINT_TOLERANCE_PX = 1.0`: assertion tolerance for subpixel layout
  changes between physics and rendering; not a production positioning value.

All existing fixture values, proof dimensions, UI scale and image-region
thresholds were retained. `FOCUS_META` is an internal ownership key, not tuning.

## Open issues

Fresh keyboard renderer capture must be rerun by the director using the command
above. The full Godot suite passed; the full Python suite has the existing art
replay failure below.

The full Python suite reproduces the pre-existing approved-pixel replay failure
for `spec/art_identity/jobs/frostglass_lancer/mq4_rear`:

- Actual: `7879c813af25b39f68fd4084275d1e239dd873e09bc551145a285c00948031e7`
- Approved: `a74bc9cdd606bc813de6535235524f89ec5cc488bfd8d51ab9d0119b5fe47288`

The job, art tool and assertion are unchanged from reviewed HEAD `5e20c1099`.
The same mismatch was observed in the earlier baseline replay log
`/tmp/cbt-01-art-baseline.log`. No art or assertion was changed to hide it.
