- **Medium — staged startup skips the arrow fix.** [run_scene.gd:1947](/private/tmp/labyrinth_codex/review/det-01-2c94e72b4/scripts/run_scene.gd:1947) connects the signal after the staged-startup early return. Menu loading requests that staged path, whose jobs omit this connection. The [reviewer reproduction](/private/tmp/det01-review/staged-failure.log) reports `CONNECTED=false` and a **4 px endpoint error**. Adding the connection makes the same fixture pass. The existing regression uses direct startup. **Fix:** register the connection idempotently in shared startup code and test both startup paths.

- **Low — unrelated scope changes.** [STATUS.md:25](/private/tmp/labyrinth_codex/review/det-01-2c94e72b4/spec/peer_benchmark/STATUS.md:25) rewrites roster and Blender scheduling unrelated to det-01. Split those edits from this unit.

Review evidence:

- Reproduced both original failures on old code. Audio published synchronously while cancellation remained pending; the arrow retained geometry sampled before board movement.
- **Mutation results: 5 caught, 0 survived:** audio guard removal, warm-cache bypass, signal removal, cached-endpoint rollback, and combined arrow rollback.
- **40/40 focused runs passed under load**, alongside six CPU load processes.
- Scheduler tests: 28 passed; UI lint tests: 25 passed; registration audit passed.
- Multi-path audio and all five candidate endpoint kinds passed. No new typed-array violations, production tunables, dead code, stray files, or signal-lifetime problems found.

Full suites were not independently rerun. Every mutation was reverted; checkout is clean.

CHANGES REQUESTED