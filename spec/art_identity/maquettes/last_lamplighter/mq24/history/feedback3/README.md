# mq-24 — feedback 3

The revised loose-ring gates are implemented, and the exact mq-20 integration
test fix is applied. The required full director contract **still fails**. The
ring does not pass through any finger disk in the permitted pose search.
Two outer fingertip caps are also farther than 0.012 H from the palm.
No new geometry or visible design value was chosen to conceal those failures.

## Requirement results

| Feedback-3 requirement | Result |
|---|---|
| Preserve accepted fan, thumb, mantle and segments | Every source mesh piece is byte-identical to round 2. The fan remains 12° with 0.01549 H tip separation; thumb remains 53° / 37.82154° with 0.003845 H clearance. All eight native limb ratios pass. |
| Mandatory signed containment through all four finger disks | FAIL. Independent polygon-parity audit of live opened geometry: 80,601 poses, zero four-loop candidates, maximum upper loops linked = zero. |
| Wire/hand clearance 0.001–0.012 H | FAIL. Exact triangle-surface distance is 0 H: wire intersects the hand. |
| Penetration no more than 0.004 H | FAIL. Native measured maximum is 0.004565568 H. |
| Every fingertip within 0.012 H of palm | FAIL. Native blunt-cap / palm surface gaps are 0.013240648, 0.011579783, 0.011574826 and 0.013247506 H. The two outer fingers exceed the limit. |
| Preferred pose or best permitted pose | Preferred −0.010 H axial offset / −3.8° roll retained as diagnostic. No contained pose exists in the prescribed search, so none can pass all gates. |
| mq-20 test fix | Exact line from integration a26e293e9 applied. Focused mq-20 tests pass. No mq-20 specification, delivery, paint, prompt or provided-data byte changed. |
| Accepted native delivery and complete proof | Not achieved: source/native mandatory gates fail. A fresh native build and opened-geometry/mutation audit were run through the bridge. Strict accepted capture/regeneration remains blocked. |
| Focused tests, mq-20 verify, full Python once | Focused results below; the single full Python invocation completed: 2331 tests, failures=2, skipped=66. |

## Geometry evidence

`contact.py` measures minimum actual wire/hand triangle distance, including
interior edge and face crossings. Sampling wire vertices alone misses contact.
`surface_gap.py` uses conservative AABB pruning and tests vertex/face,
interior edge/edge and segment/face regions. It also measures the actual blunt
distal caps against the palm surface. The old exact middle-contact and
full-occlusion numerical gates were replaced by the director's feedback-3
gates; their visibility observations remain in the report. Mandatory signed
containment and penetration were retained.

`pose_audit.py` independently recovers the live finger polygons and wire,
then uses polygon parity and signed crossings. It does not import the
constructor's analytic finger inequalities or trust its diagnostic output.
The native upper ring crossings have forearm-axis coordinates between
−0.017480077 and −0.009752090 H. The lowest any finger disk can reach under
allowed travel is −0.005674835 H. They do not overlap.

The cap/palm distances are intrinsic to the accepted hand geometry. A rigid
axial shift or wrist roll cannot reduce them. A separate necessary-interval
calculation also found no common upper-bar inclusion interval for all four
fingers at any of the 401 rolls, even without clipping axial travel. Merely
widening travel does not establish a complete solution.

The director was asked asynchronously for decided construction changes. No
answer or new dimension was assumed. All original mantle, label, wrist, ring,
chain, iron-limb and retained mq-20 geometry checks pass. The existing native
mutation targets catch **6 / 6**, with **0 survived**; this remains diagnostic
target-gate evidence because full-baseline acceptance fails.

## Evidence and results

- `feedback3_validation/`: current source/native gate reports, opened native
  snapshot, independent pose audit, fresh bridge receipts and segment/mutation
  tables. Its status explicitly says accepted=false.
- `proof/feedback3-native-r1/native/maquette.blend`: fresh native build.
- `delivery/`: retained round-2 diagnostic front/rear captures, 44 solos,
  joints_px.json, four exact 3× crops and same-scale contact sheet. This is
  previous proof of identical geometry, not a new accepted feedback-3 delivery.
- `history/feedback2/`: previous narrative, measurements and verification.
- `proof/feedback3-python-full/`: the single full Python suite's raw outputs.
- `verification_results.json`: exact commands, result lines, exit codes and
  current input hashes.

