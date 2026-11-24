# Burrow mound, take 5: judge verdict (director, 2026-11-23)

Judged on `sheet_5.png` (source and as-shipped rows, board scale beside the hero, crag_outcrop and raised_cover) and on real-game native stills from the art-08 probe (`/private/tmp/labyrinth_codex/art-08/native/after/`), per the owner's split: art is judged by Claude directly, with no subagent.

Why take 5 replaced take 3: take 3 passed this sheet, but in the real fight, under the Grub's actor lighting and the cel look, it measured 22 luma against the floor ring's 43 and could not be found on the board. Take 4 fixed the value but went orange (chroma 0.308). Take 5 is the take-3 heap repainted in lighter grey-brown soil.

1. View: PASS. The base is corner-on and follows the 2:1 diamond (base_v_left 0.40, base_v_right −0.37). The top of the heap is visible and the near side is lower-right.
2. Proportions: PASS. One low continuous heap filling about 2/3 of the footprint, with chunky clods; it sits below the hero's knee as a ground feature should.
3. Detail: PASS. Clods are 2 to 4 blocks; two half-buried stones; no filigree or strands.
4. Palette and value: PASS with an exception. Chroma 0.169 is in band; the soil is a muted grey-brown, and the ochre hide is the only accent. Value 0.4175 is just above the 0.4 creature band. In game it measures 47–49 luma against the floor ring's 43 (01 peak +3.8, 02 trough +5.9, 04 after burrow +4.7), so it reads as raised earth just above the floor rather than as a bright object. The exception and its reason are in the registry.
5. Size: PASS with the existing exception. 138×52 px is a low mound by design; `height_drawn` fails only the standing-prop band (120–180).
6. Hand: PASS. Chunky clusters, upper-left light on the clod tops, and a dark lower edge that matches the canon props once processed.
7. Cutout readiness: N/A (static board state; the Burrow Grub rig hides at the end of `burrow`, and this mound is what stays).
8. Identity: PASS. At board size it reads as freshly churned earth with the Grub's ringed back sunk in a crack along the crest, distinct from the crag and the cover.
9. Structure legibility: PASS. The single hide arc dips under the soil at both ends.

VERDICT: PASS. Production source: `processed_5.png` (from `raw_5.png`), copied to `processed.png`/`sheet.png`. The owner approves it from a real-game capture.
