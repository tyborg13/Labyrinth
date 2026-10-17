# mq-03 review fixes on 91eb24aaf

Historical round-4 handoff. The director corrected the split rule in feedback 5;
[ROUND5_VALIDATION.md](ROUND5_VALIDATION.md) supersedes the two open issues below.

Implementation scope: six findings in the director's feedback 4. The review was
read from `codex/peer-benchmark:spec/peer_benchmark/feedback/mq-03_review_91eb24aaf.md`.
No new review, commit, branch change, queue edit or publication is part of this work.

## Acceptance and implementation

1. Native compatibility: `legacy_capture.py` executes the geometry and camera of
   the original `61b0c2f0ba8793db3499038de3d959b1a6f220d4` builders, replacing only
   their Workbench rendering loops with Cycles CPU alpha captures. The shared
   humanoid adapter exposes a capture callback so proof uses its actual builder.
   `legacy_proof.py` runs one view per bridge job for all five figures. `compat`
   compares every old/new solo and actual projected joint. Gates remain IoU
   >=0.98 and joint error <=1 px; missing solo or joint evidence cannot pass.
2. Capture provenance: `capture_manifest.py` binds original spec hash, capture
   mode, every named PNG's SHA-256/dimensions and joints SHA-256. `backend.py`
   never selects masks by file existence. Full captures delete fit-only mattes.
   Regression: a current 2,000-pixel silhouette/solo retains 2,000 pixels despite
   adjacent stale 500-pixel body/head files; a manifest-listed overwritten matte
   is rejected by hash, and unnamed/mismatched-mode/spec inputs are rejected.
3. Cloak ownership: face centroids are compared to the actual posed torso bone
   midpoint plane, normal to the horizontal camera direction. Negative signed
   depth is `cape_far`; zero/positive is `cape_near`. Each view starts from the
   unchanged mesh. Transparent excluded faces isolate mixed-owner solos. Every
   spec label requires a non-empty solo. Weighted anatomy is audited against
   independent summed region winners; material indices are audited against
   expected owners. `relabel_proof.py` checks frozen mesh coordinates, topology
   and transforms, then checks clay/gallery byte hashes against approved r3. Coverage remains a strict gate; diagnostic captures are retained when it fails.
4. Bezier conformance: `curve_projection.py` snapshots and projects each control
   coordinate and both handles; FREE handles retain projected positions. POLY
   controls retain their homogeneous weight. Portable and native behavioral
   fixtures check projection counts and moved coordinates for both types.
5. Facing: `torso_reflection.py` reflects pixel centres, evaluating the projected
   centreline at row centres. Axis-aligned and sloped symmetric fixtures return
   exactly zero mirror difference. A frontal axis and symmetric torso fail the
   facing checks. The native rotationally symmetric debug anatomy is now an
   explicit negative control; its former apparent asymmetry was the reviewed bug.
6. Bytecode: the two tracked `.pyc` files are removed; the maquette-local
   `.gitignore` excludes Python bytecode and `__pycache__` directories.

The original r3 spec, geometry recipe, pose, facing, camera, materials and source
painting remain unchanged. This pass changes ownership outputs and validation.

## Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/mq-03`:

```sh
python3 -B spec/art_identity/maquettes/blender/legacy_proof.py
python3 -B tools/maquette_fit.py compat --out spec/art_identity/maquettes/proof_mq02 --require-gate
python3 -B spec/art_identity/maquettes/blender/relabel_proof.py
python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/integration.py -- /private/tmp/labyrinth_codex/mq-03/round4/integration
python3 -B tools/maquette_fit.py measure --spec spec/art_identity/maquettes/frostglass_lancer/spec_r3.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --renders /private/tmp/labyrinth_codex/mq-03/round4/lancer_r3 --out /private/tmp/labyrinth_codex/mq-03/round4/measure --require-gate
python3 -B spec/art_identity/maquettes/blender/mutation_proof.py --out /private/tmp/labyrinth_codex/mq-03/round4/mutation_results.json
python3 -B -m unittest discover -s tests -p 'test_maquette*.py' -v
python3 -B tests/test_art_identity_gate.py
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
```

