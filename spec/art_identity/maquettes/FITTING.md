# Maquette geometry and source fitting

## Blender-native v2 — mq-03, round 3

V2 is selected by `version: 2`. The owner approved the external Blender bridge
and source-measured proposals on 2026-10-16; round 3 follows the 2026-10-17 facing/tabard review. Every r3 value is numeric and marked
`proposed: true` at the spec/piece/registration level. The original r2 spec,
identity image, fit annotations, gate, camera and existing label colours remain
unchanged. No game code, saves, analytics, balance or icon registry changed.
The branch remains uncommitted; review and publication belong to the owner.

Local Blender still exits 139 during Metal initialization under the sandbox.
All successful native tests, builds and captures use `blender/bridge_client.py`
and the director-owned bridge. The worker never launches Blender directly or
starts the external service. The client atomically queues unique JSON jobs,
serializes native work, waits for the matching result, and retains the log path.
The service enforces factory startup, disabled autoexec, script/argument roots
and a maximum 1800-second timeout; the client default is 900 seconds.

Risk/proof: standard authoring tooling; focused Python, full Python discovery,
art identity checks, native geometry tests, source fit and rendered evidence.
There is no playable scene or UI, so no inspection fixture/Godot visual probe
applies. Maquette captures retain the existing 1024×1024 orthographic camera.

The approved cache bundle is Blender Human Base Meshes v1.4.1 (CC0). ZIP SHA-256:
`811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`.
Extracted blend SHA-256, also checked against its verified ZIP member:
`3c121505651140ceb4d69fd1d8923f7788ffadd81672f5be14845a5f2c75c137`.
The public asset id `realistic_body_male` names a thumbnail camera in this bundle;
the builder resolves its actual `GEO-body_male_realistic` mesh. R3 evaluates the
original 10,582-vertex surface at subdivision level 0, preserving real anatomy
and avoiding failed heat weighting on the dense multires evaluation. No body
asset substitution or new asset download was needed.

### V2 data contract

Coordinates use the legacy world convention: +X forward, +Y near side, +Z up;
Euler rotations are XYZ radians. Required numeric fields have no sculpting
fallbacks. Any `TODO_DESIGN_*` key or string fails before Blender starts.

- `base: {asset, matrix}` appends the named object or collection from the
  approved bundle. `matrix` is the owner-supplied 4×4 asset registration. The
  bundle's evaluated surface is frozen before binding, so weight ownership and
  posed topology agree. The original bundled file is never saved over.
- `joints` contains desired posed joint coordinates, retaining the existing
  fitting/landmark interface. `armature.rest_joints` contains anatomically
  registered joint coordinates in the transformed base's rest pose. They are
  deliberately separate: binding in the desired pose cannot bend a neutral
  base correctly. Terminal tips must also be explicit.
- `armature.bones` is a list of `{name, head, tail, parent, region, roll,
  scale: [transverse_x, transverse_z]}`. `head`/`tail` name joints in both maps.
  Blender binds with `ARMATURE_AUTO` heat weights. Pose matrices put each bone
  head/tail at the desired coordinates, derive length from those endpoints,
  and scale transverse axes without propagating a parent's thickness into its
  children. Body polygon ownership is the greatest sum of heat weights by
  region; any unweighted polygon fails. `armature.collision_margin` configures
  the frozen posed-body collision surface.
- `simulation: {gravity, fps}` supplies scene physics. Cloth `stiffness` is an
  explicit map of Blender `ClothSettings` property names/values, including the
  desired quality, mass, tension/compression/shear/bending stiffness, damping,
  pin stiffness and time scale as applicable. Unknown property names fail;
  settings omitted from an approved map use that Blender version's native
  settings. Blender's version is part of the cache key.
- Every `piece` has unique `id`, `type`, `part` (a key in `labels`), `at` (joint),
  `offset`, and `rot`. Optional `bone` orients it in that posed bone's frame.
  Labels are linear RGB, as in v1. Existing label colours are not changed.
- `plate`: `outline` is a local XZ polygon; native Solidify (`thick`), Bevel
  (`bevel: {width, segments, angle_limit}`, sharp outer miter), then Shrinkwrap
  onto the posed body (`offset_surface`). Optional `ridge: {line: [[x,z],
  [x,z]], height}` inserts a constrained edge with Blender's 2D constrained
  Delaunay triangulation, raised toward local -Y. Optional `conform_weights`
  gives one shrinkwrap weight per outline/ridge input vertex, so a designed
  ridge need not be flattened onto the body.
- `lames`: the plate fields plus `count`, `lame_scale` (one XZ pair per lame),
  `lame_drop` (one attachment-space XYZ offset per lame), `overlap` (one surface
  lift per lame). All arrays must match the count. Each plate retains its part.
