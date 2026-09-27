# Tharokh attachment repair

Fork of the current `feedback_breath_v02` case. Final-v1 walk/claw poses exposed
wrist cuts, while Breath translated a rigid neck away from the chest and head.

`repair_attachments.py` preserves the forked source layouts, PNGs, joints and
sampler. It creates `layouts/*_attachments_v3.json`, matching distal limb
collars to actual claw-paint boundaries and retaining rigid one-bone claws.
The neck's irregular rock-plate ownership edges now blend between torso, neck
and head. The head remains a rigid one-bone drawing. `attachment_repair.json`
records the affected vertices. Motion amplitude, stride, support and action
timing are unchanged.

The first native candidate closed the large neck/wrist cuts but exposed small
paint islands with the wrong joint ownership. The accepted second candidate
assigns those existing crown, tail and limb pixels to the adjacent painted
part's original weight field, with locally refined mesh vertices. It does not
repaint or remove the islands, or reduce articulation.

Status: promoted after native full-cycle inspection and independent acceptance
of `/private/tmp/dragon-seam-repair/tharokh-candidate02/` (576 timed boards,
448 first-cycle poses, 12 pixel-identical editable-scene reloads). Both facings,
all six clips, the original Breath/Walk/Claw failures and repeated idle/walk
boundaries were inspected. Promotion changes only the two layout JSONs; all
painted PNGs, rest images and motion remain unchanged. The independent scope and
evidence are in `playtest/dragon_vyr_thar_attachment_review_20260927.md`. Both
the failed v02 receipt at `/private/tmp/dragon-cutout-final-v1/tharokh/` and the
rejected `tharokh-candidate01` receipt remain preserved.

Use the maintained workflow, under the root worker's renderer lease:

```sh
python3 tools/cutout_workflow.py render experiments/cutouts/tharokh/feedback_seams_v03 --output /private/tmp/dragon-seam-repair/tharokh-candidate02 --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --backend metal
```
