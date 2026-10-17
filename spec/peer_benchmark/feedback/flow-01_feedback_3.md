# flow-01 feedback 3 — owner: cut the board flash between the title card and the section map

Owner (review inbox, section-transition, NEEDS CHANGES): "After introducing the next section, you're briefly
switching back to the board before going to the new map section. We should cut that. Otherwise, looks good."

The cause: arrival reveals the entry room, then the threshold's automatic map handoff opens the section map on top of
it.

## Decision: the title card cross-fades straight into the section map
When the destination entry auto-opens the section map (every section threshold does), skip the board reveal:
- **Title card to map.** From the arrival point (2.60 s), over 0.40 s, cubic in-out:
  - the title text and band fade out;
  - the full-screen backdrop dims from full brightness to the section map's own background modulate
    (`Color(0.56, 0.54, 0.59)` in `section_map_panel.gd`);
  - the section map's frame, header, nodes, paths and legend fade in from 0 to 1.

  The map's background is the same `sections/<boss_id>.png` painting, cover-fit the same way, so it reads as one
  continuous image. Match the scale exactly at the hand-off: end the 1.00→1.05 push-in so that the frame the map takes
  over shows no visible jump. If the map's cover-fit differs, ease the push-in to land on the map's framing over those
  0.40 s.
- **No board.** The entry room loads underneath and stays hidden until the player closes the map, exactly as when the
  map is open today. Never a frame of the board between the title card and the map. Add a frame-level test.
- **Music.** The map's planning track starts at the hand-off, as now. One handoff only.
- **Reduced motion.** A 0.30 s cross-fade from the title card to the map, with no push-in.
- **Skip.** Skipping jumps to the map view: the same end state, with a 0.12 s cross-fade.
- **Unchanged.** If a destination does not auto-open the map, keep the current arrival. The save-failure reversal and
  everything else stay the same.

Update the probe contract with captures at the hand-off midpoint and once the map is fully open, normal and reduced.
Update the demo so the clip ends 2 s after the map is fully open. I'll post the new clip to the owner.
