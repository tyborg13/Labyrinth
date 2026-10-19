# rr-26 feedback 1: source-edge coverage

Status: Mimic and the Seer sleeve are fixed. Five Seer hem frames remain
blocked on `TODO_DESIGN_SEER_HEM_CONTINUATION_POLICY`. The design clarification
was requested asynchronously; no activation policy or new ownership was
invented. Changes are uncommitted. No windowed run, peer review or publication
was performed.

## Numbered requirements

1. **Mimic fixed.** Rear `mirror` frames 12 and 19 now have zero unmatched
   components. Both original stray pixels `(223,312)` came from the near leg's
   source texel `(90,185)`, RGBA `[0,1,0,255]`. The visible and covered meshes
   sample this narrow contour differently in the existing two-segment field.
   Duplicating its own approved texel into `leg_near_hidden` reconnects the
   surface. Existing visible paint, mesh geometry, weights, joints and timing
   are unchanged. The replay recipe is `rr20/source_underlaps.json`, applied
   by `underlaps.py` during construction and independent derivation checks.
2. **Seer sleeve fixed; hems unresolved.** Rear `death` 76's black pixel
   `(304,251)` belongs to `sleeve_far`, source `(154,95)`. It separates at
   the sleeve's narrow outer edge. A one-texel same-surface underlap at source
   `(156,96)` follows the existing full sleeve weight rule; it reconnects the
   contour without erasing or moving the original outline. The original
   sleeve is byte-identical. `rr26_underlaps.py` replays this addition from
   `rr10/rr26_underlaps.json` without rebuilding the approved cuts.

   Front move 11/12/15 come from robe texels `(152,235..237)`; rear move 10/13
   come from `(101,229..230)`. These are approved narrow robe tips, rather
   than misplaced sleeve/boot paint or an exposed tuck. The unchanged
   two-anchor hem field samples their thin connection away. The direct
   bridge candidates inverse-map to source air, including `(151,235)`,
   `(154,234)`, `(99,229)`, `(102,228)` and `(105,228)`. Permanent added
   texels there would change the approved rest silhouette. Covered copies
   within the original silhouette on the same field did not reconnect the
   hems in the diagnostic search. A move-only extension requires an owner
   activation/endpoints policy, or the owner must supply a corrected hem
   ownership/attachment. That decision remains a named data placeholder.

   A rejected, inactive diagnostic is saved at
   `experiments/cutouts/hoarfrost_seer/rr26_hem_continuation.proposal.json`.
   Two copied source texels per view reconnect all five target frames in CPU
   estimates. All four lie in approved source air. Permanent use would add
   two rest-alpha pixels in each view. Whole-move use also fails: 32/54 front
   and 36/54 rear move frames have detached components. This is diagnostic
   evidence, not a usable repair or an approved activation schedule. No
   frame-specific texture patch or per-frame exception was introduced.
3. **Thrall untouched.** Its old mq7 rear move 14 failure remains reported;
   the director will rerun the rr-24 replacement. No Thrall source, motion,
   production file or exception was changed.
4. **Five-rig census rerun.** See the final observed results below. The strict
   classifier and all detached exception data remain unchanged. Seer still
   fails the five hem frames, so the requested all-zero acceptance is unmet.
   Windowed sequences for both rigs are listed below.


## Final strict census (CPU only)

| Rig | View | Frames | Unmatched failure frames |
|---|---|---:|---:|
| Mimic | front | 362 | 0 |
| Mimic | rear | 362 | 0 |
| Seer | front | 467 | 3 |
| Seer | rear | 467 | 2 |
| Thrall | front | 335 | 0 |
| Thrall | rear | 335 | 1 |
| Mirror | front | 344 | 0 |
| Mirror | rear | 344 | 0 |
| Capacitor | front | 348 | 0 |
| Capacitor | rear | 348 | 0 |

| Rig | View | Clip | Frame | Exact pixels |
|---|---|---|---:|---|
| Seer | front | move | 11 | (265,372), (265,373) |
| Seer | front | move | 12 | (265,371), (265,372), (265,373) |
| Seer | front | move | 15 | (264,372), (264,373) |
| Seer | rear | move | 10 | (244,350), (244,351) |
| Seer | rear | move | 13 | (245,350) |
| Thrall | rear | move | 14 | (340,319) |

Census exits: Mimic/Mirror/Capacitor 0, Seer/Thrall 1. No failure was exempted.
Seer sleeve death 76 and both Mimic mirror targets are absent from the failure
reports. Seer's remaining five hem frames keep the all-zero criterion unmet.

