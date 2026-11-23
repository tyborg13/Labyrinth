#!/bin/sh
set -eu
exec python3 "$GRD11_WORKTREE/tools/godot_task_runner.py" --task-id grd-11 --timeout 120 --stream -- \
  godot --windowed --resolution 1920x1080 "$@"
