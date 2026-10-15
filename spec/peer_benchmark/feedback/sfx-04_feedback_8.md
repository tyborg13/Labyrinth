# sfx-04 — round 8 (Codex delta review of 9c2b0cd1e: one medium test gap)

Work on top of 9c2b0cd1e. Do not commit. Full review: /private/tmp/labyrinth_codex/review/sfx-04-9c2b0cd1e.md.

**Medium — the new blink re-arm guard lacks regression coverage.** Replacing [the guard](/private/tmp/labyrinth_codex/review/sfx-04-9c2b0cd1e/scripts/sfx_cue_router.gd:342) with `if true` passes the shipped harness. Its [blink fixtures](/private/tmp/labyrinth_codex/review/sfx-04-9c2b0cd1e/tests/sfx_sync_harness.gd:219) stop before the caller’s final board submission.

Adding that submission passes current code but catches the mutant: blink and illusion-swap each play twice, producing four failures and second peaks approximately **298 ms after arrival**. [Reproduction and results](/private/tmp/labyrinth_codex/review/sfx-04-9c2b0cd1e/output/sfx/review-r67/rearm-results.json).

**Fix:** extend the permanent fixtures through the final after-state presentation, beyond the cooldown, and assert exactly one request and successful playback.


Fix: extend the blink fixtures through the caller's final board submission so the re-arm guard is exercised; the 'if true' mutant must fail. Proof: harness, bank tests, full suite.
