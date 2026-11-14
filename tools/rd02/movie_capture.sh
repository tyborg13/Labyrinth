#!/bin/sh
set -eu
RD02_MOVIE_DIR=${RD02_MOVIE_DIR:-/private/tmp/labyrinth_codex/rd-02/movie_raw}
RD02_MOVIE_FPS=30
RD02_MOVIE_GODOT=${RD02_MOVIE_GODOT:-godot}
mkdir -p "$RD02_MOVIE_DIR"
RD02_MOVIE_RUN=$(mktemp -d "$RD02_MOVIE_DIR/run.XXXXXX")
printf '%s\n' "$RD02_MOVIE_RUN"
# Godot consumes --fixed-fps before exposing OS.get_cmdline_args(). Repeat the
# same rate after the user-argument delimiter for PresentationClock's fallback.
RD02_HAS_USER_ARGS=false
for RD02_ARG in "$@"; do
  if [ "$RD02_ARG" = -- ]; then RD02_HAS_USER_ARGS=true; fi
done
if [ "$RD02_HAS_USER_ARGS" = true ]; then
  exec "$RD02_MOVIE_GODOT" --write-movie "$RD02_MOVIE_RUN/movie.png" --fixed-fps "$RD02_MOVIE_FPS" --windowed --resolution 1920x1080 --rendering-method mobile --rendering-driver metal "$@" --fixed-fps "$RD02_MOVIE_FPS"
else
  exec "$RD02_MOVIE_GODOT" --write-movie "$RD02_MOVIE_RUN/movie.png" --fixed-fps "$RD02_MOVIE_FPS" --windowed --resolution 1920x1080 --rendering-method mobile --rendering-driver metal "$@" -- --fixed-fps "$RD02_MOVIE_FPS"
fi
