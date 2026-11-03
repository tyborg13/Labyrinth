# Art and animation backlog (low priority: "when we have some spare cycles")

Owner-raised polish that is not blocking. Pick these up when the queue is quiet; each needs a director look at the
native frames first, then a small unit.

1. **Frostglass Lancer: spear shaft shows through where it shouldn't** (owner, 2026-10-27, inbox `lancer-rig-v2`,
   APPROVED otherwise). "There's some perspective issues where parts of the spear handle show through that shouldn't
   in both front and rear view." Start from the rr-43 review reel: find the frames where the shaft draws over a
   piece that should hide it (the gripping hand, the body or the far arm), in both views, and fix the draw order or
   the shaft's visible segments per clip. Add a native check for the found frames.
2. **Glacial Mirror: feet and fists** (owner, 2026-10-19: "not totally sold"). Revisit; see STATUS 2026-10-19.
3. **Arc Thrall rear tether fin** (low priority; rr-27 study in `experiments/cutouts/arc_thrall/rr27/tether_study`).
