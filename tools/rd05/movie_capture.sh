#!/bin/sh
set -eu
RD05_MOVIE_DIR=/private/tmp/labyrinth_codex/rd-05/movie_raw
mkdir -p "$RD05_MOVIE_DIR"
RD05_MOVIE_RUN=$(mktemp -d "$RD05_MOVIE_DIR/run.XXXXXX")
exec godot --write-movie "$RD05_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
