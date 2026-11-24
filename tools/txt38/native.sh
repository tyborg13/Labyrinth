#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$repo"
export LABYRINTH_CEL_LOOK=all
proof_root="$repo/output/txt38"
probe=res://tools/txt38/native_probe.gd

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

mkdir -p "$proof_root"
touch "$repo/output/.gdignore"
export TXT38_OUTPUT
TXT38_OUTPUT=$(mktemp -d "$proof_root/native.XXXXXX")
export TXT38_GRIMOIRE="$TXT38_OUTPUT/grimoire.json"
git show codex/txt-36:data/grimoire.json > "$TXT38_GRIMOIRE"

if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id txt-38 --stream -- godot --headless \
        --path . --script "$probe" | tee "$TXT38_OUTPUT/probe.log"
else
    python3 tools/visual_probe_runner.py --task-id txt-38 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract tools/txt38/native_contract.json \
        --result-manifest "$TXT38_OUTPUT/captures.json" "$probe" | tee "$TXT38_OUTPUT/probe.log"
fi
