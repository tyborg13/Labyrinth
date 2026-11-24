#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
export LABYRINTH_CEL_LOOK=all
script=tools/gfix53/native.gd
if [[ "${1:-}" == "--dry-run" && $# -eq 1 ]]; then
    exec python3 tools/godot_task_runner.py --task-id gfix-53 --stream -- \
        godot --headless --path . --script "$script" -- --check-only
fi
if [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi
exec python3 tools/visual_probe_runner.py "$script" --task-id gfix-53 \
    --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
    --proof-contract tools/gfix53/native_contract.json
