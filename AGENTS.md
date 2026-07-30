<!-- memento:managed -->
## Memento

This repo uses `memento` for code-scoped project memory.

- Before substantive code changes, run `memento brief <paths>` for the files or folders you expect to touch.
- `memento brief` is strictly read-only; run `memento compact` explicitly when storage cleanup is intended.
- After substantive code changes, record only durable, non-obvious learnings with `memento record ...` when future sessions would benefit.
- Use `shared` for committed repo truth and `local` for private, machine-specific, branch-specific, or temporary notes.
- Supersede or obsolete stale notes instead of adding contradictory duplicates.
- Memento state lives under `.codex/memento/`.
- Run `memento configure-merge` once in older repositories so shared memory reconciles by note identity during Git merges.
<!-- /memento:managed -->

## Parallel Codex Tasks

- For substantive Labyrinth coding tasks, use `$parallel-labyrinth-task` so work happens in an isolated `codex/<task-id>` worktree based on `master`.
- The default task base is the current local `master` tip; use `--fetch --base origin/master` only when explicitly choosing the remote tracking branch.
- If a thread is already running inside a clean app-created worktree, run `python3 tools/parallel_task.py adopt --task "<short task description>"` before editing. If it is in the shared checkout, create or move into an isolated task worktree before editing game/source/content files.
- Before implementation, record observable acceptance criteria, required proof, risk tier, and inspection expectation with `python3 tools/parallel_task.py contract ...`, then pass `python3 tools/parallel_task.py preflight`. Preflight must prove object, index, and temporary task-branch ref writes. See `spec/development_workflow.md` for risk-tier proof breadth.
- Keep development commands parallel-safe. Use `python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot ...` for Godot commands; the runner terminates commands after 300 seconds by default, accepts `--timeout <seconds>` to tune that limit, and still scans captured output for Godot failure markers. Use `python3 tools/visual_probe_runner.py <probe.gd> --task-id <task-id>` instead of invoking visual probes directly.
- When task work is done, commit the task branch, get explicit signoff from a peer-review sub-agent, then create a verified task-local inspection fixture with `python3 tools/inspection_fixture.py --scenario <scenario> --summary "<what Continue opens>" ...` or record why no playable fixture applies. Use the reported self-healing launch command, which regenerates and verifies the pre-choice/pre-action state before opening the game. Wait for user inspection after that. Do not push, land, or clean up the worktree until the user explicitly approves publication. After approval, bind peer signoff and user approval to the exact HEAD with `python3 tools/parallel_task.py authorize-publish ...`, then land on `master` and push `master`; remote task branches are not the final published state.

## Autonomous Task Queue

- Use `$scout-labyrinth-tasks` when asked to find good autonomous changes. Scout output must pass a separate scout-reviewer gate before entering the queue as `ready`.
- Use `$orchestrate-labyrinth-tasks` when asked to run queued work in parallel. Treat that request as explicit permission to create app-visible Codex background/app threads for the selected worker tasks; the user should not need to separately say "create background threads" every time. The orchestrator should select reviewed tasks with concrete path/shared-state collision checks, create app-visible worker threads, and track status with `python3 tools/labyrinth_task_queue.py`.
- Queue bookkeeping is mandatory whenever queued work changes lifecycle state. Use `tools/labyrinth_task_queue.py complete` after reviewer signoff plus fixture/not-applicable handoff, `tools/labyrinth_task_queue.py landed` after approved work lands on `master`, and `tools/labyrinth_task_queue.py mark <task-id> abandoned|blocked|rejected` when work is explicitly stopped. Do this before ending the turn, or report the exact command still needed if permissions block the update.
- App-visible Codex thread tools are mandatory for implementation workers. Before leasing or launching any queued implementation task, the orchestrator must verify that tool discovery exposes callable app-thread equivalents for `create_thread`, `read_thread`, and `send_message_to_thread`. If those tools are unavailable, stop and report the missing host tools; do not fall back to hidden sub-agents or pre-created worktrees as implementation workers without explicit user approval in that turn.
- App-visible workers must start from a branch created by `python3 tools/parallel_task.py prepare-worker` when the host supports branch starting state. Their first actions are `adopt`, `contract`, and worker-owned `preflight`; only then may implementation continue. If preflight fails, abandon/recreate the worker or report the host limitation. Queue JSON remains orchestrator-owned and is transferred through one verified handoff file.
- Avoid fixed broad collision groups. Prefer comparing likely touched files, generated paths, singleton/shared state, and specific task ids that should not run together.

## GDScript Typed Arrays

- Godot on Windows has caught typed-array assignments that may pass on macOS. When assigning to `Array[T]`, do not rely on bare array literals or conditional-expression branches like `[value] if condition else typed_array`; build the value through a typed helper such as `_vector2i_array(...)` or an explicitly typed temporary first.
- For fallbacks passed into typed-array helpers, keep using plain `[]` only as input to the helper. The typed local should receive the helper result, not the raw literal.

## Player-facing UI

- For any change that creates, modifies, or reviews player-facing UI, use `$create-labyrinth-ui` and follow `spec/game_ui_rubric.md`.
- Follow `spec/icon_identity_policy.md` for every icon-bearing player-facing concept. Distinct abilities, relics, equipment, keywords, statuses, and resources require distinct purpose-built icon assets; generic reuse, duplicate paths, and copied/recolored stand-ins are not acceptable.
- Run `python3 tests/test_icon_identity_policy.py` when adding or changing player-facing identities or icon registries.
- Treat the rubric as an acceptance gate, including for UI copy, icons, cards, HUD state, menus, tooltips, tutorials, focus/selection behavior, and visual effects that communicate gameplay state.
- Prefer compact, game-native, progressively disclosed presentation over generic web/app layouts or explanatory prose. Preserve precise rules text when it is the clearest way to explain a card, relic, equipment item, setting, or detailed inspection view.
- UI work is not complete with code-only proof. Render the changed surface through a focused visual probe and inspect fresh screenshots at the rubric's relevant states. The default and only required visual-QA resolution is `1920x1080` at `100%` UI scale; do not add lower-resolution or alternate-scale proof unless the user or task explicitly asks for it.

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
