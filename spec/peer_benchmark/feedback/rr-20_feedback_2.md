# rr-20 feedback 2 (director): the new walk, readable actions, native holes

The director ran the windowed chain. Density, rest, idle (252 frames) and production (1282 frames, 0 errors) pass. The
native gates refused sheets and review. Do this round, then hand back:

1. **Integration is already merged in.** The director committed your round 1 work and merged `codex/peer-benchmark` into this branch. It brings gait-01, the humanoid walk on
   the protagonist's model: the gait block compiler, projected legs, pelvis fit, shared walk gates and compact walk
   reports.
   - Conflicts were resolved toward integration's shared code. Check that your case code still builds on it.
   - Rig spec §3 and §4 are binding.
   - `assets/generated/unit_shadow_cache.res` now holds integration's version. Re-run your unit's shadow refresh so
     your records return, and leave every other unit's records untouched.
2. **New protected director data** (`spec/peer_benchmark/staged/rr-20/motion_tracks.json`; import byte for byte).
   - `move` is now a gait block, 6 steps per tile, 0.8 s. Retire the Mimic's `leg_roles` as gait-01 did for the
     Thrall. The shared walk gates must pass in both views.
   - **`bolt` and `mirror` are restaged.** On the all-black Mimic, the old thrust crossed the black torso and vanished
     at board scale. The leading arm is now `hand_far`, the target-side arm in both 3/4 views, and it reaches out of
     the silhouette.
   - Overreach on these thrusts is reported, not failed (the dense reach gate). The arm fully extends.
3. **Native gate failures.** Fix each by its root cause: joint continuations from the pieces' own edge texels, the way
   rr-15 built the Thrall's. No exemptions, no motion changes.
   - Joint-seam holes larger than 1 px:
     - rear `death` frames 5, 7, 8, 20, 21, 29;
     - rear `hit` frames 2, 13;
     - rear `mirror` frames 7, 9, 13;
     - rear `bolt` frame 38;
     - front `block` frame 13.
   - Detached opaque components:
     - front `hit` frames 4, 7, 8, 9;
     - front `mirror` frames 11–14, 17, 18.
   - Frame numbers refer to the old data. Re-run the native gate on the new data and fix every failure it reports,
     including any in the new `move`.
4. **Compact proof records** (the gait-01 rule): the case's committed `samples.json`, `gates.json` and
   `native_gates.json` hold summaries, extrema and failures only. Full per-frame data goes to the gitignored proof
   outputs. They are 3–9 MB each today.
5. Then every gate passes headless in both views. List the exact windowed sequence. Proof captures stay gitignored.
   Run focused tests only.
