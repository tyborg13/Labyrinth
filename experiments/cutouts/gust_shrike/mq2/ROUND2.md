# rr-03 round 2 — head clock, ownership and hidden values repaired

Work remains uncommitted. The supplied original paintings, all 23 Blender
exports and protected director motion JSON are unchanged. Both rebuilt rests
retain every approved RGBA byte (0 changed pixels).

1. **Head clock implemented.** `recipes/motion_interpretation.json` records 30
   FPS and start-at-key placement. The compiler emits `HEAD_SNAP_FPS`,
   `HEAD_SNAP_PLACEMENT`, `HEAD_SNAP_SECONDS` and the actual two-frame transitions.
   The return to the first pose starts at loop phase zero. Generated runtime and
   case motion data match. Motion design is complete.
2. **Ownership islands repaired.** `repair_ownership.py` reuses rr-02's complete
   visible-plus-hidden component repair with its 8-connected components,
   4-connected neighbour borders and source-label-order tie break. It moves 45
   front and 50 rear source pixels onto adjacent parts. The split nodes retain
   each pixel's original rest draw depth. Islands connected to the whole rest
   only through another moving part are included. A trace across all 904 poses
   finds zero remaining small detached components; no additional traced moves
   were needed. Source gates independently re-derive owners and hidden masks
   from the original paints/Blender maps and compare the recorded repair.
3. **Visible-value fills repaired.** `repair_fills.py` uses each paint label's
   complete visible RGB distribution, including midtones, with the existing
   rr-02 diffusion and sampled palette. The full hidden region participates in
   quantile matching: the former fixed outline override made 15 of the front
   wing's 16 hidden pixels too dark. Visible RGB, alpha and rest images are
   untouched. The median-L* limit remains **8**, and reference-IQR midtones
   remain mandatory. The six semantic ownership classes are unchanged. Head
   feathers, beak and mask are compared to their own material references rather
   than pooling unequal visible/hidden material proportions.

Front wing_near now has median difference **1.963** with **7** midtone pixels;
rear head feathers have **0.654** with **199** midtone pixels. Each retained
hidden material uses its own same-view visible distribution. Sparse references
still require rr-02's same-view, same-material nearest-part rule and fail if no
eligible donor exists; no cross-view fallback is used.

The rear beak/mask initially appeared to require a new donor decision. Source
analysis showed that their entire hidden regions are covered by higher layers
on the identical head bone. The same holds for the front beak. These three
underlays (152 front-beak, 224 rear-beak and 413 rear-mask pixels) were removed
as redundant. Strictly higher hidden depth prevents cyclic coverage proofs;
visible layers are above all hidden layers. Their visible paint remains intact.
The source coverage is invariant for every rigid head transform. A separate
904-pose before/after RGBA comparison verifies the removal has no rendered
pixel effect in the complete sampled motion set. No donor decision remains.

There are no remaining `TODO_DESIGN` fields or pending fills. All 16 source
requests are accounted for: 13 retained hidden materials and 3 requests with
no retained hidden pixels. Production promotion and windowed native proof
remain with the design owner.

## Files

- Compiler, generated case/runtime motion data, motion interpretation recipe.
- New case-local `repair_ownership.py`, `repair_fills.py`, ownership/value recipes.
- Rebuilt case ownership, segmented pieces, layouts, hidden requests and fills.
- `probes/motion_gates.py`: source-derived ownership verification and same-part
  value references; unchanged zero-speck and median-L* limits.
- Focused Python and Godot tests cover the explicit head clock, islands attached
  through another part, sparse donor selection, and thin hidden-fill midtones.

No shared rr-02 tool, protected design data, gameplay value, damage/contact
logic, analytics or save behaviour changed in this round.

## Observed checks

Current headless gates are **PASS**. Logs are in `proof/round2_*.log`.

- `SHRIKE MOTION SAMPLES: PASS (904 poses; design complete=true)`.
- `SHRIKE MOTION GATES: PASS`: 904 frames, 0 specks, 0 magenta, 0 clipping,
  0 empty frames, 0 errors; all 13 retained hidden material references pass.
- `MAQUETTE_EXPOSURE: PASS (16 requests; 0 unknown solos)`.
- Rest identity: 0 different pixels front and rear. Protected originals/data/
  Blender exports all match their round-1 hashes.
