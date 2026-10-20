# rr-25 — Slag Mortar finish

Implementation is uncommitted on `codex/rr-25`. The design owner owns commits,
peer review, inspection and publication. No windowed run or full suite was
attempted. The existing `rr22/` case paths remain the production integration.

## Numbered requirements and task acceptance

1. **Masks and cut: PASS.** Both updated protected masks and their generator
   are imported byte for byte. Every opaque masked texel belongs to `mortar`;
   no outside texel does. All 63 previously reported fragment pixels are now
   covered. `proof/mask_fragments.json` reports zero outside fragments in both
   views. Each near arm is one connected visible piece. Both source-space
   rests still match the approved painting at **0 px**.
2. **Coverage root causes: PASS headless.** The cut and its covered materials
   are rebuilt from the new ownership. The existing continuation calibration
   is recomputed from the protected poses and bound to the new ownership.
   Hidden crucible paint uses its own edge texels, including beneath the
   shoulder/head. `rr22_surface_gates.py` now also rejects hidden texels whose
   RGB has no donor in their own visible piece. A one-skin-texel contamination
   mutation fails this gate. The protected paintings, masks, generator and
   motion stay unchanged. No exemptions were added. Feedback 1 makes the shared detached-paint checks strict, as described below.

   All **862 CPU coverage frames pass**, replacing rr-22's 8 front / 75 rear
   failed frames. There are zero holes or detached-paint errors. The existing
   inverse-source rule passes **2,198 front / 878 rear natural air pockets**
   (3,076 total), with every passed bound and occurrence count retained in
   `proof/seams.json`. Largest pockets are 578 / 1,001 pixels. Full per-frame
   pocket records remain in ignored `proof/logs/seams_full.json`.
3. **Headless gates: PASS.** Source/bone/knee gates report zero errors in both
   views. Both gait-01 walks have six swings, zero support drift and 3.5 px
   maximum total pelvis drop. Maximum extra fit is 0.091893 px front and
   0.098218 px rear. Signed lob/scatter direction, idle rigidity, supports,
   own-piece materials and chroma residue checks pass. Dense reach retains its
   specified reporting behavior: 6 front / 3 rear overreach reports, zero gate
   errors. Runtime, production logic, reference figure sets, mutations, SFX
   sync, identity and registration results are in `proof/results.json`.
4. **Windowed handoff: prepared.** The exact eight-stage sequence is below.
   Existing probe scripts and proof contracts are retained at 1920×1080,
   100% UI scale. Every runner in the Mortar driver now uses task `rr-25`.

These satisfy the task contract's two implementation acceptance criteria:
exact mask ownership/connected near arm/0 px rest; and all headless Mortar
coverage, source, bone and gait gates in both views. Native GPU acceptance
remains pending the design owner's windowed sequence.

## Feedback 1 — review of 5369d4cb6

1. **Detached opaque paint requires provenance.** `clean_metrics` now requests
   colour-independent counts from `detached_metrics(..., allow_outline=False)`.
   `source_space.py` removes only components certified as originally detached
   in the approved painting and transported rigidly with their owner. It no
   longer classifies certified components by size, darkness or distance.
   Feeding pre-exempted legacy metrics to the classifier fails explicitly.
   The director reproduction and the regression cover bright/dark severed
   tips for both rigid and skinned owners. Every unmatched tip fails.

   Generic changes are limited to `tools/humanoid_cutout/source_space.py`,
   `gates.py` and the optional strict-count argument in `silhouette_gates.py`.
   The legacy primitive remains available to older diagnostics; native/CPU
   clean-piece gates always request strict counts. `rest_space.py` is not
   present on this branch and was not changed; rr-26 can reuse strict counts.
2. **Walk clock has one source.** The Mortar renderer calls
   `Action.frames_for("slag_mortar", "move")`. The duplicate cycle duration is removed; the required frame-period API
   derives from `Action.FPS`. The runtime regression mutates only the process-local cached
   move duration to a named test value, verifies the frame count follows it,
   and restores the original before other checks. Protected motion is unchanged.
3. **Focused handoff: PASS.** All 862 strict CPU frames pass with zero errors;
   no Mortar textures changed. The focused set reports `Ran 30 tests in 15.112s`
   / `OK`; references plus legacy silhouette primitive checks report
   `Ran 99 tests in 188.553s` / `OK`. Runtime passes 478 checks, affected
   integration 513 checks, production 1,516 frames per view, and the exported
   package passes with `editor=false`. Exact feedback-round logs/results are recorded under
   `proof/results.json` → `feedback_1`. Windowed proof is still pending the
   owner; the eight commands below remain unchanged. The package fixture was
   updated to handle the registry's formatted renderer path before traversing
   the new Action preload closure; the exported package smoke passes.

## Files changed

- `rr22_build.py`: also imports the protected mask generator as provenance.
- `rr22_surface_gates.py`: checks hidden material against its own-piece donors.
- `rr22_proof.sh`, `tests/test_rr22_humanoid.py`: use the current task runner ID.
- `tests/test_rr25_mortar_finish.py`: mask, connected-arm, source-rest,
  all-piece donor and one-texel contamination regressions.
- `rr22/`: imported masks/recipe, ownership, visible/hidden cuts, checks,
  meshes/layouts, tucks, continuation bindings and compact proof records.
