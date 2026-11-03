# mq-25 — ratified fist, native image acceptance still unresolved

The director's numeric ratification is implemented, and the full source and
opened-native 3D contracts now pass. Every source piece and native mesh is
identical to accepted round 2. The requested `accepted: true` delivery cannot
be issued under the literal native-image condition: the ring's physical top
projects outside the hand-only silhouette in front. Fresh acceptance is
explicitly **false**; no acceptance seal was manufactured.

The inherited mq-24 feedback-3 README and verification summary are preserved
in `history/feedback3/`. Its older evidence remains historical. `delivery/`
is untouched; this round's fresh front/rear clays, parts, 44 solos, joints,
four exact 3× hand crops and inspected same-scale sheet are retained in
`ratification_validation/native_delivery/`.

## Numbered requirement results

| mq-25 requirement | Result |
|---|---|
| 1. Accepted native prove/regenerate/verify; unchanged geometry and listed hashes | Fresh native build, opened-geometry audit and captures completed through the approved bridge. 3D gates pass; all 6 native mutations are caught, 0 survive; all 8 segment ratios pass. Native image acceptance fails, so prove and verify cannot certify an accepted delivery. Clean regeneration is recorded in `ratification_validation/regeneration.log`; final results are in `verification_results.json`. |
| 2. Admit protected director prompts; both verifies pass | `director_files.json` pins both original prompt byte hashes. They and their inventory are copied proof inputs, validated by `oracle.protected()`. Neither prompt was changed. mq-20 verify passes with them present. mq-24 verify correctly rejects the unmet image contract. |
| 3. Generate import sidecars, leave for owner commit | Isolated headless Godot imports generated the missing paint-job and fresh native-delivery sidecars. Original sources and existing sidecars are preserved. `ratification_validation/sidecars.json` lists generated paths and hashes. The real tracked guard still needs the owner's stage/commit; its prospective inventory is checked separately. |
| 4. No test compares against HEAD | mq-24 preservation is pinned to reviewed `3a8fccb65477c1685005d12c05a8d3179af91e3a`. The inherited mq-20 test already pins `84f5083029f7437efc9b409d470c2ced701261ad`; it was not changed. |

## Fist ratification and native measurements

`contract.json` changes penetration to at most 0.005 H and fingertip/palm
distance to at most 0.014 H. Wire distance and signed disk crossings are
reported only. Historical `feedback1_rules` and `design_details.json` remain
frozen construction inputs, including their superseded contact wording;
the top-level `near_hand` policy and `native_capture_requirements` define
current acceptance. No constructor, coordinate, pose, colour or visible
dimension changed.

Fresh opened-native measurements:

- maximum penetration: **0.004565567813149169 H**;
- cap/palm distances: **0.013240648138326106**, **0.011579783099567371**,
  **0.01157482639075373**, **0.013247505803422354 H**;
- exact nearest wire/hand distance: **0 H**;
- signed crossings per finger: **[0, 0, 0, 0]**; all-four containment **false**;
- fan: **12°**; thumb and mantle unchanged; all eight segments pass.

`ratification_validation/native_probe.json` retains every original
measurement plus the explicit signed counts. `segment_lengths.md` and
`mutation_table.md` report the live native results. Every source/native piece
hash is listed in `ratification_validation/geometry_sha256.md`; all protected
input byte hashes are in `round2_geometry_sha256.json`. The combined native
mesh hash remains:

`943a4519b9f457746fc3d53609c2a26e533e8b253cf1ac7668a45df1d50e05bd`

## Native-image conflict

The native hand-only front silhouette's bounding box is
**[720, 576, 769, 625)**. The ring's highest physical centreline station
projects to native pixel **(735, 570)**, outside that silhouette. This is a
necessary inclusion condition regardless of the chosen extent of “top bar.”
All upper-ring station positions and their actual native alpha observations
are reported. Rear inclusion is diagnostic only.

For the lower ring, there are **37** native visible owner pixels, but **0**
below the hand's overall bottom; the lower ring's projected region is
**[720, 579, 750, 606)**. **8** of those visible pixels are below the hand edge
in their own columns. Both interpretations are retained in
`projection_witness.json`; the current gate uses the whole-fist bottom.
The chain has **366** native visible pixels below that bottom and passes.
The director was asked for the intended top-bar/silhouette definition; no
geometry or requirement was silently changed to obtain acceptance.

