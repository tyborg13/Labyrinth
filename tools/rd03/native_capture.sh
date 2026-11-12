#!/bin/sh
set -eu
# Task-local native default for the project's mobile renderer.
exec godot --rendering-driver metal --rendering-method mobile "$@"
