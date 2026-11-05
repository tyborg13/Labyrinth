#!/bin/sh
# Visual-probe runner adapter; records with Godot's built-in AVI writer.
set -eu
FX01_CLIP_OUTPUT=${FX01_CLIP_OUTPUT:-/private/tmp/labyrinth_codex/fx-01/card_buff_playback.avi}
FX01_CLIP_FPS=60
mkdir -p "$(dirname "$FX01_CLIP_OUTPUT")"
exec godot --write-movie "$FX01_CLIP_OUTPUT" --fixed-fps "$FX01_CLIP_FPS" --windowed --resolution 1920x1080 "$@"
