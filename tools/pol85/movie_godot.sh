#!/bin/sh
set -eu
exec godot --write-movie "$POL85_MOVIE_DIR/raw.avi" --fixed-fps 60 \
    --windowed --resolution 1920x1080 "$@"
