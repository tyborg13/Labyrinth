# Vyraketh attachment repair

Fork of the current `feedback_breath_v02` case. Final-v1 walk pose 29 exposed
detached reaching claws in both views. The rigid claw paint starts above the
foot pivot, but the limb's old blend did not finish until that pivot.

`repair_attachments.py` preserves the forked source layouts, PNGs, joints and
sampler. It creates `layouts/*_attachments_v3.json`, matching the distal limb
collar to the actual claw-paint boundary and retaining a rigid one-bone claw
mesh. `attachment_repair.json` records the affected vertices. Motion amplitude,
stride, support and action timing are unchanged.

Status: promoted after native full-cycle inspection and independent acceptance
of `/private/tmp/dragon-seam-repair/vyraketh-candidate01/` (656 timed boards,
512 first-cycle poses, 12 pixel-identical editable-scene reloads). Both facings,
all six clips, the original Walk 29 failure and repeated idle/walk boundaries
were inspected. Promotion changes only the two layout JSONs; all painted PNGs,
rest images and motion remain unchanged. The independent scope and evidence are
in `playtest/dragon_vyr_thar_attachment_review_20260927.md`. The failed v02
receipt remains at `/private/tmp/dragon-cutout-final-v1/vyraketh/`.

Use the maintained workflow, under the root worker's renderer lease:

```sh
python3 tools/cutout_workflow.py render experiments/cutouts/vyraketh/feedback_seams_v03 --output /private/tmp/dragon-seam-repair/vyraketh-candidate01 --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --backend metal
```
