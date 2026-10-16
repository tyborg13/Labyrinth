# Shared maquette geometry and source fitting (mq-02)

This is authoring tooling, with no game runtime, save, balance, icon or analytics
change. Approved jobs, original specs and `tools/maquette_cutout.py` are read-only.
The design owner owns commits, peer review, inspection and publication. This
worker leaves its edits uncommitted and does not edit queue state.

## Acceptance / proof contract

Risk tier: **standard**, as specified by the task handoff. No playable inspection
fixture applies: the output is mesh authoring data and numerical diagnostics.
Blender proof is 1024² using the existing orthographic board camera; the 1920×1080
UI rule does not apply to these maquette renders.

1. Every primitive is built in `geometry.py`, including the literal legacy
   shrike transcription in `shrike_spec.py`. Blender's adapters consume those
   triangles without geometry modifiers. All available committed solo masks
   must clear 0.98 IoU. Missing solo baselines require director proof; combined
   visible label maps are also reported without hiding failures.
2. NumPy rasterisation returns both unoccluded per-part masks and depth-tested
   visible owners; front/rear joint projection must agree within 1 px.
3. Optional profiled limbs, section torsos, partial shells, draped cloaks and
   per-part voxel unions must be deterministic and covered by synthetic checks.
4. Measurement reports height-normalised IoU, 24 band errors and annotated
   landmark errors, with a cyan/magenta/white overlay. Fitting preserves shape
   types/labels, clamps band ratios to [0.6, 1.6], and writes only `spec_fit.json`.
5. Lancer r2 must meet the brief's proportion intent and gate. **Pending design
   data**: the brief supplies intent but no approved r2 numeric geometry,
   measured source frame or landmark fractions. `spec_r2.json` is explicitly an
   incomplete template, not an approved sculpt or passing fit. Existing r1
   geometry is retained as a runnable fallback; no dimensions were invented.

The task helper currently reports an empty contract despite the handoff saying
it was recorded and preflight passed. This document records the worker's
observable criteria without changing Git metadata or the owner's queue.

## Specification additions

All existing primitive fields retain their meanings. XYZ Euler rotations are
radians. Dimensions and joint coordinates use the original world units.

- `limb`: `a`, `b`, `radii: [r_start, r_mid, r_end]`, `mid_at` strictly between
  zero and one. Radii interpolate linearly through the profile; endpoint spheres
  retain capsule caps. No profile values are inferred by the builder.
- `torso`: optional `at`/`offset` or `c`, `rot`, required increasing `sections`
  with `z`, full lateral `width`, full forward `depth`, and superellipse exponent
  `round` (2 is an ellipse). A zero-width/depth end closes a pointed tip.
  `lean: [dx_per_z, dy_per_z]` offsets section centres relative to the shape
  origin. Sections loft linearly; caps are triangulated.
- `shell`: ellipsoid `s`, `at`/`c`, `rot`; `cut: {polar: [start, end],
  azimuth: [start, end]}` in radians. Polar zero is +Z. Optional world-space
  `thick` closes the rim, offset inward from the original surface. Without cuts
  it is the original full ellipsoid; no unapproved cap angles are selected.
- `cloak`: required `anchors` (joint names or coordinates, in far-to-near
  shoulder order around the back), `length`, `hem_width` (hem diameter), `flare`
  (radial bow beyond straight drape), `wrap` radians, `folds: {count, depth}`,
  `rag: {count, depth, seed}`, `thick`. Optional `angle_range` selects a labelled
  portion of the wrap, so `cape_near` and `cape_far` can retain separate ownership.
  The hem is below the anchors' mean Z by `length`; seeded notches raise it.
- `part_options: {part_name: {smooth: true, voxel: world_size}}` unions that
  part's primitives before rendering and fitting. It also enables smooth
  normals. A shape's explicit `smooth`/`voxel` may supply the same options for
  its whole labelled part. No default voxel size is chosen. `smooth_normals`
  alone preserves the legacy shrike shading without changing geometry.
- `mesh` (vertices/faces), `cone` and `cylinder` retain the shrike's existing
  geometry in the shared pipeline; the old centroid-only export cannot recreate
  a silhouette, so the literal factory supplies that missing source geometry.

Voxel union uses closed-mesh parity occupancy, marching tetrahedra and two mild
Laplacian relaxation passes. The output is welded triangles. Blender consumes
exactly this result rather than doing a separate voxel remesh. Legacy bevels
are tessellated in the unscaled local metric, including tapered helms.

## Measurement and fitting

`fit.source_frame` supplies `head_top`, `sole_bottom` and `ground_x` in source
pixel-edge coordinates. This is necessary when a spear extends above the hood.
The source image remains untouched. If annotations are absent, the overlay uses
an explicitly disclosed foreground-bounds diagnostic and the gate fails closed.
The maquette head top comes from `head_part` (default `head`); the lowest body
sole excludes `weapon_parts`. Ground centroid uses the bottom 1% contact band.

`fit.landmarks` maps names to `{y: source_fraction, joint: joint_name}` or
`{y: source_fraction, joints: [names]}`; the latter measures the mean projected
height. Fractions are 0 at head top and 1 at the lowest sole. `weapon_only_bands`
can mark director-measured source-only weapon bands; bands containing only the
maquette weapon are also excluded from width-error gates. IoU still includes
the entire silhouette, including weapon pixels beyond the head-to-sole range.