The bridge uses factory startup and disables automatic scripts. Default job and
response limits are 120 seconds; there is no retry after an unanswered job.
All proof is offline Python or native Cycles CPU via the bridge. No game runtime
changed, so Godot, windowed 1920x1080 captures and `inspection_fixture.py` are not
applicable. The round-3 native gallery is retained byte-for-byte because no
accessory geometry or clay shading changes.

## Observed results

Native legacy compatibility: `BLENDER_LEGACY_COMPATIBILITY: PASS` and
`MAQUETTE_COMPAT: PASS` (both exit 0). Every joint error is 0 px. Minimum
front/rear part IoUs are Gaoler 0.990079/0.990081, Lancer r1
0.997701/0.997645, Wisp 1/1, Bloomer 0.986605/0.982631, Shrike
0.998274/0.998746. The 20 native capture jobs took 11.7–63.1 seconds each.

Mutation proof: each of constant torso ownership, material index zero, omitted
cloth context and disabled cache integrity is caught by an assertion with zero
errors. Exact result: `MQ03_MUTATIONS: PASS; caught=4; survived=0`.

Final focused suites: `Ran 96 tests in 73.766s`, `OK (skipped=1)`.
Final full Python suite: `Ran 596 tests in 385.211s`, `OK (skipped=62)`.
Final explicit art identity: `Ran 111 tests in 38.693s`, `OK`.
Native integration: `BLENDER_NATIVE_INTEGRATION: PASS` (exit 0, 21.6s), including
`BLENDER_SYMMETRIC_FACING_CONTROL: PASS; mirror_difference=0; rejected=true`.
Its `BLENDER_FACING: FAIL` line is the expected symmetric negative fixture.
Initial full-suite and art runs also passed; their logs remain archived.

Remeasurement: `MAQUETTE_FIT: PASS; IoU=0.812207; median band error=0.036732; max band error=0.124394; conflicting bands=[]`.
Frozen delivery: `MQ03_FROZEN_GEOMETRY: PASS; matching_meshes=51; approved_spec_unchanged=true; clay_bytes_identical=true; unchanged_rgba_captures=66; joints_identical=true`.
The manifest binds all 72 current native capture images. The 66 unchanged RGBA
captures exclude only the two parts passes and four cape solos. The saved-mesh
signatures retain exact vertices, topology and attachment transforms. Rear
verification uses the authoritative attachment `matrix_basis`, avoiding the
floating-point inverse reconstruction in `matrix_local` after camera parenting.

Ownership result: `MQ03_OWNERSHIP_PROOF: FAIL; {"front": {"cape_near": 0, "cape_far": 211986}, "rear": {"cape_near": 193252, "cape_far": 0}}`,
`OWNERSHIP_VERIFY_EXIT: 1`. The native front/rear jobs exit 2 because the strict
required-solo gate rejects the empty labels; all images and invariant reports
are retained. No bridge response exceeded the 120-second deadline.

Artifacts under `/private/tmp/labyrinth_codex/mq-03/round4`:

- `lancer_r3/front_parts.png`, `rear_parts.png`, `front_clay.png`, `rear_clay.png`;
  all 52 `front/rear_solo_<part>.png`, `joints_px.json`, `facing_report.json`;
  `piece_gallery/front_gallery.png`, `rear_gallery.png` and 12 native type images.
- `lancer_r3/capture_manifest.json`, `ownership_proof.json`,
  `ownership_validation.json`, `solo_coverage.json`, `cloak_depth.json`;
  `ownership-front_geometry.json`, `ownership-rear_geometry.json` and bridge receipts.
- `measure/fit_report.json`, `measure/fit_overlay.png`; `invariants.json`;
  `cloak_depth_audit.json`; `integration/integration_report.json`;
  `mutation_results.json`; `compatibility/` old/new images and receipts.
- Logs: `compat.log`, `ownership_verify.log`, `integration.log`, `measure.log`,
  `invariants.log`, `mutations.log`, `focused_final.log`, `python_full_final.log`,
  `art_identity_final.log`. Native scripts' complete commands/logs are also in
  the bridge `done/<id>.json` and `.log` receipts.

