# vfx-01 — round 5 (Codex peer review of 54454a73d: two medium test gaps)

Work on top of 54454a73d. Do not commit. Full review: /private/tmp/labyrinth_codex/review/vfx-01-54454a73d.md (read it for the exact fixes).

1. **The draw-time core fade guard can regress undetected.** Both fade fixtures use a transparent halo ([unit test:412](/private/tmp/labyrinth_codex/review/vfx-01-54454a73d/tests/pixel_fx_test.gd:412), [render probe:383](/private/tmp/labyrinth_codex/review/vfx-01-54454a73d/tests/pixel_fx_render_probe.gd:383)). The early stroke filter therefore hides failures in the separate [core cutoff:30](/private/tmp/labyrinth_codex/review/vfx-01-54454a73d/scripts/pixel_fx_lines.gd:30). Changing that cutoff to `core.a > 0.0` still passes all 11,672 checks. My mixed-alpha experiment produces an erroneous opaque core at source alpha `0.2999` with halo alpha `0.5`. **Fix:** add a case with the core below the floor and halo above it; assert that halo drawing survives while core coverage is empty. [Reproduction output](/private/tmp/vfx-01-review-mixed-fade-mutant.log).

2. **The cleanup test checks detachment, not destruction.** The [lifetime assertion:424](/private/tmp/labyrinth_codex/review/vfx-01-54454a73d/tests/pixel_fx_test.gd:424) accepts null references and zero children. Removing [`viewport.queue_free()`:98](/private/tmp/labyrinth_codex/review/vfx-01-54454a73d/scripts/pixel_fx_lines.gd:98) still reports PASS and exits zero, despite ten leaked viewport RIDs. **Fix:** retain instance IDs for the viewport, drawing and composite; after deferred deletion, assert they are invalid. Exercise repeated line→non-line and line→empty transitions. [Mutation log](/private/tmp/vfx-01-review-mutation-target_free.log).


Both mutants named there must fail the tests. Proof: pixel FX tests, render probe logic, full suite.
