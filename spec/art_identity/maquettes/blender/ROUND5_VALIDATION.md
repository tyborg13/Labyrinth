# mq-03 feedback 5 — body-side cloak labels and deterministic cache replay

The director accepted findings 1, 2, 4, 5 and 6 from round 4. This pass changes
only cloak ownership and hidden cloth cache serialization. The approved r3 spec,
geometry, facing, pose, joints, camera, clay and source painting are frozen.
Changes remain uncommitted on `codex/mq-03`; commits, peer review, task queue,
inspection setup and publication remain the design owner's responsibility.
Risk: offline Python/Blender authoring. No game runtime, balance, saves, input,
analytics or icon registry changes; no windowed/Godot fixture applies.

## Acceptance

1. Classify cloak faces once in body space by the sagittal plane through the
   actual posed torso bone midpoint. The plane contains armature forward and up;
   the named near shoulder orients its normal. Ties are near. Every face keeps
   its label in both views; both cape solos and every required rig solo are
   non-empty in both native captures. `MQ03_OWNERSHIP_PROOF` must pass.
2. Preserve approved saved mesh coordinates, polygon/loop topology, attachment
   transforms and pose through capture. Keep original clay/gallery bytes and
   joints identical; source spec bytes unchanged. No beauty PNG exists in the
   native baseline; approved painting/source assets remain untouched.
3. A fresh production Lancer r3 build and cache replay produce identical raw
   mesh hash strings for all 51 meshes, with unchanged hash function/precision.
4. Re-run focused maquette tests, art identity, compatibility, all four review
   mutations and the full Python suite; run native integration via the bridge.

## Implementation and files

- `ownership.py`: the body-side plane, normal oriented toward `shoulder_near`,
  and stable near ties. `ownership_probe.py` independently averages face vertices
  and confirms the native polygon-centre labels. `render.py`: classification before camera turns;
  unchanged owner-array hashes recorded in both views in `cloak_side.json`.
  Existing weighted/material validation and strict solo gates remain active.
- `cloth_topology.py` (new): snapshots and restores native vertices, edges,
  polygon loop ranges, loop vertex/edge indices and smooth flags. Solidify sees
  the original edge order instead of reconstructed edges. `cloth.py` uses this
  codec. `cloth_cache.py` verifies a topology digest as well as geometry.
  `contract.py` advances only hidden `cache_revision` from 7 to 8.
- `cache_replay_probe.py` (new): empty-cache real r3 build, replay, exact raw hash
  comparisons. `tests/test_maquette_blender.py` exposes it as an opt-in native
  unittest. `tests/test_maquette_regressions.py` tests body-side rotation
  invariance/ties and corruption of stored edge/loop order. Existing mutations
  and validations are preserved.
- `relabel_proof.py`: bounded saved-geometry captures, per-view label-hash checks
  against the initial classification, coverage and byte checks; round-5 output.
- `FITTING.md`, `VALIDATION.md`, `REVIEW_FIXES.md`, this handoff: updated rules and
  preserved historical evidence. Compatibility report is refreshed by its gate.

Chosen defaults: cache format revision 8 is a technical invalidation key; the
armature up axis is the existing +Z body frame. Native proof retains 1024-square
Cycles CPU, seed 0 and 8 threads. Bridge job/response budgets remain the
director's 120 seconds. Fresh-cache probe directories use UUIDs for isolation.
No player-facing values were chosen, and no `TODO_DESIGN_*` was introduced.

## Proof for the design owner

From `/Users/borgerding/workspace/Labyrinth.worktrees/mq-03`:

```sh
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/cache_replay_probe.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-03/spec/art_identity/maquettes/frostglass_lancer/spec_r3.json /private/tmp/labyrinth_codex/mq-03/round5/cache_replay
python3 -B spec/art_identity/maquettes/blender/relabel_proof.py
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/integration.py -- /private/tmp/labyrinth_codex/mq-03/round5/integration
python3 -B tools/maquette_fit.py measure --spec spec/art_identity/maquettes/frostglass_lancer/spec_r3.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --renders /private/tmp/labyrinth_codex/mq-03/round5/lancer_r3 --out /private/tmp/labyrinth_codex/mq-03/round5/measure --require-gate
python3 -B -m unittest discover -s tests -p 'test_maquette*.py' -v
python3 -B tests/test_art_identity_gate.py
python3 -B tools/maquette_fit.py compat --out spec/art_identity/maquettes/proof_mq02 --require-gate
python3 -B spec/art_identity/maquettes/blender/mutation_proof.py --out /private/tmp/labyrinth_codex/mq-03/round5/mutation_results.json
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
```

