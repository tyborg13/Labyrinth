# rr-26 implementation handoff

Implementation is complete and uncommitted on `codex/rr-26`. Native acceptance
remains pending the design owner's windowed sequence. Strict CPU diagnostics
now expose nine failing frames; no motion, paint, cuts or exception files were
changed. The supplied review findings and reproduction remain untouched.

## Numbered requirements and task contract

1. **Strict detached provenance implemented.** `DetachedSource.report()` counts
   every unmatched component directly. It never calls the legacy tiny/dark
   outline heuristic. Existing exact source-texel, rigid transform and visible
   owner matching remain required. `exempt_outline_components` remains a
   compatible metric field fixed at zero. Unmatched records contain bounds,
   pixel counts and every `(x, y)` coordinate; the native gate retains these
   diagnostics even in a frame with no pockets or approved specks.
   The review's originally connected skinned sleeve-tip regression removes
   only its bridge pixel. It has no approved detached source, no outside-paint
   violation and no hole; it now fails the final frame rule with one stray
   pixel. An in-memory substitution of the original HEAD classifier makes
   this new assertion fail, confirming the regression catches the reviewed bug.
   This meets contract acceptance 1 at the classifier/frame-rule level;
   native renderer verification remains pending.
2. **All five strict gate censuses rerun.** Fresh headless Bone2D samples were
   taken through the rr-26 runner. All reference outputs are under Mimic's
   ignored logs. No reference files were written. The census deliberately
   ignores old detached-frame exceptions, rather than letting those exceptions
   supply missing source provenance. Existing hole exceptions remain as before.
   The results and exact components below meet contract acceptance 2.
   Capacitor also passes its existing full rigid pixel gate in the focused
   reference tests; its census adapter checks detached provenance only and
   preserves its approved runtime glow table.
3. **Focused proof and owner handoff.** No full project suite, windowed run,
   peer review, commit or publication was performed. The brief explicitly
   limits this unit to focused tests. Existing native probes and proof
   contracts are retained; the shell wrapper and inherited test runner now
   default to task ID `rr-26`. The owner performs the windowed sequence and
   inbox inspection required by the standard-risk task contract.

## Strict all-frame results (CPU estimates, not native acceptance)

| Rig | View | Frames | Verdict | Failing frames |
|---|---|---:|---|---:|
| Seer | front | 467 | FAIL | 3 |
| Seer | rear | 467 | FAIL | 3 |
| Thrall | front | 335 | PASS | 0 |
| Thrall | rear | 335 | FAIL | 1 |
| Mirror | front | 344 | PASS | 0 |
| Mirror | rear | 344 | PASS | 0 |
| Capacitor | front | 348 | PASS | 0 |
| Capacitor | rear | 348 | PASS | 0 |
| Mimic | front | 362 | PASS | 0 |
| Mimic | rear | 362 | FAIL | 2 |

All 16,732 source-air pockets still pass across the four humanoid cases.
Mimic's 355 front detached-head components still pass exact source provenance.
No palette, size, proximity or board-scale visibility allowance was introduced.

Coordinates below are zero-based `(x, y)` pixels in the existing 512×512 proof
canvas, with its existing `(128, 128)` source offset. Frames are zero-based.
Each row is one unmatched component. No hole failures occurred in this census.

| Rig | View | Clip | Frame | Pixels | Exact pixel coordinates |
|---|---|---|---:|---:|---|
| Seer | front | `move` | 11 | 2 | (265, 372), (265, 373) |
| Seer | front | `move` | 12 | 3 | (265, 371), (265, 372), (265, 373) |
| Seer | front | `move` | 15 | 2 | (264, 372), (264, 373) |
| Seer | rear | `move` | 10 | 2 | (244, 350), (244, 351) |
| Seer | rear | `move` | 13 | 1 | (245, 350) |
| Seer | rear | `death` | 76 | 1 | (304, 251) |
| Thrall | rear | `move` | 14 | 1 | (340, 319) |
| Mimic | rear | `mirror` | 12 | 1 | (223, 312) |
| Mimic | rear | `mirror` | 19 | 1 | (223, 312) |

Seer front move 11/12/15 and rear move 10 were already listed in its historical
detached exceptions; they are reported as strict failures here. Seer rear move
13/death 76, Thrall rear move 14 and Mimic rear mirror 12/19 were hidden by the
old tiny-dark heuristic. Their cuts and motion are outside this unit's scope.
All five full census reports, including every passed pocket's bounds and all
unmatched coordinates, are in `rr20/proof/logs/rest_space/<rig>.json`.

## Tests and headless probes

Exact command logs are in `rr20/proof/logs/rr26/`.

- Source-air/provenance suite: `Ran 11 tests in 0.110s`; `OK`.
- Regression mutation: `RR26 REVIEW MUTATION: CAUGHT (new sleeve-tip regression rejects the HEAD classifier)`.
- Reference suites: `Ran 107 tests in 178.227s`; `OK`;
  `RR20 INHERITED RUNNERS: PASS (12 Godot invocations forced to rr-26)`.
