# Labyrinth / Escape the Umbra

## Working context

Classify the task before loading context. Read the relevant code and specification sections; do not reread instructions already supplied in the task. Keep durable rationale near the code or in its owning specification.

## Isolated implementation and completion

- Use `$parallel-labyrinth-task` for substantive coding, content, and developer-workflow changes. Work in an isolated `codex/<task-id>` worktree based on the current local `master`; choose remote `origin/master` only explicitly.
- Before editing, adopt or start the task, record observable acceptance criteria, proof, risk tier, and inspection expectation, then pass worker-owned Git `preflight`.
- Carry authorized work through verification, fixes, a committed branch, separate peer-review signoff, and a verified inspection fixture or a concrete not-applicable reason. Resolve review findings before handoff.
- Wait for user inspection and explicit publication approval before pushing, landing, or cleaning up. Bind approval and peer signoff to the exact HEAD, then publish to `master` through the task helper.
- Follow [the development workflow](spec/development_workflow.md) for proof breadth, bootstrap, fixtures, and publication. Preserve unrelated checkout changes.

## Parallel-safe execution

Run Godot through `tools/godot_task_runner.py --task-id <task-id> --stream -- godot ...`; run visual probes through `tools/visual_probe_runner.py`. Never use an editor scan as a parser check. Override timeouts only for known command behavior, not to conceal launch failures.

For autonomous work, use `$scout-labyrinth-tasks` to review proposals and `$orchestrate-labyrinth-tasks` to dispatch the queue. Implementation workers must be app-visible tasks with callable create/read/send tools and worker-owned preflight. Keep queue lifecycle state current using the queue helper; the orchestrator owns queue JSON and consumes verified worker handoffs.

## Windows GDScript compatibility

Assignments to `Array[T]` must use a typed helper or explicitly typed temporary. Bare literals and conditional branches such as `[value] if condition else typed_array` can pass on macOS and fail on Windows. Plain `[]` is safe as input to a typed helper, not as the typed assignment itself.

## Player-facing work

For player-facing UI, use `$create-labyrinth-ui` and the relevant [UI rubric](spec/game_ui_rubric.md) sections. Require fresh, inspected real-renderer proof at `1920x1080`, `100%` UI scale; add other configurations only when requested. Preserve supported input paths and precise rules text.

Distinct player-facing concepts require purpose-built, distinct icons under [the icon identity policy](spec/icon_identity_policy.md). Run `python3 tests/test_icon_identity_policy.py` when identities or registries change.

For card balance or combat/encounter assumptions, consult [the heuristic](spec/card_balance_heuristic.md). Score changed mechanics; update its specification and scorer together when assumptions change. Art-only changes do not require balance scoring.

For combat/reward flow, draw/play rules, outcomes, or status timing, consult [analytics](spec/analytics.md) and update affected instrumentation and documentation together. Preserve local-first, append-only JSONL events; prefer additive fields.
