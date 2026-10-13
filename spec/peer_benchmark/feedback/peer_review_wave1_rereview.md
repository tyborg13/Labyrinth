# Re-review of fix-01 (reviewer subagent)

## Re-review of fix-01: REQUEST_CHANGES at 9b0f8999d

Reviewed: merge 83eb01a5c (fix commit 9f2893f57) plus follow-up 9b0f8999d. The merge's only conflict resolution was in `tests/suites/event_view_suite.gd`, and it is clean.

The worktree HEAD has since moved to 8ff4eb929. Between 9b0f8999d and that HEAD only sfx tooling changed, so all GDScript I read and ran is identical to 9b0f8999d. I edited nothing; my repro scripts are in my scratchpad under `repro/`.

Eleven of the 13 findings are fixed, and their new tests fail on the old code. Finding 2 is kept by your decision and finding 11 is logged as debt. But the fix for 3 and 10 introduced a new blocker.

### Findings, most severe first

**1. BLOCKER (new): the victory beat shows the board as it was before the killing blow.**
- **Cause:**
  - `end_scope()` now queues `scene.call_deferred("_refresh_stage_view")` (`combat_pacing.gd`, end of `end_scope`).
  - fix-01 also added `_combat_pacing.end_scope()` right before `await _play_post_combat_victory(...)` in both `_play_player_card` and `_commit_player_movement` (`run_scene.gd` ~22450 and ~22351 at 9b0f8999d).
  - While `_animation_lock` is on, `_refresh_stage_view` renders `_board_display_state()`, which returns `_combat_state`. During a card play that is still the pre-card state; it's only synced after the victory beat (`_run_state = committed_run_state; _sync_combat_state_from_run()`).
  - The deferred call runs at the end of the frame, after `_play_post_combat_victory`'s single `_render_board_state(board_state, {})`. The victory overlay is label-only and never re-renders the board, so the stale board stays up for the whole beat.
- **Confirmed by repro on the production card flow** (MotionSuite fixture, `quick_stab` on a 1-HP crawler, real `_play_post_combat_victory`): in 120 of 120 victory-beat frames the board shows the killed enemy alive.
- **Control repro:** with the same calls but no `end_scope()` before the victory, the final board persists. So this is a fix-01 regression.
- **Enemy-phase victories, same mechanism (code trace, not repro'd):** `finish_enemies()` (~24288) queues the refresh while `_combat_state` is still the pre-phase `scheduled_state`.
  - If the victory path reaches `_play_post_combat_victory` without yielding a frame, the stale board persists through the beat.
  - Otherwise it shows as a one-frame flicker.
- **Why the suite misses it:** `_test_card_victory` overrides `_play_post_combat_victory`, so it only checks the time scale.
- **Fix:**
  - Either don't queue `_refresh_stage_view` from `end_scope` while `scene._animation_lock` is true (the unlock paths already call `_refresh_ui`), or add a scale-only `restore_time_scale()` for the pre-victory call sites.
  - Add a regression test that samples `board_view.combat_state` during a real victory beat, for both a card kill and an enemy-phase win.

**2. MINOR (new, not repro'd; check in the windowed feel probe): retained overlays are cut short when the enemy phase ends.**
- `end_scope()` now clears `_deaths`/`_popups`/`_surfaces`, and its deferred stage refresh renders without them.
- A death dissolve started by `overlap_defeats` in the last enemy action, or the last damage number (whose wait is trimmed to 0.2 s), can vanish abruptly. Before the fix they ran their full life.
- **Fix:** have `finish_enemies` wait for those bounded overlays to expire (the scope is still active, so the overlay refresh keeps drawing them), or let the next scene render retire them.

**3. MINOR: stale spec text on Escape.**
- `spec/events.md:277-278` still says "Back/Escape … activates Continue on results".
- Escape now always opens pause; controller Back (`ACTION_CANCEL`) still continues. This intentionally departs from the ev-02 brief, so the spec should say so.

**4. MINOR: the Expose scoring can't be reproduced from the repo.**
- `spec/events.md` "Hero Expose compatibility" cites `python3 tools/enemy_expose_heuristic.py`.
- That file isn't in any commit, so the scores (1.304→1.517, 4.549→4.639) can't be reproduced. Commit the tool or record the exact scorer invocation.

**5. NIT: the event view accepts input during its own animations.**
- `release_request()` runs on every `present()` with an unchanged signature. Any `_refresh_ui` during the 0.22 s open or the 0.18 s page cross-fade now clears `_busy`, so input works mid-animation.
- The page guards keep this correct. A separate `_request_pending` flag would keep the intended animation lock.

**6. NIT: possible deferred call after removal.** `CombatPacing._exit_tree` → `end_scope()` can queue `_refresh_stage_view` on a scene that is removed but not freed (test harness case).

### Status of the original 13

| # | Status | Evidence |
|---|---|---|
| 1 | Fixed | `_begin_scope` adopts `hit_stop.previous_scale()`; non-positive guards added in request, restore, `_apply_speed` and `end_scope`. Re-ran my wave-1 repro: restores to 1.0, also after scene exit. `_test_scope_less_stop` fails on old code. |
| 2 | Kept (your decision) | Spec updated. The preview test asserts losses `[4,5]` and the lethal second hit. The byte-identity check is now meaningful. See finding 4 above for the missing tool. |
| 3 | Fixed as stated | Refresh only inside a scope, de-duplicated per frame, deferred. `_test_overlay_refresh` fails on old code. But it caused new findings 1 and 2. |
| 4 | Fixed | Flow probe migrated to EventView, plus a source-contract assertion. |
| 5 | Fixed | No non-empty typed literals were added anywhere in 8c71fa17b..9b0f8999d. `= []` plus `.assign()` matches the codebase's existing convention; the remaining literals are pre-existing consts/master code. |
| 6 | Fixed | Escape and Start open pause above the event; closing pause restores choice focus. Tests fail on old code. Mouse/Escape now fall through `_input`; I checked that path and found nothing harmful in event mode. |
| 7 | Fixed | Release on unchanged signature and on scene decline; both tests fail on old code. |
| 8 | Fixed | Biome cache keyed on seed, coord, section-enabled, section index, boss and override; invalidation is correct and `set_inspection_override` resets it. `first_movement` short-circuits. `EMPTY_FEEL_FRAME` const. |
| 9 | Fixed | `reward_kind`/`event_id` on `reward_choice`; real claim/skip tests; spec updated. |
| 10 | Speed fixed | The victory beat runs at 1.0, but the fix causes the new blocker (finding 1). |
| 11 | Logged as debt | Per your note. |
| 12 | Fixed | The waiver now keys on `peak_cap_applied`; both new tests fail on old code. |
| 13 | Fixed | Owned pack pieces are excluded; the test fails on old code. |

The undo input split looks correct: input is consumed synchronously and `request_undo()` runs without blocking `_input`.

**Verdict: REQUEST_CHANGES at 9b0f8999d** (merge 83eb01a5c / fix 9f2893f57), because of the new blocker. Findings 2–6 can ride along with that fix.