Focused observed results:

- mq-24: `Ran 40 tests in 15.710s`; `FAILED (failures=1)` — unchanged full director-contract assertion.
- mq-20: `Ran 35 tests in 31.175s`; `OK`.
- Delivery: `Ran 11 tests in 4.096s`; `OK`.
- Art identity: `Ran 111 tests in 65.461s`; `OK`.
- `MQ20_HASH_BOUND_DELIVERY: PASS`.
- `ISOLATION AUDIT: 236 modules`; exit 0.
- Fresh bridge native audit: `MQ24_NATIVE_AUDIT: FAIL; caught=6; survived=0`.

## Chosen defaults

Named controls in `chosen_defaults.json`: 401 roll × 201 axial samples,
minimum normalized motion from the director-preferred pose among equal
containment counts, 256 triangle pairs per distance batch, independent
polygon-parity audit, inherited thumb solve/sweep/oval/mantle numerical
controls, existing proof camera/crop/sheet controls, and 110 s execution /
120 s response deadlines. New distance fixtures are plain named fields in
`tests/test_mq24_maquette.py` FIXTURE_DEFAULTS. No visible target or model
vertex was selected or changed. **TODO_DESIGN keys: none.** The blocker is a
conflict among specified constraints.

## Proof for the design owner

From this worktree, the current source audit (expected failure) is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof source --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-source
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.feasibility --spec spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-source/spec_native.json --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-feasibility.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof verify
```

After decided construction rules permit every mandatory gate to pass, strict
native proof and fresh regeneration use the already supplied mq-24 bridge:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof prove --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-native
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof regenerate --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-regeneration --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-native/capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof verify --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-native/capture --regeneration spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-feedback3-regeneration
```

All Blender work used the director bridge. No local windowed run or GUI probe was attempted. A headless Godot import
generated missing proof-image sidecars; it was not used as a parser check. This offline native maquette has no Godot UI
scene or saved-run fixture; visual_probe_runner.py at 1920×1080 and
inspection_fixture.py have no target here. Existing native captures keep
mq-20's required physical registration. No full Godot suite, peer review,
sign-off, preflight, task-queue operation or Git write was run. All edits
remain uncommitted.

Changed this round: `contact.py`, new `surface_gap.py` and `pose_audit.py`,
`fist_construction.py`, `feasibility.py`, `measure.py`, `native_probe.py`,
contract/design/default data, README, measurements and reports under mq24;
`tests/test_mq24_maquette.py`; the single authorized line in
`tests/test_mq20_maquette.py`.

## Final full Python result and sidecars

The requested full Python suite ran **once**, after the last executable code
change, and completed with:

```text
Ran 2331 tests in 1760.681s
FAILED (failures=2, skipped=66)
```

Failures: the unchanged full director-contract assertion, and the repository
tracked-sidecar guard. The starting HEAD already lacked all 101 import
sidecars for its tracked mq24 proof PNG/WebP images; this round changed no
image. No assertion was rewritten. Standard metadata is now generated in
the owned delivery paths, with original image bytes unchanged. The prepared
prospective inventory passes the existing guard helper; the real tracked
inventory guard still requires the director to stage/commit the new files.
The observed full-suite result was not relabeled as a pass or rerun.

Sidecar proof: `feedback3_validation/sidecars.json`. Chosen invisible import
fixture defaults: `debug_project_name = MQ24 Proof Metadata Import`,
`debug_renderer = gl_compatibility`; only existing proof images were copied
under their original res:// paths into an isolated temporary project.
No production scene or script was loaded.

Exact full-suite command run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B tools/run_python_suite.py --shards 4 --output-dir spec/art_identity/maquettes/last_lamplighter/mq24/proof/feedback3-python-full
```

Exact headless metadata import command run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-24 && python3 -B tools/godot_task_runner.py --task-id mq-24 --stream -- godot --headless --path spec/art_identity/maquettes/last_lamplighter/mq24/proof/feedback3-sidecar-import --import
```

The executable-code and contract-data hashes still match their pre-suite
snapshot. The full native geometry hash still matches accepted round 2.
Current acceptance is **false**; fresh accepted captures/regeneration remain
unfulfilled because mandatory fist geometry checks fail.
