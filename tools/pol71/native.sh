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

if [ "${POL71_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id pol-71 --stream -- godot "$@"
fi
exec python3 tools/pol71/proof.py "$@"