`native_delivery/mq24_acceptance.json` binds the observations to image hashes
and records `accepted: false`. The gate uses the actual native hand alpha,
lantern solo and depth-tested label images. Projected triangles locate only
the native pixels to inspect; they do not replace the renderer. All four
fresh hand crops and the contact sheet were opened and inspected.

## Chosen defaults

Only invisible measurement/import controls were chosen. They are plain named
fields in `chosen_defaults.json`, `capture_gate.py:IMAGE_DEFAULTS`, and
`sidecars.py:IMPORT_DEFAULTS`: existing 128 alpha threshold and nearest-sRGB
label decoding, containing-pixel projection, existing pixel-centre triangle
sampling, highest ring centreline as a necessary inclusion witness, and a
whole-fist-bottom reference with the local-column observation also reported.
The import scratch project uses `MQ25 Proof Metadata Import` and
`gl_compatibility`, and preserves each original `res://` path. Inherited
camera, physical registration, numeric tolerances and bridge deadlines were
retained. **TODO_DESIGN placeholder:** `TODO_DESIGN_below_fist_definition` in
`ratification_validation/design_pending.json` records the unresolved lower-ring
interpretation; the whole-bottom gate is a provisional measurement convention. The top-bar issue is a conflict with preserved geometry. The lower-ring
interpretation is pending director clarification.

## Proof for the design owner

The full commands, observed results and artifact paths are recorded in
`verification_results.json`. The full Python suite was invoked once, after
the final executable-code change, using:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B tools/run_python_suite.py --shards 4 --output-dir spec/art_identity/maquettes/last_lamplighter/mq24/proof/mq25-python-full
```

After a director resolution, use fresh output directories for strict proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof prove --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-mq25-native
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof regenerate --out spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-mq25-regeneration --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-mq25-native/capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof verify --capture spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-mq25-native/capture --regeneration spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-mq25-regeneration
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof verify
```

No local windowed run was attempted. Blender work used only the approved
headless bridge. This is an offline native maquette with no Godot UI scene or
saved-run fixture; `visual_probe_runner.py` and `inspection_fixture.py` have
no applicable target, so there is no windowed command to invent. The Godot
runner was used only for headless import metadata. No full Godot suite,
preflight, Git write, commit, queue update, reviewer agent or sign-off was run.
All changes remain uncommitted for the design owner.

## Final full-suite result

The required full Python invocation ran once, after the final code change.
It did **not complete**. The runner reached its 2,400-second per-shard limit
and then could not terminate one process group in this sandbox:

```text
SHARD 3 COMPLETE: 626 tests; 1579.850s
SHARD 4 COMPLETE: 574 tests; 1758.608s
RuntimeError: Shard 2 timed out after 2400s
PermissionError: [Errno 1] Operation not permitted
```

There is no official aggregate `Ran`/`OK`/`FAILED` line or `summary.json`.
234 of 236 module completion lines exist; `test_rr35_production` and
`test_rr45_lancer` have no completed result. The two complete shard reports
contain 1,200 tests, two failures (native image acceptance and an unrelated
SB02 movement check), zero errors, and 65 skips. The tracked-sidecar failure
is additionally recorded in an unfinished shard log. SB02 reports movement
plan 7,842 us against a 4,000 us cap; its assertion and runtime were unchanged. These partial counts are not presented
as the full-suite outcome. Raw shard logs, records and coverage are retained
in `ratification_validation/python_full/`; no assertions or runner code were
changed, and no full-suite retry was made.

The final code/contract hashes, 247 protected input hashes and all 57 native
mesh hashes still match their snapshots. No tracked file outside this unit
and its test changed. New test-only fixture choices are also named in
`verification_results.json:chosen_defaults`: ring translation `[0, 0, 1]`
and an all-zero invalid SHA-256.

For the design owner's merge validation, the observed slow execution now
justifies a longer known-workload limit; use a new output directory:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B tools/run_python_suite.py --shards 4 --shard-timeout 3600 --output-dir spec/art_identity/maquettes/last_lamplighter/mq24/proof/director-mq25-python-full
```
