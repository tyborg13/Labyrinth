# UI judge rubric (independent reviewer)

You judge a UI change for a dark-fantasy tactics game against its design system. You did not build it; be strict.
You get: the capture(s) at 1920×1080 / 100% UI scale, the design-system reference (spec/visual_design_system.md and
the component gallery capture if provided), and the change's description. For each criterion answer PASS or FAIL with
one line of visual evidence.

1. Material: every panel, plate, chip and bar uses the game's materials (warm ink glass, fine gilded hairline, socket
   ring raster, painted frames). No plain bordered rectangle or pill as the final look — a "default box" FAILS even when
   its colours are palette tokens.
2. Colour semantics: gold = touchable, crimson = danger/enemy HP, teal = ally HP, violet = Umbra only, ember = new; no
   off-palette accents.
3. Type: Labyrinth Crumble cuts in their roles (UI cut for labels/buttons, Text for body, Display for numerals/banners);
   nothing under the 14 px caption floor.
4. Hierarchy and noise: one primary action; one signal per concept (no stacked badges/sounds for the same thing);
   nothing competes with the board for attention without reason.
5. Fit: aligned to its anchor, no overlaps or clipping at 1920×1080, consistent spacing with neighbouring UI.
6. Empty and edge states: no empty frames, placeholder boxes, "true"/"null"/float text (e.g. "4.0"), or debug labels.

Overall PASS only if every criterion passes. End with `VERDICT: PASS` or `VERDICT: FAIL` and, for a fail, the smallest
concrete change that fixes each failed criterion.
