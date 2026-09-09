# Stone Warden — editable cutout study v03

The walking revision gives both feet an advancing step and orders each complete leg by ground depth. The rear left boot is occluded by the nearer right shin when it steps forward. A longer stride lowers cadence while preserving approximately the accepted board speed. All source paint, part registration, meshes, idle motion and overhead attack are preserved from v02; v01 and v02 remain available for comparison. The small front attack overlap with the health bar remains explicitly accepted.

## Inspect and edit

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py inspect experiments/cutouts/stone_warden/v03 --task-id stone-warden-editable-front-rear-cutout
```

Choose Front/Rear and Walk. Space pauses; arrows step. Cloak on/off hides the tabard to expose the leg overlaps. The preview uses the actual CombatBoardView at 1920×1080 and 100% UI scale.

- `review/videos/cutout_review.mp4`: full timed board reel with idle, two walking cycles and attack for both views.
- `review/front.tscn`, `review/rear.tscn`: editable Skeleton2D, painted parts and meshes, bone animation tracks, and discrete part-layer tracks. Rerender after editing the sampler.
- `review/assembled.png`, `review/contact_sheets/`: shared-scale assembly and every regular/exposed pose.
- `review/walk_checks/`: native overlap layers, same-pose legacy-order counterexample, accepted-clip preservation and alternating-step measurements.

## Walking and perspective

| Quantity | v02 | v03 |
|---|---:|---:|
| Stride | 48 px | 72 px |
| Support fraction | 62% | 60% |
| Travel per cycle | 77.419 px | 120 px |
| Cycle duration | 0.34 s | 0.52 s |
| Steps per second | 5.882 | 3.846 |
| Source ground speed | 227.704 px/s | 230.769 px/s |

Each new step covers 60 source pixels of root travel instead of 38.71. Cadence is 34.6% lower; ground speed changes by only 1.35% and remains about 86.5% of the protagonist's nominal source-pixel pace. The case retains a 5px foot lift and rigid painted boots. The feet stay planted during support.

The gait uses the two 2:1 projected ground axes. Sole landmarks, including each boot's different ankle-to-sole offset, define the contact plane. Removing the resting stagger in that plane and retaining 60% of the painted lateral lane width lets both soles pass the opposite foot without the previous screen-perpendicular centering bias. At right-forward and left-forward samples, projected sole advance is roughly 13px and 40px respectively; the different screen distances reflect the two perspective lanes. Both steps make equal forward progress on the ground.

The case's `draw_order_parts` declares the leg paint that can change layers. `sample_draw_order` sorts by ground-contact depth, excluding airborne lift. The farther leg's boot, shin and underpainting remain behind the nearer complete leg in both views. Idle, attack and rest return an empty override and restore their original part layers. The authoring adapter resolves actual Sprite2D/Polygon2D paint, including boots whose nodes share names with their bones, and bakes discrete `z_index` tracks into the saved scenes.

## Verification

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tests/test_cutout_workflow.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py validate experiments/cutouts/stone_warden/v03 --protect all
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/cutout_workflow.py verify-render experiments/cutouts/stone_warden/v03 --output experiments/cutouts/stone_warden/v03/review
```

`verify_walk.gd` runs through `tools/visual_probe_runner.py` with `--no-headless --expect-size 512x512 --timeout 60` and absolute `--case`/`--baseline` paths to the v03/v02 `cutout.json` files. It compares all 112 native idle/attack frames after switching out of walking, checks actual painted layers across both walking cycles, confirms alternating sole advance, and renders each rear leg separately. At the left-forward crossing, the old layer order produces 48 leak pixels; the corrected order produces zero across 254 near-opaque overlaps, allowing only measured residual alpha contribution and pixel rounding.

The standard render retains full 512px action canvases, board travel, rigid/support metrics, timed encoding, source/output digests and scene save/reload equality. Animated-order walks additionally reload at both alternating step phases. `validate --protect art` passed against the fork baseline before writing the final baseline. The original segmentation, hidden-paint masks, generation requests and source masters are retained unchanged under `source/` and `recipes/`.

## Scope

This remains an isolated authoring case. The board uses the toolkit's player proxy (30/30 HP and proxy scale); it does not establish production Stone Warden scale, real combat routing or outcomes. A gameplay pre-action save is not applicable; the native case inspector above is the inspection fixture. Production assets, enemy data, action timing and mechanics are untouched.

The concealed front armor is approximate paint for these inspected poses. The accepted rear shield gap and front attack HP overlap remain. Two painted views plus reflection do not provide a 3D turn; the board retains its static reference shadow. Broader motion can require additional concealed paint. Publication awaits inspection and explicit approval of the committed branch.

Next-task prompt: “Use `$create-labyrinth-cutout` to fork the reviewed Stone Warden v03 case and refine [specific inspected issue], preserving its accepted paint, idle and attack. Provide fresh full-cycle native proof and editable scenes.” Live enemy integration additionally requires the enemy/UI workflows and real action/outcome proof.
