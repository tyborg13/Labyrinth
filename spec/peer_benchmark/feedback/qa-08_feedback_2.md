# qa-08 feedback 2 — qa-07 has landed: move the 116 supplemental programs onto its runner

The quarantine and guard work is accepted. I merged `codex/peer-benchmark` into your branch (46a4f5209). It brings
the qa-07 parallel runner (`tools/program_suite_runner.py` manifest + `tools/program_suite_runner.gd`), plus
boon-01, map-02 and cbt-01.

The conflict resolution dropped your old call in `tests/run_tests.gd`
(`preload("res://tests/helpers/supplemental_program_suites.gd").run(...)`), because qa-07 replaced that section with
`ProgramSuiteRunner.finish(...)`.

1. **Register through qa-07's runner.** Register the 116 supplemental programs so they run under qa-07's scheduler:
   - Use the same isolation: per-child namespace, logs and APPDATA/XDG, the 180 s per-child cap, and the 900 s total.
   - Respect qa-07's manifest guard (`tests/test_program_suite_runner.py`). Extend it so the supplemental set is part
     of the guarded manifest, rather than bypassing it.
   - Keep your completeness and quarantine guard working against the new registration.
   - Delete `supplemental_program_suites.gd` if it's no longer used.
2. **Runtime.** Report the full-suite wall time with all of them included, three runs.
   - Target ≤ 600 s on this machine with nothing else running; the 900 s cap still applies.
   - If it exceeds 600 s, raise the scheduler's concurrency to `min(6, logical_cpus // 3)`. This machine has 15
     logical CPUs, so 5.
   - Report the per-child maxima, which must stay under 110 s under load.
3. Re-run the guard tests and the Python suite.
