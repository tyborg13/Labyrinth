# rr-28 implementation handoff

All changes are uncommitted on `codex/rr-28`. Preservation is pinned to the supplied checkout, `370ab4b13b298b4a32bc1670f4c36916541850da`. No commit, push, merge, branch change, queue edit, reviewer, or windowed run was performed.

## Numbered requirements and task-contract acceptance

1. **Close every tear with own-piece continuations.** Seer has 25 coordinate copies (front 17, rear 8); Mimic has 36 (rear only). Each `gait_continuations` recipe declares its action `clips`. Shared recipes cover the mark/death runs. The builder replays nearest existing non-outline donors from the same logical piece; production playback copies the existing density-treated donor RGBA. Layouts, geometry, skin fields, motion, timing, source images and shared gates/thresholds are retained. The new tests cover all 31 original Seer pockets and all 85 Mimic pockets across its 73 failing frames. No tear requires an attachment or exemption.
2. **Density.** No shipped PNG changes. `--adopt --force-adopt` is therefore not applicable. Re-derived only `hoarfrost_seer_cutout` and `hollow_mimic_cutout`: `PROCESSED 168 file(s)` / `PROCESSED 44 file(s)`. Both `--only <id> --check` calls end `CHECK-OK`. Preservation proves all original PNG bytes unchanged, including rests, so a rest rebake is unnecessary for these copies.
3. **Capacitor shadow pin.** The check explicitly requires and exactly compares both Capacitor rest entries and their source hashes. Other figures' entries/hashes are outside its scope. The proof script extracts `HEAD` (or the explicit baseline override) before the shadow-cache refresh, instead of the pre-Capacitor historical revision. Regression fixtures remove other figures and corrupt/delete own records: only own corruption/deletion fails.
4. **Proof.** All headless proof below passes. The native-gate acceptance criterion remains pending the director's fresh windowed capture. No CPU output is labelled native acceptance. Existing 1920×1080 / 100% proof contracts and captures are used unchanged; the inspection fixture, commit and later peer review remain the design owner's work.

`native_baseline.json` in each rig's `rr28` folder re-derives the copied captures with canonical `native_errors(..., hole_details=...)`, with the original capture-manifest and gate hashes. Seer's baseline also had two stale headless-header errors; the new samples are refreshed. The Mimic's missing ignored full sample inventory was reconstructed before editing; both before/after raw-row digests match the committed rr-26 pose-identity record.

## Observed verification

```text
Ran 180 tests in 128.476s
OK
RR28 RUNTIME CONTINUATION TEXTURES: PASS (116 case/production clip-piece checks)
RR28 STRICT CENSUS SEER FRONT: PASS (467 frames; 0 pocket failures; 0 unmatched detached)
RR28 STRICT CENSUS SEER REAR: PASS (467 frames; 0 pocket failures; 0 unmatched detached)
RR28 STRICT CENSUS MIMIC FRONT: PASS (362 frames; 0 pocket failures; 0 unmatched detached)
RR28 STRICT CENSUS MIMIC REAR: PASS (362 frames; 0 pocket failures; 0 unmatched detached)
RR28 SEER POSE ROW IDENTITY: PASS (1258 raw rows)
RR28 SEER PAINT/REST/MOTION IDENTITY: PASS (353 protected files; 0 unexpected changes; exact rest composites)
RR28 MIMIC POSE ROW IDENTITY: PASS (1008 raw rows)
RR28 MIMIC PAINT/REST/MOTION IDENTITY: PASS (331 protected files; 0 unexpected changes; exact rest composites)
RR10 BONE/CUT GATES: PASS (0 errors)
RR20 SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH GATES: PASS (0 errors; both views)
RR17 SHADOW PRESERVATION: PASS (2 Capacitor records unchanged)
CHECK-OK
CHECK-OK
```

The separate pocket-delta check passes all 1,658 presented frames with **zero newly enclosed or split pockets, including 1px air**. It compares CPU support with and without these recipes, so a newly trapped gap cannot hide behind the canonical source-air classification. The census independently applies canonical source-space classification plus joint-tear detection and exact detached provenance. No historical exceptions are consumed.