- `round2_prune_equivalence.json`: 904 comparisons, 0 different frames.
- `GUST SHRIKE CUTOUT: PASS (43 checks, 0 failures; headless logic only)`.
- Focused Python: `Ran 15 tests in 0.046s`, `OK`.
- Full Python: `Ran 529 tests in 341.019s`, `OK (skipped=61)`.
- Full Godot: `FULL SUITE RUNTIME: 735.048 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`, process exit 0.
- Structural validation with all case input hashes protected: PASS;
  `git diff --check`: exit 0.

The full suites ran during implementation. The final case-only redundant-layer
repair additionally passed the focused Python tests, source-derived ownership
checks, fresh motion sampling, all CPU gates and exact before/after comparison;
the full suites were not repeated for that isolated repair. The logs contain
macOS certificate, NumPy and resource-exit diagnostics, without assertion failures.
No baseline claim is made for those diagnostics.

The refreshed `proof/cpu_diagnostic.png` was visually inspected as a CPU
reference only. It is not native proof. `round2_diagnostic_sheet.json` records
its diagnostic defaults: existing 512px canvas, five columns, middle sample per
clip and terminal death sample. The hidden-fill contact sheet is also current.

## Reproduce headless checks

Run from the worktree root. The source-derived rebuild records every ownership
move and redundant-layer coverage. Fill regeneration preserves manually changed
runtime paint by refusing bytes that differ from the previous generated output
or a recorded fresh rebuild.

```sh
python3 experiments/cutouts/gust_shrike/mq2/pipeline.py prepare-motion
python3 experiments/cutouts/gust_shrike/mq2/repair_ownership.py rebuild
python3 experiments/cutouts/gust_shrike/mq2/repair_fills.py
python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script experiments/cutouts/gust_shrike/mq2/probes/motion_samples.gd -- --case "$PWD/experiments/cutouts/gust_shrike/mq2/cutout.json" --output "$PWD/experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json"
python3 experiments/cutouts/gust_shrike/mq2/probes/proof.py --case experiments/cutouts/gust_shrike/mq2 --samples experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json
python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --cpu
python3 -m unittest discover -s tests -p 'test_gust_shrike_cutout.py' -v
python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/gust_shrike_cutout_test.gd
```

`repair_ownership.py trace` is an optional CPU diagnostic after a rebuild. It
records any remaining source-pixel islands with clip/frame evidence in the case
recipe; rerun rebuild/fill/sample after any recorded repair. It never changes a
motion value or deletes approved visible RGBA. The current trace has zero new
repairs. Fresh sample hashes are required by the real gates.

## Proof for the design owner

No windowed command has been run. These commands
produce the native rest, reel, verification, native motion gates and proof.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03
case_path="$PWD/experiments/cutouts/gust_shrike/mq2"
native_path="$PWD/experiments/cutouts/gust_shrike/native_v01"
python3 tools/visual_probe_runner.py "$case_path/probes/native_rest.gd" --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_path/probes/rest_contract.json" --result-manifest "$case_path/proof/native_rest_result.json" -- --case "$case_path/cutout.json"
python3 tools/cutout_workflow.py render "$case_path" --output "$native_path" --task-id rr-03
python3 tools/cutout_workflow.py verify-render "$case_path" --output "$native_path"
python3 "$case_path/probes/motion_gates.py" --case "$case_path" --capture-native "$native_path" --task-id rr-03
python3 "$case_path/probes/proof.py" --case "$case_path" --native-output "$native_path"
python3 "$case_path/pipeline.py" promote --native-output "$native_path"
python3 tools/visual_probe_runner.py tests/gust_shrike_cutout_probe.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 180 --proof-contract "$case_path/probes/production_contract.json" --result-manifest "$case_path/proof/production_result.json"
```

The native reel is `../native_v01/videos/cutout_review.mp4`. The production probe
captures idle, move, dive, talon_rake, hover, hit and death in combat at 1920×1080,
100% UI scale. Its result manifest reports the capture directory; pass that
location to `probes/pack_production.py` for `production_reel.mp4`. Promotion adds
project assets, so final whole-project `verify-render` requires a fresh native
output version afterward. Inspection/PCK commands are in the original README.

No new player-visible defaults were chosen. Diagnostic sample counts, canvas,
rr-02 solver/palette settings and connectivity/tie rules are recorded in the
recipes. No Blender run, art service, windowed proof, production promotion,
commit, publication, sub-agent or peer review was performed by this worker.
