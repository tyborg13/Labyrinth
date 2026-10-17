# rr-05 feedback 5 — the Wisp still fails native verification (director run 3)

After round 3, I ran only the Wisp's native review step: `tools/maquette_cutout_review.py --case
experiments/cutouts/lightning_wisp/mq4 --capture output/rr-05/wisp-native ... --render`.
- Log: `output/rr-05/director_windowed_run3_wisp.log`.
- Report: `output/rr-05/wisp-native/pixel_gates.json`.

Native capture PASS. Verification FAIL, 18 errors, all "native part does not match its source transform":
`front/arc_right` ×12 (frames 18–23, 90–93 and more) and `rear/arc_right` ×6. The eye and `arc_left` now pass.
Round 3's fix was validated against the old saved captures only. These are fresh captures from the fixed runtime.

`arc_right` must share core's snapped transform exactly, like `arc_left`. Find what differs for `arc_right`, for
example a crop offset, a hidden-fill node, an odd-width crop or a pivot rounding. Give the same evidence as in
feedback 2/3, and fix the runtime or the model. The regression must use these fresh captures. Never loosen
tolerances. Keep the fresh captures until I've re-run.
