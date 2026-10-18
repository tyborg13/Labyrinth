1. **Medium — dormant lambdas still register unexecuted suites.** [gdscript_test_calls.py:79](/private/tmp/labyrinth_codex/review/qa-08-fecdbf24e/tools/gdscript_test_calls.py:79) includes nested lambda bodies in the caller’s tokens. Reproduction: `_initialize()` executes A and stores an unused lambda that loads and calls B. The audit passes and credits both suites; native Godot executes only A, even with `assert(false)` inside B. **Fix:** preserve nested function scopes and follow lambda bodies only when invoked; add this regression.

2. **Low — StringName/NodePath arguments cause false negatives.** [gdscript_test_calls.py:121](/private/tmp/labyrinth_codex/review/qa-08-fecdbf24e/tools/gdscript_test_calls.py:121) requires an immediate string token, while prefixes remain separate symbols. Native fixtures execute `call_deferred(&"_run")`, `Callable(self, &"_run").call()`, and `load(^"res://tests/active_suite.gd").run()` successfully; the audit reports their suites as orphaned. **Fix:** recognize prefixed literals consistently in calls and aliases, with positive regressions.

3. **Low — Python decoding mishandles valid GDScript escapes.** [gdscript_test_calls.py:52](/private/tmp/labyrinth_codex/review/qa-08-fecdbf24e/tools/gdscript_test_calls.py:52) cannot decode GDScript’s six-digit `\UXXXXXX`. Native `load("res://tests/\U000061ctive_suite.gd").run()` executes `active_suite.gd`; the audit reports it orphaned. **Fix:** use GDScript-compatible escape decoding and add a regression.

The original quoted-call, named-function alias, inferred-alias, fixture-mode and absolute-runtime-path mutations are now caught. All 115 mode changes fail their guard. The dormant-lambda case survives.

Item 6 passes: excess-node and excess-fallback mutations fail; wall-time-only injection passes. All 23 prior non-wall assertion sites remain, and the unchanged 2,000-seed tool retains its timing limits.

Verification: **60 focused tests passed**. Concurrent full runs passed: Godot **349.25 seconds**, all **165 children**; Python **745 tests**, **63 skipped**, **549.77 seconds**. Map: **6,378 checks**, zero fallbacks; node maxima were 32 for seed 1792271957 and 40 for the other 20 seeds.

No additional material scope, tunable or Windows typed-array issue found. Experiments removed; checkout clean.

CHANGES REQUESTED