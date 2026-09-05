---
name: run-labyrinth-playtest
description: Run and synthesize Escape the Umbra headless playtests with isolated outputs and the manual strategy guide.
---

# Run Labyrinth Playtest

Use this skill when asked to run Labyrinth playtests, kick off tester agents, use the headless playtest harness, or summarize playtest balance findings.

## Core Workflow

1. Read `playtest/headless_strategy_guide.md` for the run. Inspect the harness or request its `--help` through the Godot task runner only when needed.
2. Choose the run shape:
   - If the user asks for sub-agents, testers, agents, or a parallel round, spawn that many worker agents. Default to six workers when no count is given.
   - If the user only asks for a playtest without delegation, run one local harness session.
3. Assign each tester a unique seed and output directory:
   - Use deterministic seeds such as `<MMDDYY><agent_index>` or user-provided seeds.
   - Use directories like `playtest/agent_round_<YYYYMMDD>_<NN>`.
   - Never let two agents share an output directory.
4. Give every tester a unique task id and the harness command. `--timeout 0` is intentional for interactive play through a natural endpoint:
   ```bash
   python3 tools/godot_task_runner.py --task-id <tester-id> --timeout 0 --stream -- godot --headless --path . --script tools/headless_playtest.gd -- --seed <seed> --output-dir res://playtest/<dir>
   ```
5. Tell testers to read `playtest/headless_strategy_guide.md`, use `state`, `cards`, `moves`, and target previews after meaningful actions, and add in-run observations with `note ...`.
6. Play to a natural endpoint: victory, defeat, rest/leave when rational, no legal progress, or enough depth/combat evidence to make a balance call. Do not accept a stop after one trivial room unless the tester is blocked.
7. After agents finish, read each `manual_playtest_notes.md`, tester final summaries, and the generated analytics under each run's `analytics/` directory. Use notes and analytics together before making recommendations.

## Worker Prompt Template

Use a prompt like this for each worker:

```text
You are Playtester <NN> for /Users/borgerding/workspace/Labyrinth. You are not alone in the codebase: do not modify source files or revert anyone's edits. Only write playtest artifacts under your assigned directory: playtest/<dir>.

Task: run a manual headless playtest using the existing harness and strategy guide, then report findings.

Required workflow:
1. Work in <assigned-repo-or-task-worktree>.
2. Read playtest/headless_strategy_guide.md before playing.
3. Start the harness with: python3 tools/godot_task_runner.py --task-id <tester-id> --timeout 0 --stream -- godot --headless --path . --script tools/headless_playtest.gd -- --seed <seed> --output-dir res://playtest/<dir>
4. Use the harness interactively. After each meaningful action, inspect state/cards/moves/target previews as needed. Follow the guide: avoid traps, avoid entering enemy range without a reason, collect efficient pickups, and use notes.
5. Add notes during the run with `note ...` for balance, UX, unclear harness output, suspicious mechanics, difficulty spikes, card/relic/reward choices, and the reason for stopping.
6. Play until a natural endpoint. Do not stop after only one trivial room unless blocked.
7. Final response: summarize seed, endpoint, rooms/combat depth reached, strongest balance findings, suspected bugs or harness issues, and written file paths.

Do not implement fixes. Do not edit files outside playtest/<dir>.
```

## Synthesis Checklist

When the round is done, report:

- Seeds, endpoints, and note paths for each tester.
- Analytics consulted for each run, including combat outcomes, card/reward choices, damage spikes, HP/ember trajectory, and any event anomalies visible in JSONL.
- Repeated balance signals across runs, separated from one-off variance.
- Suspected bugs or harness clarity issues with note path evidence.
- Gameplay recommendations, ordered by impact and confidence.
- Any card, enemy, reward, map, analytics, or harness files that should be inspected before implementing changes.

For card or combat mechanic changes recommended from a playtest, do not implement them unless the user asks. If implementation follows, use the relevant Labyrinth card/relic guidance and run the card balance heuristic where applicable.
