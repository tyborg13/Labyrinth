#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export LABYRINTH_CEL_LOOK=all

if [[ "${1:-}" == "--dry-run" ]]; then
    exec python3 tools/godot_task_runner.py --task-id eco-03 --stream -- godot \
        --headless --path . --script tools/eco03/native.gd
fi

exec python3 tools/visual_probe_runner.py tools/eco03/native.gd --task-id eco-03 \
    --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
    --proof-contract tools/eco03/native_contract.json \
    --result-manifest .godot/eco03/native_manifest.json --overwrite-result-manifest