Native engine work runs only through the serial bridge with factory startup and
autoexec disabled. A job unanswered at 120 seconds stops work without retry.

## Observed results

The production-spec cache regression is observed:
`MQ03_CACHE_REPLAY: PASS; raw_hashes_identical=true; meshes=51` (exit 0, 7.5s).
Those hashes also match the original approved r3 cold-build report exactly.

Compatibility: `MAQUETTE_COMPAT: PASS` (exit 0); minimum part IoU 0.982631,
maximum joint error 0 px, all five figures/both views. The prior 20 native
old/new capture receipts remain bound in `proof_mq02/compatibility_report.json`.
Mutations: `MQ03_MUTATIONS: PASS; caught=4; survived=0`; constant torso,
material index zero, omitted context and disabled integrity each fail an
assertion with zero errors.

Ownership: `MQ03_OWNERSHIP_PROOF: PASS` (exit 0). Both required cape labels and
all other rig labels have non-empty solos in both views. Front/rear jobs exited
0 in 107.5s/95.2s, within the 120-second limit. The same face-owner array hash is
recorded before rendering and in both views; no camera-dependent relabelling.

| View | cape_near pixels | cape_far pixels |
|---|---:|---:|
| Front | 115071 | 98239 |
| Rear | 105552 | 88916 |

Native body-side audit: `CLOAK_BODY_SIDE_AUDIT: PASS` (exit 0, 1.0s).
All 12,952 independently averaged face centroids agree with native polygon
centre classification: 6,597 near faces, 6,355 far faces.

Frozen geometry: `MQ03_FROZEN_GEOMETRY: PASS; meshes=51; unchanged_rgba_images=66; clay_bytes_identical=true; spec_and_joints_identical=true; cold_replay_hashes_match_approved=true`.
The 66 byte-for-byte identical RGBA arrays exclude only two parts maps and four
cape solos from the 72-image capture manifest. Original clay/gallery PNG files
remain byte-identical, including metadata. Both view signatures retain the same
exact saved vertices, topology, attachment transforms and pose matrices.

Fit: `MAQUETTE_FIT: PASS; IoU=0.812207; median band error=0.036732; max band error=0.124394; conflicting bands=[]` (exit 0).
Native integration: `BLENDER_NATIVE_INTEGRATION: PASS` (exit 0, 25.5s), including
`BLENDER_SYMMETRIC_FACING_CONTROL: PASS; mirror_difference=0; rejected=true`.
The symmetric debug body's `BLENDER_FACING: FAIL` is the intended negative
fixture, while the actual Lancer facing report passes.
Focused suites: `Ran 98 tests in 93.870s`, `OK (skipped=2)`.
Art identity: `Ran 111 tests in 49.336s`, `OK`.
The two native opt-in test cases are exercised separately through the bridge
above. Full Python suite: `Ran 598 tests in 428.763s`, `OK (skipped=63)`.

All logs/artifacts are under `/private/tmp/labyrinth_codex/mq-03/round5`:

- `lancer_r3/front_parts.png`, `rear_parts.png`, `front_clay.png`, `rear_clay.png`;
  all 52 `front/rear_solo_<part>.png`; `piece_gallery/front_gallery.png`,
  `rear_gallery.png` and all 12 native gallery type captures.
- `lancer_r3/capture_manifest.json`, `ownership_proof.json`, `cloak_side.json`,
  `solo_coverage.json`, `ownership_validation.json`, `ownership-front_geometry.json`,
  `ownership-rear_geometry.json`, `facing_report.json` and bridge receipts.
- `cache_replay/cache_replay_report.json`, fresh/replay `build_report.json` and
  editable native blends; `cloak_side_audit.json`; `invariants.json`;
  `measure/fit_report.json`, `measure/fit_overlay.png`;
  `integration/integration_report.json`; `mutation_results.json`.
- Logs: `relabel.log`, `cache_replay.log`, `cloak_side_audit.log`, `invariants.log`,
  `measure.log`, `integration.log`, `focused.log`, `art_identity.log`, `compat.log`,
  `mutations.log`, `python_full.log`. Native receipts also retain exact commands
  and logs under the bridge `done/<id>.json`/`.log`.

The earlier empty-cloak and cache-reordering issues are resolved. No design
placeholder or remaining issue is known in this pass.
