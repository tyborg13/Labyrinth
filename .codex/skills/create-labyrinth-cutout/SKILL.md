---
name: create-labyrinth-cutout
description: Build, animate, refine, or extend editable 2D cutout characters for Escape the Umbra, including enemy rigs and character or equipment variants. Use for segmented art and skeletal animation, not ordinary static portraits or sprite-sheet-only work.
---

# Create a Labyrinth character cutout

Use the repository's `$parallel-labyrinth-task` workflow. The maintained toolkit is `tools/cutout_workflow.py`; the [case format and commands](../../../spec/cutout_workflow.md) are the executable authoring contract. Work in a fresh case/version under `experiments/cutouts/<character>/<version>/` or an explicitly isolated temporary output directory.

## Pick the starting point

| Request | Start | Read |
| --- | --- | --- |
| New enemy/creature cutout | `init`; define that creature's own joint graph and registered art | [Art and rig construction](references/art-and-rig.md) |
| Protagonist animation or visual variant | `seed-protagonist`; it copies current approved production inputs and playback timing | [Motion and integration](references/motion-and-integration.md) |
| Extend an existing case | `fork`; keep its original case and proof | The reference for the changed surface |
| New equipment drawing on a rig | Fork, register the replacement, then `replace-part` for rigid pieces or `skin` for deforming pieces | [Art and rig construction](references/art-and-rig.md), equipment section |
| Connect a finished cutout to actual combat | Start from its reviewed case | [Motion and integration](references/motion-and-integration.md), integration section |

For enemy mechanics/roster work, also use `$create-labyrinth-enemy`. Use `$create-labyrinth-equipment` for gear data/equip rules and `$create-labyrinth-ui` for player-facing routing/feedback. An art-only case does not imply changing combat balance, inventory rules or the whole enemy rendering architecture.

## Current baseline and useful boundaries

The accepted protagonist is pass nine in `assets/units/protagonist_cutout/` and `scripts/protagonist_cutout/`. Its design/proof is in `spec/protagonist_cutout_runtime.md`. Start variants there, not from the older saved rigs in `experiments/protagonist_2d`.

Historical builders such as `registered_assets.py`, `seam_assets.py` and the pass-nine refinement script write their particular old revision. Read them when investigating a recipe; do not run them to initialize a new task or assume their poses/proportions are current. The [evidence map](references/art-and-rig.md#retained-evidence) points to specific useful examples.

The protagonist's 21 bones, two views, long-stride gait, front idle default and sword timing are character-specific choices. New anatomy needs its own joints, support surfaces, viewpoints and clips. Mirroring supplies reflected painted views; it does not invent unseen anatomy or rotate a foot in 3D.

## Build and judge the result

1. Establish the requested identity, views, actions and integration scope. Record native source landmarks, hidden joint coverage and the intended contact/recovery timing before tuning motion.
2. Save actual source paint, generation requests and manual ownership/registration recipes with the case. Use `$imagegen` when new or corrected raster paint is needed. Inspect the complete assembly at one shared native scale before investing in full animation proof.
3. Use `segment` for explicit pixel ownership, `skin` for a shared source-space weight field, and `validate` for structural contracts. Preserve an animation-only variant's art with `validate --protect art`. Numeric passes do not establish correct anatomy or style.
4. Use `render` for real-renderer frames, complete fixed-canvas bounds, board travel, rigid/support checks, editable scenes, pixel-identical save/reload checks and a timed reel. Use `inspect` for facing/action selection, pause/step, reflection and cloak-off examination. Both commands call the required repo runners.
5. Inspect the whole cycle and the difficult poses: preparation, contact, passing, deepest bend, recovery and exposed anatomy. Inspect the board at 1920×1080/100%. Fix ownership, missing paint or perspective errors at their source rather than hiding them with another layer or extreme bone rotation.
6. `verify-render` must match the final case and proof. Integration additionally requires real action-trigger/outcome proof and a playable pre-action fixture. Give the normal exact-HEAD peer-reviewed handoff with the skill/case path, preview, saved scenes, validation, residual limits and a useful new-task prompt.

Do not add optional actions or redesign the character when the request is narrower. Preserve requested deferrals and existing publication authorization boundaries.
