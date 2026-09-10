# Shale Bloomer editable cutout

This case preserves `assets/art/enemies/bile_bloomer.png` as the accepted front painting. The stable enemy ID remains `bile_bloomer`; this is earth/mineral presentation only. Shale Burst opens/braces the crown and ejects shards outward; Shard Mark aims a bloom release at the resolved target. Roots perform grounded, substantial pulling steps. Shale Shell retains its existing restrained Stoneskin cue.

The changed surface is the combat actor: the player must see the impending release and its direction while choosing movement, cards or Pass through the existing pointer, keyboard and controller paths. Body, shadow, HP, intent and turn-clock geometry stay registered. Proof covers the native front/rear/reflected cycles, reduced motion, real actions/outcomes, player repositioning, multiple actors and death at 1920×1080/100% UI scale.

The root graph, crown and tendril owners belong to this creature. Idle uses a coordinated translation of the rigid upper body and anchored basal contacts. No Warden anatomy or mace motion is reused. Production reuses the common skeleton loader and enemy facing policy.

## Authoring provenance

`source/front_original.png` and `source/front_registered.png` are byte-identical to the accepted production painting. `source/generation_requests.json` records actual tool prompts and reference roles. Generated rear RGB paint is retained untouched; only explicit neutral-background ownership removes the baked checkerboard during whole-image registration. A second imagegen transparency correction was rejected because it again supplied RGB checkerboard and changed the painting. Background exclusion is a segmentation operation authorized by the coordinating task; no generated creature paint is synthesized or repainted outside imagegen.

The selected layouts are `front_r11_skinned.json` / `rear_r11_skinned.json`: 18 bones, 19 parts and three root meshes per view. The amber core, crown plates, rigid mineral trunk, five tendrils and three spreading root groups have distinct owners. The final owners keep the amber trunk rims out of the neighboring moving tendrils and separate the core from its crown edges. Root weight bands keep their upper attachments fixed to the trunk before bending into the rigid toes. Concealed generated calyx paint is visible only when the crown opens; concealed root paint fills moving basal joints. Neither donor adds paint to the neutral assembly.

`motion.gd` owns the editable pose sampler. Idle is a coordinated 1.2px upper-body bob over 1.8 seconds with anchored roots and no rotations. Root travel takes 0.9 seconds per 57.14 source pixels, with staggered 70% support intervals and at least two planted contacts. Burst takes 1.0 second; Mark takes 0.984 seconds, including 0.28 seconds of preparation before the unchanged earth effect. Shale Shell uses its existing Stoneskin cue without a new clip.

Use the maintained workflow from the repository root:

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/bile_bloomer/v01
python3 experiments/cutouts/bile_bloomer/v01/recipes/render_queued.py proof
python3 tools/cutout_workflow.py verify-render experiments/cutouts/bile_bloomer/v01 --output experiments/cutouts/bile_bloomer/v01/proof
python3 tools/cutout_workflow.py inspect experiments/cutouts/bile_bloomer/v01 --task-id shale-bloomer-editable-cutout-and-gameplay-animation
```

Choose a fresh output directory when rerendering an existing proof. The queue wrapper only lengthens shared-lease acquisition; native startup, execution and verification remain maintained by the existing pipeline. Keep one active or queued native capture for this task. `proof/front.tscn` and `proof/rear.tscn` are editable exports; rerender them after changing the sampler. Explicitly pass the fresh proof folder when promoting: `python3 experiments/cutouts/bile_bloomer/v01/recipes/promote_case.py proof`.

Production paths, current verification, the UI rubric and playable inspection are documented in [the runtime specification](../../../../spec/bile_bloomer_cutout_runtime.md). Earlier revision files retain the ownership history; only the layouts selected by `cutout.json` are current.
