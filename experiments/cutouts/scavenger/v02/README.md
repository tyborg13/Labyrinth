# Scavenger articulated idle v02

The production painting remains unchanged. Seven registered paint parts share one continuous anatomical weight field across eleven joints. This keeps seams covered while the head, shoulders, elbows, hands, lantern and pack move differently; the root and feet stay planted.

Rebuild a fresh case from the repository:

```bash
python3 experiments/cutouts/scavenger/v02/recipes/articulate.py --output /private/tmp/scavenger-rebuilt
python3 tools/cutout_workflow.py validate /private/tmp/scavenger-rebuilt
```

`recipes/articulate.py` and `registration_v02.json` own this revision. The copied `build_case.py`, `front_skin.skin.json`, original `layouts/front.json` and `segmented` are retained v01 baseline sources, not the active authoring entry point. The active layout is `layouts/front_articulated.json`, active paint is `segmented_articulated`, and `motion.gd` is the production sampler. Runtime loads only the corresponding assets under `assets/units/scavenger_cutout` and `scripts/scavenger_cutout`.

Native review covers two full 1.8-second cycles, neutral/quarter/peak/recovery poses, joint metadata, saved-scene reload and a production-only non-editor export runtime. Small projected arm offsets preserve painted anatomy without requiring invented hidden surfaces.
