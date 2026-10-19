# rr-21 feedback 2 (director): the new walk

Your round 1 numbers confirmed the problem: the stride + trailing shuffle can't keep the feet planted in 2D. The owner
also rejected that pattern as a limp on the Glacial Mirror. Every humanoid now walks on the protagonist's model
(decisions 2026-10-19; rig spec §3 and §4).

1. **Sync integration first.** Merge `codex/peer-benchmark` into this branch. It brings gait-01's shared walk: the gait
   block compiler, lanes, projected leg scale, pelvis fit, shared walk gates and compact walk reports. Resolve conflicts
   toward integration's shared code.
2. **New protected director data** (`spec/peer_benchmark/staged/rr-21/motion_tracks.json`; import byte for byte):
   - `move` is a gait block: 6 steps per tile, 0.9 s, 7 px lift, settle 2.5 px; the claws sway 3 px; the tatters trail
     2 px.
   - Retire the Weaver's `leg_roles` and its stride/trailing move gates. The shared walk gates replace them.
3. **Native gates.** The windowed run failed only in the old `move`:
   - joint-seam holes in front frames 8–17 and 26–36;
   - detached components in rear frames 28–35.
   Re-run the native gate on the new walk and fix every failure by its root cause: joint continuations from the
   pieces' own edge texels, no exemptions.
4. Then every gate passes headless in both views. List the exact windowed sequence. Proof captures stay gitignored.
   Run focused tests only.
