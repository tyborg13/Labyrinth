# perf-13: sweeping across the hand stays smooth

## Header
- **Evidence (native, quiet machine, 2026-11-02, perf-12 merged at 8593be76e, reports in `/private/tmp/labyrinth_codex/perf-12/native-*`):** hovering one card is fixed (over-33-ms 11% to 2%). **Sliding across the hand is still heavy:** `hand_sweep` p50 28 ms, p95 51 ms, 43% of frames over 33 ms (it was 34 ms and 54%). Each adjacent leave plus enter still runs one full stage refresh: the board preview for the new card (targets, forecasts, risk chips, glossary) plus the turn-order strip.
- **Director decision (the taste part):** while the pointer is sweeping, the board preview doesn't need to follow every card. **The card's own lift and enlarge stay immediate. The board preview for a hovered card appears once the hover has rested on that card for 2 consecutive rendered frames** (about 33 ms at 60 fps). Leaving the hand clears the preview immediately, as now. Keyboard and controller card focus are not sweeps, so they keep today's immediate preview. A click, drag, key press or Pass flushes and uses the current card at once, as perf-12 already does. Nothing else changes in what the player sees.
- **Worktree:** `/Users/borgerding/workspace/Labyrinth.worktrees/perf-13`, branch `codex/perf-13`, base `codex/peer-benchmark` (includes perf-12 and qa-20).
- **Owned:** the hand hover path in `scripts/run_scene.gd` (`_on_card_hover_started`, `_on_card_hover_ended`, `_queue_hover_presentation`, `_refresh_hand_hover_presentation`, `_flush_hand_hover_before_action`), `tools/perf11*`, `tools/fight_soak.gd`. Keep away from the turn-order rail code (`_animate_turn_order_*`), the board click path and `_render_board_state`, which qa-20 just changed.
- **Risk tier:** standard. A fresh worktree needs a cold import first: `python3 tools/godot_task_runner.py --task-id perf-13 --timeout 500 --stream -- godot --headless --path . --import`. Run with source art (`LABYRINTH_CEL_LOOK=off`).

## Change
1. **Implement the decision.** The card emphasis applies on the same frame as today. The board preview and stage refresh wait for a 2-frame rest on the same card, counted with real rendered frames, not a wall-clock timer. If the pointer leaves the hand before that, no preview is built for the cards it passed over. The turn-order strip's hover projection follows the same rest rule. Reduced motion changes nothing here.
2. **Equivalence:** extend perf-12's `tools/perf11/hover_equivalence.gd` with the sweep and rest cases. After a rest, the final state must equal today's for the same card: preview, glossary, strip, emphasis. During a sweep, no stage refresh runs for passed-over cards. Any click, drag, key or Pass flushes first. Keyboard and controller focus still preview immediately.
3. **CPU attribution, before and after:** the `--hand-sweep` workload headless, as perf-12 reported it.

## Proof
The equivalence proof, focused tests, the Python default group. **No full suites. No new permanent guards.** No windowed Godot: list the exact native commands (perf-12's set in `tools/perf11/perf12.md` with your new equivalence cases). The director runs them. The target is `hand_sweep` over-33-ms at or below 10%, with hover and other phases unchanged.

## Working rules (director)
Leave every change **uncommitted**; the director commits. Don't push, don't touch other worktrees. Taste gaps get `TODO_DESIGN_<what>`. Report to `/private/tmp/labyrinth_codex/perf-13/result.md`, short.