- `cloth`: `kind` is `cloak`, `collar`, `tabard`, `skirt` or `hood`; `pattern`
  contains `columns`, `closed`, `rows` and explicit `pins` vertex indices.
  A row is either `{a: [x,y,z], b: [x,y,z]}` for an open panel or `{centre,
  radii: [x_radius,y_radius], angles: [start,sweep]}` for an annular/open cowl
  section. Consecutive sampled rows are sewn with quads. Closed rings require
  a multiple of four columns and weld the final column to the first.
  This representation supports flat panels, annular collars and open pointed
  cowls; the owner supplies the pattern shape and its initial drape placement.
  Optional `splits: {from_row, columns, gap_columns}` removes lower-row quads
  before simulation, retaining one connected upper panel. Three cuts create
  four strips. Loose cut-away points are pruned with pin indices remapped. `pin_group`, fixed `frames`,
  `stiffness`, `collision_margin`, `self_collision`, `thick`, `solidify_offset`
  and `rag: {count, depth, seed}` are required. Seeded hem notches raise sampled
  hem vertices **before** cloth simulation. Optional `wind: {location, rot,
  strength}` has zero procedural noise. Simulation steps/evaluates every frame,
  freezes the result, then Solidifies. Cache keys include the complete spec,
  approved bundle digest, Blender version and cache revision; cached geometry
  has a verified mesh hash. Fresh builds use separate caches in the proof.
- `curve`: `path`, `spline` (`POLY`/`BEZIER`), `radius`, `taper` (one radius
  multiplier per control point), `closed`, `resolution`, `bevel_resolution`.
- `crystal`: `path`, `sides`, `length`, increasing `width_profile` pairs
  `[length_fraction, radius]`, ending at `[1,0]`, and `jag: {count, depth, seed}`.
  Jags are seeded faceted outward teeth on non-tip vertices. `continues` names
  an earlier curve; its transformed endpoint/tangent replace the crystal path,
  so differing attachment frames cannot detach or redirect an icicle tip.
  Alternatively `continues_bone` uses a posed bone's tail/tangent. Without a
  continuation, rings follow the explicit polyline, normalised to `length`.
- `gem`: `sides`, `length` (local Z), `width` (local X), `depth` (local Y).
  A two-tip bipyramid with a four-vertex waist makes the requested front-view
  diamond. Placement/inset is the piece's explicit `offset`.

`build.py SPEC OUT` saves editable `maquette.blend` and `build_report.json` with
per-object and combined evaluated mesh hashes. Frozen render objects preserve
piece ids/types; the original weighted armature/base, native curves and plate
modifier stacks remain hidden but editable in the blend. Cloth keeps its baked
surface and editable thickness modifier.
The report gates face label coverage, cloth/body triangle intersection and
sampled signed clearance, front/back collar lateral extents, and corner erosion
within the explicit bevel width. Clearance samples include vertices, edge
midpoints and face centroids; BVH triangle overlaps additionally catch crossings
between samples. The collider's mesh normals must face outward.

`--engine cycles` is the default CPU path, with emission materials for exact
labels and a neutral studio/AO clay material. `--engine workbench` is an explicit
director choice; there is no automatic failed-render retry. Both output existing
`front/rear_parts.png`, `front/rear_clay.png`, all `*_solo_<part>.png`,
`front/rear_silhouette.png`, and `joints_px.json`, at the legacy camera/size.
`--gallery` adds `piece_gallery/{front,rear}_{type}.png` for every accessory type.
Solos include hidden body regions, split using the heat-weight ownership.

V2 `measure` reads Blender-rendered alpha silhouettes and projected joints,
either freshly captured or supplied with `--renders`. A spec digest rejects
captures from a different spec. V2 `fit` iterates only joint Z values and bone
transverse scales, clamping total scale changes to [0.6, 1.6] of their initial
values. It never writes into `pieces`, the base recipe, rest joints, labels or
the source image. Attachments follow the new pose. A fit history records the
method and measured passes. The r2 proportion gate is unchanged; failed fits
remain failed diagnostics. V1 fitting/rasterisation is unchanged.

### Round-1 implementation additions

`base.object` explicitly resolves an asset to its mesh; optional
`base.subdivision_level` sets native subdivision evaluation before binding.
If direct heat weighting fails, the builder can heat-bind a closed native voxel
proxy and transfer its weights back using native Data Transfer, keeping the
original visible anatomy. The binding proxy voxel size is a technical field in
`BIND_DEFAULTS`.

Cloth pattern rows may also be explicit `points`, with exactly `columns` XYZ
coordinates. This records measured irregular hems and rear trails directly.
`solver_margin` separates the native solver envelope from the required verified
clearance. `collision_refine_levels` refines contact triangles with native Simple
Subdivision, then iteratively corrects violated collision constraints; distant
vertices retain the simulation result. Interior tests use majority ray parity,
avoiding the false inside classification that nearest-face normals can produce
at concave edges. BVH overlaps, vertices, edge midpoints and face centroids are
still independently checked after Solidify.

