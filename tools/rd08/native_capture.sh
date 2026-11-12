#!/bin/sh
set -eu
export LABYRINTH_CEL_LOOK=all
# The visual runner supplies this exact engine log and validates native PNGs.
RD08_ENGINE_LOG=
RD08_PREVIOUS_ARG=
for RD08_ARGUMENT in "$@"; do
    if [ "$RD08_PREVIOUS_ARG" = --log-file ]; then RD08_ENGINE_LOG=$RD08_ARGUMENT; fi
    RD08_PREVIOUS_ARG=$RD08_ARGUMENT
done
if [ -z "$RD08_ENGINE_LOG" ]; then
    printf '%s\n' 'error: use the visual probe runner so the native engine log can be checked' >&2
    exit 2
fi
if [ "${RD08_MOVIE:-0}" = 1 ]; then
    export LABYRINTH_MOVIE_FPS=30
    RD08_MOVIE_ROOT=/private/tmp/labyrinth_codex/rd-08/movie_raw
    mkdir -p "$RD08_MOVIE_ROOT"
    RD08_MOVIE_RUN=$(mktemp -d "$RD08_MOVIE_ROOT/run.XXXXXX")
    printf '%s\n' "$RD08_MOVIE_RUN"
    python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --write-movie "$RD08_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
else
    python3 tools/godot_task_runner.py --task-id rd-08 --stream -- godot --windowed --resolution 1920x1080 "$@"
fi
python3 tools/rd08/check_capture_log.py "$RD08_ENGINE_LOG"
