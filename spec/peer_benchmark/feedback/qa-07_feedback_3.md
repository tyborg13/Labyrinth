# qa-07 feedback 3 — delta review CHANGES on 7c331a860 (fixtures + one runtime headroom risk)

Review: `spec/peer_benchmark/feedback/qa-07_review_7c331a860.md`. The runner itself is confirmed. Fix:

1. **Windows fixture cleanup (Medium).**
   - Skip dead processes and handle exit races, including `ERROR_ACCESS_DENIED` on terminated processes.
   - Guarantee unrelated-process cleanup in its own `finally`. No sleeper may survive the test.
2. **Flag guards (Low).**
   - Assert the Win32 values independently: `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE == 0x2000` and
     `CREATE_SUSPENDED == 0x4`.
   - Make the simulation honour the recorded flags, so setting either constant to 0 fails.
3. **Timeout fixture race (Low).** It errored 5 of 8 times. Give the stub its startup budget before requiring its PID,
   keep the controlled-clock deadline coverage, and run Python discovery 3 times clean.
4. **Headroom (new).** Under load the slowest child took 155.060 s against the 180 s cap; see the reviewer's
   `full-summary.json`. Split that child the same way as the presentation domain: target ≤ 110 s under load, with
   assertions preserved and counted. Check every child above 110 s under load and split it too.

Then show three consecutive green full runs under concurrent load with the per-child times, plus Python discovery.
This is the last planned round for this unit. If something else comes up, stop and report it rather than widening
scope.
