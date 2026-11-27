#!/usr/bin/env bash
set -euo pipefail
exec godot --windowed --resolution 1920x1080 --fixed-fps 30 --write-movie "${FEL13_MOVIE:?}" "$@"
