# rr-03 round 4 — review fixes, native density completion pending

Changes are uncommitted on `0c5faf1625106b633c5a4fdb2fb1084da03a558c`.
The protected r3 director source and case copy remain byte-identical at SHA-256
`88ed872a94968da8dbe075a160d1cc87b668689880f29edb16932c276b32b5f4`.
No authored motion, camera, source painting or maquette export was changed.

1. **Death expectations fixed.** The focused Godot test reads the current
   director file, verifies its compiled digest, and checks roll, lift and
   relative leg reach at every death key in both views. No obsolete 70-degree
   or 10px death expectation remains.
2. **Density registration and paint processing complete; native rests pending.**
   `gust_shrike_cutout` registers 46 paint parts and two derived rest PNGs,
   preserving the existing static fallback entries. All 48 untouched inputs
   were adopted. Both facing measurements prescribe native regrid 1.33;
   processing changes RGB in 27 production PNGs while preserving dimensions,
   alpha, transparent RGB and silhouette edges. The roster gate includes
   conditional cutouts and rejects the real roster with this registry entry
   removed. The two rest records require the native rebake below. They have
   deliberately not been certified from headless rendering. Until then the
   density check and full Python suite correctly fail, and `seal-density`
   refuses to refresh the production integration manifest.
3. **Shadow cache fixed for the current shipped rest.** The refresh includes
   the promoted front rest and both retained en-05 static sources; it verifies
   every unrelated entry and source digest remains equal. Integration sync
   now covers the promoted source and retained fallback rear. Both checks
   pass. Repeat the refresh after the native rest changes, as listed below.
4. **Signed motion contract added.** An oracle independent of the compiler
   projects the protected semantic values from the exported geometry. The
   sampler exposes the channel values actually used by production. The gate
   checks every key's presence, time, interpolation and signed value, and
   signed samples at every key and interval midpoint in both views. Existing
   angle/pixel/scale tolerances remain 1 degree / 0.5px / 0.002. Both reviewer
   mutations are compiled in disposable cases, resampled by Godot and rejected
   by the CPU gate: missing idle-tail hold at 0.4 and reversed tail projection.
5. **Per-action production coverage implemented; native pixels pending.**
   The real RunScene action callbacks use a probe frame clock so captures
   cannot miss short actions during PNG IO. Every action must have at least
   six distinct visible poses, increasing phases from 0 to 1, required contact
   or apex, and interior recovery. Move includes its apex and landing; Dive
   includes exact contact; talon rake includes 0.5; death includes its terminal
   pose. Native captures save the actual 512px rig texture alongside each
   1920x1080 board frame. Alpha-zero RGB is normalized before comparing hashes.
   Identical adjacent poses are omitted, then minimum coverage is checked.
   The packer independently checks phases, image sizes and decoded pose hashes.
   A large idle/global count, frozen pose hashes or missing contact cannot pass.
   The old v04 capture is rejected by the new validator.

Headless action coverage is **123 frames total**, including move 9, Dive 11,
talon rake 7, hover 13, hit 7 and death 18. These are transform observations,
not native pixel evidence; windowed deduplication can reduce these counts and
must still satisfy the same contract. Idle retains its original recording.

Changed files are grouped by the five findings:

- `tests/gust_shrike_cutout_test.gd`: source-bound motion expectations and four
  capture-contract regressions.
- `spec/assets/board_pixel_density/{registry.json,outputs.json,report.md,sources/}`,
  `spec/board_pixel_density.md`, production PNGs and
  `tests/test_board_pixel_density.py`: registration, immutable originals,
  derivations and conditional roster coverage. Case `pipeline.py seal-density`
  checks derivations/rest records before updating integration hashes.
- `tools/en05_refresh_shadow_cache.gd`, generated shadow cache and
  `tests/en05_integration_sync_test.gd`: additive cache refresh and sync checks.
- Case/runtime `motion.gd`, `probes/{motion_samples.gd,director_contract.py,motion_gates.py}`
  and `tests/test_gust_shrike_cutout.py`: sampled signed contract and actual
  mutation regressions. Refreshed case input closure, samples and CPU evidence.
- `tests/gust_shrike_cutout_probe.gd`,
  `tests/fixtures/gust_shrike_capture_scene.gd`,
  `tests/helpers/gust_shrike_capture_contract.gd`,
  `probes/{production_contract.json,production_coverage.py,pack_production.py}`:
  per-action real board capture, native pose evidence and encoding validation.

