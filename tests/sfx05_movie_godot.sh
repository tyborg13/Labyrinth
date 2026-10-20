#!/bin/sh
# MovieWriter records the mixed audio track as well as the root viewport.
set -eu
mkdir -p output/sfx/sfx-05
exec godot --write-movie output/sfx/sfx-05/empower-toggles.avi --fixed-fps 60 --windowed --resolution 1920x1080 "$@"
