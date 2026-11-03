# perf-02 feedback 1

Good numbers. One required fix, and one check.

1. **`tests/suites/move_attack_approach_suite.gd` ~36 is in this unit's scope now.** It fails because it encodes the
   old key (the approach revision). Its intent still holds under the new contract: "the same enemy approached
   differently invalidates cached turn consequences". Rewrite that block so the scene has the card selected and the
   enemy as the hovered/target tile, and assert:
   - WEST entry vs SOUTH entry, which give different plans → different `_pass_preview_key(ENEMY)`;
   - two entries that give the same plan (or a re-entry from the same side) → equal keys;
   - an invalid entry → the same key as the default approach.
   Keep every other assertion in the suite unchanged. Run it through `tests/run_tests.gd`'s program that hosts it and
   through `tests/move_attack_approach_probe.gd` headless; both must pass.
2. **Check, add a test if missing:** the prewarm queue never starts or runs when no card is selected, during the enemy
   phase, during card resolution, or outside combat (`_invalidate_preview_derived_caches` now calls `restart` on every
   invalidation). One assertion per case in `pass_preview_prewarm_suite.gd`.

Re-run only: the new suite, the approach suite/probe, `tests/spx07_hover_benchmark.gd --fresh` (report the table again),
`full_scene_controls_program`. No full suites.
