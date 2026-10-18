# Proof for the design owner

Run under the director lock from this worktree. These are **full passes**: the textures changed, so the old native captures cannot prove this round. No windowed command was attempted by the worker. Existing captures and MP4s were preserved.

Bloomer:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --creature shale_bloomer
```

Wisp, after resolving `TODO_DESIGN_exposed_hidden_lightning_wisp_tail`:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --creature lightning_wisp
```

The Wisp command currently stops at the new blocking CPU material gate. It must not be bypassed. The script retains `--from-native` and `--from-adopt` for future resumes, but neither is an appropriate starting point after this texture derivation.

Order: derive → headless pixel/material gates → native review captures and verification → review MP4 → promotion → density adoption → density processing → native rest rebake → rest recording/density seal → shared shadow cache and density check → production captures/gates. Registry lookup retains `item.get('dir')`; the adoption heredoc passes `Path` to `read_json`. Inspection is separate.

Expected native/review outputs:

- `output/rr-05/shale-native/`, `output/rr-05/shale_bloomer_review.mp4`
- `output/rr-05/wisp-native/`, `output/rr-05/lightning_wisp_review.mp4`
- `output/rr-05/shale-production/`, `output/rr-05/shale-production-result.json`, `output/rr-05/shale-production-gates.json`
- `output/rr-05/wisp-production/`, `output/rr-05/wisp-production-result.json`, `output/rr-05/wisp-production-gates.json`

Review and production captures use the existing 1920×1080 / 100% contracts. Native verification still enforces exact tie candidates, strict non-ties and held shimmer 0. The director judges seams in the new MP4s.

## Reproduce the CPU comparison

The before-case snapshot and old native sample matrices remain in untracked output. This command composes approved textures headlessly; it does not claim native-renderer proof:

```sh
PYTHONPATH=tools python3 -m maquette_motion.material_proof \
  --before-case output/rr-05/feedback11/before-case \
  --after-case experiments/cutouts/shale_bloomer/mq3 \
  --before-samples output/rr-05/shale-native/pixel_samples.json \
  --after-samples output/rr-05/feedback11/shale-pixels.json \
  --crops experiments/cutouts/shale_bloomer/rr05/proof/feedback11/cpu_crops.json \
  --output output/rr-05/feedback11/cpu-evidence
```

If the director's fresh native pass replaces the old samples, use the preserved matching sample file from `output/rr-05/feedback11/before-case/proof/continuity_samples.json` for the before stage. Runtime derivation has no dependency on either output snapshot.
