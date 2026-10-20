# rr-26 feedback 2 handoff

The five Seer hem failures are fixed by the director's attachment policy.
Mimic, Seer, Mirror and Capacitor have zero unmatched detached components in
the fresh strict CPU census. Thrall's old cut remains deferred to rr-24.
Changes are uncommitted on `codex/rr-26`, above `f11932ab7`. Native acceptance
is pending the two windowed sequences below; no windowed command was attempted.
This record supersedes the open hem policy in the historical feedback-1 handoff.

## Acceptance criteria

1. **Strict provenance retained.** Every unmatched detached component still
   fails, including a single dark pixel. No tiny-component exemption or new
   frame exception was added. The reviewed connected-sleeve bridge-removal
   regression passes in the focused suite. Existing strict classifier and
   native-gate provenance behavior from round zero remain intact.
2. **Attachment, without new paint.** Eight front and five rear original
   `robe` texels inherit the weights at their eight-connected body neighbour's
   texel centre, or inherit through an already attached neighbour. The exact
   links are in `hoarfrost_seer/rr10/rr26_hem_attachments.json`. Only base grid
   cells containing these tips are replaced by local texel quads; every
   original vertex, weight and other paint-bearing triangle remains exact.
   Every painted texel in a replaced cell is retained. Validation rejects
   air/tuck donors, missing painted texels, cycles, non-neighbours and arbitrary
   weights. The original PNGs, rest images, joints, motion and rigid parts are
   unchanged. The neutral-pose CPU raster is pixel-identical in both views.
   The case, runtime v2 and family density layouts have normalized parity.
3. **All changed rows reported.** All 1,258 original Seer pose sample records
   remain byte-identical after canonical serialization. All original robe
   vertex positions remain exact in those poses. Only the attached tip
   geometry can differ. The complete [1,258-row inventory](../hoarfrost_seer/rr26_feedback2_pose_changes.csv)
   reports view, kind, clip, frame, phase, part, tip texels, maximum corner
   delta and changed robe CPU-pixel count for every row, including unchanged
   rows and sub-tolerance differences. There are 468 rows above the existing
   `0.0001` vertex tolerance and 220 rows with any changed robe CPU pixels;
   all are part `robe`. These are CPU diagnostics, not native-pixel proof.
   Every other original part and mesh definition is unchanged. Fresh Thrall,
   Mirror and Capacitor transform records also match retained evidence exactly.
4. **Five-rig census complete.** No further unmatched component exists in
   Mimic, Seer, Mirror or Capacitor. The earlier Mimic near-leg and Seer sleeve
   underlaps remain effective. Thrall is untouched. Mirror's working-tree
   scope assertion is unchanged, as instructed; it still reports the
   authorized uncommitted Seer paths. No other reference assertion fails.
5. **Focused checks and owner proof.** Focused tests, all-frame censuses,
   source/structure checks, layout parity and headless native-probe loads ran.
   The full project suite, peer review, commits and publication were not run.
   The existing two capture scripts/contracts are ready for the owner.

## Pose inventory summary

Continuous tip changes above the existing vertex tolerance, per view:

| Kind / clip | Front rows | Rear rows | Presented frames |
|---|---:|---:|---|
| authored / move | 50 | 50 | phase values in CSV |
| presented / move | 44 | 44 | 3–46 |
| authored / land | 8 | 8 | phase values in CSV |
| presented / land | 14 | 14 | 11–24 |
| authored / hit | 9 | 9 | phase values in CSV |
| presented / hit | 8 | 8 | 3–10 |
| authored / death | 22 | 22 | phase values in CSV |
| presented / death | 79 | 79 | 23–101 |

CPU raster changes occur only in `move` and `death`; the CSV lists each frame
and authored phase, including duplicate serialized phases disambiguated by
`pose_row`. Original transform records do not change in any clip.

## Fresh strict census

| Rig | Presented frames per view | Unmatched front | Unmatched rear | Exit |
|---|---:|---:|---:|---:|
| Seer | 467 | 0 | 0 | 0 |
| Thrall | 335 | 0 | 1 | 1 |
| Mirror | 344 | 0 | 0 | 0 |
| Capacitor | 348 | 0 | 0 | 0 |
| Mimic | 362 | 0 | 0 | 0 |

Thrall's sole unmatched component is rear `move` frame 14, one pixel
`(340,319)`, bbox `[340,319,341,320]` in the existing 512×512 proof canvas.
It belongs to the old cut and remains deferred to rr-24. No rule was loosened.
The census continues to ignore historical detached exceptions and retains the
existing source-air rules and hole exceptions. Capacitor's original rigid
pixel gates also ran in its focused reference suites.

Exact census lines:

