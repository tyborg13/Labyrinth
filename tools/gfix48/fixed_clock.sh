#!/bin/sh
# One rendered frame every 10 ms of Godot time for the 30 ms strip samples.
exec godot --fixed-fps 100 "$@"
