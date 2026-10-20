# mq-11 feedback 3 — actual crack visibility

The validation and regressions are implemented. Native measurement remains
blocked on one missing director measurement: the registered crack's stroke
width. No production width was chosen. All changes remain uncommitted; no
bridge, Blender, Godot, windowed capture, peer review or full suite was run.

## Files changed

- `spec/art_identity/maquettes/hollow_mimic/owner_review/measurements.py`:
  loads the registered `violet_crack.source_path_px`, rasterizes its full
  stroke at native front-view resolution with NumPy, and depth-tests its
  actual pixels against hair and mask. Requires 85% retained crack pixels.
  A stroke pixel outside the mask is not visible. The existing report check
  name `crack_band_remains_visible` is retained for callers; it now measures
  the actual crack. Total/visible counts and visible fraction are reported.
- `tests/test_mq11_crack_visibility.py`: registered-path triangle regressions,
  exactly 98%-hidden synthetic case, inclusive 85% boundary, depth ordering,
  source scaling, stroke width, and invalid/unresolved registration cases.
- `tests/test_mq11_validation.py`: supplies test-owned registered crack data
  for the isolated mask tests. Midpoint occlusion away from the crack now
  correctly passes; the lower-mask band tests are unchanged.
- `tests/test_mq11_accessories.py`: test-owned crack data for the isolated
  fringe-occlusion test. It never substitutes a production width.
- `owner_review/README.md`, this directory's README, this report, logs and
  protected-input receipts document the current contract and data gap.

## Requested requirement and regressions

The check uses pixel-centre distance to each registered stroke segment and
its endpoints, with the supplied width scaled from the existing 256 source
registration to the 1024 front view. It counts visible pixels where the mask
surface is nearer than the hair, or where hair is absent. The cutoff is
exactly 85%, inclusive. No mask-midpoint sample substitutes for the path.

The real-registration tests use the current compiled mask outline and real
3D triangle projection/depth sampling, with synthetic hair and a **fixture-only
2-source-pixel stroke width**. They do not claim a production/native capture:

```text
MQ11_CRACK_TRIANGLE_FIXTURE: top_band_only; pixels=820; visible=730; passed=true
MQ11_CRACK_TRIANGLE_FIXTURE: hidden_over_98_percent; pixels=820; visible=16; passed=false; mask_midpoints_clear=true
```

The negative case hides 804/820 pixels (98.05%) while rear height, fringe
overlap, lower-mask retention and all old middle-third midpoint samples pass.
The separate synthetic registration hides exactly 98/100 pixels. The positive
case covers only the mask's top band and retains 89.02% of the registered crack.

## Exact focused commands and observed results

```sh
python3 -B -m unittest tests.test_mq11_crack_visibility tests.test_mq11_accessories tests.test_mq11_validation tests.test_mq11_freshness tests.test_mq11_guard_mutations spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation tests.test_maquette_blender tests.test_mq09_maquettes tests.test_mq09_forms tests.test_maquette_rear_turn tests.test_rr20_cutout.HollowMimicTests.test_approved_inputs_and_prior_figures_are_byte_identical tests.test_rr20_cutout.HollowMimicTests.test_director_residue_cleanup_preserves_sources_and_resolves_placeholder -v
```

`feedback3_focused.log`:

```text
Ran 171 tests in 39.961s
OK (skipped=2)
```

The two skips are opt-in bridge tests. The existing four in-memory guard
mutation regressions also pass in that run.

```sh
python3 -B tests/test_art_identity_gate.py
```

`feedback3_art_identity.log`:

```text
Ran 111 tests in 35.512s
OK
```

`git diff --check` returned exit 0. The protected-input probe observed:

```text
MQ11_FEEDBACK3_PRESERVATION: PASS; files=989; protected_data_gates_median_lower_band_unchanged=true
MQ11_FEEDBACK3_PENDING_WIDTH: TODO_DESIGN_VIOLET_CRACK_STROKE_WIDTH_SOURCE_PX
```

Both director design files, the entire candidate/GATES source and protected
base recipe are byte-identical to feedback-start. The median function and
lower-band assignments are byte-identical to HEAD. Existing measurement
defaults and validation limits are unchanged; only the instructed .85 limit
is added. Receipts: `feedback3_protected_inputs.json` and
`feedback3_protected_check.json`.

## TODO_DESIGN / open issue

`measurements.py:CRACK_STROKE_WIDTH_SOURCE_PX` contains
`TODO_DESIGN_VIOLET_CRACK_STROKE_WIDTH_SOURCE_PX`. The protected registered
feature defines its path but has no stroke-width field. Its measured width
in source-image pixels must come from the director. The loader also accepts
a director-supplied `stroke_width_px` on the registered feature if provided.
This implementation does not edit that protected recipe or its checksum pins.

The current native measurement deliberately stops with the named unresolved
design error. Passing fixture tests do not resolve this production data gap.
An asynchronous clarification requesting the width and its data location
remains pending.

## Chosen defaults

Only test data were chosen. `CRACK_FIXTURE` names a 100-pixel canvas and source,
a synthetic 100-pixel L-shaped registration, 1-pixel test stroke, 3-pixel wide
stroke control, source scale factor 2, depth layers 1/0/-1, and a .01 m occluder
offset. Its registered-path triangle case uses the explicit fixture width
2 source pixels. `VALIDATION_FIXTURE` owns a separate off-centre path and
1-pixel stroke for isolated lower-mask tests; `FIXTURE.test_crack` supplies
registration data for the existing fringe test. None is production artwork
or a fallback for the director's missing width. The 85% gate is instructed.

## Proof for the design owner

After supplying the stroke width, use a fresh run id through the existing
director bridge. These commands were not executed here:

```sh
python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow build --run-id feedback3_01
python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow verify --run-id feedback3_01
```

Future native captures/review sheets will be under
`tests/mq11_proof/feedback3_01/{hollow_mimic,slag_mortar}/{capture,review}/`.
No new native capture or after-IoU is claimed. Existing `director_04` and
`director_05` outputs are untouched. No windowed Godot or inspection-fixture
command applies to this offline validation fix.
