#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
proof_root=/private/tmp/labyrinth_codex/txt-42-native
capture_timeout_seconds=90
export LABYRINTH_CEL_LOOK=all

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

mkdir -p "$proof_root"
output=$(mktemp -d "$proof_root/proof.XXXXXX")
export TXT42_OUTPUT="$output/captures"

if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id txt-42 --stream -- godot --headless \
        --path . --script res://tools/txt42/native_capture.gd | tee "$output/capture.log"
else
    python3 tools/visual_probe_runner.py --task-id txt-42 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --timeout "$capture_timeout_seconds" --proof-contract tools/txt42/native_contract.json \
        --result-manifest "$output/captures.json" res://tools/txt42/native_capture.gd | tee "$output/capture.log"
fi
