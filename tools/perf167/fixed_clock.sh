#!/bin/sh
set -eu
capture_fps=60
exec godot --fixed-fps "$capture_fps" "$@"
