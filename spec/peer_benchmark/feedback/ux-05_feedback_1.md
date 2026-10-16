# ux-05 — round 1 (Codex peer review of 17630b1d8: CHANGES REQUESTED)

Fix all three findings as the reviewer proposes (full review: /private/tmp/labyrinth_codex/review/ux-05-17630b1d8.md; evidence /private/tmp/ux05_review_evidence.md):

1. **Blocking — hidden traps affect retained bodies.** [combat_preview_retention.gd:17](/private/tmp/labyrinth_codex/review/ux-05-17630b1d8/scripts/combat_preview_retention.gd:17) restores positions using the actual forecast. In heart Umbra, Unsealed Gale pushes a crawler from `(3,3)` toward `(6,3)`. Adding an unseen lethal trap at `(5,3)` makes the displayed crawler return to `(3,3)`, although the filtered forecast reports no damage. **Fix:** derive retention from the information-safe forecast, including intermediate action prefixes.

2. **Medium — lethal illusion ghosts bypass destination visibility.** [run_scene.gd:34508](/private/tmp/labyrinth_codex/review/ux-05-17630b1d8/scripts/run_scene.gd:34508) lacks the enemy ghost’s visibility guard. Hollow Puppet + Skybreak Current produces a marked illusion ghost at unseen `(8,3)` after a lethal wall collision. **Fix:** apply the same committed-sight guard and add this regression.

3. **Low — illusion privacy guard lacks regression coverage.** Removing that filter survives the focused suite. [destruction_preview_suite.gd:141](/private/tmp/labyrinth_codex/review/ux-05-17630b1d8/tests/suites/destruction_preview_suite.gd:141) checks hidden traps and enemy destinations, but not hidden illusion losses. **Fix:** assert that a concealed illusion’s damage key is absent.

Each fix needs a regression that fails before. Focused tests + full suite once; re-run the 12-capture probe command list. Do not commit.
