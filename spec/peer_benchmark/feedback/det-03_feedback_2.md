# det-03 feedback 2 (final round)

Round 1 is good (22/22 mutations). One remaining load flake of the kind this unit exists to remove:

1. `tests/suites/combat_action_pacing_suite.gd` ~172: the settle assertion (≤ 230 ms) failed 2 of 16 runs under the
   4-busy-loop proof. It measures real elapsed time. Convert it by the same rule 1 as the others (game clock: scheduled
   durations / delivered frame deltas; keep 230 ms as the bound, measured on the game clock; add the lower bound if the
   authored settle duration is known). Mutation: lengthen the settle past 230 ms of game time → fails.
2. Re-run the audit over `tests/suites/*.gd` for any other real-elapsed-time assertion the proof didn't exercise, and
   convert or list it.

Re-run only the suites you change (3 alone + 1 under 4 busy loops) and the repeat proof; report 16/16. No full suites.
