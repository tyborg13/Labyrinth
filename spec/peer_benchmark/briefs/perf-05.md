# perf-05 — Shard perf/transition_failure_case under the runner budget

## Header
- `tests/perf/transition_failure_case.gd` (no args) shells out to `tests/perf/run_transition_differential.py`, which
  runs every transition case (save_quit, continue, run_end, run_end_victory, run_end_defeat, new_run and any others)
  for both the parent and the candidate. On an idle machine it takes 105–125 s of the program runner's single 180 s
  budget (`tools/program_suite_runner.py`). At the rr-40 integration merge it hit 180 s under concurrent Codex load
  and failed the suite; re-run alone it passed in 118.5 s.
- Same fix as fix-16 did for `fix_12_test`: shard it so every program stays well under budget.
- Base `codex/peer-benchmark`. Risk tier: low. Owned: `tests/perf/transition_failure_case.gd`,
  `tests/perf/run_transition_differential.py`, the program list entries for it in `tests/headless_test_programs.json`
  and `tests/test_program_suite_runner.py`, and a small test.

## Change
1. Add a case filter to the driver (e.g. `--cases=save_quit,continue`), passed through from the Godot program's user
   args. With no filter, it still runs everything, for manual use.
2. Replace the single program entry with shards whose idle runtime is each ≤ 45 s (measure; aim for 3–4 shards). Each
   shard prints its own `PERF03 TRANSITION DIFFERENTIAL RESULT`. Every case runs in exactly one shard.
3. Python test: the union of shard case lists equals the driver's full case list (a new case added to the driver
   fails the test until it is assigned to a shard), with no case in two shards.

## Proof
- Each shard's idle runtime and result, the old single-program runtime for comparison, and the Python test.
  Focused only; the director runs the full suites at merge.

## Out of scope
- The transition behaviour and its assertions; any other perf program.
