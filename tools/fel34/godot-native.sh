#!/usr/bin/env bash
set -euo pipefail
exec godot --main-pack "${FEL34_OVERLAY:?missing caption diagnostic pack}" "$@"
