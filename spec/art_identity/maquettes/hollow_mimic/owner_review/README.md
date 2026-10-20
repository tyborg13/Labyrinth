# mq-11 implementation handoff — design data pending

The requested appearance corrections are **not delivered**. The brief supplies
shape constraints but no replacement scalp profile, individual tuft paths and
thicknesses, belt dimensions, curved flap rows, or shorter rear-flap ratio.
Under the explicit implementation-only rule, these are `TODO_DESIGN_…` data
fields rather than invented visible dimensions. No placeholder geometry or
synthetic test fixture is used as player art.

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
   from frozen native triangles. Pending the three Mimic design fields below.
2. **Mortar loincloth:** one closed belt and two curved cloth flaps are drafted
   in the posed hip frame, with the original `apron` ownership, thickness,
   stiffness, native collision solve and `rag` style. The front root tangent
   is perpendicular to body forward, spans half the measured outer hip width,
   and hangs from the belt front centre. Its nominal hem reaches mid-thigh;
   the rear uses the same frame and an owner-specified shorter ratio. The old
   world-X gathering and fixed-plane rest correction are removed only from
   these candidates. Both cameras see the same mesh and pose. Pending the four
   Mortar design fields below.
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

The centre-line probe uses the projected vertical through the existing
`pelvis` joint and checks **every occupied scanline of each unoccluded flap**
in both views at 1024. It does not offset the reference line to hide body-front
or body-rear displacement. If the physical front/rear attachment cannot satisfy
the stated ±4 px gate, the director must resolve that conflict; the probe
retains the literal gate and reports the measured errors.

## Owner data contract / TODO_DESIGN

Edit only the candidate `design` fields; the `base_recipe_sha256` pins are
intentionally immutable. Coordinates are metres in the existing posed native
body space, X forward / Y lateral / Z up, before the front/rear camera turn.
No generated art, audio, fonts or new dependencies are involved.

In [the Mimic candidate](design.json):

- `TODO_DESIGN_MIMIC_SKULL_LANDMARKS`: replace `skull` with `crown_m`, `base_m`,
  `ear_line_m` (3D points), `height_m`, `width_m`, and a unit `lateral_axis`
  perpendicular to crown-minus-base. Height must equal crown-to-base distance.
- `TODO_DESIGN_MIMIC_SCALP_PROFILE`: replace `scalp` with `centre_m` and
  `radii_m` (three positive native ellipsoid radii). The existing organic
  relief, subdivision and voxel-union settings are inherited unchanged.
- `TODO_DESIGN_MIMIC_TUFT_LAYOUT`: replace `tufts` with 16 objects containing
  distinct `id`, `role` (`mop` or `fringe`; four fringe), `path_m` (at least two
  3D controls), and corresponding positive `radii_m`, tapering toward each tip.
  All roots must lie within the scalp. Arc length, rather than root-to-tip
  chord, is checked against the brief. Layout and thickness are owner data.

In [the Mortar candidate](../../slag_mortar/owner_review/design.json):

- `TODO_DESIGN_MORTAR_BELT_PROFILE`: replace `belt` with `forward_radius_m`,
  `lateral_radius_m`, `height_m` and anatomical **outer** `hip_width_m`. Belt
  centre and orientation come from the two posed hips. Thickness is inherited
  from the existing leather flap. Hip-joint spacing is not substituted for
  the measured outer hip width.
- `TODO_DESIGN_MORTAR_FRONT_FLAP_CURVE` and
  `TODO_DESIGN_MORTAR_REAR_FLAP_CURVE`: replace each `rows` with at least two
  objects containing `drop_fraction` (monotonically 0 to 1), `width_fraction`
  (0–1, positive), `forward_offset_m`, and `curve_m`. These define the nominal
  hem taper and the bow over the thighs. The root row has width fraction 1,
  zero forward offset and zero curve; the free rows retain the native solver.
  Front and rear depths follow their respective outward-facing body axes.
- `TODO_DESIGN_MORTAR_REAR_LENGTH_RATIO`: replace `rear.front_length_ratio`
  with the owner's ratio strictly between 0 and 1. No arbitrary interpretation
  of “slightly shorter” is supplied.

## Proof for the design owner

After filling those fields, run the complete native pipeline **through the
director bridge** with a fresh run id. These commands do not launch Blender
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
- `MEASURE_DEFAULTS`: epsilon 1e-9 and existing `pelvis` joint as centre-line
  reference. Scanline pixel centres and native triangle depths are measured.
- `WORKFLOW_DEFAULTS`: 900-second native job budget inherited from the existing
  workflow; default local proof run id `owner_01`.
- `PROOF_DEFAULTS`: existing 28 px header and 24/24/24 background, white marks,
  3 px joint circles, 4 px caption offset, 256 px comparison skull height;
  hero crop [92,7,164,73] / proof skull height 40 px, original Mimic crop
  [92,37,162,103] / proof skull height 44 px. Existing Pillow default font.
- `FIXTURE` in `tests/test_mq11_accessories.py`: synthetic dimensions, paths,
  camera test rectangles, masks, depths and rotation; never candidate data.

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
