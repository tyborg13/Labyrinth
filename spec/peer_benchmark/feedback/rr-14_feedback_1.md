# rr-14 feedback 1 — review fixes

The director committed your round as fcae304f3, then ran the Seer's windowed native gates (PASS, 0 errors) and sheets
on it. The Codex review asked for changes; its text is below each item. Fix all four. The Seer must stay
byte-identical.

1. **Knee direction for straight legs (Medium; director decision).** `humanoid_motion.gd` ~line 115 falls back to
   `bend_side = 1.0` for a straight rest chain, so front and rear knees both move screen-left.
   - **Decision:** knees bend toward the figure's facing. In the front view (facing the lower-left) a bending knee moves
     toward screen-left; in the rear view (facing the upper-right) it moves toward screen-right.
   - Express it as case data per view and per leg (e.g. anatomy `legs.<side>.<view>.knee: "facing"` resolved to the
     screen sign, or an explicit sign). Required when the rest thigh/shin chain is straight (collinear within an
     epsilon). Fail loudly when it's missing. For bent chains keep the rest-derived side; if data is also given and it
     disagrees, fail.
   - Set it in the Thrall-shaped fixture so both views are exercised: front knee moves screen-left, rear screen-right.
2. **Attachment propagation (Medium).** The loop at ~line 128 rebuilds a solved hand's immediate children from rest
   offsets with zero local rotation; a keyed child lost its 1 px lift and a grandchild was off by 0.57 px. Propagate
   every affected descendant in hierarchy order using its authored local transform, consistent with the held-item
   pass's final transform. Add keyed-child and grandchild regressions.
3. **Anatomy validation (Medium).** `anatomy.py` checks only `schema_version`, and embedded anatomy skips even that.
   Validate loaded and embedded anatomy against `anatomy.schema.json`, reject unknown or misspelled keys, and require
   explicit `null` for absent grip roles (so `griip` fails). Both cases must still validate.
4. **Negative coverage (Low).** Add a reflected-knee sample with preserved segment lengths and a wrong-target sample
   with preserved lengths and bend side; assert each specific error. Removing the bone gate's bend-side check or
   disabling its foot-target check must then fail a test.

Proof (headless): the focused rr10–rr14 tests, `test_rr07_production`, `test_maquette_rear_turn`, the rr10/rr14/rr07
runtime checks, the Seer identity check and fresh sample identity, and mutation results for items 1–4. No full suites;
no windowed runs. List any binding change that needs the director's windowed native rerun.
