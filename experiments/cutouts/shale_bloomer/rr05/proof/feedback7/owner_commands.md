# Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rr-05` under the director lock. The worker did not run these windowed commands. The current strict headless gate stops the driver before rendering because the prescribed backing has recorded TODO_DESIGN failures; no native after success is claimed.

```sh
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature shale_bloomer
```

This is the one-pass resumable driver; do not separately run the expansion below as another pass. Its order is: fresh headless sampler/gate → native review MP4 → promote → density adopt → density processing → native rest rebake → record rests/seal → shared shadow cache/density audit → production native capture/gate. Default mode adds derive first. `--from-adopt` resumes at density adoption. Inspection is separate and has no launch here.

The driver's native review command is:

```sh
python3 tools/maquette_cutout_review.py --task-id rr-05 --case experiments/cutouts/shale_bloomer/mq3 --capture output/rr-05/shale-native --output output/rr-05/shale_bloomer_review.mp4 --render
```

The review tool itself runs the headless sampler and this exact native renderer probe at 1920x1080, 100% scale. It then verifies every feature, source transform, silhouette, native backing layer and shimmer frame before encoding the MP4:

```sh
python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_render_contract.json tests/maquette_cutout/native_capture.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/experiments/cutouts/shale_bloomer/mq3 --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/shale-native
```

After the driver's successful native review/promote/adopt stages, its windowed rest rebake and production commands are:

```sh
python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only shale_bloomer_cutout
python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_production_contract.json --result-manifest output/rr-05/shale-production-result.json tests/maquette_cutout/production_capture.gd -- --type bile_bloomer --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/shale-production
```

Both creatures have new authoring backing data; the Wisp's already accepted production/captures/video remain intact. Its equivalent driver is:

```sh
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature lightning_wisp
```

Its exact windowed commands inside that driver are:

```sh
python3 tools/maquette_cutout_review.py --task-id rr-05 --case experiments/cutouts/lightning_wisp/mq4 --capture output/rr-05/wisp-native --output output/rr-05/lightning_wisp_review.mp4 --render
python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_render_contract.json tests/maquette_cutout/native_capture.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/experiments/cutouts/lightning_wisp/mq4 --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/wisp-native
python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only lightning_wisp
python3 tools/visual_probe_runner.py --task-id rr-05 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_production_contract.json --result-manifest output/rr-05/wisp-production-result.json tests/maquette_cutout/production_capture.gd -- --type lightning_wisp --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-05/output/rr-05/wisp-production
```
