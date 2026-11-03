# det-03 feedback 3 (final round; from the re-review of b560e49a5, evidence /tmp/det-03-review-rereview: /tmp/det-03-rereview/review.md)

The tests are good now (every earlier survivor caught). Fix the production prompt change so it matches the parent
exactly in normal play:

1. **Medium: same frame as before at 60 fps.** `scripts/contextual_combat_prompt.gd` (~187) hides on frame 55 where the
   parent hid on frame 54 when input arrives before process/draw. Align the first-frame accounting, and add a direct
   test that runs the parent's timing model and the new one side by side at a steady 60 fps (input before and after
   process/draw) and asserts the same hide frame and the same pulse phase.
2. **Medium: real time, not game speed.** (~194) The new code accumulates scaled delta, so at 2x combat speed the
   explanation lasts ~450 ms and pulses twice as fast. The parent used wall time, which ignores game speed. Accumulate
   unscaled frame time (delta / Engine.time_scale when time_scale > 0), still capped at 0.1 s per frame and starting
   at the first drawn frame. Test at 1x and 2x: same visible duration (900 ms) and pulse rate.
3. **Low: three surviving guard mutations** in `tests/suites/guided_combat_tutorial_suite.gd` (~335): removing the
   first-draw protection, doubling the pulse rate and ignoring reduced motion must each fail.
4. **Low:** `tests/helpers/timing_suite_proof.py` (~94) crashes on an external `--output-dir`; serialize paths safely.
   Remove the write-only `scheduled_seconds` accumulator from `tests/helpers/presentation_test_clock.gd`.

Re-run only the tutorial suite, the prompt tests and the proof helper (alone + once under 4 busy loops). No full suites.
