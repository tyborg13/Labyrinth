# fix-16 — fix_12_test fits the program suite's timeout

## Header
- At the joint merge of fix-12, fix-14 and fix-15 (integration 0b71b528f), the full Godot suite failed one program:
  `fix_12_test` timed out at the program runner's global 180 s limit (`tools/program_suite_runner.py`,
  `SUITE_TIMEOUT_SECONDS`) under the suite's parallel load. Log: `/private/tmp/labyrinth_codex/merge_rr-39_godot.log`
  (search for `fix_12_test`). It has grown across three units (popup totals, reactions, cascades, Defiance,
  newborns, journal). Every other fix-12/fix-14 program passed.
- Base `codex/peer-benchmark` (1dbcd8fda). Risk tier: low. Owned: the fix-12, fix-14 and fix-15 test programs and their
  suites, `tests/headless_test_programs.json`, and `tests/test_program_suite_runner.py` (pins).

## Change
1. Split `fix_12_test` into shards so each one runs in **≤ 60 s alone** on this machine. That leaves headroom under the
   suite's parallel load. Every check must remain; the same assertions must cover the same cases.
2. Register the shards in `tests/headless_test_programs.json` (appended last) and pin them with a
   `POST_SNARE_PROGRAMS += [...]` line in `tests/test_program_suite_runner.py`, replacing `fix_12_test`'s pin.
3. Report each shard's solo runtime and the total check count before and after (they must be equal).

## Proof
- Every shard PASS with its runtime; the summed checks equal the old total; `tests.test_program_suite_runner` OK.
- Don't change the global timeout.
