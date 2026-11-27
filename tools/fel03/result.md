# fel-03 baseline capture

The headless probe resumed all three fel-01 samples through production Continue. It observed four melee contacts, one baked fx-12 comparison, and eight enemy caption appearances. The native command below produces the images and measures the rendered caption durations.

## Acceptance criteria

| Requirement | Result |
| --- | --- |
| 1. Resume and play | All three Continue witnesses matched. Sample 01 played Quick Stab at (3, 5). Sample 02 had no playable melee with an adjacent enemy after checking the legal movement endpoints. Sample 03 played Sidestep Slash at (3, 7) through the production move-attack shortcut. Pass resolved the full enemy sequence in all three samples. The native probe includes fel-01's 90-frame and 2-second wait after its normal settle. |
| 2. Trail strips | The dry run observed three sweeps and one Tunnel Crawler `claw_marks` contact. All four were non-elemental. Each strip window had 25 consecutive samples at 60 Hz. Native export clamps a 480 × 360 crop at the contact midpoint, scales it 2× with nearest-neighbour, and writes the numbered sequence and five-column sheet. |
| 3. Baked comparisons | Quick Stab in sample 01 produced a natural fx-12 `steel_hit_front` stamp and a 25-sample window. The samples produced no natural fx-13 Block stamp. The fallback plays one fixture-owned Block card if neither comparison occurs. With fx-12 present, the fx-13 strip remains open under `TODO_DESIGN_fx13_when_only_fx12_occurs`. |
| 4. Caption frames | The probe found 3, 4, and 1 caption appearances in the three samples. Each first fully shown frame had a measured label rectangle and a 24 px font. The probe tracks the displayed duration through the next caption or dismissal. Native capture writes one full 1920 × 1080 PNG for each appearance. Dry-run timing through callouts can vary with process throughput. |
| 5. Output | Dry-run logged one line per strip and wrote no images. The native wrapper creates an ignored `captures/native.*/` directory and writes `index.md`, sheets, 25 cropped PNGs per strip, caption PNGs, and the visual proof manifest. |

## Checks

- `tools/fel03/native.sh --dry-run` exited 0 with `FEL03 DRY RUN PASS strips=5 captions=8`. Log at `/private/tmp/labyrinth_codex/fel03-final-dry-run.log`.
- `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/fel03-python.EwQaFo` selected the default group only, including the rules text lint. It exited 0 with `Ran 196 tests in 30.413s` and `OK`. The log and summary are in that output directory.
- Bash syntax and proof-contract JSON parsing passed. The full Godot suite was outside this proof.
- Godot logged the sandbox macOS certificate-access diagnostic. The Python runner could not update the shared Git timing cache in this sandbox. Both commands exited 0.

## Chosen defaults

- Probe camera uses the board's rendered unit-rectangle centers, with tile centers as a fallback for unavailable unit geometry. Baked comparisons are centered on the visible front stamp.
- Sheet annotations use the engine's existing label font at 20 px in a 28 px header band.
- The probe allows 5 seconds of frames for presentation readiness and detached turn-order settling, and 30 seconds of samples for each fight. The launcher has a 180-second process timeout. The synthetic dry draw runs at process priority 1000 after the game updates.

## Proof for the design owner

Run with macOS window-server access.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-03 && tools/fel03/native.sh
```

Open the printed `tools/fel03/captures/native.*/index.md` to inspect the frame sequences, sheets, and captions. The wrapper uses `tools/visual_probe_runner.py` with the fel-03 proof contract at 1920 × 1080 and 100% UI scale. Native proof remains unrun in this sandbox, so no capture directory or PNG is reported as observed.
