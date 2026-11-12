#!/bin/sh
mkdir -p /private/tmp/labyrinth_codex/ptf-08c/capture/frames
exec godot --write-movie /private/tmp/labyrinth_codex/ptf-08c/capture/frames/movie.png --fixed-fps 30 "$@"
