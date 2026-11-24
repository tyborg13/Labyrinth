#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
export LABYRINTH_CEL_LOOK=all
proof_root="$repo/output/gfix54"
probe=res://tools/gfix54/native_probe.gd

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --dry-run ) ]]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

mkdir -p "$proof_root"
touch "$repo/output/.gdignore"
export GFIX54_OUTPUT
GFIX54_OUTPUT=$(mktemp -d "$proof_root/native.XXXXXX")

if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id gfix-54 --stream -- godot --headless \
        --path . --script "$probe" | tee "$GFIX54_OUTPUT/probe.log"
else
    python3 tools/visual_probe_runner.py --task-id gfix-54 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract tools/gfix54/native_contract.json \
        --result-manifest "$GFIX54_OUTPUT/captures.json" "$probe" | tee "$GFIX54_OUTPUT/probe.log"
fi