## Preservation and integration

- `RR26F1 SEER POSE IDENTITY: PASS (1258 rows; all original bone and part transforms exact)`.
- All original Seer and Mimic joints, mesh arrays, part definitions, visible
  paint, case/production motion imports and case/production rest bytes remain
  identical to approved revision `e0d78de13`.
- Removing either underlap reproduces its original strict failure. Four new
  focused regression tests also check the original surfaces, structures,
  poses and rest bytes.
- Production receives only the amended Mimic covered texture and the Seer
  sleeve underlap/declarations. The source-first density pipeline adopts and
  processes those two files. Registry changes add only the Seer underlap
  path; output-record changes name exactly those two textures. Rest records
  are not certified headlessly.
- The original Mimic `protected_inputs.json` ledger stays immutable.
  `rr20/rr26_source_coverage.json` binds the six feedback-authorized Seer
  construction/declaration changes to both their old hashes and exact new
  hashes; all other protected paths continue to fail on any mismatch.

## Tests and proof

Exact logs are under `rr20/proof/logs/rr26f1/`.

- `Ran 45 tests in 148.022s`; `OK`;
  `RR20 INHERITED RUNNERS: PASS (10 Godot invocations forced to rr-26)`.
- Reference run: `Ran 107 tests in 179.665s`; `FAILED (failures=1)`;
  `RR20 INHERITED RUNNERS: FAIL (12 Godot invocations forced to rr-26)`.
  The other 106 tests pass. The sole failure is
  `tests.test_rr18_humanoid.MirrorTests.test_other_creatures_and_director_inputs_unchanged`
  (`tests/test_rr18_humanoid.py:260`): its `git diff --name-only` scope guard
  flags the six deliberately authorized, uncommitted Seer files. The assertion
  was left unchanged; no commit was made to satisfy this working-tree guard.

- Art identity: `Ran 111 tests in 51.914s`; `OK`.
- Density derivation/coverage checks: `Ran 2 tests in 12.666s`; `OK`.
- `RR10 NATIVE PROBE LOAD: PASS` and `RR20 NATIVE PROBE LOAD: PASS`, both
  headless `--validate-only`; no native capture claim.
- `PROCESSED 44 file(s)` (Mimic), `PROCESSED 168 file(s)` (Seer).
- Both density `--check --only <rig>` commands exit 1 for pending native rest
  rebakes. Mimic names its front/rear rests. Seer names the two family rests
  and both humanoid_v2 rests. Complete exact lines are in the check logs.
- `git diff --check` and both proof-wrapper shell syntax checks pass.
- No full project suite was run: this feedback explicitly requires focused
  checks only. Existing certificate/resource teardown and numerical warnings
  remain visible in complete logs; no failing assertion was rewritten.

Mimic and new fragment checks:

```sh
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr26_fragments tests.test_rr20_cutout tests.test_rr20_residue tests.test_rr20_feedback2 tests.test_rr20_rest_space tests.test_rr20_production
```

Reference checks:

```sh
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr10_humanoid tests.test_rr10_silhouette_gates tests.test_rr11_humanoid tests.test_rr17_cutout tests.test_rr17_integration tests.test_rr17_production tests.test_rr18_humanoid tests.test_rr18_air_policy tests.test_rr18_materials tests.test_rr16_review_fixes
```

Census inputs are fresh Seer samples at `rr20/proof/logs/rr26f1/seer_samples.json`,
current Mimic samples at `rr20/proof/logs/samples.full.json`, and unchanged,
still hash-matched reference samples at `rr20/proof/logs/rr26/<rig>_samples.json`.
The reports are in `rr20/proof/logs/rest_space/<rig>.json`; original round-zero
reports were retained as `rr20/proof/logs/rr26f1/baseline_<rig>.json`.

## Proof for the design owner

No windowed command was attempted. All actual captures remain pending at
1920×1080, 100% UI scale. Both wrappers use the required Godot/visual runners
and the existing proof contracts. Seer native acceptance still depends on
resolving its five hem failures. `sheets` and `review` require passing gates.
No inspection-fixture command is requested by this unit; the owner prepares
and inspects the inbox fixture.

