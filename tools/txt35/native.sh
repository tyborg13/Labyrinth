#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
proof_root=/private/tmp/labyrinth_codex/txt-35
export LABYRINTH_CEL_LOOK=all

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

mkdir -p "$proof_root"
output=$(mktemp -d "$proof_root/proof.XXXXXX")
export TXT35_OUTPUT="$output/after"
printf 'TXT35 OUTPUT FOLDER %s\n' "$output"

if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id txt-35 --stream -- godot --headless \
        --path . --script res://tools/txt35/pages.gd | tee "$output/after.log"
else
    python3 tools/visual_probe_runner.py --task-id txt-35 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract tools/txt35/native_contract.json \
        --result-manifest "$output/after-captures.json" res://tools/txt35/pages.gd | tee "$output/after.log"
fi
printf 'TXT35 OUTPUT FOLDER %s\n' "$output"