Widths are mean row spans in each of the 24 figure-height bands (zero-width
rows do not contribute). Relative error is `abs(maquette-source)/source`.
The all-empty case is zero; extra geometry in a source-empty band has error 1.
`fit.gate` keys and defaults are `iou_min: 0.80`,
`median_band_error_max: 0.12`, `max_band_error_max: 0.30`,
`landmark_error_max: 0.03`. Any `TODO_DESIGN_` data blocks a passing gate.

The fitter maps projected heights piecewise between landmarks, adjusting joint
Z and attached/free primitive data together. Up to six numerical correction
passes account for changes in the discrete raster frame. It then writes
`fit_width_profile`, with clamped continuous band ratios for each part. This
deforms meshes and joints along camera-right, leaving camera depth and projected
height unchanged. Primitive types and original parameterisation survive.
Fit the original spec, not an already deformed `spec_fit.json`. Camera fitting
currently requires an identity front object transform (the humanoid front and
the committed shrike's FRONT_YAW=0); other poses fail explicitly.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-02
python3 tools/maquette_fit.py measure --spec spec/art_identity/maquettes/frostglass_lancer/spec_r2.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --out spec/art_identity/maquettes/frostglass_lancer/proof_r2 --require-gate
python3 tools/maquette_fit.py fit --spec spec/art_identity/maquettes/frostglass_lancer/spec_r2.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --out /private/tmp/labyrinth_codex/mq-02/fit
python3 tools/maquette_fit.py raster --spec spec/art_identity/maquettes/frostglass_lancer/spec_r2.json --out /private/tmp/labyrinth_codex/mq-02/raster
python3 tools/maquette_fit.py compat --out spec/art_identity/maquettes/proof_mq02 --require-gate
```

Until the design placeholders are resolved, `measure --require-gate` exits 1
and `fit` exits 2 with the missing values named. Measurement without
`--require-gate` still writes the failing report and overlay successfully.

## Proof for the design owner

No Blender, GUI, visual-probe or windowed command was attempted in the worker
sandbox. The director can print every exact command, then execute the complete
capture and comparison contract:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-02
python3 spec/art_identity/maquettes/director_proof.py --print-only
python3 spec/art_identity/maquettes/director_proof.py
```

The script obtains the two original builders with read-only `git show` at the
recorded base commit, captures legacy/shared versions of all five creatures,
and captures the lancer r2 template. It compares every old/new **solo alpha
mask** at >=0.98 IoU and joints within 1 px; missing solos fail explicitly.
It separately compares shared Blender captures against the NumPy rasteriser.
Results and command return codes are written to
`/private/tmp/labyrinth_codex/mq-02/director/director_results.json`.
`--blender` and `--out` can override machine paths. There are no retries.

The six shared-builder capture commands are:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/humanoid.py -- spec/art_identity/maquettes/frostglass_lancer/spec_r2.json /private/tmp/labyrinth_codex/mq-02/director/lancer_r2
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/humanoid.py -- spec/art_identity/maquettes/chainbound_gaoler/spec.json /private/tmp/labyrinth_codex/mq-02/director/chainbound_gaoler/shared
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/humanoid.py -- spec/art_identity/maquettes/frostglass_lancer/spec.json /private/tmp/labyrinth_codex/mq-02/director/frostglass_lancer/shared
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/humanoid.py -- spec/art_identity/maquettes/lightning_wisp/spec.json /private/tmp/labyrinth_codex/mq-02/director/lightning_wisp/shared
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/humanoid.py -- spec/art_identity/maquettes/shale_bloomer/spec.json /private/tmp/labyrinth_codex/mq-02/director/shale_bloomer/shared
FRONT_YAW=0 /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/gust_shrike.py -- /private/tmp/labyrinth_codex/mq-02/director/gust_shrike/shared
```

No `inspection_fixture.py` command applies: there is no scene/gameplay state to
inspect. The director inspects the source overlay and Blender maquette captures.

## Chosen defaults

New choices are numerical approximation/proof settings, not creature tuning.
Their named fields live in `MESH_DEFAULTS`, `RASTER_DEFAULTS`, `FIT_DEFAULTS`,
`PROOF_DEFAULTS` and the explicit synthetic shape fixture dictionaries in
`tests/test_maquette_geometry.py`.

- Legacy tessellation is retained: ellipsoids 24×12, capsules 20×10, chains
  48×12, bevel four steps; shrike ellipsoids 32×16/cone 24/cylinders 12.
- New sampling: 16 limb intervals, 32 torso perimeter samples, 24×64 cloth
  intervals. Voxel work is capped at 8,000,000 cells; relaxation uses two passes
  at weight 0.25. Parity rays use a fixed sub-voxel XY perturbation
  [1.234567e-7, 3.456789e-7] to avoid shared-edge degeneracy.
- Raster uses pixel centres, 1e-9 edge tolerance, alpha cutoff 128. Normalised
  proof height is 1024, source green-key distance 60, contact band 1%, overlay
  padding 24 px/chart width 320 px. Height fitting uses at most six passes with
  0.001 fractional residual tolerance. Width-ratio clamps and gate thresholds
  are the brief's values.
- Paths, baseline commit and platform Blender path are plain named proof
  fields in `director_proof.py`; the compatibility colour decoder uses the
  installed Blender 5.2 OCIO LUT through the existing cutout decoder. Raster
  previews use sRGB label colours for diagnostic ownership, not paint colours.
- R2 template limbs use the exact r1 linear midpoint (mid_at 0.5); torso
  sections transcribe r1's ellipsoid rings; pauldron shells remain uncut r1
  spheres. Each unresolved design replacement is marked, and original r1 data
  is untouched.
