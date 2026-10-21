# rr-31 feedback 3 — final storage and documentation cleanup

The accepted rig is unchanged from `e9aadfc32`. This round only repackages the
existing calibration evidence and corrects the brace-selector documentation.

Files changed: `../rr30_joint_calibrate.py`, new `../rr30_joint_storage.py`,
regenerated `../rr30_joint_cover_cuts.json`, new
`../rr30_joint_cover_cuts.evidence.json.gz`, `README.md`, this handoff,
`proof/feedback3_storage.json`, `proof/feedback3_results.json`, and new
`tests/test_rr31_storage.py` at the repository root. No runtime asset changes.

## 1. Compact operational cuts, lossless evidence sidecar

`../rr30_joint_calibrate.py` now writes through `../rr30_joint_storage.py`.
The operational JSON keeps each view's original `basis`, `frames` and `cuts`.
Its `full_evidence` reference binds the gzip sidecar by SHA-256 and row counts.
Construction readers need only the JSON; they do not open the sidecar.
Calibration `--extend` verifies and loads the sidecar before appending evidence.
Legacy inline records remain readable for repackaging.

| Storage | Bytes |
|---|---:|
| Previous inline JSON | 27,622,307 |
| Regenerated operational JSON | 596,864 |
| Detailed evidence gzip sidecar | 391,329 |
| Combined after | 988,193 |

Combined storage falls by **96.42%**. All 11,911 unique source cuts are unchanged.
All 10,281 evidence rows and 435,880 texel occurrences survive losslessly,
including repeated observations. Regenerating again produces byte-identical
JSON and gzip files. No cover calibration or art builder was rerun.

The packaging command is:

```sh
python3 experiments/cutouts/slag_mortar/rr30_joint_calibrate.py --compact
```

`tests/test_rr31_storage.py` checks lossless legacy conversion, deterministic
regeneration, sidecar integrity/inventory, extension retaining old evidence,
all real cut/evidence correspondences and both actual action-domain readers
without the sidecar present.

## 2. Brace documentation

The README now records that the director restored `brace:block` in the staged
data. Both imports match that data byte for byte. Editable and production
compiled motion are byte-identical and include the selector. No motion file or
compiler behavior was changed.

## 3. Runtime identity and focused proof

`proof/feedback3_storage.json` records hashes, sizes and the accepted baseline.
All **217/217** files under `assets/units/slag_mortar_cutout/` match both the
before-edit snapshot and accepted HEAD. No file was added or removed there.
The saved native capture's input bindings remain current. Paintings, source
construction, motion, rests, flap, stretch, walk fit and density are untouched.

Focused commands, from this worktree:

```sh
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr31*.py' -v
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr30_mortar.py' -v
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr30_joint_surfaces.py' -v
python3 experiments/cutouts/slag_mortar/rr30_gates.py --native experiments/cutouts/slag_mortar/rr30/proof/native
```

Final observed result lines are recorded in `proof/feedback3_results.json`.
Full focused logs are local under `proof/logs/feedback3_*.log`.

- rr31: `Ran 35 tests in 26.670s`; `OK`.
- Mortar: `Ran 10 tests in 11.189s`; `OK`.
- Joint surfaces: `Ran 4 tests in 410.664s`; `OK`.
- `RR30 FRONT CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)`.
- `RR30 REAR CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)`.
- `RR30 NATIVE GATES: PASS (0 errors; both views)`.
- `RR31 FINAL RUNTIME BYTE IDENTITY: PASS (217/217 files unchanged after all focused checks)`.

There are **49 passing focused tests**. The native replay checks all 862 saved
frames. Maximum CPU cover distances remain front 2.999497061328248 px and rear
2.9981903453869387 px. Native walk fits remain front 0.091893 px / rear
0.098218 px, with zero support drift in both views.

## Proof for the design owner

The native gate replay reads the director's accepted frames in
`../rr30/proof/native/`; it does not capture, mask or rewrite images. Its compact
result is `../rr30/proof/native_gates.json`. The CPU sweep report remains
`../rr30/proof/joint_cleanup/full_sweep.json`.

No windowed command, new capture, full suite, peer review or publication is
needed or performed for this storage-only cleanup. The director's native
acceptance stands; the eight-stage proof driver is unchanged.

## Chosen defaults, TODOs and open issues

Storage-only constants are `EVIDENCE_GZIP_LEVEL=9` and
`EVIDENCE_GZIP_MTIME=0` (deterministic archive metadata). The new synthetic
fixtures are test-only. No player-visible default or TODO_DESIGN placeholder
was introduced. There are no open issues from this round. Changes remain
uncommitted for the design owner.
