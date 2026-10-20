# mq-11 feedback 2 — implementation and focused verification

All requested validation fixes are implemented, with uncommitted changes.
No bridge, Blender run, Godot run, windowed capture, peer review, or full
Python suite was run for this feedback. Director proof directories are untouched.

## Files changed

- `spec/art_identity/maquettes/blender/accessory_geometry/forms.py`:
  three-dimensional skull-axis/scalp contact and relative tuft-bound tolerance.
- `spec/art_identity/maquettes/hollow_mimic/owner_review/measurements.py`:
  meaningful lower-mask retention, visible crack centres, relative rear-height
  tolerance, and contiguous flap-row support.
- `owner_review/native_probe.py`: exports exact frozen native triangles in
  `capture/mq11_meshes.json`, using stdlib I/O only.
- `owner_review/preservation.py`: recursively discovers repository Python
  import dependencies without executing native modules.
- `owner_review/workflow.py`: takes one pre-compile input snapshot, checks it
  during building, binds acceptance to it, and verifies without rewriting fit.
- `owner_review/proof.py`: binds the mesh export to native artifacts and
  recomputes shape metrics before accepting cached results.
- `owner_review/README.md`: current protected data, validation and replay contract.
- `tests/test_mq11_accessories.py`: supported-size centre-line fixture,
  isolated input fixture and current director-value test names.
- `tests/test_mq11_validation.py`, `tests/test_mq11_freshness.py`,
  `tests/test_mq11_guard_mutations.py`: new behavioral and mutation regressions.
- This directory's `feedback2*` logs, protected-input receipts and summary.

All abbreviated `owner_review/` paths above are beneath
`spec/art_identity/maquettes/hollow_mimic/`.

## Numbered feedback requirements

1. **Fresh acceptance:** seed every native builder/owner-workflow script and
   follow local absolute, relative, conditional and literal dynamic imports,
   including package initializers. The current bound set has 157 inputs,
   including raster, geometry, fitting, batch proof and rear-turn observations.
   Preparation snapshots before either compile; changed inputs prevent
   acceptance. Receipt inputs are that original snapshot. Verification checks
   current inputs and recomputes shape metrics from the exact native triangle
   export, bound to its spec/build/blend and recorded export hash. Cached
   passing numbers cannot replace recomputation.
2. **Detached scalp:** validate the skull crown/base axis inside the ellipsoid's
   lateral extent in three dimensions, retaining crown/ear-height coverage.
   The cap need not contain the chin below its vertical extent. Moving the
   entire scalp and all roots 10 m along the skull lateral axis is rejected;
   both untouched director candidates still compile.
3. **Mask occlusion:** select the mask's lower 80% band by projected rows and
   require at least 60% of its mask pixels to remain depth-visible. In each
   occupied middle-third row, the median occupied mask column must remain
   visible, protecting the projected crack centre. Tests reject near-total
   coverage and a hidden crack centre despite ample visible lower-mask area.
4. **Inclusive numerical boundaries:** tuft bounds and the rear-height maximum
   allow relative error 1e-9. Tests accept boundary roundoff and reject values
   beyond the epsilon. The approved thresholds are unchanged.
5. **Flap measurement quality:** at least 12 central rows, with no missing row
   between them, are required before taking the existing median. Otherwise
   fail with `insufficient flap rows`. Tests cover the inclusive support
   boundary, too few rows, gaps and the cancelling two-row outlier case.
6. **Surviving mutations:** all four are applied in memory and each causes a
   focused behavioral test assertion to fail, with zero fixture errors:

```text
MQ11_MUTATION_CAUGHT: flap_row_ordering; errors=0
MQ11_MUTATION_CAUGHT: unowned_accessory_preservation; errors=0
MQ11_MUTATION_CAUGHT: acceptance_freshness; errors=0
MQ11_MUTATION_CAUGHT: shape_report_spec_binding; errors=0
```

## Exact final test commands and results

```sh
python3 -B -m unittest tests.test_mq11_accessories tests.test_mq11_validation tests.test_mq11_freshness tests.test_mq11_guard_mutations spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation tests.test_maquette_blender tests.test_mq09_maquettes tests.test_mq09_forms tests.test_maquette_rear_turn tests.test_rr20_cutout.HollowMimicTests.test_approved_inputs_and_prior_figures_are_byte_identical tests.test_rr20_cutout.HollowMimicTests.test_director_residue_cleanup_preserves_sources_and_resolves_placeholder -v
```

Observed in `feedback2_focused_final.log`:

```text
Ran 162 tests in 39.634s
OK (skipped=2)
```

The skips are opt-in bridge tests. Earlier attempts exposed test-fixture
issues and nine historical inventory failures from adding/changing a direct
builder module. Dependency discovery now lives inside mq-11's existing
preservation module; no historical assertion or delivery inventory changed.
The final focused run includes those inventory checks and passes.

```sh
python3 -B tests/test_art_identity_gate.py
```

Observed in `feedback2_art_identity_final.log`:

```text
Ran 111 tests in 35.740s
OK
```

`git diff --check` returned exit 0. The protected-input check recorded:

```text
MQ11_DIRECTOR_INPUTS: PASS; design_files_byte_identical=2; candidate_gates_byte_identical=true; median_defaults_unchanged=true
MQ11_PRESERVATION: PASS; files=989; other_figure_deliveries_byte_identical=true
MQ11_DEPENDENCY_INPUTS: files=157
```

The full candidate source is byte-identical to feedback-start, preserving all
GATES values, including 1.25 and 12. `MEASURE_DEFAULTS` is unchanged, including
the central fraction .6. Hashes are in `feedback2_protected_inputs.json` and
`feedback2_protected_check.json`.

## TODO_DESIGN placeholders

None introduced. Intentional unresolved strings remain test fixtures only.

## Chosen defaults

Only synthetic test parameters were chosen. Existing `FIXTURE` now supplies
a 32-row test canvas, occupied box `(4, 28, 4, 12)` and vertical reference at
x=8. `VALIDATION_FIXTURE` supplies mask size 100, passing rear ratio .4,
roundoff fraction .5, outside-epsilon factor 2, flap width 8 px, support case
20 rows and gap row 10. Its 10 m detachment and 100 px outliers reproduce the
review examples. `FRESHNESS_FIXTURE` supplies synthetic before/after hashes,
blend bytes, mesh hash and local run id `mq11-freshness-fixture`.

The 60% retention, middle-third crack band, 12-row requirement and relative
epsilon are director instructions, not chosen design defaults. No player
dimension, visible tuning, artwork or runtime behavior was changed.

## Proof for the design owner / open issues

Run from the mq-11 worktree, through the existing director bridge with a fresh
run id; these commands were not executed here:

```sh
python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow build --run-id feedback2_01
python3 -B -m spec.art_identity.maquettes.hollow_mimic.owner_review.workflow verify --run-id feedback2_01
```

New native captures and sheets will be under
`tests/mq11_proof/feedback2_01/{hollow_mimic,slag_mortar}/{capture,review}/`.
`capture/mq11_meshes.json` is newly required; older proof runs must be rebuilt.
No new native after-IoU or visual proof is claimed. Windowed Godot probes and
`tools/inspection_fixture.py` do not apply to this offline maquette unit.
Native proof remains pending the director; no headless implementation issue
is left open.