Observed verification:

- Focused Godot: **PASS, 82 checks, 0 failures**, headless logic only.
- Focused Python: **PASS, 17 tests in 2.266s**, including both resampled mutations.
- Motion sampler: **PASS, design_complete=true, 904 poses and 196 channel-time records**.
- CPU gates: **PASS, 904 frames**, zero detached specks, magenta, clipping or
  empty frames; signed contract and unchanged hidden-material limits pass.
- Exposure: **PASS, 16 requests, 0 unknown solos**.
- Production logic-only recorder: **PASS, 123 frames**; native proof pending.
- Shadow refresh and en-05 integration sync: **PASS**.
- Density suite: **47 tests, 1 failure**, exclusively missing two native rests.
- Full Python: **535 tests in 340.927s, 1 failure, 61 skipped**, exclusively the
  same missing rest records. Final conditional-roster regression passes separately.
- Full Godot: **PASS, 700.436 seconds (900-second budget)**, process exit 0.
- Packer synthetic contract: valid phase/image fixtures accepted and changed
  pose pixels rejected; this is not native proof. Old v04 capture: rejected.
- Protected inputs, unrelated density records, current sample hashes,
  case/runtime motion copies and structural validation with `--protect all`:
  **PASS**. Case front/rear rest identity remains exact. `git diff --check`: PASS.

Logs and the headless per-action phase list are in `proof/round4_*`.
Certificate, NumPy and resource-exit diagnostics are present in tool logs;
the test results above report actual failures separately. The full suites ran
before the final packer handling of old empty snapshots, proof-size declaration
and source-closure refresh; focused checks cover those final changes.

No new motion-design TODO or player-visible value was introduced. Capture-only
requirements are the requested six poses per action, existing 1920x1080/100%
board, existing 512px rig texture and existing 30fps idle clock. Prescribed
density treatment is the only production paint change. No Blender run, native
capture, promotion, commit, publication, sub-agent or peer review was performed.

## Proof for the design owner — native_v05

Complete density first. These commands update the production rest PNGs and
their recorded hashes; `seal-density` verifies the immutable case-to-source
chain and refreshes the existing integration manifest. Do not raw-promote the
case again: that would replace the prescribed density treatment with untreated
paint. Keep v04 intact. Run from this worktree and stop on any failure.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03
case_path="$PWD/experiments/cutouts/gust_shrike/mq2"
native_path="$PWD/experiments/cutouts/gust_shrike/native_v05"
python3 tools/visual_probe_runner.py tools/rebake_cutout_rests.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 255x255 --result-manifest "$case_path/proof/density_rest_result_v05.json" -- --only gust_shrike_cutout
python3 tools/process_board_density.py --record-rests --only gust_shrike_cutout
python3 "$case_path/pipeline.py" seal-density
python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tools/en05_refresh_shadow_cache.gd
python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/en05_integration_sync_test.gd
python3 tools/process_board_density.py --check
python3 tests/test_board_pixel_density.py
python3 tools/visual_probe_runner.py "$case_path/probes/native_rest.gd" --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_path/probes/rest_contract.json" --result-manifest "$case_path/proof/native_rest_result_v05.json" -- --case "$case_path/cutout.json"
python3 tools/cutout_workflow.py render "$case_path" --output "$native_path" --task-id rr-03
python3 tools/cutout_workflow.py verify-render "$case_path" --output "$native_path"
python3 "$case_path/probes/motion_gates.py" --case "$case_path" --capture-native "$native_path" --task-id rr-03
python3 "$case_path/probes/proof.py" --case "$case_path" --native-output "$native_path"
python3 tools/visual_probe_runner.py tests/gust_shrike_cutout_probe.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 512x512 --timeout 180 --proof-contract "$case_path/probes/production_contract.json" --result-manifest "$case_path/proof/production_result_v05.json"
```

Inspect `../native_v05/videos/cutout_review.mp4` and the production board frames.
The production result manifest lists the capture directory. Encode and validate
its actual timestamps with:

```sh
python3 "$case_path/probes/pack_production.py" <capture-directory>
```

Case rest/reel proof uses the unchanged approved source paint. Production proof
uses the prescribed density outputs; the density tests bind those outputs back
to the case sources and the native rebake binds their assembled rest.
