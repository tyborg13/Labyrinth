# rr-55 — mq27 Burrow Grub

Uncommitted implementation for the design owner. No peer review, Git mutation,
windowed Godot, new art, dependencies, mechanics or motion edits were performed.

## Requirements

1. The approved mq27 paints are registered through rr12/rr07/rr05, without
   forking their modules. `seg_3` chains outward; native legs attach to rings
   1/3/5. The front tooth ring is one 2,376-pixel feature on `head`; rear is
   occluded. Source-space rest differs by **0 RGBA pixels**, with **0 outside
   texels** in both views; inspected crops are `proof/*_rest_outside_4x.png`.
   Hidden seeds retain material beyond rest alpha if supplied. Only hidden seeds
   with four-way contact with visible material survive; this removed two
   diagonal-only derived texels that caused 47 death-frame stray failures.
   Every visible approved pixel stays exact. No external hidden extent is needed
   by the current all-tie CPU sweep. The protected rr12 director file and its
   case copy remain byte-identical (`a278c6205fee0ffb1c42265ce72392897f1d89b0e6f88311add227ce3289a503`).
2. `art_scale=0.64`. Untouched adopted parts/rests replace same-name mq5 sources;
   both density grids derive to **1.56, regrid**. The registry records the owner's
   scale/drawn-height exceptions; global bands are unchanged. Native rest records
   are deliberately invalidated until a real rebake. `--check` reports exactly
   the two missing Grub native-rest records.
3. Floor anchors are the midpoint of the occupied projection interval on the
   least-squares lower-silhouette line: front `(138.39211465,207.87035554)`, rear
   `(140.07841208,208.45391609)`. Mirrors reflect the same anchor. Source lower
   contour overrun is **9/236 front, 10/212 rear**, including the game's existing
   1.03 canvas-width factor. At a 144px proof tile, offline NEAREST samples are
   **3/88 front, 4/79 rear** outside the diamond; mirrors have identical counts.
   `ACTION_BOUNDS` comes from every sampled texel-square hull and both reflections,
   subtracting continuous root travel once. See `proof/registration.json`.
4. One measured capsule per view follows that line. Half widths are half the
   median painted normal thickness: **38.13637938 / 33.60432536** source pixels.
   Ends stay within **6 source pixels** of both the axial paint extent and its
   canvas-x bounds (including the oblique circular caps). Existing
   alpha **0.62**, root-alpha multiplication and buried suppression are preserved.
   Cache refresh reuses the common extractor and preserves 80 unrelated entries.
5. Existing board, pre-battle, turn-order/landing portraits and bestiary renderer
   routing consume the new production rig. Real resolver callbacks cover idle,
   move, gnaw, burrow, erupt, hit and death; hit returns to idle. The independent
   runtime/surface suites pass. All **74** owned cel variants were rebuilt with
   the unchanged common builder into `/private/tmp/labyrinth_codex/rr-55/cel_grub`.
   The full generated cache must be completed after the director's native rebake;
   the broad local build was interrupted and is not certified. No variants ship
   in Git. The strike registry's existing generic arc needs no source landmark
   change and is preserved, along with the mound art and mv01 continuous root.
6. Production assets/rest records now point to mq27. The old static fallback
   registry entries are explicitly historical legacy entries; old mq5 jobs and
   protected director metadata remain untouched. No live cutout loads mq5 paint.

## Observed proof

Logs: `/private/tmp/labyrinth_codex/rr-55/`.

- `headless-final.log`: `MAQUETTE MOTION SAMPLES: PASS (460 bone poses)`;
  `MAQUETTE PIXEL SAMPLES: PASS (828 poses; headless transforms only)`;
  `RR12 MOTION GATES: PASS (burrow_grub; 0 errors)`;
  `RR12 PIXELS GATES: PASS (burrow_grub; 0 errors)`.
- `proof/focused.json`: `MQ27 FOCUSED: PASS (29 checks; 2/2 motion/parent mutations rejected)`.
- `proof/cpu_sweep.json`: `MQ27 CPU SWEEP: PASS (828 poses; 9/9 mutations rejected; 0 failures)`.
  It tests all independent native u/v tie occupancies conservatively, rather
  than accepting their union as a connected silhouette. Held and boundary
  unexplained shimmer residuals are both zero; feature/seam/dark-slab gates pass.
- `runtime.log`: `MQ27 RUNTIME: PASS (461 checks; 0 failures)`.
- `production_logic-final.log`: `MAQUETTE PRODUCTION LOGIC: PASS (1082 frames)`;
  `proof/production_logic/verification.json`: true, 0 errors.
- `ground_contact-final.log`: `GRB01 REAL FIGHT HEADLESS CONTRACT: PASS (standing + mid-move; front/rear and mirrors; 1920x1080; UI 100%)`.
- `python-default-final.log`: `Ran 178 tests in 31.635s` / `OK` (19 default modules,
  including approved-content production-PCK smoke and icon identity). The
  approved-content module was rerun after the final metadata/capsule refresh;
  see `approved-final.log`: `Ran 1 test in 14.201s` / `OK`.
