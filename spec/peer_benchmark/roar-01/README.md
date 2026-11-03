# roar-01 implementation and director proof

`dragon_arrival.gd` accumulates process delta for the 1.90-second opening and its 0.40-second cue. It shares game time with timers, music, rumble and the movie writer. Cancellation and completion clear the original actor's override and restore ordinary idle facing. The front override is installed before the first combat board submission. Mirror selection uses screen x, including the dragon footprint center. No combat state, save, RNG, sound asset or cue data changes.

The director's decisions remain: authored envelope keys, snap beginning at 0.40 seconds and peaking at 0.513 seconds, and folded Tharokh wings. Reduced motion retains the front pose and suppresses tremble/rumble. First-action sound suppression and area-attack roar routing remain intact.

## Feedback 1 changes and joint limits

Tharokh's tail retains its chest-relative bind. Vyraketh's root-bound tail follows the trunk. Iskaldra raises the pelvis/trunk together, retaining the planted hind supports; suspended foreclaws follow their body. Zekarion's hind roots/tail follow the torso. Vaeloryx hovers. Noctyrax's wing signs follow its existing `eclipse` clip.

Clamps are explicit `ROAR_CLAMPS` fields; missing fields retain the authored values. These are CPU-verified limits awaiting the director's native rerun, not a claim of native visual approval. The search retained the largest passing tested values at its documented steps; raster topology is discontinuous, so these are sampled limits, not a continuous optimum.

| Dragon | Every applied clamp |
| --- | --- |
| Tharokh | Gather back 1.50 → 1.00 px; down 2.00 → 1.00 px. |
| Vyraketh | Gather back 1.50 → 1.49 px. |
| Iskaldra | None. |
| Vaeloryx | Gather torso scale .66: back 1.50 → .99 px and down 2.00 → 1.32 px; roar lift 4.00 → 3.20 px; near-wing rotation ×.94 (fold .060 → .0564 rad, spread .240 → .2256 rad). |
| Noctyrax | Gather back 1.50 → 1.49 px; neck rotation/tremble ×.84 (gather .100 → .084, peak .300 → .252, tremble .020 → .0168 rad); head and both wing rotations ×.85 (head .120 → .102; near fold .060 → .051/spread .240 → .204; far fold .050 → .0425/spread .230 → .1955 rad). |
| Zekarion | Gather back 1.50 → 1.49 px; neck rotation/tremble ×.98 (gather .100 → .098, peak .300 → .294, tremble .020 → .0196 rad); lift 4.00 → 1.45 px; near-wing gather fold .060 → .045 rad. Its peak wing spread, head and jaw remain authored. |

The final Zekarion lift check rejected 1.49 px and passed 1.45 px; 1.50 and larger coarse samples also failed. Its gather fold check rejected ×.80 and passed ×.75. Tharokh's torso-axis grid used .1 px steps plus the authored/half-pixel boundaries; Vaeloryx's gather scale used .01 steps. Other local searches used .01 rotation-scale steps and .001 px back-translation steps. Candidate observations are retained under `/private/tmp/labyrinth_codex/roar-01/feedback1/`.

Sign/topology differences: Noctyrax's front `sign_x=-1` makes its wing spread signs differ from the other front rigs; its head raises with the opposite local sign to its neck. Vaeloryx/Zekarion wing signs do not follow rear-view `sx`. Iskaldra has a combined head/neck joint. Tharokh's death bow establishes positive front neck/head raise. Vyraketh's existing head raise supplies the positive front rotation registration.

There are no unresolved design placeholders.

## Seam tooling

`seam_check.py` reads PNG alpha only. It finds enclosed transparent pixels absent at phase 0, labels 8-connected components, requires area ≥12 px and length ≥10 px, and rejects components surviving a 5×5 min filter. Exterior transparency uses 4-connectivity. Alpha ≤16 counts as transparent. An additional transported body/tail join witness catches open attachment tears, which cannot be detected by an enclosed-hole metric alone.

`export_poses.gd` records actual production bone/sprite transforms headlessly. `cpu_render.py` uses the existing paint, repository skin/triangle raster, source-over alpha, five nearest-UV sampler variants and both independent-tie interval extremes. `cpu_check.py` takes the maximum roar count across those cases against the minimum approved-baseline maximum, and checks each painted part's thin-hole topology and attachment witness. An interval mask never replaces actual-sampler counts. Source fingerprints reject stale current proofs.

Historical transforms in `feedback1/poses-before.json` calibrate this CPU raster against the supplied native frames. Every native flagged pixel must lie in the conservative possible-gap interval, and CPU maximum counts must cover native counts. Calibration is not RGBA pixel parity: the diagnostic reports alpha interval outliers separately. The native rerun must recalibrate against its new frames and pass their actual count gate. Separate painted-part CPU topology is provenance evidence, not an anatomy judge.

Final CPU proof: `feedback1/cpu-accepted/`, with `feedback1/cpu-accepted-gate.json`. It contains the eight requested phases plus two tremble extrema and twenty approved peak poses. Approved clips include `crownfire`, `eclipse`, `call`, and the other rigs' wing/head/support peaks; Zekarion `hit` adds his strongest backward load and wing fold. Native contact sheets render these same baselines in the same run.

## Proof for the design owner

No windowed commands were attempted. These commands use source art, 1920×1080, 100% UI scale and the fixed 512×512 dragon viewport. Fresh output goes below `feedback1`, preserving the supplied captures. No inspection-fixture command is required by this brief; the director owns fixture preparation.

