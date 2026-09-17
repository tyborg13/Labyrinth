# Local-light density references

Native 1920×1080, 100% UI scale, Godot 4.6.1 Mobile/Metal on Apple M5 Pro.

`before/` contains the original runtime at `c527d0afae188de7855d09b0b2baafe4679268b0`; `after/` contains the ambient rebalance and removal of duplicate floor washes. Each folder has four PNGs and `density-capture.json` containing exact profile values, real encounter seeds, column counts, realism results and GPU shader samples.

- `02_columns_warm.png` and `02_columns_balanced.png`: seed 62001, coordinate (1,1), Hollow Grotto, two natural torch columns.
- `04_columns_warm.png` and `04_columns_balanced.png`: seed 62002, coordinate (1,1), Sealed Antechamber, four natural torch columns.

Each encounter retains its generated topology, three enemy types/spawns, starting player, terrain, loot and traps. No merchant props or overlapping actor footprints. These are production-generated initial snapshots using the standard fixture recipe, not a recorded playthrough. Wall-clock decorative particles can differ across invocations; do not claim full-frame exact equality.

Reproduce with `tests/combat_lighting_density_probe.gd` via `tools/visual_probe_runner.py`; see [the guide](../../../combat_art_treatment.md#density-rebalance-and-reconstruction) and [proof report](../ambient-rebalance-verification.md). The original runtime is preserved by its commit and the original fifteen-image reference set, not by adding a legacy renderer branch to production code.

These files are proof/reference artifacts, not runtime textures. `.gdignore` keeps them out of Godot's import scan.
