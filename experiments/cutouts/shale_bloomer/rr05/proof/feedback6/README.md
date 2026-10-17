# rr-05 feedback 6 — support bleed and adoption resume

Bloomer remains blocked by the strict silhouette gate. The generated support adds **1,376 texels** across **242 sampled joints** (derived margins **5–88 source pixels**). Every one of its 71 painted nodes remains one eight-connected component; rest reconstruction remains **0 changed RGBA pixels in both views**. All 1,008 poses have zero detached pixels. Enclosed-hole failures decreased from 504 poses / 186 px maximum to **451 poses / 172 px maximum**. This is not a complete silhouette fix or an accepted production handoff.

## Requirement results

1. **Authorized support bleed:** `bleed.py` derives each joint margin as `ceil(maximum sampled separation) + 1`. Donors use exact Euclidean nearest-edge RGBA replication, with stable source-coordinate ties. New support occupies only a higher neighbour’s rest alpha within the approved rest union. Feature masks cannot supply or receive new support. `seam_support.py` selects connected support for actual seam gaps and rejects additions that enclose another gap. Hidden-fill provenance records this policy and both tool hashes. [Before/after by clip](before_after.md).
2. **Crop expansion fix:** a hidden-only bone used its changing texture-crop corner as the snapping reference. The alternative donor trial preserved rest but acquired 14 detached pixels after actual Godot resampling. A fixed `presentation_anchor`, taken from the pre-bleed source crop, now keeps that bone’s source affine fixed as storage bounds grow. The regression pads the real front `root_stem_l` crop by 2 transparent source pixels and compares all 504 actual Godot front poses. Before: `1.0000038146972017 not less than or equal to 0.0001`. After: PASS at the unchanged tolerance. No extra motion channel or bone was introduced.
3. **Conditional motion edit:** applied exactly `idle.tendril_high_r.raise_deg` `(0.5, 5) → (0.5, 4)`. It is recorded in the Bloomer’s `director_amendments.json`, applied to its local director copy and compiled data, and independently checked against the unchanged shared director source. The compiler and oracle validate every other field. Wisp’s source, case and promoted files remain untouched. The early front idle 0012 pose still quantizes to 3°; the four connected pixels `(319,291)` through `(319,294)` remain unfillable. [Key/matrix evidence](amendment_evidence.json).
4. **Remaining design limits:** [53 certificates](TODO_DESIGN.json), grouped in [TODO summary](TODO_summary.md), give exact view, clip, frame, phase, coordinates, rim nodes, bone channels and authored key arrays. Each certificate allows every painted bone the entire opaque rest silhouette, a more generous domain than authorized bleed, and still finds a connected gap of at least 2 pixels. The other failing seams do not claim this impossibility proof. No other amplitude or gate tolerance was changed. Promotion remains blocked.
5. **Adoption script:** the heredoc now passes `Path(...)` to `read_json`. `--from-adopt` skips derives, headless/native reviews and promote, then runs adoption → density process → native rest rebake → record/seal → shared shadow/density audit → selected production capture. The existing `--from-native` and creature filters remain. Inspection is separate. The heredoc also marks copied feature-mask PNGs with the registry’s existing `never_drawn` reference category; painted feature crops remain registered and adopted. The regression executes the real heredoc with temporary layouts and a stub density module: it reproduced the supplied AttributeError before the fix and passes after. Separate command stubs test stage order and creature isolation.
6. **Feature/shimmer preservation:** [Per-feature results](features.md) and [raw feature records](features.json) report exact pixels, one painted node, owner bone and poses for every view, including protected occlusion reasons. [Shimmer numbers](shimmer.json) compare continuous presentation with stepped presentation on the same final paint. CPU residuals after stepping are 0 held / 0 boundary pixels for both creatures. Retained Wisp native run 4 has 0 held / 15 boundary residual pixels, maximum fraction 0.000498381, below the unchanged 0.01 limit. Its 750 native poses have zero detached pixels and new holes. Wisp’s 7,875 node poses are bit-identical to the pre-change runtime: [equivalence report](wisp_runtime_equivalence.json).

## Verification

Exact commands, exit codes, result lines and logs are recorded in [verification.json](verification.json) after the final run. Logs are under `output/rr-05/feedback6/`. Initial diagnostic failures and superseded checks remain in `output/rr-05/feedback6/initial/`; `crop_anchor_before.log` and `adoption_before.log` retain the two reproduced regressions. The initial pixel suite’s stale-input failure was caused by changing a proof-bound helper during that run; the frozen-source rerun retains the assertion.

Observed final result lines:

