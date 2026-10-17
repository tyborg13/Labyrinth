# bug-01 — Four possible real bugs exposed by orphaned tests (qa-08 quarantine)

## Header
- qa-08 found four orphaned tests that fail in ways that may be real player-facing bugs. They are quarantined under
  `follow_up: bug-01` in `tests/quarantine.json` on `codex/qa-08` (commit 8d0f59c9c; not yet merged). Evidence logs:
  `output/qa-08/quarantine-check/*.log` in `/Users/borgerding/workspace/Labyrinth.worktrees/qa-08`.
  1. `tests/prepared_other_character_view_test.gd`: 45 cases and 1,116 checks. One input-capture/cancellation
     ownership assertion fails.
  2. `tests/retained_character_inventory_equivalence_test.gd`: 117 cases. Authoritative-state preservation fails
     during equipment definition changes and when a boundary opens.
  3. `tests/shop_retained_content_test.gd`: an unchanged pack refresh loses the selected shop page.
  4. `tests/static_floor_cache_equivalence_test.gd`: 102 cases. The restored empty-board presentation differs
     between the retained/current and reference states.
- Base `codex/peer-benchmark`. Copy the four test files and their helpers from `codex/qa-08` if they are missing
  here. Owned: whatever production code each root cause requires, those four tests and their fixtures, and new
  regressions. Do not touch `tests/quarantine.json`: the director removes the entries when this unit merges, after
  qa-08.

## Change, per test
1. **Root cause first.** Reproduce, then state whether production behaviour is wrong or the test's reference is stale.
   - For a real bug, describe what a player would see: when it happens, and what is lost or wrong.
   - Bisect when it started (master `816f5e68a` onward).
2. **Real bugs.** Fix them in production, with a minimal regression that fails before the fix and passes after.
   Existing assertions stay.
3. **Stale references.** Update the reference to the current intended contract without weakening the assertion, and
   explain why the new reference is the intended behaviour. If "intended" is a player-facing choice (for example,
   which shop page should persist), stop and report it under TODO_DESIGN with both options.
4. All four tests must pass, and each must also pass as a program under the full runner.

## Proof
- A table: test, verdict (bug / stale), player impact, root-cause commit, fix, regression name.
- For (4), a windowed native capture comparing restored vs fresh empty-board presentation. Give the exact command; I
  run it.
- Focused tests, then the full Godot and Python suites.
