<!-- memento:managed -->
## Memento

This repo uses `memento` for code-scoped project memory.

- Before substantive code changes, run `memento brief <paths>` for the files or folders you expect to touch.
- After substantive code changes, record only durable, non-obvious learnings with `memento record ...` when future sessions would benefit.
- Use `shared` for committed repo truth and `local` for private, machine-specific, branch-specific, or temporary notes.
- Supersede or obsolete stale notes instead of adding contradictory duplicates.
- Memento state lives under `.codex/memento/`.
<!-- /memento:managed -->

## Parallel Codex Tasks

- For substantive Labyrinth coding tasks, use `$parallel-labyrinth-task` so work happens in an isolated `codex/<task-id>` worktree based on `master`.
- The default task base is the current local `master` tip; use `--fetch --base origin/master` only when explicitly choosing the remote tracking branch.
- If a thread is already running inside a clean app-created worktree, run `python3 tools/parallel_task.py adopt --task "<short task description>"` before editing. If it is in the shared checkout, create or move into an isolated task worktree before editing game/source/content files.
- Keep development commands parallel-safe. Use `python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot ...` for Godot commands; the runner terminates commands after 300 seconds by default, accepts `--timeout <seconds>` to tune that limit, and still scans captured output for Godot failure markers. Use `python3 tools/visual_probe_runner.py <probe.gd> --task-id <task-id>` instead of invoking visual probes directly.
- When task work is done, commit the task branch, get explicit signoff from a peer-review sub-agent, then wait for user inspection. Do not push, land, or clean up the worktree until the user explicitly approves publication. After approval, finished task branches land on `master` and push `master`; remote task branches are not the final published state.

## Autonomous Task Queue

- Use `$scout-labyrinth-tasks` when asked to find good autonomous changes. Scout output must pass a separate scout-reviewer gate before entering the queue as `ready`.
- Use `$orchestrate-labyrinth-tasks` when asked to run queued work in parallel. The orchestrator should select reviewed tasks with concrete path/shared-state collision checks, create app-visible worker threads, and track status with `python3 tools/labyrinth_task_queue.py`.
- Avoid fixed broad collision groups. Prefer comparing likely touched files, generated paths, singleton/shared state, and specific task ids that should not run together.

## GDScript Typed Arrays

- Godot on Windows has caught typed-array assignments that may pass on macOS. When assigning to `Array[T]`, do not rely on bare array literals or conditional-expression branches like `[value] if condition else typed_array`; build the value through a typed helper such as `_vector2i_array(...)` or an explicitly typed temporary first.
- For fallbacks passed into typed-array helpers, keep using plain `[]` only as input to the helper. The typed local should receive the helper result, not the raw literal.

## Card Balance Heuristic

- When creating or modifying cards, consult `spec/card_balance_heuristic.md`.
- Run `python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown` for touched cards and `python3 tools/card_heuristic.py` when comparing against the full pool.
- Treat the heuristic as the default curve check for card work, then call out any deliberate deviations from curve in your notes or review context.
- When combat mechanics or encounter assumptions change, update both `spec/card_balance_heuristic.md` and `tools/card_heuristic.py` in the same change.
- Revisit the heuristic whenever changes touch `scripts/combat_engine.gd`, `scripts/room_generator.gd`, `data/enemies.json`, fatigue rules, cards/draw per turn, status semantics, multi-target behavior, or new action keywords.

## Analytics

- When changing reward flow, draw rules, card play flow, combat outcome flow, or status timing, consult `spec/analytics.md`.
- Keep analytics local-first and append-only unless the task explicitly adds remote upload.
- Preserve the JSONL event contract in `scripts/analytics_store.gd`; prefer additive schema changes over renaming or deleting fields.
- If combat or reward mechanics change, update both the instrumentation and `spec/analytics.md` in the same change so card-balance analysis keeps matching live behavior.
