- **Medium — Windows cancellation can orphan Godot.** [stop_wrapper():58](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tools/program_suite_runner.py:58) terminates the Python wrapper. On Windows this bypasses its cleanup, and the [descendant watchdog is POSIX-only](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tools/godot_task_runner.py:165). A Windows-semantics experiment left the descendant alive. **Fix:** use a kill-on-close Windows Job Object or terminate the descendant tree before killing the wrapper; add a Windows cancellation test.

- **Medium — Actual storage and logs aren’t fully isolated across platforms.** [Child launches](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tools/program_suite_runner.py:42) use absolute executable paths, which bypass the [log injection condition](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tools/godot_task_runner.py:235) for `Godot`/`Godot.exe`. Additionally, [en02](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tests/en02_enemies_test.gd:9) and en04 execute persistence tests before namespace initialization. Unique environment strings don’t isolate Windows APPDATA or an inherited Linux XDG directory. **Fix:** initialize every child’s namespace before tests run, explicitly assign its log path, and test actual resolved paths.

- **Low — Extracted coverage can disappear unnoticed.** The [manifest guard](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tests/test_program_suite_runner.py:84) checks only the historical prefix. Removing both extracted domains still passed all 12 new tests. **Fix:** require both extracted programs in the complete ordered manifest.

- **Low — The deadline test doesn’t enforce its duration.** Doubling the scheduler’s budget survived the [budget test](/private/tmp/labyrinth_codex/review/qa-07-fb2fc0c34/tests/test_program_suite_runner.py:140). **Fix:** verify cancellation at the requested deadline using a controlled clock and a bounded cleanup allowance.

Verification found no assertion loss: **2,431 sites before and after**, byte-identical existing test bodies, and all **99 moved invocation lines** preserved in order. Independent presentation-message counting reproduced the combined **1,076,516 callbacks**; the fresh full run counted 1,076,515 with scheduling-dependent frame sampling.

The fresh full run passed all 25 children in **324.033 seconds**. Both focused suites passed (23 tests), and real macOS parent interruption left no child alive. Python discovery covered 682 cases; tool-dependent reruns passed, with 63 optional environment skips.

**Mutations: 8 caught, 2 survived.** Caught: ignored failures, excess concurrency, shared namespace, reversed logs, ignored script errors, missing timeout flag, dropped `await`, and ignored parent EOF. The two survivors are described above.

Docs and scope were checked; no new typed-array violations were found. Native Windows/Linux execution remains unverified. Every mutation was reverted; the checkout is clean.

CHANGES REQUESTED