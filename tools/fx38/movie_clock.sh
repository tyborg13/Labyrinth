#!/bin/sh
set -eu
# Keep the movie clock and the live Continue viewport at the same resolution.
exec godot --windowed --resolution 1920x1080 --fixed-fps 60 --write-movie "${FX38_CLOCK_FILE:?}" "$@"
