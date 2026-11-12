#!/bin/sh
set -eu
export LABYRINTH_CEL_LOOK=all
# The visual runner supplies this exact engine log and validates native PNGs.
RD04_ENGINE_LOG=
RD04_PREVIOUS_ARG=
for RD04_ARGUMENT in "$@"; do
    if [ "$RD04_PREVIOUS_ARG" = --log-file ]; then RD04_ENGINE_LOG=$RD04_ARGUMENT; fi
    RD04_PREVIOUS_ARG=$RD04_ARGUMENT
done
if [ -z "$RD04_ENGINE_LOG" ]; then
    printf '%s\n' 'error: use the visual probe runner so the native engine log can be checked' >&2
    exit 2
fi
if [ "${RD04_MOVIE:-0}" = 1 ]; then
    export LABYRINTH_MOVIE_FPS=30
    RD04_MOVIE_ROOT=/private/tmp/labyrinth_codex/rd-04/feedback2/movie_raw
    mkdir -p "$RD04_MOVIE_ROOT"
    RD04_MOVIE_RUN=$(mktemp -d "$RD04_MOVIE_ROOT/run.XXXXXX")
    printf '%s\n' "$RD04_MOVIE_RUN"
    python3 tools/godot_task_runner.py --task-id rd-04 --stream -- godot --write-movie "$RD04_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
else
    python3 tools/godot_task_runner.py --task-id rd-04 --stream -- godot --windowed --resolution 1920x1080 "$@"
fi
python3 tools/rd04/check_capture_log.py "$RD04_ENGINE_LOG"
