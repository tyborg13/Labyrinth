# fix-08 — The blocked-input explanation survives a frame stall

## Header
- When the guided tutorial blocks an input, `scripts/contextual_combat_prompt.gd` shows a short explanation for 900 ms
  of wall clock (`_blocked_until_msec = Time.get_ticks_msec() + 900`, lines ~149/166/216).
  - A frame stall (loading, a shader compile, a busy machine) can use up those 900 ms before the explanation is ever
    drawn. The player then never sees why their input did nothing.
- det-03 round 3 (commit `1b03a95c7`, not landed: det-03 was reverted and det-04 relanded the rest) already fixed it,
  together with a clock suite and a probe:
  - the explanation counts from its first drawn frame, on capped unscaled frame time;
  - it hides at the same frame a steady 60 fps would, with the parent prompt's pulse phase matched.
- Base `codex/peer-benchmark`. Risk tier: low. Owned:
  - `scripts/contextual_combat_prompt.gd`;
  - `tests/suites/contextual_combat_prompt_clock_suite.gd`;
  - `tests/helpers/blocked_prompt_clock_probe.gd`;
  - the touched test helpers;
  - `tests/suites/guided_combat_tutorial_suite.gd`.

## Change
1. Port `1b03a95c7`'s `contextual_combat_prompt.gd` change and its tests onto today's code. Keep det-04's helpers as
   they are now. Where today's file has moved on, keep today's behaviour and add only the timing change.
2. The visible behaviour is unchanged at a steady 60 fps:
   - the same 900 ms, which is 54 frames;
   - the same hide frame and pulse.
   Under a stall, the explanation shows for its full duration once drawn.
3. No other wall-clock reads in player-facing code. Report any you find, with file:line; don't fix them here.

## Proof
- A regression test that fails on today's code: a long first frame skips the explanation entirely. It passes after.
- A steady 60 fps test: the same hide frame as today.
- The guided tutorial suite and the clock suite pass. Focused only.

## Out of scope
- Other timing code. Tutorial text and layout.
