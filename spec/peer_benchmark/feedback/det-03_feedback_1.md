# det-03 feedback 1 (from the Codex review of ec540eb59; evidence /tmp/det-03-review/review.txt)

1. **Medium: run_sfx lost completion coverage.** `tests/suites/run_sfx_suite.gd` ~80 records the authored animation
   duration and ~108/~140 sum requested timers, so ending the door animation immediately or dropping the `await` on the
   victory hold now passes (the original tests failed). Measure the presentation time actually delivered and that each
   timer completed, keeping the existing bounds. Both mutations must fail.
2. **Use the game clock to close the old one-sided gaps.** Now that these checks are deterministic, make them two-sided
   where the authored duration is known: door settle, surface lifetime, button cooldown, and the two combat_feel
   survivors (skipping the settle, halving the lifetime/cooldown must fail). Same numbers; add the lower bound only.
3. **Production fix (rule 2 allows it; not run_scene.gd): the blocked-input explanation can vanish unseen.**
   `scripts/contextual_combat_prompt.gd` ~149/166/215: call `show_blocked()`, stall 950 ms before the next render, then
   one 16.667 ms update, and the 900 ms explanation is already hidden. Drive its lifetime and pulse from accumulated
   frame delta with each frame's delta capped at 0.1 s, and count time only from the first frame it was actually drawn.
   Timing at a steady 60 fps must stay identical. Regression: that exact stall reproduction keeps it visible for at
   least 0.8 s of later frames; a steady-60-fps run hides it at the same frame as before.
4. **Low: rename the unit-named helpers by responsibility** (`tests/helpers/det_03_proof.py`,
   `tests/helpers/det_03_suite_driver.gd` → e.g. `timing_suite_proof.py`, `timing_suite_driver.gd`) and take the task
   id as a parameter. Update every reference and the `.uid` sidecars.

Re-run only the suites you change (3 alone + 1 under 4 busy loops, as before) and each mutation above. No full suites.
