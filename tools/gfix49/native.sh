#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
export LABYRINTH_CEL_LOOK=all

if [ "${1:-}" = "--dry-run" ]; then
    exec python3 tools/godot_task_runner.py --task-id gfix-49 --stream -- godot --headless --path . \
        --script tools/gfix49/native_probe.gd -- --dry-run
fi

exec python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy \
    --task-id gfix-49 --expect-size 1920x1080 --proof-contract tools/gfix49/proof_contract.json \
    tools/gfix49/native_probe.gd
