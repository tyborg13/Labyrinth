#!/bin/sh
set -eu
RD07_MOVIE_DIR=/private/tmp/labyrinth_codex/rd-07/movie_raw
mkdir -p "$RD07_MOVIE_DIR"
RD07_MOVIE_RUN=$(mktemp -d "$RD07_MOVIE_DIR/run.XXXXXX")
exec godot --write-movie "$RD07_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 --rendering-driver metal --rendering-method mobile "$@"
