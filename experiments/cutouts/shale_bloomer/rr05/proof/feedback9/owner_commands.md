# Proof for the design owner

Windowed rendering is unavailable in the worker sandbox. No native output, production adoption, promotion, MP4 or inspection launch was run by the worker. Accepted native outputs and MP4s remain in place. These scripts preserve derive → native review MP4s → promote → density adopt → rest rebake → production proof order; inspection is separate.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature shale_bloomer
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature lightning_wisp
```

`--from-adopt --creature CREATURE` remains available after native review and promotion. Resolve any blocking TODOs in results.json first; seam measurements themselves never stop the scripts.

Native review commands expanded:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/maquette_cutout_review.py --task-id rr-05 --case experiments/cutouts/shale_bloomer/mq3 --capture output/rr-05/shale-native --output output/rr-05/shale_bloomer_review.mp4 --render
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/maquette_cutout_review.py --task-id rr-05 --case experiments/cutouts/lightning_wisp/mq4 --capture output/rr-05/wisp-native --output output/rr-05/lightning_wisp_review.mp4 --render
```

Each review invokes `tools/visual_probe_runner.py` with `--no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080` and the creature’s `tests/maquette_cutout/*_render_contract.json`.

Native rest rebakes, in script order after promotion and density adoption:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only shale_bloomer_cutout
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only lightning_wisp
```

Production captures, after record-rests, seal-density, shadow-cache and density audit:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_production_contract.json --result-manifest output/rr-05/shale-production-result.json tests/maquette_cutout/production_capture.gd -- --type bile_bloomer --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/shale-production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05 && python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_production_contract.json --result-manifest output/rr-05/wisp-production-result.json tests/maquette_cutout/production_capture.gd -- --type lightning_wisp --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/wisp-production
```

Captures use 1920×1080, 100% UI scale. Fresh CPU/native agreement and visible seam judgement require these runs. No inspection command is embedded.
