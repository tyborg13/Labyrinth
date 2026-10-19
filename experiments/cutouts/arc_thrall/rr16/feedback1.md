# rr-16 feedback 1 implementation

Both generic-tool findings from the re-review at `ae4d86b8f` are fixed. Implementation began from clean `codex/rr-16` HEAD `f0eff8a40f02f59ff52afaf9e1f1e841a14cb530`. These changes remain uncommitted. No peer review, publication, full suite or windowed run was performed.

## Requirements

1. **Rotation-only support tracks retain modes.** `compiler.py` counts only `forward_px`, `lift_px` and `inward_px` as positional tracks when deciding whether mode metadata is necessary, matching the runtime's keyed-support predicate. A zero-valued lean track no longer removes the explicit body support mode in either view. The regression compares all existing compiled bytes and metadata, excluding only the newly authored zero track and source digest, then checks the real headless runtime: the foot remains `(20,31)` in both views, with and without the lean track. The authored zero track remains faithfully compiled.
2. **Nonlinear reach paths use conservative bounds.** Chords are used only when every relevant positional channel is affine on the key-partitioned interval and all rotations are constant. Changing smoothstep, hold jumps and rotations use FK interval boxes instead. Since each supported interpolation is monotone between keys, its endpoint value range contains the interval. Outward-rounded arithmetic and 1-Lipschitz sine/cosine bounds contain each composed world transform. Subtracting the first bone's position box from the target's box and finding its distance from zero gives a conservative reach lower bound; discarding correlations widens the bound rather than hiding a dip. Unsafe intervals are bisected to `1e-6` phase. The review's mixed linear/smoothstep regression fails at **23.113249183 px, phase .500730859**, matching the reference minimum **23.113248654 px, phase .500730940** within the required phase resolution. Additional regressions cover chord eligibility and strict enclosure of actual rotating/world-step FK paths.

The Thrall's same four documented overreach paths remain unchanged: `front/jab/hand_far`, `front/death/tube_tip`, `front/death/hand_far`, `rear/death/hand_far`. Both creatures' compiled files and recompilation results remain exactly unchanged. All 990 Thrall and 1,258 Seer pose rows match; production render inputs and the protected director data are unchanged. See `feedback1_preservation.json`. The fresh Thrall samples update only input bindings.

## Files changed

- `tools/humanoid_cutout/compiler.py`: positional-support predicate.
- `tools/humanoid_cutout/reach.py`: affine eligibility, conservative FK interval bounds, guarded refinement.
- `tests/test_rr16_feedback1.py`: four focused regressions, including a temporary headless runtime probe. No new project Godot resource or sidecar is needed.
- `experiments/cutouts/arc_thrall/rr16_mutations.py` and `rr16/mutations.json`: two additional guard-removal mutations; the three original mutations also ran.
- `rr11/proof/samples.json`: fresh input bindings, identical pose rows.
- This handoff, `feedback1_preservation.json`, and `feedback1_files_changed.txt`.

## Verification

Both new reproductions failed against the pre-fix code as expected (`/private/tmp/labyrinth_codex/rr16-feedback1-before.log`: two assertion failures).

Commands run, all from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -B -m unittest tests.test_rr16_feedback1
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -B -m unittest tests.test_rr15_reach
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -B experiments/cutouts/arc_thrall/rr16_mutations.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -B experiments/cutouts/arc_thrall/rr16_focused.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case experiments/cutouts/arc_thrall/rr11 --output experiments/cutouts/arc_thrall/rr11/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 -B experiments/cutouts/arc_thrall/rr11_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/rr11/runtime_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && python3 tools/godot_task_runner.py --task-id rr-16 --stream -- godot --headless --path . --script tests/rr10/runtime_checks.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-16 && git diff --check
```

The focused helper includes the entire requested rr11, rr14, rr15, Seer rr10, rr07 production, sidecar, registration and rr16 regression sets. Exact observed result lines:

```text
/private/tmp/labyrinth_codex/rr16-feedback1-focused.log
Ran 189 tests in 153.889s
OK
RR14 RUNTIME: PASS (246 checks; headless synthetic anatomy and foot IK)
RR14 SEER BYTE IDENTITY: PASS (777 files; only two input-binding objects excluded)
RR16 THRALL POSE IDENTITY: PASS (990 exact rows)
RR16 SEER POSE IDENTITY: PASS (1258 exact rows)

/private/tmp/labyrinth_codex/rr16-feedback1-regressions-final.log
Ran 4 tests in 0.527s
OK
RR16 CURVED REACH: FAIL AS REQUIRED (23.113249183 px at 0.500730859)
RR16 SUPPORT MODES: PASS (4 views/configurations)

/private/tmp/labyrinth_codex/rr16-feedback1-thrall-reach.log
Ran 4 tests in 7.256s
OK

/private/tmp/labyrinth_codex/rr16-feedback1-gates.log
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR15 FRONT ACTION DIRECTION: PASS (458 positive checks)
RR15 FRONT REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)
RR15 REAR ACTION DIRECTION: PASS (458 positive checks)
RR15 REAR REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)

/private/tmp/labyrinth_codex/rr16-feedback1-runtime.log
RR11 RUNTIME: PASS (5722 checks; headless logic only)

/private/tmp/labyrinth_codex/rr16-feedback1-seer-runtime.log
RR10 RUNTIME: PASS (10 checks; headless logic only)
```

`git diff --check` exits 0. No rendering or capture paths were added; the support probe uses real runtime transforms headlessly, and its temporary fixtures are cleaned up. No full suites, SFX reruns, editor scans or windowed runs were needed or performed in this feedback round.

## Mutation table

| Removed guard | Regression | Result | Restoration |
|---|---|---|---|
| Positional-only support predicate (revert to all numeric tracks) | Zero lean/body-mode regression | CAUGHT: missing support metadata assertion | Byte for byte |
| Conservative nonlinear bounds (force endpoint chords) | Mixed linear/smoothstep minimum | CAUGHT: gate incorrectly passes without guard | Byte for byte |

Both failures are assertion failures. The original three rr16 mutations were also caught and restored. See `mutations.json`, `/private/tmp/labyrinth_codex/rr16-feedback1-mutations.log`, and `/private/tmp/labyrinth_codex/rr-16/mutations/fix6.log` / `fix7.log` for the two new guards.

## TODO_DESIGN placeholders

None. There are no player-perceived changes.

## Chosen defaults

Only test verification fields: `BOUND_ENCLOSURE_SAMPLE_COUNT=9` samples per key interval, and `DISTANCE_TOLERANCE_PX=1e-4` for the curved regression assertion. The fixture motion, support coordinates, `.5` probe phase, 40/20 chain and reference minimum come from the review. The 96px/2x proof scale and 180s probe timeout reuse established proof values. All are named fields in `tests/test_rr16_feedback1.py`; no gameplay defaults or tuning changed.

## Open issues / proof for the design owner

None in this implementation. Compiled bytes, render inputs and pose rows are unchanged; the feedback explicitly requests no windowed runs, so there are no new capture or inspection commands. Review, commits and publication remain the design owner's stages.
