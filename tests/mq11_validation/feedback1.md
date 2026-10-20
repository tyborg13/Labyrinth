# mq-11 feedback 1

All changes remain uncommitted. No bridge, Blender, Godot, windowed probe,
peer review, or full Python suite was run for this feedback fix.

## Files changed for this feedback

- `spec/art_identity/maquettes/hollow_mimic/owner_review/native_probe.py`:
  stdlib hashing and durable compact JSON writing replace the PIL-dependent
  curation import. Measurement imports load at module import time.
- `spec/art_identity/maquettes/hollow_mimic/owner_review/candidate.py`:
  stdlib recipe hashing and the existing compiler's project root replace the
  two host-side imports that indirectly required PIL. No gate value was edited
  by this implementation fix.
- `tests/test_mq11_accessories.py`: test-owned unresolved-data fixtures;
  isolated no-write/no-submission checks for either incomplete figure; filled
  candidate preservation; the requested 0.9 length expectations; fresh-process
  PIL blocking; and actual projected attachment-centred flap triangles in both
  views, with a 5 px displacement negative control.
- `tests/mq11_validation/feedback1*`: test logs and protected-input snapshots.

## Numbered feedback requirements

1. The native probe and its measurement import closure load with PIL blocked
   in a fresh host Python process. The test also enters `main` with a stub
   `bpy` module, stopping on an intentionally absent spec before any native
   operation; then it writes and hashes a receipt with only stdlib helpers.
   This verifies imports and receipt I/O, not a Blender execution.
2. Unresolved assertions now use their own data. The length assertion uses
   0.9 as requested. Each flap centred on its own belt attachment passes in
   both views; a front flap shifted exactly 5 projected pixels fails in both.
   The director's attachment-centre measurement implementation is untouched.
3. Only focused Python tests were run. No bridge submission occurred.

## Observed focused results

The first accessories-only run (`feedback1_accessories.log`) exposed an older
fixed-output-directory assumption; the test was isolated afterward:

```text
Ran 25 tests in 0.979s
FAILED (failures=1)
```

The focused set uses the command recorded in this directory's `README.md`,
with output in `feedback1_focused.log`:

```text
Ran 142 tests in 40.895s
FAILED (failures=3, skipped=2)
```

The two skips are opt-in native bridge tests. All three failures are the
requested 0.9 assertions observing 1.25: two filled-candidate subtests and the
front length test. During verification, the gate and Mortar design file were
changed externally. They were preserved; the asynchronous clarification asks
which fraction is authoritative. Initial and current hashes are recorded in
`feedback1_protected_inputs.json` and `feedback1_protected_check.json`.

The seven focused import, attachment-line, unresolved-fixture, no-submission,
and preservation regressions were isolated in `feedback1_regressions.log`:

```text
Ran 7 tests in 0.452s
OK
```

## TODO_DESIGN placeholders

No live design placeholders were introduced. Intentional unresolved strings
exist only in test fixtures. Both filled design JSON files were read only by
this implementation work; concurrent director edits were not overwritten.

## Chosen defaults

Only synthetic test values were added under `FIXTURE`:

- `attachment_camera`: orthographic scale 2.4, target `[0, 0, 1]`.
- `attachment_joints`: hips `[0, ±0.25, 1]`, pelvis `[0, 0, 1]`.
- `attachment_flap_size_m`: width 0.08, length 0.35.
- `attachment_shift_px`: 5, the requested failure control.
- `probe_import_timeout_s`: 30 seconds.

## Proof for the design owner / open issue

The native build remains the director's responsibility. Use the documented
`workflow build` command with a fresh run id after resolving the fraction
conflict; the existing `director_01` output is not overwritten. This revision
claims no new native capture or after-IoU. No windowed Godot or inspection
fixture command applies to this offline maquette unit.
