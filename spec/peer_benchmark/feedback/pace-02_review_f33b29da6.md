Two Medium findings prevent signoff:

- **Ambush slows enemy movement.** [combat_pacing.gd:319](/private/tmp/labyrinth_codex/review/pace-02-f33b29da6/scripts/combat_pacing.gd:319) enables 0.80 before Gloam Stalker’s embedded blink, which lacks movement guards in [veil_view.gd:78](/private/tmp/labyrinth_codex/review/pace-02-f33b29da6/scripts/enemy_mechanics/veil_view.gd:78). Reproduction: identical `(6,4) → (3,4)` blinks run at **1.0 for Fade, 0.8 for Ambush**, with Reduced Motion both enabled and disabled. **Fix:** bracket the blink with `begin_movement`/`end_movement`, resuming 0.80 for the strike. [Reproduction log](/private/tmp/pace-02-review-extra.log).

- **The direct approach-walk guard lacks effective regression coverage.** [combat_enemy_action_clock_suite.gd:114](/private/tmp/labyrinth_codex/review/pace-02-f33b29da6/tests/suites/combat_enemy_action_clock_suite.gd:114) tests movement through the outer wrapper; its Shrike fixture is already aligned. Removing both movement hooks from `_animate_actor_along_path` **survived the entire new suite**. An independent unaligned Shrike probe caught the resulting approach speed of **0.8 instead of 1.0**. **Fix:** add an unaligned Dive fixture, assert approach and subsequent attack scales independently, and register this mutation. [Mutation evidence](/private/tmp/pace-02-review-direct-mutant.log).

Requested combat-feel, pacing, action-clock, three SFX programs, and registration checks passed. All eight supplied mutations were caught; the additional direct-path mutation survived. Exit probes found no scale leaks. No new Windows typed-array violations, misplaced tunables, scope creep, dead code, or stray tracked files found.

Headless `pass_to_hero_banner`:

| Speed | Before | After |
|---|---:|---:|
| Normal | 5.341 s | 6.011 s |
| Fast | 4.594 s | 5.070 s |
| Fastest | 3.815 s | 4.109 s |

All mutations were reverted; checkout is clean at the reviewed HEAD. No full suites or windowed runs.

CHANGES REQUESTED