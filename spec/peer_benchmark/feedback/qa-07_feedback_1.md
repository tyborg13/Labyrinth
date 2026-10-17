# qa-07 feedback 1 — peer review CHANGES on fb2fc0c34

Review: `spec/peer_benchmark/feedback/qa-07_review_fb2fc0c34.md` (integration branch). The speedup and the
assertion preservation are confirmed: 324 s, 2,431 sites, 1,076,516 callbacks. Fix all four findings:

1. **Windows cancellation orphans Godot.**
   - Put each child in a kill-on-close Job Object, or terminate the descendant tree before the wrapper.
   - Add a cancellation test that runs on POSIX and that uses the Windows path's logic under a simulation where real
     Windows isn't available.
   - Document which parts are verified natively.
2. **Storage and log isolation.**
   - Assign every child its log path explicitly, including absolute `Godot`/`Godot.exe` executables.
   - Initialise each child's namespace before any test runs, which fixes en02 and en04 persisting before init.
   - Isolate APPDATA (Windows) and XDG dirs (Linux) per child, not only HOME.
   - Add a test that asserts the resolved user-data and log paths per child are distinct.
3. **Extracted coverage guard.** The manifest test must require the complete ordered manifest, including both
   extracted programs. Removing either must fail.
4. **Deadline test.** Use a controlled clock. Cancellation must happen at the requested deadline within a bounded
   cleanup allowance, and doubling the budget must fail the test.

Re-run the runner tests and three full Godot runs (report the wall times), plus the Python suite.
