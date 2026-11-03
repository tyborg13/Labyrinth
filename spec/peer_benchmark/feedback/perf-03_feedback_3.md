# perf-03 feedback 3 (final round; from the re-review of 3fce860e7)

The earlier durability faults pass now. Two items:

1. **High: transitions on a failed flush must behave exactly as the old synchronous code did.** The review saw Exit to
   Desktop, Save & Quit and Continue proceed after a flush failure, losing pending checkpoint 701 (restart loaded 700).
   Find what the parent (`codex/peer-benchmark` before perf-03) did when the same checkpoint write failed at commit:
   what it logged or showed, whether the transition proceeded, and what was on disk afterwards. Make HEAD's
   transitions match it exactly when the flush fails. Prove it with a differential test that injects the same storage
   failure into the parent's synchronous path and HEAD's deferred path, for Exit to Desktop, Save & Quit, Continue, run
   end and new run, and compares the outcomes. If the parent also lost the checkpoint and proceeded, HEAD may do the
   same. Don't invent new UI.
2. **Medium: the 0.5 s cap wins.** Consecutive resolution frames delayed writes up to 756 ms. Once a queued write is
   0.5 s old, run it on the next frame even if that frame is resolving an action (one checkpoint or one analytics batch
   per frame). Regression: a scripted run of back-to-back resolution frames, where no write waits more than 0.5 s plus
   one frame.

Re-run the durability injections, the new differential test, save pipeline, analytics, equivalence and controls.
No full suites.
