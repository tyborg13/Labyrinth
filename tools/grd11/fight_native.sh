#!/bin/sh
set -eu
clock_dir="$(mktemp -d ${TMPDIR:-/private/tmp}/grd11-clock.XXXXXX)"
trap 'rm -f "$clock_dir/clock.avi"; rmdir "$clock_dir"' EXIT
python3 tools/godot_task_runner.py --task-id grd-11 --timeout 600 --stream -- \
  godot --write-movie "$clock_dir/clock.avi" --fixed-fps 24 --windowed --resolution 1920x1080 "$@"
