# rr-05 feedback 6 — close the Bloomer seams (director decision on support bleed)

The Wisp passes every gate. The director is running its full windowed proof and production adoption now
(`--from-native --creature lightning_wisp`). Don't touch Wisp outputs while that runs; the log will be at
`output/rr-05/director_windowed_run4_wisp.log` when I copy it in.

The Bloomer's remaining enclosed holes are real defects. My check of the saved native captures (front_move pose 0019,
328 px) shows hairline background cracks along part seams (petals↔trunk, root stems↔trunk) and a wedge at a
lower-left root tip: background showing through where neighbouring parts rotate apart. This is the tearing the owner
objected to.

## Decision: support bleed
Your support was limited to copying existing approved texels clipped to rest alpha, which can't cover these seams.
I now authorise synthesized support:
- Each part's paint may be extended under its neighbouring parts by edge-texel replication: nearest-edge colour,
  outward, the standard cutout bleed. The margin per joint is derived from that joint's maximum sampled separation,
  plus 1 px.
- The bleed lives only underneath the neighbour, by draw order, and only inside the union of the rest silhouette. So
  it is never visible at rest. Rest identity must remain 0 px in all views.
- Features (gems, nodules, eye) are never bled into and never bleed.
- The gate stays as is: no new enclosed hole of 2 px or more in any pose, CPU and native.

## TODO_DESIGN_silhouette_front_idle_0012
If bleed resolves it, nothing changes. If those 4 pixels still remain after bleed, change the director motion key
`tendril_high_r.raise_deg` `(0.5, 5)` → `(0.5, 4)` in the Bloomer's idle clip. Report that you did. This is the only
motion edit I authorise. Any other unfillable pose goes under TODO_DESIGN with the same evidence format.

## Then
Re-run the Bloomer gates (detached + holes, CPU), the focused suites and the full suites. Hand back the
`--from-native --creature shale_bloomer` command for my windowed run.
