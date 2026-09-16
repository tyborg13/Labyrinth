# Graftwright portrait cutout

The front-only workshop NPC retains every visible pixel of the original
`assets/art/npcs/graftwright.png`. No new paint, unseen body, or combat action is
introduced. The bench and traced countertop props remain foreground layers in
`GraftwrightView`; the portrait's placement is fixed throughout the idle.

The authoring case is `experiments/cutouts/graftwright/v01`. It uses the maintained
cutout workflow and the production protagonist skeleton loader. Five bones own
the fixed lower root, chest, masked head, needle hand, and lantern. Four explicitly
segmented paint owners share one continuous source-space weight field so their
boundaries stay joined. The 2.4-second breathing beat raises the chest 1.4 logical
pixels and adds 0.9 at the head and a slightly delayed 1.2 at the needle hand.
There are no periodic joint rotations, traveling cloth waves, or portrait-level
translations. Reduced motion uses the same assembly in its bind pose.

Logical registration remains 255×255 for the authoring toolkit. Production UVs
sample the original paint in a 1448×1448 square, with the original 1086×1448 image
at (181, 0); the small registration image is solely for ownership/skin authoring.
This preserves detail when the portrait fills the left side of the workshop.
The runtime rig uses linear filtering and ordinary canvas order, so the bench
and individual spool silhouettes cover the moving cutout correctly.

`recipes/build_case.py --output <fresh-case-directory>` reconstructs ownership,
registered skin, native textures and source provenance. `--promote` explicitly
copies that new case's layout and paint into production. The final motion sampler
is identical in `scripts/graftwright_cutout/motion.gd` and the case. The original
native ownership polygons and source hash remain in the case's source/recipes.

Production depends only on `assets/units/graftwright_cutout/` and
`scripts/graftwright_cutout/`, plus the existing rig/asset loader. All export presets
include the new layout JSON; PNGs use the established raw keep import. The package
smoke test runs the production closure in the unmodified non-editor export runtime.

Proof: `cutout_workflow.py validate`, `render`, and `verify-render` cover the full
48-sample loop twice, bounds, rigid bases and pixel-identical editable-scene
save/reload. `graftwright_motion_probe.gd` records the NPC in the actual encounter,
checks bench/spool occlusion, and records crafting and the complete framed result.
`graftwright_feedback_probe.gd` checks bind-pose reduced motion alongside pointer
feedback. Only the requested workshop front idle is supported; there are no rear,
walk or attack clips. The board in the authoring reel is a registration test,
not a claim that this NPC is a combat character.
