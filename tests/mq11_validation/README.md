# mq-11 observed verification

Current director-feedback-2 results are in [feedback2.md](feedback2.md): all
162 focused tests pass (two opt-in bridge skips), all 111 art-identity tests
pass, and all four surviving guard mutations are caught. The pending-design
notes below are historical initial-implementation evidence.

Implementation and native-proof commands are documented in
[`owner_review/README.md`](../../spec/art_identity/maquettes/hollow_mimic/owner_review/README.md).
All changes are uncommitted. No Blender job or windowed capture was run.

## Final focused checks

Command (from the mq-11 worktree):

```sh
python3 -B -m unittest tests.test_mq11_accessories spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation tests.test_maquette_blender tests.test_mq09_maquettes tests.test_mq09_forms tests.test_maquette_rear_turn tests.test_rr20_cutout.HollowMimicTests.test_approved_inputs_and_prior_figures_are_byte_identical tests.test_rr20_cutout.HollowMimicTests.test_director_residue_cleanup_preserves_sources_and_resolves_placeholder -v
```

Observed in `focused_final.log`:

```text
Ran 138 tests in 42.129s
OK (skipped=2)
```

The skips are the two opt-in Blender bridge tests. The new unit has 21 portable
tests, including negative controls for unauthorized old-inventory changes.

## Art identity

`python3 -B tests/test_art_identity_gate.py`, observed in `art_identity.log`:

```text
Ran 111 tests in 67.039s
OK
```

## Full Python discovery

```sh
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
```

The first completed sweep, `python_full.log`, observed:

```text
Ran 1490 tests in 1614.306s
FAILED (failures=11, skipped=64)
```

Nine failures are existing Seer identity-pin subtests. All nine failed files
were compared byte-for-byte with integration commit
`ee03daf93cf6625085a8021da3e08064e6c74216`; they are unchanged. See
`rr14_baseline.json`. The assertions and Seer files were not modified.

The remaining two failures were introduced by the required mq-11 additions to
the live Mimic inventory. The bounded historical receipt adapter resolves
them, while preserving all old lines and paint pins. Both old tests and its
negative controls pass in `focused_final.log`. Earlier attempts are retained
in `rr20_repro.log`, `rr20_fixed.log` and `focused_pin_error.log`.

Final discovery against the final implementation is recorded separately in
`python_full_final.log`:

```text
Ran 1492 tests in 1481.696s
FAILED (failures=9, skipped=64)
```

All nine failures are the same pre-existing Seer pin mismatches. The two
rr-20 inventory checks and all mq-11 tests pass in this final sweep. The Seer
failure is independently reproduced in `rr14_repro.log`:

```text
Ran 1 test in 0.091s
FAILED (failures=9)
```

## Compiler and preservation probes

`workflow status` is recorded in `status.json`: all 989 protected files pass,
all other figure deliveries are byte-identical, after-IoUs are unset, and
native acceptance is explicitly pending. Seven named design fields remain.

`workflow prepare --run-id unresolved_check` returned exit 2 with
`MQ11_WORKFLOW_ERROR: Unresolved design` (`prepare.log`). This is the expected
rejection; the unit test verifies that no output or bridge submission occurs.

The existing full suite refreshes the tracked Briar sample-input receipt.
`briar_test_side_effect.json` records the generated and initial hashes. Only
that test-generated receipt is restored, after verifying its body is unchanged.

No native after-IoU, rear hair extent, fringe visibility, flap centre-line
measurement, joint-marked sheet or head comparison has been produced. Those
require complete owner data and the director bridge.

Final Python AST syntax check: `MQ11_PYTHON_SYNTAX: PASS; files=11`.
Final byte check: `MQ11_PRESERVATION: PASS; files=989;
other_figure_deliveries_byte_identical=true; native_acceptance=pending`.

The suite also left an empty local `output/rr-05` directory. The required
output helper's local marker and that empty test-created directory were
removed together; no output data was deleted. The final output-marker check
is recorded in `output_gdignore_check.log`.

## Changed files

- `spec/art_identity/maquettes/blender/accessory_geometry/{__init__,forms}.py`.
- `spec/art_identity/maquettes/hollow_mimic/owner_review/`: `__init__.py`,
  `candidate.py`, `measurements.py`, `native_probe.py`, `preservation.py`,
  `proof.py`, `workflow.py`, `README.md`, `baseline.json`, and `design.json`.
- `spec/art_identity/maquettes/slag_mortar/owner_review/design.json` and both
  figures' `COMMIT_MANIFEST.txt` inventories.
- `tests/test_mq11_accessories.py`, `tests/mq11_preservation.py`, and three
  additive lines in `tests/test_rr20_cutout.py` (import and two decorators).
- `tests/mq11_proof/.gdignore` and `tests/mq11_validation/`'s local proof logs,
  receipts, `.gdignore` and this report.

No original recipe, painting, delivery, runtime script, scene, registry,
assertion, Git commit or branch was changed.
