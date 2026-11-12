# perf-110 proof tools

These tools do not change gameplay or art. All Godot launches use the task runner;
pixels use the visual runner. No Git writes or branch changes are performed.

`gate.gd` inherits the read-only perf-109 headless whole driver. It records exact
consecutive draw inputs per instance and observes native visibility/topology
signals. Version 2 includes native Control transform/clip/rect inputs for tooltip
hosts. Legacy empty-tooltip observations are conservatively discounted, so they
cannot inflate gate eligibility. Anonymous Node2D script classes with custom `_draw` are conservatively
changed. `report.py` joins those observations to census redraw fields, excludes
startup and incomplete intervals, checks count coverage, and tests the gate.
A changed bone pose alone is not a Polygon2D command-buffer change: GPU skeleton
transforms update independently. Polygon topology, weights and bindings are in
the signature. Resource textures are the existing immutable cutout sources.

`run_ab.py` snapshots the candidate, verifies the saved baseline hashes, and
installs only the six recorded owned source files in serial A/B, B/A, A/B
pairs on seeds 84 and 85. It restores the exact candidate in `finally`, rejects
unexpected concurrent edits, and leaves all changes uncommitted. Do not edit
those files or run other engines concurrently with the measurements.
The final default is 96 decisions, because short smoke runs miss the humanoid
mesh workload. There is a 360-second headless replay cap and 420-second runner cap.
`source/{A,B}` and `sources.json` retain the exact measured source bytes/hashes.
`summarize_ab.py` reports each threshold literally, including failures.

`pose_oracle.gd` samples 592 poses across five humanoid adapters, both facings,
all their declared clips and repeated phases. It hashes submitted polygon/UV/topology/color buffers, transforms, tints and
texture pixels, and records visibility and depth. It is a buffer oracle, not pixel proof.
`focused_tests.gd` exercises redraw suppression and the existing affected health,
tooltip, cutout-gate and runtime suites. `--regression-only` and `--existing-only`
separate the new checks from existing suite assertions without modifying them.
The trigger probes isolate equal native Control assignments and Crawler bone
motion; they are diagnostics, not replacement tests.

## Owner pixel proof

`run_ab.py --capture` uses the saved baseline and current candidate to produce
four PNGs for each variant at 1920×1080, UI scale 1.0. Each board contains the
production hero plus one enemy (Crawler, then Hoarfrost Seer), mid-idle and
mid-attack, and a production segmented health widget during ghost drain.
No imported art is generated or changed. All placement/time constants in the
capture are proof-only. The fixture freezes processing and uses the board's
existing explicit presentation-time fields. `samples.json` records the exact
phases and ghost ranges. `proof_contract.json` validates size, presence and
nonempty render regions; only the owner's pixel diff can establish equality.

The `--native-census` owner mode invokes the unchanged census collector on
frozen A/B copies (the collector retains its historical perf-109 runner label).
It collects both seeds, warm cache, normal profile, 240 seconds or 96 decisions.
Neither owner mode is run by the sandboxed implementation engineer.

`--gate-summary` reuses an observed passing original-snapshot gate after a candidate-only refinement, verifies its recorded original source hashes and decision count, and records the reference. After the final takes, run `compare_states.gd` through the Godot task runner with `PERF110_AB_DIR` set, then run `summarize_ab.py`. The former compares decoded saved Variant state excluding wall-clock `run_stats.run_seconds` and normalizing randomized analytics run identity (retaining the combat ordinal and all raw differences); the latter retains raw decision logs and normalizes only frame timing and anonymous node numeric suffixes in UI paths.

`--resume` accepts only identical source hashes, retains completed takes, and writes retries to fresh directories. A valid candidate replay reached decision 90 at the original 240-second cap under a broader measured slowdown; the cap was raised to 360 seconds (420-second runner) for fixed-decision completion. Native collection retains its original 240-second cap. Incomplete takes are never compared.
