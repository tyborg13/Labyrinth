#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."
export LABYRINTH_CEL_LOOK=all
output=/private/tmp/labyrinth_codex/pol-60
probe=tools/pol60/capture.gd

case "${1:-}" in
    --dry-run)
        python3 tools/godot_task_runner.py --task-id pol-60 --stream -- godot --headless --path . --script "$probe" -- --dry-run --before
        python3 tools/godot_task_runner.py --task-id pol-60 --stream -- godot --headless --path . --script "$probe" -- --dry-run
        python3 tools/godot_task_runner.py --task-id pol-60 --stream -- godot --headless --path . --script "$probe" -- --dry-run --compact-event
        ;;
    "")
        python3 tools/visual_probe_runner.py "$probe" --task-id pol-60 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/pol60/proof_contract.json --result-manifest "$output/before/manifest.json" --overwrite-result-manifest -- --before
        python3 tools/visual_probe_runner.py "$probe" --task-id pol-60 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/pol60/proof_contract.json --min-images 18 --result-manifest "$output/after/manifest.json" --overwrite-result-manifest
        ;;
    *)
        echo "Usage: $0 [--dry-run]" >&2
        exit 2
        ;;
esac
