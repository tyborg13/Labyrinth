#!/bin/sh
set -eu
exec godot --windowed --resolution 64x64 --fixed-fps 60 --write-movie "${FX13_CLOCK_FILE:?}" "$@"