```text
RR20 REST SPACE SEER FRONT: PASS (467 frames; 3232 air pockets; 0 failing frames)
RR20 REST SPACE SEER REAR: PASS (467 frames; 4601 air pockets; 0 failing frames)
RR20 REST SPACE THRALL FRONT: PASS (335 frames; 988 air pockets; 0 failing frames)
RR20 REST SPACE THRALL REAR: FAIL (335 frames; 922 air pockets; 1 failing frames)
RR20 REST SPACE MIRROR FRONT: PASS (344 frames; 374 air pockets; 0 failing frames)
RR20 REST SPACE MIRROR REAR: PASS (344 frames; 1976 air pockets; 0 failing frames)
RR20 REST SPACE CAPACITOR FRONT: PASS (348 frames; 0 air pockets; 0 failing frames)
RR20 REST SPACE CAPACITOR REAR: PASS (348 frames; 0 air pockets; 0 failing frames)
RR20 REST SPACE MIMIC FRONT: PASS (362 frames; 1996 air pockets; 0 failing frames)
RR20 REST SPACE MIMIC REAR: PASS (362 frames; 2655 air pockets; 0 failing frames)
```

Fresh samples and archived census JSON/logs are under
`rr20/proof/logs/rr26f2/`; Mimic uses `rr20/proof/logs/samples.full.json` and
its refreshed tracked compact inventory. Live census reports are also under
`rr20/proof/logs/rest_space/`. All reports bind their current input hashes.

## Tests and probes

- Main focused batch: `Ran 50 tests in 144.521s`; `OK`;
  `RR20 INHERITED RUNNERS: PASS (10 Godot invocations forced to rr-26)`.
- Final hem suite, including the added neutral-raster check:
  `Ran 6 tests in 1.789s`; `OK`.
- Case/runtime/density layout parity: `Ran 1 test in 0.536s`; `OK`;
  `RR20 INHERITED RUNNERS: PASS (0 Godot invocations forced to rr-26)`.
- Reference batch: `Ran 107 tests in 159.994s`; `FAILED (failures=1)`;
  `RR20 INHERITED RUNNERS: FAIL (12 Godot invocations forced to rr-26)`.
  The only failure is
  `tests.test_rr18_humanoid.MirrorTests.test_other_creatures_and_director_inputs_unchanged`,
  which reports ten authorized uncommitted Seer paths. Its assertion is intact.
  Per director feedback 2, the owner commit clears this working-tree guard;
  that post-commit result has not been observed by this worker.
- `RR10 NATIVE PROBE LOAD: PASS` and `RR20 NATIVE PROBE LOAD: PASS`.
  Both used `--headless --validate-only`; no image was captured.
- `RR26F2 SEER POSE ROWS: PASS (1258 byte-identical canonical rows; all original vertices exact)`.
- `RR26F2 TIP DEFORMATION CHANGES: 468 rows above existing vertex epsilon; part=robe; full 1258-row inventory=experiments/cutouts/hoarfrost_seer/rr26_feedback2_pose_changes.csv`.
- `RR26F2 ROBE CPU PIXEL CHANGES: 220 pose rows; all remaining parts unchanged`.
- Retained pose identities: Seer 1,258, Thrall 1,050, Mirror 968 and
  Capacitor 696 rows match exactly. Mirror uses retained round-zero ignored
  samples because its full sample file is not tracked; the initial attempt
  to read that absent file from HEAD was a diagnostic read failure.
- Both density `--check --only <rig>` commands exit 1 for existing pending
  native rest rebakes: Mimic front/rear and Seer front/rear family/v2 rests.
  Each reports `rig part pixels changed since recorded rebake`. This round
  changes no PNGs. Native certification is not claimed.
- Both proof wrappers pass `sh -n`. `git diff --check` passes.
- `RR26F2 SCOPE: PASS (15 tracked changes; 7 new files; branch codex/rr-26)`.
- `RR26F2 PAINT/MOTION: PASS (no PNG or motion changes; retained 1258-row file and original protected ledger byte-identical)`.
- `RR26F2 INTEGRATION HASHES: PASS (all files current; 9 authorized Seer before/after bindings)`.
- Existing macOS CA-certificate and Godot resource-teardown warnings remain
  in sampler/probe output; the reported probe/sample commands exited 0.

Focused commands:

```sh
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr26_hem_attachments tests.test_rr26_fragments tests.test_rr20_cutout tests.test_rr20_residue tests.test_rr20_feedback2 tests.test_rr20_rest_space tests.test_rr20_production
OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B -m unittest tests.test_rr26_hem_attachments
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr10_layout_parity
LABYRINTH_TASK_ID=rr-26 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B tests/rr20_regression_runner.py tests.test_rr10_humanoid tests.test_rr10_silhouette_gates tests.test_rr11_humanoid tests.test_rr17_cutout tests.test_rr17_integration tests.test_rr17_production tests.test_rr18_humanoid tests.test_rr18_air_policy tests.test_rr18_materials tests.test_rr16_review_fixes
OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B experiments/cutouts/hoarfrost_seer/rr26_pose_changes.py --samples experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26f2/seer_samples.json --output experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26f2/seer_pose_changes.json
```

The main batch loaded the original five-test hem module; the final six-test
module additionally verifies neutral raster identity. No failure was rewritten.
Every Godot invocation used the mandated rr-26 runner. Native probe loads:

