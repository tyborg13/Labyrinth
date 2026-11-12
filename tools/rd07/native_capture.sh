#!/bin/sh
set -eu
exec godot --rendering-driver metal --rendering-method mobile "$@"
