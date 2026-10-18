# det-02 — Deterministic health-ghost clock test

## Header
- **Bug.** `tests/suites/health_ghost_suite.gd` (~lines 157–162) checks that combat speed scales the ghost clock by
  comparing the tracker's accumulated `elapsed` with wall-clock time (`Time.get_ticks_usec()`) × `Engine.time_scale`,
  within `CLOCK_TOLERANCE_SECONDS`. It failed once under load in the integration suite (after det-01, with rr-07
  running alongside) and passes 3/3 alone.
- **Root cause to confirm.** The tracker accumulates per-frame process deltas; the wall clock also counts time between
  frames and the timer's late wake-up. Under load one long frame lands on one side of the measurement and not the
  other. Confirm this with a reproduction before fixing (e.g. a forced long frame around the timer edge).
- **Base:** `codex/peer-benchmark`. **Owned:** `tests/suites/health_ghost_suite.gd` and a test helper if needed.
  `scripts/health_ghost_tracker.gd` only if the test can't observe the deltas otherwise (keep production behaviour
  identical).

## Change
1. Replace the wall-clock comparison with one against the frame deltas the tracker actually received: either sum the
   scaled process deltas over the same frames with a probe that runs in the same frame order, or drive the tracker's
   presentation clock with injected deltas in the test. Keep the property being tested: elapsed scales with
   `Engine.time_scale`, and hit-stop (`time_scale` 0) freezes it.
2. Audit the rest of `health_ghost_suite.gd` for other wall-clock or timer-edge assertions and make them
   deterministic the same way. List what you changed.
3. Regression: a check that fails with the old comparison under a forced long frame and passes with the new one.

## Proof (headless)
- The health ghost suite alone, 5 runs in a row, all PASS; plus the forced-long-frame regression.
- Don't run the full Godot or Python suites; the director runs them at merge.

## Out of scope
Other suites, other wall-clock tests (list any you notice), production behaviour.
