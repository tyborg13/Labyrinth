#!/bin/sh
# MovieWriter adapter invoked only by visual_probe_runner.py.
set -eu
brs03_movie_path=${BRS03_MOVIE_PATH:-/private/tmp/labyrinth_codex/brs-03/chain-1x.avi}
mkdir -p "$(dirname "$brs03_movie_path")"
exec godot --write-movie "$brs03_movie_path" --fixed-fps 60 --windowed --resolution 1920x1080 "$@"
