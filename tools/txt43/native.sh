#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
export LABYRINTH_CEL_LOOK=all
proof_root="$repo/output/txt43"
probe=res://tools/txt43/native_probe.gd
contract=tools/txt43/native_contract.json

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

mkdir -p "$proof_root"
touch "$repo/output/.gdignore"
export TXT43_OUTPUT
TXT43_OUTPUT=$(mktemp -d "$proof_root/native.XXXXXX")

if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id txt-43 --stream -- godot --headless \
        --path . --script "$probe" | tee "$TXT43_OUTPUT/probe.log"
else
    python3 tools/visual_probe_runner.py --task-id txt-43 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract "$contract" \
        --result-manifest "$TXT43_OUTPUT/captures.json" "$probe" | tee "$TXT43_OUTPUT/probe.log"
fi
