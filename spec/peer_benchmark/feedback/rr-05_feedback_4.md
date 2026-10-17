# rr-05 feedback 4 — the silhouette must stay whole (the owner's "wrong breakages")

The gems are fixed, but the owner's other complaint ("a few wrong breakages from the cutout that are too
distracting") is still visible in the Bloomer's native captures from director run 2 (`output/rr-05/shale-native`).
Small pieces of a part detach and float off the body, and background shows through between parts.

Evidence: `output/rr-05/director_review/bloomer_detached_islands.png`. Cyan boxes mark detached components. The method
is 8-connected components on the native alpha, where a component is detached when it is more than 3 px from the
largest component. The worst pose per clip:

| clip | pose | detached px | islands |
|---|---|---:|---:|
| front_hit | 0020 | 182 | 2 (a tendril-tip chunk) |
| front_death | 0030 | 207 | 10 |
| front_shell | 0019 | 37 | 8 |
| rear_shell | 0047 | 25 | 15 (a trail of specks) |
| front_move | 0006 | 20 | 3 |
| front_idle | 0030 | 19 | 1 |
| rear_death | 0036 | 29 | 17 |

`rear_idle` is clean.

## Requirements
1. **One piece per part.** In every view, after hidden fill, each part's pixels form a single 8-connected component.
   - Reassign orphan islands to the neighbouring part they touch most at rest.
   - Add this as a derive-time gate for every maquette cutout case: Bloomer, Wisp, and future rigs.
   - Rest identity must stay 0 px against the approved art.
2. **Whole silhouette in every pose.** In every sampled pose of every clip, in both views, on both the CPU model and
   the native captures:
   - the rendered silhouette has no detached component (any size, more than 2 px from the main body);
   - no new enclosed background hole of 2 px or more appears compared with the rest pose. This catches background
     showing between parts.
   - There is no exception for death: nothing in the motion design calls for debris.
   - Add both checks to the pixel gates, with mutation tests: inject an orphan pixel, and widen a joint gap.
3. **Fix approach is yours**, implementation only:
   - ownership cleanup;
   - hidden fill extended under neighbouring parts at joints;
   - a joint overlap margin.

   Do not change the director motion data. If a pose cannot be made whole without reducing an authored amplitude,
   report the exact clip, channel, key and pose under TODO_DESIGN and I will decide.
4. Run the gates on the Bloomer and the Wisp. Report the before/after table above for both creatures, CPU and native
   (native from the saved captures where they exist). I re-run the windowed proof afterwards.
