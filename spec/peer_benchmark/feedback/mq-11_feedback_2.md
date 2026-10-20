# mq-11 feedback 2 (director; Codex review of 2e97131de requested changes)

The design data and the director's gate values don't change. That covers both `design.json` files, GATES
`front_thigh_fraction` 1.25, `flap_centre_error_px_max` 12, and the median-of-central-rows centre statistic. Fix the
validation and the tests. Full review: `/private/tmp/labyrinth_codex/review/mq-11-2e97131de.md`.

1. **Medium: stale measurements can keep valid acceptance hashes.**
   - `workflow.inputs()` omits dependencies such as `raster.py`.
   - Bind the complete dependency set: every module the capture, measure and inspect paths import.
   - Snapshot the inputs before building and compare against that snapshot. Don't refresh the snapshot at acceptance.
   - `verify` must recompute or re-bind the shape report, not trust the cached one.
2. **Medium: a detached scalp passes.**
   - Moving the scalp and every tuft 10 m sideways still compiles.
   - Validate in 3D: the scalp ellipsoid must contain the skull's crown and base axis points within its lateral extent,
     and every tuft root must lie inside it (already checked).
   - Add a detached-scalp negative test.
3. **Medium: near-total mask occlusion passes the fringe gate.**
   - Require at least 60% of the mask's lower 80% band (by rows) to remain visible.
   - The rows holding the crack's projected centre must stay visible: use the mask's middle third as the crack band.
   - Add an excessive-occlusion regression.
4. **Low: inclusive boundaries reject valid geometry through rounding.** Apply an epsilon of 1e-9 relative to the
   threshold for the tuft length range and the rear-height ratio. Don't change the thresholds.
5. **Low: very short flaps have no measurement-quality guard.**
   - Require at least 12 contiguous occupied rows in the central band before the median applies.
   - Otherwise fail with "insufficient flap rows".
6. **Surviving mutations.** Make each of these fail a focused test:
   - removing the flap-row ordering check;
   - removing unowned-accessory preservation;
   - removing acceptance freshness;
   - removing the shape-report spec binding.

Focused tests only. Don't run the bridge. The director reruns `workflow build` natively afterwards.
