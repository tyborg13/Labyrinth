#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
export LABYRINTH_CEL_LOOK=all
proof_root=/private/tmp/labyrinth_codex/pol-83
probe=res://tools/pol83/capture.gd
contract=tools/pol83/proof_contract.json

case "${1:-}" in
    ""|--dry-run) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi
mkdir -p "$proof_root"
export POL83_OUTPUT
if [[ "${1:-}" == --dry-run ]]; then
    POL83_OUTPUT=$(mktemp -d "$proof_root/headless.XXXXXX")
    python3 tools/godot_task_runner.py --task-id pol-83 --stream -- godot \
        --headless --path . --script "$probe" | tee "$POL83_OUTPUT/probe.log"
else
    POL83_OUTPUT=$(mktemp -d "$proof_root/native.XXXXXX")
    python3 tools/visual_probe_runner.py --task-id pol-83 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract "$contract" --result-manifest "$POL83_OUTPUT/captures.json" \
        "$probe" | tee "$POL83_OUTPUT/probe.log"
fi
