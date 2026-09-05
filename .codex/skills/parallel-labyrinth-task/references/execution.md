## During Work

Use the risk-tier proof rules in `spec/development_workflow.md`. Peer review remains mandatory at every tier; the tier controls focused/full/visual proof breadth.

Begin in the task worktree:

```bash
cd <task-worktree>
python3 tools/parallel_task.py status
python3 tools/parallel_task.py env
```

For normal Godot or test commands, use the task-local Godot runner:

```bash
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id <task-id> --timeout 180 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The runner gives each Godot process an isolated temp `HOME`, a safe `--log-file`, and a unique `LABYRINTH_TASK_ID` so default `user://` state does not collide across parallel tasks. It terminates commands after 300 seconds by default, accepts `--timeout <seconds>` to tune that limit, accepts `--timeout 0` for intentionally unbounded local runs, and `--stream` tees output live while preserving captured output for Godot failure-marker scanning.

For visual probes, use the validated runner instead of invoking probe scripts directly:

```bash
cd <task-worktree> && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/ui_probe.gd --task-id <task-id>
cd <task-worktree> && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/motion_probe.gd --task-id <task-id>
```

The visual runner uses the same temp-home isolation, disables Steam, assigns a unique `user://` namespace per process, serializes non-headless GUI renderer access, defaults macOS capture to ANGLE with native fallback, rejects generated `.import`/`.uid` noise, and validates emitted PNGs. It defaults to one attempt, a 30-second total process timeout, an 8-second startup watchdog, and a 30-second GUI-lease wait. A startup or execution timeout fails immediately instead of retrying another backend; `--timeout`, `--startup-timeout`, `--gui-lease-timeout`, and `--attempts` remain configurable for known probe behavior. Use repeatable `--expect-size`, `--proof-contract`, and `--result-manifest` for exact-resolution and semantic proof. If a completed probe fails under the default renderer, retry with an explicit backend such as:

```bash
cd <task-worktree> && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3_angle tests/ui_probe.gd --task-id <task-id>
```

For headless playtests, always use unique output directories:

```bash
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tools/headless_playtest.gd -- --seed <seed> --output-dir res://playtest/<task-id>/<run-id>
```
