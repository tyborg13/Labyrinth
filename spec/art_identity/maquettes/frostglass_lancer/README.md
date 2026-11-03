# Frostglass Lancer — mq-14

Uncommitted implementation for the design owner. No paint-over, runtime rig,
image generation, peer review, Git publication, or queue change is included.
The original r1–r4 specifications, prompts, tone files and painting provenance
remain byte-for-byte unchanged.

1. `measurements.json` is the canonical Blender-native v2 input. It is rebuilt
   by `mq14/recipe.py` from untouched `spec_r3.json` and the explicit source
   measurements in `mq14/measurements.json`. The CC0 humanoid anatomy and
   armature remain real native geometry. Facing and native ownership pass.
   There are exactly the director's 22 semantic labels. Hood/scarf own `head`;
   the single split tabard belongs to `pelvis`; both cape sides belong to
   `torso`. Shaft and crystal use one `spear` owner, one hand bone and one grip.
2. Shoulders are level in 3D. At the r4 provenance camera the old far shoulder
   was **11 px below** the near one. At the common delivery camera the old
   value is **9.428571 px below**; the new value is **25.59 px above**, against
   **25.5855 px required**, within the brief's ±10 px. Full values are in
   `delivery/review/mq14_gates.json` and `delivery/joints_px.json`.
3. Both views turn one frozen body through a proper 180° rotation. Front's
   lower/right foot is `near`; rear's lower/right foot is `far`. Native sole
   minima are 0.031236140 m / 0.029006820 m. The planted spear surface is
   0.029006720 m. Native feature visibility independently verifies the visor
   and chest crystal in front only, and the spearhead in both views.
4. Front IoU is **0.711792466** (minimum 0.70); rear is **0.693576133**
   (minimum 0.65). Every label has nonempty, unclipped front/rear solos.
   Per-part native coverage and painting-alpha coverage are in
   `delivery/review/per_part_coverage.csv`. Hidden rear torso, pelvis, belt,
   free hand and upper legs have explicit occlusions and native occluding-owner
   counts. No painting part segmentation is inferred.
5. `delivery/` contains native 1024 clays, part maps, every solo, projected
   joints, manifests, fit overlays and one contact sheet. Herald r2 and Gloam
   r3 clays are registered at a common world scale on that sheet. Native clay
   PNG bytes are retained; only masks receive lossless packing. The manifest
   covers this figure's retained files and must stay below 6,000,000 bytes.
   Temporary blends, caches, candidates, clean input copies and duplicates
   are inventoried before removal in `discarded_proof_sha256.json`.
6. Cold, shared-cache replay and independent-cold builds match bit for bit:
   52 native meshes and every native joint matrix. A fresh input-only build
   matches both clay/map pairs and geometry. Material mutations and the
   shared delivery mutation suite are caught. `acceptance_binding.json` binds
   the native capture, fit, source measurements and task-specific proof;
   the existing hash-bound delivery validator remains mandatory.

## Registration and known source-fit limits

The front fit uses the measured lower-sole alpha centroid x=150.5. The true-turn
rear fit uses the director's lower-sole landmark x=148 from
`spec/art_identity/jobs/frostglass_lancer/mq4_landmarks_pair.json`. Source
head/sole pixel-edge heights are 22/246. These registration inputs are explicit,
hash-bound data. The report retains the alternate rear alpha-centroid x=
143.14814814814815 result: **IoU 0.649631766**. The rear result is registration
sensitive; that diagnostic is retained for the director's inspection.

The rear painting exposes a belt pouch. In this static native assembly the
belt/pouch is occluded by the cloak and body; this difference is explicit in
coverage rather than counted as a visible part. Its complete native solo and
rigid geometry remain available. The historical spear stopped above the floor.
It now extends along its existing axis to the measured boot support plane,
keeping the grip and crystal connected. This makes its front floor end project
below the painting's old endpoint. The wider proof camera retains the whole
planted item; fit includes that additional shaft silhouette.

## Proof for the design owner

No windowed Godot command or inspection fixture applies: this is an offline
Blender-only source and delivery change. Every native job used the director's
bridge, with `timeout_s=110`; no unanswered job or windowed retry occurred.
All changes remain uncommitted. The director owns inspection, full suites,
peer review, commit and publication.

Run these stages in order to reproduce the complete native proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-14 && python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow build
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-14 && python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-14 && python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow regenerate
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-14 && python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow proof
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-14 && python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow curate
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-14 && python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow verify
```

The native build, capture and regeneration commands, exits and logs are retained
under `mq14/validation/bridge/`. Focused test logs and mutation results are in
`mq14/validation/`. The full suites are intentionally left to the director,
per the unit brief.

## Chosen defaults

`mq14/chosen_defaults.json` records all new proof/sampling choices: 2.8-world-unit
proof camera at target [0,0,1], 17 cape columns, one static rest frame, 11-label
capture batches, 110-second bridge jobs, a 4×2 proof sheet with 28-pixel captions
and Pillow's default font. Native contact/joint tolerances reuse 0.02 m / 1e-4 m.
The source coordinates, support-plane height and pouch dimensions are measured
inputs, not gameplay tuning. No player-facing defaults were introduced.

No unresolved `TODO_DESIGN_*` placeholder remains. The registration sensitivity,
rear pouch occlusion and planted-spear projection above remain explicit limits
for the design owner's inspection.

## Feedback 1 — delivery binding and effective guard tests

The coverage CSV writer uses explicit LF record terminators. Its acceptance
binding is regenerated from those checkout-stable bytes. Accepted clays, part
maps, solos, joints and all fit/turn measurements are unchanged. No native
builder code changed, so no Blender regeneration is needed for this correction.

`tests/test_mq14_lancer.py` validates the canonical baseline before each delivery
test. Semantic mutations refresh the report seal and dependent fit-report hash;
hash mutations have independent tests. Missing canonical proof fails the tests.
The CSV regression regenerates the fit report in a temporary directory and
checks LF bytes and unchanged coverage data.

`tests/test_mq14_builder.py` rejects invalid native-v2 inputs, non-finite static
axes and conflicting drape. Its headless fixture exercises the real cloth
dispatcher, static contact resolver, harmonic interpolation and cache replay.
Only native API plumbing is replaced; an analytical half-space supplies exact
BVH overlap/nearest answers. It checks contact clearance, unchanged tangential
coordinates and free boundaries. No render or geometry source is replaced.

Run the focused regressions and guard-removal proof from a fresh checkout of
the scratch proof commit:

```sh
python3 -B -m spec.art_identity.maquettes.frostglass_lancer.mq14.workflow verify
python3 -B -m unittest tests.test_mq14_lancer tests.test_mq14_builder
python3 -B -m tests.mq14_guard_mutations --out /private/tmp/labyrinth_codex/mq-14-feedback1/mutations-fresh
```

The mutation runner first requires a passing baseline, then removes each guard
in an isolated interpreter without editing source files. It requires an actual
assertion failure, with no errors or skips, for each mutation: required gates,
fit thresholds, report/measurement/fit-report binding, static-back dispatch and
contact, native-v2 validation, finite axis, conflicting drape, LF CSV and missing
proof skipping. Test-only geometry, API and cache fixtures are named fields in
`tests/mq14_cloth_fixture.py`; the mutation subprocess timeout is a named
60-second field in `tests/mq14_guard_mutations.py`. These are the only additional
chosen defaults. No design placeholders or player-facing values were added.
