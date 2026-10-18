# qa-08 feedback 4: review fixes (review db2a234fe) + map timing determinism

The review is in `spec/peer_benchmark/feedback/qa-08_review_db2a234fe.md` in the integration worktree. Your branch
already has the director's merge and fix commits (HEAD db2a234fe); work on top.

1. **Function-local aliases (Medium).** Resolve `var`/`const` aliases declared inside a function only within that
   function, separately from class-level constants. Add the reviewer's regression: `_initialize()` loads suite A, and an
   uncalled function declares the same local name for suite B. B must stay unregistered.
2. **String contents are not calls (Medium).** Tokenize GDScript so that string literals and comments never yield call
   edges. Add regressions for a quoted inline call and a quoted alias call (`print("Ghost.run()")` with an unused
   `Ghost` preload).
3. **Inferred aliases (Low).** Support `var suite := load(...)` (and `const X := preload(...)`), next to explicitly
   typed and untyped aliases. Test all three.
4. **Fixture modes are pinned (Low).** `test_program_suite_runner` asserts each supplemental fixture's exact required
   mode (for example `cutout_pack` for every cutout pack test). Changing Bile Bloomer to `script` must fail.
5. **Runtime preload path (Low).** Add a unit test that the fixture bootstrap uses `res://scripts/parallel_runtime.gd`
   when the stage project is the repository root, and the absolute path only for foreign stage projects (the
   director's fix in `program_suite_fixture.py`). The absolute-in-root form broke every pack test on the director's
   machine, with a duplicate `ParallelRuntime` class.
6. **Map timing determinism (from STATUS follow-up; the reviewer hit it too, 259 ms against 250 ms under load).**
   - In the committed section-map performance program, replace the wall-clock per-section assertion with the
     deterministic budget fix-05 introduced: the search-node count stays within the type-assignment node budget, and
     the fallback rate stays within its limit. Keep every other check.
   - Keep the wall-clock limits (≤ 250 ms per section, ≤ 1.0 s per run) in the 2,000-seed sweep tool only, as fix-05
     specified.
   - Report the node-count maxima for the committed seeds.

Proof:
- the focused audit and runner tests, with mutation results for items 1–5;
- the full Godot suite through the parallel runner, plus the Python suite, run concurrently once to show load
  tolerance.

Don't change quarantine entries (bug-02 stays quarantined), partitions or any test assertions beyond item 6.
