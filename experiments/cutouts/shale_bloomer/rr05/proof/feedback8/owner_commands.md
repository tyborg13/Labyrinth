# Proof for the design owner

The headless hard gates currently fail; the driver deliberately stops before native review while TODO_DESIGN remains. No tolerance or acceptance bypass was added. The director’s requested command, after resolving the reported cases:

```sh
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --from-native --creature shale_bloomer
```

Wisp uses the same command with `--creature lightning_wisp`; `--from-adopt` remains supported. No inspection launch is included.

The driver retains derive → headless acceptance → native review MP4 → promote → density adoption → native rest rebake → production captures. Native capture produces `seam_frames.json`, including independent parts/seams layers, native rest/interior reference masks, and the actual body/reference matrices in every pose. The gate validates coverage, hashes, runtime/source closure and recomposed native alpha before measuring tears/protrusion. Features and held/boundary shimmer retain their existing tolerances.

Exact native review commands (each internally invokes the named headless sampler and 1920×1080 visual_probe_runner contract):

```sh
python3 tools/maquette_cutout_review.py --task-id rr-05 --case experiments/cutouts/shale_bloomer/mq3 --capture output/rr-05/shale-native --output output/rr-05/shale_bloomer_review.mp4 --render
python3 tools/maquette_cutout_review.py --task-id rr-05 --case experiments/cutouts/lightning_wisp/mq4 --capture output/rr-05/wisp-native --output output/rr-05/lightning_wisp_review.mp4 --render
```

These are not worker-run commands. The existing accepted captures/videos and Wisp production adoption remain intact. No fresh native-after results are claimed. Full expanded production commands are in `../feedback7/owner_commands.md`; the executable driver is authoritative and has no inspection launch.
