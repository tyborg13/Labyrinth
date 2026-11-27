#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

export LABYRINTH_CEL_LOOK=all
proof_root=/private/tmp/labyrinth_codex/crd-34
probe=res://tools/crd34/capture.gd

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --dry-run ) ]]; then
    printf 'Usage: %s [--dry-run]\n' "$0" >&2
    exit 2
fi

mkdir -p "$proof_root"
output=$(mktemp -d "$proof_root/native.XXXXXX")
printf 'CRD34 PROOF DIRECTORY %s\n' "$output"
if [[ "${1:-}" == --dry-run ]]; then
    python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless \
        --path . --script "$probe" -- "$output" 2>&1 | tee "$output/probe.log"
else
    python3 tools/visual_probe_runner.py --task-id crd-34 --no-headless \
        --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
        --proof-contract tools/crd34/native_contract.json \
        --result-manifest "$output/manifest.json" "$probe" -- "$output" 2>&1 | tee "$output/probe.log"
fi
