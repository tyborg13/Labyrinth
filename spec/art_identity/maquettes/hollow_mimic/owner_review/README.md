# mq-11 implementation handoff — director feedback 3

Both `design.json` files are filled director data and remain protected. The
director's front thigh fraction 1.25, centre tolerance 12 px and median of the
central 60% of flap rows are unchanged. No test fixture is used as player art.
Fresh native proof remains the director's responsibility; this feedback fix
runs focused Python checks only, with no bridge submission or full-suite run.

The registered `violet_crack.source_path_px` has no stroke width in the recipe; the director set
`measurements.py:CRACK_STROKE_WIDTH_SOURCE_PX = 2` (the painted crack is about 2 px wide at the 255 px source).
Explicit fixture widths are test data only.

The implementation is opt-in: `candidate.py` compiles the protected current
recipe, replaces only `hair_crown` or the two apron accessories, and validates
that every other piece, body setting, mask, joint, label, source binding and
pose remains identical. It does not stage production deliveries. The original
recipes, reference images and all existing delivery bytes are protected by
the immutable [baseline](baseline.json).

## Numbered requirements

1. **Mimic hair:** native scalp-plus-swept-tuft construction is wired to the
   existing editable voxel-union builder. Owner-filled paths must have 16
   distinct roots, varied 0.3–0.9 head-height lengths, four forward/down fringe
   tufts, up/up-back/both-side/down-back directions, and attached roots. Scalp
   width is 1.25 times the owner's skull width; its volume must reach the crown
   and ear line. The mask, crack source, body, limbs, joints and labels are
   preserved. Actual rear height and front fringe depth overlap are measured
   from frozen native triangles. Three-dimensional containment of the skull
   axis within the scalp's lateral extent rejects a detached cap without
   extending the cap down to the chin. The lower 80% mask band must retain at
   least 60% visible mask pixels. The actual registered crack polyline, at its
   stroke width, is rasterized into the front view and depth-tested against
   the hair; at least 85% of its pixels must remain visible. Mask midpoints do
   not substitute for crack pixels. Inclusive tuft and rear-height
   limits allow relative numerical error of 1e-9.
2. **Mortar loincloth:** one closed belt and two curved cloth flaps are drafted
   in the posed hip frame, with the original `apron` ownership, thickness,
   stiffness, native collision solve and `rag` style. The front root tangent
   is perpendicular to body forward, spans half the measured outer hip width,
   and hangs from the belt front centre. Its nominal thigh fraction is 1.25;
   the rear uses the same frame and an owner-specified shorter ratio. The old
   world-X gathering and fixed-plane rest correction are removed only from
   these candidates. Both cameras see the same mesh and pose.
3. **Gates/proof:** the director command runs native build/capture, cold/cache/
   independent replay, unrounded exact mesh/joint replay, ownership mutation,
   facing/collision/solo validation, before/after IoU, the existing mq-06 pixel
   turn check, unchanged native body/accessory hashes, and the new shape gates.
   Every other figure's delivery stays byte-identical. Native after values
   and visual approval remain pending; portable tests are not native proof.

| Figure | Front before | Rear before | After |
|---|---:|---:|---|
| Hollow Mimic | 0.815673909922 | 0.770515330525 | Pending director capture |
| Slag Mortar | 0.799598979220 | 0.772701972148 | Pending director capture |

The centre-line reference is the vertical through each flap's belt attachment:
pelvis-frame origin ± forward × belt forward radius. At 1024, the median error
of the central 60% of occupied rows must remain within ±12 px. This statistic
requires at least 12 central rows with no gaps; otherwise measurement fails
with `insufficient flap rows`. End-row maximum errors are still reported.

## Protected owner data contract

Both candidate `design` fields and `base_recipe_sha256` pins are immutable for
implementation work. Coordinates are metres in the existing posed native
body space, X forward / Y lateral / Z up, before the front/rear camera turn.
No generated art, audio, fonts or new dependencies are involved.

In [the Mimic candidate](design.json):

- `skull` contains `crown_m`, `base_m`,
  `ear_line_m` (3D points), `height_m`, `width_m`, and a unit `lateral_axis`
  perpendicular to crown-minus-base. Height must equal crown-to-base distance.
- `scalp` contains `centre_m` and
  `radii_m` (three positive native ellipsoid radii). The existing organic
  relief, subdivision and voxel-union settings are inherited unchanged.
- `tufts` contains 16 objects with
  distinct `id`, `role` (`mop` or `fringe`; four fringe), `path_m` (at least two
  3D controls), and corresponding positive `radii_m`, tapering toward each tip.
  All roots must lie within the scalp. Arc length, rather than root-to-tip
  chord, is checked against the brief. Layout and thickness are owner data.

In [the Mortar candidate](../../slag_mortar/owner_review/design.json):

- `belt` contains `forward_radius_m`,
  `lateral_radius_m`, `height_m` and anatomical **outer** `hip_width_m`. Belt
  centre and orientation come from the two posed hips. Thickness is inherited
  from the existing leather flap. Hip-joint spacing is not substituted for
  the measured outer hip width.
- `front.rows` and `rear.rows` each contain at least two
  objects containing `drop_fraction` (monotonically 0 to 1), `width_fraction`
  (0–1, positive), `forward_offset_m`, and `curve_m`. These define the nominal
  hem taper and the bow over the thighs. The root row has width fraction 1,
  zero forward offset and zero curve; the free rows retain the native solver.
  Front and rear depths follow their respective outward-facing body axes.