- Mimic final suite: `Ran 41 tests in 128.405s`; `OK`;
  `RR20 INHERITED RUNNERS: PASS (8 Godot invocations forced to rr-26)`.
- First Mimic attempt: `Ran 41 tests in 139.053s`; `FAILED (errors=2)`.
  Both errors were `FileNotFoundError` for ignored `logs/samples.full.json`
  absent from the new worktree. The normal headless sampler regenerated it
  and refreshed only the compact inventory's evidence hash. No assertion was
  rewritten. Affected suite rerun: `Ran 7 tests in 1.936s`; `OK`.
- `RR26 MIMIC SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH GATES: PASS (0 errors; both views)`.
- `RR20 NATIVE PROBE LOAD: PASS` (`--validate-only`, headless, no capture).
- `RR26 SEER POSE IDENTITY: PASS (1258 exact retained rows)`.
- `RR26 THRALL POSE IDENTITY: PASS (1050 exact retained rows)`.
- `RR26 CAPACITOR POSE IDENTITY: PASS (696 exact retained rows)`.
- `RR26 OWNERSHIP AUDIT: PASS (8 tracked changed files; all owned)`; the
  ninth changed file is this new handoff document.
- `RR26 PROTECTED FIGURE INPUTS: PASS (assets, runtime, data, specs and four reference cases unchanged)`.
- `sh -n experiments/cutouts/hollow_mimic/proof.sh` and `git diff --check` pass.
- Godot's existing macOS certificate/resource teardown warnings are retained
  in the complete sampler and probe logs; they did not change exit status.

Mimic suites:

```sh
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr20_cutout tests.test_rr20_residue tests.test_rr20_feedback2 tests.test_rr20_rest_space tests.test_rr20_production
```

Reference suites:

```sh
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr10_humanoid tests.test_rr10_silhouette_gates tests.test_rr11_humanoid tests.test_rr17_cutout tests.test_rr17_integration tests.test_rr17_production tests.test_rr18_humanoid tests.test_rr18_air_policy tests.test_rr18_materials tests.test_rr16_review_fixes
```

Each strict census uses the corresponding fresh sample file:

```sh
for rig in seer thrall mirror capacitor mimic; do
    OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B experiments/cutouts/hollow_mimic/rest_space_proof.py --rig "$rig" --samples "experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26/${rig}_samples.json"
done
```

Census exits are 1 for Seer, Thrall and Mimic and 0 for Mirror and Capacitor.
These are reported failures, not relaxed gates.

## Proof for the design owner

No windowed command was attempted. Run at 1920×1080, 100% UI scale, using the
existing probe contracts and validated visual runner invoked by this wrapper:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh review
```

The `native` stage may now fail on the two Mimic frames above if the renderer
reproduces the CPU estimate. Diagnose those captures without adding exemptions
or changing the protected design. `sheets`/`review` require passing native gates.
No `tools/inspection_fixture.py` command is requested by this unit; fixture
preparation and inbox inspection belong to the owner.

Capture paths (all relative to `experiments/cutouts/hollow_mimic/rr20/proof/`):
`native_rest/`, `native/`, `contact_sheets/`, `idle_native/`,
`production_native/{front,rear}/{whirlwind_slash,quick_stab,hurl_spear}/`,
`hollow_mimic_protagonist_idle.mp4`, `hollow_mimic_review.mp4`.
These are pending outputs, not captures produced during rr-26.
Native failure crops, if any, are written to `logs/native_failures/`.

## Files changed

- `tools/humanoid_cutout/rest_space.py`: strict unmatched counts and exact
  component diagnostics.
- `tools/humanoid_cutout/gates.py`: retain unmatched components in native
  source-space diagnostics, including detached-only failure frames.
- `tests/test_rr20_rest_space.py`: review bridge-removal regression through
  the final frame rule.
- `tests/rr20_regression_runner.py`: honor the task environment and default
  inherited engine calls to rr-26.
- `experiments/cutouts/hollow_mimic/rest_space_proof.py`: all five strict
  censuses, with exact failed pixels and no detached legacy exemptions.
- `experiments/cutouts/hollow_mimic/proof.sh`: rr-26 runner task ID.
- `experiments/cutouts/hollow_mimic/rr20/proof/samples.json`: refreshed
  compact evidence hash for regenerated ignored headless samples; all
  inventory counts and other values remain identical.
- `experiments/cutouts/hollow_mimic/README.md`: pointer to the current handoff.
- `experiments/cutouts/hollow_mimic/rr26_implementation.md`: this handoff.

## TODO_DESIGN placeholders

None. The brief supplies all design decisions needed for this classifier fix.

## Chosen defaults

No player-visible values or new discretionary proof settings were chosen.
`FIXTURE_DARK_COLOR = [5, 5, 5, 255]` names the existing review reproduction's
RGBA value. `TASK_ID` / shell `task_id` default to the required `rr-26`.
All existing fixture dimensions, transforms, capture sizes, timing and timeouts
remain as before.

## Open issues

- Nine strict CPU failure frames remain as listed; no out-of-scope pose/paint
  fix or exemption was made.
- Fresh native captures, both pending density rest rebakes and owner inbox
  inspection are still required. Headless proof cannot establish native pixels.
