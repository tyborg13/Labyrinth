# mq-06 feedback 4 — decouple: freeze the front, build only the rear from a planted body

Three rounds show that keeping the front pixel-identical while re-posing the 3D body fights the cloth solver. That
constraint isn't needed.
- The approved front painting and the front delivery are final, and the rig (rr-10) already uses them.
- Only the REAR needs a body standing on the floor, turned 180°.
- The tiny 3D difference at the far foot, hidden under the robe in the front view, doesn't matter.

## Decision
1. **Front: frozen.** Don't regenerate or stage any front output. Front delivery bytes stay unchanged (that is the
   gate), and `joints_px.json` front entries stay unchanged. Drop the front alpha/union gate and
   `TODO_IMPLEMENTATION_CONTACT_ALPHA`.
2. **Rear body.**
   - Start from the fitted body. Re-pose the far leg through its real bones (hip/knee/ankle) so the far foot stands
     on the floor plane at the near ankle's height. Keep its ground position as close as practical to where the front
     ray correction put it.
   - Re-settle the robe skirt with the existing collision solver and margin, so all hem points rest on or within
     0.02 m above the floor, with zero intersections.
   - No front-view constraint.
3. **Rear capture.**
   - The exact 180° turn, the same camera direction and scale.
   - Pan-only framing with every pixel ≥ 8 px from every edge (feedback 3).
   - If the figure can't fit the 1024 canvas by panning alone (height over 1008 px), report the height and stop. Don't
     scale.
   - Rebuild the rear clay, part map, solos and rear `joints_px.json` entries.
4. **Gates.**
   - The turn regression passes for the Seer.
   - The floor guard passes (Seer: no exceptions).
   - Native collision passes.
   - Rear IoU against the old approved rear painting ≥ 0.60 under dynamic registration; also report the fixed value.
   - Per-part rear coverage.
   - Curation within budget; the full Python suite.

Proof: the 1024 rear sheet (old rear clay | new rear clay | new rear part map | old approved rear painting) and the
height table.
