#!/bin/sh
set -eu
if [ "${MRG17_MOVIE_CLOCK:-}" = 1 ]; then
    exec godot --windowed --resolution 1920x1080 --fixed-fps 60 --write-movie "${MRG17_MOVIE_FILE:?}" "$@"
fi
if [ "${POL70_WINDOWED_ENGINE:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id mrg-17 --stream -- godot "$@"
fi
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
exec python3 tools/mrg17/native.py "$@"