Contact sheets: all six dragons, front and mirrored front, eight requested phases and up to five approved baseline columns. Sheets are 6656×1024; all individual frames are 512×512. The contract requires 142 PNGs and each specific baseline pair.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/roar-01 && LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py spec/peer_benchmark/roar-01/contact_sheet_probe.gd --task-id roar-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --proof-contract spec/peer_benchmark/roar-01/contact_sheet_contract.json --result-manifest /Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1/contact-sheet-proof.json -- --output-dir=/Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1
```

Then the native seam gate, including baseline counts, current source provenance, CPU calibration, painted-part checks and the attachment witness:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/roar-01 && python3 spec/peer_benchmark/roar-01/seam_check.py --frames /Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1/contact_sheets --cpu /private/tmp/labyrinth_codex/roar-01/feedback1/cpu-accepted --output /Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1/native-seams.json
```

Six real-game opening movies with sound. All enter from the north, exposing front-to-rear idle recovery. The probe resizes Retina backing images before PNG save; the helper also scales its encoded MP4 to 1920×1080. Traces include game and wall elapsed time.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/roar-01 && for dragon in tharokh vyraketh iskaldra vaeloryx noctyrax zekarion; do
  LABYRINTH_CEL_LOOK=off python3 spec/peer_benchmark/director_tools/fight_opening_clip.py "$PWD" "/Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1/${dragon}_opening.mp4" --probe=spec/peer_benchmark/roar-01/fight_opening_probe.gd --proof-contract=spec/peer_benchmark/roar-01/opening_contract.json "--dragon=$dragon" --entry=north --output-dir=/Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1 || break
done
```

Expected captures below `/Users/borgerding/workspace/Labyrinth/output/roar-01/feedback1/`:

- `contact_sheets/<dragon>/{front,mirrored_front}_*.png`, including `*_baseline_<clip>_<phase>.png`; six `<dragon>_roar_contact_sheet.png` sheets; `contact_sheets/frames.json`.
- `<dragon>_opening.mp4`, `.log`, `.json`.
- `openings/<dragon>/<dragon>_{roar_peak,idle_after}.png` and `openings/<dragon>/opening.json`.

## Headless reproduction

No new permanent guards or Python test modules; the suite resource registry is unchanged. No full suites.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/roar-01
python3 tools/godot_task_runner.py --task-id roar-01 --stream -- godot --headless --path . --script spec/peer_benchmark/roar-01/pose_check.gd
for scale in 0.5 2.0; do
  python3 tools/godot_task_runner.py --task-id roar-01 --stream -- godot --headless --fixed-fps 60 --path . --script spec/peer_benchmark/roar-01/pose_check.gd -- "--time-scale=$scale" || break
done
python3 tools/godot_task_runner.py --task-id roar-01 --stream -- godot --headless --path . --script spec/peer_benchmark/roar-01/focused_checks.gd
python3 tools/program_suite_runner.py --task-id roar-01 --suite dragon_committed_patterns_test --suite dragon_feedback_mechanics_test --result-file /private/tmp/labyrinth_codex/roar-01/feedback1/programs-reproduction.json
LABYRINTH_TASK_ID=roar-01 python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/roar-01/feedback1/python-reproduction
python3 tools/godot_task_runner.py --task-id roar-01 --stream -- godot --headless --path . --script spec/peer_benchmark/roar-01/export_poses.gd -- --stress=1 --output=/private/tmp/labyrinth_codex/roar-01/feedback1/poses-reproduction.json
python3 spec/peer_benchmark/roar-01/cpu_render.py --poses /private/tmp/labyrinth_codex/roar-01/feedback1/poses-reproduction.json --output /private/tmp/labyrinth_codex/roar-01/feedback1/cpu-reproduction --ties
python3 spec/peer_benchmark/roar-01/cpu_check.py --cpu /private/tmp/labyrinth_codex/roar-01/feedback1/cpu-reproduction --output /private/tmp/labyrinth_codex/roar-01/feedback1/cpu-reproduction-gate.json
```

Original native diagnostic and historical raster calibration:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/roar-01
python3 spec/peer_benchmark/roar-01/seam_check.py --frames /Users/borgerding/workspace/Labyrinth/output/roar-01/contact_sheets --cpu /private/tmp/labyrinth_codex/roar-01/feedback1/cpu-before-calibrated --diagnostic-only --output /private/tmp/labyrinth_codex/roar-01/feedback1/native-reproduction.json
python3 spec/peer_benchmark/roar-01/cpu_check.py --cpu /private/tmp/labyrinth_codex/roar-01/feedback1/cpu-before-calibrated --native /Users/borgerding/workspace/Labyrinth/output/roar-01/contact_sheets --calibration-only --output /private/tmp/labyrinth_codex/roar-01/feedback1/calibration-reproduction.json
```

## Chosen defaults

Debug/proof only: dragon tile (3,3), hero tiles (1,3)/(3,1)/(1,1), inspector seed 7262026/loadout and north travel DOWN; 25×60-frame watchdog; preview 2.5 s/lead 1.2 s/tail 4 s (headless lead/preview .1 s); .001 px pose tolerance/.12 s timing tolerance; half/double-scale fixed-60-fps checks; movie fixed/max 60 fps; two-pixel canvas margin; contact-sheet organization and approved-clip sampling phases in `proof_data.gd`; source offset 128 and mirrored origin 383; seam alpha threshold 16, 4-connected exterior/8-connected gaps, UV-tie epsilon 1/128, one alpha quantization unit, one raster-edge pixel, 2048-triangle batches, 5×5 transported-join domain, and the two tremble-extremum phases; existing semantic image regions; runner timeouts 180/280/600 seconds for known workloads. Runtime numeric summation tolerance: `TIME_EPSILON_SECONDS=0.000001` (no perceptible timing change). No new dependencies.
