# mq-11 feedback 3 (director; Codex re-review of a62dce585: one Medium left)

Findings 1, 2, 4, 5 and 6 are resolved: 15 of 15 guard mutations caught. One fix remains. Focused tests only. Design
data, gates and the median statistic don't change.

1. **Medium: crack visibility checks mask midpoints, not the crack.**
   - `measurements.py:86` samples one central column per middle-third row.
   - A reproduction hid 115 of 117 crack pixels and still passed.
   - Fix:
     - rasterize the registered `violet_crack` feature (`source_path_px` with its stroke width) into the front view;
     - depth-test its actual pixels against the hair;
     - require at least **85%** of the crack's pixels to stay visible.
   - Keep the lower-mask band rule as it is.
   - Add the 98%-hidden negative regression, and a positive case where the fringe covers only the mask's top band and
     passes.
