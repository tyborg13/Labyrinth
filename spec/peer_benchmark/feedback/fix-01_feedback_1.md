# fix-01 feedback 1 (director) — re-review findings

Your branch has been synced with `codex/peer-benchmark` (merge 5b1b82565: itb-01 threats at rest, sfx-02 and the
director's typed-array follow-up are now in your base). The re-review report is
`spec/peer_benchmark/feedback/peer_review_wave1_rereview.md` (read it; repro paths are in it). Fix all of these:

1. **BLOCKER — victory beat shows the pre-kill board.** `end_scope()` queues `scene.call_deferred("_refresh_stage_view")`;
   your new pre-victory `end_scope()` calls run while `_animation_lock` is on and `_combat_state` is still the
   pre-card state, so the deferred refresh paints the killed enemy back for the whole victory beat (120/120 frames in
   the reviewer's repro). Fix: add a scale-only `restore_time_scale()` used by the two pre-victory call sites (keep
   overlays and scope bookkeeping for the normal end), and never queue `_refresh_stage_view` from `end_scope` while
   `scene._animation_lock` is true (unlock paths already call `_refresh_ui`). Regression: sample
   `board_view.combat_state` during a real `_play_post_combat_victory` (do not override it) for (a) a card kill and
   (b) an enemy-phase win (enemy dies to its own/ally damage or the last enemy dies during the enemy phase): every
   sampled frame shows the post-kill board. Must fail on 9b0f8999d.
2. **Retained overlays cut short at enemy-phase end.** `finish_enemies` must let bounded overlays (death dissolves
   started by the last enemy action, the last damage numbers) finish their normal life — wait for them while the scope
   is still active (cap the wait at the longest overlay's remaining life), then end the scope. Regression: the last
   enemy action kills a unit → its dissolve reaches completion before the scope ends.
3. **Spec:** `spec/events.md` Back/Escape text: Escape (keyboard) and Start (controller) open the pause menu over an
   event; controller Back (`ACTION_CANCEL`) still activates Continue on result pages. State that this supersedes the
   ev-02 wording.
4. **Expose scorer reproducibility:** I moved your `tools/enemy_expose_heuristic.py` out of the commit by mistake.
   Restore it from `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/fix-01/evidence/enemy_expose_heuristic.py`
   into `tools/`, make sure the command cited in `spec/events.md` reproduces 1.304064→1.517118 and 4.548725→4.639225.
5. **Event view busy flag:** use a separate `_request_pending` flag released on unchanged signature / declined request,
   and keep the open (0.22 s) and page cross-fade (0.18 s) animation lock independent of it.
6. **Deferred call after removal:** `CombatPacing._exit_tree` → `end_scope()` must not queue a deferred call on a scene
   that is leaving the tree (check `is_inside_tree()`/`is_queued_for_deletion()`).

Proof: the new regressions fail on 9b0f8999d and pass after; full suite, combat_feel, event_view, event_rules, movement
undo, threats_at_rest suites green. List the windowed combat-feel probe command again (I run it).
