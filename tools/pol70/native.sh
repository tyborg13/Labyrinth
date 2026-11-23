#!/bin/sh
set -eu

launcher=$0
if [ -L "$launcher" ]; then
    launcher=$(readlink "$launcher")
fi
cd "$(dirname "$launcher")/../.."
export LABYRINTH_CEL_LOOK=all

if [ "${POL70_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id pol-70 --stream -- godot "$@"
fi

exec python3 tools/pol70/proof.py "$@"
