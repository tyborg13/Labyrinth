# mq-07 feedback 1 — tube values (TODO_DESIGNs decided) and a width correction

The shoulder fix is right in both views; keep it. The tube reads as a fat pill: it is about 29 source px wide
(255-px scale), capped at both ends. The approved original Thrall's tube is about 17 px wide, open at the elbow with
the arm going in, and closed at the far end. Rebuild the tube with these exact values. Native 1024-px values are 4×
the source px.

1. **Width (correction).** Outer diameter 17 source px (68 native) ± 1 px, measured perpendicular to the tube axis in
   the front view, constant along the length. This replaces the 1.4× upper-arm rule; your measurement of the upper arm
   included the deltoid. Keep the length: the cap ends where it is now.
2. **`TODO_DESIGN_tube_elbow_offset_px` = −2.**
   - The tube's top is an OPEN rim, centred 2 source px (8 native) ABOVE the elbow joint along the forearm axis, so
     the elbow pivot sits inside the mouth.
   - The upper arm's distal end passes into the mouth: no gap between arm and rim, and no cap at the top.
   - The bottom end is a closed, rounded cap with a dome height of 0.35 × the diameter.
3. **`TODO_DESIGN_collar_band_dimensions_px`.** One band at the mouth: 3 source px tall (12 native) along the axis,
   raised 1 source px (4 native) radially from the tube surface. No other bands.
4. **`TODO_DESIGN_collar_rivets` = none.** No rivet geometry; the paint-over handles surface detail.
5. **Labels.** The band belongs to `fore_near` (the tube). The upper arm's end inside the mouth stays `upper_near`;
   the mouth hides it.

Re-run the IoU gates (front ≥ 0.70, rear ≥ 0.65), the shoulder rule, the turn rule and curation. Update the sheet with
a 3× crop of the elbow/mouth in both views.
