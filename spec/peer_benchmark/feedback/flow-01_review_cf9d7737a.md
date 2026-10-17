1. **Blocking — Older cleared-boss saves can become stuck after an entry-save failure.** [section_transition.gd:325](/private/tmp/labyrinth_codex/review/flow-01-cf9d7737a/scripts/section_transition.gd:325) restores `{}` when `section_transition_reward` is absent. Reproduction: save `Run.continue_dragon_reward(Suite.fixture())`, load it, block the destination write, then finish reversal. Result: `mode="reward"`, empty `pending_reward`, no CONTINUE button; quit/resume preserves the broken state. See [reproduction log](/private/tmp/flow-01-review-legacy.log). **Fix:** reconstruct or migrate the already-claimed summary before transitioning older saves, without granting rewards, and cover failure → retry and failure → quit → resume.

2. **Medium — Tests miss repeated music handoffs and changes to the exact notice.** [section_transition_suite.gd:137](/private/tmp/labyrinth_codex/review/flow-01-cf9d7737a/tests/suites/section_transition_suite.gd:137) checks handoffs before the remaining reveal; line 143 only checks track identity. Removing the `_entered` guard passes, although a temporary post-reveal assertion observes **two arrivals instead of one**. [Line 235](/private/tmp/labyrinth_codex/review/flow-01-cf9d7737a/tests/suites/section_transition_suite.gd:235) compares the notice against its production constant, so changing that constant also passes. **Fix:** assert handoff/playback-start counts after completion and deferred callbacks, and compare the notice against the independently specified literal.

3. **Medium — Dead references to the removed control remain.** [section_map_review_probe.gd:23](/private/tmp/labyrinth_codex/review/flow-01-cf9d7737a/tests/section_map_review_probe.gd:23) reads removed `_continue`; subsequent assertions dereference it and expect “Next section.” [section_map.md:167](/private/tmp/labyrinth_codex/review/flow-01-cf9d7737a/spec/section_map.md:167) still documents that control. **Fix:** update the probe to exercise automatic transition and subsequent history navigation, and update the specification.

4. **Low — The demo still displays a cursor during the title card.** [section_transition.gd:112](/private/tmp/labyrinth_codex/review/flow-01-cf9d7737a/tools/demo_clips/section_transition.gd:112) hides the native pointer, but the game’s cursor glyph has separate visibility handling. It remains visible in supplied `director_r1/v_sheet2.png` frames. **Fix:** use `CursorFeedback.set_glyph_visibility_suppressed()` during capture, restore it on completion/exit, and recapture.

Mutation results against the supplied suite:

| Mutation | Result |
|---|---|
| Remove 0.40-second skip gate | Caught |
| Ignore failed destination save | Caught |
| Remove one-time arrival guard | Survived |
| Remove already-entered section guard | Survived |
| Remove claimed-reward retry bypass | Survived |
| Remove destination validation | Survived |
| Change exact failure-notice punctuation | Survived |

The temporary post-reveal assertion passed on HEAD and caught the arrival mutant. [Mutation results](/private/tmp/flow-01-review-mutation-results.json).

Reviewed all 16 changed files and supplied director captures. Transition and start-room-map suites passed; UI lint passed 25 tests; clip-tool checks passed four. Focused coverage passed reward preservation, modern-save retry/resume, skip inputs, reduced motion, final ascent, and additive analytics. No new Windows typed-array violation, misplaced gameplay tunable, or unrelated scope expansion found.

The known `dragon_rewards_test.gd:159` failure and serial-suite budget issue remain excluded as instructed. All experiments were reverted; checkout is clean at `cf9d7737a9e7918a6689b5a9466d36429970d24e`.

CHANGES REQUESTED