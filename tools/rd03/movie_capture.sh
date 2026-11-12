#!/bin/sh
set -eu
RD03_MOVIE_DIR=/private/tmp/labyrinth_codex/rd-03/feedback1/movie_raw
mkdir -p "$RD03_MOVIE_DIR"
RD03_MOVIE_RUN=$(mktemp -d "$RD03_MOVIE_DIR/run.XXXXXX")
printf '%s\n' "$RD03_MOVIE_RUN"
export RD03_CLIP=1
exec godot --rendering-driver metal --rendering-method mobile --write-movie "$RD03_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
