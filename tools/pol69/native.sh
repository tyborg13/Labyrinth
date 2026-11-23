#!/bin/sh
set -eu

launcher=$0
if [ -L "$launcher" ]; then
    target=$(readlink "$launcher")
    case "$target" in
        /*) launcher=$target ;;
        *) launcher=$(dirname "$launcher")/$target ;;
    esac
fi
cd "$(dirname "$launcher")/../.."
export LABYRINTH_CEL_LOOK=all

# The visual runner owns the window and PNG validation. Its engine goes
# through the project task runner with the same namespace as the probe.
if [ "${POL69_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id pol-69 --stream -- godot "$@"
fi

exec python3 tools/pol69/proof.py "$@"