- `python-audit/`: `ISOLATION AUDIT: 53 modules`; exit 0. No new `tests/test*.py`.
- `art-check.log`: `ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)`.
  `front-kit.log` / `rear-kit.log`: both `ART IDENTITY REPLAY: PASS`.
- `art-tests.log`: `Ran 111 tests in 82.419s` / `FAILED (failures=2)`.
  Both are `test_canon_sheet_covers_both_views_objects_scales_and_exact_doubling`,
  line 2204, front/rear: `AssertionError: 0.64 != 0.85`. This is the old hardcoded
  scale expectation, newly conflicting with the director's required value; the
  out-of-scope test was not changed or bypassed.
- `cel-grub.log`: `CEL_BUILD {"seconds": 0.47385579200000016, "counts": {"rigs": 74}, "total_files": 74, "touch_canvas_mismatches": []}`;
  `MQ27 CEL: PASS (74 owned variants; common builder; isolated output)`.
- `shadow_owned.log`: `MQ27 SHADOW CACHE: PASS (2 views; 80 unrelated entries preserved)`.
- `rebake-parser.log`: headless `tools/rebake_cutout_rests.gd --check-only`, exit 0;
  no native proof claim. `density-check.log`, exit 1: two missing native rebakes.

The first default run's import-sidecar failures were fixed. No full Godot or
all-groups Python suite was run. Existing NumPy/Accelerate warnings, Godot's
macOS CA warning, a final callback-probe ObjectDB leak-at-exit warning after
PASS/exit 0, and the read-only Git timing-cache write refusal were observed;
none was treated as a rendering success or used to change assertions.

## Proof for the design owner

Run stages in this order. `workflow.py` explicitly sets `LABYRINTH_CEL_LOOK=off`
for density/rest/native/sheets; only production, actual fights and consumer
captures use `all`. It uses only the approved runners, 1920x1080 and UI100;
density proof additionally emits the native 255px rest images.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-55 && python3 -B experiments/cutouts/burrow_grub/mq27/workflow.py density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-55 && python3 -B experiments/cutouts/burrow_grub/mq27/workflow.py rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-55 && python3 -B experiments/cutouts/burrow_grub/mq27/workflow.py native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-55 && python3 -B experiments/cutouts/burrow_grub/mq27/workflow.py sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-55 && python3 -B experiments/cutouts/burrow_grub/mq27/workflow.py production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-55 && python3 tools/inspection_fixture.py --task-id rr-55 --run-id rr-55-inspection --scenario combat --enemy-types burrow_grub --enemy-intents burrow --summary 'rr-55 mq27 Grub floor contact'
```

Density stage runs the actual native rebaker, records rests, refreshes identity,
only the Grub shadow entries and pins, then invokes the normal full cel builder.
If the native rebake and `RECORDED-RESTS` succeeded before a later failure, resume
with `workflow.py density-resume`. This headless stage validates and seals the
existing records, then continues shadow/check/cel/pins; it never rebakes,
processes paint or records new rests. Feedback 1 fixes the seal's case-local
rr12 director-source override; shared tooling and protected inputs are unchanged.
Use `workflow.py production-verify` to verify an existing production capture
without recapturing. Feedback 2 makes this case's expected production cel mode
`all`, matching its capture launch and the brief; every file hash still compares
exactly. Isolated source/native proof retains the shared `off` policy. Captured
manifests are never rebound or rewritten by this verification-only stage.
Rest/native/sheets produce `proof/native_rest/`, `proof/native/verification.json`,
`proof/burrow_grub_review.mp4` and `proof/contact_sheets/`. Production produces
`proof/production_native/verification.json`, `proof/ground_contact/`, plus the
isolated runner's `user://probes/rr55_surfaces/` and bestiary-lineup captures.
No windowed run was attempted here. The director owns capture inspection,
fixture verification, the stale test expectation, commit and publication.

Reproduction, if needed: run `build_case.py`, `workflow.py headless`, `verify.py`,
then `promote.py promote`. Do not rebuild merely to view the current proof.

## TODO_DESIGN and chosen defaults

No new design placeholder. The supplied maquette retains
`TODO_DESIGN_FRONT_FAR_LEG_VISIBILITY`; this rig does not invent those occluded
legs. New choices are proof-only: 144px comparison tile; 32px synthetic mutation
canvas, main rectangle `[8,8,20,20]`, stray origin `[4,4]`, bridge column 12
and rows `[5,8]` (`sweep.PROOF_DEFAULTS`); 8 surface-settle frames; runner's existing 300s headless cap; inherited
rr12 diagnostic dimensions/96px motion query and native 120s/900s stage budgets.
Proof output paths, generated ResourceUIDs and mask/crop coordinates identify
existing resources or approved paint. Player geometry above is measured from
that paint and existing board code, not new tuning.