### Existing cache replay ordering issue (not a delivery geometry change)

An additional cache-hit r3 rebuild returns `BLENDER_MAQUETTE: PASS` (2.6s).
Its vertices and attachment matrices are exactly identical to the approved
saved model, but the four cloth meshes have reordered polygon arrays, changing
raw mesh hashes. Native `compare_saved.py` confirms the same oriented face sets
and identical coordinates. Running the original cloth code from `91eb24aaf`
against the same cache produces exactly the current hashes:
`HEAD_CACHE_REPLAY_COMPARISON: PASS; mesh_hashes_identical=true` (2.6s).
This is a pre-existing cache-ordering issue, not introduced by these fixes.
It was not concealed by changing the mesh hash/assertion. The delivered labels
come from the original frozen blend, preserving even its polygon array order.
Evidence: `rebuild_comparison.json`, `rebuild_comparison.log`, `head_cache.log`.
Future cache-format work can preserve native edge ordering; no such geometry
pipeline change was made in this ownership-only pass.

### Requirement 3 has incompatible frozen-geometry constraints

The native audit `/private/tmp/labyrinth_codex/mq-03/round4/cloak_depth_audit.json`
measures the exact frozen approved mesh, independently averaging each face's
vertices and comparing that centroid with Blender's native polygon centre.
Their maximum difference is exactly 0. All 12,952 cloak faces are behind the
front plane: signed depths range from -0.320416048 to -0.009565346. All are
in front of the rear plane: +0.009565346 to +0.320416048. Even the nearest
vertex is 0.006794922 units behind the front plane. The actual torso midpoint
is [0.1593562514, -0.3179406822, 1.6289999485], and the front horizontal
camera normal is [0.7071067691, 0.7071067691, 0].

Thus exact requested depth classification necessarily leaves front `cape_near`
and rear `cape_far` empty. Requiring both labels non-empty in both views cannot
pass while the approved geometry and specified plane remain fixed. No plane
shift, invented ownership, geometry edit or gate relaxation was made. Native
coverage rejects the empty solos; the delivered diagnostic proof remains FAIL.
A design-owner change to one of these constraints is needed to complete that
acceptance criterion.

A diagnostic front clay rerender had exactly identical RGBA pixels, but native
PNG metadata contains current Date/RenderTime fields. Delivery retains the
original approved clay and gallery files byte-for-byte; ownership-only capture
never overwrites them. No beauty render is present in the native baseline,
and the approved paintings/source files are untouched.

## Files and technical defaults

Changed builder/adapter files: `build.py`, `backend.py`, `bridge_client.py`,
`capture_saved.py`, `cloth.py`, `conformance.py`, `facing_probe.py`,
`integration.py`, `render.py`, `validation.py`; new focused helpers are
`capture_manifest.py`, `cloth_cache.py`, `curve_projection.py`, `ownership.py`,
`torso_reflection.py`. New proof runners are `legacy_capture.py`,
`legacy_proof.py`, `relabel_proof.py`, `mutation_proof.py`, `ownership_probe.py`,
`compare_saved.py` and `check_head_cache.py`.
Outside this package: `humanoid.py` (capture callback), `compatibility.py`,
`tools/maquette_fit.py`, `tests/test_maquette_blender.py`,
`tests/test_maquette_regressions.py`, maquette `.gitignore`, `FITTING.md`,
`proof_mq02/compatibility_summary.md` and `compatibility_report.json`; two removed
tracked Python binaries. `VALIDATION.md` links this current handoff.

Chosen defaults: bridge poll interval 1 second; job/response limit 120 seconds;
legacy proof Cycles CPU at 1024 square, 1 sample, 8 threads, seed 0; baseline Git
revision above; isolated proof roots in `PROOF_DEFAULTS`. Regression fixtures
use 100-square masks with 2,000 current/500 stale pixels, explicit synthetic
weight winners/ties and curve controls. No player-visible design defaults were
chosen, and no `TODO_DESIGN_*` placeholder was introduced.
