#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

export LABYRINTH_CEL_LOOK=all
proof_root=/private/tmp/labyrinth_codex/crd-33
probe=res://tools/crd33/capture.gd
mkdir -p "$proof_root"
output=$(mktemp -d "$proof_root/native.XXXXXX")

case "${1:-}" in
    --dry-run)
        python3 tools/godot_task_runner.py --task-id crd-33 --stream -- godot --headless \
            --path . --script "$probe" -- "$output" | tee "$output/probe.log"
        ;;
    "")
        python3 tools/visual_probe_runner.py --task-id crd-33 --no-headless \
            --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
            --proof-contract tools/crd33/native_contract.json \
            --result-manifest "$output/manifest.json" "$probe" -- "$output" | tee "$output/probe.log"
        for card_id in stoke white_silence sleet_squall; do
            printf '%s/%s.png\n' "$output" "$card_id"
        done
        ;;
    *)
        printf 'Usage: %s [--dry-run]\n' "$0" >&2
        exit 2
        ;;
esac
printf 'CRD33 PROOF DIRECTORY %s\n' "$output"
