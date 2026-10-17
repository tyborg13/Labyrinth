- **Medium — Windows cleanup still orphans descendants when the root exits.** [Cleanup skips exited roots](/private/tmp/labyrinth_codex/review/qa-07-09f60c6d7/tools/godot_task_runner.py:114), and [taskkill failure is ignored once the root exits](/private/tmp/labyrinth_codex/review/qa-07-09f60c6d7/tools/godot_task_runner.py:107). Independent simulations reproduced both cases; `run_task_command` remained blocked beyond its timeout until manual descendant cleanup. [Reproduction](/private/tmp/qa-07-review-09f60c6d7/repro_windows_exited_root.log). **Fix:** own the Windows tree through a kill-on-close Job Object from launch, and test both exit timings. Current taskkill arguments target the owned PID and its tree; no broad image kill was found.

- **Medium — Three consecutive green full runs remain unmet.** Wall times were **349.758s FAIL**, **358.091s PASS**, and **322.989s PASS**. The failed trial killed the presentation program at 180.232s before its final assertion counter. [Failure log](/private/tmp/qa-07-review-09f60c6d7/full-1.log:870). **Fix:** optimize or split that domain while preserving assertions and the 180-second cap, then demonstrate three consecutive passes.

- **Low — The storage guard does not enforce namespace initialization.** [It checks distinct paths](/private/tmp/labyrinth_codex/review/qa-07-09f60c6d7/tests/test_program_suite_runner.py:287). Removing bootstrap namespace initialization still passed the native Godot fixture because separate HOME directories preserved distinct paths. **Fix:** assert the requested namespace before the fixture’s first persistence operation.

- **Low — The Windows simulation does not guard `/F`.** [The simulator always sends SIGKILL](/private/tmp/labyrinth_codex/review/qa-07-09f60c6d7/tests/test_runner_cancellation.py:82); removing `/F` survived. **Fix:** assert the complete owned-PID `/T /F` command and verify an unrelated process survives.

Verification: **31 focused tests passed; Python discovery passed 690 tests with 63 skips.** All 864 GDScript test files are byte-identical across the delta, preserving 2,431 harness assertion sites. Completed runs reproduced 1,076,516 and 1,076,515 callbacks, consistent with the known frame-sampling variation.

All three trials resolved 25 distinct namespaces and explicit engine logs. En02/en04 initialize before their suite bodies. Absolute executable logging and inherited APPDATA/XDG isolation passed.

**Mutations: 8 caught, 2 survived.** Caught: `/T` removal, either extracted program’s removal, doubled budget, old executable detection, inherited APPDATA, inherited XDG, and missing explicit child logs. Survivors are described above.

No new typed-array, misplaced tunable, scope, dead-code, or stray-file issue found. Native Windows/Linux Godot remains unverified. All experiments were restored; the checkout is clean.

CHANGES REQUESTED