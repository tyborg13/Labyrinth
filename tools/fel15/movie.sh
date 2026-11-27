#!/bin/sh
# Called by visual_probe_runner.py as the Godot executable for a paired take.
set -eu
exec godot --disable-vsync --fixed-fps "${FEL15_MOVIE_FPS:?}" --resolution 1920x1080 \
    --windowed --write-movie "${FEL15_MOVIE_PATH:?}" "$@"
