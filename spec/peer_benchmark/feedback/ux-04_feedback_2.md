# ux-04 — round 2 (Codex peer review of 66c75a74a: CHANGES REQUESTED)

Work on top of 66c75a74a. Do not commit. Full review: /private/tmp/labyrinth_codex/review/ux-04-66c75a74a.md.

1. **Medium — Skill duration tooltips still describe Time.** [data/skills.json:583](/private/tmp/labyrinth_codex/review/ux-04-66c75a74a/data/skills.json:583), also lines 604 and 683, retain `@icon(time)` for Long Dawn, Sunpath, and Afterglow durations. The Abilities popup reads these descriptions at [run_scene.gd:11852](/private/tmp/labyrinth_codex/review/ux-04-66c75a74a/scripts/run_scene.gd:11852). Headless hit-testing reproduced Time tooltips for all three. **Fix:** use their approved glossary wording in skill details; any retained duration icon must resolve to Turns. Add coverage for these three skills.

2. **Medium — Unknown-token coverage has a parser mismatch.** [text_budget_test.py:8](/private/tmp/labyrinth_codex/review/ux-04-66c75a74a/tests/text_budget_test.py:8) and [glossary_coverage_suite.gd:100](/private/tmp/labyrinth_codex/review/ux-04-66c75a74a/tests/suites/glossary_coverage_suite.gd:100) recognize fewer key characters than the renderer. Appending `@kw(review.missing_key)` to Quick Stab’s description passed both coverage checks, while rendering retained the invalid token literally. **Fix:** align validation with the renderer’s token grammar and reject malformed tokens explicitly; add punctuation/whitespace cases.

3. **Low — Orphaned preloads remain.** `SkillTreeLibrary` is now unused in [action_icon_library.gd:7](/private/tmp/labyrinth_codex/review/ux-04-66c75a74a/scripts/action_icon_library.gd:7) and [glossary_test.gd:14](/private/tmp/labyrinth_codex/review/ux-04-66c75a74a/tests/glossary_test.gd:14). **Fix:** remove both preloads.


Proof: budgets, glossary tests and coverage suite, text probe logic, full suite.