- Bloomer: `MAQUETTE PIXEL GATES: FAIL (504 errors)` — 451 hole poses plus 53 TODO certificates. Wisp: `MAQUETTE PIXEL GATES: PASS (0 errors)`.
- `MAQUETTE CUTOUT: PASS (22130 checks, 0 failures; headless logic only)`; `MAQUETTE INTEGRATION: PASS (0 failures)`; both authored-motion gates and both native-probe parse checks PASS.
- Pixel suite: `Ran 13 tests in 136.616s` / `OK`; semantic suite: `Ran 8 tests in 59.707s` / `OK`; native raster 3, silhouette 6 and bleed 4 tests / `OK`.
- Updated adoption heredoc and command-order tests, after the reference-mask fix: `Ran 5 tests in 1.881s` / `OK`.
- Crop regression: `MAQUETTE CROP ANCHOR: PASS (504 front poses; maximum source-affine residual 0.000027135)`, versus 1.0000038146972017 before, with tolerance unchanged at 0.0001.
- Full Godot initial run: outer timeout after 900 seconds, exit 124, no final test result. Reporting-grace retry: `TEST RESULT: FAIL (2 failure(s))`, exit 1: `Program sub-suite failed: section_map_v2_test (exit 124)` (23 seconds remained), then `Full suite exceeded its 15 minute budget before en01_enemies_test`. Its internal budget was not changed. All seven interrupted/unattempted programs subsequently passed independently at the existing 180-second per-program limit; section map reports `0 failures (64 seeds x 6 sections)`.
- Full Python: `Ran 649 tests in 705.551s` / `FAILED (failures=24, skipped=61)`, exit 1. [Exact failure inventory](python_failures.json): 19 Wisp source/output size/alpha subtests, four density/coverage/rest assertions, and the identity assertion for its two promoted rest pixel digests. They reflect the director’s promote-before-adopt state. No assertion or live adoption data was rewritten. The later mask-reference code fix was verified by the five-test heredoc suite.
- `GAOLER REBUILD: PASS (882 files)`.
- `FINAL PRESERVATION/CLOSURE: PASS`: 12 supplied feature input files, 7,008 Wisp case/production/capture/video files, and 25,376 original Bloomer capture/video files unchanged. Both case baselines, fresh sampler bindings, rest identity and all connected-part checks PASS. [Preservation record](preservation.json).
- `DIAGNOSTIC DISK HYGIENE: PASS`: 176,290,467 bytes removed; a compact pre-bleed seed cache and compressed diagnostic matrices remain. Original director captures/videos were retained. [Cleanup record](scratch_cleanup.json).
- `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`; `git diff --check` and `bash -n` PASS.

CPU diagnostic images (not native captures):

- `output/rr-05/feedback6/cpu-after/front_idle_0012.png`
- `output/rr-05/feedback6/cpu-after/front_move_0019.png`

Bloomer native after remains pending. The original Bloomer captures and 1,212-frame MP4 remain in place. Director Wisp run 4 remains at `output/rr-05/wisp-native` and `output/rr-05/lightning_wisp_review.mp4` (918 frames). The worker ran no windowed command, promote, density adoption or production rest rebake.

## Files changed in this round

- `tools/maquette_motion/{bleed,seam_support}.py`: derived joint domains, nearest-edge replication and connected seam support.
- `scripts/maquette_cutout_runtime/pixel_presentation.gd`, `tools/maquette_motion/pixels.py`, `tests/maquette_cutout/pixel_runtime_suite.gd`: fixed source anchors and independent transform checks.
- `tools/maquette_motion/{continuity,continuity_limits,contract,gates}.py`, `tools/maquette_cutout{_polish,_build}.py`, `tests/maquette_cutout/proof_inputs.gd`: provenance, all unfillable certificates, validated case-local director amendment and bindings.
- Bloomer generated hidden crops, layouts, local director/compiled data, amendment, proof and baseline. The shared director data and supplied feature declarations/masks were not edited.
- `proof_for_design_owner.sh`, `tests/test_maquette_{owner_proof,bleed,pixel_polish}.py`, `tests/test_semantic_maquette_motion.py`: resume flag, Path regression, support and crop tests, exact authorized edit check; semantic probes now use task id rr-05.
- This evidence and the rr-05 overview. Earlier unit changes are listed in the feedback 4 handoff. Wisp production changes in Git belong to the director’s run 4 promote.

## Proof for the design owner

Wisp can resume after its successful native review and promote:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-adopt --creature lightning_wisp
```

Bloomer’s requested command is below. It currently stops at the strict headless gate; resolve its remaining design limits before taking the director lock for a complete run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature shale_bloomer
```

The script is the exact native review MP4 → promote → density adopt → native rest rebake → production capture sequence. Windowed proof uses the existing 1920×1080 / 100% contracts. No inspection launch is included.

## Chosen defaults and open issues

No new player-facing default was chosen. Diagnostic archives use the named compression level 9. Joint margins and the sole motion edit come from the director’s decision. Non-player fixtures use `CROP_PADDING_SOURCE_PX = 2`, `FIXTURE_SEPARATION_PX = 3`, fixed test RGBA donor colours and synthetic mask geometry in their tests; command stubs retain `COMMAND_STUB_TIMEOUT_SECONDS = 10`. Nearest-donor ties use stable source row/column order. Existing proof fields and thresholds are unchanged. The Godot retry uses 60 seconds of outer reporting grace while retaining the internal 900-second assertion. [All named proof/fixture/watchdog values](chosen_defaults.json).

Open issues: the full Godot 900-second budget failure and Python’s pending Wisp-adoption failures; 451 Bloomer poses still fail enclosed holes, including the 53 certified TODO_DESIGN poses; further seam work; fresh Bloomer native verification, review MP4 and production adoption; Wisp’s owner-only stages after promote. All changes remain uncommitted. No peer review, signoff, task queue edit or publication operation was performed.
