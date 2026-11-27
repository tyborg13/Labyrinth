#!/usr/bin/env bash
set -euo pipefail
# visual_probe_runner owns renderer choice and process isolation.
exec godot --fixed-fps "${FEL14_PROOF_FPS:-60}" "$@"
