Reviewed `1382b691659cf04aa4e1867d9da946e3c29d850a`. Two persistence failures block approval.

1. **Blocking — consumed heirlooms can return on a replacement descent.**  
   [opening_boon_flow.gd:157](/private/tmp/labyrinth_codex/review/boon-01-1382b6916/scripts/opening_boon_flow.gd:157) permits profile-write failure after saving consumption, relying on recovery. But [run_scene.gd:10631](/private/tmp/labyrinth_codex/review/boon-01-1382b6916/scripts/run_scene.gd:10631) starts replacements from the disk profile without recovering the previous run’s newer progression. Reproduction: fail the profile write while taking Duelist Rapier, restore writes, start another descent. The saved run records consumption, yet the new offer contains that Rapier again. **Fix:** reconcile and durably acknowledge the previous saved run’s newer progression before replacing it.

2. **Medium — Save & Quit deletes unflushed terminal analytics.**  
   [run_scene.gd:28826](/private/tmp/labyrinth_codex/review/boon-01-1382b6916/scripts/run_scene.gd:28826) clears terminal saves without checking boon-event delivery. With analytics appends forced to fail, choosing Leave nothing retained a save containing three receipts; `_save_run_progress()` then deleted it with zero events appended. **Fix:** preserve or transfer outstanding receipts until delivery succeeds, including across quit and replacement. [Reproduction log](/private/tmp/boon01-review-experiments.log).

3. **Medium — three guard removals survive the focused suite.**  
   The repeated-selection assertion at [opening_boon_suite.gd:130](/private/tmp/labyrinth_codex/review/boon-01-1382b6916/tests/suites/opening_boon_suite.gd:130) retries an unequipped Rapier, so equipment validation masks removal of the actual repeat guard. Purge tests never request two copies when only one remains, and save rollback has no injected failure coverage. **Fix:** retry another equipped piece, test insufficient duplicate copies, and inject save failures while asserting unchanged gameplay, progression and receipts.

4. **Low — Purge mixes data and literal selection limits.**  
   [opening_boon_overlay.gd:205](/private/tmp/labyrinth_codex/review/boon-01-1382b6916/scripts/opening_boon_overlay.gd:205) and line 225 hard-code `2`, while confirmation readiness reads the data count. `focus.remove_count` is also unused. **Fix:** use one data-backed Purge count throughout; remove or validate the unused Focus field.

Mutation results: **7 caught, 3 survived**.

| Result | Guards removed |
|---|---|
| Caught | Resolved choice, offered-event deduplication, heirloom consumption, start-room restriction, first Scavenger visit, first-run gating, terminal-wallet restoration |
| Survived | Repeated heirloom selection, Purge multiplicity, save-failure rollback |

[Mutation results and assertion failures](/private/tmp/boon01-review-mutations/summary.json).

Fresh checks passed: focused boon suite, headless UI contract, recap tests, main-menu resume tests, UI identity lint, balance report and whitespace checks. Reviewed submitted full-suite logs: Godot passed in 844.070 seconds; Python passed 617 tests with 61 skips.

Normal boon effects, seeded offer persistence, input paths and Purge confirmation checked out. No Windows typed-array violations, unrelated scope changes or stray files found; behavior is largely extracted from `run_scene.gd`. Latest renderer-manifest PNGs have expired, so feedback-2 appearance remains unverified.

Every mutation and temporary experiment was reverted. Checkout is clean; no commits or pushes made.

CHANGES REQUESTED