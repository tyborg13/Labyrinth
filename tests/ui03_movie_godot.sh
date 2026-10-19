#!/bin/sh
# Visual-probe runner Godot adapter: use the engine's built-in AVI writer.
set -eu
mkdir -p output/ui03
# --windowed: the project default is fullscreen, and its exit animation would resize frames mid-clip.
exec godot --write-movie output/ui03/empower-interactions.avi --fixed-fps 60 --windowed --resolution 1920x1080 "$@"
