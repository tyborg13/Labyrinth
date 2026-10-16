# ux-05 implementation proof

Implementation remains uncommitted on `codex/ux-05`. The design owner owns review,
inspection, commits and publication. No new art, icons, fonts, audio, card data,
combat rules, analytics events or save fields were introduced.

## Acceptance coverage

1. The display-only `CombatPreviewRetention` adapter retains committed enemies,
   illusions, terrain, traps and surface layers. Destroyed actors/objects retain
   their committed positions and durability baseline; resolvers continue using
   the unmodified simulated state. Earlier losses remain in the display while
   aiming a later action.
2. The board reuses the enemy death mark, with its existing pulse and reduced
   motion behavior. Terrain marks are centered on the object. Terrain and
   illusion HP bars show zero fill for lethal previews. Lifetime terrain gains no
   HP bar. Triggered traps reuse the existing stable trigger footprint; consumed
   traps also receive the death mark. Lethal forced movement marks the original
   and its destination ghost, including confirmation/intermediate previews.
3. Consumed committed surface layers remain visible. Their existing AoE preview
   communicates the blast; no surface death mark is added.
4. Committed sight still owns visibility. New trap/illusion damage records and
   trap highlights are filtered against current sight; lethal destination ghosts
   are suppressed at unseen destinations. Probe cases run in clear and heart
   Umbra.

The regression suite covers the Whirlwind Slash 2-HP crate confirmation,
triggered/consumed trap, Shattered Reflection's lethal illusion, a pull that dies
on a destination trap, and an automatic AoE followed by an aimed second action.
It also checks removed/lifetime terrain, consumed/replaced Fire, immutable live
state, and hidden-trap/destination privacy. It is included in the full Godot suite
through `lethal_preview_suite.gd`.

## Headless commands

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tools/output_gdignore.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tools/godot_task_runner.py --task-id ux-05 --stream -- godot --headless --path . --script tests/destruction_preview_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tools/godot_task_runner.py --task-id ux-05 --stream -- godot --headless --path . --script tests/destruction_preview_probe.gd -- --logic-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tools/ui_identity_lint.py check
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tools/godot_task_runner.py --task-id ux-05 --timeout 930 --stream -- godot --headless --path . --script tests/run_tests.gd
```

`--logic-only` checks the actual run-scene selection/hover presentation for all
12 capture cases. It does not capture or claim renderer proof.

Observed headless results:

- Regression against the original HEAD versions of the two runtime scripts:
  `DESTRUCTION PREVIEW TEST RESULT: FAIL (16 failures)` (exit 1). All five required
  cases failed. Log: `/private/tmp/ux-05-focused-before.log`.
- Final focused check: `DESTRUCTION PREVIEW TEST RESULT: PASS (0 failures)`.
  Log: `/private/tmp/ux-05-focused-after.log`.
- Final 12-state scene probe: `DESTRUCTION PREVIEW PROBE: PASS (0 failures)`.
  Log: `/private/tmp/ux-05-probe-logic.log`. No PNGs were captured in this mode.
- `python3 tests/test_ui_identity_lint.py`: `Ran 25 tests in 3.950s`, `OK`.
  `python3 tools/ui_identity_lint.py check`:
  `PASS: UI identity lint (1602 sites within baseline + exceptions)`.
- Full Python discovery (`python3 -m unittest discover -s tests -p 'test_*.py' -v`):
  `Ran 545 tests in 416.919s`, `OK (skipped=61)`.
  Log: `/private/tmp/ux-05-python-suite.log`.
- Final isolated full Godot suite (exit 0):
  `FULL SUITE RUNTIME: 802.969 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`. Log: `/private/tmp/ux-05-full-suite-isolated.log`.
- `OUTPUT GDIGNORE: PASS (12 folders; 2 referenced roots)`; JSON syntax and
  `git diff --check` also passed.

The initial full Godot invocation hit the generic runner default:
`error: command timed out after 300 seconds.` Two subsequent overlapping full
runs printed passing sub-suite results but timed out at 900 seconds before an
aggregate result. Logs: `/private/tmp/ux-05-full-suite-900.log` and
`/private/tmp/ux-05-full-suite-final.log`. The final isolated invocation has a
930-second outer process timeout, including 30 seconds of cleanup margin; the
suite's existing internal 900-second limit and assertions are unchanged. Godot
emits the environment's macOS certificate warning; the headless scene probe can
also emit an ObjectDB leak warning at exit. Neither causes the passing
focused/probe commands to fail.

## Proof for the design owner

Windowed execution is unavailable in this worker sandbox and was not attempted.
Run this from a session with macOS window-server access:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-05 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id ux-05 --timeout 120 --expect-size 1920x1080 --proof-contract tests/proof_contracts/destruction_preview.json --result-manifest /private/tmp/ux-05-destruction-renderer-proof.json tests/destruction_preview_probe.gd
```

The runner prints the isolated absolute capture directory. Relative to that
run's `user://`, images are in
`probes/ux_05_destruction_preview/1920x1080_ui100/`:

- `clear_crate_confirmation.png`, `heart_crate_confirmation.png`
- `clear_trap_trigger.png`, `heart_trap_trigger.png`
- `clear_illusion_consumed.png`, `heart_illusion_consumed.png`
- `clear_lethal_pull.png`, `heart_lethal_pull.png`
- `clear_two_actions.png`, `heart_two_actions.png`
- `clear_consumed_fire.png`, `heart_consumed_fire.png`

Inspect the marks, empty bars, retained sprites, trap footprint, and unchanged
committed visibility in these captures. The probe asserts their presentation
semantics before each save; the JSON contract requires all 12 full-resolution
images with a nonblank board region. No inspection-fixture command is required
by this unit brief; the design owner prepares the publication fixture.

## Chosen defaults

All newly chosen values are proof-only, in named constants/data fields:

- Existing `BoardSurfaceSuite.fixture` grid, seed, hero and surviving crawler.
- Crate: 2 HP at `(3,3)`; Fire trap at `(2,4)`; 2-HP illusion at `(3,4)`.
- Pull: 100-HP crawler at `(5,3)` into a 200-damage Fire trap at `(4,3)`;
  committed radius-2 light for 3 turns makes that case visible in heart Umbra.
- Synthetic second action: ranged damage 1, range 4, aimed at `(4,3)`.
- Synthetic Detonate: damage 60, range 4, Fire at `(3,2)`.
- Lifetime-terrain and concealed-trap fixtures remain explicit test data.
- Capture size `1920x1080`, scale `1.0`, five settle frames, existing death-mark
  peak phase, and a 120-second budget for 12 windowed scene captures. Pixel
  thresholds reuse the existing lethal-preview proof contract.
- Outer full-suite process timeout: 930 seconds, including 30 seconds beyond
  the existing internal 900-second assertion budget for process cleanup.

No `TODO_DESIGN_` placeholders were needed.

## Workflow discrepancy

Read-only `parallel_task.py status` reported an empty acceptance/proof contract
and `contract_ready: false`, despite the setup note saying the contract and
preflight were complete. This file records implementation acceptance evidence;
the worker did not alter workflow metadata or run owner-assigned Git actions.