- `assets/units/slag_mortar_cutout/`: matching promoted layouts, changed arm
  and crucible textures, and integration fingerprints.
- `spec/assets/board_pixel_density/`: eight changed Mortar source textures and
  their eight output records. Every other record is identical.

Every other figure, shared runtime files, the identity registry and shadow-cache
bytes are unchanged. The three generic offline gate changes are listed below. Scoped shadow refresh passes for both v2 views and verifies
that every other unit's entries/fingerprints are retained. Protected inputs
(152 tracked files) remain byte-identical to HEAD.

## Headless reproduction

Run from this worktree. A changed protected ownership revision needs the first
build/sample/rebuild sequence; later builds can reuse the hashed calibration.
Build promotion restores raw textures, so density processing follows each build.

```sh
python3 experiments/cutouts/slag_mortar/rr22_build.py
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr22 --output res://experiments/cutouts/slag_mortar/rr22/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr22_build.py
python3 experiments/cutouts/slag_mortar/rr22_density.py --refresh-sources
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr22 --output res://experiments/cutouts/slag_mortar/rr22/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr22_records.py samples
python3 experiments/cutouts/slag_mortar/rr22_gates.py
python3 experiments/cutouts/slag_mortar/rr22_seams.py
LABYRINTH_TASK_ID=rr-25 python3 -m unittest discover -s tests -p 'test_rr2[25]*.py' -v
LABYRINTH_TASK_ID=rr-25 PYTHONPATH=tests python3 -m unittest test_rr10_humanoid test_rr11_humanoid test_rr17_cutout test_rr18_humanoid test_rr19_overlap test_gait01 -v
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/affected_suites.gd
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/native_capture.gd -- --output res://experiments/cutouts/slag_mortar/rr22/proof/native --validate-only
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/rr22/shadow_refresh.gd
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/suites/sfx_sync_0_program.gd
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/suites/sfx_sync_1_program.gd
python3 tools/godot_task_runner.py --task-id rr-25 --stream -- godot --headless --path . --script tests/suites/sfx_sync_2_program.gd
python3 tools/test_registration_audit.py
python3 -m unittest discover -s tests -p 'test_art_identity_gate.py' -v
python3 -m unittest discover -s tests -p 'test_icon_identity_policy.py' -v
```

## Proof for the design owner

Run in this order. The driver contains the exact visual-runner flags, semantic
contracts, manifests and capture paths. No inspection-fixture command was
required by this brief; inspection remains assigned to the owner.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh walk
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-25 && sh experiments/cutouts/slag_mortar/rr22_proof.sh review
```

`density` processes pieces, rebakes/records native rests, seals metadata,
refreshes scoped shadows and checks density. `native` refreshes full samples
and their compact inventory, captures all poses and runs the strict native
pixel/feature/negative-space gates. `sheets` and `review` require fresh native
proof and continue to reject absent/stale evidence.

All paths below are relative to `rr22/` and ignored:

- Observed and inspected: `proof/contact_sheets/source_cuts_outlined.png`;
  `proof/seam_cpu/rr25_{front_death_0031,front_scatter_0008,front_lob_0038,rear_death_0019,rear_brace_0024}.png`.
  These are source/CPU diagnostics, not GPU renderer proof.
- Owner captures: `proof/native_rest/`, `proof/native/`, `proof/contact_sheets/`,
  `proof/gait_move_native/`, `proof/gait_move_sheet.png`, `proof/idle_native/`,
  `proof/production_native/{front,rear}/`, `proof/slag_mortar_idle_comparison.mp4`
  and `proof/slag_mortar_review.mp4`.
- Test logs and full evidence: `proof/logs/rr25-*.log`,
  `proof/logs/samples_full.json`, `proof/logs/seams_full.json` and
  `proof/logs/{production_logic,production_logic_rear}/logic_frames.json`.

The retained `proof/{front,rear}_stray_sources.json` are historical rr-22
failure traces; current zero-failure evidence is `proof/seams.json`.

## TODO_DESIGN placeholders

None. No director choices or perceivable defaults were introduced.

## Chosen defaults

The original test fixture's 4×4 canvas, grey pot texel (70,70,70,255) and skin
mutation (110,60,30,255), plus the five CPU diagnostic frame selections.
Feedback 1 adds the synthetic connected dark-tip fixture (bridge/tip at
(25,10)/(26,10), dark RGB 10/10/10 and bright RGB 100/60/40), and a 1.25 s
process-local duration mutation. They are named in the tests and
`proof/chosen_defaults.json`. Existing proof
origins, camera/layout values, seeds and timeouts are retained there too.

## Open issues

The sandbox has no macOS window server. Native GPU proof and the two native
rest rebake/record steps remain for the owner. Density `--check` therefore
returns the two explicit `rest rebake needed: ... no rebake record` lines.
Production integration deliberately remains `ready: false` until native proof.
The current `proof/native_gates.json` records this as pending, not a GPU pass.
The production-only release-template smoke passes with `editor=false` using
an adjacent `godot.pck`; its disabled path-override flags were not needed.
Full suites, peer review, commits, publication and inspection were not run,
as assigned by the brief. Some headless Godot probes emit the existing system
certificate and exit-time resource cleanup diagnostics; exact logs are retained.