A collar can declare `symmetry_origin`, `symmetry_front`, and
`symmetry_lateral`, so the gate follows the actual actor facing rather than a
hard-coded world axis. Plate corner erosion is bounded by the designed bevel
width divided by the corner half-angle sine. Per-piece errors and front/back
collar extents are retained in `build_report.json`.

The source-measured recipe is `blender/propose_lancer.py`; it transcribes plate
corners, shoulder/limb landmarks, cloak boundaries and ragged hems from the
untouched identity reference. It preserves all 27 brief pieces and their counts,
including the five-sided, six-jag crystal continuing the shaft direction.
The round-1 source fit passed at IoU 0.804414, median band error 0.083320,
maximum band error 0.240221, with all landmark checks and geometry gates passing.
Native fresh-build mesh hashes match. No `TODO_DESIGN_*` remains in r3.

`--fit-only` captures actual Cycles front silhouette/body/head mattes plus
projected joints; fitting does not need dozens of solo passes at every iteration.
`--preview` captures parts/clay/silhouette for both views without solos, plus front body/head mattes when a fit contract exists. Full
captures retain every legacy filename and all solos. `--gallery` adds each of
the six accessory types in both views. Label/silhouette passes use one Cycles
sample; clay uses 32 samples. `capture_saved.py` can recapture a hash-matched baked
build without rebinding. All these entry points run through the bridge.

### Round-2 conforming armour

`blender/refine_lancer.py` applies the director's round-2 changes to the measured
round-1 recipe. This is the historical round-2 recipe; use `round3_lancer` below to reproduce
the current spec.
The approved r2/reference data remains read-only. All 32 pieces are proposals;
the three face pieces and two boot shells supplement the original 27 pieces.
Collar and cloak patterns/physics, anatomy asset/registration/rest rig, standing
joint locations, camera, gate and original labels are retained. The near wrist
moves to the hip; terminal foot directions put both boots forward while the
ankles remain planted. The cowl's clearance above the unchanged skull is reduced
40%, and its lower rows widen into the collar.

All r3 plates/lames declare `conforming: true`. A constrained, sampled outline
is projected to the posed contact surface; a full-weight native Shrinkwrap then
runs **before** ridge displacement, Solidify and sharp Bevel. There are no
partial `conform_weights` in r3. The contract rejects a surface offset plus lame
lift above the director's 0.015 limit (actual offsets 0.008–0.014). Legacy weighted
plates remain supported for existing specs/fixtures. Corner erosion is checked
against the actual post-Shrinkwrap/pre-Bevel corners, including the plate's half
thickness; a separate contact gate rejects a deliberately floating plate.

`body_regions` selects native heat-weighted anatomy. `contact_hull` uses Blender's
convex hull of that anatomy (`contact_min_z`/`contact_max_z` optionally delimit a
region), so rigid armour bridges skin recesses instead of copying facial or
muscle creases. `contact_pieces` adds the underlying collar/tabard surfaces for
shoulder/hip stacks. `surface_spacing` controls surface sampling. Native
source objects retain the wrapping target name; reports bound distance by the explicit
offset, thickness, ridge and bevel miter. `body_shell` makes a closed envelope
for boots/gauntlets; `cuff_flare` and `cuff_height` drive its native Displace cuff.
These envelopes and garment contacts are retained in the editable blend.

The face plate has two real native Boolean `slots` with separate narrow cross
inlays. `base.covered_regions` and `covered_above_z` remove covered skin only from
render copies; the original weighted body and posed collision anatomy remain
intact. This prevents a face/fingers/toes showing through fitted covers.
`clay_colour` and `accent_colour` are explicit source-based material proposals;
flat ownership passes retain their label colours. `seat_on` and `seat_contacts`
project the gem's diamond onto the frozen breastplate/collar surfaces, with the
explicit `seat_offset`. Crystal `jag.indices` can identify six irregular teeth
while retaining the fixed seed and five sides. Its head is 22% of total length.

Round-2 native measurement passes the unchanged gate at IoU 0.813414, median
band error 0.042171 and maximum band error 0.194316. The full proof contract and
observed suite results are in [blender/VALIDATION.md](blender/VALIDATION.md).

### Round-3 board facing and single tabard

`python3 -B -m spec.art_identity.maquettes.blender.round3_lancer` reproduces the
current 31-piece proposal from the two earlier recipes. No pose joint, segment
length, bone thickness, base registration input, camera or fit-gate value changes.

