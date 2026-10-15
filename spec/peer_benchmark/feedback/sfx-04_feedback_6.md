# sfx-04 — round 6 (Codex delta review of df41875b4: CHANGES REQUESTED)

Work on top of df41875b4. Do not commit. Full review: /private/tmp/labyrinth_codex/review/sfx-04-df41875b4.md (reproduction and fixes are there).

1. **Blocking — composite relay moves lose or delay blink audio.** The trigger at [sfx_cue_router.gd:325](/private/tmp/labyrinth_codex/review/sfx-04-df41875b4/scripts/sfx_cue_router.gd:325) relies on logical `player.pos`, but movement segments retain the original state.
   - Walk → blink: **zero blink sounds** at all three speeds.
   - Blink → walk: peak arrives **531.697 / 365.027 / 281.692 ms late** at 1× / 1.5× / 2×.
   
   **Fix:** trigger at each relay’s actual destination submission, including position overrides. Add walk-before/after-relay fixtures with independently observed arrival times. [Reproduction](/private/tmp/labyrinth_codex/review/sfx-04-df41875b4/output/sfx/review-delta/relay-experiment.py), [results](/private/tmp/labyrinth_codex/review/sfx-04-df41875b4/output/sfx/review-delta/relay-summary.log).

2. **Medium — pause/hit-stop tests do not protect the new dispatch guard.** At [sfx_sync_bank_test.gd:176](/private/tmp/labyrinth_codex/review/sfx-04-df41875b4/tests/sfx_sync_bank_test.gd:176), the presentation clock stays before the deadline throughout both assertions. Removing [the guard](/private/tmp/labyrinth_codex/review/sfx-04-df41875b4/scripts/sfx_bank.gd:289) still passes the bank suite.
   
   **Fix:** submit an already-due cue while paused and during hit-stop; assert it remains queued and plays exactly once after resuming. My added fixture passes unchanged production and catches the mutant with four failures.

3. **Low — unused clock state remains.** [last_frame_usec](/private/tmp/labyrinth_codex/review/sfx-04-df41875b4/tests/sfx_sync_clock.gd:15) is assigned but never read. **Fix:** remove the declaration and assignment.


Proof: harness (fixed + variable frames, 1x/1.5x/2x) incl. a composite relay move scenario, bank suite with the guard mutant failing, full suite.
