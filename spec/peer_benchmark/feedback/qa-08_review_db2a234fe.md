1. **Medium — local aliases leak across functions.** [tools/test_registration_audit.py:110](/private/tmp/labyrinth_codex/review/qa-08-db2a234fe/tools/test_registration_audit.py:110) collects aliases from the entire file. In a native reproduction, `_initialize()` loads suite A while an uncalled function declares the same local name for suite B. The audit credits B as executed; Godot executes B zero times. **Fix:** resolve function-local aliases within their owning function, separately from inherited class constants, and add this regression.

2. **Medium — strings count as executed calls.** [tools/test_registration_audit.py:152](/private/tmp/labyrinth_codex/review/qa-08-db2a234fe/tools/test_registration_audit.py:152) scans string contents for calls. With an unused `Ghost` preload, `print("Ghost.run()")` makes the audit report Ghost’s suite as covered. Native Godot confirms its failing assertion never executes. **Fix:** recognize call expressions using string-aware tokenization; add regressions for quoted inline and alias calls.

3. **Low — valid inferred aliases are rejected.** [tools/test_registration_audit.py:48](/private/tmp/labyrinth_codex/review/qa-08-db2a234fe/tools/test_registration_audit.py:48) misses `var suite := load(...)`. My native fixture executes `suite.run()`, but the audit reports it orphaned. **Fix:** support `:=` and test both inferred and explicitly typed aliases.

4. **Low — fixture-mode preservation is not guarded.** [tests/test_program_suite_runner.py:159](/private/tmp/labyrinth_codex/review/qa-08-db2a234fe/tests/test_program_suite_runner.py:159) accepts any recognized mode. Changing Bile Bloomer’s mode from `cutout_pack` to `script` survives this guard. **Fix:** assert the required mode for each fixture path.

Mutation results:

- **Caught:** missing map partition, doubled deadline, passing quarantine, omitted namespace initialization, and `res://` runtime preload in the empty project.
- **Survived:** quoted calls, cross-function aliases, fixture-mode changes, and absolute runtime preloads everywhere. The absolute-path mutation did not reproduce the director’s duplicate-class failure here.

Verification:

- Python: **734 tests passed**, 63 skipped, 797.5 seconds. Focused audit/runner checks: **24/25 passed**.
- Full Godot: **564.5 seconds**, 165 children, maximum **99.47 seconds**. One unchanged map assertion failed at 259.487 ms against 250 ms while quarantine and Python ran concurrently; its focused rerun passed all **6,377 checks**.
- Slow quarantine flagged only the documented host-dependent `bug-02` test as passing here.
- All **98 scene invocations** remain; forced-movement checks total **17,426**. No partition assertion removal or Windows typed-array violation found. Native Windows remains unverified.
- Checkout clean at the reviewed HEAD; experiments restored.

CHANGES REQUESTED