# mq-04 feedback 1 — bridge timeout clarified; Gale Herald banner decision

1. **The 120 s rule was mine and was misread.** It means the bridge must start a job within 120 s: a `RUN` line in
   `bridge.log`, or a result for a quick job. It does not cap how long a Blender job may run.
   - Set each job's `timeout_s` to its real need. Cloth builds and previews may take up to 900 s; the bridge's hard
     maximum is 1800 s.
   - The job `mq03-177e286a…` (Gale Herald `--preview`) was started at once and killed by its own 120 s `timeout_s`
     (`exit -1 in 120.0s` in `bridge.log`). Re-run it with a realistic timeout.
   - The bridge is running for this worktree. Keep going without waiting for me unless a job is never started.
2. **TODO_DESIGN_gale_herald_rear_cape_pose (director decision).** Both approved paintings trail the banners
   screen-right. Keep that: on screen it reads as one consistent wind direction whichever way the Herald faces.
   - Give the banner/cape cloth a per-view pose. The rear capture uses a rear-specific cloth state, with the banners
     trailing screen-right to match the approved rear painting. The body, armature, joints and every other part stay
     one model turned 180°.
   - Document the per-view cloth pose in the spec. The ownership and fit gates apply per view. Use this for any
     figure whose approved paintings show the same wind direction in both views; for this batch that is the Gale
     Herald only.
3. **Finish the unit.**
   - Fix the Gloam Stalker build failure (`exit 1`, job `mq03-c9fb2c49…` at 13:32:09).
   - Resolve the cloth intersections.
   - Reach the fit gates (IoU ≥ 0.80 front, ≥ 0.75 rear, every part present or explicitly occluded).
   - Recapture with the current specs, and deliver the four-figure overlay contact sheet and the fit table.
   - Re-run determinism, ownership and mutations.
   - If a figure cannot reach its gate after a real effort, report its best IoU, the specific mismatching regions (with
     the overlay), and what would be needed. Don't lower the gate.