The approved body is native -Y forward. `blender/facing.py` converts its append
matrix and rest-joint registration to board +X for every v2 build; the spine's
posed bone basis explicitly retains anatomical +X. This corrects the asset/rig,
without changing the camera. Pose joints, limb-plate placements, spear and cloak paths remain world-space
design data. Front chest planes are registered vertically to the anatomy so the
breastplate spans collarbones to belt and the diamond clears the retained collar. Head/neck garments, visor, front breastplate and gem turn
with the anatomical frame. `board_spec` works on a copy, retaining original spec
provenance. Rendered joints, inspection and proof use the same conversion.

The facing gate projects the actual posed torso heading: front must point
screen down-left at the board's 2:1 slope; rear points up-right. Two native torso
mattes compare left/right area and reflected silhouette, including an actual
frontal object-rotation control that must fail the axis gate. These are proof
views, not extra character views. Body lean is removed only when measuring its
horizontal board heading; the anatomical 3D vector is also reported.

One hip-wide front cloth replaces the two old panels. Its flat pattern flares
from 0.30 to 0.40 world units, has three cuts beginning at mid-thigh, four ragged
strips, above-knee hem and four seeded fold-ease waves. The native cloth solver
runs 24 fixed frames; self-collision is disabled for this open panel, while body
collision remains enabled. The two short, two-lame hip tassets remain. Explicit
initial depth keeps the flat pattern outside the legs before simulation.

`cloth_contacts.py` isolates contact correction and loose-point cleanup. Native
convex shoulder/hip contacts prevent opposite-side snapping; the final clearance
and triangle-overlap gates still test the complete original posed anatomy.
Lame contact hulls bridge the underlying cloth. The gem now seats by one rigid
translation above all sampled contacts, preserving its bipyramid rather than
warping its vertices through the chest ridge. No other accessory dimensions change.

Round-3 final measure and fit pass unchanged gates: IoU 0.812207, median band
error 0.036732, maximum band error 0.124394. All production mesh hashes match
an independent fresh-cache build. Native integration/facing pass; the full
Python suite runs 585 tests with 62 skips. Exact observed lines and native
receipts are recorded in `blender/VALIDATION.md` and the delivery manifest.

### Proof and reproduction

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-03 && python3 spec/art_identity/maquettes/blender/bridge_client.py spec/art_identity/maquettes/blender/integration.py -- /private/tmp/labyrinth_codex/mq-03/round3/delivery/integration_final
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-03 && python3 spec/art_identity/maquettes/blender/bridge_client.py spec/art_identity/maquettes/blender/build.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-03/spec/art_identity/maquettes/frostglass_lancer/spec_r3.json /private/tmp/labyrinth_codex/mq-03/round3/delivery/lancer_r3 --gallery
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-03 && python3 tools/maquette_fit.py measure --spec spec/art_identity/maquettes/frostglass_lancer/spec_r3.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --renders /private/tmp/labyrinth_codex/mq-03/round3/delivery/lancer_r3 --out /private/tmp/labyrinth_codex/mq-03/round3/delivery/measure --require-gate
```

The director helper also prints/runs its complete bridge-based build/fit/proof
sequence: `python3 spec/art_identity/maquettes/blender/director.py --print-only`.
Native integration defaults to eight diagnostic captures; pass a second argument
`full` to also capture its complete synthetic solos/gallery. The final lancer
provides the complete 72-image ownership/clay/solo/gallery/torso-proof contract.
See `blender/VALIDATION.md` for observed results, receipts and actual paths.

### Chosen technical defaults and proposed design data

The original missing creature values have been replaced with reviewable
proposals, rather than defaults: native asset registration, bone registration
and thickness, attachment transforms, outlines, materials-as-labels, cloth
physics/patterns and weapon profiles are explicit in `spec_r3.json`, with source
measurements/recipe in `propose_lancer.py`. They remain subject to owner review.

Technical settings are named in `BUILD_DEFAULTS`, `BIND_DEFAULTS`,
`COLLISION_DEFAULTS`, `RENDER_DEFAULTS`, `BRIDGE_DEFAULTS`, `PROOF_DEFAULTS`, `INSPECTION_DEFAULTS`, `PROJECT_DEFAULTS`, `FACING_DEFAULTS`,
and synthetic `TEST_DEFAULTS`/fixtures. Hash precision is 9 decimals; clearance
and triangulation epsilon 1e-6; fit uses six passes and existing [0.6,1.6] scale
clamps; bridge poll interval 1 second and default job budget 900 seconds.
Contact correction uses 24 passes, ray epsilon 1e-5 and three fixed ray directions.
Proof uses 1024², Cycles CPU, fixed seed 0, eight render threads, grey 0.6,
roughness 0.8, AO distance 0.15, studio energy 600/size 5/location [4,-3,6].
Facing proof uses axis cosine ≥0.995 and reflected torso difference ≥0.01;
cache revision is 7. Synthetic fixture dimensions and eight-frame physics remain
test data only. See `blender/VALIDATION.md` for final observed results.

## Historical v1 / mq-02 contract (unchanged)

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
