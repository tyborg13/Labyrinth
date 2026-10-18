# Proof for the design owner

Run these full passes under the director lock, Bloomer then Wisp:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-05
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --creature shale_bloomer
bash experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh --creature lightning_wisp
```

Both CPU derivations now pass. The director's feedback 12 resolves the Wisp tail blocker by reporting approved paint separately; no paint was altered. These commands use the default/full stage, **not `--from-native`**, because native captures still need the round 11 texture update.

Order: derive → headless gates → native capture/verification and review MP4 → promotion → density adoption/processing → native rest rebake → rest recording/density seal → shared shadow cache and density audit → production captures/gates at 1920×1080, 100% UI scale. The script keeps its creature filter and resume flags, the `Path(...)` adoption fix, and `item.get('dir')` registry lookup. Inspection is separate.

Outputs:

| Creature | Native capture | Review MP4 | Production capture |
|---|---|---|---|
| Bloomer | `output/rr-05/shale-native/` | `output/rr-05/shale_bloomer_review.mp4` | `output/rr-05/shale-production/` |
| Wisp | `output/rr-05/wisp-native/` | `output/rr-05/lightning_wisp_review.mp4` | `output/rr-05/wisp-production/` |

The final visual acceptance remains the director watching both native MP4s. No worker windowed command was attempted; existing native captures were preserved.

## Headless proof commands

```sh
python3 tools/maquette_cutout_polish.py derive --case experiments/cutouts/shale_bloomer/mq3 --output output/rr-05/feedback12/shale-derive.json
python3 tools/maquette_cutout_polish.py derive --case experiments/cutouts/lightning_wisp/mq4 --output output/rr-05/feedback12/wisp-derive.json
python3 tools/maquette_cutout_polish.py gate --case experiments/cutouts/shale_bloomer/mq3 --samples experiments/cutouts/shale_bloomer/mq3/proof/continuity_samples.json --output output/rr-05/feedback12/shale-gates.json
python3 tools/maquette_cutout_polish.py gate --case experiments/cutouts/lightning_wisp/mq4 --samples experiments/cutouts/lightning_wisp/mq4/proof/continuity_samples.json --output output/rr-05/feedback12/wisp-gates.json
python3 -m unittest discover -s tests -p 'test_maquette_*.py' -v
python3 tools/godot_task_runner.py --task-id rr-05 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Derive samples Godot through the task runner and seals the exact input bindings. Saved gate inputs/reports/logs for this run are in `output/rr-05/feedback12/`.
