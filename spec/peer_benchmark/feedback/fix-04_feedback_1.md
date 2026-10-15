# fix-04 — round 1 (Codex peer review of 2a330a699: runtime fix correct; one medium proof defect)

Work on top of 2a330a699. Do not commit. Full review: /private/tmp/labyrinth_codex/review/fix-04-2a330a699.md.

- **Medium — the probe never opens the intent details it claims to verify.** [Probe line 84](/private/tmp/labyrinth_codex/review/fix-04-2a330a699/tests/enemy_intent_continuity_probe.gd:84) calls the scene’s hover handler without updating the board’s hover state. My reproduction produced `board_hover=(-1,-1)`, `expanded=false`, an empty name, and zero rows. Actual board hover immediately produced “Lash of Thorns” and one row. All five existing captures omit expanded intent text. Meanwhile, [suite line 143](/private/tmp/labyrinth_codex/review/fix-04-2a330a699/tests/suites/enemy_intent_continuity_suite.gd:143) checks formatting helpers rather than the displayed layout. **Fix:** drive hover through the board, assert the resulting HUD name/rows/bounds, and regenerate an expanded-intent capture. [Reproduction log](/private/tmp/fix-04-review-probe-hover.log).

Root cause independently reproduced with the base engine: Thornwall leaves no eligible ranged choice, and the selector assigns `{}`. Weaver **remains scheduled**, but loses its intent presentation and takes empty turns using default Time. HEAD retains cancelled Lash at authored Time 5.

The differential experiment passed: **736 valid selections preserved intent and RNG state**, 32 fallback cases were deterministic, and 46 valid resolutions preserved realized outcomes. The 43-type invariant genuinely exercises activation and rescheduling; its displayed-detail coverage has the gap above.


Fix the probe so it drives the real board hover state and asserts the expanded intent details (name, rows, cancelled badge) for the Weaver after Thornwall; list the windowed probe command.
