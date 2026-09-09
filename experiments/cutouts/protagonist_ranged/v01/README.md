# Protagonist offhand actions — v01

Seeded with `seed-protagonist` from local master `6640106ac621` (approved pass-nine paint, gait, idle, and sword motion). This is the initial authoring case for `cast` and `shoot`, preserved with its proof. The user requested a crossbow about three times larger; **v02 supersedes this version for production**.

The user's follow-up explicitly requested lifting the arm straight out instead of bending the elbow. Both clips reach almost the complete projected arm length (the raised segments have a direction dot product above 0.99). The front arm reaches across the chest; the rear casting hand reaches clear of the cloak, and the rear shooting arm reaches forward behind the body so its crossbow emerges beside the far shoulder. The rear arm's resting 33px projection is shortened beneath the cloak; extension reveals its near mate's approximately 53px reach while preserving sleeve width and a rigid glove. Cloak-off proof is required to judge that projection change.

All 21 existing joints and original paint remain. `weapon_l` is one additional rigid attachment, registered in the offhand glove. The 42×27 front and 42×32 rear crossbow drawings have independently painted viewpoints, muted walnut/leather/steel, and the same dark pixel contours as the protagonist. Grip and muzzle landmarks are in each layout's `offhand_attachment`; original generator outputs, exact prompts, and the deterministic registration recipe are under `source/`. There is no live inventory or balance change.

The clips describe a 200ms straight-arm preparation, existing effect release/travel, and recovery. `cast` previews the 720ms fire effect for 920ms total; `shoot` previews the 240ms default effect for 440ms total. Other elements retain their own original clocks and use the same authored pose phases. The small hand charge is drawn by the real board during preparation, and existing elemental FX start from the hand when the effect clock begins. The case reel is a skeletal/art study; the gameplay probe proves charge and actual card routing.

`source/accepted_motion.gd` retains the exact production sampler for differential regression checks. Original idle/walk/attack transforms are compared at 25 phases in each facing. The baseline art protection check passed before the intentional addition of attachment layouts; final validation permits those two declared layout additions. Existing rest silhouettes are unchanged because the crossbow is hidden at rest.

Proof commands (run from the isolated task worktree):

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/protagonist_ranged/v01
python3 tools/cutout_workflow.py render experiments/cutouts/protagonist_ranged/v01 --output /private/tmp/protagonist-ranged-case-final --task-id protagonist-spellcast-and-offhand-crossbow-animations
python3 tools/cutout_workflow.py verify-render experiments/cutouts/protagonist_ranged/v01 --output /private/tmp/protagonist-ranged-case-final
python3 tools/cutout_workflow.py inspect experiments/cutouts/protagonist_ranged/v01 --task-id protagonist-spellcast-and-offhand-crossbow-animations
```