Focused suite (including art identity), run with `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 LABYRINTH_TASK_ID=rr-28 PYTHONPATH=tests:tools`:

```sh
python3 -m unittest test_rr28_continuations test_rr28_shadow test_rr10_humanoid test_rr10_rear test_rr13_continuations test_rr20_cutout test_rr20_feedback2 test_rr20_rest_space test_rr17_feedback test_art_identity_gate -v
```

The full unrelated Godot/Python suites were not run: the unit brief explicitly requires focused tests only. Every Godot process, including those launched by Python tests, uses `godot_task_runner.py`. `sh -n` on the Capacitor proof script and `git diff --check` also pass. Logs contain the macOS certificate warning, the existing Mimic sampler resource-cleanup messages, and NumPy warnings in the art-identity suite; runner exits and the suite result are successful.

Reproducible headless commands, from this worktree:

```sh
python3 -B experiments/cutouts/hoarfrost_seer/rr28_build.py
python3 tools/godot_task_runner.py --task-id rr-28 --stream -- godot --headless --path . --script tests/rr10/samples.gd -- --case res://experiments/cutouts/hoarfrost_seer/rr10 --output res://experiments/cutouts/hoarfrost_seer/rr10/proof/samples.json
python3 tools/godot_task_runner.py --task-id rr-28 --stream -- godot --headless --path . --script tests/rr20/samples.gd -- --case res://experiments/cutouts/hollow_mimic/rr20 --output res://experiments/cutouts/hollow_mimic/rr20/proof/samples.json
python3 tools/godot_task_runner.py --task-id rr-28 --stream -- godot --headless --path . --script tests/rr28/continuations.gd
python3 -B experiments/cutouts/hoarfrost_seer/rr28_check.py census --rig seer
python3 -B experiments/cutouts/hoarfrost_seer/rr28_check.py census --rig mimic
python3 -B experiments/cutouts/hoarfrost_seer/rr28_pockets.py --rig seer
python3 -B experiments/cutouts/hoarfrost_seer/rr28_pockets.py --rig mimic
python3 -B experiments/cutouts/hoarfrost_seer/rr28_check.py preservation --rig seer --before /private/tmp/labyrinth_codex/rr-28/seer/baseline_samples.json
python3 -B experiments/cutouts/hoarfrost_seer/rr28_check.py preservation --rig mimic --before /private/tmp/labyrinth_codex/rr-28/mimic/baseline_samples.json
```

Complete command logs and retained before inventories: `/private/tmp/labyrinth_codex/rr-28/`. Full hash-bound census records: each case's `proof/logs/rr28/census.full.json`. The compact census/preservation/pocket-delta reports and replay recipes are in the two `rr28/` folders.

## Inspected diagnostic capture paths

These sheets show the supplied native baseline beside the current **CPU estimate**. They were regenerated and inspected after the final recipes:

- `experiments/cutouts/hoarfrost_seer/rr10/proof/logs/rr28/joint_crops.png` (31 pockets).
- `experiments/cutouts/hollow_mimic/rr20/proof/logs/rr28/joint_crops.png` (85 pockets).

Regenerate with `rr28_crops.py --rig seer|mimic --capture /private/tmp/labyrinth_codex/rr28_evidence/<rig>_native --output <case>/proof/logs/rr28`. The companion `joint_crops.json` binds each sheet to the original manifest. These are diagnostic artifacts, not new game art.

## Proof for the design owner

