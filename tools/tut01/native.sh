#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
export LABYRINTH_CEL_LOOK=all
probe=tools/tut01/native_capture.gd

case "$#:${1:-}" in
    1:--dry-run)
        exec python3 tools/godot_task_runner.py --task-id tut-01 --stream -- godot \
            --headless --path . --script "$probe" -- --dry-run
        ;;
    0:) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

exec python3 tools/visual_probe_runner.py "$probe" --task-id tut-01 \
    --no-headless --display-driver macos --audio-driver Dummy \
    --expect-size 1920x1080 --min-images 3 --timeout 60 \
    --proof-contract tools/tut01/proof_contract.json \
    --result-manifest .godot/tut01/native/manifest.json --overwrite-result-manifest
