# QA-124 shutdown proof

Run from the QA-124 worktree. The regression leaves two script-owned lambdas on
RenderingServer and a named observer as a control. The assertion runs after the
game's root shutdown callback. The process must also exit cleanly.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-124
python3 tools/godot_task_runner.py --task-id qa-124 --stream -- godot --headless --path . --script tools/qa124/draw_shutdown_check.gd
```

The quit matrix opens real menus, loading covers and a saved combat. Each child
process reports whether it reached the requested phase and whether the managed
drain reached tree exit. The Steam case invokes the application's Steam
shutdown handler with the service disabled by the task runner.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-124
out=$(mktemp -d /private/tmp/labyrinth_codex/qa-124-check.XXXXXX)
python3 tools/qa124/stress.py --output "$out/editor"
python3 tools/qa124/build_release_probe.py --output-dir "$out/release"
binary="$out/release/QA124 Quit Probe.app/Contents/MacOS/Escape the Umbra"
python3 tools/qa124/stress.py --output "$out/export" --binary "$binary"
```

The release probe uses the Steam macOS release template with a disposable
entry scene. The following native command requests close during real card
playback. The probe delivers the window-close notification and signal at the
observed phase. For other close points use `movement`, `enemy`, `cover` or
`startup`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-124
python3 tools/godot_task_runner.py --task-id qa-124 --stream -- "$binary" \
  --display-driver macos --audio-driver Dummy --rendering-method mobile \
  --rendering-driver metal --resolution 1920x1080 --windowed -- --case=card
```

Use the perf-170 strict contract for native pixel proof at 1920×1080 and 100%
UI scale. Images are under `$out/strict/captures/{A,B}` and the comparison is in
`$out/strict/captures/summary.json`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-124
out=$(mktemp -d /private/tmp/labyrinth_codex/qa-124-native.XXXXXX)
python3 -c 'from tools.perf170 import proof; proof.TASK = "qa-124"; raise SystemExit(proof.main())' \
  --native --mode strict \
  --fixtures /private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var \
  --output "$out/strict"
```
