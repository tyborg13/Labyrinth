1. **Blocking — merged map generation can freeze New Game.** [section_map_graph.gd:287](/private/tmp/labyrinth_codex/review/flow-01-63c1f11ba/scripts/section_map_graph.gd:287) remains in Section II type assignment for seed `1792271957`: the unmodified production call [times out after 300 seconds](/private/tmp/flow-01-review-seed-trace.log). Instrumentation reaches 671,000 search nodes; the pre-merge generator finishes the same fixture in 1.74 seconds. Generation runs synchronously during startup. **Fix:** improve pruning or memoize failed assignments, and add this seed as a performance regression case.

2. **Medium — legacy recovery displays internal placeholders.** [section_transition_reward.gd:37](/private/tmp/labyrinth_codex/review/flow-01-63c1f11ba/scripts/section_transition_reward.gd:37) supplies `TODO_DESIGN_LEGACY_REWARD_PAYOUT` and `TODO_DESIGN_LEGACY_REWARD_SHARDS` directly to visible labels. [Reproduction](/private/tmp/flow-01-review-legacy-no-offer.log): load an old save without its offer event, fail entry persistence, then finish reversal. CONTINUE works, but both placeholders appear. **Fix:** use finished fallback copy or omit unavailable totals, and assert the visible result independently.

3. **Medium — new typed-array assignments violate the Windows rule.** Examples include [section_transition_suite.gd:279](/private/tmp/labyrinth_codex/review/flow-01-63c1f11ba/tests/suites/section_transition_suite.gd:279) (`Array[int] = [0]`) and [section_map_graph.gd:174](/private/tmp/labyrinth_codex/review/flow-01-63c1f11ba/scripts/section_map_graph.gd:174) (`Array[String] = []`). There are 27 added literal initializers across runtime, tests, and tools. **Fix:** replace them with typed helpers or typed temporaries populated through `append`/`assign`.

The prior stuck-state defect is fixed, including retry and quit/resume. Arrival/playback counts, the literal notice, cursor cleanup, and removed-control references are covered. Direct title→map frame coverage, framing, skip and reduced-motion checks pass. Merge input/load ordering and registration in both manifests are correct.

Verification:

- [Full Godot suite](/private/tmp/flow-01-review-full-godot.log): **FAIL**, 408.5 seconds; 33/34 children pass. `main_menu_resume_test` hits its 180-second limit.
- [Python suite](/private/tmp/flow-01-review-python.log): **PASS**, 702 tests, 63 skips.
- Transition, start-room map, and updated map-review checks pass.
- [Mutation results](/private/tmp/flow-01-review-delta-mutation-results.json): **12 caught, 0 survived**; registration removal also caught. Skip/save mutants additionally produce downstream script errors.

Inspected the supplied 1920×1080 native demo, which predates the merge. No Windows or windowed runs performed. No additional flow-specific tuning, dead-code, scope, or stray-file issue found. All mutations were in memory; checkout remains clean at `63c1f11ba895e8408346aa183c1ba5c1296202f0`.

CHANGES REQUESTED