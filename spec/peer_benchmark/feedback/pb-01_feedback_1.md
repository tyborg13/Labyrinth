# pb-01 — round 1 (Codex peer review: CHANGES REQUESTED + owner copy decision)

A. Owner decision 2026-10-16: the pre-battle shows ONLY the heading `OBJECTIVE · <TITLE>` for every objective — no second line. The one-line rule texts (kill_all "Defeat every enemy.", kill_leader "Defeat the marked leader. The rest flee.", survive "Survive until the marked time.", reach_exit "Reach a marked door to escape.") move to the heading's hover tooltip (existing tooltip style; keyboard/controller focus shows it too). Update tests.

B. Fix the three test-coverage findings as the reviewer proposes (full review: /private/tmp/labyrinth_codex/review/pb-01-2d8c89100.md):
1. **Renderer identity is not verified.** [Line 63](/private/tmp/labyrinth_codex/review/pb-01-2d8c89100/tests/suites/pre_battle_living_foes_suite.gd:63) checks only whether a renderer exists. Routing Noctyrax to Crawler’s renderer survives. **Fix:** compare each instantiated renderer’s Script against its expected board renderer, including Guardian `character_id`.

2. **Motion tests bypass automatic processing.** [Line 79](/private/tmp/labyrinth_codex/review/pb-01-2d8c89100/tests/suites/pre_battle_living_foes_suite.gd:79) calls `_process` directly. Disabling processing globally—or only for Noctyrax—survives. Noctyrax is absent from the capture rosters. **Fix:** let SceneTree drive frames and assert each rigged identity’s phase advances naturally, then freezes when hidden or reduced motion is enabled.

3. **Phase tests never initialize a renderer.** [Line 104](/private/tmp/labyrinth_codex/review/pb-01-2d8c89100/tests/suites/pre_battle_living_foes_suite.gd:104) inspects configured metadata outside the tree. Removing the actual `_idle_seconds` seed survives. **Fix:** instantiate six identical foes and verify their actual renderer phases are distinct and deterministic across rebuilds.

All five surviving mutations in the table must now fail. Focused tests + full suite once; re-run the 13-capture probe (contract expected_sizes now "1920x1080"). Do not commit.
