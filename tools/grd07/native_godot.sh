#!/bin/sh
set -eu
exec python3 tools/godot_task_runner.py --task-id grd-09 --stream -- godot --windowed --resolution 1920x1080 "$@"