- `rear.front_length_ratio` is the director's 0.8, strictly between 0 and 1.

Both protected design files are complete. The crack stroke-width measurement
above is unresolved; other unresolved-data tests own their fixtures.

## Acceptance freshness and shape replay

`workflow.inputs()` follows repository Python imports, including relative and
conditional imports and package initializers. It seeds the complete native
builder family and owner workflow scripts, covering separately executed jobs
and dynamic builder dispatch without importing Blender modules on the host.
The closure includes `raster.py`, `geometry.py`, fitting, batch proof and the
rear-turn observations. Recipe, design, baseline and Lancer rig-template JSON
inputs are bound too.

Preparation takes one input snapshot before compiling either figure. Building
checks that same snapshot before each figure and before accepting its output;
acceptance never refreshes it. Verification compares the receipt, preparation
snapshot and current dependency hashes, then checks the bound artifacts and
replays shape measurements without rewriting their fit report.

The native probe writes `capture/mq11_meshes.json` with the exact frozen native
accessory vertices and faces, bound to the spec, build report and blend. Its
hash is recorded in `mq11_shape.json`. Host inspection recomputes every shape
metric from those triangles and rejects stale spec bindings or cached numbers.
Both native imports and export I/O remain stdlib/NumPy only; image curation
stays on the host. Older proof runs lacking this export require a fresh build.

Crack coverage uses pixel-centred distances to registered stroke segments,
including their full width and endpoints, scaled from the existing 256-pixel
source registration to the 1024 front view. Pixels not on the mask count as
not visible. The existing `crack_band_remains_visible` report key is preserved
but now represents the 85% actual-crack rule. Reports include total and visible
crack-pixel counts and their fraction. The lower-mask band rule is unchanged.

## Proof for the design owner

After supplying the stroke width, run the complete native pipeline **through the director bridge** with a fresh
run id. These commands do not launch Blender
directly, modify production deliveries, or perform Git actions.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-11 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow status
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-11 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow build --run-id owner_01
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-11 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow verify --run-id owner_01
```

`build` compiles **both** complete designs before creating proof output or
submitting any job. Unresolved data fails with `MQ11_WORKFLOW_ERROR` and no
bridge submission. `prepare` is a headless compiler-only check; it consumes a
run id, so use a different id for a subsequent `build`.

Outputs are under `tests/mq11_proof/owner_01/{hollow_mimic,slag_mortar}/`:

- `review/front_old_new_parts.png` and `review/rear_old_new_parts.png`: old
  clay | new clay | new part map, each native cell 1024² at 1:1, with joints
  marked on every cell; the complete sheet is 3072×1052 including its header.
- Mimic `review/mimic_hero_original_heads.png`: new Mimic head, the named hero
  reference and original Mimic head, normalized by skull height using nearest
  resampling. Reference crop bounds are proof-only fields in `PROOF_DEFAULTS`.
- `review/proof_contract.json`: exact sizes, source/capture/joint hashes and
  output hashes. `capture/mq11_fit.json` contains IoU and turn/pose/coverage;
  `capture/mq11_shape.json` contains native height/overlap/centre-line values.
- `acceptance.json`: current inputs and artifact bindings, only emitted after
  all gates and native delivery validation pass. It is rechecked by `verify`.

No windowed Godot probe, 1920×1080 UI capture, playable fixture, or
`tools/inspection_fixture.py` command applies: this unit is offline 1024²
Blender maquette authoring and changes no runtime scenes or player flow.
No native capture was attempted in the implementation sandbox. The director
owns the bridge run, inspection, staging, commit, review and publication.

## Chosen defaults

Only non-player-visible implementation/proof values were chosen:

- `GEOMETRY_DEFAULTS`: numerical epsilon 1e-9 m; 32 belt tessellation samples.
- `MEASURE_DEFAULTS`: epsilon 1e-9 and the director's central row fraction .6.
  The 12-row minimum and mask visibility requirements come from feedback 2.
- `WORKFLOW_DEFAULTS`: 900-second native job budget inherited from the existing
  workflow; default local proof run id `owner_01`.
- `PROOF_DEFAULTS`: existing 28 px header and 24/24/24 background, white marks,
  3 px joint circles, 4 px caption offset, 256 px comparison skull height;
  hero crop [92,7,164,73] / proof skull height 40 px, original Mimic crop
  [92,37,162,103] / proof skull height 44 px. Existing Pillow default font.
- `FIXTURE` in `tests/test_mq11_accessories.py`: synthetic dimensions, paths,
  camera test rectangles, masks, depths and rotation; never candidate data.
- `VALIDATION_FIXTURE` and `FRESHNESS_FIXTURE` in the new focused tests contain
  only synthetic geometry, roundoff cases and receipt metadata. No visible
  dimension, gate value or design field is chosen by these tests.

No gameplay tuning, balance, icon identities, analytics, saves or runtime
inputs change. Exact observed checks and logs are in `tests/mq11_validation/`.

## Historical receipt compatibility

The live curated manifests include these new authoring files. rr-20's older
protected-input receipt also pins the original Mimic manifest, so its two
existing tests run inside `tests/mq11_preservation.py`'s inventory context.
Only the exact named mq-11 additions and their comment are removed before
checking that old receipt. Every inherited manifest byte, source/paint pin and
original assertion remains checked. Negative controls reject altered or
removed original lines and any unapproved addition. The new files themselves
remain subject to the live curated inventory and byte-budget checks. This
does not certify a new renderer capture or change rr-20 production inputs.
