#!/bin/sh
# atk-02 native movie: the visual probe runner calls this in place of godot.
set -eu
ATK02_MOVIE_ROOT=/private/tmp/labyrinth_codex/atk-02/movie_raw
mkdir -p "$ATK02_MOVIE_ROOT"
ATK02_MOVIE_RUN=$(mktemp -d "$ATK02_MOVIE_ROOT/run.XXXXXX")
printf '%s\n' "$ATK02_MOVIE_RUN"
exec godot --write-movie "$ATK02_MOVIE_RUN/movie.png" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
