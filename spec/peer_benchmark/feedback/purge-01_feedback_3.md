# purge-01 feedback 3 — regressions found at merge (final round)

The director merged cb60c77db into integration and ran the full suites. Two failures, both absent at the previous
integration commit (40e1a7093, where these suites passed). Integration has been reset to before the merge; your branch
is unchanged.

1. **SFX sync regression (deterministic; reproduced in isolation):**
   ```
   ERROR: Loop waits after its state change: ambience.tharokh   (12× in sfx_sync_0, 12× in _1, 6× in _2)
   SFX SYNC HARNESS RESULT: FAIL (1970 observations, 12 failures)
   ```
   Run: `python3 tools/program_suite_runner.py --task-id purge-sfx --suite suites/sfx_sync_0_program --result-file
   <file> --jobs 1` (and `_1`, `_2`). Find the root cause with evidence (an SFX sync trace on 40e1a7093 vs your HEAD):
   which purge-01 change delays the Tharokh ambience loop after its state change (e.g. the `run_scene.gd` hooks, the
   extracted pile dialog, an added await or deferred call in a shared path). Fix it in production code so the loop
   starts on its state change as before. Don't touch the SFX baseline or the harness.
2. **Registration audit:** `Unregistered headless test: tests/magic_deck_guard_mutation_test.gd` (Godot audit and
   `test_test_registration_audit`). Register it the way the repository registers standalone tests (both lists, see
   `tests/helpers/program_sub_suites.gd` and `tools/program_suite_runner.py`), or fold it into a registered runner.

Proof: all three `suites/sfx_sync_*_program` PASS, `python3 -m unittest tests.test_test_registration_audit`, the magic deck
tests, the text-fit test and the mutations. Rerun the windowed probe only if a visual file changes, and say so. This is
purge-01's last fix round.
