# purge-02 feedback 2 — badge clipped and dim (windowed review)

The director ran the windowed Purge probe on your round 1 (12 captures; evidence `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/purge02/scavenger_grid_14.png`
and the crop `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/purge02/badge.png`). The header is right: keep it. The badge needs two fixes:

1. **Clipped.** The medallion's lower half is cut off flat at the bottom of the grid's scroll viewport (every bottom-row
   badge). Badges must never clip: give the grid content **24 px** of extra padding at the bottom and the right (the
   badge's overhang past the card corner), and grow the dialog height by 24 px. The badge position on the card stays
   the same. Add an assertion that every badge rect lies fully inside the visible viewport rect.
2. **Dim.** The ring renders as a dark brown circle, not the antique-bronze medallion the character menu's sockets show
   (`ui_socket.gd` with `medallion_ring.png`). Draw the ring texture at full colour, with no modulate or darkening, at
   the medallion's native aspect from `medallion_ring.json`. The dark centre disc stays inside the ring's inner radius.

Then stop; the director recaptures. Headless proof: the magic deck tests, the pile viewer test, text-fit and the
mutations. No full suites.
