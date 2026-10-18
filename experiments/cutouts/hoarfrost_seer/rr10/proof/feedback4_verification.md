# Feedback 4 verification

All changes are uncommitted on `codex/rr-10`, based on `477e6d24a`. No GUI run,
peer review, Git publication or task-queue edit was performed.

## Build, source and bone proof

Commands:

```sh
python3 -B experiments/cutouts/hoarfrost_seer/rr10_build.py
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/samples.gd
python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py
```

Observed exit 0:

```text
RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)
RR10 TUCK COVERAGE: 0 missing source pixels (see proof/build.json)
RR10 BONE SAMPLES: PASS (629 poses; headless transforms only)
RR10 FRONT BONE/CUT GATES: PASS (0 errors)
```

Sample log: `/private/tmp/rr10-feedback4-samples.log`. Both the staged and case
compiled motion remain unchanged. A byte audit against HEAD also observed:

```text
RR10 PROTECTED PAINT/MOTION/ROPE AND NATIVE GATES: PASS (unchanged)
```

## Focused tests and mutations

```sh
python3 -m unittest discover -s tests -p 'test_rr10_*.py' -v
```

Log `/private/tmp/rr10-feedback4-focused.log`, exit 0:

```text
Ran 41 tests in 42.115s
OK
RR10 ATTACHMENT TRANSFORMS: PASS (629 poses; max wrist snap separation 1.368480 px)
```

After adding bolt 27 to the captured body fixtures:

```sh
python3 experiments/cutouts/hoarfrost_seer/rr10_seam_fixtures.py
python3 -m unittest discover -s tests -p 'test_rr10_tucks.py' -v
```

Observed exit 0, targeted log `/private/tmp/rr10-feedback4-tucks.log`:

```text
RR10 NATIVE SEAM FIXTURES: PASS (4 captured poses; no mesh raster)
Ran 6 tests in 0.804s
OK
RR10 ATTACHMENT TRANSFORMS: PASS (629 poses; max wrist snap separation 1.368480 px)
```

The four calibrated hole checks combine captured GPU body masks with current
rigid tuck masks. They pass mark 30, death 30, move 9 and bolt 27. Restoring
old native wrist tucks fails mark/death, and restoring the old near foot tuck
fails move 9. Existing far-elbow 3 px, idle rotation, split robe, 2 px tuck,
staff angle, planted hem, source fill/ownership and rigid agreement mutations
remain tested. The focused sheet success is a mocked-gate composer fixture;
it does not certify real current Seer contact sheets.

## Native probe load (headless only)

```sh
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/native_capture.gd -- --output /private/tmp/rr10-feedback4-probe-load --validate-only
```

Log `/private/tmp/rr10-feedback4-probe-load.log`, observed exit 0:

```text
RR10 NATIVE PROBE LOAD: PASS
```

This checks current rig, texture/check dimensions and proof mesh templates.
It does not produce or accept renderer pixels.

## Source idle preservation

```sh
python3 experiments/cutouts/hoarfrost_seer/rr10_idle_identity.py --reference 477e6d24a
```

Log `/private/tmp/rr10-feedback4-idle-source.log`, exit 0:

```text
RR10 SOURCE IDLE PRESERVATION: PASS (50 poses; 0 original source changes; 0 original frame changes; 132 new tuck pixel appearances; reference 477e6d24a)
RR10 IDLE TUCK DELTA: 36 affected frames; maximum 4 added pixels per frame
```

This source-space audit only shifts idle's rigid groups, without skinning a
mesh. It verifies every original source texel is unchanged and every added
texel is marked as continuation. Removing added tucks restores the old source
frames exactly. With those authorized additions present, 36 source frames
show up to four extra covered-surface pixels. The bob, still groups, timing
and original paint are preserved; a byte-identical old full idle bitmap is
not claimed. Exposed continuation is permitted by director feedback 1.

## Full Godot suite

```sh
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

Log `/private/tmp/rr10-feedback4-godot-full.log`, exit 0:

```text
TEST REGISTRATION AUDIT: PASS (742 scripts; full suite=398, quarantined=29, windowed probe=315)
MAIN BODY ASSERTIONS: 378792
FULL SUITE RUNTIME: 372.146 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The expected save-failure fixture and engine exit-time ObjectDB warning are
present. No existing assertions were rewritten.

## Full Python suite

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Log `/private/tmp/rr10-feedback4-python-full.log`, exit 0:

```text
Ran 880 tests in 765.671s
OK (skipped=63)
```

The verbose log records every optional-dependency skip and its reason.

## All-pose pixel-proof limitation and historical-body diagnostic

The unit brief prohibits a CPU mesh raster oracle and this sandbox cannot
capture current GPU pixels. Therefore no all-pose current native mesh hole
PASS is claimed. All 629 attachment samples and the four captured-body
regressions pass, but they do not replace fresh full native acceptance.

A discarded exploratory CPU alpha raster is not part of the implementation
or acceptance path. Its sampling flags are not native defects or proof.

A separate read-only diagnostic keeps every OLD captured GPU body mask and
adds only the new rigid tucks, without skinning/rasterizing current meshes:

```sh
python3 experiments/cutouts/hoarfrost_seer/rr10_tuck_diagnostic.py
```

Log `/private/tmp/rr10-feedback4-all-body-diagnostic.log`, exit 1:

```text
RR10 HISTORICAL-BODY TUCK DIAGNOSTIC: FAIL (467 presented poses; 71 flagged; current meshes not rendered)
```

This diagnostic is explicitly unaccepted and not fresh capture. Its remaining
flags are on the old body/cuff/robe rendering; it cannot measure the new robe
top or cuff mesh corrections. Details:
`proof/feedback4_rigid_tuck_diagnostic.json`. Stale native proof was never
rebound or certified; calibrated thresholds and the sheet acceptance guard
remain unchanged. The director's `native` and `sheets` commands in
`../feedback4.md` are the required next pixel proof.
