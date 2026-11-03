# det-03 — Timing tests that don't flake under load

## Header
- **Why.** Several Godot suites assert on real elapsed time, so they can fail when the machine is busy (det-02 and
  qa-13 were this kind; det-01 found two of them hid real product bugs). The audit found these elapsed-time
  assertions:
  - `tests/suites/attack_sfx_suite.gd` ~294 (reward reveal `< 1250` ms);
  - `tests/suites/combat_pacing_regression_suite.gd` ~117, ~123 (`< MOVE_ONLY_MAX_SECONDS`), ~143-144 (elapsed ≤
    seconds + `WAIT_TOLERANCE_SECONDS`);
  - `tests/suites/combat_enemy_action_clock_suite.gd` ~58-62 (two-sided window on real elapsed time);
  - `tests/suites/combat_feel_suite.gd` ~143-148 (130 ms ± `REAL_WAIT_TOLERANCE_MS`);
  - `tests/suites/run_sfx_suite.gd` ~84-88 (+0.30 s), ~113-117 (+0.35 s);
  - `tests/suites/movement_undo_suite.gd` ~242-249 (a 0.06 s wall sample must see the fade mid-way);
  - `tests/suites/guided_combat_tutorial_suite.gd` ~303 (`blocked_until > Time.get_ticks_msec()`);
  - performance budgets: `tests/suites/enemy_tactical_ai_suite.gd` ~181-182 (`total_usec < 250000`),
    `tests/suites/relic_u7_suite.gd` ~437-441 (best of 3 `< 40000` µs).
  Deadline polls that only bound a wait (e.g. `combat_motion_timing_suite.gd` ~42/84/104/121) are watchdogs, not
  timing assertions.
- **Base:** `codex/peer-benchmark`. **Risk tier:** low (tests), standard if production code changes.
- **Owned:** the suites above, `tests/helpers/` (a shared test clock helper if useful), and production code only under
  rule 2.

## Change (decided)
1. **Presentation timing checks** (pacing, enemy action clock, feel waits, run/attack SFX, movement undo fade,
   tutorial block): assert on the game's own clock: the scheduled durations, timer `wait_time`s, tween durations, and
   the frame deltas the presentation actually received (as det-02 did for the health ghost), or drive the code with an
   injected delta. Keep each assertion's intent and its numbers (the 130 ms wait is still 130 ms, measured on the game
   clock). Never widen a tolerance to make a test pass.
2. **If production code itself reads wall time** (`Time.get_ticks_*`, `OS` time) for something a player sees, report
   it with file:line. Never edit `scripts/run_scene.gd` in this unit (another unit owns it); report those only.
   Elsewhere, change it only when the fix makes it frame-delta driven with identical timing at a steady 60 fps,
   and list each such change separately in the result.
3. **Performance budgets** keep their numbers. Take the minimum of 5 runs (relic_u7 goes from 3 to 5), and where the
   code exposes a deterministic work counter (e.g. plan nodes evaluated), also assert that counter's budget.
4. **Watchdogs** that only bound a wait: raise any below 5000 ms to 10000 ms, and make each timeout fail with a
   message naming what it waited for. `ui_button_feedback_suite.gd` ~159 (110 ms): classify it (window or watchdog)
   and treat it by rule 1 or 4.
5. Re-run the audit (`Time.get_ticks_`, `OS.get_ticks`, `Time.get_unix_time`) over `tests/suites/*.gd` and list any
   assertion this brief missed; fix those by the same rules.

## Proof
Each changed suite: 3 passes alone, then 1 pass under load: the suite runs while 4 CPU busy loops
(`python3 -c 'while True: pass'`) run for its duration; stop them afterwards. Report the timings. Mutation per
converted check: break the timing it guards (e.g. double the wait) → the test fails. No full suites.

## Out of scope
Changing any player-visible timing, pacing numbers or combat speed settings.
