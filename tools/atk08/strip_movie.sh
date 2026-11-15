#!/bin/sh
# atk-08 native frame strips: MovieWriter wrapper (fixed 30 fps game clock,
# 1920x1080 window). Use as visual_probe_runner.py --godot; the strip script
# saves its own exact-size SubViewport frames, the movie file is discarded.
set -u
ATK08_MOVIE_DIR=${ATK08_MOVIE_DIR:-/private/tmp/labyrinth_codex/atk-08/strips/movie}
mkdir -p "$ATK08_MOVIE_DIR"
ATK08_MOVIE_RUN=$(mktemp -d "$ATK08_MOVIE_DIR/run.XXXXXX")
godot --write-movie "$ATK08_MOVIE_RUN/movie.avi" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
ATK08_STATUS=$?
rm -rf "$ATK08_MOVIE_RUN"
exit $ATK08_STATUS
