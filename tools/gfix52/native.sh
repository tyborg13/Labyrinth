#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
probe=tools/gfix52/retreat_capture.gd
export LABYRINTH_CEL_LOOK=all

case $#:${1:-} in
    1:--dry-run)
        exec python3 tools/godot_task_runner.py --task-id gfix-52 --stream -- godot \
            --headless --path . --script "$probe"
        ;;
    0:) ;;
    *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac

exec python3 tools/visual_probe_runner.py "$probe" --task-id gfix-52 \
    --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
    --timeout 120 --proof-contract tools/gfix52/proof_contract.json \
    --result-manifest .godot/gfix52/native/round-2-manifest.json --overwrite-result-manifest