No windowed command was attempted; this sandbox has no window server. Execute the existing sequences in the prepared worktree. Their scripts enforce the original proof contracts and resolution. The density stages are unnecessary for unchanged PNGs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-28 && (
  set -e
  for stage in rest native idle production sheets review; do
    LABYRINTH_TASK_ID=rr-28 sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh "$stage"
    LABYRINTH_TASK_ID=rr-28 sh experiments/cutouts/hollow_mimic/proof.sh "$stage"
  done
  LABYRINTH_TASK_ID=rr-28 sh experiments/cutouts/storm_capacitor/rr17_proof.sh
)
```

Seer outputs: `experiments/cutouts/hoarfrost_seer/rr10/proof/{native_rest,native,idle_native,production_native,contact_sheets,hoarfrost_seer_review.mp4}`. Mimic outputs: `experiments/cutouts/hollow_mimic/rr20/proof/{native_rest,native,idle_native,production_native,contact_sheets,hollow_mimic_review.mp4}`. Capacitor outputs: `experiments/cutouts/storm_capacitor/mq5/proof/{native_rest,native,production_native,storm_capacitor_review.mp4}`. No `inspection_fixture.py` command is requested by this unit brief.

## TODO_DESIGN placeholders, chosen defaults, open issues

- **TODO_DESIGN:** none added; no missing player-facing design decisions.
- **Chosen defaults (proof only):** `PROOF_TIMEOUT_SECONDS=90`, `PROOF_PHASE=0.0`, `PROGRESS_INTERVAL_FRAMES=50`; crop margin 14 source pixels, nearest zoom 4, 4 sheet columns, 32px labels, 8px gap, background RGB `(38,38,38)`. No player-facing values were chosen.
- **Open issue:** fresh native acceptance and production/reel inspection await the director. No unclosed tear, new CPU pocket, unmatched component, unexpected protected-file change, or failing focused test remains.

## Files changed

- `assets/units/hoarfrost_seer_cutout/front.json`
- `assets/units/hoarfrost_seer_cutout/humanoid_v2/front.json`
- `assets/units/hoarfrost_seer_cutout/humanoid_v2/rear.json`
- `assets/units/hoarfrost_seer_cutout/integration.json`
- `assets/units/hoarfrost_seer_cutout/rear.json`
- `assets/units/hollow_mimic_cutout/integration.json`
- `assets/units/hollow_mimic_cutout/rear.json`
- `experiments/cutouts/hoarfrost_seer/rr10/layouts/front.json`
- `experiments/cutouts/hoarfrost_seer/rr10/layouts/rear.json`
- `experiments/cutouts/hoarfrost_seer/rr10/proof/samples.json`
- `experiments/cutouts/hoarfrost_seer/rr28/README.md`
- `experiments/cutouts/hoarfrost_seer/rr28/census.json`
- `experiments/cutouts/hoarfrost_seer/rr28/joint_continuations.json`
- `experiments/cutouts/hoarfrost_seer/rr28/native_baseline.json`
- `experiments/cutouts/hoarfrost_seer/rr28/pocket_delta.json`
- `experiments/cutouts/hoarfrost_seer/rr28/preservation.json`
- `experiments/cutouts/hoarfrost_seer/rr28_build.py`
- `experiments/cutouts/hoarfrost_seer/rr28_check.py`
- `experiments/cutouts/hoarfrost_seer/rr28_crops.py`
- `experiments/cutouts/hoarfrost_seer/rr28_pockets.py`
- `experiments/cutouts/hollow_mimic/rr20/layouts/rear.json`
- `experiments/cutouts/hollow_mimic/rr20/proof/samples.json`
- `experiments/cutouts/hollow_mimic/rr28/census.json`
- `experiments/cutouts/hollow_mimic/rr28/joint_continuations.json`
- `experiments/cutouts/hollow_mimic/rr28/native_baseline.json`
- `experiments/cutouts/hollow_mimic/rr28/pocket_delta.json`
- `experiments/cutouts/hollow_mimic/rr28/preservation.json`
- `experiments/cutouts/storm_capacitor/rr17_proof.sh`
- `experiments/cutouts/storm_capacitor/rr17_shadow_check.gd`
- `tests/rr28/continuations.gd`
- `tests/rr28/shadow_fixture.gd`
- `tests/test_rr20_feedback2.py`
- `tests/test_rr28_continuations.py`
- `tests/test_rr28_shadow.py`
