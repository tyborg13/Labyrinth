# rr-21 feedback 2 (director): the new walk

Your round 1 numbers confirmed the problem: the stride + trailing shuffle can't keep the feet planted in 2D. The owner
also rejected that pattern as a limp on the Glacial Mirror. Every humanoid now walks on the protagonist's model
(decisions 2026-10-19; rig spec §3 and §4).

1. **Integration is already merged in.** The director committed your round 1 work and merged `codex/peer-benchmark` into this branch. It brings gait-01's shared walk: the gait
   block compiler, lanes, projected leg scale, pelvis fit, shared walk gates and compact walk reports. Conflicts were
   resolved toward integration's shared code; check that your case code still builds on it.
   - `assets/generated/unit_shadow_cache.res` now holds integration's version. Re-run your unit's shadow refresh so
     your records return, and leave every other unit's records untouched.
2. **New protected director data** (`spec/peer_benchmark/staged/rr-21/motion_tracks.json`; import byte for byte):
   - `move` is a gait block: 6 steps per tile, 0.9 s, 7 px lift, settle 2.5 px; the claws sway 3 px; the tatters trail
     2 px.
   - Retire the Weaver's `leg_roles` and its stride/trailing move gates. The shared walk gates replace them.
3. **Native gates.** The windowed run failed only in the old `move`:
   - joint-seam holes in front frames 8–17 and 26–36;
   - detached components in rear frames 28–35.
   Re-run the native gate on the new walk and fix every failure by its root cause: joint continuations from the
   pieces' own edge texels, no exemptions.
4. **Compact proof records** (the gait-01 rule): the case's committed `samples.json`, `gates.json` and
   `native_gates.json` hold summaries, extrema and failures only. Full per-frame data goes to the gitignored proof
   outputs. They are 3–9 MB each today.
5. Then every gate passes headless in both views. List the exact windowed sequence. Proof captures stay gitignored.
   Run focused tests only.
