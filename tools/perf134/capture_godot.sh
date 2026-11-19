#!/bin/sh
# Screenshots use the gameplay movie clock. Timing runs never use this wrapper.
: "${PERF134_CAPTURE_MOVIE:?PERF134_CAPTURE_MOVIE must name a scratch AVI}"
exec godot --windowed --write-movie "$PERF134_CAPTURE_MOVIE" --fixed-fps 60 "$@"
