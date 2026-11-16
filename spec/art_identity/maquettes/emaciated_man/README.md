# emac-01 implementation handoff

Status: **incomplete — numeric subject geometry awaits design authority**.
The brief specifies the pose and approximate proportions but supplies neither an
approved primitive recipe nor joint coordinates. Under the worker's explicit
no-design rule, these remain named `TODO_DESIGN_*` fields in `recipe.json`.
No Emaciated Man image, painting, prompt, kit, rig or production asset was created.
All changes remain uncommitted. No Git writes, peer review or queue changes ran.

## Acceptance criteria

1. Seated pose, empty lap, sack beside the near knee, arms and chunky masses:
   transcribed into `recipe.json`'s pose contract; actual geometry **pending**.
2. Front-only standard board camera and nine ordered ownership parts:
   implemented through shared `geometry.py`, `raster.py`, `humanoid.py` and the
   maintained CPU Cycles capture adapter. Native execution **not verified**.
3. Neck, shoulders, elbows, near wrist and fixed sack-base projections:
   the seven requested joints plus the existing-style root are required;
   projected native output **pending** geometry/capture.
4. Seated hood at 0.62 hero standing H; minimum three-pixel limbs:
   geometry checks enforce floor Z=0/hood Z=0.62 with H=1 and capsule/limb
   thickness. Framing derives the target projected height from canon hero alpha,
   multiplies by 0.62 and renders at K=4. Actual scale and pose await owner inspection.
5. Label/clay, nine solos and board row at 1x/2x NEAREST:
   capture/proof code implemented; all actual subject outputs **pending**.
   The row uses the approved captured backdrop and slots, with hero / clay /
   Grave Surgeon at the shared board scale. It never uses synthetic tile art.
6. Art identity registry remains unaffected: required check observed green.
   No prompt or `kit.json` was written, and the subject is not registered.

## Recipe interface

Fill the seven `TODO_DESIGN_joint_*` fields with XYZ vectors. `root` is the tile
origin. Replace each of the nine `TODO_DESIGN_rounded_primitives_*` shape rows
with one or more of the shared geometry schema's rounded `ellipsoid`, `capsule`,
`limb`, `shell`, `torso` or `cloak` shapes bearing that row's exact `part` name.
The supplied order is retained independently of shape row ordering. All
coordinates/dimensions are in hero standing height units (H=1). Rotations are
XYZ radians. Hood and back drape must remain in `head_hood`; feet remain in
`legs`; the far forearm and hand share `far_forearm_hand`.

`--check` rejects every unresolved placeholder before building geometry.
`--raster` writes only a clearly named diagnostic ownership preview, never a
clay or native proof substitute. `--proof` verifies native capture hashes,
nonempty solos, dimensions and the front-only joint inventory before composing
the board comparison. A stale capture fails rather than being silently reused.
Numerical checks cannot certify the pose/overlap requirements.

## Observed verification

- `python3 tests/test_art_identity_gate.py`: `Ran 111 tests in 84.824s`; `OK`.
  Existing NumPy matmul runtime warnings and Pillow deprecation warnings appeared.
- Inline, temporary disconnected-sphere fixture (not a proposed character):
  `EMAC_SYNTHETIC_PIPELINE: PASS; nine parts; eight joints; framing; 1x/2x; stale capture rejected`.
  This checked recipe compilation, geometry validation, NumPy raster ownership,
  manifest validation and proof composition. Temporary synthetic images were removed.
- `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/emac-01/python-audit`:
  `ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/emac-01/python-audit/isolation-audit.md`;
  exit 0. No new test module or suite-resource entry was added.
- `python3 spec/art_identity/maquettes/emaciated_man.py --check`:
  `EMAC_BLOCKED: recipe.joints.neck: TODO_DESIGN_joint_neck; ...`; exit 2,
  expected until design data is supplied.
- No native Blender, Godot, windowed capture or play session was attempted.
  No full Python or Godot suite was run.

## Proof for the design owner

After resolving the recipe fields, run these exact commands in order:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/emac-01 && python3 spec/art_identity/maquettes/emaciated_man.py --check
cd /Users/borgerding/workspace/Labyrinth.worktrees/emac-01 && /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/emaciated_man.py -- spec/art_identity/jobs/emaciated_man/mq_front
cd /Users/borgerding/workspace/Labyrinth.worktrees/emac-01 && python3 spec/art_identity/maquettes/emaciated_man.py --proof spec/art_identity/jobs/emaciated_man/mq_front
```

The headless native command uses the brief's Blender entry point and CPU Cycles;
it does not start a window. The separate Python proof command supplies Pillow
without requiring it in Blender's Python. No windowed command,
`visual_probe_runner.py` or `inspection_fixture.py` applies: this unit changes
only authoring geometry, and has no game scene or UI.

Expected outputs under `spec/art_identity/jobs/emaciated_man/mq_front/`:
`front_parts.png`, `front_clay.png`, nine `front_solo_<part>.png`,
`front_silhouette.png`, `joints_px.json`, `maquette.blend`, native capture/check
manifests, `refs/01_maquette_front_parts.png`,
`refs/02_maquette_front_clay.png`, `front_clay_drawn.png`,
`board_row_1x.png`, `board_row_2x.png`, `board_comparison.png`, and
`proof_report.json`. None of these subject captures exists yet.

## Chosen defaults

These are authoring/debug/proof settings, not production appearance choices:

- `LABEL_COLOURS`: nine distinct diagnostic RGB labels; never paint colours.
- `PROOF_DEFAULTS`: existing 1024-square native capture, K=4, 256 canvas,
  existing [128,246] board anchor, alpha cutoff 128, numerical tolerance 1e-6,
  approved backdrop slots [1,2,3] and shared board-sheet crop/text settings.
- Existing shared renderer settings: CPU Cycles, 32 clay samples, seed 0,
  eight threads, neutral clay and established studio lighting.
- Temporary synthetic fixture only: radius .025, grid step .08, grid Z .05,
  hood-test centre Z .595, raster size 1024; these never enter the recipe.

Open issues: numeric geometry and actual native captures are outstanding. The
owner must inspect silhouette, anatomical pose, occlusion/layering, sack/hand
contact, both visible feet, empty lap and board scale after capture. The worker
has not claimed a design review or native-render pass.
