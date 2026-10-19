# gait-01 feedback 3 (director): two test gaps, then merge

The director's windowed re-runs at 798bedc07 all pass: Thrall native and review, Mirror production (948 frames, gait
production gates 0 errors). The Codex re-review found two regression gaps. Add these tests only; the runtime stays as
is unless a test exposes a real defect:

1. **Medium: fractional bind preservation.** `tests/gait01/presented_stance.gd:48` checks only consecutive-frame
   stability. Removing the bind anchor still passes, while the Mirror's far-foot bind shifts from 92.5 to 93.0 at zero
   travel. Assert both, including mirrored (reflected) presentation:
   - exact bind registration at zero travel;
   - integer, bind-relative translations.
   The anchor-removal mutation must fail.
2. **Low: opaque-target rejection.** `tests/test_gait01.py:281` corrupts only donor coordinates.
   - Add negative cases for opaque, duplicate and out-of-bounds targets, each using an otherwise valid donor recipe.
   - Disabling the transparent-target guard must fail. The re-review repainted the opaque `leg_far` texel `(1,37)`.
3. Focused tests only, then hand back. This is the last round of this unit.
