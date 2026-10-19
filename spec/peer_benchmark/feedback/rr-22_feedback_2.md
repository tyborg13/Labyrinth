# rr-22 feedback 2 (director): the new walk, crucible ownership, native holes

The director ran the windowed chain. Density, rest, idle and production pass. The native gates refused sheets and
review. Do this round, then hand back:

1. **Integration is already merged in.** The director committed your round 1 work and merged `codex/peer-benchmark` into this branch. It brings gait-01's shared walk: the gait
   block compiler, lanes, projected leg scale, pelvis fit, shared walk gates and compact walk reports. Conflicts were resolved
   toward integration's shared code; rig spec §3 and §4 are binding.
   - `assets/generated/unit_shadow_cache.res` now holds integration's version. Re-run your unit's shadow refresh so
     your records return, and leave every other unit's records untouched.
2. **New protected director data** (`spec/peer_benchmark/staged/rr-22/motion_tracks.json`; import byte for byte):
   - `move` is a gait block: 6 steps per tile, 0.85 s, 5 px lift, settle 3.5 px, a torso jolt on the four full-step
     landings; the apron trails 2 px.
   - Retire the Mortar's `leg_roles`. The shared walk gates must pass in both views.
3. **Crucible ownership.** This replaces your literal HSV bands, which you reported moving warm crucible paint into the
   torso and shoulder; the source-cut sheet shows skin specks under the pot and holes in the torso.
   - The director authored the ownership: `spec/peer_benchmark/staged/rr-22/crucible_mask_{front,rear}.png`, made by
     `make_crucible_mask.py` (protected).
   - Every opaque pixel inside a mask belongs to `mortar`, the crucible: its rim, pot body, slag and the straps where
     they lie on the pot. Nothing outside it does.
   - Head, shoulder and harness keep their own ownership rules.
   - No piece may keep an isolated component smaller than 6 px. Reassign it to the piece that surrounds it.
   - When the crucible tips (`lob` 22°, `death` +12°), its bottom, hidden behind the shoulder, may show. Fill that
     hidden surface from the pot's own edge texels, never from skin.
4. **Native gate failures.** Fix each by its root cause, with no exemptions and no motion changes. Frame numbers refer
   to the old data.
   - Detached opaque components:
     - front `death` frames 22–26, 28, 29 and 31–34;
     - front `scatter` frames 8, 9, 18.
   - Joint-seam holes:
     - front `death` frames 31, 32;
     - rear `death` frames 19, 34;
     - rear `lob` frames 14, 31.
   - Re-run the native gate on the new cut and data, and fix every failure it reports.
5. **Compact proof records** (the gait-01 rule): the case's committed `samples.json`, `gates.json` and
   `native_gates.json` hold summaries, extrema and failures only. Full per-frame data goes to the gitignored proof
   outputs. They are 3–9 MB each today.
6. Then every gate passes headless in both views. List the exact windowed sequence. Proof captures stay gitignored.
   Run focused tests only.
