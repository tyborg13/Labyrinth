# Burrow mound, take 6: judge verdict (director, 2026-11-24)

Why take 6 replaced take 5: on 2026-11-23 the owner said the take-5 mound sits too high and looks like it floats. In
the real fight (`/private/tmp/labyrinth_codex/art-08/realfight/after_2.9.png`, Hollow Antechamber), take 5 sits in
the back half of its tile and the Grub's health bar covers its crest, so what shows is the rounded underside of a
lump hanging under the bar. Take 6 is a new painting from `subject_6.md` with a new kit (target 36×152 instead of
52×136): a lower, wider dome whose base spreads into the floor as loose earth.

Two image runs were made from the same kit and prompt (`img-mound6`, `img-mound6b`). Judged on `sheet_6.png` (source
and as-shipped rows, board scale beside the hero, crag_outcrop and raised_cover), on both processed takes at 8×
nearest, and on the board-scale cel crops side by side, by Claude directly with no subagent.

Chosen take: `img-mound6b` (`raw_6.png`, sha256 799445e1623227e131be362e53328306b8e7feddc0dbe0400261b4578efce295,
byte-identical to `~/.codex/generated_images/01a20ebd-7b37-7af0-b448-eac9f470c570/exec-b852b07b-a342-4e83-947b-079a02e9850c.png`).
The other take (`img-mound6`) reads as a pile of loaves with a bright blob on top; take b reads as churned earth with
the Grub's back showing in a crack, and its darker foot sinks into the floor.

1. View: PASS with an exception. The heap is seen from above at the board angle, with the crest visible and the near
   side lower-right. `base_v_left` 0.152 and `base_v_right` −0.155 fall below the 0.3–0.75 band: the loose crumbs
   spread along the floor and flatten the measured base line. That spread is the owner's request (base sunk into the
   floor). Placement on the tile is fixed in code, not paint (centred on the tile; see `feedback` round 2).
2. Proportions: PASS. One low, wide dome, 156×43 px (take 5 was 138×52), filling most of the tile width.
3. Detail: PASS. Clods of 2 to 4 blocks, two half-buried stones, scattered crumbs, one crack along the crest.
4. Palette and value: PASS. Chroma 0.135 and value 0.343 are inside their bands. Dusty grey-brown soil; the hide in
   the crack is the one warm accent. The in-game value against the floor ring is checked with `tools/art08/luma.py`
   in the round-2 native run (take 3 vanished at 22 luma vs 43; take 5 read at 47–49).
5. Size: PASS with the existing exception. `height_drawn` 43 fails only the standing-prop band (120–180); the mound
   is a ground feature by design.
6. Hand: PASS. Chunky clusters, upper-left light, dark foot, same hand as the canon props once processed.
7. Cutout readiness: N/A (static board state).
8. Identity: PASS. At board size it reads as freshly churned earth, distinct from the crag and the cover.
9. Structure legibility: PASS. The hide shows only inside the crack, so the Grub is under the soil, not on it.

VERDICT: PASS, pending the real-fight capture. Production source: `processed_6.png` (from `raw_6.png`), copied to
`processed.png`/`sheet.png`. The owner approves it from a real-game capture.
