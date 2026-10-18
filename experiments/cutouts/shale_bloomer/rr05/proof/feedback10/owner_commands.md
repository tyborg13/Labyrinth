# Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rr-05`, under the director lock, Bloomer first:

```sh
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature shale_bloomer
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature lightning_wisp
```

Each command skips derive, runs headless gates, native review/verification and MP4, promotion, density adoption, rest rebake, rest/density sealing, shadow cache, density audit and production captures. Native probes use 1920×1080 at 100% UI scale. Inspection stays separate. The Wisp command currently stops at the unchanged 2% tie guard; resolve the documented guard-scope conflict before expecting it to reach adoption.

To re-check the retained captures without rendering or adoption:

```sh
python3 tools/maquette_cutout_polish.py gate --case experiments/cutouts/shale_bloomer/mq3 --samples output/rr-05/shale-native/pixel_samples.json --native output/rr-05/shale-native --output output/rr-05/feedback10/shale-native-gates.json
python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --native output/rr-05/shale-native --output output/rr-05/feedback10/shale-native-errors.json
python3 tools/maquette_cutout_polish.py gate --case experiments/cutouts/lightning_wisp/mq4 --samples output/rr-05/wisp-native/pixel_samples.json --native output/rr-05/wisp-native --output output/rr-05/feedback10/wisp-native-gates.json
python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --native output/rr-05/wisp-native --output output/rr-05/feedback10/wisp-native-errors.json
```
