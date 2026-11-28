#!/usr/bin/env bash
set -euo pipefail
exec godot --main-pack "${FEL30_OVERLAY:?missing diagnostic main pack}" "$@"