```sh
python3 tools/godot_task_runner.py --task-id rr-26 --stream -- godot --headless --path . --script tests/rr10/native_capture.gd -- --case res://experiments/cutouts/hoarfrost_seer/rr10 --output res://experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26f2/seer_probe_load --validate-only
python3 tools/godot_task_runner.py --task-id rr-26 --stream -- godot --headless --path . --script tests/rr20/native_capture.gd -- --case res://experiments/cutouts/hollow_mimic/rr20 --output res://experiments/cutouts/hollow_mimic/rr20/proof/logs/rr26f2/mimic_probe_load --validate-only
```

## Proof for the design owner

Both sequences run at 1920×1080, 100% UI scale, through the existing required
Godot/visual runners and proof contracts. Run in stage order; errors stop the
sequence. No inspection-fixture command is requested by this unit; the owner
prepares the fixture. The first sequence is Mimic; the second is Seer.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh -ec 'for stage in density rest native sheets idle production review; do sh experiments/cutouts/hollow_mimic/proof.sh "$stage"; done'
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-26 && sh -ec 'for stage in density rest native sheets idle production review; do sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh "$stage"; done'
```

Pending capture roots:

- Mimic: `experiments/cutouts/hollow_mimic/rr20/proof/{native_rest,native,contact_sheets,idle_native,production_native}/`,
  `hollow_mimic_protagonist_idle.mp4` and `hollow_mimic_review.mp4` in that proof root.
- Seer: `experiments/cutouts/hoarfrost_seer/rr10/proof/{native_rest,native,contact_sheets,idle_native,production_native}/`,
  `seer_protagonist_idle.mp4` and `hoarfrost_seer_review.mp4` in that proof root.

No fresh renderer capture or MP4 was produced by this worker.

## TODO_DESIGN placeholders

None active. `TODO_DESIGN_SEER_HEM_CONTINUATION_POLICY` is resolved and removed
from the active underlap recipe. Its earlier air-bridge proposal remains
inactive and is marked resolved; historical handoff prose is retained.

## Chosen defaults

- `BARYCENTRIC_EPSILON = np.finfo(float).eps * 8` is a named floating-point
  roundoff allowance for solving a source triangle; it does not tune motion.
- `APPROVED_REVISION = f11932ab7` names the pre-feedback-2 preservation baseline
  in the pose inventory helper. The original preservation test still uses
  its earlier round-zero baseline.
- `MUTATION_WEIGHT_DELTA = 0.01` is an invalid-weight test fixture only.
- The pose report reuses the existing `EPSILON = 0.0001` for the summary;
  its CSV retains every row's unfiltered maximum delta and CPU pixel count.
  No player-facing number, colour, timing, pose or paint was chosen.

## Files changed in this round

- `tools/humanoid_cutout/texel_attachments.py`: exact neighbour inheritance,
  local quads and original-paint validation.
- `tools/humanoid_cutout/gates.py`: exact canonical attachment validation.
- `experiments/cutouts/hoarfrost_seer/rr10/rr26_hem_attachments.json`:
  thirteen texel-to-neighbour links.
- `experiments/cutouts/hoarfrost_seer/rr26_attachments.py` and `rr10_build.py`:
  deterministic case builder integration.
- `experiments/cutouts/hoarfrost_seer/rr10/layouts/{front,rear}.json`:
  only robe geometry/weights/attachment metadata.
- `assets/units/hoarfrost_seer_cutout/{front,rear}.json` and
  `assets/units/hoarfrost_seer_cutout/humanoid_v2/{front,rear}.json`:
  identical production/density geometry; all other declarations retained.
- `assets/units/hoarfrost_seer_cutout/integration.json`: current layout hashes;
  readiness remains false and native proof pending.
- `experiments/cutouts/hoarfrost_seer/rr10/rr26_underlaps.json` and
  `experiments/cutouts/hoarfrost_seer/rr26_hem_continuation.proposal.json`:
  resolved policy metadata; sleeve underlap and inactive diagnostic retained.
- `experiments/cutouts/hoarfrost_seer/rr26_pose_changes.py` and
  `experiments/cutouts/hoarfrost_seer/rr26_feedback2_pose_changes.csv`:
  complete frame/phase/part preservation and deformation inventory.
- `experiments/cutouts/hollow_mimic/rr20/rr26_source_coverage.json`:
  binds the nine authorized old/new Seer file hashes; the protected original
  ledger remains untouched.
- `experiments/cutouts/hollow_mimic/rr20/proof/samples.json`: refreshed compact
  evidence hash after the shared validation helper changed.
- `tests/test_rr26_hem_attachments.py` and `tests/test_rr26_fragments.py`:
  behavioral regression, mutation and preservation checks.
- `experiments/cutouts/hollow_mimic/README.md` and this handoff:
  current results, file inventory and exact owner commands.

## Open issues

The only strict census failure is the deferred rr-24 Thrall cut. The known
Mirror scope guard remains red while authorized Seer files are uncommitted.
Native rendering, rest rebakes, visual inspection, owner commit/review and
inspection fixture are still pending with the design owner. No commit,
reviewer agent, sign-off request or publication action was performed.