Mimic:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hollow_mimic/proof.sh review
```

Seer:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

Capture roots: `experiments/cutouts/hollow_mimic/rr20/proof/` and
`experiments/cutouts/hoarfrost_seer/rr10/proof/`. Both write `native_rest/`,
`native/`, `contact_sheets/`, `idle_native/` and `production_native/`, plus their
named idle/review MP4s. Mimic production includes both facings and the three
copied card kinds. No such captures were produced in this round.

## TODO_DESIGN placeholders

`TODO_DESIGN_SEER_HEM_CONTINUATION_POLICY` in
`experiments/cutouts/hoarfrost_seer/rr10/rr26_underlaps.json`.

## Chosen defaults

- New tests use named `PROOF_TIMEOUT_SECONDS = 180`, matching the existing
  focused-test convention. This is a headless proof timeout only.
- `APPROVED_REVISION = e0d78de13` names the director's committed round-zero
  baseline for preservation tests.
- The Seer underlap's transparent mesh margin is the existing three-pixel
  anatomical tuck depth; its weights are computed from the unchanged sleeve
  field. Its depth is derived below every original layer. No new artistic
  value, timing, movement key, colour, pose or rest silhouette was chosen.

## Open issues

The five Seer hem failures require the pending design clarification. The reference working-tree scope guard also fails on the authorized Seer edits. Thrall's
one failure is explicitly deferred to rr-24. Native captures/rest rebakes and
owner inbox inspection remain pending. This branch is not ready for the
requested all-zero handoff.

## Files changed

- `assets/units/hoarfrost_seer_cutout/humanoid_v2/rear.json`
- `assets/units/hoarfrost_seer_cutout/humanoid_v2/rear/hidden_sleeve_far_edge_underlap.png`
- `assets/units/hoarfrost_seer_cutout/integration.json`
- `assets/units/hoarfrost_seer_cutout/rear.json`
- `assets/units/hollow_mimic_cutout/integration.json`
- `assets/units/hollow_mimic_cutout/rear/leg_near_hidden.png`
- `experiments/cutouts/hoarfrost_seer/rr10/checks/rear/hidden_sleeve_far_edge_underlap.png`
- `experiments/cutouts/hoarfrost_seer/rr10/checks/rear/hidden_sleeve_far_edge_underlap.png.import`
- `experiments/cutouts/hoarfrost_seer/rr10/layouts/rear.json`
- `experiments/cutouts/hoarfrost_seer/rr10/pieces/rear/hidden_sleeve_far_edge_underlap.png`
- `experiments/cutouts/hoarfrost_seer/rr10/pieces/rear/hidden_sleeve_far_edge_underlap.png.import`
- `experiments/cutouts/hoarfrost_seer/rr10/rr26_underlaps.json`
- `experiments/cutouts/hoarfrost_seer/rr10_build.py`
- `experiments/cutouts/hoarfrost_seer/rr10_proof.sh`
- `experiments/cutouts/hoarfrost_seer/rr26_hem_continuation.proposal.json`
- `experiments/cutouts/hoarfrost_seer/rr26_underlaps.py`
- `experiments/cutouts/hollow_mimic/README.md`
- `experiments/cutouts/hollow_mimic/build.py`
- `experiments/cutouts/hollow_mimic/continuations.py`
- `experiments/cutouts/hollow_mimic/gates.py`
- `experiments/cutouts/hollow_mimic/rr20/checks/rear/leg_near_hidden.png`
- `experiments/cutouts/hollow_mimic/rr20/layouts/rear.json`
- `experiments/cutouts/hollow_mimic/rr20/pieces/rear/leg_near_hidden.png`
- `experiments/cutouts/hollow_mimic/rr20/proof/samples.json`
- `experiments/cutouts/hollow_mimic/rr20/residue_source/rear/leg_near_hidden.png`
- `experiments/cutouts/hollow_mimic/rr20/rr26_source_coverage.json`
- `experiments/cutouts/hollow_mimic/rr20/source_underlaps.json`
- `experiments/cutouts/hollow_mimic/rr26_feedback1.md`
- `experiments/cutouts/hollow_mimic/underlaps.py`
- `spec/assets/board_pixel_density/outputs.json`
- `spec/assets/board_pixel_density/registry.json`
- `spec/assets/board_pixel_density/sources/assets/units/hoarfrost_seer_cutout/humanoid_v2/rear/hidden_sleeve_far_edge_underlap.png`
- `spec/assets/board_pixel_density/sources/assets/units/hollow_mimic_cutout/rear/leg_near_hidden.png`
- `tests/test_rr26_fragments.py`
