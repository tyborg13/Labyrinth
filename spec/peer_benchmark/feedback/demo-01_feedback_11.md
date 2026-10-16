# demo-01 — round 11 (delta review of 051a1badc: CHANGES REQUESTED)

Fix both findings as the reviewer proposes (full review: /private/tmp/labyrinth_codex/review/demo-01-051a1badc.md):
1. **Medium — repeated cues still produce false sync measurements.** [sync.py:116](/private/tmp/labyrinth_codex/review/demo-01-051a1badc/tools/demo_clips/sync.py:116) rejects ambiguity unless correlations are nearly equal. Adding another sound over the first correctly aligned hit makes both rows select the second occurrence, falsely reporting **+115 ms**. Fix: reject any distinct identifiable competing match, or assign occurrences uniquely. Add the mixed-audio regression.

2. **Low — thread-option removal escapes the regression.** [test_demo_clips.py:156](/private/tmp/labyrinth_codex/review/demo-01-051a1badc/tests/test_demo_clips.py:156) checks flag values without requiring their presence. Removing every PCM thread option survives all **52 tests**. Assert required flags and counts before checking values.

Focused tests only; do not commit.
