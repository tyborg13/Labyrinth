# Feedback 3 verification

Gate-only changes; no windowed command attempted. No rig, mesh, director data,
source paint, approved idle or production registration was changed. Changes
remain uncommitted on `codex/rr-10` at `5abe9b561`.

## Focused headless suite and mutations

```sh
python3 -m unittest discover -s tests -p 'test_rr10_*.py' -v
```

Observed final focused run (exit 0), log
`/private/tmp/rr10-feedback3-focused.log`:

```text
Ran 35 tests in 43.152s
OK
```

The 3 px native far-elbow mutation is rejected (9 missing pixels), its intact
native sleeve passes, and all five hash-bound feedback-1 captures still fail
the stray gate. Existing 2 px tuck, split robe, idle rotation, staff angle,
planted hem, signed motion, source ownership, cloth fill, feature and rigid
native agreement regressions remain exercised.

After the final test-fixture constant extraction:

```sh
python3 -m unittest discover -s tests -p 'test_rr10_silhouette_gates.py' -v
```

Log `/private/tmp/rr10-feedback3-thresholds.log`, exit 0:

```text
Ran 5 tests in 0.015s
OK
```

The one-frame sheet success printed by the focused suite is a synthetic
composer regression fixture with a mocked native gate; it is **not** an
acceptance claim for the current 467-frame Seer capture.

## Bone/cut gates

```sh
python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py
```

Observed exit 0:

```text
RR10 FRONT BONE/CUT GATES: PASS (0 errors)
```

## Full Godot suite

```sh
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

Log `/private/tmp/rr10-feedback3-godot-full.log`, exit 0:

```text
TEST REGISTRATION AUDIT: PASS (742 scripts; full suite=398, quarantined=29, windowed probe=315)
MAIN BODY ASSERTIONS: 378792
FULL SUITE RUNTIME: 399.000 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The log also contains the deliberate selection-save-failure fixture and the
engine's exit-time ObjectDB warning. No assertion was changed to accommodate
existing failures.

## Full Python suite

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Log `/private/tmp/rr10-feedback3-python-full.log`, exit 0:

```text
Ran 874 tests in 810.957s
OK (skipped=63)
```

The verbose log records each optional-dependency skip and its reason. All five
new calibration tests passed in this full run, including the native far-elbow
gap mutation. No existing assertion was weakened.

## Existing native diagnostic

All 467 director-captured frames were checked against the calibrated code;
none was recaptured, rebound or accepted as fresh. Diagnostic output:

```text
RR10 EXISTING NATIVE DIAGNOSTIC: {'stale native proof inputs': 1, 'stale headless pose reference; rerun samples.gd': 1, 'new joint-seam hole larger than 1px': 217, 'detached opaque component outside outline exemption': 1}
```

See `feedback3_native_diagnostic.json` for the exact capture manifest hash,
current gate criteria and input hash differences. The only binding changes
are the gate hook, new silhouette helper and native elbow test metadata.
A final binding audit also observed:

```text
UNCHANGED ART/MESH/MOTION BINDINGS: PASS; only ['runtime:tests/rr10/feedback3/capture.json', 'runtime:tools/humanoid_cutout/gates.py', 'runtime:tools/humanoid_cutout/silhouette_gates.py']
```

Only `runtime:tools/humanoid_cutout/gates.py`,
`runtime:tools/humanoid_cutout/silhouette_gates.py`, and
`runtime:tests/rr10/feedback3/capture.json` differ from the director's captured
inputs. The original `native_gates.json` is preserved with the director's 344 errors.
New diagnostic crops: `/private/tmp/rr10-feedback3-native-failures/`.
This diagnostic did not pass native acceptance; sheets remain blocked.

Exact director commands and remaining-region coordinates are in
`../feedback3.md`. Existing rear TODO is unchanged; no new TODO_DESIGN added.
