#!/bin/sh
set -eu
exec godot --windowed --resolution 64x64 --fixed-fps 30 --write-movie "${FEL10_FIX_CLOCK:?}" "$@"
