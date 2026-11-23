#!/bin/sh
set -eu
if [ "${MRG18_MOVIE_CLOCK:-}" = 1 ]; then
    exec python3 tools/godot_task_runner.py --task-id mrg-18 --stream -- godot \
        --windowed --resolution 1920x1080 --fixed-fps 60 --write-movie "${MRG18_MOVIE_FILE:?}" "$@"
fi
cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
export LABYRINTH_CEL_LOOK=all PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0
exec python3 tools/mrg18/native.py "$@"
