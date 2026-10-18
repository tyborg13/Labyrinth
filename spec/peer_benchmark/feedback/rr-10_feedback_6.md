# rr-10 feedback 6 — rear near-foot donor (TODO_DESIGN_rear_foot_near_hidden_paint decided)

The rear near foot is fully hidden under the robe in the approved rear painting (0 visible pixels), and it only shows
when the hem lifts during the move.
- Donor: the rear FAR foot's visible painted heel. It is the same boot.
- Copy that heel's pixels, including its outline, to the near-foot solo's position, aligned to the solo's bottom edge.
  Clip them to the near-foot solo silhouette, and fill any remaining solo pixels with the nearest donor pixel.
- The dark-slab gate applies. At rest it stays fully hidden, so rest identity stays 0 px.

The director committed your r5 (both views). After this, stop. The director runs the full windowed proof:
`density`, `rest`, `native`, `sheets`, `idle`, `production` and `review`.
