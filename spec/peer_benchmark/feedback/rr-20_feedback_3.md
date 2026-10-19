# rr-20 feedback 3 (director): your three questions answered — last round

The director merged integration into this branch again (c00205b71). It brings the gait-01 scope-test fix, so rr-20's
PNG changes no longer trip it, and two decisions:

1. **`TODO_DESIGN_rear_far_apex_knee` (decided).** The director raised the Mimic's walk lift from 5 to 7 px
   (`staged/rr-20/motion_tracks.json`; import byte for byte). The long rear leg's swing knee then out-bends its stance
   knee at the apex.
   - Recompile and re-measure; report every swing's apex numbers.
   - If a swing still fails, report the numbers. Don't tune.
2. **`TODO_DESIGN_front_head_detached_source_texels` (decided by the new rig spec rule, §1 "Negative space vs
   holes").** A component that is already detached in the approved painting passes when it moves rigidly with its
   owner piece. The hair pixels `(105,48)` and `(105,49)` belong to `head`.
3. **`TODO_DESIGN_joint_continuation_rest_envelope` (decided by the same rule).** A pocket whose every pixel maps to
   air in the approved painting is negative space, not a hole. The neck pockets between the hair mass and the
   shoulders qualify where they map to rest-transparent space. Don't paint into transparent rest space, and keep the
   gait fill proposal inactive.
   - Implement the rule as rig spec §1 states it, in shared gate code if it isn't there yet. Keep it generic,
     additive and test-covered, with every rig's verdicts reported.
   - Report every pocket it passes, with its bounds. Any pocket that maps into painted area or tuck is a hole: fix it
     with own-piece continuations.
4. Then every gate passes headless in both views. List the exact windowed sequence. Focused tests only. This is the
   last round of this session.
