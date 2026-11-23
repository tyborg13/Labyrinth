#!/bin/sh
set -eu
exec godot --windowed --resolution 64x64 --fixed-fps 60 --write-movie "${FX17_CLOCK_FILE:?}" "$@"
