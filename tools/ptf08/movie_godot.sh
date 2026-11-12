#!/bin/sh
# Engine flags precede the visual runner's -- user-argument separator.
mkdir -p /private/tmp/labyrinth_codex/ptf-08/movement-capture/frames
exec godot --write-movie /private/tmp/labyrinth_codex/ptf-08/movement-capture/frames/movie.png --fixed-fps 30 "$@"
