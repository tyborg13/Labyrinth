#!/usr/bin/env bash
set -euo pipefail
exec godot --main-pack "${FEL32_PACK:?missing fel-32 diagnostic main pack}" "$@"
