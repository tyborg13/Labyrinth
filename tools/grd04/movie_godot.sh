#!/bin/sh
set -eu
exec godot --write-movie "$LABYRINTH_GRD04_MOVIE" --fixed-fps 30 --windowed --resolution 1920x1080 "$@"
