#!/bin/sh
set -eu
PTF09_MOVIE_DIR=/private/tmp/labyrinth_codex/ptf-09/feedback2/movie_raw
mkdir -p "$PTF09_MOVIE_DIR"
PTF09_MOVIE_RUN=$(mktemp -d "$PTF09_MOVIE_DIR/run.XXXXXX")
printf '%s\n' "$PTF09_MOVIE_RUN"
exec godot --write-movie "$PTF09_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
